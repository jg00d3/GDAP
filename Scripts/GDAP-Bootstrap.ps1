<#
    GDAP-Bootstrap.ps1
    Auto-Updater, Auto-Unblocker, and Launcher for the GDAP Toolkit
#>

param(
    [switch]$Update,
    [switch]$RunExport,
    [string]$Status,
    [string]$Detail,
    [string]$Output,
    [string]$OutputFolder
)

# --------------------------- CONFIG ---------------------------
$ScriptPath  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RemoteRoot  = "https://raw.githubusercontent.com/jg00d3/GDAP/main/Scripts"
$FilesToManage = @(
    "GDAP-Bootstrap.ps1",
    "GDAP-Export.ps1",
    "GDAP-Modules.ps1",
    "GDAP-Graph.ps1",
    "GDAP-Data.ps1",
    "GDAP-Output.ps1",
    "version.txt"
)

Write-Host "[Bootstrap] Starting…" -ForegroundColor Cyan


# --------------------------- AUTO-UNBLOCK ---------------------------
function Unblock-GdapFile {
    param([string]$FileName)

    $Full = Join-Path $ScriptPath $FileName
    $Zone = "$Full:Zone.Identifier"

    if (Test-Path $Zone) {
        try {
            Remove-Item $Zone -Force
            Write-Host "[Bootstrap] Unblocked $FileName (was blocked)" -ForegroundColor Yellow
        }
        catch {
            Write-Host "[Bootstrap][WARN] Could not unblock $FileName : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Auto-unblock *only* the GDAP files
foreach ($file in $FilesToManage) {
    Unblock-GdapFile -FileName $file
}


# --------------------------- VERSION CHECK ---------------------------
$LocalVersionFile = Join-Path $ScriptPath "version.txt"
$LocalVersion = "0.0.0"

if (Test-Path $LocalVersionFile) {
    $LocalVersion = (Get-Content $LocalVersionFile | Select-Object -First 1).Trim()
}

$RemoteVersion = (Invoke-WebRequest "$RemoteRoot/version.txt" -UseBasicParsing).Content.Trim()

Write-Host "[Bootstrap] Local Version : $LocalVersion"
Write-Host "[Bootstrap] Remote Version: $RemoteVersion"


# Update needed?
$DoUpdate = $Update -or ($LocalVersion -ne $RemoteVersion)

if ($DoUpdate) {
    Write-Host "`n[UPDATE] Downloading script updates..." -ForegroundColor Green

    foreach ($file in $FilesToManage) {
        $remote = "$RemoteRoot/$file"
        $local  = Join-Path $ScriptPath $file

        try {
            Invoke-WebRequest $remote -OutFile $local -UseBasicParsing -ErrorAction Stop
            Write-Host "[OK] Updated $file" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to update $file : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n[UPDATE] Complete." -ForegroundColor Green
}
else {
    Write-Host "[Bootstrap] Everything is up to date."
}


# --------------------------- AUTO-UNBLOCK AGAIN AFTER UPDATE ---------------------------
foreach ($file in $FilesToManage) {
    Unblock-GdapFile -FileName $file
}


# --------------------------- LOAD MODULE HELPERS ---------------------------
$ModulesPath = Join-Path $ScriptPath "GDAP-Modules.ps1"
if (Test-Path $ModulesPath) {
    . $ModulesPath
    Write-Host "[Load] Imported GDAP-Modules.ps1"
}
else {
    Write-Host "[Bootstrap][ERROR] GDAP-Modules.ps1 missing — cannot continue." -ForegroundColor Red
    exit
}


# --------------------------- OPTIONAL: RUN EXPORT ---------------------------
if ($RunExport) {

    $ExportScript = Join-Path $ScriptPath "GDAP-Export.ps1"
    if (-not (Test-Path $ExportScript)) {
        Write-Host "[Bootstrap][ERROR] GDAP-Export.ps1 not found." -ForegroundColor Red
        exit
    }

    Write-Host "[Bootstrap] Running GDAP-Export.ps1…" -ForegroundColor Cyan

    # Build argument list dynamically to forward parameters
    $argsList = @()
    if ($Status)       { $argsList += "-Status `"$Status`"" }
    if ($Detail)       { $argsList += "-Detail `"$Detail`"" }
    if ($Output)       { $argsList += "-Output `"$Output`"" }
    if ($OutputFolder) { $argsList += "-OutputFolder `"$OutputFolder`"" }

    & $ExportScript @argsList
    exit
}

Write-Host "[Bootstrap] Update check complete. No further action requested."
