<#
.SYNOPSIS
    Main controller for the GDAP Export Tool (with automatic updates).

.DESCRIPTION
    This script manages the entire GDAP export workflow:

      • Checks SharePoint/OneDrive for updates (version.txt)
      • If a newer version exists, downloads all updated GDAP scripts
      • Replaces the local versions
      • Restarts itself

    After ensuring it is up-to-date, it:

      • Loads helper modules
      • Ensures minimal Microsoft Graph modules are present
      • Connects to Microsoft Graph
      • Retrieves:
            - GDAP relationships
            - GDAP role definitions
            - GDAP access assignments
      • Builds:
            - Relationships table
            - Role summary
            - Role matrix
      • Outputs:
            Screen, CSV, JSON, HTML, Excel, or All

.NOTES
    Author : ChatGPT (Umetech Automation Suite)
    File   : GDAP-Export.ps1
    Version: 1.0.0
#>

# ---------------------------------------------------------------------
# Script metadata
# ---------------------------------------------------------------------
$Script:Name         = 'GDAP-Export.ps1'
$Script:LocalVersion = [version]'1.0.0'


# ---------------------------------------------------------------------
# PARAMETERS
# ---------------------------------------------------------------------
[CmdletBinding()]
param(
    [ValidateSet('Active','Expired','Both')]
    [string]$Status = 'Active',

    [ValidateSet('Basic','Full')]
    [string]$Detail = 'Full',

    [ValidateSet('Screen','Csv','Json','Html','Excel','All')]
    [string]$Output = 'All',

    [string]$OutputFolder = "C:\Scripts"
)


# ---------------------------------------------------------------------
# SharePoint configuration
# ---------------------------------------------------------------------
# Your confirmed folder: /personal/jgoode/Documents/Scripts
$ShareBase  = 'https://jmgent-my.sharepoint.com'
$UserPath   = '/personal/jgoode'
$FolderPath = '/personal/jgoode/Documents/Scripts'


# ---------------------------------------------------------------------
# Logging functions (fallback versions)
# ---------------------------------------------------------------------

if (-not (Get-Command Write-GdapLog -ErrorAction SilentlyContinue)) {
    function Write-GdapLog {
        param(
            [string]$Level,
            [string]$Script,
            [string]$Function,
            [string]$Message
        )
        $t = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$t][$Level][$Script][$Function] $Message"
    }
}

if (-not (Get-Command Write-GdapError -ErrorAction SilentlyContinue)) {
    function Write-GdapError {
        param([string]$Script,[string]$Function,[string]$Message)
        Write-GdapLog -Level 'ERROR' -Script $Script -Function $Function -Message $Message
    }
}


# ---------------------------------------------------------------------
# Self-update helper: Build sharepoint download URL
# ---------------------------------------------------------------------
function Get-UpdateDownloadUrl {
    param([Parameter(Mandatory)][string]$FileName)
    return "$ShareBase$UserPath/_layouts/15/download.aspx?SourceUrl=$FolderPath/$FileName"
}


# ---------------------------------------------------------------------
# Self-update: read remote version.txt
# ---------------------------------------------------------------------
function Get-RemoteSuiteVersion {
    $fn = 'Get-RemoteSuiteVersion'
    $url = Get-UpdateDownloadUrl -FileName 'version.txt'

    try {
        Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn `
            -Message "Checking remote version.txt at $url"

        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content.Trim()
        return [version]$content
    }
    catch {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn `
            -Message "Could not read version.txt: $($_.Exception.Message). Continuing with local version."
        return $null
    }
}


# ---------------------------------------------------------------------
# Self-update logic
# ---------------------------------------------------------------------
function Invoke-GdapSelfUpdate {
    $fn = 'Invoke-GdapSelfUpdate'

    $remoteVersion = Get-RemoteSuiteVersion
    if (-not $remoteVersion) { return }

    # Already current?
    if ($remoteVersion -le $Script:LocalVersion) {
        Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn `
            -Message "GDAP scripts are up to date (local $Script:LocalVersion , remote $remoteVersion)."
        return
    }

    # Update required
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn `
        -Message "Updating GDAP scripts from $Script:LocalVersion to $remoteVersion..."

    $files = @(
        'GDAP-Export.ps1',
        'GDAP-Modules.ps1',
        'GDAP-Graph.ps1',
        'GDAP-Data.ps1',
        'GDAP-Output.ps1'
    )

    # Where scripts are stored locally
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

    foreach ($file in $files) {
        $url  = Get-UpdateDownloadUrl -FileName $file
        $dest = Join-Path $scriptRoot $file
        $temp = "${dest}.new"

        try {
           Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn `
                -Message "Downloading updated file: $file"
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -ErrorAction Stop
            Move-Item -Path $temp -Destination $dest -Force
            Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn `
                -Message "Updated $file"
        }
        catch {
            Write-GdapError -Script $Script:Name -Function $fn `
                -Message "Failed updating $file: $($_.Exception.Message)"
        }
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn `
        -Message "Update complete. Restarting GDAP-Export.ps1..."

    # Relaunch this script with same arguments
    & (Join-Path $scriptRoot 'GDAP-Export.ps1') @PSBoundParameters
    exit
}


# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------
Write-GdapLog -Level 'INFO' -Script $Script:Name -Function 'Main' `
    -Message "Starting GDAP Export (local version $Script:LocalVersion)."

# Check for updates
Invoke-GdapSelfUpdate


# ---------------------------------------------------------------------
# Load helper scripts
# ---------------------------------------------------------------------
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$helpers = @('GDAP-Modules.ps1','GDAP-Graph.ps1','GDAP-Data.ps1','GDAP-Output.ps1')

foreach ($file in $helpers) {
    $path = Join-Path $scriptRoot $file
    if (-not (Test-Path $path)) {
        Write-GdapError -Script $Script:Name -Function 'LoadHelpers' `
            -Message "Missing helper script: $path"
        throw "Cannot continue without $file"
    }

    . $path
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'LoadHelpers' `
        -Message "Loaded $file"
}


# ---------------------------------------------------------------------
# Ensure minimal Graph modules
# ---------------------------------------------------------------------
Ensure-GdapModules


# ---------------------------------------------------------------------
# Connect to Microsoft Graph
# ---------------------------------------------------------------------
Ensure-GdapGraphConnection -Scopes @(
    "DelegatedAdminRelationship.Read.All",
    "Directory.Read.All",
    "RoleManagement.Read.All"
)


# ---------------------------------------------------------------------
# Map status to filter
# ---------------------------------------------------------------------
$statusMap = @{
    "Active"  = "ActiveOnly"
    "Expired" = "ExpiredOnly"
    "Both"    = "Both"
}

$filter = $statusMap[$Status]


# ---------------------------------------------------------------------
# Retrieve GDAP relationship data
# ---------------------------------------------------------------------
$relationships = Get-GdapRelationships -StatusFilter $filter

if (-not $relationships -or $relationships.Count -eq 0) {
    Write-GdapLog -Level 'WARN' -Script $Script:Name -Function 'Main' `
        -Message "No GDAP relationships found using filter '$Status'."
}


$roleMap     = Get-GdapRoleDefinitionsMap
$assignments = Get-GdapAccessAssignments -Relationships $relationships -RoleMap $roleMap

$relsTable   = Get-GdapRelationshipsTable -Relationships $relationships
$summary     = Get-GdapRoleSummaryTable -RoleAssignments $assignments
$matrix      = Get-GdapRoleMatrixTable -RoleAssignments $assignments


# ---------------------------------------------------------------------
# Output data
# ---------------------------------------------------------------------
Write-GdapOutputs `
    -Relationships $relsTable `
    -RoleAssignments $assignments `
    -RoleSummary $summary `
    -RoleMatrix $matrix `
    -Detail $Detail `
    -Output $Output `
    -OutputFolder $OutputFolder


Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Main' `
    -Message "GDAP export completed successfully."

# END OF FILE
