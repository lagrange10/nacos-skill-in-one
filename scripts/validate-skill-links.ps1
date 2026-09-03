[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CodexSkillsRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [string]$ConfigPath,
    [switch]$Strict
)

. (Join-Path $PSScriptRoot 'skill-config.ps1')
$config = Get-SkillConfig -RepoRoot $RepoRoot -ConfigPath $ConfigPath
if (-not $PSBoundParameters.ContainsKey('CodexSkillsRoot')) {
    $CodexSkillsRoot = Resolve-SkillPath -PathValue $config.paths.codexSkillsRoot -RepoRoot $RepoRoot
}
$manifestPath = Join-Path $RepoRoot 'skill-links.json'
$sourceRoot = Resolve-SkillPath -PathValue $config.paths.sourceRoot -RepoRoot $RepoRoot
$destinationRoot = Join-Path $CodexSkillsRoot 'personal'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Skill link manifest was not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "Personal skill source was not found: $sourceRoot"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$localOnly = @($manifest.localOnlySkills)
$errors = [System.Collections.Generic.List[string]]::new()
$sourceNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null

Get-ChildItem -LiteralPath $sourceRoot -Directory | ForEach-Object {
    $sourcePath = $_.FullName
    $destinationPath = Join-Path $destinationRoot $_.Name
    $sourceNames.Add($_.Name) | Out-Null

    if (-not (Test-Path -LiteralPath $destinationPath)) {
        $errors.Add("Missing link: $destinationPath")
        return
    }

    $destination = Get-Item -LiteralPath $destinationPath -Force
    if (-not ($destination.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $errors.Add("普通副本不是唯一信源: $destinationPath")
        return
    }

    $actualTarget = ([string]$destination.Target).TrimEnd('\')
    $expectedTarget = (Resolve-Path -LiteralPath $sourcePath).Path.TrimEnd('\')
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($actualTarget, $expectedTarget)) {
        $errors.Add("错误链接: $destinationPath -> $actualTarget; expected $expectedTarget")
    }
}

if (Test-Path -LiteralPath $destinationRoot) {
    Get-ChildItem -LiteralPath $destinationRoot -Directory -Force | ForEach-Object {
        if (-not $sourceNames.Contains($_.Name) -and $localOnly -notcontains $_.Name) {
            $errors.Add("仓库外 Skill 未登记: $($_.FullName)")
        }
    }
}

foreach ($legacy in @($manifest.legacyPaths)) {
    $expanded = $legacy.Replace('%USERPROFILE%', $env:USERPROFILE)
    if (Test-Path -LiteralPath $expanded) {
        $errors.Add("旧发现入口仍存在: $expanded")
    }
}

if ($errors.Count -eq 0) {
    Write-Output "Skill link validation passed."
    exit 0
}

Write-Warning "Skill link validation found $($errors.Count) issue(s)."
foreach ($errorItem in $errors) {
    Write-Warning "  $errorItem"
}

if ($Strict) {
    exit 1
}
