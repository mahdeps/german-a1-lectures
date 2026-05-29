﻿﻿# Scans the 16 lecture folders, classifies files, stages small notes/PDFs,
# and emits manifest.json consumed by index.html.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$notesDir = Join-Path $root 'notes'
$pdfDir   = Join-Path $root 'pdf'
New-Item -ItemType Directory -Force -Path $notesDir | Out-Null
New-Item -ItemType Directory -Force -Path $pdfDir   | Out-Null

function Get-HtmlTitle($path) {
  try {
    $txt = Get-Content -Raw -Encoding UTF8 $path
    if ($txt -match '<title>\s*(.*?)\s*</title>') { return $Matches[1].Trim() }
  } catch {}
  return ''
}

function Format-Size($bytes) {
  if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
  if ($bytes -ge 1MB) { return ('{0:N0} MB' -f ($bytes / 1MB)) }
  return ('{0:N0} KB' -f ($bytes / 1KB))
}

$lectures = @()
$uploadMap = [ordered]@{}

$exclude = @(1)   # lectures to skip entirely

for ($n = 1; $n -le 16; $n++) {
  if ($exclude -contains $n) { continue }
  $folder = Join-Path $root ("المحاضرة $n")
  if (-not (Test-Path $folder)) { continue }
  $files = Get-ChildItem -File $folder
  $nn = '{0:D2}' -f $n

  $htmls = @($files | Where-Object { $_.Extension -ieq '.html' })
  $pdfs  = @($files | Where-Object { $_.Extension -ieq '.pdf' })
  $mp4s  = @($files | Where-Object { $_.Extension -ieq '.mp4' } | Sort-Object Length -Descending)
  $m4as  = @($files | Where-Object { $_.Extension -ieq '.m4a' })

  $downloads = @()  # release assets (big media)
  $notes = @()      # repo-hosted html
  $pdfList = @()    # repo-hosted pdf

  # ---- Topic title from primary html ----
  $primaryHtml = $htmls | Where-Object { $_.Name -match 'المحاضرة' } | Select-Object -First 1
  if (-not $primaryHtml) { $primaryHtml = $htmls | Sort-Object Length -Descending | Select-Object -First 1 }
  $topic = ''
  if ($primaryHtml) { $topic = Get-HtmlTitle $primaryHtml.FullName }

  # ---- Notes (html) -> notes/ ----
  $hi = 0
  foreach ($h in ($htmls | Sort-Object Length -Descending)) {
    $hi++
    $name = if ($hi -eq 1) { "lec$nn.html" } else { "lec$nn-$hi.html" }
    Copy-Item $h.FullName (Join-Path $notesDir $name) -Force
    $label = if ($hi -eq 1) { 'الملخص التفاعلي' } else { 'ملخص إضافي' }
    $t = Get-HtmlTitle $h.FullName
    $notes += [ordered]@{ label = $label; title = $t; path = "notes/$name" }
  }

  # ---- PDF -> pdf/ ----
  $pi = 0
  foreach ($p in $pdfs) {
    $pi++
    $name = if ($pi -eq 1) { "lec$nn.pdf" } else { "lec$nn-$pi.pdf" }
    Copy-Item $p.FullName (Join-Path $pdfDir $name) -Force
    $pdfList += [ordered]@{ label = 'ملف PDF'; path = "pdf/$name"; size = (Format-Size $p.Length) }
  }

  # ---- Smallest video only -> release (per user's choice; audio/extra videos skipped) ----
  $smallest = $mp4s | Sort-Object Length | Select-Object -First 1
  if ($smallest) {
    $asset = "L$nn-video.mp4"
    $downloads += [ordered]@{ label = 'الفيديو'; kind = 'video-main'; asset = $asset; size = (Format-Size $smallest.Length) }
    $uploadMap[$asset] = $smallest.FullName
    Write-Host ("  -> L{0:D2} smallest video: {1} ({2})" -f $n, $smallest.Name, (Format-Size $smallest.Length))
  }

  $lectures += [ordered]@{
    number    = $n
    topic     = $topic
    downloads = $downloads
    notes     = $notes
    pdf       = $pdfList
  }
}

$manifest = [ordered]@{
  site = [ordered]@{
    title    = 'German A1 - المحاضرات'
    subtitle = 'دورة اللغة الألمانية - المستوى A1'
    owner    = '__OWNER__'
    repo     = '__REPO__'
    tag      = '__TAG__'
  }
  lectures = $lectures
}

$json = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText((Join-Path $root 'manifest.json'), $json, (New-Object System.Text.UTF8Encoding($false)))

$mapJson = $uploadMap | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText((Join-Path $root 'upload-map.json'), $mapJson, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "manifest.json + upload-map.json written. Lectures: $($lectures.Count), assets: $($uploadMap.Count)"
foreach ($l in $lectures) {
  Write-Host ("  L{0:D2}  videos/audio={1}  notes={2}  pdf={3}  topic='{4}'" -f $l.number, $l.downloads.Count, $l.notes.Count, $l.pdf.Count, $l.topic)
}
