///|
pub using @common {
  views_ambient_theme,
  max_view_double,
  view_layout_declaration,
  view_record_key,
  view_double_option_key,
}

///|
pub using @layout {container_box, padding_layout}

///|
pub fn[Msg] container(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  border? : @core.BorderStyle? = None,
  variant? : @style.ContainerVariant = Base,
  theme? : @core.Theme,
  padding? : Double,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = variant.style(resolved_theme)
  let child_padding = match padding {
    Some(value) => @core.Insets::all(value)
    None => style.padding
  }
  let framed_size = match (width, height) {
    (Some(w), Some(h)) => Some(@core.Size::new(width=w, height=h))
    _ => None
  }
  // 声明期读不到环境主题:未钉 background/theme 的容器把表面 chrome 推迟到
  // paint 期按 `ctx.environment.theme` 解析(与 button/text 同约定),
  // 否则 `.theme()` 子树下的表面永远停留在中性主题的配色上。
  let ambient : @style.ContainerVariant? = if background is None &&
    theme is None {
    Some(variant)
  } else {
    None
  }
  let (boxed_background, boxed_border, boxed_radius, boxed_shadow) = if ambient
    is Some(_) {
    (None, border, corner_radius, None)
  } else {
    let (bg, radius) = match background {
      Some(color) => (Some(@core.Brush::solid(color)), corner_radius)
      None => (Some(style.brush), style.radius)
    }
    let resolved_border = match border {
      Some(value) => Some(value)
      None => style.border
    }
    (bg, resolved_border, radius, style.shadow)
  }
  let container = @layout.container_box(
    child=Some(@layout.padding_layout(child~, insets=child_padding)),
    size=framed_size,
    background=boxed_background,
    border=boxed_border,
    corner_radius=boxed_radius,
    shadow=boxed_shadow,
    ambient~,
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
  // `theme` 保持 Option 原样转发:不显式指定时表面 chrome 在 paint 期取
  // `ctx.environment.theme`,跟随宿主主题,不钉死调用时的中性配色。
  container(child, width?, height?, variant=Raised, theme?, padding~)
}

///|
pub fn[Msg] center(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  let centered = @core.View::from_node(Center::{ width, height, }, children=_node => {
    [child]
  })
  match background {
    Some(color) =>
      container(
        centered,
        width?,
        height?,
        background=color,
        theme?,
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
priv struct Center {
  width : Double?
  height : Double?
}

///|
impl @core.ViewNode for Center with fn identity(_self) {
  @core.ViewIdentity::new(kind="Center")
}

///|
impl @core.ViewNode for Center with fn declaration(self) {
  @common.view_layout_declaration(
    @common.view_record_key("Center", [
      ("width", @common.view_double_option_key(self.width)),
      ("height", @common.view_double_option_key(self.height)),
    ]),
  )
}

///|
impl @core.ViewNode for Center with fn layout(self, ctx) {
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
  let x = @common.max_view_double(0.0, (size.width - child_size.width) / 2.0)
  let y = @common.max_view_double(0.0, (size.height - child_size.height) / 2.0)
  @core.ViewLayoutResult::new(size~, child_frames=[
    @core.Rect::new(x~, y~, width=child_size.width, height=child_size.height),
  ])
}

///|
impl @core.ViewNode for Center with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(composition=Transparent)
}

///|
pub fn[Msg] empty() -> @core.View[Msg] {
  @core.View::from_node(EmptyControl::{ })
}

///|
priv struct EmptyControl {}

///|
impl @core.ViewNode for EmptyControl with fn identity(_self) {
  @core.ViewIdentity::new(kind="Empty")
}

///|
impl @core.ViewNode for EmptyControl with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for EmptyControl with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=0.0, height=0.0)),
  )
}

///|
pub fn[Msg] spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  @core.View::from_node(SpacerViewNode::{ min_length, weight, })
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
impl @core.ViewNode for SpacerViewNode with fn declaration(self) {
  @common.view_layout_declaration(
    @common.view_record_key("Spacer", [
      ("min_length", @core.DeclarationKey::double(self.min_length)),
      ("weight", @core.DeclarationKey::double(self.weight)),
    ]),
  )
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
