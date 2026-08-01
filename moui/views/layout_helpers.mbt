///|
pub fn[Msg] expanded(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.expanded(weight~)
}

///|
pub fn[Msg] flexible(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.flexible(weight~)
}

///|
pub fn[Msg] layout_priority(
  child : @core.View[Msg],
  priority : Double,
) -> @core.View[Msg] {
  child.layout_priority(priority)
}

///|
pub fn[Msg] align(
  child : @core.View[Msg],
  alignment? : @core.Alignment = @core.Alignment::center(),
) -> @core.View[Msg] {
  child.align(alignment~)
}

///|
pub fn[Msg] rounded_clip(
  child : @core.View[Msg],
  radius? : Double = 0.0,
) -> @core.View[Msg] {
  @core.View::from_node(RoundedClip::{ radius, }, children=_node => [child])
}

///|
priv struct RoundedClip {
  radius : Double
}

///|
impl @core.ViewNode for RoundedClip with fn identity(_self) {
  @core.ViewIdentity::new(kind="RoundedClip")
}

///|
impl @core.ViewNode for RoundedClip with fn declaration(self) {
  view_paint_declaration(@core.DeclarationKey::double(self.radius))
}

///|
impl @core.ViewNode for RoundedClip with fn child_constraints(
  _self,
  constraints,
) {
  constraints
}

///|
impl @core.ViewNode for RoundedClip with fn layout(_self, ctx) {
  let child_size = if ctx.child_sizes.is_empty() {
    ctx.constraints.constrain(@core.Size::new(width=0.0, height=0.0))
  } else {
    ctx.constraints.constrain(ctx.child_sizes[0])
  }
  @core.ViewLayoutResult::new(size=child_size, child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
impl @core.ViewNode for RoundedClip with fn paint(self, ctx) {
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=self.radius)
  {
    commands: [@core.DrawCommand::PushRoundedClip(rounded)],
    child_layers: [],
    post_commands: [@core.DrawCommand::PopRoundedClip],
    overlay_commands: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for RoundedClip with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}

///|
pub fn[Msg] aspect_ratio(
  child : @core.View[Msg],
  ratio : Double,
) -> @core.View[Msg] {
  child.aspect_ratio(ratio)
}

///|
pub fn[Msg] intrinsic_width(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_width()
}

///|
pub fn[Msg] intrinsic_height(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_height()
}

///|
pub fn[Msg] custom_children_layout(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint~ : (PaintContext, @core.Rect) -> Unit,
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @controls.custom_children_layout_control(
    children~,
    measure~,
    place~,
    paint~,
    semantics_role~,
    semantics_label~,
  )
}

///|
pub fn[Msg] component(
  build : (@core.ComponentContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @controls.component_host(build)
}
