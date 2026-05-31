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
  "native smoke render frame resource plan count",
  "native smoke render frame validation status",
  "native smoke render frame cache resources",
  "native smoke render resource cache inserts",
  "native smoke gpu context resource plan count",
  "native smoke gpu frame context validation",
  "native smoke surface target resource plan count",
  "native smoke window target resource plan count",
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
  "native smoke text run resource plan count",
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
  "native smoke font fallback font resource plan count",
  "native smoke font fallback width"
)
$defaultExpectedStageValues = @(
  [pscustomobject]@{
    Marker = "native smoke render resource plan count"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame resource plan count"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame validation status"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame cache resources"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache inserts"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu context resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame context validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface target resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke window target resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke shader draws"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke shader resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke filter resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke text run resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke font resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback font resource plan count"
    Value = "2"
  }
)
$stageMarkers = $defaultStageMarkers
$expectedStageValues = $defaultExpectedStageValues
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
  $statusExpectedStageValues = @($status.native_smoke_expected_values | ForEach-Object {
      $marker = "$($_.marker)".Trim()
      $value = "$($_.value)".Trim()
      if ($marker -ne "" -and $value -ne "") {
        [pscustomobject]@{
          Marker = $marker
          Value = $value
        }
      }
    })
  if ($statusExpectedStageValues.Count -gt 0) {
    $expectedStageValues = $statusExpectedStageValues
  }
}
foreach ($stageMarker in $stageMarkers) {
  if (!$content.Contains($stageMarker)) {
    throw "native smoke executable log is missing required stage marker: $stageMarker"
  }
}

function Get-MarkerValue {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Marker
  )

  $lines = Get-Content -LiteralPath $LogPath
  for ($index = 0; $index -lt $lines.Count; $index += 1) {
    if ($lines[$index].Trim() -eq $Marker) {
      if ($index + 1 -ge $lines.Count) {
        throw "native smoke executable log marker has no value: $Marker"
      }
      return $lines[$index + 1].Trim()
    }
  }
  throw "native smoke executable log is missing exact stage marker line: $Marker"
}

foreach ($expectedStageValue in $expectedStageValues) {
  $actualValue = Get-MarkerValue -Marker $expectedStageValue.Marker
  if ($actualValue -ne $expectedStageValue.Value) {
    throw "native smoke executable log has unexpected stage marker value: $($expectedStageValue.Marker) expected=$($expectedStageValue.Value) actual=$actualValue"
  }
}

Write-Host "Verified native smoke stage markers and success marker in $LogPath."
