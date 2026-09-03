function Get-SkillConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string]$ConfigPath
    )

    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $RepoRoot 'nacos.config.json'
    }

    if (Test-Path -LiteralPath $ConfigPath) {
        return Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    }

    return [pscustomobject]@{
        repository = [pscustomobject]@{ url = ''; branch = 'main'; visibility = 'private'; status = 'not-configured' }
        paths = [pscustomobject]@{
            sourceRoot = 'skills/personal'
            codexSkillsRoot = '%USERPROFILE%/.codex/skills'
            backupRoot = '%USERPROFILE%/.codex/skill-link-backups'
        }
        linkType = 'junction'
    }
}

function Resolve-SkillPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue.Replace('/', '\'))
    if ([IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }
    return Join-Path $RepoRoot $expanded
}
