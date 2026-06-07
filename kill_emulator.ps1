# Use .NET to kill the process directly
$proc = [System.Diagnostics.Process]::GetProcessById(27156)
if ($proc) {
    Write-Host "Found process: $($proc.ProcessName) (PID: $($proc.Id))"
    try {
        $proc.Kill()
        Write-Host "Process killed successfully"
    } catch {
        Write-Host "Kill failed: $($_.Exception.Message)"
    }
}

Start-Sleep -Seconds 3

# Verify
try {
    $check = [System.Diagnostics.Process]::GetProcessById(27156)
    Write-Host "Process still exists: $($check.ProcessName)"
} catch {
    Write-Host "Process is gone"
}
