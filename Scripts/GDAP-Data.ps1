<#
.SYNOPSIS
    Data retrieval and table-building functions for the GDAP Export Tool.

.DESCRIPTION
    Retrieves:
      • GDAP delegated admin relationships
      • Role definitions
      • Access assignments for each GDAP relationship (NEW API PATTERN)

    Produces:
      • Relationships table
      • Role summary table
      • Role matrix table

    Logging is standardized and tagged with:
      - Timestamp
      - Level (INFO, OK, WARN, ERROR)
      - Script name
      - Function name

.NOTES
    Author: ChatGPT (Umetech Automation Suite)
    File  : GDAP-Data.ps1
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Data.ps1'


# ---------------------------------------------------------------------
# Logging helpers (fallback if needed)
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
# Import Graph modules
# ---------------------------------------------------------------------

try {
    Import-Module Microsoft.Graph.Beta -ErrorAction Stop
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Import-Modules' -Message 'Imported Microsoft.Graph.Beta'
}
catch {
    Write-GdapError -Script $Script:Name -Function 'Import-Modules' -Message "Failed to import Microsoft.Graph.Beta: $($_.Exception.Message)"
    throw
}

try {
    Import-Module Microsoft.Graph.Beta.RoleManagement -ErrorAction SilentlyContinue
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Import-Modules' -Message 'Imported Microsoft.Graph.Beta.RoleManagement (optional)'
}
catch {
    Write-GdapLog -Level 'WARN' -Script $Script:Name -Function 'Import-Modules' -Message 'Graph Beta RoleManagement module not available; continuing.'
}


# ---------------------------------------------------------------------
# Role List (from your memory profile)
# ---------------------------------------------------------------------

$Script:RequiredRoles = @(
    "Cloud Application Administrator",
    "Directory Readers",
    "Directory Writers",
    "Exchange Administrator",
    "Global Reader",
    "Helpdesk Administrator",
    "Intune Administrator",
    "License Administrator",
    "Privileged Authentication Administrator",
    "Privileged Role Administrator",
    "Security Administrator",
    "Service Support Administrator",
    "SharePoint Administrator",
    "Teams Administrator",
    "User Administrator",
    "Insights Business Leader",
    "Reports Reader"
)


# ---------------------------------------------------------------------
# Retrieve GDAP delegated admin relationships
# ---------------------------------------------------------------------

function Get-GdapRelationships {

    param(
        [ValidateSet('ActiveOnly','ExpiredOnly','Both')]
        [Parameter(Mandatory)]
        [string]$StatusFilter
    )

    $fn = 'Get-GdapRelationships'
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Retrieving delegated admin relationships..."

    try {
        $rels = Get-MgBetaTenantRelationshipDelegatedAdminRelationship -All -ErrorAction Stop
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to retrieve GDAP relationships: $($_.Exception.Message)"
        throw
    }

    if (-not $rels) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "No GDAP relationships returned."
        return @()
    }

    switch ($StatusFilter) {
        "ActiveOnly"  { $rels = $rels | Where-Object { $_.Status -eq "active" } }
        "ExpiredOnly" { $rels = $rels | Where-Object { $_.Status -in @("expired","terminated") } }
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Retrieved $($rels.Count) filtered GDAP relationships."

    return $rels
}


# ---------------------------------------------------------------------
# Retrieve role definitions (by ID and Name)
# ---------------------------------------------------------------------

function Get-GdapRoleDefinitionsMap {

    $fn = 'Get-GdapRoleDefinitionsMap'
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Retrieving role definitions..."

    try {
        $defs = Get-MgBetaRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to retrieve role definitions: $($_.Exception.Message)"
        throw
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Retrieved $($defs.Count) total role definitions."

    return @{
        ById   = $defs | Group-Object -Property Id -AsHashTable
        ByName = $defs | Group-Object -Property DisplayName -AsHashTable
    }
}


# ---------------------------------------------------------------------
# UPDATED — Retrieve access assignments using NEW Graph API pattern
# ---------------------------------------------------------------------

function Get-GdapAccessAssignments {

    param(
        [Parameter(Mandatory)][array]$Relationships,
        [Parameter(Mandatory)][hashtable]$RoleMap
    )

    $fn = 'Get-GdapAccessAssignments'

    if (-not $Relationships -or $Relationships.Count -eq 0) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message 'No relationships passed in.'
        return @()
    }

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Retrieving access assignments (new API behavior)…"

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($rel in $Relationships) {

        Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Processing relationship '$($rel.DisplayName)' ($($rel.Id))..."

        # Step 1: Retrieve assignments (without expand)
        try {
            $assignments = Get-MgBetaTenantRelationshipDelegatedAdminRelationshipAccessAssignment `
                -DelegatedAdminRelationshipId $rel.Id `
                -All `
                -ErrorAction Stop
        }
        catch {
            Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to list assignments: $($_.Exception.Message)"
            continue
        }

        foreach ($aa in $assignments) {

            # Step 2: Retrieve accessDetails separately
            try {
                $details = Get-MgBetaTenantRelationshipDelegatedAdminRelationshipAccessAssignmentAccessDetail `
                    -DelegatedAdminRelationshipId $rel.Id `
                    -DelegatedAdminAccessAssignmentId $aa.Id `
                    -ErrorAction Stop
            }
            catch {
                Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to get accessDetails for assignment $($aa.Id): $($_.Exception.Message)"
                continue
            }

            if (-not $details.UnifiedRoles) { continue }

            foreach ($ur in $details.UnifiedRoles) {

                $roleName =
                    if ($RoleMap.ById.ContainsKey($ur.RoleDefinitionId)) {
                        $RoleMap.ById[$ur.RoleDefinitionId].DisplayName
                    } else {
                        "<Unknown Role>"
                    }

                $results.Add([pscustomobject]@{
                    RelationshipId    = $rel.Id
                    RelationshipName  = $rel.DisplayName
                    CustomerTenantId  = $rel.CustomerTenantId
                    AssignmentId      = $aa.Id
                    RoleDefinitionId  = $ur.RoleDefinitionId
                    RoleDisplayName   = $roleName
                    Status            = $rel.Status
                })
            }
        }
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Built $($results.Count) total access assignment records."

    return $results
}


# ---------------------------------------------------------------------
# Table formatting (simple pass-throughs)
# ---------------------------------------------------------------------

function Get-GdapRelationshipsTable {
    param([Parameter(Mandatory)][array]$Relationships)
    return $Relationships
}

function Get-GdapRoleSummaryTable {
    param([Parameter(Mandatory)][array]$RoleAssignments)
    return $RoleAssignments
}

function Get-GdapRoleMatrixTable {
    param([Parameter(Mandatory)][array]$RoleAssignments)
    return $RoleAssignments
}

# END OF FILE
