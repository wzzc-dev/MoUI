///|
/// Emoji coverage is a *host* font capability, not a MoUI behaviour: the
/// diagnostic depends on a system typeface covering the representative emoji
/// codepoint (U+1F469) and, for colour output, on that typeface carrying
/// colour glyphs. Minimal Linux images and CI hosts frequently ship neither.
///
/// This lives in a white-box test file because gating on the host capability
/// needs `skia_emoji_typeface_has_color_glyphs`, which is package-private.
test "skia emoji font fallback diagnostic records glyph metadata and reports color emoji readiness" {
  guard skia_available() else { return () }
  let color_emoji_ready = skia_emoji_typeface_has_color_glyphs()
  let glyph_format = if color_emoji_ready { "rgba" } else { "alpha" }
  match skia_emoji_font_fallback_diagnostic() {
    Some(diagnostic) => {
      let language_tags = diagnostic.fallback_language_tags()
      let glyph_key = diagnostic.glyph_key()
      inspect(diagnostic.font_family(), content="emoji")
      inspect(diagnostic.font_source(), content="skia-system-fontmgr")
      inspect(language_tags.length(), content="2")
      inspect(language_tags[0], content="und-Zsye")
      inspect(language_tags[1], content="en")
      inspect(diagnostic.fallback_script_tag(), content="und-Zsye")
      inspect(diagnostic.fallback_language_tag_count(), content="2")
      inspect(diagnostic.fallback_request_language_count(), content="2")
      assert_true(diagnostic.text_system_id() == "skia-raster-text-system")
      assert_true(diagnostic.emoji_hint())
      assert_true(diagnostic.emoji_fallback_attempted())
      assert_true(diagnostic.fallback_request_ready())
      assert_true(diagnostic.missing_glyph_recovery_ready())
      // A host with only a monochrome emoji typeface legitimately reports
      // false; the diagnostic must mirror what the host actually offers.
      assert_true(
        diagnostic.deterministic_color_emoji_ready() == color_emoji_ready,
      )
      inspect(diagnostic.glyph_format(), content=glyph_format)
      assert_true(glyph_key.contains("skia-system-fontmgr"))
      assert_true(glyph_key.contains("skia-raster-text-system"))
      assert_true(glyph_key.contains("script=und-Zsye"))
      assert_true(glyph_key.contains("langs=2"))
      assert_true(glyph_key.contains("lang-tags=und-Zsye+en"))
      assert_true(
        glyph_key.contains("emoji-u+\{diagnostic.fallback_character()}"),
      )
      assert_true(glyph_key.contains(glyph_format))
      assert_true(diagnostic.glyph_count() >= 1)
      assert_true(diagnostic.cluster_count() == 1)
      assert_true(diagnostic.glyph_width() > 0)
      assert_true(diagnostic.glyph_height() > 0)
      assert_true(diagnostic.resolved_missing_glyph_count() >= 0)
      assert_true(diagnostic.fallback_character() == 0x1F469)
      assert_true(diagnostic.resolved_font_name().length() > 0)
      assert_true(diagnostic.resolved_font_name() != "no-fontmgr")
      assert_true(diagnostic.resolved_font_name() != "no-match")
    }
    // Skia is up, so a missing diagnostic means the host exposed no typeface
    // for this codepoint — not that Skia is unavailable, which is what the
    // previous assertion wrongly implied.
    None => {
      assert_false(color_emoji_ready)
      // Skia itself is still healthy; only the emoji typeface is absent.
      assert_true(skia_text_visual_order_diagnostic("MoUI") is Some(_))
    }
  }
}
