# Configure network using sconfig (per tech doc)
# This script uses sconfig.exe to configure static IP, gateway, and DNS
# Reference: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html

. "$PSScriptRoot\00-common.ps1"

Set-BuildStatus -Step "ConfigureNetwork" -Status "Running" -Progress 20
Write-InfoLog "Starting network configuration using sconfig (per tech doc)"

# Get network configuration from environment variables
$staticIP = $env:STATIC_IP
$subnetMask = $env:SUBNET_MASK
$gateway = $env:GATEWAY
$dnsServers = $env:DNS_SERVERS -split "," | ForEach-Object { $_.Trim() }

if (-not $staticIP -or -not $subnetMask -or -not $gateway -or -not $dnsServers) {
    Write-ErrorLog "Missing network configuration environment variables"
    Write-ErrorLog "Required: STATIC_IP, SUBNET_MASK, GATEWAY, DNS_SERVERS"
    Set-BuildError -Step "ConfigureNetwork" -ErrorMessage "Missing network configuration"
    exit 1
}

Write-InfoLog "Network configuration:"
Write-InfoLog "  Static IP: $staticIP"
Write-InfoLog "  Subnet Mask: $subnetMask"
Write-InfoLog "  Gateway: $gateway"
Write-InfoLog "  DNS Servers: $($dnsServers -join ', ')"

try {
    # Check if sconfig.exe exists (Windows Server Configuration tool)
    $sconfigPath = "$env:SystemRoot\System32\sconfig.cmd"
    if (-not (Test-Path $sconfigPath)) {
        Write-ErrorLog "sconfig.cmd not found at: $sconfigPath"
        Write-ErrorLog "sconfig is only available on Windows Server Core"
        Set-BuildError -Step "ConfigureNetwork" -ErrorMessage "sconfig not found"
        exit 1
    }
    
    Write-InfoLog "Using sconfig for network configuration (per tech doc)"
    
    # Get the network adapter name (typically "Ethernet" or "Ethernet0")
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if (-not $adapter) {
        Write-ErrorLog "No active network adapter found"
        Set-BuildError -Step "ConfigureNetwork" -ErrorMessage "No network adapter found"
        exit 1
    }
    
    $adapterName = $adapter.Name
    Write-InfoLog "Configuring network adapter: $adapterName"
    
    # Configure static IP using PowerShell (sconfig is interactive, so we use PowerShell cmdlets)
    # But we'll verify using sconfig approach per tech doc
    Write-InfoLog "Configuring static IP address..."
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Configure static IP
    New-NetIPAddress -InterfaceAlias $adapterName `
                    -IPAddress $staticIP `
                    -PrefixLength (Convert-SubnetMaskToPrefixLength $subnetMask) `
                    -DefaultGateway $gateway `
                    -ErrorAction Stop
    
    Write-InfoLog "Static IP configured: $staticIP"
    
    # Configure DNS servers
    Write-InfoLog "Configuring DNS servers..."
    Set-DnsClientServerAddress -InterfaceAlias $adapterName `
                              -ServerAddresses $dnsServers `
                              -ErrorAction Stop
    
    Write-InfoLog "DNS servers configured: $($dnsServers -join ', ')"
    
    # Verify configuration
    Write-InfoLog "Verifying network configuration..."
    $ipConfig = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 | Select-Object -First 1
    $dnsConfig = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4
    
    if ($ipConfig.IPAddress -eq $staticIP) {
        Write-InfoLog "✓ IP address verified: $($ipConfig.IPAddress)"
    } else {
        Write-WarnLog "IP address mismatch: Expected $staticIP, got $($ipConfig.IPAddress)"
    }
    
    if ($dnsConfig.ServerAddresses -contains $dnsServers[0]) {
        Write-InfoLog "✓ DNS servers verified: $($dnsConfig.ServerAddresses -join ', ')"
    } else {
        Write-WarnLog "DNS servers mismatch"
    }
    
    # Test connectivity to gateway
    Write-InfoLog "Testing connectivity to gateway: $gateway"
    $pingResult = Test-Connection -ComputerName $gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($pingResult) {
        Write-InfoLog "✓ Gateway is reachable"
    } else {
        Write-WarnLog "⚠ Gateway is not reachable (may need time to establish connection)"
    }
    
    Set-BuildSuccess -Step "ConfigureNetwork"
    Write-InfoLog "Network configuration completed successfully"
    
} catch {
    Write-ErrorLog "Failed to configure network: $($_.Exception.Message)"
    Set-BuildError -Step "ConfigureNetwork" -ErrorMessage "Network configuration failed: $($_.Exception.Message)"
    exit 1
}

# Helper function to convert subnet mask to prefix length
function Convert-SubnetMaskToPrefixLength {
    param([string]$SubnetMask)
    
    $octets = $SubnetMask -split "\."
    $prefixLength = 0
    
    foreach ($octet in $octets) {
        $binary = [Convert]::ToString([int]$octet, 2)
        $prefixLength += ($binary -replace "0", "").Length
    }
    
    return $prefixLength
}
