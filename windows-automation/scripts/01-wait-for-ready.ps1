# Wait for Windows to be fully ready after installation
# This script ensures all services are started and the system is ready for provisioning

. "$PSScriptRoot\00-common.ps1"

Set-BuildStatus -Step "WaitForReady" -Status "Running" -Progress 10
Write-InfoLog "Starting wait-for-ready provisioner"
Write-InfoLog "Waiting for Windows to be fully ready..."

# Wait for network to be available
$maxRetries = 60
$retryCount = 0
$networkReady = $false

while ($retryCount -lt $maxRetries -and -not $networkReady) {
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if ($adapters) {
            $networkReady = $true
            Write-InfoLog "Network adapter is ready"
        } else {
            Start-Sleep -Seconds 5
            $retryCount++
            Write-DebugLog "Waiting for network adapter... ($retryCount/$maxRetries)"
        }
    } catch {
        Start-Sleep -Seconds 5
        $retryCount++
        Write-DebugLog "Network check failed, retrying... ($retryCount/$maxRetries)"
    }
}

if (-not $networkReady) {
    Write-WarnLog "Network adapter may not be fully ready, continuing anyway"
}

# Wait for Windows Update service
Write-InfoLog "Waiting for Windows Update service to be ready..."
$maxRetries = 30
$retryCount = 0

while ($retryCount -lt $maxRetries) {
    try {
        $wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($wuService -and $wuService.Status -eq "Running") {
            Write-InfoLog "Windows Update service is running"
            break
        }
    } catch {
        # Service may not exist yet
    }
    Start-Sleep -Seconds 2
    $retryCount++
}

# Wait for WinRM to be fully functional
Write-InfoLog "Verifying WinRM is ready..."
Start-Sleep -Seconds 10

# Verify system is ready
Write-InfoLog "System information:"
Write-InfoLog "  Computer Name: $env:COMPUTERNAME"
Write-InfoLog "  OS Version: $((Get-CimInstance Win32_OperatingSystem).Version)"
Write-InfoLog "  Total Memory: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)) GB"

Set-BuildSuccess -Step "WaitForReady"
Write-InfoLog "Wait-for-ready provisioner completed successfully"
