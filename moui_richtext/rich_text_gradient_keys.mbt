///|
/// Declaration/string keys for multi-stop gradient brushes. Kept out of
/// `rich_text_editor_helpers.mbt` so the helper file stays under its line
/// budget; both functions are package-private like their siblings.
fn rich_text_stops_gradient_declaration_key(
  spec : @core.StopsGradientSpec,
) -> @core.DeclarationKey {
  rich_text_record_key("Brush.StopsGradient", [
    ("axis", rich_text_gradient_axis_key(spec.axis)),
    (
      "stops",
      @core.DeclarationKey::array(
        spec.stops.map(stop => {
          rich_text_record_key("GradientStop", [
            ("at", @core.DeclarationKey::double(stop.at)),
            ("color", declaration_color_key(stop.color)),
          ])
        }),
      ),
    ),
    ("oklab", @core.DeclarationKey::bool(spec.oklab)),
  ])
}

///|
fn rich_text_gradient_axis_key(
  axis : @core.GradientAxis,
) -> @core.DeclarationKey {
  match axis {
    @core.LinearAxis(start, end) =>
      rich_text_record_key("GradientAxis.Linear", [
        ("start", declaration_point_key(start)),
        ("end", declaration_point_key(end)),
      ])
    @core.RadialAxis(center, radius) =>
      rich_text_record_key("GradientAxis.Radial", [
        ("center", declaration_point_key(center)),
        ("radius", @core.DeclarationKey::double(radius)),
      ])
    @core.ConicAxis(center, angle) =>
      rich_text_record_key("GradientAxis.Conic", [
        ("center", declaration_point_key(center)),
        ("angle", @core.DeclarationKey::double(angle)),
      ])
  }
}

///|
fn rich_text_stops_gradient_key(spec : @core.StopsGradientSpec) -> String {
  let stops = spec.stops
    .map(stop => "\{stop.at}:\{rich_text_color_key(stop.color)}")
    .join(";")
  let axis = match spec.axis {
    @core.LinearAxis(start, end) => "l:\{start.x},\{start.y},\{end.x},\{end.y}"
    @core.RadialAxis(center, radius) => "r:\{center.x},\{center.y},\{radius}"
    @core.ConicAxis(center, angle) => "c:\{center.x},\{center.y},\{angle}"
  }
  "stops:\{axis}:\{spec.oklab}:\{stops}"
}
