$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

# 自动读取 App 当前登录用户的手机号（Windows shared_preferences）
$prefs = Join-Path $env:APPDATA "com.example\flutter_rust_demo\shared_preferences.json"
if (Test-Path $prefs) {
    try {
        $json = Get-Content $prefs -Raw | ConvertFrom-Json
        $phone = $json.'flutter.login_phone_number'
        if ($phone) {
            $env:OPENIM_DEMO_TARGET_PHONE = $phone
            Write-Host "检测到当前登录用户手机号: $phone"
        }
    } catch {
        Write-Host "读取本地登录信息失败，将使用演示主账号"
    }
} else {
    Write-Host "未找到本地登录信息（$prefs），将使用演示主账号 17764008301"
}

Write-Host "== 给当前用户生成 OpenIM 演示数据（需 Docker OpenIM：10001/10002/10008）=="
cargo test --test seed_demo -- --ignored --test-threads=1 --nocapture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host ""
Write-Host "完成。在 App 里重新登录（手机号 + 验证码 666666）即可看到联系人与会话。"