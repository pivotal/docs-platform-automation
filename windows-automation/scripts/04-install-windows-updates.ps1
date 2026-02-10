# Install Windows Updates (Step 2 from documentation)
# This script installs all available Windows updates using Windows Update
# NOTE: Network must be configured (Step 2) BEFORE this script runs

. "$PSScriptRoot\00-common.ps1"

Set-BuildStatus -Step "InstallWindowsUpdates" -Status "Running" -Progress 50
Write-InfoLog "Starting Windows Updates installation provisioner"
Write-InfoLog "Verifying network connectivity (network should be configured in previous step)..."

$enableUpdates = $env:ENABLE_UPDATES
if ($enableUpdates -eq "false") {
    Write-InfoLog "Windows updates are disabled, skipping"
    Set-BuildStatus -Step "InstallWindowsUpdates" -Status "Skipped" -Progress 50
    exit 0
}

# Verify network connectivity before attempting updates
$staticIp = $env:STATIC_IP
$gateway = $env:GATEWAY

if ($staticIp) {
    Write-InfoLog "Verifying network configuration..."
    
    # Check if static IP is configured
    $ipConfig = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $staticIp }
    if (-not $ipConfig) {
        Set-BuildError -Step "InstallWindowsUpdates" -ErrorMessage "Static IP $staticIp is not configured. Network configuration must complete before Windows updates."
    }
    Write-InfoLog "Static IP $staticIp is configured correctly"
    
    # Test connectivity to gateway
    if ($gateway) {
        Write-InfoLog "Testing connectivity to gateway: $gateway"
        $pingResult = Test-Connection -ComputerName $gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
        if (-not $pingResult) {
            Write-WarnLog "Could not ping gateway: $gateway"
            Write-WarnLog "Network connectivity may be limited, but continuing with updates..."
        } else {
            Write-InfoLog "Gateway connectivity verified"
        }
    }
    
    # Test DNS resolution
    Write-InfoLog "Testing DNS resolution..."
    try {
        $dnsTest = Resolve-DnsName -Name "microsoft.com" -ErrorAction Stop
        Write-InfoLog "DNS resolution working correctly"
    } catch {
        Set-BuildError -Step "InstallWindowsUpdates" -ErrorMessage "DNS resolution failed. Cannot download Windows updates without DNS."
    }
    
    # Test internet connectivity
    Write-InfoLog "Testing internet connectivity..."
    try {
        $webTest = Invoke-WebRequest -Uri "http://www.microsoft.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-InfoLog "Internet connectivity verified - ready to download Windows updates"
    } catch {
        Write-WarnLog "Could not reach internet. Windows updates may fail if internet access is required."
        Write-WarnLog "Continuing anyway - updates may use WSUS or local sources if configured..."
    }
} else {
    Write-WarnLog "No static IP configured - using DHCP. Network should be configured via DHCP."
}

try {
    # Install PSWindowsUpdate module if not present
    Write-InfoLog "Checking for PSWindowsUpdate module..."
    $module = Get-Module -ListAvailable -Name PSWindowsUpdate
    
    if (-not $module) {
        Write-InfoLog "PSWindowsUpdate module not found, installing..."
        
        # Set execution policy for current process
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Install module
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck
        Write-InfoLog "PSWindowsUpdate module installed"
    } else {
        Write-InfoLog "PSWindowsUpdate module found (Version: $($module.Version))"
    }
    
    # Import module
    Import-Module PSWindowsUpdate -Force
    Write-InfoLog "PSWindowsUpdate module imported"
    
    # Check for updates
    Write-InfoLog "Checking for Windows Updates..."
    $updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
    
    if ($null -eq $updates -or $updates.Count -eq 0) {
        Write-InfoLog "No Windows updates available"
        exit 0
    }
    
    Write-InfoLog "Found $($updates.Count) Windows update(s) available"
    
    # Install all updates with automatic reboot
    Write-InfoLog "Installing all Windows updates (this may take a long time)..."
    Write-InfoLog "The system may reboot multiple times during update installation"
    
    $maxIterations = 10
    $iteration = 0
    $allUpdatesInstalled = $false
    
    while ($iteration -lt $maxIterations -and -not $allUpdatesInstalled) {
        $iteration++
        Write-InfoLog "Update iteration $iteration of $maxIterations"
        
        # Check for pending updates
        $pendingUpdates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        
        if ($null -eq $pendingUpdates -or $pendingUpdates.Count -eq 0) {
            Write-InfoLog "All updates installed successfully"
            $allUpdatesInstalled = $true
            break
        }
        
        Write-InfoLog "$($pendingUpdates.Count) update(s) still pending"
        
        # Install updates
        try {
            Install-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$false -ErrorAction Stop
            Write-InfoLog "Update installation initiated, waiting for completion..."
            
            # Wait a bit for updates to start
            Start-Sleep -Seconds 30
            
            # Note: If reboot occurs, Packer will reconnect and this script will run again
            # The iteration counter will help prevent infinite loops
            
        } catch {
            Write-WarnLog "Error during update installation: $($_.Exception.Message)"
            Write-WarnLog "Updates may still be installing in the background"
        }
        
        # Wait before next check
        Start-Sleep -Seconds 60
    }
    
    if (-not $allUpdatesInstalled) {
        Write-WarnLog "Maximum iterations reached. Some updates may still be pending."
        Write-WarnLog "You may need to run Windows Update again after the build completes"
    } else {
        Write-InfoLog "All Windows updates have been installed"
    }
    
    # Final check
    $finalUpdates = Get-WindowsUpdate -ErrorAction SilentlyContinue
    if ($null -eq $finalUpdates -or $finalUpdates.Count -eq 0) {
        Set-BuildSuccess -Step "InstallWindowsUpdates"
        Write-InfoLog "Windows Updates installation provisioner completed successfully"
    } else {
        Set-BuildStatus -Step "InstallWindowsUpdates" -Status "Completed" -Progress 50 -Message "$($finalUpdates.Count) update(s) may still be pending"
        Write-WarnLog "$($finalUpdates.Count) update(s) may still be pending"
    }
    
} catch {
    Set-BuildError -Step "InstallWindowsUpdates" -ErrorMessage "Failed to install Windows Updates: $($_.Exception.Message)"
}

Write-InfoLog "Windows Updates installation provisioner completed"
