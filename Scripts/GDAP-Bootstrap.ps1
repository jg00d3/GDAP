<#
    GDAP-Bootstrap.ps1
    Auto-Unblock + Auto-Update + Menu Launcher
#>

param(
    [switch]$Update
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


# --------------------------- MENU SYSTEM ---------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "         GDAP Toolkit" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Run GDAP Export" -ForegroundColor White
    Write-Host "2. Exit" -ForegroundColor White
    Write-Host ""
    return Read-Host "Select an option (1-2)"
}


# MAIN MENU LOOP
while ($true) {

    $choice = Show-MainMenu

    switch ($choice) {

        "1" {
            $ExportScript = Join-Path $ScriptPath "GDAP-Export.ps1"

            if (-not (Test-Path $ExportScript)) {
                Write-Host "[Bootstrap][ERROR] GDAP-Export.ps1 not found." -ForegroundColor Red
                pause
                continue
            }

            Write-Host "`n[Bootstrap] Running GDAP-Export.ps1…" -ForegroundColor Cyan
            & $ExportScript
            pause
        }

        "2" {
            Write-Host "Exiting. Goodbye!" -ForegroundColor Cyan
            exit
        }

        default {
            Write-Host "Invalid selection. Try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
