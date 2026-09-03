[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$OldName,
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$NewName,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CodexSkillsRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'skill-config.ps1')
$config = Get-SkillConfig -RepoRoot $RepoRoot -ConfigPath $ConfigPath
if (-not $PSBoundParameters.ContainsKey('CodexSkillsRoot')) {
    $CodexSkillsRoot = Resolve-SkillPath -PathValue $config.paths.codexSkillsRoot -RepoRoot $RepoRoot
}

if ($OldName -eq $NewName) {
    throw 'OldName and NewName must be different.'
}

$sourceRoot = Resolve-SkillPath -PathValue $config.paths.sourceRoot -RepoRoot $RepoRoot
$oldSource = Join-Path $sourceRoot $OldName
$newSource = Join-Path $sourceRoot $NewName
$destinationRoot = Join-Path $CodexSkillsRoot 'personal'
$oldLink = Join-Path $destinationRoot $OldName
$newLink = Join-Path $destinationRoot $NewName
$backupRoot = Resolve-SkillPath -PathValue $config.paths.backupRoot -RepoRoot $RepoRoot

if (-not (Test-Path -LiteralPath $oldSource)) {
    throw "Source skill was not found: $oldSource"
}
if (Test-Path -LiteralPath $newSource) {
    throw "Destination skill already exists: $newSource"
}
if (Test-Path -LiteralPath $newLink) {
    throw "Destination discovery path already exists: $newLink"
}

Move-Item -LiteralPath $oldSource -Destination $newSource

$skillFile = Join-Path $newSource 'SKILL.md'
if (Test-Path -LiteralPath $skillFile) {
    $content = Get-Content -LiteralPath $skillFile -Raw
    $content = $content -replace "(?m)^name:\s*$([regex]::Escape($OldName))\s*$", "name: $NewName"
    Set-Content -LiteralPath $skillFile -Value $content -Encoding utf8NoBOM
}

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
if (Test-Path -LiteralPath $oldLink) {
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $backupPath = Join-Path $backupRoot $OldName
    if (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $backupRoot ($OldName + '-' + (Get-Date -Format 'yyyyMMddHHmmss'))
    }
    Move-Item -LiteralPath $oldLink -Destination $backupPath
    Write-Output "Backed up $oldLink -> $backupPath"
}

New-Item -ItemType Junction -Path $newLink -Target $newSource | Out-Null
Write-Output "Renamed $oldSource -> $newSource"
Write-Output "Linked $newLink -> $newSource"
