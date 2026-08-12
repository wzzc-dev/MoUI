///|
// Full pipeline: register embedded font data on the text system, then measure
// with a FontSpec that references the registered family and varies the "wght"
// axis. macOS ships SFNS.ttf (a variable font); other platforms skip.
test "embedded font registration drives measurement with variations" {
  let font_path = "/System/Library/Fonts/SFNS.ttf"
  if !@fs.path_exists(font_path) {
    return
  }
  let data = @fs.read_file_to_bytes(font_path) catch { _ => return }
  let text_system = skia_text_system()
  text_system.register_font_data(@core.FontFamily::Name("MouiEmbedSF"), data)
  let families = @core.FontFamilyStack::named("MouiEmbedSF")
  let light = @core.FontSpec::new(families~, size=32.0, variations=[
    @core.FontVariation::new(axis="wght", value=100.0),
  ])
  let black = @core.FontSpec::new(families~, size=32.0, variations=[
    @core.FontVariation::new(axis="wght", value=900.0),
  ])
  let light_width = text_system.measure_text(
      @core.TextLayoutInput::new(text="WWWW", font=light),
    ).size.width
  let black_width = text_system.measure_text(
      @core.TextLayoutInput::new(text="WWWW", font=black),
    ).size.width
  assert_true(black_width > light_width)
  // Re-registering the same family replaces the previous entry.
  text_system.register_font_data(@core.FontFamily::Name("MouiEmbedSF"), data)
  let replaced_width = text_system.measure_text(
      @core.TextLayoutInput::new(text="WWWW", font=black),
    ).size.width
  assert_true(replaced_width > light_width)
}

///|
// Registering garbage data must not crash or poison the text system.
test "embedded font registration rejects invalid data" {
  let text_system = skia_text_system()
  text_system.register_font_data(@core.FontFamily::Name("Broken"), b"\x00\x01")
  let width = text_system.measure_text(
      @core.TextLayoutInput::new(
        text="A",
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::named("Broken"),
        ),
      ),
    ).size.width
  assert_true(width >= 0.0)
}
