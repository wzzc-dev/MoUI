///|
test "skia transform maps MoUI affine fields to Skia matrix members" {
  let transform = @core.Transform2D::{
    a: 2.0,
    b: 3.0,
    c: 5.0,
    d: 7.0,
    tx: 11.0,
    ty: 13.0,
  }
  let matrix = skia_matrix(transform)
  assert_true(
    matrix.values() == [2.0, 5.0, 11.0, 3.0, 7.0, 13.0, 0.0, 0.0, 1.0],
  )
  assert_true(
    matrix.map_point(@skia_mbt.Point::new(17.0, 19.0)) ==
    @skia_mbt.Point::new(140.0, 197.0),
  )
}

///|
test "skia font resolver maps MoUI font families to platform candidates" {
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Name("Acme Sans")) ==
    ["Acme Sans"],
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SystemUi).contains(
      "Helvetica Neue",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SansSerif).contains(
      "Segoe UI",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Serif).contains(
      "Times New Roman",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::UiMonospace).contains("Menlo"),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Emoji).contains(
      "Apple Color Emoji",
    ),
  )
  assert_true(skia_font_slant(@core.FontStyle::Normal) == 0)
  assert_true(skia_font_slant(@core.FontStyle::Italic) == 1)
}

///|
test "skia font resolver preserves fallback availability" {
  match skia_font(@core.FontSpec::new(size=14.0, weight=400)) {
    Some(font) => assert_true(font.size() == 14.0)
    None => assert_true(!skia_available())
  }
  let missing = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Definitely Missing MoUI Font"),
    size=15.0,
    weight=700,
    style=@core.FontStyle::Italic,
  )
  match skia_font(missing) {
    Some(font) => assert_true(font.size() == 15.0)
    None => assert_true(!skia_available())
  }
}
