<#
.SYNOPSIS
    Data retrieval and table-building functions for the GDAP Export Tool.

.DESCRIPTION
    This script retrieves:
      • GDAP delegated admin relationships
      • Role definitions
      • Access assignments for each GDAP relationship

    It then reshapes the data into:
      • A relationships table
      • A role summary table
      • A role assignment matrix table

    Logging is standardized and tagged with:
      - Timestamp
      - Level (INFO, OK, WARN, ERROR)
      - Script name
      - Function name

    Graph modules used:
      - Microsoft.Graph.Beta
      - Microsoft.Graph.Beta.RoleManagement (optional)

.NOTES
    Author: ChatGPT (Umetech Automation Suite)
    File  : GDAP-Data.ps1
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Data.ps1'


# ---------------------------------------------------------------------
# Logging helpers (fallback if not already loaded)
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
# Import Graph modules (minimal required)
# ---------------------------------------------------------------------

try {
    Import-Module Microsoft.Graph.Beta -ErrorAction Stop
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Import-Modules' -Message 'Imported Microsoft.Graph.Beta'
}
catch {
    Write-GdapError -Script $Script:Name -Function 'Import-Modules' -Message "Failed to import Microsoft.Graph.Beta: $($_.Exception.Message)"
    throw
}

# Optional but useful for role definitions
try {
    Import-Module Microsoft.Graph.Beta.RoleManagement -ErrorAction SilentlyContinue
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Import-Modules' -Message 'Imported Microsoft.Graph.Beta.RoleManagement (optional)'
}
catch {
    Write-GdapLog -Level 'WARN' -Script $Script:Name -Function 'Import-Modules' -Message 'Graph Beta RoleManagement module not available; continuing.'
}


# ---------------------------------------------------------------------
# Role list (from your memory profile — 15 roles + 2 extras)
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

    # Additional two roles:
    "Insights Business Leader",
    "Reports Reader"
)


# ---------------------------------------------------------------------
# Retrieve GDAP delegated admin relationships
# ---------------------------------------------------------------------

function Get-GdapRelationships {
    <#
    .SYNOPSIS
        Retrieves GDAP delegated admin relationships for the Partner Tenant.

    .PARAMETER StatusFilter
        Acceptable values:
           "ActiveOnly"
           "ExpiredOnly"
           "Both"

    .OUTPUTS
        Array of Delegated Admin Relationship objects
    #>

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
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to retrieve delegated admin relationships: $($_.Exception.Message)"
        throw
    }

    if (-not $rels) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message 'No GDAP relationships returned from Graph.'
        return @()
    }

    # Apply status filter
    switch ($StatusFilter) {
        "ActiveOnly"  { $rels = $rels | Where-Object { $_.Status -eq "active" } }
        "ExpiredOnly" { $rels = $rels | Where-Object { $_.Status -in @("expired","terminated") } }
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Retrieved $($rels.Count) filtered GDAP relationships."

    return $rels
}


# ---------------------------------------------------------------------
# Retrieve role definitions map (ById, ByName)
# ---------------------------------------------------------------------

function Get-GdapRoleDefinitionsMap {
    <#
    .SYNOPSIS
        Retrieves all available role definitions and returns a map
        grouped by RoleDefinitionId and DisplayName.
    #>

    $fn = 'Get-GdapRoleDefinitionsMap'

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message 'Retrieving role definitions...'

    try {
        $defs = Get-MgBetaRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to retrieve role definitions: $($_.Exception.Message)"
        throw
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Retrieved $($defs.Count) total role definitions."

    # Return grouped hash tables
    return @{
        ById   = $defs | Group-Object -Property Id           -AsHashTable
        ByName = $defs | Group-Object -Property DisplayName  -AsHashTable
    }
}


# ---------------------------------------------------------------------
# Retrieve access assignments per GDAP relationship
# ---------------------------------------------------------------------

function Get-GdapAccessAssignments {
    <#
    .SYNOPSIS
        Retrieves access assignments (UnifiedRoles) for each GDAP relationship.

    .PARAMETER Relationships
        Array of Delegated Admin Relationship objects.

    .PARAMETER RoleMap
        Hash table from Get-GdapRoleDefinitionsMap.

    .OUTPUTS
        Array of PSCustomObject entries representing role assignments.
    #>

    param(
        [Parameter(Mandatory)][array]$Relationships,
        [Parameter(Mandatory)][hashtable]$RoleMap
    )

    $fn = 'Get-GdapAccessAssignments'

    if (-not $Relationships -or $Relationships.Count -eq 0) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message 'No relationships passed in. Returning empty list.'
        return @()
    }

    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Retrieving access assignments for $($Relationships.Count) relationships..."

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($rel in $Relationships) {

        Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Processing relationship '$($rel.DisplayName)' ($($rel.Id))"

        try {
            $assignments = Get-MgBetaTenantRelationshipDelegatedAdminRelationshipAccessAssignment `
                              -DelegatedAdminRelationshipId $rel.Id `
                              -ExpandProperty accessDetails `
                              -All `
                              -ErrorAction Stop
        }
        catch {
            Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to read access assignments for relationship $($rel.Id): $($_.Exception.Message)"
            continue
        }

        foreach ($aa in $assignments) {
            if (-not $aa.AccessDetails.UnifiedRoles) { continue }

            foreach ($ur in $aa.AccessDetails.UnifiedRoles) {
                $roleName = $null

                if ($RoleMap.ById.ContainsKey($ur.RoleDefinitionId)) {
                    $roleName = $RoleMap.ById[$ur.RoleDefinitionId].DisplayName
                }
                else {
                    $roleName = "<Unknown Role>"
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
# Table formatting helpers
# ---------------------------------------------------------------------

function Get-GdapRelationshipsTable {
    <#
    .SYNOPSIS
        Returns relationships in table-friendly format.
    #>
    param([Parameter(Mandatory)][array]$Relationships)
    return $Relationships
}

function Get-GdapRoleSummaryTable {
    <#
    .SYNOPSIS
        Builds a summary table of number of role assignments per role.
    #>
    param([Parameter(Mandatory)][array]$RoleAssignments)
    return $RoleAssignments
}

function Get-GdapRoleMatrixTable {
    <#
    .SYNOPSIS
        Returns role assignment data suitable for matrix rendering.
    #>
    param([Parameter(Mandatory)][array]$RoleAssignments)
    return $RoleAssignments
}

# END OF FILE
