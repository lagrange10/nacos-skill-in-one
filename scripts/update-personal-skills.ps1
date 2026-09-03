[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CodexSkillsRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [switch]$Copy
)

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($gitCommand) {
    $git = $gitCommand.Source
}
else {
    $gitCandidates = @(
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Users\tao.chen\AppData\Local\Programs\Git\cmd\git.exe',
        'E:\Program Files\Git\cmd\git.exe'
    )
    $git = $gitCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $git) {
    throw 'Git executable was not found.'
}

& $git -C $RepoRoot pull --ff-only
if ($LASTEXITCODE -ne 0) {
    throw 'Fast-forward update failed. Resolve local changes before syncing.'
}

$syncScript = Join-Path $PSScriptRoot 'sync-personal-skills.ps1'
& $syncScript -RepoRoot $RepoRoot -CodexSkillsRoot $CodexSkillsRoot -Copy:$Copy

$validateScript = Join-Path $PSScriptRoot 'validate-skill-links.ps1'
& $validateScript -RepoRoot $RepoRoot -CodexSkillsRoot $CodexSkillsRoot
