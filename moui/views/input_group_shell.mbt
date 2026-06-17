///|
pub fn[Msg] input_group(
  child~ : @core.View[Msg],
  prefix? : @core.View[Msg]? = None,
  suffix? : @core.View[Msg]? = None,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
  height? : Double = 44.0,
  padding? : Double = default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  match prefix {
    Some(view) => rows.push(view)
    None => ()
  }
  rows.push(child.expanded())
  match suffix {
    Some(view) => rows.push(view)
    None => ()
  }
  surface(
    row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding~,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.74)),
      width=1.0,
    ),
  )
}
