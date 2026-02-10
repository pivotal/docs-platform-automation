# Common logging and utility functions for Packer provisioners

$ErrorActionPreference = "Stop"
$LogLevel = $env:LOG_LEVEL
if (-not $LogLevel) { $LogLevel = "INFO" }
$LogDir = $env:LOG_DIR
if (-not $LogDir) { $LogDir = "C:\packer-logs" }

# Create log directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logMessage
    
    # Write to log file
    $logFile = Join-Path $LogDir "provisioner.log"
    Add-Content -Path $LogFile -Value $logMessage
    
    # Write to appropriate PowerShell stream
    switch ($Level) {
        "ERROR" { Write-Error $Message }
        "WARN"  { Write-Warning $Message }
        default { }
    }
}

function Write-DebugLog {
    param([string]$Message)
    if ($LogLevel -eq "DEBUG") {
        Write-Log -Message $Message -Level "DEBUG"
    }
}

function Write-InfoLog {
    param([string]$Message)
    if ($LogLevel -in @("DEBUG", "INFO")) {
        Write-Log -Message $Message -Level "INFO"
    }
}

function Write-WarnLog {
    param([string]$Message)
    if ($LogLevel -in @("DEBUG", "INFO", "WARN")) {
        Write-Log -Message $Message -Level "WARN"
    }
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Log -Message $Message -Level "ERROR"
}

# Registry-based status tracking for build progress monitoring
# Status is stored in: HKLM:\SOFTWARE\PackerBuild
$StatusRegistryPath = "HKLM:\SOFTWARE\PackerBuild"

function Set-BuildStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Step,
        [Parameter(Mandatory=$false)]
        [string]$Status = "Running",
        [Parameter(Mandatory=$false)]
        [string]$Message = "",
        [Parameter(Mandatory=$false)]
        [int]$Progress = 0
    )
    
    try {
        # Create registry key if it doesn't exist
        if (-not (Test-Path $StatusRegistryPath)) {
            New-Item -Path $StatusRegistryPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Set status values
        Set-ItemProperty -Path $StatusRegistryPath -Name "CurrentStep" -Value $Step -Force
        Set-ItemProperty -Path $StatusRegistryPath -Name "Status" -Value $Status -Force
        Set-ItemProperty -Path $StatusRegistryPath -Name "LastUpdate" -Value $timestamp -Force
        Set-ItemProperty -Path $StatusRegistryPath -Name "Progress" -Value $Progress -Force
        
        if ($Message) {
            Set-ItemProperty -Path $StatusRegistryPath -Name "Message" -Value $Message -Force
        }
        
        Write-InfoLog "Build Status: $Step - $Status ($Progress%)"
    } catch {
        Write-WarnLog "Failed to update build status: $($_.Exception.Message)"
    }
}

function Set-BuildError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Step,
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage
    )
    
    Set-BuildStatus -Step $Step -Status "Failed" -Message $ErrorMessage -Progress 0
    Write-ErrorLog "BUILD FAILED at step: $Step"
    Write-ErrorLog "Error: $ErrorMessage"
    exit 1
}

function Set-BuildSuccess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Step
    )
    
    Set-BuildStatus -Step $Step -Status "Completed" -Message "Step completed successfully" -Progress 100
}

# Fail-fast error handler
function Test-CommandSuccess {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Command,
        [Parameter(Mandatory=$true)]
        [string]$Step,
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage
    )
    
    try {
        $result = & $Command
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Set-BuildError -Step $Step -ErrorMessage "$ErrorMessage (Exit Code: $LASTEXITCODE)"
        }
        return $result
    } catch {
        Set-BuildError -Step $Step -ErrorMessage "$ErrorMessage - $($_.Exception.Message)"
    }
}

# Note: Functions are sourced via dot-sourcing (.) in other scripts
# Export-ModuleMember is not needed when using dot-sourcing
# The functions are available in the current scope when sourced
