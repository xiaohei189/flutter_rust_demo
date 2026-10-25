<#
.SYNOPSIS
  一键门禁：Flutter/Rust 全量测试、静态检查、架构/设计 token 与 codegen 一致性。

.DESCRIPTION
  默认按顺序执行，任一步失败立即停止并返回非零：
    1. flutter test test
    2. flutter analyze lib test
    3. cargo test --lib
    4. cargo clippy --all-targets
    5. scripts/check-architecture.ps1
    6. scripts/check-design-tokens.ps1
    7. scripts/check-codegen.ps1（-SkipCodegen 可跳过，约 3 分钟）
  最后打印每一步耗时汇总。

.NOTES
  本文件需保持 UTF-8 BOM 编码：Windows PowerShell 5.1 读取无 BOM 的中文脚本会乱码报错。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\check-all.ps1
  powershell -ExecutionPolicy Bypass -File scripts\check-all.ps1 -SkipCodegen
#>
[CmdletBinding()]
param(
  [switch]$SkipCodegen
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Step {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [scriptblock]$Action
  )
  Write-Host "==> $Name" -ForegroundColor Cyan
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  Push-Location $WorkingDirectory
  try {
    & $Action
    if ($LASTEXITCODE -ne 0) {
      throw "命令退出码 $LASTEXITCODE"
    }
  } catch {
    $watch.Stop()
    $results.Add([pscustomobject]@{
      Step    = $Name
      Result  = 'FAIL'
      Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
    })
    Write-Host "    FAIL: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    $results | Format-Table -AutoSize | Out-String | Write-Host
    exit 1
  } finally {
    Pop-Location
  }
  $watch.Stop()
  $results.Add([pscustomobject]@{
    Step    = $Name
    Result  = 'PASS'
    Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
  })
  Write-Host ('    PASS ({0}s)' -f [math]::Round($watch.Elapsed.TotalSeconds, 1)) -ForegroundColor Green
}

Invoke-Step 'Flutter 全量测试' $root { flutter test test }
Invoke-Step 'Flutter 静态分析' $root { flutter analyze lib test }
Invoke-Step 'Rust 单测' (Join-Path $root 'rust') { cargo test --lib }
Invoke-Step 'Rust clippy' (Join-Path $root 'rust') { cargo clippy --all-targets }
Invoke-Step '架构边界检查' $root { powershell -ExecutionPolicy Bypass -File scripts\check-architecture.ps1 }
Invoke-Step '设计 token 检查' $root { powershell -ExecutionPolicy Bypass -File scripts\check-design-tokens.ps1 }
if (-not $SkipCodegen) {
  Invoke-Step 'Codegen 一致性' $root { powershell -ExecutionPolicy Bypass -File scripts\check-codegen.ps1 }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host
$total = ($results | Measure-Object -Property Seconds -Sum).Sum
Write-Host ('全部通过，用时 {0}s' -f [math]::Round($total, 1)) -ForegroundColor Green
