///|
pub fn[Msg] input_group(
  child~ : @core.View[Msg],
  prefix? : @core.View[Msg]? = None,
  suffix? : @core.View[Msg]? = None,
  theme? : @core.Theme,
  width? : Double = 320.0,
  height? : Double = 44.0,
  padding? : Double = default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
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
  container(
    row(rows, spacing=resolved_theme.spacing_scale.xs, align=CrossAlign::Center),
    width~,
    height~,
    variant=ContainerVariant::Base,
    theme=resolved_theme,
    padding~,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        resolved_theme.palette.outline.multiply_alpha(0.74),
      ),
      width=1.0,
    ),
  )
}
