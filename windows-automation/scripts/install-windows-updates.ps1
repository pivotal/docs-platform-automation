# Install Windows Updates and Shutdown
$ErrorActionPreference = "Stop"

# Logging
$LogFile = "$env:TEMP\windows-updates-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    try {
        Add-Content -Path $LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=========================================="
Write-Log "Windows Updates Installation"
Write-Log "=========================================="

# Create Windows Update Session
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

# Search for updates
Write-Log "Searching for updates..."
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

if ($SearchResult.Updates.Count -eq 0) {
    Write-Log "No updates available"
    exit 0
}

Write-Log "Found $($SearchResult.Updates.Count) update(s)"

# Download updates
Write-Log "Downloading updates..."
$UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($Update in $SearchResult.Updates) {
    $UpdatesToDownload.Add($Update) | Out-Null
}

$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$DownloadResult = $Downloader.Download()

if ($DownloadResult.ResultCode -ne 2) {
    Write-Log "Download failed or incomplete"
    exit 1
}

Write-Log "Downloads completed"

# Install updates
Write-Log "Installing updates..."
$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($Update in $SearchResult.Updates) {
    if ($Update.IsDownloaded) {
        $UpdatesToInstall.Add($Update) | Out-Null
    }
}

$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallResult = $Installer.Install()

Write-Log "Installation result: $($InstallResult.ResultCode)"
Write-Log "Reboot required: $($InstallResult.RebootRequired)"

if ($InstallResult.ResultCode -ne 2) {
    Write-Log "Installation may have issues"
    exit 1
}

Write-Log "Updates installed successfully"
Write-Log "VM will be shut down by the automation script"
exit 0
