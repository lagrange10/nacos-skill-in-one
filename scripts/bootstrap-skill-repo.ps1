[CmdletBinding()]
param(
    [string]$RepositoryUrl,
    [Parameter(Mandatory = $true)]
    [string]$LocalRoot,
    [string]$Branch = 'main',
    [string]$GitHubName,
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',
    [switch]$CreateGitHubRepository,
    [switch]$Offline,
    [int]$ProbeTimeoutSeconds = 8
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

$LocalRoot = [IO.Path]::GetFullPath($LocalRoot)
$configPath = Join-Path $LocalRoot 'nacos.config.json'
$remoteStatus = if ($Offline) { 'pending' } elseif ($RepositoryUrl) { 'unknown' } else { 'local-only' }

if ($RepositoryUrl -and -not $Offline) {
    $probeScript = Join-Path $PSScriptRoot 'probe-github-repository.ps1'
    $probe = (& $probeScript -RepositoryUrl $RepositoryUrl -TimeoutSeconds $ProbeTimeoutSeconds | ConvertFrom-Json)
    if (-not $probe.reachable) {
        Write-Warning "GitHub repository is not reachable ($($probe.status))."
        Write-Output 'No clone or overwrite was attempted.'
        Write-Output 'Options: verify VPN/proxy and rerun; use a reachable mirror URL; or rerun with -Offline to prepare a local-only repository.'
        exit 2
    }
    $remoteStatus = 'verified'
}

if ($RepositoryUrl -and -not $Offline) {
    if (Test-Path -LiteralPath (Join-Path $LocalRoot '.git')) {
        & $git -C $LocalRoot pull --ff-only
    }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LocalRoot) | Out-Null
        & $git clone --branch $Branch $RepositoryUrl $LocalRoot
    }
}
else {
    New-Item -ItemType Directory -Force -Path $LocalRoot | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $LocalRoot '.git'))) {
        & $git -C $LocalRoot init -b $Branch
    }
    if ($CreateGitHubRepository) {
        if (-not $GitHubName) {
            throw 'GitHubName is required with -CreateGitHubRepository.'
        }
        $gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
        if (-not $gh) {
            throw 'GitHub CLI (gh) was not found. Create the repository first, then rerun with -RepositoryUrl.'
        }
        & $gh repo create $GitHubName "--$Visibility" --source $LocalRoot --remote origin --push
    }
}

$sourceRoot = Join-Path $LocalRoot 'skills\personal'
New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null

if (-not (Test-Path -LiteralPath $configPath)) {
    $config = [ordered]@{
        repository = [ordered]@{ url = $RepositoryUrl; branch = $Branch; visibility = $Visibility; status = $remoteStatus }
        paths = [ordered]@{
            sourceRoot = 'skills/personal'
            codexSkillsRoot = '%USERPROFILE%/.codex/skills'
            backupRoot = '%USERPROFILE%/.codex/skill-link-backups'
        }
        linkType = 'junction'
    }
    $config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding utf8NoBOM
}

Write-Output "Skill repository ready: $LocalRoot"
Write-Output "Config: $configPath"
Write-Output "Next: run scripts/update-personal-skills.ps1 from this repository."
