# ---------------------------------------------------------------------
# GLOBAL LOG FILE (timestamped per run)
# ---------------------------------------------------------------------

$logFolder = "C:\Scripts\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# Create a unique log file per run (timestamp to second)
$logTimestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$Global:GdapLogFile = Join-Path $logFolder ("gdap_{0}.log" -f $logTimestamp)

function Write-GdapLog {
    param(
        [string]$Level,
        [string]$Script,
        [string]$Function,
        [string]$Message
    )

    $t = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$t][$Level][$Script][$Function] $Message"

    # Console output
    Write-Host $line

    # Append to per-run log file
    Add-Content -Path $Global:GdapLogFile -Value $line
}

function Write-GdapError {
    param(
        [string]$Script,
        [string]$Function,
        [string]$Message
    )

    Write-GdapLog -Level 'ERROR' -Script $Script -Function $Function -Message $Message
}
