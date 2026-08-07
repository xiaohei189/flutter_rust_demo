param(
    [string]$Suite = "",
    [ValidateSet("Smoke", "Full")]
    [string]$Mode = "Full"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$suites = @(
    "connection_tests",
    "conversation_tests",
    "friend_tests",
    "group_tests",
    "message_tests",
    "negative_tests",
    "user_tests"
)

if ($Suite -ne "") {
    $suites = @($Suite)
} elseif ($Mode -eq "Smoke") {
    $suites = @("contract_tests")
}

foreach ($s in $suites) {
    Write-Host "== $s (requires docker OpenIM server) =="
    cargo test --test $s -- --ignored --test-threads=1
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host "Integration tests passed."
