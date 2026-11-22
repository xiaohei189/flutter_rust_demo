$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Invoke-Check([string]$Label, [scriptblock]$Cmd) {
    Write-Host "== $Label =="
    & $Cmd
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Invoke-Check "cargo test --workspace --lib" { cargo test --workspace --lib }
Invoke-Check "cargo test -p rust_lib_flutter_rust_demo --test hermetic_tests" { cargo test -p rust_lib_flutter_rust_demo --test hermetic_tests }
Invoke-Check "cargo clippy --workspace --all-targets" { cargo clippy --workspace --all-targets -- -D warnings }

Write-Host "Fast tests passed."
