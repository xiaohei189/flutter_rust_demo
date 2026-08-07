$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "== contract tests (requires docker OpenIM server) =="
cargo test --test contract_tests -- --ignored --test-threads=1
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Contract tests passed."
