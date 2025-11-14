<#
    GDAP-Export.ps1
    Runs the actual GDAP export after Bootstrap handles updates.
#>

param(
    [string]$Status = "Active",
    [string]$Detail = "Full",
    [string]$Output = "All",
    [string]$OutputFolder = "$PSScriptRoot\Export"
)

Write-Host "[GDAP Export] Starting…" -ForegroundColor Cyan

# Load dependencies — NOT bootstrap
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$ScriptPath\GDAP-Graph.ps1"
. "$ScriptPath\GDAP-Data.ps1"
. "$ScriptPath\GDAP-Output.ps1"

# Ensure output folder exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Run the export
Start-GdapExport -Status $Status -Detail $Detail -Output $Output -OutputFolder $OutputFolder

Write-Host "[GDAP Export] Complete!" -ForegroundColor Green
