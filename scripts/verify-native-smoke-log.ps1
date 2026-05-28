param(
  [Parameter(Mandatory = $true)]
  [string] $LogPath,

  [string] $Marker = "skia_mbt native smoke test passed"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $LogPath)) {
  throw "native smoke executable log is missing: $LogPath"
}

$content = Get-Content -LiteralPath $LogPath -Raw
if (!$content.Contains($Marker)) {
  throw "native smoke executable log is missing the success marker: $Marker"
}

$stageMarkers = @(
  "native smoke readback width",
  "native smoke bounded readback width",
  "native smoke bounded snapshot width",
  "native smoke encoded PNG bytes",
  "native smoke decoded image width",
  "native smoke codec encoded format PNG",
  "native smoke decoded bitmap width"
)
foreach ($stageMarker in $stageMarkers) {
  if (!$content.Contains($stageMarker)) {
    throw "native smoke executable log is missing required stage marker: $stageMarker"
  }
}

Write-Host "Verified native smoke stage markers and success marker in $LogPath."
