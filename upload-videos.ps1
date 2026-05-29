﻿# Uploads all big video/audio files to a GitHub Release as clean-named assets.
# Reads upload-map.json (asset -> local source path) and manifest.json (repo/tag).
# Uses NTFS hardlinks so nothing is duplicated on disk. Safe to re-run (skips done).
# Note: keep ErrorActionPreference at Continue. With 'Stop', PowerShell 5.1 wraps
# native gh stderr as a terminating error and aborts mid-run.
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'manifest.json') | ConvertFrom-Json
$map      = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'upload-map.json') | ConvertFrom-Json
$repo = "$($manifest.site.owner)/$($manifest.site.repo)"
$tag  = $manifest.site.tag

if ($repo -match '__' -or $tag -match '__') {
  Write-Error "manifest.json still has placeholders. Run the deploy step first to fill owner/repo/tag."
  exit 1
}

$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { Write-Error "GitHub CLI (gh) not found in PATH."; exit 1 }

Write-Host "Repo: $repo   Tag: $tag" -ForegroundColor Cyan

# Ensure the release exists
& gh release view $tag --repo $repo *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Creating release $tag ..." -ForegroundColor Yellow
  & gh release create $tag --repo $repo --title "محاضرات German A1" --notes "ملفات الفيديو والصوت لجميع المحاضرات. حمّلها من الموقع."
}

# Existing assets (to skip already-uploaded)
$existing = @{}
try {
  (& gh release view $tag --repo $repo --json assets | ConvertFrom-Json).assets |
    ForEach-Object { $existing[$_.name] = $true }
} catch {}

$stage = Join-Path $root '.upload-stage'
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$assets = $map.PSObject.Properties
$total = $assets.Count
$i = 0
foreach ($a in $assets) {
  $i++
  $asset = $a.Name
  $src   = $a.Value
  if ($existing.ContainsKey($asset)) {
    Write-Host "[$i/$total] SKIP (already uploaded): $asset" -ForegroundColor DarkGray
    continue
  }
  if (-not (Test-Path $src)) {
    Write-Host "[$i/$total] MISSING source, skipping: $asset" -ForegroundColor Red
    continue
  }
  $link = Join-Path $stage $asset
  if (Test-Path $link) { Remove-Item $link -Force }
  New-Item -ItemType HardLink -Path $link -Value $src | Out-Null

  $sizeMB = [math]::Round((Get-Item $src).Length/1MB)
  Write-Host "[$i/$total] Uploading $asset ($sizeMB MB) ..." -ForegroundColor Green
  & gh release upload $tag $link --repo $repo --clobber
  if ($LASTEXITCODE -ne 0) { Write-Host "  ! failed: $asset (re-run the script to retry)" -ForegroundColor Red }
  Remove-Item $link -Force -ErrorAction SilentlyContinue
}

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Done. All assets processed." -ForegroundColor Cyan
