<#
.SYNOPSIS
    Self-updating bootstrap installer for the GDAP Export Toolset.

.DESCRIPTION
    This script performs three major functions:

      1. Self-update:
         - Contacts your SharePoint "Scripts" folder.
         - Checks version.txt.
         - If newer, downloads the new bootstrap script.
         - Replaces itself.
         - Relaunches.

      2. Environment Setup:
         - Ensures C:\Scripts exists.
         - Downloads updated copies of:
               • GDAP-Export.ps1
               • GDAP-Modules.ps1
               • GDAP-Graph.ps1
               • GDAP-Data.ps1
               • GDAP-Output.ps1
         - Unblocks all GDAP files.

      3. Launch:
         - Executes GDAP-Export.ps1.

    This is the correct entry point for ANY system.

.NOTES
    Author  : ChatGPT (Umetech Automation Suite)
    File    : GDAP-Bootstrap.ps1
    Version : 1.0.0
#>

# ---------------------------------------------------------------------
# Script metadata
# ---------------------------------------------------------------------
$Script:Name         = 'GDAP-Bootstrap.ps1'
$Script:LocalVersion = [version]'1.0.0'


# ---------------------------------------------------------------------
# SharePoint configuration
# ---------------------------------------------------------------------
# Confirmed path from you:
#   /personal/jgoode/Documents/Scripts
$ShareBase  = 'https://jmgent-my.sharepoint.com'
$UserPath   = '/personal/jgoode'
$FolderPath = '/personal/jgoode/Documents/Scripts'


# ---------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------

function Write-BootLog {
    param(
        [string]$Level,
        [string]$Function,
        [string]$Message
    )
    $t = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$t][$Level][$Script:Name][$Function] $Message"
}

function Write-BootError {
    param($Function,$Message)
    Write-BootLog -Level 'ERROR' -Function $Function -Message $Message
}


# ---------------------------------------------------------------------
# Build SharePoint download URL
# ---------------------------------------------------------------------
function Get-DownloadUrl {
    param([Parameter(Mandatory)][string]$FileName)
    return "$ShareBase$UserPath/_layouts/15/download.aspx?SourceUrl=$FolderPath/$FileName"
}


# ---------------------------------------------------------------------
# Read remote version.txt
# ---------------------------------------------------------------------
function Get-RemoteVersion {
    $fn = 'Get-RemoteVersion'
    $url = Get-DownloadUrl -FileName 'version.txt'

    try {
        Write-BootLog 'INFO' $fn "Checking version.txt at $url"
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content.Trim()
        return [version]$content
    }
    catch {
        Write-BootLog 'WARN' $fn "Could not read remote version: $($_.Exception.Message)"
        return $null
    }
}


# ---------------------------------------------------------------------
# Self-update logic
# ---------------------------------------------------------------------
function Invoke-BootstrapSelfUpdate {

    $fn = 'Invoke-BootstrapSelfUpdate'

    $remoteVersion = Get-RemoteVersion
    if (-not $remoteVersion) { return }

    if ($remoteVersion -le $Script:LocalVersion) {
        Write-BootLog 'INFO' $fn "Bootstrap is up to date (local $Script:LocalVersion, remote $remoteVersion)"
        return
    }

    Write-BootLog 'INFO' $fn "Updating bootstrap from $Script:LocalVersion to $remoteVersion..."

    $selfPath = $MyInvocation.MyCommand.Path
    $tempPath = "${selfPath}.new"
    $url      = Get-DownloadUrl -FileName 'GDAP-Bootstrap.ps1'

    try {
        Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
        Move-Item -Path $tempPath -Destination $selfPath -Force
        Write-BootLog 'OK' $fn "Bootstrap updated. Relaunching..."
        & $selfPath
        exit
    }
    catch {
        Write-BootError $fn "Failed updating bootstrap: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------
# Ensure C:\Scripts exists
# ---------------------------------------------------------------------
function Ensure-ScriptsFolder {
    $fn = 'Ensure-ScriptsFolder'

    $path = 'C:\Scripts'

    if (-not (Test-Path -Path $path)) {
        try {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            Write-BootLog 'OK' $fn "Created $path"
        }
        catch {
            Write-BootError $fn "Failed creating $path: $($_.Exception.Message)"
            throw
        }
    }
    else {
        Write-BootLog 'OK' $fn "Using existing folder: $path"
    }

    return $path
}


# ---------------------------------------------------------------------
# Download all GDAP scripts
# ---------------------------------------------------------------------
function Download-GdapFiles {
    param([string]$TargetFolder)

    $fn = 'Download-GdapFiles'

    $files = @(
        'GDAP-Export.ps1',
        'GDAP-Modules.ps1',
        'GDAP-Graph.ps1',
        'GDAP-Data.ps1',
        'GDAP-Output.ps1'
    )

    foreach ($file in $files) {
        $url  = Get-DownloadUrl -FileName $file
        $dest = Join-Path $TargetFolder $file

        try {
            Write-BootLog 'INFO' $fn "Downloading $file..."
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            Write-BootLog 'OK' $fn "$file downloaded."
        }
        catch {
            Write-BootError $fn "Failed downloading $file: $($_.Exception.Message)"
        }
    }
}


# ---------------------------------------------------------------------
# Unblock downloaded scripts
# ---------------------------------------------------------------------
function Unblock-GdapFiles {
    param([string]$TargetFolder)

    $fn = 'Unblock-GdapFiles'

    $pattern = Join-Path $TargetFolder 'GDAP-*.ps1'

    foreach ($file in (Get-Item $pattern -ErrorAction SilentlyContinue)) {
        try {
            Unblock-File -Path $file.FullName
            Write-BootLog 'OK' $fn "Unblocked $($file.Name)"
        }
        catch {
            Write-BootLog 'WARN' $fn "Could not unblock $($file.Name): $($_.Exception.Message)"
        }
    }
}


# ---------------------------------------------------------------------
# Launch GDAP-Export.ps1
# ---------------------------------------------------------------------
function Start-GdapExport {
    param([string]$TargetFolder)

    $fn = 'Start-GdapExport'

    $path = Join-Path $TargetFolder 'GDAP-Export.ps1'

    if (-not (Test-Path $path)) {
        Write-BootError $fn "GDAP-Export.ps1 not found at $path"
        return
    }

    Write-BootLog 'INFO' $fn "Launching GDAP-Export.ps1..."
    & $path   # pass on any cmdline params?
}


# ---------------------------------------------------------------------
# MAIN EXECUTION
# ---------------------------------------------------------------------

Write-BootLog 'INFO' 'Main' "Starting GDAP Bootstrap (local $Script:LocalVersion)."

# Self-update
Invoke-BootstrapSelfUpdate

# Ensure folder
$target = Ensure-ScriptsFolder

# Download all script files
Download-GdapFiles -TargetFolder $target

# Ensure they aren't blocked by Windows
Unblock-GdapFiles -TargetFolder $target

# Launch the actual export tool
Start-GdapExport -TargetFolder $target

Write-BootLog 'OK' 'Main' "Bootstrap completed."
# END OF FILE
