///|
test "artifact path strips artifacts prefix" {
  assert_true(
    artifact_path("/tmp/run/artifacts/conformance/renderer-proof/web.log") ==
    "artifacts/conformance/renderer-proof/web.log",
  )
  assert_true(
    artifact_path("C:\\tmp\\artifacts\\conformance\\renderer-proof\\web.log") ==
    "artifacts/conformance/renderer-proof/web.log",
  )
}

///|
test "parses browser color emoji metadata" {
  let log = "MoUI renderer proof colorEmojiPixels metadata font_family=emoji font_source=browser-canvas text_system=webgpu-wasm shaper=browser-canvas glyph_format=rgba glyph_count=1 cluster_count=1 high_saturation_pixels=42 alpha_pixels=120 glyph_key=1|normal|400|24|system-ui|rgba|emoji glyph_width=24 glyph_height=24"
  let metadata = match color_emoji_metadata(log) {
    Some(value) => value
    None => fail("expected metadata")
  }
  assert_true(color_emoji_metadata_ready(Some(metadata), "webgpu-wasm"))
}

///|
test "requires Skia fallback metadata for Skia color emoji readiness" {
  let log =
    #|MoUI renderer proof colorEmojiPixels metadata font_family=emoji font_source=skia-system-fontmgr text_system=skia-raster-text-system shaper=skshaper glyph_format=rgba glyph_count=2 cluster_count=1 high_saturation_pixels=42 alpha_pixels=120 glyph_key=skia-system-fontmgr|skia-raster-text-system|skshaper|script=und-Zsye|langs=2|lang-tags=und-Zsye+en|emoji-u+128105|rgba glyph_width=28 glyph_height=32 fallback_script_tag=und-Zsye fallback_language_tags=und-Zsye+en fallback_language_tag_count=2 fallback_request_language_count=2 fallback_request_character=128105 resolved_missing_glyph_count=0 missing_glyph_recovery_ready=true
  let metadata = match color_emoji_metadata(log) {
    Some(value) => value
    None => fail("expected metadata")
  }
  assert_true(color_emoji_metadata_ready(Some(metadata), "skia-native"))
  let broken = log.replace(old=" fallback_request_character=128105", new="")
  let broken_metadata = match color_emoji_metadata(broken) {
    Some(value) => value
    None => fail("expected metadata")
  }
  assert_false(color_emoji_metadata_ready(Some(broken_metadata), "skia-native"))
}
