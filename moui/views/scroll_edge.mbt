///|
/// Fade the content under a scrollable edge, as a toolbar over a list does.
/// The child is placed at the full size; the top/bottom fades are gradients
/// from `color` (default: theme background) to transparent.
///
/// This is a pure composition over `stage`/`place` and the existing gradient
/// brush, so every renderer that draws linear gradients gets it.
pub fn[Msg] scroll_edge(
  child : @core.View[Msg],
  width~ : Double,
  height~ : Double,
  fade_height~ : Double = 24.0,
  color? : @core.Color,
  theme? : @core.Theme,
  top~ : Bool = true,
  bottom~ : Bool = true,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let fade_color = color.unwrap_or(resolved_theme.palette.background)
  let clear = @core.Color::transparent()
  let layers : Array[Placed[Msg]] = [
    place(child, x=0.0, y=0.0, width~, height~),
  ]
  let fade = @common.view_min_double(fade_height, height).max(0.0)
  if top && fade > 0.0 {
    let brush = @core.Brush::linear_gradient(
      start=@core.Point::new(x=0.0, y=0.0),
      end=@core.Point::new(x=0.0, y=fade),
      start_color=fade_color,
      end_color=clear,
    )
    layers.push(
      place(
        container(empty(), width~, height=fade, theme=resolved_theme).background_brush(
          brush,
        ),
        x=0.0,
        y=0.0,
        width~,
        height=fade,
      ),
    )
  }
  if bottom && fade > 0.0 {
    let brush = @core.Brush::linear_gradient(
      start=@core.Point::new(x=0.0, y=0.0),
      end=@core.Point::new(x=0.0, y=fade),
      start_color=clear,
      end_color=fade_color,
    )
    layers.push(
      place(
        container(empty(), width~, height=fade, theme=resolved_theme).background_brush(
          brush,
        ),
        x=0.0,
        y=height - fade,
        width~,
        height=fade,
      ),
    )
  }
  stage(width~, height~, layers)
}
