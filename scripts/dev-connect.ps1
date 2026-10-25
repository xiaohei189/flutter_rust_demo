<#
.SYNOPSIS
  重连真机开发链路：等待设备授权后重放 adb reverse（10001/10002/10008/10005）。

.DESCRIPTION
  宿主重启、USB 抖动或「USB 调试授权」丢失后，设备上的 adb reverse 规则会消失，
  App 访问 127.0.0.1 失败，表现为「网络断开/一直转圈」。本脚本：
    1. 找到 adb 并等待设备进入 device（已授权）状态；
    2. 为设备重放四条 reverse 规则（与 scripts/adb_reverse.ps1 保持一致）；
    3. 打印设备与转发状态。

  -Watch 常驻：每 2 秒轮询一次，设备上线或转发规则缺失时自动恢复，只在状态变化时打印。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\dev-connect.ps1
  powershell -ExecutionPolicy Bypass -File scripts\dev-connect.ps1 -Watch
  powershell -ExecutionPolicy Bypass -File scripts\dev-connect.ps1 -Serial 849f6987
#>
[CmdletBinding()]
param(
  [string]$Serial = '',
  [switch]$Watch,
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$ports = @(10001, 10002, 10008, 10005)

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

function Get-DeviceStates {
  $lines = @(& $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
  foreach ($line in $lines) {
    $parts = $line -split "`t"
    if ($parts.Count -ge 2) {
      [pscustomobject]@{ Serial = $parts[0]; State = $parts[1].Trim() }
    }
  }
}

function Get-TargetSerials {
  $devices = @(Get-DeviceStates)
  if ($Serial) {
    $match = $devices | Where-Object { $_.Serial -eq $Serial } | Select-Object -First 1
    if (-not $match) { return @() }
    if ($match.State -ne 'device') { return @() }
    return @($Serial)
  }
  return @($devices | Where-Object { $_.State -eq 'device' } | ForEach-Object { $_.Serial })
}

function Get-ReverseCount([string]$serial) {
  $rules = @(& $adb -s $serial reverse --list 2>$null)
  return @($ports | Where-Object { $rules -match "tcp:$_" }).Count
}

function Invoke-Reverse([string[]]$serials) {
  foreach ($serial in $serials) {
    foreach ($port in $ports) {
      & $adb -s $serial reverse "tcp:$port" "tcp:$port" 2>$null | Out-Null
    }
    $ok = Get-ReverseCount $serial
    if ($ok -eq $ports.Count) {
      Write-Host "[dev-connect] $serial 转发已就绪 $ok/$($ports.Count)" -ForegroundColor Green
    } else {
      Write-Host "[dev-connect] $serial 转发仅 $ok/$($ports.Count)，请检查 USB 连接" -ForegroundColor Red
    }
  }
}

function Wait-ForDevice([int]$timeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($timeoutSeconds)
  $hinted = $false
  while ((Get-Date) -lt $deadline) {
    $devices = @(Get-DeviceStates)
    $ready = @($devices | Where-Object { $_.State -eq 'device' })
    if ($ready.Count -gt 0) { return $ready }
    if (-not $hinted) {
      $unauthorized = @($devices | Where-Object { $_.State -eq 'unauthorized' })
      if ($unauthorized.Count -gt 0) {
        Write-Host '[dev-connect] 设备未授权：请解锁手机并点「允许 USB 调试」' -ForegroundColor Yellow
      } else {
        Write-Host '[dev-connect] 等待设备连接…' -ForegroundColor Yellow
      }
      $hinted = $true
    }
    Start-Sleep -Seconds 2
  }
  return @()
}

if (-not $Watch) {
  $targets = @(Get-TargetSerials)
  if ($targets.Count -eq 0) {
    $ready = @(Wait-ForDevice $TimeoutSeconds)
    $targets = @($ready | ForEach-Object { $_.Serial })
  }
  if ($targets.Count -eq 0) {
    Write-Host "[dev-connect] ${TimeoutSeconds}s 内没有可用设备（device 状态）" -ForegroundColor Red
    exit 1
  }
  Invoke-Reverse $targets
  & $adb devices
  exit 0
}

Write-Host '[dev-connect] 监听中（Ctrl+C 退出）：设备上线或转发缺失时自动恢复' -ForegroundColor Cyan
$healthy = @{}
$warnedUnauthorized = $false
while ($true) {
  $devices = @(Get-DeviceStates)
  $ready = @($devices | Where-Object { $_.State -eq 'device' })
  $unauthorized = @($devices | Where-Object { $_.State -eq 'unauthorized' })

  if ($unauthorized.Count -gt 0 -and -not $warnedUnauthorized) {
    Write-Host '[dev-connect] 设备未授权：请解锁手机并点「允许 USB 调试」' -ForegroundColor Yellow
    $warnedUnauthorized = $true
  } elseif ($unauthorized.Count -eq 0) {
    $warnedUnauthorized = $false
  }

  $targets = @($ready | ForEach-Object { $_.Serial })
  if ($Serial) { $targets = @($targets | Where-Object { $_ -eq $Serial }) }

  foreach ($serial in $targets) {
    $rulesOk = (Get-ReverseCount $serial) -eq $ports.Count
    if ($healthy[$serial] -and $rulesOk) { continue }
    if (-not $rulesOk) {
      Write-Host "[dev-connect] $serial 转发缺失，正在恢复…" -ForegroundColor Yellow
    }
    Invoke-Reverse @($serial)
    $healthy[$serial] = $true
  }

  foreach ($serial in @($healthy.Keys)) {
    if ($targets -notcontains $serial) { $healthy.Remove($serial) }
  }

  Start-Sleep -Seconds 2
}
