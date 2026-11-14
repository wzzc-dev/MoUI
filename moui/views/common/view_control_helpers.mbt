///|
pub fn view_exact_channel(
  key : @core.DeclarationKey,
) -> @core.DeclarationChannel {
  Exact(key)
}

///|

///|
pub fn view_double_option_key(value : Double?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(@core.DeclarationKey::double))
}

///|
pub fn view_point_key(point : @core.Point) -> @core.DeclarationKey {
  view_record_key("Point", [
    ("x", @core.DeclarationKey::double(point.x)),
    ("y", @core.DeclarationKey::double(point.y)),
  ])
}

///|

///|
pub fn view_size_option_key(size : @core.Size?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(size.map(view_size_key))
}

///|
pub fn view_insets_key(insets : @core.Insets) -> @core.DeclarationKey {
  view_record_key("Insets", [
    ("top", @core.DeclarationKey::double(insets.top)),
    ("right", @core.DeclarationKey::double(insets.right)),
    ("bottom", @core.DeclarationKey::double(insets.bottom)),
    ("left", @core.DeclarationKey::double(insets.left)),
  ])
}

///|
pub fn view_font_family_key(family : @core.FontFamily) -> @core.DeclarationKey {
  match family {
    Name(name) =>
      view_record_key("FontFamily.Name", [
        ("name", @core.DeclarationKey::string(name)),
      ])
    SystemUi => @core.DeclarationKey::int(1)
    UiSansSerif => @core.DeclarationKey::int(2)
    UiSerif => @core.DeclarationKey::int(3)
    UiMonospace => @core.DeclarationKey::int(4)
    SansSerif => @core.DeclarationKey::int(5)
    Serif => @core.DeclarationKey::int(6)
    Monospace => @core.DeclarationKey::int(7)
    Emoji => @core.DeclarationKey::int(8)
    Math => @core.DeclarationKey::int(9)
    FangSong => @core.DeclarationKey::int(10)
  }
}

///|
pub fn view_font_key(font : @core.FontSpec) -> @core.DeclarationKey {
  view_record_key("FontSpec", [
    (
      "families",
      @core.DeclarationKey::array(
        font.families.families.map(view_font_family_key),
      ),
    ),
    ("size", @core.DeclarationKey::double(font.size)),
    ("weight", @core.DeclarationKey::int(font.weight)),
    (
      "line_height",
      @core.DeclarationKey::option(
        font.line_height.map(@core.DeclarationKey::double),
      ),
    ),
    (
      "letter_spacing",
      @core.DeclarationKey::option(
        font.letter_spacing.map(@core.DeclarationKey::double),
      ),
    ),
    (
      "features",
      @core.DeclarationKey::array(font.features.map(view_font_feature_key)),
    ),
    (
      "style",
      @core.DeclarationKey::int(
        match font.style {
          Normal => 0
          Italic => 1
        },
      ),
    ),
  ])
}

///|
pub fn view_font_feature_key(
  feature : @core.FontFeature,
) -> @core.DeclarationKey {
  view_record_key("FontFeature", [
    ("tag", @core.DeclarationKey::string(feature.tag)),
    ("value", @core.DeclarationKey::int(feature.value)),
  ])
}

///|
pub fn view_font_option_key(font : @core.FontSpec?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(font.map(view_font_key))
}

///|
pub fn view_semantics_role_key(
  role : @core.SemanticsRole,
) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match role {
      None => 0
      Text => 1
      Link => 2
      Heading => 3
      Navigation => 4
      Main => 5
      Button => 6
      Checkbox => 7
      TextField => 8
      List => 9
      ListItem => 10
      Grid => 11
      ScrollView => 12
      Switch => 13
      Radio => 14
      Slider => 15
      Progress => 16
      Tab => 17
      Dialog => 18
      Tooltip => 19
      Menu => 20
      ButtonGroup => 21
      Form => 22
      FormField => 23
      Tree => 24
      TreeItem => 25
      Group => 26
      WebView => 27
      Image => 28
      Alert => 29
      Status => 30
      ComboBox => 31
      Option => 32
      Table => 33
      Row => 34
      Cell => 35
      Separator => 36
    },
  )
}

///|
pub fn view_brush_key(value : @core.Brush) -> @core.DeclarationKey {
  match value {
    Solid(color) =>
      view_record_key("Brush.Solid", [("color", view_color_key(color))])
    LinearGradient(spec) =>
      view_record_key("Brush.LinearGradient", [
        ("start", view_point_key(spec.start)),
        ("end", view_point_key(spec.end)),
        ("start_color", view_color_key(spec.start_color)),
        ("end_color", view_color_key(spec.end_color)),
      ])
    RadialGradient(spec) =>
      view_record_key("Brush.RadialGradient", [
        ("center", view_point_key(spec.center)),
        ("radius", @core.DeclarationKey::double(spec.radius)),
        ("center_color", view_color_key(spec.center_color)),
        ("edge_color", view_color_key(spec.edge_color)),
      ])
    StopsGradient(spec) =>
      view_record_key("Brush.StopsGradient", [
        ("axis", view_gradient_axis_key(spec.axis)),
        (
          "stops",
          @core.DeclarationKey::array(
            spec.stops.map(stop => {
              view_record_key("GradientStop", [
                ("at", @core.DeclarationKey::double(stop.at)),
                ("color", view_color_key(stop.color)),
              ])
            }),
          ),
        ),
        ("oklab", @core.DeclarationKey::bool(spec.oklab)),
      ])
  }
}

///|
fn view_gradient_axis_key(axis : @core.GradientAxis) -> @core.DeclarationKey {
  match axis {
    @core.LinearAxis(start, end) =>
      view_record_key("GradientAxis.Linear", [
        ("start", view_point_key(start)),
        ("end", view_point_key(end)),
      ])
    @core.RadialAxis(center, radius) =>
      view_record_key("GradientAxis.Radial", [
        ("center", view_point_key(center)),
        ("radius", @core.DeclarationKey::double(radius)),
      ])
    @core.ConicAxis(center, angle) =>
      view_record_key("GradientAxis.Conic", [
        ("center", view_point_key(center)),
        ("angle", @core.DeclarationKey::double(angle)),
      ])
  }
}

///|
pub fn view_brush_option_key(value : @core.Brush?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_brush_key))
}

///|
pub fn view_border_key(value : @core.BorderStyle) -> @core.DeclarationKey {
  view_record_key("BorderStyle", [
    ("brush", view_brush_key(value.brush)),
    ("width", @core.DeclarationKey::double(value.width)),
  ])
}

///|
pub fn view_border_option_key(
  value : @core.BorderStyle?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_border_key))
}

///|
pub fn view_shadow_key(value : @core.ShadowStyle) -> @core.DeclarationKey {
  view_record_key("ShadowStyle", [
    ("color", view_color_key(value.color)),
    ("offset", view_point_key(value.offset)),
    ("blur_radius", @core.DeclarationKey::double(value.blur_radius)),
    ("spread", @core.DeclarationKey::double(value.spread)),
  ])
}

///|
pub fn view_shadow_option_key(
  value : @core.ShadowStyle?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_shadow_key))
}

///|
pub fn view_max_double(left : Double, right : Double) -> Double {
  if left >= right {
    left
  } else {
    right
  }
}

///|
pub fn view_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}

///|
pub fn view_max_int(left : Int32, right : Int32) -> Int32 {
  if left >= right {
    left
  } else {
    right
  }
}

///|
/// Decode consecutive big-endian doubles from a view-state slot payload,
/// rejecting a corrupt sample instead of guessing at it.
pub fn view_decode_doubles(
  bytes : Bytes,
  from~ : Int32,
  count~ : Int32,
) -> Array[Double]? {
  let values : Array[Double] = []
  let mut index = from
  let mut failed = false
  while index < from + count * 8 && !failed {
    match
      @core.ViewStateValue::decode_view_state(
        0.0,
        bytes[index:index + 8].to_owned(),
      ) {
      Some(value) => values.push(value)
      None => failed = true
    }
    index = index + 8
  }
  if failed || values.length() != count {
    None
  } else {
    Some(values)
  }
}

///|
pub fn[Msg] view_event_result(
  changed~ : Bool = false,
  activated~ : Bool = false,
  focused~ : Bool = false,
  captured~ : Bool = false,
  state~ : @core.ViewStateContext? = None,
  text_control~ : @core.TextControlStateContext? = None,
  dirty~ : @core.ViewDirtyHint = ViewClean,
  messages~ : Array[Msg] = [],
) -> @core.ViewEventResult[Msg] {
  {
    changed,
    activated,
    focused,
    captured,
    state,
    text_control,
    dirty,
    messages,
  }
}

///|
/// Emit a two-layer elevation shadow for a raised surface: a tight ambient
/// shadow (zero offset, small blur, low alpha) for contact depth, followed by
/// the key directional shadow. In dark mode the ambient uses a lighter tint
/// than pure black so the shadow is visible against the dark surface, since
/// black-on-near-black key shadows disappear. Callers that only have a single
/// `ShadowStyle?` (the key shadow) pass it here to upgrade it to the pair;
/// `None` emits nothing.
pub fn emit_elevation_shadow(
  commands : Array[@core.DrawCommand],
  rounded : @core.RoundedRect,
  key_shadow : @core.ShadowStyle?,
  scheme : @core.ColorScheme,
) -> Unit {
  match key_shadow {
    Some(key) => {
      // Ambient: tight, centered, low-alpha. Light surfaces use black; dark
      // surfaces lift toward white so the elevation reads.
      let ambient_color = match scheme {
        Light => @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.06)
        Dark => @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.04)
      }
      commands.push(
        DrawShadow(
          @core.ShadowSpec::new(
            rect=rounded,
            color=ambient_color,
            offset=@core.Point::new(x=0.0, y=0.0),
            blur_radius=view_max_double(2.0, key.blur_radius * 0.25),
          ),
        ),
      )
      commands.push(
        DrawShadow(
          @core.ShadowSpec::new(
            rect=rounded,
            color=key.color,
            offset=key.offset,
            blur_radius=key.blur_radius,
            spread=key.spread,
          ),
        ),
      )
    }
    None => ()
  }
}
