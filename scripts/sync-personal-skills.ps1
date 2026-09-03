[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CodexSkillsRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [string]$ConfigPath,
    [switch]$Copy,
    [switch]$ReplaceMismatchedJunction
)

. (Join-Path $PSScriptRoot 'skill-config.ps1')
$config = Get-SkillConfig -RepoRoot $RepoRoot -ConfigPath $ConfigPath
if (-not $PSBoundParameters.ContainsKey('CodexSkillsRoot')) {
    $CodexSkillsRoot = Resolve-SkillPath -PathValue $config.paths.codexSkillsRoot -RepoRoot $RepoRoot
}
$sourceRoot = Resolve-SkillPath -PathValue $config.paths.sourceRoot -RepoRoot $RepoRoot
$destinationRoot = Join-Path $CodexSkillsRoot 'personal'

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "Personal skill source was not found: $sourceRoot"
}

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null

Get-ChildItem -LiteralPath $sourceRoot -Directory | ForEach-Object {
    $sourcePath = $_.FullName
    $destinationPath = Join-Path $destinationRoot $_.Name

    if (-not $Copy) {
        if (Test-Path -LiteralPath $destinationPath) {
            $existing = Get-Item -LiteralPath $destinationPath -Force
            if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $existingTarget = [IO.Path]::GetFullPath(($existing.Target | Select-Object -First 1))
                $sourceFullPath = [IO.Path]::GetFullPath($sourcePath)
                if ($existingTarget.TrimEnd('\') -ieq $sourceFullPath.TrimEnd('\')) {
                    Write-Output "Already linked $destinationPath -> $sourcePath"
                    return
                }
                if (-not $ReplaceMismatchedJunction) {
                    throw "Junction target mismatch at $destinationPath. Confirm the migration, then rerun with -ReplaceMismatchedJunction."
                }
                Remove-Item -LiteralPath $destinationPath -Force
            }
            else {
                $backupPath = "$destinationPath.local-backup"
                if (Test-Path -LiteralPath $backupPath) {
                    throw "Backup path already exists: $backupPath"
                }
                Move-Item -LiteralPath $destinationPath -Destination $backupPath
            }
        }
        New-Item -ItemType Junction -Path $destinationPath -Target $sourcePath | Out-Null
        Write-Output "Linked $destinationPath -> $sourcePath"
    }
    else {
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force
        Write-Output "Copied $sourcePath -> $destinationPath"
    }
}
