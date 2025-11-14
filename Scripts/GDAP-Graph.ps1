<#
.SYNOPSIS
    Microsoft Graph connection helper for the GDAP export toolset.

.DESCRIPTION
    This script provides helper functions that:
      • Check whether a Microsoft Graph connection already exists.
      • Establish a new connection with the required scopes when needed.
      • Integrate with the centralized GDAP logging format.

    It expects that:
      • GDAP-Modules.ps1 has already ensured:
          - Microsoft.Graph.Authentication
          - Microsoft.Graph.Beta
        are installed and importable.

.NOTES
    Author: ChatGPT (Umetech Automation Suite)
    File  : GDAP-Graph.ps1
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Graph.ps1'


# ---------------------------------------------------------------------
# Logging helpers (fall back if main logger not yet loaded)
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
# Import minimal Graph modules (Modules script should already have them)
# ---------------------------------------------------------------------

try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Beta           -ErrorAction Stop
    Write-GdapLog -Level 'OK' -Script $Script:Name -Function 'Import-Modules' -Message 'Imported Microsoft.Graph.Authentication and Microsoft.Graph.Beta.'
}
catch {
    Write-GdapError -Script $Script:Name -Function 'Import-Modules' -Message "Failed to import Graph modules: $($_.Exception.Message)"
    throw
}


# ---------------------------------------------------------------------
# Test existing Microsoft Graph connection
# ---------------------------------------------------------------------

function Test-GdapGraphConnection {
    <#
    .SYNOPSIS
        Determines whether there is a usable Microsoft Graph connection.

    .DESCRIPTION
        Uses Get-MgContext to check if a valid account is currently
        associated with the Graph session. Returns $true if so, otherwise
        returns $false.

    .OUTPUTS
        [bool]
    #>

    $fn = 'Test-GdapGraphConnection'

    try {
        $ctx = Get-MgContext -ErrorAction Stop

        if ($null -eq $ctx) {
            Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message 'Get-MgContext returned $null.'
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($ctx.Account)) {
            Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message 'No Graph account is currently connected.'
            return $false
        }

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Graph context found for account '$($ctx.Account)'."
        return $true
    }
    catch {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Get-MgContext failed: $($_.Exception.Message)"
        return $false
    }
}


# ---------------------------------------------------------------------
# Ensure Graph connection with required scopes
# ---------------------------------------------------------------------

function Ensure-GdapGraphConnection {
    <#
    .SYNOPSIS
        Ensures there is a valid Microsoft Graph connection.

    .DESCRIPTION
        If an existing Graph connection is detected (via Test-GdapGraphConnection),
        it will be reused. Otherwise, this function will call Connect-MgGraph
        with the specified scopes.

    .PARAMETER Scopes
        Array of Microsoft Graph permission scopes required for this run.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Scopes
    )

    $fn = 'Ensure-GdapGraphConnection'

    # If already connected, reuse that connection
    if (Test-GdapGraphConnection) {
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'Using existing Microsoft Graph connection.'
        return
    }

    # Not connected; attempt to connect now
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "No existing Graph connection detected. Connecting with scopes: $($Scopes -join ', ')"

    $params = @{
        Scopes    = $Scopes
        NoWelcome = $true
    }

    try {
        Connect-MgGraph @params
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'Successfully connected to Microsoft Graph.'
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        throw
    }
}

# END OF FILE
