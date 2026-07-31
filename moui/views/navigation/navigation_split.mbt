///|
pub fn[Msg] split_view(
  primary~ : @core.View[Msg],
  detail~ : @core.View[Msg],
  primary_width? : Double = 240.0,
  detail_width? : Double = 480.0,
  height? : Double = 320.0,
  spacing? : Double = @style.default_theme().spacing_scale.md,
) -> @core.View[Msg] {
  row(
    [
      primary.frame(width=primary_width, height~),
      detail.frame(width=detail_width, height~),
    ],
    spacing~,
    align=@style.CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] resizable_split_view(
  primary~ : @core.View[Msg],
  detail~ : @core.View[Msg],
  primary_width~ : Double,
  detail_width? : Double = 480.0,
  height? : Double = 320.0,
  min_primary_width? : Double = 160.0,
  max_primary_width? : Double = 420.0,
  spacing? : Double = @style.default_theme().spacing_scale.sm,
  handle_width? : Double = 8.0,
  theme? : @core.Theme,
  on_drag~ : (Double) -> Msg,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let width = navigation_clamp_double(
    primary_width, min_primary_width, max_primary_width,
  )
  let handle = @container.container(
      @container.empty(),
      width=handle_width,
      height~,
      background=resolved_theme.palette.primary.multiply_alpha(0.38),
      corner_radius=handle_width / 2.0,
      theme=resolved_theme,
      padding=0.0,
    )
    .accessibility_label("Split resize handle")
    .on_drag(event => {
      on_drag(
        navigation_clamp_double(
          width + event.translation.x,
          min_primary_width,
          max_primary_width,
        ),
      )
    })
  row(
    [
      primary.frame(width~, height~),
      handle,
      detail.frame(width=detail_width, height~),
    ],
    spacing~,
    align=@style.CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] master_detail(
  master~ : @core.View[Msg],
  detail~ : @core.View[Msg],
  master_width? : Double = 220.0,
  detail_width? : Double = 420.0,
  height? : Double = 300.0,
  spacing? : Double = @style.default_theme().spacing_scale.md,
) -> @core.View[Msg] {
  split_view(
    primary=master,
    detail~,
    primary_width=master_width,
    detail_width~,
    height~,
    spacing~,
  )
}

///|
fn navigation_clamp_double(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
