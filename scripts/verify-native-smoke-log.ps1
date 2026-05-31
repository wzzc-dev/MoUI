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

$defaultStageMarkers = @(
  "native smoke surface descriptor backend",
  "native smoke canvas state restored",
  "native smoke canvas replay commands",
  "native smoke render resource plan count",
  "native smoke gpu context resource plan count",
  "native smoke shader draws",
  "native smoke shader resource plan count",
  "native smoke filter layer count",
  "native smoke filter resource plan count",
  "native smoke path verbs",
  "native smoke readback width",
  "native smoke bounded readback width",
  "native smoke bounded snapshot width",
  "native smoke encoded PNG bytes",
  "native smoke decoded image width",
  "native smoke codec encoded format PNG",
  "native smoke decoded bitmap width",
  "native smoke font spacing",
  "native smoke font resource plan count",
  "native smoke measured text width",
  "native smoke text glyph count",
  "native smoke first glyph id",
  "native smoke first glyph width",
  "native smoke second glyph position x",
  "native smoke second glyph x position",
  "native smoke first glyph bounds width",
  "native smoke measured text bounds width",
  "native smoke font family count",
  "native smoke first font family bytes",
  "native smoke typeface family bytes",
  "native smoke font fallback resource plan count",
  "native smoke font fallback width"
)
$stageMarkers = $defaultStageMarkers
$repoRoot = Split-Path -Parent $PSScriptRoot
$statusFile = Join-Path $repoRoot "skia-platform-status.json"
if (Test-Path -LiteralPath $statusFile -PathType Leaf) {
  $status = Get-Content -LiteralPath $statusFile -Raw | ConvertFrom-Json
  $statusStageMarkers = @($status.native_smoke_capabilities | ForEach-Object {
      "$($_.marker)".Trim()
    } | Where-Object {
      $_ -ne ""
    })
  if ($statusStageMarkers.Count -gt 0) {
    $stageMarkers = $statusStageMarkers
  }
}
foreach ($stageMarker in $stageMarkers) {
  if (!$content.Contains($stageMarker)) {
    throw "native smoke executable log is missing required stage marker: $stageMarker"
  }
}

Write-Host "Verified native smoke stage markers and success marker in $LogPath."
