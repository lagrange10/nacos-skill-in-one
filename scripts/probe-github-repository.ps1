[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryUrl,
    [int]$TimeoutSeconds = 8
)

$ErrorActionPreference = 'Stop'
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $git = @(
        'C:\Program Files\Git\cmd\git.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'),
        'E:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $git) {
    throw 'Git executable was not found.'
}

$process = [Diagnostics.Process]::new()
$process.StartInfo = [Diagnostics.ProcessStartInfo]::new()
$process.StartInfo.FileName = $git
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.RedirectStandardError = $true
$process.StartInfo.ArgumentList.Add('ls-remote')
$process.StartInfo.ArgumentList.Add('--heads')
$process.StartInfo.ArgumentList.Add($RepositoryUrl)
$startedAt = [DateTime]::UtcNow
$process.Start() | Out-Null
$finished = $process.WaitForExit([Math]::Max(1, $TimeoutSeconds) * 1000)

if (-not $finished) {
    $process.Kill()
    [pscustomobject]@{
        reachable = $false
        status = 'timeout'
        repositoryUrl = $RepositoryUrl
        checkedAtUtc = [DateTime]::UtcNow.ToString('o')
        elapsedMs = ([DateTime]::UtcNow - $startedAt).TotalMilliseconds
    } | ConvertTo-Json -Compress
    exit 2
}

$stderr = $process.StandardError.ReadToEnd().Trim()
[pscustomobject]@{
    reachable = ($process.ExitCode -eq 0)
    status = if ($process.ExitCode -eq 0) { 'reachable' } else { 'unreachable' }
    repositoryUrl = $RepositoryUrl
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    elapsedMs = ([DateTime]::UtcNow - $startedAt).TotalMilliseconds
    detail = if ($process.ExitCode -eq 0) { '' } else { $stderr }
} | ConvertTo-Json -Compress
if ($process.ExitCode -ne 0) { exit 2 }
