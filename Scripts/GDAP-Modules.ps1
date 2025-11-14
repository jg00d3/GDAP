<#
.SYNOPSIS
    Module and dependency checker for the GDAP export toolset.

.DESCRIPTION
    This script ensures that only the minimal required Microsoft Graph
    components are installed for proper GDAP operation. It avoids the
    heavy full Graph SDK installation and instead installs only:

      - Microsoft.Graph.Authentication
      - Microsoft.Graph.Beta
      - ImportExcel

    It also supports optional modules:
      - Microsoft.Graph.Beta.RoleManagement
      - Microsoft.Graph.Beta.Identity.Partner

    The script provides:
      • A consistent logging system (INFO, OK, WARN, ERROR)
      • A default action (A) to install missing modules
      • ENTER = automatic selection of option A
      • Detailed prompts and guidance
      • Error tagging per script/function for easier debugging

.NOTES
    Author: ChatGPT (Umetech Automation Suite)
    File  : GDAP-Modules.ps1
#>

# ---------------------------------------------------------------------
# Script identity (used in all log messages)
# ---------------------------------------------------------------------
$Script:Name = 'GDAP-Modules.ps1'


# ---------------------------------------------------------------------
# Logging utilities
# ---------------------------------------------------------------------

function Write-GdapLog {
    <#
    .SYNOPSIS
        Writes a standardized log line to the PowerShell console.

    .PARAMETER Level
        Log severity: INFO, OK, WARN, ERROR.

    .PARAMETER Script
        Script name producing the log.

    .PARAMETER Function
        Function name producing the log.

    .PARAMETER Message
        Human-readable log message.
    #>

    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Function,
        [Parameter(Mandatory)][string]$Message
    )

    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$time][$Level][$Script][$Function] $Message"
}


function Write-GdapError {
    <#
    .SYNOPSIS
        Writes a standardized error message with “ERROR” level.
    #>

    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Function,
        [Parameter(Mandatory)][string]$Message
    )

    Write-GdapLog -Level 'ERROR' -Script $Script -Function $Function -Message $Message
}


# ---------------------------------------------------------------------
# Helper: Determine whether a module is installed
# ---------------------------------------------------------------------

function Test-GdapModuleInstalled {
    <#
    .SYNOPSIS
        Returns $true if the specified PowerShell module exists locally.
    #>

    param([Parameter(Mandatory)][string]$Name)

    return [bool](Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)
}


# ---------------------------------------------------------------------
# Helper: Ensure a specific module is present
# ---------------------------------------------------------------------

function Ensure-GdapModule {
    <#
    .SYNOPSIS
        Ensures that a PowerShell module is installed and imported.

    .DESCRIPTION
        This function checks if the module exists locally. If missing,
        the user is prompted with three choices:

            [A] Install the module now (default)
            [B] Skip (not recommended for required modules)
            [C] Abort script

        Pressing ENTER automatically chooses [A].

    .PARAMETER Name
        Module name to check/install.

    .PARAMETER Required
        If $true, skipping is discouraged.
    #>

    param(
        [Parameter(Mandatory)][string]$Name,
        [bool]$Required = $true
    )

    $fn = 'Ensure-GdapModule'

    # Already installed?
    if (Test-GdapModuleInstalled -Name $Name) {
        Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Module '${Name}' found."
        try { Import-Module $Name -ErrorAction SilentlyContinue }
        catch { Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Module '${Name}' found but failed to import: $($_.Exception.Message)" }
        return $true
    }

    # Optional module missing?
    if (-not $Required) {
        Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Optional module '${Name}' not found. Continuing without it."
        return $false
    }

    # Required module missing
    Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Required module '${Name}' missing."

    Write-Host ""
    Write-Host "Module '${Name}' options:"
    Write-Host "  [A] Install the module now (this may take a few minutes to download and install)"
    Write-Host "  [B] Skip and continue (not recommended)"
    Write-Host "  [C] Abort script"
    Write-Host ""
    Write-Host "Press ENTER to choose the default option [A]."
    Write-Host ""

    while ($true) {

        # Get user choice; ENTER = A
        $choice = Read-Host -Prompt "Choose an option (A/B/C)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'A' }
        $choice = $choice.ToUpper()

        switch ($choice) {

            'A' {
                # Install module
                try {
                    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Installing module '${Name}'..."
                    Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -AcceptLicense -ErrorAction Stop
                    Import-Module $Name -ErrorAction Stop
                    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Module '${Name}' installed successfully."
                    return $true
                }
                catch {
                    Write-GdapError -Script $Script:Name -Function $fn -Message "Install failed for '${Name}': $($_.Exception.Message)"
                    return $false
                }
            }

            'B' {
                Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "User skipped installation of '${Name}'."
                return $false
            }

            'C' {
                Write-GdapError -Script $Script:Name -Function $fn -Message "User aborted due to missing module '${Name}'."
                throw "Aborted because required module '${Name}' is missing."
            }

            default {
                Write-GdapLog -Level 'WARN' -Script $Script:Name -Function $fn -Message "Invalid selection. Please use A, B, or C."
            }
        }
    }
}


# ---------------------------------------------------------------------
# Main module check (called by GDAP-Export.ps1)
# ---------------------------------------------------------------------

function Ensure-GdapModules {
    <#
    .SYNOPSIS
        Checks all required and optional modules for GDAP operations.
    #>

    $fn = 'Ensure-GdapModules'
    Write-GdapLog -Level 'INFO' -Script $Script:Name -Function $fn -Message "Checking minimal required Graph modules..."

    #
    # Minimal required modules (Option B — lightweight installation)
    #
    $required = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Beta'
        'ImportExcel'
    )

    #
    # Optional but recommended modules
    #
    $optional = @(
        'Microsoft.Graph.Beta.RoleManagement'
        'Microsoft.Graph.Beta.Identity.Partner'
    )

    # Process required modules
    foreach ($name in $required) {
        [void](Ensure-GdapModule -Name $name -Required:$true)
    }

    # Process optional modules
    foreach ($name in $optional) {
        [void](Ensure-GdapModule -Name $name -Required:$false)
    }

    Write-GdapLog -Level 'OK' -Script $Script:Name -Function $fn -Message "Module check completed."
}

# END OF FILE
