///|
pub fn sheet(
  content~ : @core.ViewSpec,
  presentation_mode~ : @core.SheetPresentationMode = @core.SheetPresentationMode::Modal,
  background~ : @core.Brush = @core.Brush::solid(@core.Color::white()),
  corner_radius~ : Double = @core.Theme::default().radius_scale.lg,
  shadow? : @core.ShadowStyle? = None,
  on_dismiss? : (() -> Unit)? = None,
) -> @core.ViewSpec {
  @core.ViewSpec::SheetSpec({
    key: None,
    content,
    presentation_mode,
    background,
    corner_radius,
    shadow,
    on_dismiss,
  })
}

///|
pub fn sheet_host(
  child~ : @core.ViewSpec,
  sheet? : @core.ViewSpec? = None,
  presented? : Bool = false,
  presentation_mode~ : @core.SheetPresentationMode = @core.SheetPresentationMode::Modal,
  on_dismiss? : (() -> Unit)? = None,
) -> @core.ViewSpec {
  if presented && sheet is Some(sheet_spec) {
    let theme = @core.Theme::default()
    // Semi-transparent scrim background
    let scrim = surface(
      @core.ViewSpec::EmptySpec,
      style=@core.SurfaceStyle::default(),
    ).background_brush(@core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.5)))
    let scrim_with_tap = match on_dismiss {
      Some(handler) => scrim.on_tap(handler)
      None => scrim
    }
    // The sheet content
    let aligned_sheet = match presentation_mode {
      @core.SheetPresentationMode::Modal =>
        sheet_spec
          .frame(width=400.0, height=400.0)
          .corner_radius(theme.radius_scale.lg)
          .align()
      @core.SheetPresentationMode::BottomSheet =>
        sheet_spec
          .frame(max_height=500.0)
          .corner_radius(theme.radius_scale.lg)
          .align(alignment=@core.Alignment::new(x=0.5, y=1.0))
    }
    stack([child, scrim_with_tap, aligned_sheet])
  } else {
    child
  }
}
