///|
pub fn[Msg] container(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  border? : @core.BorderStyle? = None,
  variant? : ContainerVariant = ContainerVariant::Base,
  theme? : @core.Theme,
  padding? : Double,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let style = variant.style(resolved_theme)
  let child_padding = match padding {
    Some(value) => @core.Insets::all(value)
    None => style.padding
  }
  let (background, corner_radius) = match background {
    Some(color) => (Some(@core.Brush::solid(color)), corner_radius)
    None => (Some(style.brush), style.radius)
  }
  let resolved_border = match border {
    Some(value) => Some(value)
    None => style.border
  }
  let framed_size = match (width, height) {
    (Some(w), Some(h)) => Some(@core.Size::new(width=w, height=h))
    _ => None
  }
  let container = container_box(
    child=Some(padding_layout(child~, insets=child_padding)),
    size=framed_size,
    background~,
    border=resolved_border,
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
  padding? : Double = 24.0,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  container(
    child,
    width?,
    height?,
    variant=ContainerVariant::Raised,
    theme=resolved_theme,
    padding~,
  )
}

///|
pub fn[Msg] center(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let centered = @core.View::from_node(
    CenterViewNode::{ width, height },
    children=_node => [child],
  )
  match background {
    Some(color) =>
      container(
        centered,
        width?,
        height?,
        background=color,
        theme=resolved_theme,
        padding=0.0,
      )
    None => centered
  }
}

///|
/// Concrete view node for the `center` control.
///
/// Centers a single child inside its own frame. The node carries only
/// immutable declaration data: the optional explicit `width` / `height`. The
/// child is wired through `View::from_node`'s typed children adapter, so the
/// node itself stays message-independent.
priv struct CenterViewNode {
  width : Double?
  height : Double?
}

///|
impl @core.ViewNode for CenterViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Center")
}

///|
impl @core.ViewNode for CenterViewNode with fn revision(self) {
  let width_token = match self.width {
    Some(value) => "\{value}"
    None => "auto"
  }
  let height_token = match self.height {
    Some(value) => "\{value}"
    None => "auto"
  }
  "center:\{width_token}:\{height_token}"
}

///|
impl @core.ViewNode for CenterViewNode with fn layout(self, ctx) {
  let child_size = if ctx.child_sizes.length() > 0 {
    ctx.child_sizes[0]
  } else {
    @core.Size::new(width=0.0, height=0.0)
  }
  let measured_width = match self.width {
    Some(width) => width
    None =>
      if ctx.constraints.max.width >= 1.0e9 {
        child_size.width
      } else {
        ctx.constraints.max.width
      }
  }
  let measured_height = match self.height {
    Some(height) => height
    None =>
      if ctx.constraints.max.height >= 1.0e9 {
        child_size.height
      } else {
        ctx.constraints.max.height
      }
  }
  let size = ctx.constraints.constrain(
    @core.Size::new(width=measured_width, height=measured_height),
  )
  // Center the child inside the measured frame. We clamp the offsets at zero
  // so a child larger than the frame stays top-left aligned rather than
  // painting at negative coordinates.
  let x = views_max_double(0.0, (size.width - child_size.width) / 2.0)
  let y = views_max_double(0.0, (size.height - child_size.height) / 2.0)
  @core.ViewLayoutResult::new(
    size~,
    child_frames=[
      @core.Rect::new(
        x~,
        y~,
        width=child_size.width,
        height=child_size.height,
      ),
    ],
  )
}

///|
impl @core.ViewNode for CenterViewNode with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Group,
    label="Centered content",
  )
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
  @core.View::from_node(EmptyControlNode::{  })
}

///|
priv struct EmptyControlNode {}

///|
impl @core.ViewNode for EmptyControlNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Empty")
}

///|
impl @core.ViewNode for EmptyControlNode with fn revision(_self) {
  "empty"
}

///|
impl @core.ViewNode for EmptyControlNode with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=0.0, height=0.0)),
  )
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
  @core.View::from_node(SpacerViewNode::{ min_length, weight })
}

///|
priv struct SpacerViewNode {
  min_length : Double
  weight : Double
}

///|
impl @core.ViewNode for SpacerViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Spacer")
}

///|
impl @core.ViewNode for SpacerViewNode with fn revision(self) {
  "spacer:\{self.min_length}:\{self.weight}"
}

///|
impl @core.ViewNode for SpacerViewNode with fn layout(self, ctx) {
  let size = if self.weight > 0.0 {
    @core.Size::new(width=0.0, height=0.0)
  } else {
    @core.Size::new(width=self.min_length, height=self.min_length)
  }
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
}

///|
impl @core.ViewNode for SpacerViewNode with fn flex_weight(self) {
  if self.weight > 0.0 {
    self.weight
  } else {
    0.0
  }
}
