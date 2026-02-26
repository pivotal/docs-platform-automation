# Optimized Windows Update Script
$ErrorActionPreference = "Stop"
$LogFile = "$env:TEMP\windows-updates-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message)
    $logMessage = "$($(Get-Date -Format 'HH:mm:ss')) $Message"
    Write-Host $logMessage
    $logMessage | Out-File -FilePath $LogFile -Append
}

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

Write-Log "Searching for updates..."
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")
if ($SearchResult.Updates.Count -eq 0) {
    Write-Log "System up to date."
    exit 0
}

$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($Update in $SearchResult.Updates) {
    if (!$Update.EulaAccepted) { $Update.AcceptEula() }
    $UpdatesToInstall.Add($Update) | Out-Null
}

# Download Phase
Write-Log "Downloading $($UpdatesToInstall.Count) updates..."
$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToInstall
$Downloader.Download()

# Install Phase with Retry Logic
$MaxRetries = 2
$CurrentRetry = 0
$Success = $false

while ($CurrentRetry -le $MaxRetries -and !$Success) {
    Write-Log "Installation Attempt $($CurrentRetry + 1)..."
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallResult = $Installer.Install()
    
    # ResultCode 2 = Succeeded, 3 = Succeeded with Errors
    if ($InstallResult.ResultCode -eq 2 -or $InstallResult.ResultCode -eq 3) {
        $Success = $true
    } else {
        Write-Log "Warning: Installation failed with code $($InstallResult.ResultCode). Retrying in 30s..."
        Start-Sleep -Seconds 30
        $CurrentRetry++
    }
}

# Final Reporting
for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {
    $status = $InstallResult.GetUpdateResult($i).ResultCode
    $title = $UpdatesToInstall.Item($i).Title
    Write-Log "Update: $title - Status Code: $status"
}

if ($InstallResult.RebootRequired) {
    Write-Log "REBOOT_REQUIRED"
    exit 3010  # Standard Windows Reboot Required code
}

exit 0