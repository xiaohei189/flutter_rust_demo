# Design token check（棘轮式）。
#
# 规则：lib/ui 下除 lib/ui/core/theme 外，不得硬编码颜色；
#       颜色统一取 context.appColors.*（见 docs/conventions.md「主题/颜色」）。
#
# 现状：历史遗留的硬编码色记录在 scripts/design-token-baseline.json，
#       本脚本只拦截「新增」违规（按文件计数），迁移完成后基线应被清空并删除。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\check-design-tokens.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\check-design-tokens.ps1 -Update   # 迁移后刷新基线
# 规则二补充：圆角不得写裸数字，统一取 AppTheme.radiusSm/Md/Lg（胶囊用 radiusPill，
#             或按高度计算 —— 只要不是字面量）。圆角已一次性收敛，无基线。
param([switch]$Update)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $baselinePath = Join-Path $PSScriptRoot 'design-token-baseline.json'

  # 豁免判定：行尾 `// design-token-ignore: 原因`。
  # 注意 dart format 会把过长的行尾注释、以及多行调用的参数折行，
  # 所以本行及紧随其后的 3 行内命中注释都算豁免。
  function Test-TokenIgnored([string]$path, [int]$lineNumber, [string]$text) {
    if ($text -match 'design-token-ignore') { return $true }
    $fileLines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
    for ($offset = 0; $offset -le 3; $offset++) {
      $idx = $lineNumber + $offset
      if ($idx -lt $fileLines.Count -and $fileLines[$idx] -match 'design-token-ignore') {
        return $true
      }
    }
    return $false
  }

  # 违规形态：8 位十六进制字面量 / Material 裸色。
  # 不匹配 appColors.*（带前缀），也内置忽略 Colors.transparent（"无色"不是配色决定）。
  # 单行豁免：在行尾加 `// design-token-ignore: 原因`。
  $pattern = 'Color\(0x[0-9A-Fa-f]{8}\)|(?<![a-zA-Z])Colors\.(?!transparent\b)[a-zA-Z]+'
  $raw = & rg -n --pcre2 $pattern lib/ui --glob '!lib/ui/core/theme/**' 2>$null
  if ($LASTEXITCODE -gt 1) { throw 'rg 执行失败，请确认已安装 ripgrep' }

  $counts = @{}
  foreach ($item in $raw) {
    $parts = $item -split ':', 3
    if ($parts.Count -lt 2) { continue }
    # 整行注释里的提及（例如 token 文档）不算违规
    if ($parts.Count -ge 3 -and $parts[2].TrimStart().StartsWith('//')) { continue }
    # 显式豁免（必须带原因，便于 review）
    if ($parts.Count -ge 3 -and (Test-TokenIgnored -path $parts[0] -lineNumber ([int]$parts[1]) -text $parts[2])) { continue }
    $path = $parts[0].Replace('\', '/')
    $current = if ($counts.ContainsKey($path)) { $counts[$path] } else { 0 }
    $counts[$path] = $current + 1
  }

  $totalNow = ($counts.Values | Measure-Object -Sum).Sum
  if ($null -eq $totalNow) { $totalNow = 0 }

  if ($Update) {
    $ordered = [ordered]@{}
    foreach ($key in ($counts.Keys | Sort-Object)) { $ordered[$key] = $counts[$key] }
    $ordered | ConvertTo-Json | Set-Content -Path $baselinePath -Encoding UTF8
    Write-Host "design-token 基线已刷新：$($counts.Count) 个文件 / $totalNow 处" -ForegroundColor Yellow
    exit 0
  }

  # 规则二：圆角裸数字（BorderRadius.circular(8) / Radius.circular(8) …）。
  # 圆角已一次性收敛到 token，没有基线：新增一处即失败。
  $radiusRaw = & rg -n --pcre2 'Radius\.circular\(\s*\d' lib/ui --glob '!lib/ui/core/theme/**' 2>$null
  if ($LASTEXITCODE -gt 1) { throw 'rg 执行失败，请确认已安装 ripgrep' }
  $radiusViolations = @()
  foreach ($item in $radiusRaw) {
    $parts = $item -split ':', 3
    if ($parts.Count -lt 2) { continue }
    if ($parts.Count -ge 3 -and $parts[2].TrimStart().StartsWith('//')) { continue }
    if ($parts.Count -ge 3 -and (Test-TokenIgnored -path $parts[0] -lineNumber ([int]$parts[1]) -text $parts[2])) { continue }
    $radiusViolations += $item
  }
  if ($radiusViolations.Count -gt 0) {
    Write-Host '圆角写了裸数字；lib/ui 内请改用 AppTheme.radiusSm / radiusMd / radiusLg（胶囊用 radiusPill）：' -ForegroundColor Red
    foreach ($item in $radiusViolations) { Write-Host "  $item" }
    Write-Host '确属功能性的例外可在行尾加 // design-token-ignore: 原因' -ForegroundColor Yellow
    exit 1
  }

  $baseline = @{}
  if (Test-Path $baselinePath) {
    $json = Get-Content $baselinePath -Raw | ConvertFrom-Json
    foreach ($property in $json.PSObject.Properties) {
      $baseline[$property.Name] = [int]$property.Value
    }
  }
  $totalBase = ($baseline.Values | Measure-Object -Sum).Sum
  if ($null -eq $totalBase) { $totalBase = 0 }

  $regressions = @()
  foreach ($path in $counts.Keys) {
    $allowed = if ($baseline.ContainsKey($path)) { $baseline[$path] } else { 0 }
    if ($counts[$path] -gt $allowed) {
      $regressions += [PSCustomObject]@{ Path = $path; Now = $counts[$path]; Allowed = $allowed }
    }
  }

  if ($regressions.Count -eq 0) {
    Write-Host "Design token check passed（硬编码色 $totalNow 处，基线 $totalBase 处；裸数字圆角 0 处）。" -ForegroundColor Green
    exit 0
  }

  Write-Host '新增了硬编码颜色；lib/ui 内请改用 context.appColors.*：' -ForegroundColor Red
  foreach ($item in $regressions) {
    Write-Host ("  {0}  {1} -> {2}（基线 {3}）" -f $item.Path, $item.Allowed, $item.Now, $item.Allowed)
  }
  Write-Host '若确属合理例外（如媒体查看器黑底），请说明原因后执行 scripts\check-design-tokens.ps1 -Update 刷新基线。' -ForegroundColor Yellow
  exit 1
}
finally {
  Pop-Location
}
