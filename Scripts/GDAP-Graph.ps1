<#
.SYNOPSIS
    Microsoft Graph connection helper for the GDAP export toolset.

.DESCRIPTION
    Defines helper functions to:
      • Check existing Graph connection
      • Establish new Graph connection
      • Provide structured GDAP logging

    Actual Graph module installation/import is handled by GDAP-Modules.ps1.
#>

# ---------------------------------------------------------------------
# Script identity
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Graph.ps1'


# ---------------------------------------------------------------------
# Logging fallback
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
# Initialization Log Only (NO IMPORTS)
# ---------------------------------------------------------------------
Write-GdapLog -Level 'INFO' -Script $Script:Name -Function 'Init' -Message 'GDAP Graph module loaded.'


# ---------------------------------------------------------------------
# Test existing Graph connection
# ---------------------------------------------------------------------
function Test-GdapGraphConnection {

    $fn = 'Test-GdapGraphConnection'

    try {
        $ctx = Get-MgContext -ErrorAction Stop

        if ($null -eq $ctx -or [string]::IsNullOrWhiteSpace($ctx.Account)) {
            Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message 'No valid Graph connection found.'
            return $false
        }

        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Connected as '$($ctx.Account)'."
        return $true
    }
    catch {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Get-MgContext failed: $($_.Exception.Message)"
        return $false
    }
}

# ---------------------------------------------------------------------
# Ensure valid Graph connection
# ---------------------------------------------------------------------
function Ensure-GdapGraphConnection {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Scopes
    )

    $fn = 'Ensure-GdapGraphConnection'

    # Already connected?
    if (Test-GdapGraphConnection) {
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'Using existing Graph connection.'
        return
    }

    # Not connected — connect now
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Connecting with scopes: $($Scopes -join ', ')"

    try {
        Connect-MgGraph -Scopes $Scopes -NoWelcome
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message 'Connected to Microsoft Graph.'
    }
    catch {
        Write-GdapError -Script $Script:Name -Function $fn -Message "Failed to connect: $($_.Exception.Message)"
        throw
    }
}

# END OF FILE
