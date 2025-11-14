<#
.SYNOPSIS
    Output and orchestration helpers for GDAP export.

.DESCRIPTION
    This module wires together:
      • Graph connection (Ensure-GdapGraphConnection)
      • Data retrieval (GDAP-Data.ps1 functions)
      • CSV export to disk

    It exposes a single main entry point:
      • Start-GdapExport
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Output.ps1'


# ---------------------------------------------------------------------
# Logging helpers (fallback if main logger not loaded)
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
        param(
            [string]$Script,
            [string]$Function,
            [string]$Message
        )
        Write-GdapLog -Level 'ERROR' -Script $Script -Function $Function -Message $Message
    }
}

Write-GdapLog -Level 'INFO' -Script $Script:Name -Function 'Init' -Message 'GDAP Output module loaded.'


# ---------------------------------------------------------------------
# Helper: Write data to CSV
# ---------------------------------------------------------------------

function Write-GdapCsv {
    <#
    .SYNOPSIS
        Writes an object collection to CSV with logging and folder create.

    .PARAMETER Path
        Full path to the CSV file.

    .PARAMETER Data
        Object collection to export.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Data
    )

    $fn = 'Write-GdapCsv'

    try {
        $folder = Split-Path -Parent $Path
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Exported CSV: $Path"
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to export CSV '$Path': $($_.Exception.Message)"
        throw
    }
}


# ---------------------------------------------------------------------
# Main entry point: Start-GdapExport
# ---------------------------------------------------------------------

function Start-GdapExport {
    <#
    .SYNOPSIS
        Orchestrates the full GDAP export.

    .PARAMETER Status
        High-level status filter: Active, Expired, or All.

    .PARAMETER Detail
        Currently informational only (e.g., Full, Summary).

    .PARAMETER Output
        Output selection: All, Relationships, Roles, Matrix.

    .PARAMETER OutputFolder
        Destination folder for CSV exports.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Detail,
        [Parameter(Mandatory)][string]$Output,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Start-GdapExport'

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Starting GDAP export with Status='$Status', Detail='$Detail', Output='$Output', Folder='$OutputFolder'."

    # ----------------- Determine status filter -----------------
    $statusFilter = switch ($Status.ToLower()) {
        'active'  { 'ActiveOnly'  }
        'expired' { 'ExpiredOnly' }
        default   { 'Both'        }
    }

    # ----------------- Ensure Graph connection -----------------
    $scopes = @(
        'Directory.Read.All',
        'DelegatedAdminRelationship.Read.All',
        'RoleManagement.Read.Directory'
    )

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Ensuring Graph connection with scopes: $($scopes -join ', ')"
    Ensure-GdapGraphConnection -Scopes $scopes

    # ----------------- Retrieve relationships ------------------
    $relationships = Get-GdapRelationships -StatusFilter $statusFilter

    if (-not $relationships -or $relationships.Count -eq 0) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message 'No GDAP relationships found; nothing to export.'
        return
    }

    # ----------------- Retrieve role definitions ---------------
    $roleMap = Get-GdapRoleDefinitionsMap

    # ----------------- Retrieve access assignments -------------
    $assignments = Get-GdapAccessAssignments -Relationships $relationships -RoleMap $roleMap

    # ----------------- Build tables ----------------------------
    $relationshipsTable = Get-GdapRelationshipsTable -Relationships $relationships
    $roleSummaryTable   = Get-GdapRoleSummaryTable   -RoleAssignments $assignments
    $roleMatrixTable    = Get-GdapRoleMatrixTable    -RoleAssignments $assignments

    # ----------------- Decide which outputs to write ----------
    $outputMode = $Output.ToLower()

    if ($outputMode -eq 'all' -or $outputMode -like '*relationships*') {
        $path = Join-Path $OutputFolder 'GDAP-Relationships.csv'
        Write-GdapCsv -Path $path -Data $relationshipsTable
    }

    if ($outputMode -eq 'all' -or $outputMode -like '*roles*') {
        $path = Join-Path $OutputFolder 'GDAP-RolesSummary.csv'
        Write-GdapCsv -Path $path -Data $roleSummaryTable
    }

    if ($outputMode -eq 'all' -or $outputMode -like '*matrix*') {
        $path = Join-Path $OutputFolder 'GDAP-RoleMatrix.csv'
        Write-GdapCsv -Path $path -Data $roleMatrixTable
    }

    # ----------------- Summary ----------------------------
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message (
        "Export complete. Relationships=$($relationships.Count), " +
        "Assignments=$($assignments.Count). Output folder: $OutputFolder"
    )
}
# END OF FILE
