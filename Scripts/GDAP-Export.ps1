<#
.GDAP Export Main Script
Runs the GDAP export using the loaded modules.
#>

param(
    [string]$Status = "Active",
    [string]$Detail = "Full",
    [string]$Output = "All",
    [string]$OutputFolder = "C:\Scripts"
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Bootstrap first (ensures update check)
$bootstrap = Join-Path $ScriptRoot "GDAP-Bootstrap.ps1"
if (Test-Path $bootstrap) {
    . $bootstrap
} else {
    Write-Error "Bootstrap loader missing. Cannot continue."
    exit
}

# Confirm modules loaded
if (-not (Get-Command New-GdapSession -ErrorAction SilentlyContinue)) {
    Write-Error "GDAP modules failed to load. Aborting."
    exit
}

# Run export
Write-Host "[GDAP Export] Starting export..." -ForegroundColor Cyan
Start-GdapExport -Status $Status -Detail $Detail -Output $Output -OutputFolder $OutputFolder
Write-Host "[GDAP Export] Completed." -ForegroundColor Green
