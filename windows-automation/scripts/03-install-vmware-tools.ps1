# Install VMware Tools (Step 1.5 from documentation)
# Per documentation: VMware Tools is mounted on D: drive and setup64.exe should be run
# Reference: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html

. "$PSScriptRoot\00-common.ps1"

Set-BuildStatus -Step "InstallVMwareTools" -Status "Running" -Progress 30
Write-InfoLog "Starting VMware Tools installation provisioner (Step 1.5)"
Write-InfoLog "Per documentation: VMware Tools should be on D: drive"

try {
    # Check if VMware Tools is already installed and running
    $vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
    if ($vmwareTools -and $vmwareTools.Status -eq "Running") {
        Write-InfoLog "VMware Tools is already installed and running"
        Write-InfoLog "Service Status: $($vmwareTools.Status)"
        exit 0
    }
    
    # Per documentation: VMware Tools is on D: drive
    # Step 1.5 from documentation: 
    #   "In the vSphere Web Client, right-click the base VM and select Guest OS > Install VMware Tools"
    #   "Click Mount"
    #   "Navigate to the D: drive and run setup64.exe"
    Write-InfoLog "Checking D: drive for VMware Tools (as per documentation Step 1.5)..."
    Write-InfoLog "Per documentation: VMware Tools should be mounted on D: drive"
    
    # Wait for VMware Tools to be mounted on D: drive
    # Packer should mount it automatically, but we wait to ensure it's available
    Write-InfoLog "Waiting for VMware Tools to be mounted on D: drive..."
    $maxWait = 60  # Wait up to 2 minutes for VMware Tools to be mounted
    $waitCount = 0
    $dDrive = "D:"
    $setupPath = "$dDrive\setup64.exe"
    
    # First, check if D: drive exists
    $dDriveExists = Test-Path $dDrive
    if (-not $dDriveExists) {
        Write-WarnLog "D: drive does not exist yet, waiting for VMware Tools to be mounted..."
    }
    
    while ($waitCount -lt $maxWait) {
        if (Test-Path $setupPath) {
            Write-InfoLog "VMware Tools installer found on D: drive: $setupPath"
            break
        }
        
        # Check if D: drive exists but setup64.exe is not there yet
        if (Test-Path $dDrive) {
            $dDriveContents = Get-ChildItem -Path $dDrive -ErrorAction SilentlyContinue
            Write-DebugLog "D: drive exists but setup64.exe not found. Contents: $($dDriveContents.Name -join ', ')"
        }
        
        Write-DebugLog "Waiting for VMware Tools on D: drive... ($waitCount/$maxWait seconds)"
        Start-Sleep -Seconds 2
        $waitCount++
    }
    
    if (Test-Path $setupPath) {
        Write-InfoLog "Found VMware Tools installer on D: drive: $setupPath"
        Write-InfoLog "Installing VMware Tools from D: drive (per documentation)..."
        
        # Change to D: drive directory
        Push-Location $dDrive
        
        try {
            # Run setup64.exe with silent installation (per documentation)
            # Per documentation: "run setup64.exe" from D: drive
            # /S = Silent mode (no user interaction)
            # /v"/qn REBOOT=R" = Quiet mode with no UI, reboot if required
            Write-InfoLog "Executing setup64.exe from D: drive (per documentation Step 1.5)..."
            Write-InfoLog "Command: setup64.exe /S /v`"/qn REBOOT=R`""
            
            # Verify setup64.exe exists before running
            if (-not (Test-Path "setup64.exe")) {
                Write-ErrorLog "setup64.exe not found in current directory: $(Get-Location)"
                exit 1
            }
            
            Write-InfoLog "Current directory: $(Get-Location)"
            Write-InfoLog "Running setup64.exe..."
            
            $installProcess = Start-Process -FilePath "setup64.exe" `
                                            -ArgumentList "/S", "/v`"/qn REBOOT=R`"" `
                                            -Wait `
                                            -PassThru `
                                            -NoNewWindow `
                                            -WorkingDirectory $dDrive
            
            Write-InfoLog "Installation process completed with exit code: $($installProcess.ExitCode)"
            
            # Exit codes:
            # 0 = Success
            # 3010 = Success but reboot required
            if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
                Write-InfoLog "VMware Tools installation completed successfully"
                
                if ($installProcess.ExitCode -eq 3010) {
                    Write-InfoLog "Reboot required to complete installation"
                    Write-InfoLog "Packer will handle the reboot and reconnect"
                }
                
                # Wait for service to be available (may take time after installation)
                Write-InfoLog "Waiting for VMware Tools service to be available..."
                $maxRetries = 60  # Increased wait time
                $retryCount = 0
                $serviceFound = $false
                
                while ($retryCount -lt $maxRetries) {
                    $vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
                    if ($vmwareTools) {
                        $serviceFound = $true
                        Write-InfoLog "VMware Tools service found. Status: $($vmwareTools.Status)"
                        
                        if ($vmwareTools.Status -eq "Running") {
                            Write-InfoLog "VMware Tools service is running"
                            break
                        } elseif ($vmwareTools.Status -eq "Stopped") {
                            Write-InfoLog "VMware Tools service is stopped, attempting to start..."
                            try {
                                Start-Service -Name "VMTools" -ErrorAction Stop
                                Write-InfoLog "VMware Tools service started successfully"
                                break
                            } catch {
                                Write-DebugLog "Could not start service yet, waiting... ($retryCount/$maxRetries)"
                            }
                        }
                    }
                    
                    Start-Sleep -Seconds 3
                    $retryCount++
                    
                    if ($retryCount % 10 -eq 0) {
                        Write-InfoLog "Still waiting for VMware Tools service... ($retryCount/$maxRetries)"
                    }
                }
                
                if ($serviceFound) {
                    $vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
                    if ($vmwareTools -and $vmwareTools.Status -eq "Running") {
                        Write-InfoLog "VMware Tools installation provisioner completed successfully"
                        Write-InfoLog "Service is running and ready"
                    } else {
                        Write-WarnLog "VMware Tools service exists but is not running"
                        Write-WarnLog "Service may start after reboot if required"
                    }
                } else {
                    Write-WarnLog "VMware Tools service not found after installation"
                    Write-WarnLog "Installation may have completed but service requires reboot"
                }
                
            } else {
                Set-BuildError -Step "InstallVMwareTools" -ErrorMessage "VMware Tools installation failed with exit code: $($installProcess.ExitCode)"
            }
            
        } finally {
            Pop-Location
        }
        
    } else {
        # D: drive not found, check other CD/DVD drives
        Write-InfoLog "VMware Tools not found on D: drive, checking other CD/DVD drives..."
        
        $cdDrives = Get-Volume | Where-Object { $_.DriveType -eq "CD-ROM" -and $_.DriveLetter }
        
        if ($cdDrives) {
            Write-InfoLog "Found CD/DVD drive(s): $($cdDrives.DriveLetter -join ', ')"
            
            foreach ($drive in $cdDrives) {
                $driveLetter = $drive.DriveLetter + ":"
                Write-DebugLog "Checking drive $driveLetter for VMware Tools..."
                
                if (Test-Path "$driveLetter\setup64.exe") {
                    Write-InfoLog "Found VMware Tools installer on $driveLetter (fallback from D:)"
                    Write-InfoLog "Installing VMware Tools from $driveLetter..."
                    
                    Push-Location $driveLetter
                    try {
                        $installProcess = Start-Process -FilePath "setup64.exe" `
                                                        -ArgumentList "/S", "/v`"/qn REBOOT=R`"" `
                                                        -Wait `
                                                        -PassThru `
                                                        -NoNewWindow `
                                                        -WorkingDirectory $driveLetter
                        
                        if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
                            Write-InfoLog "VMware Tools installation completed (Exit Code: $($installProcess.ExitCode))"
                            # Wait for service similar to above
                            Start-Sleep -Seconds 10
                            $vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
                            if ($vmwareTools -and $vmwareTools.Status -eq "Running") {
                                Write-InfoLog "VMware Tools service is running"
                                exit 0
                            }
                        }
                    } finally {
                        Pop-Location
                    }
                }
            }
        }
        
        # If we get here, VMware Tools was not found
        Set-BuildError -Step "InstallVMwareTools" -ErrorMessage "VMware Tools ISO not found on D: drive or any CD/DVD drives. Ensure VMware Tools is mounted via vSphere Web Client."
    }
    
    Set-BuildSuccess -Step "InstallVMwareTools"
} catch {
    Set-BuildError -Step "InstallVMwareTools" -ErrorMessage "Failed to install VMware Tools: $($_.Exception.Message)"
}

Write-InfoLog "VMware Tools installation provisioner completed"
