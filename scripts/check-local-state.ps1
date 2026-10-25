<#
.SYNOPSIS
  只读排查：对比 App 本地「群表 / 群会话」与 OpenIM 服务端群状态。

.DESCRIPTION
  从 debug 包 run-as 拉取 openim_<userID>.db 以及 -wal/-shm（必须一起拉，否则看到旧快照），
  统计并打印：
    - 本地群表数量与 status 分布（0 正常 / 1 禁言 / 2 已解散）
    - sg_* 群会话清单、孤儿会话（会话存在但本地群表无该群）
    - 每个本地群在服务端的状态（0/1/2/missing）

  脚本只读：只在系统临时目录写文件，不修改设备与仓库数据；默认结束时清理临时目录。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\check-local-state.ps1
  powershell -ExecutionPolicy Bypass -File scripts\check-local-state.ps1 -Serial 849f6987
  powershell -ExecutionPolicy Bypass -File scripts\check-local-state.ps1 -UserId 2006526104 -KeepFiles
#>
[CmdletBinding()]
param(
  [string]$Serial = '',
  [string]$Package = 'com.example.flutter_rust_demo',
  [string]$UserId = '',
  [string]$ApiBase = 'http://127.0.0.1:10002',
  [string]$AdminSecret = 'openIM123#&9873d',
  [switch]$KeepFiles
)

$ErrorActionPreference = 'Stop'

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
  if ($cmd) { return $cmd }
  $candidates = @(
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\Android\Sdk\platform-tools\adb.exe",
    'D:\Data\Android\Sdk\platform-tools\adb.exe'
  ) | Where-Object { $_ -and (Test-Path $_) }
  if ($candidates) { return @($candidates)[0] }
  throw '找不到 adb，请安装 Android SDK platform-tools 或把 adb 加入 PATH'
}

$adb = Find-Adb
if (-not $Serial) {
  $lines = @(& $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice$" })
  if ($lines.Count -eq 0) { throw '没有处于 device（已授权）状态的设备，请先运行 scripts\dev-connect.ps1' }
  $Serial = ($lines[0] -split "`t")[0]
}

$python = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
if (-not $python) { throw '找不到 python，无法解析本地 SQLite；请安装 Python 3' }

$remoteDir = 'app_flutter/openim_data'
$listing = @(& $adb -s $Serial shell "run-as $Package ls $remoteDir" 2>&1)
if ($LASTEXITCODE -ne 0) {
  throw "无法读取应用数据（需要 debug 包）：run-as $Package ls $remoteDir 失败"
}

$dbNames = @($listing | Where-Object { $_ -match '^openim_.*\.db$' })
$dbName = ''
if ($UserId) {
  $dbName = "openim_$UserId.db"
  if ($dbNames -notcontains $dbName) { throw "设备上找不到 $dbName（现有：$($dbNames -join ', ')）" }
} elseif ($dbNames.Count -eq 1) {
  $dbName = $dbNames[0]
} else {
  throw "存在多个账号数据库，请用 -UserId 指定：$($dbNames -join ', ')"
}

$userIdText = $dbName -replace '^openim_', '' -replace '\.db$', ''
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("openim-state-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

function Pull-RemoteFile([string]$name, [string]$localName) {
  $local = Join-Path $tmp $localName
  $remote = "$remoteDir/$name"
  $proc = Start-Process -FilePath $adb `
    -ArgumentList @('-s', $Serial, 'exec-out', "run-as $Package cat $remote") `
    -RedirectStandardOutput $local -NoNewWindow -PassThru -Wait
  if ($proc.ExitCode -ne 0) { throw "拉取 $name 失败（exit=$($proc.ExitCode)）" }
  return $local
}

try {
  Write-Host "[state] 设备=$Serial 用户=$userIdText 数据库=$dbName" -ForegroundColor Cyan
  $localDb = Pull-RemoteFile $dbName 'app.db'
  Pull-RemoteFile "$dbName-wal" 'app.db-wal' | Out-Null
  Pull-RemoteFile "$dbName-shm" 'app.db-shm' | Out-Null

  $py = Join-Path $tmp 'dump.py'
  $jsonOut = Join-Path $tmp 'state.json'
  $pyCode = @'
import json
import sqlite3
import sys

db, out = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db)
groups = [
    {"group_id": row[0], "name": row[1], "status": row[2]}
    for row in con.execute("select group_id, name, status from local_groups order by group_id")
]
conversations = [
    {"conversation_id": row[0], "group_id": row[1] or ""}
    for row in con.execute(
        "select conversation_id, group_id from local_conversations "
        "where conversation_id like 'sg_%' order by conversation_id"
    )
]
ids = {g["group_id"] for g in groups}
orphans = [c["conversation_id"] for c in conversations if c["group_id"] not in ids]
with open(out, "w", encoding="utf-8") as fh:
    json.dump({"groups": groups, "conversations": conversations, "orphans": orphans},
              fh, ensure_ascii=False, indent=2)
'@
  [IO.File]::WriteAllText($py, $pyCode, [Text.UTF8Encoding]::new($false))
  & $python $py $localDb $jsonOut
  if ($LASTEXITCODE -ne 0) { throw 'Python 解析本地数据库失败' }

  $state = Get-Content -LiteralPath $jsonOut -Raw -Encoding utf8 | ConvertFrom-Json
  $groups = @($state.groups)
  $orphans = @($state.orphans)

  $statusCounts = ($groups | Group-Object status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
  if (-not $statusCounts) { $statusCounts = '（无群）' }
  Write-Host "[state] 本地群 $(@($groups).Count) 个；status 分布：$statusCounts"
  foreach ($g in $groups) {
    Write-Host ("         {0,-16} status={1}  {2}" -f $g.group_id, $g.status, $g.name)
  }

  Write-Host "[state] 本地 sg_* 会话 $(@($state.conversations).Count) 个；孤儿会话 $($orphans.Count) 个"
  if ($orphans.Count -gt 0) {
    Write-Host ("         孤儿：{0}" -f ($orphans -join ', ')) -ForegroundColor Yellow
  }

  $mismatches = 0
  if ($groups.Count -gt 0) {
    $header = @{ operationID = [guid]::NewGuid().ToString() }
    $token = (Invoke-RestMethod -Uri "$ApiBase/auth/get_admin_token" -Method Post -Headers $header `
      -ContentType 'application/json' -Body (@{ secret = $AdminSecret; userID = 'imAdmin' } | ConvertTo-Json)).data.token
    $auth = @{ token = $token; operationID = [guid]::NewGuid().ToString() }
    $ids = @($groups | ForEach-Object { $_.group_id })
    $resp = Invoke-RestMethod -Uri "$ApiBase/group/get_groups_info" -Method Post -Headers $auth `
      -ContentType 'application/json' -Body (@{ groupIDs = $ids } | ConvertTo-Json -Depth 3)
    $server = @{}
    foreach ($item in @($resp.data.groupInfos)) {
      if ($item) { $server[$item.groupID] = $item.status }
    }
    Write-Host '[state] 本地 vs 服务端：'
    foreach ($g in $groups) {
      $serverStatus = if ($server.ContainsKey($g.group_id)) { "$($server[$g.group_id])" } else { 'missing' }
      $same = "$($g.status)" -eq $serverStatus
      if (-not $same) { $mismatches++ }
      $color = if ($same) { 'Green' } else { 'Yellow' }
      Write-Host ("         {0,-16} local={1,-2} server={2}" -f $g.group_id, $g.status, $serverStatus) -ForegroundColor $color
    }
  }

  if ($orphans.Count -eq 0 -and $mismatches -eq 0) {
    Write-Host '[state] 结论：本地群表与会话一致，无需处理' -ForegroundColor Green
  } else {
    Write-Host "[state] 结论：孤儿会话 $($orphans.Count) 个，状态不一致 $mismatches 个（下次登录/重连对账会自动清理已解散群）" -ForegroundColor Yellow
  }
} finally {
  if ($KeepFiles) {
    Write-Host "[state] 调试文件保留在：$tmp" -ForegroundColor Cyan
  } else {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
