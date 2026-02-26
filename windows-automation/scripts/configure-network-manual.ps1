# Configure Network with Static IP and DNS Servers
# Simplified version for reliability

$ErrorActionPreference = "Stop"

# Setup log file on VM
$LogFile = "$env:TEMP\network-config-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
try {
    $LogDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    "Network Configuration Script Started at $(Get-Date)" | Out-File -FilePath $LogFile -Encoding UTF8
} catch {
    $LogFile = $null
}

# Simple logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    [Console]::Out.WriteLine($logMessage)
    if ($LogFile) {
        try {
            Add-Content -Path $LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            # Ignore log errors
        }
    }
}

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Log "=========================================="
Write-Log "Network Configuration Script"
Write-Log "Timestamp: $(Get-Date)"
if ($LogFile) {
    Write-Log "Log file: $LogFile"
}
Write-Log "=========================================="
Write-Log ""

# Get network configuration from environment variables
# The run-powershell-via-govc.sh script controls which variables are passed via PS_ENV_VARS
# This script simply reads the standard network configuration variables
if ($env:STATIC_IP) {
    $staticIP = $env:STATIC_IP
} else {
    $staticIP = ""
}

if ($env:SUBNET_MASK) {
    $subnetMask = $env:SUBNET_MASK
} else {
    $subnetMask = "255.255.255.0"
}

if ($env:GATEWAY) {
    $gateway = $env:GATEWAY
} else {
    $gateway = ""
}

$dnsServers = @()
if ($env:DNS_SERVERS) {
    try {
        $dnsServers = Invoke-Expression $env:DNS_SERVERS
    } catch {
        Write-Warning "Failed to parse DNS_SERVERS: $_"
    }
}

Write-Log "Network Configuration:"
if ($staticIP) {
    Write-Log "  Static IP: $staticIP"
} else {
    Write-Log "  Static IP: NOT SET (will use DHCP)"
}
Write-Log "  Subnet Mask: $subnetMask"
if ($gateway) {
    Write-Log "  Gateway: $gateway"
} else {
    Write-Log "  Gateway: NOT SET"
}
if ($dnsServers.Count -gt 0) {
    Write-Log "  DNS Servers: $($dnsServers -join ', ')"
} else {
    Write-Log "  DNS Servers: NOT SET"
}
Write-Log ""

# Get the active network adapter
Write-Log "Step 1: Getting network adapter..."
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -or $_.Status -eq "Connected" } | Select-Object -First 1

if (-not $adapter) {
    Write-Log "ERROR: No active network adapter found"
    exit 1
}

$adapterName = $adapter.Name
Write-Log "  Found adapter: $adapterName"
Write-Log ""

# Configure Static IP (if provided)
if ($staticIP -and $gateway) {
    Write-Log "Step 2: Configuring Static IP Address..."
    
    # Disable DHCP
    $dhcpInterface = Get-NetIPInterface -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($dhcpInterface -and $dhcpInterface.Dhcp -eq "Enabled") {
        Write-Log "  Disabling DHCP..."
        Set-NetIPInterface -InterfaceAlias $adapterName -Dhcp Disabled
    }
    
    # Remove existing IP configuration
    $existingIPs = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existingIPs) {
        Write-Log "  Removing existing IP addresses..."
        foreach ($ip in $existingIPs) {
            Remove-NetIPAddress -InterfaceAlias $adapterName -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    
    $existingGateway = Get-NetRoute -InterfaceAlias $adapterName -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
    if ($existingGateway) {
        Write-Log "  Removing existing default gateway..."
        Remove-NetRoute -InterfaceAlias $adapterName -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Calculate prefix length (simplified - only handle common cases)
    $prefixLength = 24  # Default
    if ($subnetMask -eq "255.255.0.0") { $prefixLength = 16 }
    elseif ($subnetMask -eq "255.0.0.0") { $prefixLength = 8 }
    elseif ($subnetMask -ne "255.255.255.0") {
        # Try to calculate for other masks
        try {
            $bytes = ([System.Net.IPAddress]$subnetMask).GetAddressBytes()
            $binary = ($bytes | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') }) -join ''
            $prefixLength = ($binary -split '0')[0].Length
        } catch {
            Write-Log "  WARNING: Could not calculate prefix length, using default 24"
            $prefixLength = 24
        }
    }
    
    Write-Log "  Configuring IP: $staticIP/$prefixLength, Gateway: $gateway"
    $ipResult = New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $staticIP -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
    $null = $ipResult  # Suppress output object
    Write-Log "  [OK] Static IP configured successfully"
    Write-Log ""
} else {
    Write-Log 'Step 2: Skipping Static IP configuration (required variables not set)'
    Write-Log ""
}

# Configure DNS Servers (if provided)
if ($dnsServers.Count -gt 0) {
    Write-Log "Step 3: Configuring DNS Servers..."
    Write-Log "  DNS servers to configure: $($dnsServers -join ', ')"
    
    # Reset all DNS servers first (both IPv4 and IPv6)
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses -ErrorAction SilentlyContinue
    
    # Wait a moment for reset to take effect
    Start-Sleep -Seconds 2
    
    # Set IPv4 DNS servers explicitly
    Write-Log "  Setting IPv4 DNS servers..."
    $dnsResult = Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dnsServers -ErrorAction Stop
    $null = $dnsResult  # Suppress output object
    
    # Verify DNS servers were set
    $verifyDns = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($verifyDns -and $verifyDns.ServerAddresses) {
        $dnsList = $verifyDns.ServerAddresses -join ', '
        Write-Log "  [OK] DNS servers configured: $dnsList"
    } else {
        Write-Log "  WARNING: DNS servers may not have been set correctly"
    }
    Write-Log ""
} else {
    Write-Log 'Step 3: Skipping DNS configuration (DNS_SERVERS variable not set)'
    Write-Log ""
}

# Verify configuration
Write-Log "Step 4: Verifying network configuration..."
$finalConfig = Get-NetIPConfiguration -InterfaceAlias $adapterName
$dnsConfig = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue

Write-Log "  Adapter: $($finalConfig.InterfaceAlias)"
Write-Log "  IPv4 Address: $($finalConfig.IPv4Address.IPAddress)"
Write-Log "  Default Gateway: $($finalConfig.IPv4DefaultGateway.NextHop)"
if ($dnsConfig -and $dnsConfig.ServerAddresses) {
    $dnsListFinal = $dnsConfig.ServerAddresses -join ', '
    Write-Log "  IPv4 DNS Servers: $dnsListFinal"
} else {
    Write-Log "  IPv4 DNS Servers: NOT CONFIGURED"
}
Write-Log ""

Write-Log "=========================================="
Write-Log "Network configuration completed successfully"
Write-Log "Timestamp: $(Get-Date)"
Write-Log "=========================================="

exit 0
