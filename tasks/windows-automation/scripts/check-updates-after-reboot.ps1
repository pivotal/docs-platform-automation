# Check for Pending Updates After Reboot
$ErrorActionPreference = "Stop"

# Logging - write to stdout so output is captured in Concourse
$LogFile = "$env:TEMP\check-updates-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    try {
        Add-Content -Path $LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=========================================="
Write-Log "Check Updates After Reboot"
Write-Log "=========================================="

# Wait for system
Start-Sleep -Seconds 10

# Create Windows Update Session
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

# Search for pending updates
Write-Log "Searching for pending updates..."
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

if ($SearchResult.Updates.Count -eq 0) {
    Write-Log "No pending updates - system is up to date"
    exit 0
}

Write-Log "Found $($SearchResult.Updates.Count) pending update(s)"
foreach ($Update in $SearchResult.Updates) {
    Write-Log "  - $($Update.Title)"
}

Write-Log "Updates are pending"
exit 1
