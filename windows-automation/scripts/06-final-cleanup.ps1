# Final cleanup provisioner
# This script performs final cleanup tasks before template creation

. "$PSScriptRoot\00-common.ps1"

Set-BuildStatus -Step "FinalCleanup" -Status "Running" -Progress 90
Write-InfoLog "Starting final cleanup provisioner"

try {
    # Clear Windows Update cache (optional, can be time-consuming)
    Write-InfoLog "Clearing Windows Update cache..."
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-InfoLog "Windows Update cache cleared"
    } catch {
        Write-WarnLog "Could not clear Windows Update cache: $($_.Exception.Message)"
    }
    
    # Clear temporary files
    Write-InfoLog "Clearing temporary files..."
    $tempPaths = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Prefetch\*"
    )
    
    foreach ($path in $tempPaths) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-DebugLog "Cleared: $path"
        } catch {
            Write-DebugLog "Could not clear: $path"
        }
    }
    
    # Clear event logs (optional)
    Write-InfoLog "Clearing event logs..."
    $logNames = Get-EventLog -List | Select-Object -ExpandProperty Log
    foreach ($logName in $logNames) {
        try {
            Clear-EventLog -LogName $logName -ErrorAction SilentlyContinue
            Write-DebugLog "Cleared event log: $logName"
        } catch {
            Write-DebugLog "Could not clear event log: $logName"
        }
    }
    
    # Run disk cleanup
    Write-InfoLog "Running disk cleanup..."
    try {
        # Clean up Windows component store
        Start-Process -FilePath "dism.exe" `
                      -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /ResetBase" `
                      -Wait `
                      -NoNewWindow `
                      -ErrorAction SilentlyContinue
        Write-InfoLog "Disk cleanup completed"
    } catch {
        Write-WarnLog "Disk cleanup may not have completed: $($_.Exception.Message)"
    }
    
    # Disable WinRM for security (will be re-enabled if needed)
    Write-InfoLog "Configuring WinRM for template..."
    try {
        # Note: We keep WinRM enabled for now as it may be needed for stembuild
        # If you want to disable it, uncomment the following:
        # Stop-Service -Name WinRM -Force -ErrorAction SilentlyContinue
        # Set-Service -Name WinRM -StartupType Disabled -ErrorAction SilentlyContinue
        Write-InfoLog "WinRM configuration complete"
    } catch {
        Write-WarnLog "Could not configure WinRM: $($_.Exception.Message)"
    }
    
    # Final system information
    Write-InfoLog "Final system state:"
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-InfoLog "  C: Drive Free Space: $([math]::Round($disk.FreeSpace / 1GB, 2)) GB"
    Write-InfoLog "  C: Drive Total Space: $([math]::Round($disk.Size / 1GB, 2)) GB"
    
    Write-InfoLog "Final cleanup provisioner completed successfully"
    
} catch {
    Write-ErrorLog "Error during final cleanup: $($_.Exception.Message)"
    Write-ErrorLog $_.ScriptStackTrace
    Write-WarnLog "Continuing despite cleanup errors"
}

Set-BuildSuccess -Step "FinalCleanup"
Set-BuildStatus -Step "BuildComplete" -Status "Completed" -Progress 100 -Message "Build completed successfully. VM ready for template conversion."
Write-InfoLog "Build preparation complete. VM is ready to be converted to template."
