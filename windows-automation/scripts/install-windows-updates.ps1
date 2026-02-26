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
# Accept EULAs first
foreach ($Update in $UpdatesToInstall) {
    if (-not $Update.EulaAccepted) {
        Write-Log "Accepting EULA for: $($Update.Title)"
        $Update.AcceptEula()
    }
}

# Install updates
Write-Log "Installing updates..."
$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallResult = $Installer.Install()

# Detailed Logging: Loop through each update to see which one failed
for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {
    $status = $InstallResult.GetUpdateResult($i).ResultCode
    $title = $UpdatesToInstall.Item($i).Title
    Write-Log "Update: $title - Result Code: $status"
}

# Flexible Exit Logic
if ($InstallResult.ResultCode -eq 2 -or $InstallResult.ResultCode -eq 3) {
    if ($InstallResult.RebootRequired) {
        Write-Log "Installation complete, but REBOOT IS REQUIRED."
        exit 0 # Or use a specific exit code like 3010 to tell govc a reboot is needed
    }
    Write-Log "Updates finished (Result: $($InstallResult.ResultCode))"
    exit 0
} else {
    Write-Log "Installation failed with Result Code: $($InstallResult.ResultCode)"
    exit 1
}

Write-Log "Updates installed successfully"
Write-Log "VM will be shut down by the automation script"
exit 0
