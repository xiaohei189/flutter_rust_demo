# Architecture boundary check. Exits non-zero on violations.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

$uiViolations = & rg -n "generated/rust/(ffi|client)" lib/ui lib/providers --glob "!lib/generated/**" 2>$null
$uiOk = $LASTEXITCODE -eq 1

$dataViolations = & rg -n "from '\.\./ui/|from '\.\./providers/|ui/core/utils/app_logger" lib/data lib/domain 2>$null
$dataOk = $LASTEXITCODE -eq 1

if (-not $uiOk) {
  Write-Host "UI/Providers must not import generated/rust/ffi or generated/rust/client:" -ForegroundColor Red
  Write-Host $uiViolations
}
if (-not $dataOk) {
  Write-Host "Data/Domain must not import UI/Providers:" -ForegroundColor Red
  Write-Host $dataViolations
}

if ($uiOk -and $dataOk) {
  Write-Host "Architecture boundary check passed." -ForegroundColor Green
  exit 0
}
exit 1