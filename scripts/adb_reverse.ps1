# adb_reverse.ps1 - Android 设备/模拟器端口转发脚本（Windows 版）
# 等价于 scripts/adb_reverse.sh：将设备上的 127.0.0.1 端口转发到宿主机服务。
# 用法：powershell -ExecutionPolicy Bypass -File scripts\adb_reverse.ps1
$ErrorActionPreference = 'Stop'

# ---- 查找 adb ----
$adb = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $adb) {
    $candidates = @(
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:USERPROFILE\Android\Sdk\platform-tools\adb.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    $adb = @($candidates | Select-Object -First 1)
}
if (-not $adb) {
    Write-Host "错误: 找不到 adb，请安装 Android SDK 平台工具或把 adb.exe 加入 PATH" -ForegroundColor Red
    exit 1
}
Write-Host "使用 adb: $adb"

# ---- 检测设备 ----
$lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice$" }
$devices = @($lines | ForEach-Object { ($_ -split "`t")[0] })
if ($devices.Count -eq 0) {
    Write-Host "错误: 未检测到已连接的设备或模拟器，请先连接后重试" -ForegroundColor Red
    exit 1
}
Write-Host "找到 $($devices.Count) 个设备/模拟器`n"

# ---- 需要转发的端口（端口号:说明） ----
$ports = @(
    @{ Port = 10001; Label = 'WebSocket' },
    @{ Port = 10002; Label = 'OpenIM API' },
    @{ Port = 10008; Label = '认证服务' },
    @{ Port = 10005; Label = 'MinIO' }
)

foreach ($device in $devices) {
    # 设备名：优先 AVD 名，失败则用型号
    $name = (& $adb -s $device emu avd name 2>$null | Select-Object -First 1) -replace "`r`n", ''
    if (-not $name -or $name -eq 'OK') {
        $name = (& $adb -s $device shell getprop ro.product.model 2>$null) -replace "`r`n", ''
    }
    if (-not $name) { $name = 'unknown' }
    Write-Host "设备: $device ($name)"
    foreach ($p in $ports) {
        & $adb -s $device reverse "tcp:$($p.Port)" "tcp:$($p.Port)" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $($p.Label) ($($p.Port))" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($p.Label) ($($p.Port))" -ForegroundColor Red
        }
    }
    Write-Host ''
}

Write-Host '端口转发设置完成！设备可通过 127.0.0.1 访问宿主机服务。' -ForegroundColor Green