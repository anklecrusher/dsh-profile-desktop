<#
.SYNOPSIS
    Push the reviewed profile files from this repo into the live DSH profile.

.DESCRIPTION
    Copies the tracked files from <repo>\profile\ into the live desktop profile
    directory. Run this after editing here, or after `git checkout` to roll a
    bad change back.

    The live profile is never committed from here and this script never commits
    anything. It backs up the files it overwrites so a mistake is still
    recoverable outside git.

    Restart the desktop app afterwards: dsh.profile.bundles is read at boot.

.NOTES
    Follows the E:\GitHubWorkspace\_workspace\scripts conventions: plain
    PowerShell, explicit paths, no implicit working directory.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Join-Path $PSScriptRoot '..' | Resolve-Path
$RepoProfile = Join-Path $RepoRoot 'profile'
$LiveProfile = Join-Path $env:USERPROFILE '.dsh\profiles\desktop'

if (-not (Test-Path -LiteralPath $LiveProfile)) {
    throw "Live profile not found: $LiveProfile"
}

# The five files this repo tracks. Anything else in the live profile is DSH's
# own business and is deliberately left alone.
$Files = @(
    'package.json',
    'cordis.patch.yml',
    'pnpm-lock.yaml',
    'pnpm-workspace.yaml',
    'cordis.yml'
)

# Tracked outside the profile directory: the user-global instruction file.
# dsh-agent-instructions reads join($DSH_HOME, 'AGENTS.md'), which applies to
# every session in every workspace, so it is the highest-leverage file here.
$GlobalFiles = @{ 'AGENTS.md' = (Join-Path $env:USERPROFILE '.dsh\AGENTS.md') }

Write-Host "repo -> live" -ForegroundColor Cyan
Write-Host "  from: $RepoProfile"
Write-Host "  to:   $LiveProfile"
Write-Host ''

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$changed = @()
$same = @()

foreach ($name in $Files) {
    $src = Join-Path $RepoProfile $name
    $dst = Join-Path $LiveProfile $name

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "missing in repo, skipped: $name"
        continue
    }

    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path -LiteralPath $dst) {
        (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
    } else { $null }

    if ($srcHash -eq $dstHash) {
        $same += $name
        continue
    }

    if (Test-Path -LiteralPath $dst) {
        Copy-Item -LiteralPath $dst -Destination "$dst.applybak-$stamp" -Force
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $changed += $name
}

# The user-global instruction file, which lives beside the profiles rather than
# inside one. Same copy-and-hash approach; no backup file is written because a
# stale copy here would itself be picked up as instructions.
foreach ($name in $GlobalFiles.Keys) {
    $src = Join-Path (Join-Path $RepoRoot 'global') $name
    $dst = $GlobalFiles[$name]

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "missing in repo, skipped: $name (global)"
        continue
    }

    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path -LiteralPath $dst) {
        (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
    } else { $null }

    if ($srcHash -eq $dstHash) { $same += "$name (global)"; continue }

    Copy-Item -LiteralPath $src -Destination $dst -Force
    $changed += "$name (global)"
}

Write-Host "updated ($($changed.Count)):" -ForegroundColor Green
if ($changed.Count -eq 0) { Write-Host '  (nothing differed)' }
foreach ($name in $changed) { Write-Host "  $name" }

Write-Host ''
Write-Host "unchanged ($($same.Count)):" -ForegroundColor DarkGray
foreach ($name in $same) { Write-Host "  $name" -ForegroundColor DarkGray }

Write-Host ''
Write-Host 'Restart the DeepSeek Harness desktop app to load new bundles.' -ForegroundColor Yellow
