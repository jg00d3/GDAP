<#
.GDAP Bootstrap Loader
Loads local scripts, checks GitHub for updates, and optionally updates on demand.
#>

param(
    [switch]$Update
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ================================
# GitHub Paths (Raw URLs)
# ================================
$GitHubBase = "https://raw.githubusercontent.com/jg00d3/GDAP/main/Scripts"
$VersionUrl = "$GitHubBase/version.txt"

$Files = @(
    "GDAP-Modules.ps1",
    "GDAP-Graph.ps1",
    "GDAP-Data.ps1",
    "GDAP-Output.ps1",
    "GDAP-Export.ps1"
)

function Get-LocalVersion {
    $localPath = Join-Path $ScriptRoot "version.txt"
    if (Test-Path $localPath) {
        return [version](Get-Content $localPath | Select-Object -First 1)
    }
    return [version]"0.0.0"
}

function Get-RemoteVersion {
    try {
        $content = Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing -ErrorAction Stop
        return [version]($content.Content.Trim())
    }
    catch {
        Write-Warning "Unable to check remote version from GitHub."
        return $null
    }
}

function Update-FilesFromGitHub {
    Write-Host "`n[UPDATE] Downloading script updates..." -ForegroundColor Cyan

    foreach ($file in $Files + "version.txt") {
        $url = "$GitHubBase/$file"
        $dest = Join-Path $ScriptRoot $file

        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            Write-Host "[OK] Updated $file"
        }
        catch {
            Write-Warning "[FAIL] Could not update $file"
        }
    }

    Write-Host "`n[UPDATE] Complete." -ForegroundColor Green
}

# ================================
# UPDATE CHECK
# ================================
$localVersion  = Get-LocalVersion
$remoteVersion = Get-RemoteVersion

Write-Host "[Bootstrap] Local Version : $localVersion"
Write-Host "[Bootstrap] Remote Version: $remoteVersion"

if ($Update) {
    Update-FilesFromGitHub
}
elseif ($remoteVersion -gt $localVersion) {
    $answer = Read-Host "A new GDAP toolset version is available. Update now? (Y/N)"
    if ($answer -match "^[Yy]") {
        Update-FilesFromGitHub
    }
    else {
        Write-Host "Skipping update."
    }
}

# ================================
# LOAD MODULES
# ================================
foreach ($file in $Files) {
    $full = Join-Path $ScriptRoot $file
    if (Test-Path $full) {
        . $full
        Write-Host "[Load] Imported $file"
    }
    else {
        Write-Warning "[Missing] $file not found."
    }
}

Write-Host "`n[Bootstrap] GDAP environment ready.`n"
