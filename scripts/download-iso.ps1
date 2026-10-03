# =============================================================================
# download-iso.ps1 - fetch, reassemble and verify a KAAL OS ISO on Windows.
# The ISO is published as several parts, each under GitHub's 2 GiB per-file
# limit.
#
# Usage:
#   irm https://raw.githubusercontent.com/pujariseema93-beep/kaal-os/main/scripts/download-iso.ps1 | iex
#   (or, with a tag)  .\download-iso.ps1 -Tag v0.0.1-testiso
#
# Steps: read MANIFEST.txt -> download parts -> verify each part -> join the
# parts into the ISO -> verify the ISO's own SHA-256.
# =============================================================================
param([string]$Tag = "latest")

$ErrorActionPreference = "Stop"
$Repo = "pujariseema93-beep/kaal-os"

if ($Tag -eq "latest") {
    Write-Host "==> Looking up the newest release..."
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers @{ "User-Agent" = "kaal-os-download" }
    if (-not $rel -or $rel.Count -eq 0) { throw "No release found. Pass -Tag v0.0.1-testiso" }
    $Tag = $rel[0].tag_name
}

$Base = "https://github.com/$Repo/releases/download/$Tag"
$Work = Join-Path (Get-Location) "kaal-os-iso"
New-Item -ItemType Directory -Force -Path $Work | Out-Null
Set-Location $Work

Write-Host "==> Release: $Tag"
Write-Host "==> Fetching MANIFEST.txt..."
Invoke-WebRequest -Uri "$Base/MANIFEST.txt" -OutFile "MANIFEST.txt" -UseBasicParsing

$lines   = Get-Content "MANIFEST.txt"
$isoName = ($lines | Where-Object { $_ -like "iso=*" })    -replace "^iso=", ""
$isoSha  = ($lines | Where-Object { $_ -like "sha256=*" }) -replace "^sha256=", ""
$partList = @($lines | Where-Object { $_ -like "part=*" } | ForEach-Object { $_ -replace "^part=", "" })

if (-not $isoName -or -not $isoSha -or $partList.Count -eq 0) { throw "MANIFEST.txt is missing or malformed." }
Write-Host "==> ISO: $isoName ($($partList.Count) parts)"

Write-Host "==> Downloading parts..."
foreach ($p in $partList) {
    if (Test-Path $p) { Write-Host "    $p (already present, skipping)"; continue }
    Write-Host "    $p"
    Invoke-WebRequest -Uri "$Base/$p" -OutFile $p -UseBasicParsing
}

Write-Host "==> Verifying part checksums..."
Invoke-WebRequest -Uri "$Base/SHA256SUMS" -OutFile "SHA256SUMS" -UseBasicParsing
foreach ($line in Get-Content "SHA256SUMS") {
    if (-not $line.Trim()) { continue }
    $fields = $line -split '\s+', 2
    $want = $fields[0].ToLower()
    $file = $fields[1].Trim()
    $got = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLower()
    if ($got -ne $want) { throw "Checksum mismatch for $file - download again." }
    Write-Host "    OK  $file"
}

Write-Host "==> Reassembling the ISO..."
$outPath = Join-Path (Get-Location) $isoName
$outStream = [System.IO.File]::Create($outPath)
try {
    foreach ($p in $partList) {
        $inStream = [System.IO.File]::OpenRead((Join-Path (Get-Location) $p))
        try { $inStream.CopyTo($outStream) } finally { $inStream.Close() }
    }
} finally { $outStream.Close() }

Write-Host "==> Verifying the ISO checksum..."
$got = (Get-FileHash -Algorithm SHA256 -Path $isoName).Hash.ToLower()
if ($got -ne $isoSha.ToLower()) { throw "ISO checksum mismatch - download again." }

Write-Host ""
Write-Host "====================================================================="
Write-Host " DONE - $isoName is verified and ready."
Write-Host ""
Write-Host " Write it to a USB stick (16 GB recommended) with Rufus (rufus.ie)"
Write-Host " or balenaEtcher. Nothing is installed on your PC."
Write-Host "====================================================================="
