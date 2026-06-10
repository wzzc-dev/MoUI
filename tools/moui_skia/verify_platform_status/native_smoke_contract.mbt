// Generated from moui_skia/scripts/verify-platform-status.sh during the tools migration.
// Keep these acceptance guard constants synchronized with platform-status policy changes.

///|
struct RequiredConditionalCapability {
  id : String
  area : String
  marker : String
  when_marker : String
  when_value : String
}

///|
struct RequiredExpectedValue {
  marker : String
  value : String
}

///|
fn required_ci_gate_ids() -> Array[String] {
  [
    "moonbit.fmt-check", "moonbit.check-test", "moonbit.all-target-check", "native.smoke-build",
    "native.smoke-capability-sync", "native.capability-contract", "native.ownership",
    "native.ffi-borrows", "native.fallback-parity", "example.link-config", "platform.status",
    "artifact.native-smoke-log", "artifact.real-skia",
  ]
}

///|
fn required_ci_gate_evidence_files() -> Array[String] {
  [
    ".github/workflows/moui-skia-fallback.yml", ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
    ".github/workflows/moui-skia-macos-real-skia-smoke.yml", ".github/workflows/moui-skia-windows-real-skia-smoke.yml",
    ".github/workflows/moui-skia-real-skia-acceptance.yml", "scripts/check-fallback.ps1",
  ]
}

///|
fn required_native_smoke_capability_ids() -> Array[String] {
  [
    "surface.descriptor", "surface.target-factory-raster", "surface.target-factory-unsupported",
    "canvas.state", "canvas.clip", "canvas.non-finite-direct-geometry-skipped", "canvas.non-finite-paint-layer-sanitized",
    "canvas.image-sampling-scalars-sanitized", "canvas.command-replay", "canvas.replay-status-contract",
    "canvas.replay-deferred-present", "canvas.replay-transforms", "canvas.empty-path-replay-cache-resources",
    "canvas.empty-path-replay-path-resources", "canvas.empty-path-replay-cache-misses",
    "canvas.empty-path-replay-cache-hits", "canvas.non-finite-path-replay-skipped",
    "canvas.non-finite-path-replay-path-resources", "canvas.non-finite-path-replay-cache-resources",
    "canvas.non-finite-path-replay-cache-misses", "canvas.non-finite-path-replay-cache-hits",
    "pipeline.shaped-glyph-run-command", "pipeline.shader-cache-resources", "pipeline.shader-cache-misses",
    "pipeline.shader-cache-hits", "pipeline.path-cache-resources", "pipeline.path-cache-misses",
    "pipeline.path-cache-hits", "pipeline.text-run-cache-resources", "pipeline.text-run-cache-misses",
    "pipeline.text-run-cache-hits", "pipeline.font-cache-resources", "pipeline.font-cache-misses",
    "pipeline.font-cache-hits", "pipeline.color-filter-cache-resources", "pipeline.color-filter-cache-misses",
    "pipeline.color-filter-cache-hits", "pipeline.image-filter-cache-resources",
    "pipeline.image-filter-cache-misses", "pipeline.image-filter-cache-hits", "pipeline.mask-filter-cache-resources",
    "pipeline.mask-filter-cache-misses", "pipeline.mask-filter-cache-hits", "pipeline.resource-plan",
    "pipeline.frame-resource-plan", "pipeline.frame-validation", "pipeline.frame-cacheable-subplan",
    "pipeline.frame-uncacheable-subplan", "pipeline.frame-unbalanced-validation",
    "pipeline.target-identity-validation", "pipeline.target-resource-binding", "pipeline.frame-present",
    "pipeline.frame-submission-resource-plan", "pipeline.frame-submission-cacheable-subplan",
    "pipeline.frame-submission-uncacheable-subplan", "pipeline.frame-submission-preflight-missing",
    "pipeline.frame-submission-preflight-cached", "pipeline.frame-submission-cache-resources",
    "pipeline.frame-finalization-resource-plan", "pipeline.frame-finalization-cacheable-subplan",
    "pipeline.frame-finalization-uncacheable-subplan", "pipeline.frame-finalization-preflight-missing",
    "pipeline.frame-finalization-preflight-cached", "pipeline.frame-finalization-cache-resources",
    "pipeline.frame-missing-present-validation", "pipeline.frame-missing-finalization-validation",
    "pipeline.frame-touched-bounds", "pipeline.frame-cache-resources", "pipeline.native-replay-resource-stats-caches",
    "pipeline.native-replay-resource-stats-resources", "pipeline.resource-cache",
    "pipeline.resource-cache-preflight-missing", "pipeline.resource-cache-preflight-cached",
    "pipeline.resource-cache-plan-coverage", "pipeline.resource-cache-eviction",
    "pipeline.resource-cache-hits", "pipeline.resource-cache-misses", "pipeline.resource-cache-byte-size",
    "gpu.context-resource-plan", "gpu.context-key-variation", "gpu.frame-context-validation",
    "gpu.present-resource-plan", "gpu.finalization-resource-plan", "gpu.frame-finalization-resource-plan",
    "gpu.frame-finalization-gpu-resources", "gpu.frame-submission-resource-plan",
    "gpu.frame-submission-gpu-resources", "surface.target-resource-plan", "surface.target-cache-resources",
    "surface.window-target-resource-plan", "surface.window-physical-width", "surface.window-frame-pacing",
    "surface.window-present-mode-key", "surface.finalization-resource-plan", "surface.finalization-key",
    "surface.flush-and-submit", "shader.draw", "shader.resource-plan", "shader.linear-gradient-validation",
    "shader.linear-gradient-finite-validation", "shader.radial-gradient-validation",
    "shader-filter.invalid-descriptor-resources", "shader-filter.invalid-replay-skipped",
    "shader-filter.invalid-replay-cache-resources", "shader-filter.invalid-replay-cache-misses",
    "shader-filter.invalid-replay-filter-resources", "filter.layer", "filter.finite-validation",
    "filter.non-finite-handle-validation", "filter.resource-plan", "path.geometry",
    "path.non-finite-from-value-rejected", "path.non-finite-add-skipped", "path.non-finite-direct-mutations-skipped",
    "surface.readback", "surface.readback-height", "surface.readback-row-bytes",
    "surface.bounded-readback", "surface.bounded-readback-height", "surface.bounded-snapshot",
    "surface.bounded-snapshot-height", "surface.bounds-rejected", "image.encode-png",
    "image.encode-parameters-sanitized", "image.decode", "image.decode-height", "image.render-command-replay",
    "image.render-command-count", "image.render-command-resource-plan", "image.render-command-cache-resources",
    "image.render-command-cache-misses", "image.render-command-cache-hits", "image.empty-descriptor-command-plan",
    "image.empty-descriptor-replay-skipped", "image.empty-descriptor-cache-misses",
    "codec.metadata", "codec.width", "codec.height", "bitmap.decode-readback", "bitmap.decode-readback-height",
    "text.font-spacing", "text.non-finite-font-scalars-sanitized", "text.font-resource-plan",
    "text.text-run-resource-plan", "text.text-run-range", "text.text-run-empty-range-resource-plan",
    "text.text-run-empty-range-skipped", "text.text-run-empty-range-cache-resources",
    "text.measured-run-resource-plan", "text.measured-run-key", "text.invalid-measured-run-resource-plan",
    "text.invalid-measured-run-uncacheable", "text.shaped-glyph-run-resource-plan",
    "text.shaped-glyph-run-key", "text.invalid-shaped-glyph-resource-plan", "text.invalid-shaped-glyph-command-plan",
    "text.invalid-shaped-glyph-replay-skipped", "text.measure", "text.glyph-count",
    "text.glyph-id", "text.glyph-width", "text.glyph-position", "text.glyph-x-position",
    "text.glyph-bounds", "text.bounds", "text.shaper-availability", "text.default-typeface-availability",
    "fontmgr.family-count", "fontmgr.family-name", "fontmgr.typeface-family", "fontmgr.character-fallback",
    "fontmgr.invalid-fallback-request-resource-plan", "fontmgr.fallback-key", "fontmgr.fallback-family-name",
    "fontmgr.fallback-match-key", "fontmgr.fallback-match-resource-plan", "fontmgr.fallback-resolution-key",
    "fontmgr.fallback-resolution-resource-plan", "fontmgr.invalid-fallback-match-resource-plan",
    "fontmgr.invalid-fallback-resolution-resource-plan", "fontmgr.fallback-resolution-bridge",
    "fontmgr.fallback-resolution-bridge-cache-resources", "fontmgr.fallback-resource-plan",
    "fontmgr.fallback-font-resource-plan",
  ]
}

///|
fn required_native_smoke_areas() -> Array[String] {
  [
    "Surface", "Canvas", "Pipeline", "GPU", "Shader", "Filter", "Path", "Image",
    "Codec", "Bitmap", "Text", "FontMgr",
  ]
}

///|
fn required_native_smoke_conditionals() -> Array[RequiredConditionalCapability] {
  [
    {
      id: "text.shaped-glyph-count",
      area: "Text",
      marker: "native smoke shaped glyph count",
      when_marker: "native smoke shaper availability",
      when_value: "1",
    },
    {
      id: "text.native-shaped-glyph-run-resource-plan",
      area: "Text",
      marker: "native smoke shaped glyph run native resource plan count",
      when_marker: "native smoke shaper availability",
      when_value: "1",
    },
    {
      id: "text.shaped-glyph-descriptor-bridge",
      area: "Text",
      marker: "native smoke shaped glyph descriptor bridge",
      when_marker: "native smoke shaper availability",
      when_value: "1",
    },
    {
      id: "text.shaped-glyph-descriptor-bridge-cache-resources",
      area: "Text",
      marker: "native smoke shaped glyph descriptor bridge cache resources",
      when_marker: "native smoke shaper availability",
      when_value: "1",
    },
  ]
}

///|
fn required_native_smoke_expected_values() -> Array[RequiredExpectedValue] {
  [
    { marker: "native smoke canvas clip device width", value: "4" },
    { marker: "native smoke canvas state restored", value: "1" },
    {
      marker: "native smoke non-finite canvas direct geometry skipped",
      value: "1",
    },
    {
      marker: "native smoke non-finite canvas paint layer sanitized",
      value: "1",
    },
    { marker: "native smoke image sampling scalars sanitized", value: "1" },
    { marker: "native smoke canvas replay commands", value: "29" },
    { marker: "native smoke render frame replay commands", value: "29" },
    { marker: "native smoke render frame replay complete", value: "1" },
    { marker: "native smoke canvas replay status contract", value: "3" },
    { marker: "native smoke canvas replay deferred present", value: "1" },
    { marker: "native smoke canvas replay transforms", value: "6" },
    { marker: "native smoke canvas replay state stats", value: "4" },
    { marker: "native smoke canvas replay resource declarations", value: "4" },
    { marker: "native smoke canvas replay image resources", value: "0" },
    { marker: "native smoke canvas replay shader resources", value: "4" },
    { marker: "native smoke canvas replay filter resources", value: "6" },
    { marker: "native smoke canvas replay path resources", value: "2" },
    { marker: "native smoke canvas replay text resources", value: "9" },
    { marker: "native smoke canvas replay rrect path clips", value: "2" },
    {
      marker: "native smoke canvas replay clip path cache resources",
      value: "1",
    },
    {
      marker: "native smoke empty path replay path cache resources",
      value: "0",
    },
    { marker: "native smoke empty path replay path resources", value: "3" },
    { marker: "native smoke empty path replay path cache misses", value: "0" },
    { marker: "native smoke empty path replay path cache hits", value: "0" },
    { marker: "native smoke non-finite path replay skipped", value: "2" },
    { marker: "native smoke non-finite path replay path resources", value: "2" },
    {
      marker: "native smoke non-finite path replay path cache resources",
      value: "0",
    },
    {
      marker: "native smoke non-finite path replay path cache misses",
      value: "0",
    },
    {
      marker: "native smoke non-finite path replay path cache hits",
      value: "0",
    },
    { marker: "native smoke canvas replay color paint fills", value: "2" },
    { marker: "native smoke canvas replay paint fill clipped", value: "1" },
    { marker: "native smoke canvas replay paint shader fills", value: "1" },
    {
      marker: "native smoke canvas replay paint shader cache resources",
      value: "1",
    },
    { marker: "native smoke render frame replay rejected skipped", value: "26" },
    { marker: "native smoke surface render frame commands", value: "29" },
    { marker: "native smoke surface render frame finalized", value: "1" },
    {
      marker: "native smoke surface render frame finalization frame index",
      value: "7",
    },
    {
      marker: "native smoke surface render frame finalization resource plan count",
      value: "16",
    },
    {
      marker: "native smoke surface render frame finalization cacheable count",
      value: "15",
    },
    {
      marker: "native smoke surface render frame finalization uncacheable count",
      value: "1",
    },
    { marker: "native smoke surface render frame cache resources", value: "9" },
    { marker: "native smoke native replay resource stats caches", value: "9" },
    {
      marker: "native smoke native replay resource stats resources",
      value: "9",
    },
    {
      marker: "native smoke surface render frame mismatch rejected",
      value: "1",
    },
    {
      marker: "native smoke render shaped glyph run command replay",
      value: "1",
    },
    { marker: "native smoke render shader cache resources", value: "1" },
    { marker: "native smoke render shader cache misses", value: "1" },
    { marker: "native smoke render shader cache hits", value: "2" },
    { marker: "native smoke render path cache resources", value: "2" },
    { marker: "native smoke render path cache misses", value: "2" },
    { marker: "native smoke render path cache hits", value: "0" },
    { marker: "native smoke render text run cache resources", value: "1" },
    { marker: "native smoke render text run cache misses", value: "1" },
    { marker: "native smoke render text run cache hits", value: "0" },
    { marker: "native smoke render font cache resources", value: "1" },
    { marker: "native smoke render font cache misses", value: "1" },
    { marker: "native smoke render font cache hits", value: "0" },
    { marker: "native smoke render typeface cache resources", value: "1" },
    { marker: "native smoke render typeface cache misses", value: "1" },
    { marker: "native smoke render typeface cache hits", value: "0" },
    { marker: "native smoke render color filter cache resources", value: "1" },
    { marker: "native smoke render color filter cache misses", value: "1" },
    { marker: "native smoke render color filter cache hits", value: "0" },
    { marker: "native smoke render image filter cache resources", value: "1" },
    { marker: "native smoke render image filter cache misses", value: "1" },
    { marker: "native smoke render image filter cache hits", value: "0" },
    { marker: "native smoke render mask filter cache resources", value: "1" },
    { marker: "native smoke render mask filter cache misses", value: "1" },
    { marker: "native smoke render mask filter cache hits", value: "0" },
    { marker: "native smoke render resource plan count", value: "15" },
    { marker: "native smoke render frame resource plan count", value: "15" },
    { marker: "native smoke render frame validation status", value: "1" },
    { marker: "native smoke render frame cacheable subplan count", value: "15" },
    {
      marker: "native smoke render frame uncacheable subplan count",
      value: "0",
    },
    { marker: "native smoke render frame unbalanced validation", value: "1" },
    { marker: "native smoke render target identity validation", value: "1" },
    { marker: "native smoke render target resource binding", value: "1" },
    { marker: "native smoke render frame present count", value: "1" },
    {
      marker: "native smoke render frame submission resource plan count",
      value: "2",
    },
    {
      marker: "native smoke render frame submission cacheable subplan count",
      value: "1",
    },
    {
      marker: "native smoke render frame submission uncacheable subplan count",
      value: "1",
    },
    {
      marker: "native smoke render frame submission preflight missing count",
      value: "1",
    },
    {
      marker: "native smoke render frame submission preflight cached count",
      value: "1",
    },
    {
      marker: "native smoke render frame submission cache resources",
      value: "1",
    },
    {
      marker: "native smoke render frame finalization resource plan count",
      value: "2",
    },
    {
      marker: "native smoke render frame finalization cacheable subplan count",
      value: "1",
    },
    {
      marker: "native smoke render frame finalization uncacheable subplan count",
      value: "1",
    },
    {
      marker: "native smoke render frame finalization preflight missing count",
      value: "1",
    },
    {
      marker: "native smoke render frame finalization preflight cached count",
      value: "1",
    },
    {
      marker: "native smoke render frame finalization cache resources",
      value: "1",
    },
    {
      marker: "native smoke render frame missing present validation",
      value: "1",
    },
    {
      marker: "native smoke render frame missing finalization validation",
      value: "1",
    },
    { marker: "native smoke render frame touched bounds width", value: "4" },
    { marker: "native smoke render frame cache resources", value: "15" },
    { marker: "native smoke render resource cache inserts", value: "15" },
    {
      marker: "native smoke render resource cache preflight missing count",
      value: "15",
    },
    {
      marker: "native smoke render resource cache preflight cached count",
      value: "15",
    },
    { marker: "native smoke render resource cache plan coverage", value: "1" },
    { marker: "native smoke render resource cache evictions", value: "1" },
    { marker: "native smoke render resource cache hits", value: "1" },
    { marker: "native smoke render resource cache misses", value: "0" },
    { marker: "native smoke render resource cache byte size", value: "8" },
    { marker: "native smoke gpu context resource plan count", value: "2" },
    { marker: "native smoke gpu context key variation", value: "1" },
    { marker: "native smoke gpu frame context validation", value: "1" },
    { marker: "native smoke gpu finalization resource plan count", value: "3" },
    {
      marker: "native smoke gpu frame finalization resource plan count",
      value: "3",
    },
    {
      marker: "native smoke gpu frame finalization gpu resource count",
      value: "3",
    },
    {
      marker: "native smoke gpu frame submission resource plan count",
      value: "3",
    },
    {
      marker: "native smoke gpu frame submission gpu resource count",
      value: "3",
    },
    { marker: "native smoke surface target resource plan count", value: "2" },
    { marker: "native smoke surface target cache resources", value: "2" },
    { marker: "native smoke window target resource plan count", value: "1" },
    { marker: "native smoke window physical width", value: "16" },
    { marker: "native smoke window frame pacing", value: "2" },
    { marker: "native smoke window present mode key variation", value: "1" },
    {
      marker: "native smoke surface finalization resource plan count",
      value: "2",
    },
    { marker: "native smoke surface finalization key variation", value: "1" },
    { marker: "native smoke surface flush-and-submit", value: "1" },
    { marker: "native smoke readback width", value: "32" },
    { marker: "native smoke readback height", value: "32" },
    { marker: "native smoke readback row_bytes", value: "128" },
    { marker: "native smoke bounded readback width", value: "4" },
    { marker: "native smoke bounded readback height", value: "4" },
    { marker: "native smoke bounded snapshot width", value: "4" },
    { marker: "native smoke bounded snapshot height", value: "4" },
    { marker: "native smoke surface bounds rejected", value: "1" },
    { marker: "native smoke image encode parameters sanitized", value: "1" },
    { marker: "native smoke filter layer count", value: "1" },
    { marker: "native smoke path verbs", value: "9" },
    { marker: "native smoke non-finite path from-value rejected", value: "1" },
    { marker: "native smoke non-finite path add skipped", value: "2" },
    {
      marker: "native smoke non-finite path direct mutations skipped",
      value: "7",
    },
    { marker: "native smoke decoded image width", value: "32" },
    { marker: "native smoke decoded image height", value: "32" },
    { marker: "native smoke render image command replay", value: "1" },
    { marker: "native smoke render image command count", value: "3" },
    { marker: "native smoke render image resource plan count", value: "2" },
    { marker: "native smoke render image cache resources", value: "1" },
    { marker: "native smoke render image cache misses", value: "1" },
    { marker: "native smoke render image cache hits", value: "1" },
    {
      marker: "native smoke render image decode failure resource plan count",
      value: "2",
    },
    { marker: "native smoke render image decode failure skipped", value: "2" },
    {
      marker: "native smoke render image decode failure cache resources",
      value: "0",
    },
    {
      marker: "native smoke render image decode failure cache misses",
      value: "2",
    },
    {
      marker: "native smoke empty image descriptor command plan count",
      value: "1",
    },
    { marker: "native smoke empty image descriptor replay skipped", value: "2" },
    { marker: "native smoke empty image descriptor cache misses", value: "0" },
    { marker: "native smoke codec width", value: "32" },
    { marker: "native smoke codec height", value: "32" },
    { marker: "native smoke decoded bitmap width", value: "32" },
    { marker: "native smoke decoded bitmap height", value: "32" },
    { marker: "native smoke shader draws", value: "3" },
    { marker: "native smoke shader resource plan count", value: "3" },
    { marker: "native smoke shader linear gradient validation", value: "1" },
    {
      marker: "native smoke shader linear gradient finite validation",
      value: "1",
    },
    { marker: "native smoke shader radial gradient validation", value: "1" },
    {
      marker: "native smoke invalid shader filter descriptor resources",
      value: "4",
    },
    { marker: "native smoke invalid shader filter replay skipped", value: "2" },
    {
      marker: "native smoke invalid shader filter replay cache resources",
      value: "0",
    },
    {
      marker: "native smoke invalid shader filter replay cache misses",
      value: "0",
    },
    {
      marker: "native smoke invalid shader filter replay filter resources",
      value: "3",
    },
    { marker: "native smoke filter resource plan count", value: "3" },
    { marker: "native smoke filter finite validation", value: "1" },
    { marker: "native smoke filter non-finite handle validation", value: "1" },
    { marker: "native smoke text run resource plan count", value: "3" },
    { marker: "native smoke text run range byte size", value: "4" },
    {
      marker: "native smoke text run empty range resource plan count",
      value: "2",
    },
    { marker: "native smoke text run empty range skipped", value: "1" },
    { marker: "native smoke text run empty range cache resources", value: "0" },
    { marker: "native smoke measured text resource plan count", value: "5" },
    { marker: "native smoke measured text key variation", value: "1" },
    {
      marker: "native smoke invalid measured text resource plan count",
      value: "1",
    },
    {
      marker: "native smoke invalid measured text uncacheable count",
      value: "1",
    },
    { marker: "native smoke shaped glyph run resource plan count", value: "6" },
    { marker: "native smoke shaped glyph run key variation", value: "1" },
    {
      marker: "native smoke invalid shaped glyph resource plan count",
      value: "1",
    },
    {
      marker: "native smoke invalid shaped glyph command plan count",
      value: "1",
    },
    { marker: "native smoke invalid shaped glyph replay skipped", value: "1" },
    { marker: "native smoke non-finite font scalars sanitized", value: "1" },
    { marker: "native smoke font resource plan count", value: "1" },
    {
      marker: "native smoke invalid fallback request resource plan count",
      value: "1",
    },
    { marker: "native smoke font fallback key variation", value: "1" },
    { marker: "native smoke font fallback match key variation", value: "1" },
    {
      marker: "native smoke font fallback match resource plan count",
      value: "2",
    },
    {
      marker: "native smoke font fallback resolution key variation",
      value: "1",
    },
    {
      marker: "native smoke font fallback resolution resource plan count",
      value: "4",
    },
    {
      marker: "native smoke invalid fallback match resource plan count",
      value: "1",
    },
    {
      marker: "native smoke invalid fallback resolution resource plan count",
      value: "1",
    },
    { marker: "native smoke font fallback resolution bridge", value: "1" },
    {
      marker: "native smoke font fallback resolution bridge cache resources",
      value: "4",
    },
    { marker: "native smoke font fallback resource plan count", value: "1" },
    {
      marker: "native smoke font fallback font resource plan count",
      value: "2",
    },
  ]
}
