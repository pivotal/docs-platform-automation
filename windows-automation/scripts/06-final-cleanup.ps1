# Final cleanup provisioner
# This script performs final cleanup tasks before template creation
# Note: This script runs via govc guest.run, so $PSScriptRoot is not available
# Using simple Write-Host for logging instead of common.ps1 functions

$ErrorActionPreference = "Continue"

Write-Host "=========================================="
Write-Host "Final Cleanup Script"
Write-Host "Timestamp: $(Get-Date)"
Write-Host "=========================================="
Write-Host "Starting final cleanup..."

try {
    # Clear Windows Update cache (optional, can be time-consuming)
    Write-Host "Clearing Windows Update cache..."
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Host "Windows Update cache cleared"
    } catch {
        Write-Host "WARNING: Could not clear Windows Update cache: $($_.Exception.Message)"
    }
    
    # Clear temporary files
    Write-Host "Clearing temporary files..."
    $tempPaths = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Prefetch\*"
    )
    
    foreach ($path in $tempPaths) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleared: $path"
        } catch {
            Write-Host "Could not clear: $path"
        }
    }
    
    # Clear event logs (optional)
    Write-Host "Clearing event logs..."
    $logNames = Get-EventLog -List | Select-Object -ExpandProperty Log
    foreach ($logName in $logNames) {
        try {
            Clear-EventLog -LogName $logName -ErrorAction SilentlyContinue
            Write-Host "Cleared event log: $logName"
        } catch {
            Write-Host "Could not clear event log: $logName"
        }
    }
    
    # Run disk cleanup
    Write-Host "Running disk cleanup..."
    try {
        # Clean up Windows component store
        Start-Process -FilePath "dism.exe" `
                      -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /ResetBase" `
                      -Wait `
                      -NoNewWindow `
                      -ErrorAction SilentlyContinue
        Write-Host "Disk cleanup completed"
    } catch {
        Write-Host "WARNING: Disk cleanup may not have completed: $($_.Exception.Message)"
    }
    
    # Disable WinRM for security (will be re-enabled if needed)
    Write-Host "Configuring WinRM for template..."
    try {
        # Note: We keep WinRM enabled for now as it may be needed for stembuild
        # If you want to disable it, uncomment the following:
        # Stop-Service -Name WinRM -Force -ErrorAction SilentlyContinue
        # Set-Service -Name WinRM -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "WinRM configuration complete"
    } catch {
        Write-Host "WARNING: Could not configure WinRM: $($_.Exception.Message)"
    }
    
    # Final system information
    Write-Host "Final system state:"
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-Host "  C: Drive Free Space: $([math]::Round($disk.FreeSpace / 1GB, 2)) GB"
    Write-Host "  C: Drive Total Space: $([math]::Round($disk.Size / 1GB, 2)) GB"
    
    Write-Host "Final cleanup completed successfully"
    
} catch {
    Write-Host "ERROR: Error during final cleanup: $($_.Exception.Message)"
    Write-Host "ERROR: Stack trace: $($_.ScriptStackTrace)"
    Write-Host "WARNING: Continuing despite cleanup errors"
}

Write-Host "=========================================="
Write-Host "Final cleanup script completed"
Write-Host "VM is ready to be converted to template"
Write-Host "Timestamp: $(Get-Date)"
Write-Host "=========================================="
exit 0
