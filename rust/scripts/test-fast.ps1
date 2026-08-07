$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Invoke-Check([string]$Label, [scriptblock]$Cmd) {
    Write-Host "== $Label =="
    & $Cmd
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Invoke-Check "cargo test --lib" { cargo test --lib }
Invoke-Check "cargo test --test hermetic_tests" { cargo test --test hermetic_tests }
Invoke-Check "cargo clippy --all-targets" { cargo clippy --all-targets }

Write-Host "Fast tests passed."
