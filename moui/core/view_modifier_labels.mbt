///|
fn declaration_option_double(value : Double?) -> DeclarationKey {
  DeclarationKey::option(value.map(DeclarationKey::double))
}

///|
fn declaration_color(color : Color) -> DeclarationKey {
  DeclarationKey::record(type_tag="Color", fields=[
    ("r", DeclarationKey::double(color.r)),
    ("g", DeclarationKey::double(color.g)),
    ("b", DeclarationKey::double(color.b)),
    ("a", DeclarationKey::double(color.a)),
  ])
}

///|
fn declaration_point(point : Point) -> DeclarationKey {
  DeclarationKey::record(type_tag="Point", fields=[
    ("x", DeclarationKey::double(point.x)),
    ("y", DeclarationKey::double(point.y)),
  ])
}

///|
fn declaration_insets(insets : Insets) -> DeclarationKey {
  DeclarationKey::record(type_tag="Insets", fields=[
    ("top", DeclarationKey::double(insets.top)),
    ("right", DeclarationKey::double(insets.right)),
    ("bottom", DeclarationKey::double(insets.bottom)),
    ("left", DeclarationKey::double(insets.left)),
  ])
}

///|
fn declaration_brush(value : Brush) -> DeclarationKey {
  match value {
    Brush::Solid(color) =>
      DeclarationKey::record(type_tag="Brush.Solid", fields=[
        ("color", declaration_color(color)),
      ])
    Brush::LinearGradient(spec) =>
      DeclarationKey::record(type_tag="Brush.LinearGradient", fields=[
        ("start", declaration_point(spec.start)),
        ("end", declaration_point(spec.end)),
        ("start_color", declaration_color(spec.start_color)),
        ("end_color", declaration_color(spec.end_color)),
      ])
    Brush::RadialGradient(spec) =>
      DeclarationKey::record(type_tag="Brush.RadialGradient", fields=[
        ("center", declaration_point(spec.center)),
        ("radius", DeclarationKey::double(spec.radius)),
        ("center_color", declaration_color(spec.center_color)),
        ("edge_color", declaration_color(spec.edge_color)),
      ])
  }
}

///|
fn declaration_font_family(family : FontFamily) -> DeclarationKey {
  match family {
    Name(name) =>
      DeclarationKey::record(type_tag="FontFamily.Name", fields=[
        ("name", DeclarationKey::string(name)),
      ])
    SystemUi => DeclarationKey::string("FontFamily.SystemUi")
    UiSansSerif => DeclarationKey::string("FontFamily.UiSansSerif")
    UiSerif => DeclarationKey::string("FontFamily.UiSerif")
    UiMonospace => DeclarationKey::string("FontFamily.UiMonospace")
    SansSerif => DeclarationKey::string("FontFamily.SansSerif")
    Serif => DeclarationKey::string("FontFamily.Serif")
    Monospace => DeclarationKey::string("FontFamily.Monospace")
    Emoji => DeclarationKey::string("FontFamily.Emoji")
    Math => DeclarationKey::string("FontFamily.Math")
    FangSong => DeclarationKey::string("FontFamily.FangSong")
  }
}

///|
fn declaration_font(font : FontSpec) -> DeclarationKey {
  DeclarationKey::record(type_tag="FontSpec", fields=[
    (
      "families",
      DeclarationKey::array(font.families.families.map(declaration_font_family)),
    ),
    ("size", DeclarationKey::double(font.size)),
    ("weight", DeclarationKey::int(font.weight)),
    (
      "style",
      DeclarationKey::string(
        match font.style {
          Normal => "normal"
          Italic => "italic"
        },
      ),
    ),
  ])
}

///|
fn declaration_shadow(style : ShadowStyle) -> DeclarationKey {
  DeclarationKey::record(type_tag="ShadowStyle", fields=[
    ("color", declaration_color(style.color)),
    ("offset", declaration_point(style.offset)),
    ("blur_radius", DeclarationKey::double(style.blur_radius)),
    ("spread", DeclarationKey::double(style.spread)),
  ])
}

///|
fn declaration_border(style : BorderStyle) -> DeclarationKey {
  DeclarationKey::record(type_tag="BorderStyle", fields=[
    ("brush", declaration_brush(style.brush)),
    ("width", DeclarationKey::double(style.width)),
  ])
}
