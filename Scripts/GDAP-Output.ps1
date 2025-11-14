<#
.SYNOPSIS
    Output engine for the GDAP Export Toolset.

.DESCRIPTION
    This script receives:
      • Relationships table
      • Role Assignments table
      • Role Summary table
      • Role Matrix table

    And depending on user selection, outputs:
      • Screen output
      • CSV files
      • JSON files
      • HTML files
      • Excel files (requires ImportExcel)

    Every action is logged with:
      - Timestamp
      - Severity level
      - Script name
      - Function name

.NOTES
    Author: ChatGPT (Umetech Automation Suite)
    File  : GDAP-Output.ps1
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Output.ps1'


# ---------------------------------------------------------------------
# Logging helpers (fallback versions)
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


# ---------------------------------------------------------------------
# Ensure output folder
# ---------------------------------------------------------------------

function Ensure-GdapOutputFolder {
    <#
    .SYNOPSIS
        Ensures output folder exists.

    .OUTPUTS
        The validated output folder path.
    #>

    param([Parameter(Mandatory)][string]$Path)

    $fn = 'Ensure-GdapOutputFolder'

    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Created output folder: $Path"
        }
        catch {
            Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to create output folder: $($_.Exception.Message)"
            throw
        }
    }
    else {
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Using output folder: $Path"
    }

    return (Resolve-Path $Path).Path
}


# ---------------------------------------------------------------------
# SCREEN OUTPUT
# ---------------------------------------------------------------------

function Write-GdapScreenOutput {
    <#
    .SYNOPSIS
        Outputs data to screen (console).
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix
    )

    $fn = 'Write-GdapScreenOutput'
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message 'Displaying data on screen:'

    "`n================ GDAP RELATIONSHIPS ================"
    $Relationships | Format-Table -AutoSize
    "`n================ ROLE ASSIGNMENTS ================"
    $RoleAssignments | Format-Table -AutoSize
    "`n================ ROLE SUMMARY ================"
    $RoleSummary | Format-Table -AutoSize
    "`n================ ROLE MATRIX (RAW) ================"
    $RoleMatrix | Format-Table -AutoSize
}


# ---------------------------------------------------------------------
# CSV OUTPUT
# ---------------------------------------------------------------------

function Write-GdapCsvOutput {
    <#
    .SYNOPSIS
        Outputs all artifacts to CSV format.
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Write-GdapCsvOutput'

    try {
        $Relationships  | Export-Csv (Join-Path $OutputFolder 'Relationships.csv') -NoTypeInformation
        $RoleAssignments | Export-Csv (Join-Path $OutputFolder 'RoleAssignments.csv') -NoTypeInformation
        $RoleSummary    | Export-Csv (Join-Path $OutputFolder 'RoleSummary.csv') -NoTypeInformation
        $RoleMatrix     | Export-Csv (Join-Path $OutputFolder 'RoleMatrix.csv') -NoTypeInformation

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'CSV export complete.'
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "CSV export failed: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------
# JSON OUTPUT
# ---------------------------------------------------------------------

function Write-GdapJsonOutput {
    <#
    .SYNOPSIS
        Outputs all artifacts to JSON format.
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Write-GdapJsonOutput'

    try {
        $Relationships   | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputFolder 'Relationships.json')
        $RoleAssignments | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputFolder 'RoleAssignments.json')
        $RoleSummary     | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputFolder 'RoleSummary.json')
        $RoleMatrix      | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputFolder 'RoleMatrix.json')

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'JSON export complete.'
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "JSON export failed: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------
# HTML OUTPUT
# ---------------------------------------------------------------------

function Write-GdapHtmlOutput {
    <#
    .SYNOPSIS
        Outputs data tables to HTML format.
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Write-GdapHtmlOutput'

    try {
        ($Relationships  | ConvertTo-Html -PreContent "<h2>GDAP Relationships</h2>") |
            Out-File (Join-Path $OutputFolder 'Relationships.html')

        ($RoleAssignments | ConvertTo-Html -PreContent "<h2>Role Assignments</h2>") |
            Out-File (Join-Path $OutputFolder 'RoleAssignments.html')

        ($RoleSummary | ConvertTo-Html -PreContent "<h2>Role Summary</h2>") |
            Out-File (Join-Path $OutputFolder 'RoleSummary.html')

        ($RoleMatrix | ConvertTo-Html -PreContent "<h2>Role Matrix</h2>") |
            Out-File (Join-Path $OutputFolder 'RoleMatrix.html')

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'HTML export complete.'
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "HTML export failed: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------
# EXCEL OUTPUT (ImportExcel)
# ---------------------------------------------------------------------

function Write-GdapExcelOutput {
    <#
    .SYNOPSIS
        Outputs all data to a single Excel file using ImportExcel.

    .NOTES
        Requires: ImportExcel module
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Write-GdapExcelOutput'

    $excelPath = Join-Path $OutputFolder 'GDAP-Export.xlsx'

    try {
        $Relationships  | Export-Excel -Path $excelPath -WorksheetName 'Relationships'  -AutoSize -TableName 'RelationshipsTable'
        $RoleAssignments | Export-Excel -Path $excelPath -WorksheetName 'RoleAssignments' -AutoSize -TableName 'AssignmentsTable' -Append
        $RoleSummary    | Export-Excel -Path $excelPath -WorksheetName 'RoleSummary'    -AutoSize -TableName 'SummaryTable' -Append
        $RoleMatrix     | Export-Excel -Path $excelPath -WorksheetName 'RoleMatrix'     -AutoSize -TableName 'MatrixTable' -Append

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Excel export ready: $excelPath"
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Excel export failed: $($_.Exception.Message)"
    }
}


# ---------------------------------------------------------------------
# MASTER OUTPUT HANDLER
# ---------------------------------------------------------------------

function Write-GdapOutputs {
    <#
    .SYNOPSIS
        Master handler. Produces all requested output formats.

    .PARAMETER Relationships
    .PARAMETER RoleAssignments
    .PARAMETER RoleSummary
    .PARAMETER RoleMatrix

    .PARAMETER Detail
        Basic or Full (future expansion)

    .PARAMETER Output
        Screen, Csv, Json, Html, Excel, All

    .PARAMETER OutputFolder
        Folder path for saved files
    #>

    param(
        [Parameter(Mandatory)]$Relationships,
        [Parameter(Mandatory)]$RoleAssignments,
        [Parameter(Mandatory)]$RoleSummary,
        [Parameter(Mandatory)]$RoleMatrix,
        [Parameter(Mandatory)][ValidateSet('Basic','Full')] [string]$Detail,
        [Parameter(Mandatory)][ValidateSet('Screen','Csv','Json','Html','Excel','All')] [string]$Output,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $fn = 'Write-GdapOutputs'

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Processing output type '$Output'..."

    # Ensure folder exists
    $OutputFolder = Ensure-GdapOutputFolder -Path $OutputFolder

    # ---- SCREEN ----
    if ($Output -eq 'Screen' -or $Output -eq 'All') {
        Write-GdapScreenOutput -Relationships $Relationships -RoleAssignments $RoleAssignments -RoleSummary $RoleSummary -RoleMatrix $RoleMatrix
    }

    # ---- CSV ----
    if ($Output -eq 'Csv' -or $Output -eq 'All') {
        Write-GdapCsvOutput -Relationships $Relationships -RoleAssignments $RoleAssignments -RoleSummary $RoleSummary -RoleMatrix $RoleMatrix -OutputFolder $OutputFolder
    }

    # ---- JSON ----
    if ($Output -eq 'Json' -or $Output -eq 'All') {
        Write-GdapJsonOutput -Relationships $Relationships -RoleAssignments $RoleAssignments -RoleSummary $RoleSummary -RoleMatrix $RoleMatrix -OutputFolder $OutputFolder
    }

    # ---- HTML ----
    if ($Output -eq 'Html' -or $Output -eq 'All') {
        Write-GdapHtmlOutput -Relationships $Relationships -RoleAssignments $RoleAssignments -RoleSummary $RoleSummary -RoleMatrix $RoleMatrix -OutputFolder $OutputFolder
    }

    # ---- EXCEL ----
    if ($Output -eq 'Excel' -or $Output -eq 'All') {
        Write-GdapExcelOutput -Relationships $Relationships -RoleAssignments $RoleAssignments -RoleSummary $RoleSummary -RoleMatrix $RoleMatrix -OutputFolder $OutputFolder
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'All requested outputs generated.'
}

# END OF FILE
