///|
test "skia Open Sans file names prefer requested style" {
  let regular = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Open Sans"),
    weight=400,
    style=@core.FontStyle::Normal,
  )
  assert_true(
    skia_open_sans_font_file_names(regular) ==
    ["open-sans-v17-latin-ext_latin-regular.woff2"],
  )
  let bold_italic = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Open Sans"),
    weight=700,
    style=@core.FontStyle::Italic,
  )
  assert_true(
    skia_open_sans_font_file_names(bold_italic) ==
    [
      "open-sans-v17-latin-ext_latin-700italic.woff2", "open-sans-v17-latin-ext_latin-italic.woff2",
      "open-sans-v17-latin-ext_latin-700.woff2", "open-sans-v17-latin-ext_latin-regular.woff2",
    ],
  )
}

///|
test "skia Open Sans typeface loads Typora bundled font when available" {
  let path = "/Applications/Typora.app/Contents/Resources/TypeMark/style/themes/github/open-sans-v17-latin-ext_latin-regular.woff2"
  guard @fs.path_exists(path) else { return () }
  guard @skia_native.Typeface::from_file(@utf8.encode(path[:], bom=false))
    is Some(typeface) else {
    fail("expected native Skia to load Typora Open Sans font file")
  }
  guard @skia_native.Font::from_typeface(typeface, size=17.0) is Some(font) else {
    fail("expected native Skia to create a font from Typora Open Sans")
  }
  assert_true(font.measure_text_utf8(b"To") > 0.0)
  match typeface.family_name() {
    Some(name) => assert_true(name.length() > 0)
    None => fail("expected loaded Open Sans typeface to report a family name")
  }
}

///|
test "skia font file resolver resolves Open Sans before system fallback" {
  let path = "/Applications/Typora.app/Contents/Resources/TypeMark/style/themes/github/open-sans-v17-latin-ext_latin-regular.woff2"
  guard @fs.path_exists(path) else { return () }
  let spec = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Open Sans").with_fallback(
      @core.FontFamily::SansSerif,
    ),
    size=17.0,
  )
  guard skia_typeface_from_font_files(spec) is Some(typeface) else {
    fail("expected renderer Open Sans file resolver to load a typeface")
  }
  guard @skia_native.Font::from_typeface(typeface, size=17.0) is Some(font) else {
    fail("expected resolved Open Sans typeface to create a font")
  }
  assert_true(font.measure_text_utf8(b"To") > 0.0)
}
