///|
pub fn[Msg] surface(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  variant? : SurfaceVariant = SurfaceVariant::Base,
  theme? : @core.Theme = default_theme(),
  padding? : Double,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let child_padding = match padding {
    Some(value) => @core.Insets::all(value)
    None => style.padding
  }
  let (background, corner_radius) = match background {
    Some(color) => (Some(@core.Brush::solid(color)), corner_radius)
    None => (Some(style.brush), style.radius)
  }
  let container = @widget.container(
    child=Some(@widget.padding(child~, insets=child_padding)),
    size=None,
    background~,
    border=style.border,
    corner_radius~,
    shadow=style.shadow,
  )
  match (width, height) {
    (None, None) => container
    _ => container.frame(width?, height?)
  }
}

///|
pub fn[Msg] card(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  padding? : Double = 32.0,
  theme? : @core.Theme = default_theme(),
) -> @core.View[Msg] {
  surface(
    child,
    width?,
    height?,
    variant=SurfaceVariant::Raised,
    theme~,
    padding~,
  )
}

///|
pub fn[Msg] center(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  theme? : @core.Theme = default_theme(),
) -> @core.View[Msg] {
  let centered = custom_children_layout(
    children=[child],
    measure=ctx => {
      let child_size = ctx.child_sizes[0]
      let measured_width = match width {
        Some(width) => width
        None =>
          if ctx.constraints.max.width >= 1.0e9 {
            child_size.width
          } else {
            ctx.constraints.max.width
          }
      }
      let measured_height = match height {
        Some(height) => height
        None =>
          if ctx.constraints.max.height >= 1.0e9 {
            child_size.height
          } else {
            ctx.constraints.max.height
          }
      }
      ctx.constraints.constrain(
        @core.Size::new(width=measured_width, height=measured_height),
      )
    },
    place=ctx => {
      let child_size = ctx.child_sizes[0]
      let x = ctx.frame.origin.x +
        views_max_double(0.0, (ctx.frame.size.width - child_size.width) / 2.0)
      let y = ctx.frame.origin.y +
        views_max_double(0.0, (ctx.frame.size.height - child_size.height) / 2.0)
      [
        @core.Rect::new(
          x~,
          y~,
          width=child_size.width,
          height=child_size.height,
        ),
      ]
    },
    semantics_label="Centered content",
  )
  match background {
    Some(color) =>
      surface(centered, width?, height?, background=color, theme~, padding=0.0)
    None => centered
  }
}

///|
fn views_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn views_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn views_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn[Msg] empty() -> @core.View[Msg] {
  @widget.empty()
}

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}

///|
pub fn[Msg] spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  @widget.spacer(min_length~, weight~)
}
