<#
.SYNOPSIS
    Pull the live DSH profile files back into this repo for review.

.DESCRIPTION
    Copies the tracked files from the live desktop profile into <repo>\profile\
    so `git diff` shows exactly what DSH, the plugin manager or dsh-market
    changed.

    This script NEVER commits. The diff is the point: the market in particular
    rewrites cordis.patch.yml when a bundle is toggled, and it has already
    silently deleted the tavily-mcp disable override once (see README).

    Review, then commit here, then apply back if you reverted anything.

.NOTES
    Follows the E:\GitHubWorkspace\_workspace\scripts conventions.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Join-Path $PSScriptRoot '..' | Resolve-Path
$RepoProfile = Join-Path $RepoRoot 'profile'
$LiveProfile = Join-Path $env:USERPROFILE '.dsh\profiles\desktop'

if (-not (Test-Path -LiteralPath $LiveProfile)) {
    throw "Live profile not found: $LiveProfile"
}
if (-not (Test-Path -LiteralPath $RepoProfile)) {
    New-Item -ItemType Directory -Path $RepoProfile | Out-Null
}

$Files = @(
    'package.json',
    'cordis.patch.yml',
    'pnpm-lock.yaml',
    'pnpm-workspace.yaml',
    'cordis.yml'
)

Write-Host "live -> repo" -ForegroundColor Cyan
Write-Host "  from: $LiveProfile"
Write-Host "  to:   $RepoProfile"
Write-Host ''

$changed = @()

foreach ($name in $Files) {
    $src = Join-Path $LiveProfile $name
    $dst = Join-Path $RepoProfile $name

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "not present in the live profile, skipped: $name"
        continue
    }

    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path -LiteralPath $dst) {
        (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
    } else { $null }

    if ($srcHash -ne $dstHash) { $changed += $name }
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

if ($changed.Count -eq 0) {
    Write-Host 'No differences — the repo already matches the live profile.' -ForegroundColor Green
    return
}

Write-Host "differed ($($changed.Count)):" -ForegroundColor Yellow
foreach ($name in $changed) { Write-Host "  $name" }

Write-Host ''
Write-Host 'Review before committing:' -ForegroundColor Yellow
Write-Host "  git -C `"$RepoRoot`" diff"

# Surface the trap directly rather than trusting the reader to spot it.
$patch = Join-Path $RepoProfile 'cordis.patch.yml'
if (Test-Path -LiteralPath $patch) {
    $text = Get-Content -LiteralPath $patch -Raw
    if ($text -notmatch '(?m)^- id: tavily-mcp\s*\r?\n\s*disabled:\s*true') {
        Write-Host ''
        Write-Host 'WARNING: the "- id: tavily-mcp / disabled: true" override is MISSING.' -ForegroundColor Red
        Write-Host '         Tavily is now served twice (native + mcp-lazy) and the' -ForegroundColor Red
        Write-Host '         ~1706 tokens/request saving is lost. See README.' -ForegroundColor Red
    }
}
