param(
  [Parameter(Mandatory = $true)]
  [string] $LogPath,

  [string] $Marker = "skia_mbt native smoke test passed"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $LogPath)) {
  throw "native smoke executable log is missing: $LogPath"
}

$lines = @(Get-Content -LiteralPath $LogPath)

function Test-ExactLogLine {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Expected
  )

  foreach ($line in $lines) {
    if ($line.Trim() -eq $Expected) {
      return $true
    }
  }
  return $false
}

if (!(Test-ExactLogLine -Expected $Marker)) {
  throw "native smoke executable log is missing the success marker: $Marker"
}

$defaultStageMarkers = @(
  "native smoke surface descriptor backend",
  "native smoke surface target factory raster",
  "native smoke surface target factory unsupported",
  "native smoke surface target support diagnostics",
  "native smoke canvas state restored",
  "native smoke canvas clip device width",
  "native smoke non-finite canvas direct geometry skipped",
  "native smoke non-finite canvas paint layer sanitized",
  "native smoke canvas replay commands",
  "native smoke render frame replay commands",
  "native smoke render frame replay complete",
  "native smoke canvas replay status contract",
  "native smoke canvas replay transforms",
  "native smoke canvas replay state stats",
  "native smoke canvas replay resource declarations",
  "native smoke canvas replay image resources",
  "native smoke canvas replay shader resources",
  "native smoke canvas replay filter resources",
  "native smoke canvas replay path resources",
  "native smoke canvas replay text resources",
  "native smoke canvas replay rrect path clips",
  "native smoke canvas replay clip path cache resources",
  "native smoke empty path replay path cache resources",
  "native smoke empty path replay path resources",
  "native smoke empty path replay path cache misses",
  "native smoke empty path replay path cache hits",
  "native smoke non-finite path replay skipped",
  "native smoke non-finite path replay path resources",
  "native smoke non-finite path replay path cache resources",
  "native smoke non-finite path replay path cache misses",
  "native smoke non-finite path replay path cache hits",
  "native smoke canvas replay color paint fills",
  "native smoke canvas replay paint fill clipped",
  "native smoke canvas replay paint shader fills",
  "native smoke canvas replay paint shader cache resources",
  "native smoke render frame replay rejected skipped",
  "native smoke surface render frame commands",
  "native smoke surface render frame finalized",
  "native smoke surface render frame status contract",
  "native smoke surface render frame finalization frame index",
  "native smoke surface render frame finalization resource plan count",
  "native smoke surface render frame finalization cacheable count",
  "native smoke surface render frame finalization uncacheable count",
  "native smoke surface render frame cache resources",
  "native smoke native replay resource stats caches",
  "native smoke native replay resource stats resources",
  "native smoke surface render frame mismatch rejected",
  "native smoke render frame pixmap sample proof",
  "native smoke render shaped glyph run command replay",
  "native smoke render shader cache resources",
  "native smoke render shader cache misses",
  "native smoke render shader cache hits",
  "native smoke render path cache resources",
  "native smoke render path cache misses",
  "native smoke render path cache hits",
  "native smoke render text run cache resources",
  "native smoke render text run cache misses",
  "native smoke render text run cache hits",
  "native smoke render font cache resources",
  "native smoke render font cache misses",
  "native smoke render font cache hits",
  "native smoke render typeface cache resources",
  "native smoke render typeface cache misses",
  "native smoke render typeface cache hits",
  "native smoke render color filter cache resources",
  "native smoke render color filter cache misses",
  "native smoke render color filter cache hits",
  "native smoke render image filter cache resources",
  "native smoke render image filter cache misses",
  "native smoke render image filter cache hits",
  "native smoke render mask filter cache resources",
  "native smoke render mask filter cache misses",
  "native smoke render mask filter cache hits",
  "native smoke render resource plan count",
  "native smoke render frame resource plan count",
  "native smoke render frame validation status",
  "native smoke render frame cacheable subplan count",
  "native smoke render frame uncacheable subplan count",
  "native smoke render frame unbalanced validation",
  "native smoke render target identity validation",
  "native smoke render target resource binding",
  "native smoke render frame present count",
  "native smoke render frame present descriptor validation",
  "native smoke render frame submission resource plan count",
  "native smoke render frame submission cacheable subplan count",
  "native smoke render frame submission uncacheable subplan count",
  "native smoke render frame submission preflight missing count",
  "native smoke render frame submission preflight cached count",
  "native smoke render frame submission cache resources",
  "native smoke render frame finalization resource plan count",
  "native smoke render frame finalization cacheable subplan count",
  "native smoke render frame finalization uncacheable subplan count",
  "native smoke render frame finalization preflight missing count",
  "native smoke render frame finalization preflight cached count",
  "native smoke render frame finalization cache resources",
  "native smoke render frame missing present validation",
  "native smoke render frame missing finalization validation",
  "native smoke render frame touched bounds width",
  "native smoke canvas replay deferred present",
  "native smoke render frame cache resources",
  "native smoke render resource cache inserts",
  "native smoke render resource cache preflight missing count",
  "native smoke render resource cache preflight cached count",
  "native smoke render resource cache plan coverage",
  "native smoke render resource cache evictions",
  "native smoke render resource cache hits",
  "native smoke render resource cache misses",
  "native smoke render resource cache byte size",
  "native smoke gpu context resource plan count",
  "native smoke gpu context key variation",
  "native smoke gpu frame context validation",
  "native smoke gpu present resource plan count",
  "native smoke gpu finalization resource plan count",
  "native smoke gpu frame finalization resource plan count",
  "native smoke gpu frame finalization gpu resource count",
  "native smoke gpu frame submission resource plan count",
  "native smoke gpu frame submission gpu resource count",
  "native smoke surface target resource plan count",
  "native smoke surface target cache resources",
  "native smoke window target resource plan count",
  "native smoke window physical width",
  "native smoke window frame pacing",
  "native smoke window frame pacing key variation",
  "native smoke window present mode key variation",
  "native smoke surface finalization resource plan count",
  "native smoke surface finalization key variation",
  "native smoke surface present buffer index",
  "native smoke surface present resource plan count",
  "native smoke surface flush-and-submit",
  "native smoke shader draws",
  "native smoke shader resource plan count",
  "native smoke shader linear gradient validation",
  "native smoke invalid shader filter descriptor resources",
  "native smoke invalid shader filter replay skipped",
  "native smoke invalid shader filter replay cache resources",
  "native smoke invalid shader filter replay cache misses",
  "native smoke invalid shader filter replay filter resources",
  "native smoke filter layer count",
  "native smoke filter finite validation",
  "native smoke filter resource plan count",
  "native smoke path verbs",
  "native smoke non-finite path from-value rejected",
  "native smoke non-finite path add skipped",
  "native smoke non-finite path direct mutations skipped",
  "native smoke readback width",
  "native smoke readback height",
  "native smoke readback row_bytes",
  "native smoke pixmap readback sample proof",
  "native smoke bounded readback width",
  "native smoke bounded readback height",
  "native smoke bounded snapshot width",
  "native smoke bounded snapshot height",
  "native smoke encoded PNG bytes",
  "native smoke decoded image width",
  "native smoke decoded image height",
  "native smoke render image command replay",
  "native smoke render image command count",
  "native smoke render image resource plan count",
  "native smoke render image cache resources",
  "native smoke render image cache misses",
  "native smoke render image cache hits",
  "native smoke render image decode failure resource plan count",
  "native smoke render image decode failure skipped",
  "native smoke render image decode failure cache resources",
  "native smoke render image decode failure cache misses",
  "native smoke empty image descriptor command plan count",
  "native smoke empty image descriptor replay skipped",
  "native smoke empty image descriptor cache misses",
  "native smoke codec encoded format PNG",
  "native smoke codec width",
  "native smoke codec height",
  "native smoke decoded bitmap width",
  "native smoke decoded bitmap height",
  "native smoke font spacing",
  "native smoke font resource plan count",
  "native smoke text run resource plan count",
  "native smoke text run range byte size",
  "native smoke text run empty range resource plan count",
  "native smoke text run empty range skipped",
  "native smoke text run empty range cache resources",
  "native smoke text measurement resource plan count",
  "native smoke measured text resource plan count",
  "native smoke measured text key variation",
  "native smoke invalid measured text resource plan count",
  "native smoke invalid measured text uncacheable count",
  "native smoke text measurement key variation",
  "native smoke text shaping resource plan count",
  "native smoke shaped text resource plan count",
  "native smoke shaped glyph run resource plan count",
  "native smoke shaped glyph run key variation",
  "native smoke invalid shaped glyph resource plan count",
  "native smoke invalid shaped glyph command plan count",
  "native smoke invalid shaped glyph replay skipped",
  "native smoke measured text width",
  "native smoke text glyph count",
  "native smoke first glyph id",
  "native smoke first glyph width",
  "native smoke second glyph position x",
  "native smoke second glyph x position",
  "native smoke first glyph bounds width",
  "native smoke measured text bounds width",
  "native smoke shaper availability",
  "native smoke default typeface availability",
  "native smoke font family count",
  "native smoke first font family bytes",
  "native smoke typeface family bytes",
  "native smoke invalid fallback request resource plan count",
  "native smoke font fallback key variation",
  "native smoke font fallback family bytes",
  "native smoke font fallback match key variation",
  "native smoke font fallback match resource plan count",
  "native smoke font fallback resolution key variation",
  "native smoke font fallback resolution resource plan count",
  "native smoke invalid fallback match resource plan count",
  "native smoke invalid fallback resolution resource plan count",
  "native smoke font fallback resolution bridge",
  "native smoke font fallback resolution bridge cache resources",
  "native smoke font fallback resource plan count",
  "native smoke font fallback font resource plan count",
  "native smoke font fallback width"
)
$defaultExpectedStageValues = @(
  [pscustomobject]@{
    Marker = "native smoke surface target support diagnostics"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas clip device width"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas state restored"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite canvas direct geometry skipped"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite canvas paint layer sanitized"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay commands"
    Value = "29"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame replay commands"
    Value = "29"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame replay complete"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay status contract"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay transforms"
    Value = "6"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay state stats"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay resource declarations"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay image resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay shader resources"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay filter resources"
    Value = "6"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay path resources"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay text resources"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay rrect path clips"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay clip path cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay color paint fills"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay paint fill clipped"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay paint shader fills"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay paint shader cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame replay rejected skipped"
    Value = "26"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame commands"
    Value = "29"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame finalized"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame status contract"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame finalization frame index"
    Value = "7"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame finalization resource plan count"
    Value = "16"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame finalization cacheable count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame finalization uncacheable count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame cache resources"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke native replay resource stats caches"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke native replay resource stats resources"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke surface render frame mismatch rejected"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame pixmap sample proof"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render shaped glyph run command replay"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render shader cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render shader cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render shader cache hits"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render path cache resources"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render path cache misses"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render path cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render text run cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render text run cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render text run cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render font cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render font cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render font cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render typeface cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render typeface cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render typeface cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render color filter cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render color filter cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render color filter cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render image filter cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image filter cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image filter cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render mask filter cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render mask filter cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render mask filter cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource plan count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame resource plan count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame validation status"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame cacheable subplan count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame uncacheable subplan count"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame unbalanced validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render target identity validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render target resource binding"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame present count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame present descriptor validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission cacheable subplan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission uncacheable subplan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission preflight missing count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission preflight cached count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame submission cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization cacheable subplan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization uncacheable subplan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization preflight missing count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization preflight cached count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame finalization cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame missing present validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame missing finalization validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame touched bounds width"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke canvas replay deferred present"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render frame cache resources"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache inserts"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache preflight missing count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache preflight cached count"
    Value = "15"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache plan coverage"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache evictions"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache hits"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache misses"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render resource cache byte size"
    Value = "8"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu context resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu context key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame context validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu present resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu finalization resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame finalization resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame finalization gpu resource count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame submission resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke gpu frame submission gpu resource count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke surface target resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke surface target cache resources"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke window target resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke window physical width"
    Value = "16"
  }
  [pscustomobject]@{
    Marker = "native smoke window frame pacing"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke window frame pacing key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke window present mode key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface finalization resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke surface finalization key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface present buffer index"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke surface present resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke surface flush-and-submit"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke readback width"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke readback height"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke readback row_bytes"
    Value = "128"
  }
  [pscustomobject]@{
    Marker = "native smoke pixmap readback sample proof"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke bounded readback width"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke bounded readback height"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke bounded snapshot width"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke bounded snapshot height"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke filter layer count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke path verbs"
    Value = "9"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path from-value rejected"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path add skipped"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path direct mutations skipped"
    Value = "7"
  }
  [pscustomobject]@{
    Marker = "native smoke decoded image width"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke decoded image height"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke render image command replay"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image command count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke render image resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render image cache resources"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image cache misses"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image cache hits"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke render image decode failure resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render image decode failure skipped"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke render image decode failure cache resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke render image decode failure cache misses"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke empty image descriptor command plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke empty image descriptor replay skipped"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke empty image descriptor cache misses"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke codec width"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke codec height"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke decoded bitmap width"
    Value = "32"
  }
  [pscustomobject]@{
    Marker = "native smoke decoded bitmap height"
    Value = "32"
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
    Marker = "native smoke shader linear gradient validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shader filter descriptor resources"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shader filter replay skipped"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shader filter replay cache resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shader filter replay cache misses"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shader filter replay filter resources"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke empty path replay path cache resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke empty path replay path resources"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke empty path replay path cache misses"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke empty path replay path cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path replay skipped"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path replay path resources"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path replay path cache resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path replay path cache misses"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke non-finite path replay path cache hits"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke filter resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke filter finite validation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke text run resource plan count"
    Value = "3"
  }
  [pscustomobject]@{
    Marker = "native smoke text run range byte size"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke text run empty range resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke text run empty range skipped"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke text run empty range cache resources"
    Value = "0"
  }
  [pscustomobject]@{
    Marker = "native smoke text measurement resource plan count"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke measured text resource plan count"
    Value = "5"
  }
  [pscustomobject]@{
    Marker = "native smoke measured text key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid measured text resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid measured text uncacheable count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke text measurement key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke text shaping resource plan count"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped text resource plan count"
    Value = "5"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped glyph run resource plan count"
    Value = "6"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped glyph run key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shaped glyph resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shaped glyph command plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid shaped glyph replay skipped"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid fallback request resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback match key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback match resource plan count"
    Value = "2"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback resolution key variation"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback resolution resource plan count"
    Value = "4"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid fallback match resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke invalid fallback resolution resource plan count"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback resolution bridge"
    Value = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke font fallback resolution bridge cache resources"
    Value = "4"
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
$defaultConditionalStageMarkers = @(
  [pscustomobject]@{
    Marker = "native smoke shaped glyph count"
    WhenMarker = "native smoke shaper availability"
    WhenValue = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped text native resource plan count"
    WhenMarker = "native smoke shaper availability"
    WhenValue = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped glyph run native resource plan count"
    WhenMarker = "native smoke shaper availability"
    WhenValue = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped glyph descriptor bridge"
    WhenMarker = "native smoke shaper availability"
    WhenValue = "1"
  }
  [pscustomobject]@{
    Marker = "native smoke shaped glyph descriptor bridge cache resources"
    WhenMarker = "native smoke shaper availability"
    WhenValue = "1"
  }
)
$stageMarkers = $defaultStageMarkers
$expectedStageValues = $defaultExpectedStageValues
$conditionalStageMarkers = $defaultConditionalStageMarkers
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
  $statusConditionalStageMarkers = @($status.native_smoke_conditional_capabilities | ForEach-Object {
      $marker = "$($_.marker)".Trim()
      $whenMarker = "$($_.when_marker)".Trim()
      $whenValue = "$($_.when_value)".Trim()
      if ($marker -ne "" -and $whenMarker -ne "" -and $whenValue -ne "") {
        [pscustomobject]@{
          Marker = $marker
          WhenMarker = $whenMarker
          WhenValue = $whenValue
        }
      }
    })
  if ($statusConditionalStageMarkers.Count -gt 0) {
    $conditionalStageMarkers = $statusConditionalStageMarkers
  }
}
foreach ($stageMarker in $stageMarkers) {
  if (!(Test-ExactLogLine -Expected $stageMarker)) {
    throw "native smoke executable log is missing required stage marker: $stageMarker"
  }
}

function Get-MarkerValue {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Marker
  )

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

foreach ($conditionalStageMarker in $conditionalStageMarkers) {
  $actualWhenValue = Get-MarkerValue -Marker $conditionalStageMarker.WhenMarker
  if ($actualWhenValue -eq $conditionalStageMarker.WhenValue) {
    if (!(Test-ExactLogLine -Expected $conditionalStageMarker.Marker)) {
      throw "native smoke executable log is missing conditional stage marker: $($conditionalStageMarker.Marker) when_marker=$($conditionalStageMarker.WhenMarker) when_value=$($conditionalStageMarker.WhenValue)"
    }
    Get-MarkerValue -Marker $conditionalStageMarker.Marker | Out-Null
  }
}

Write-Host "Verified native smoke stage markers and success marker in $LogPath."
