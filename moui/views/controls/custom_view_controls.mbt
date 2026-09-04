///|
/// Multi-child custom layout delegate.
///
/// This is the dedicated callback entry for the `@views.custom_children_layout`
/// API: callers supply `measure` / `place` / `paint` closures plus semantics
/// metadata, and the framework wires them to a concrete `CustomChildrenLayout`.
/// The closures capture only immutable declaration data; the node never carries
/// runtime mutable state such as a layout cache (the previous `CustomLayoutCache`
/// was a violation of `ViewNode`'s "immutable declaration data" contract).
pub fn[Msg] custom_children_layout_control(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint~ : (@common.PaintContext, @core.Rect) -> Unit,
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
  kind? : String = "CustomLayout",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    CustomChildrenLayout::{
      measure,
      place,
      paint,
      semantics_role,
      semantics_label,
      kind,
      key,
    },
    children=_node => children,
  )
}

///|
/// Multi-child custom layout delegate node.
///
/// This is the dedicated node for the `@views.custom_children_layout`
/// callback-based API. Unlike the removed generic `custom_control` factory,
/// it stores only immutable declaration data (the `measure`, `place`, `paint`
/// callbacks plus semantics metadata) and never carries runtime mutable state
/// such as a layout cache. The runtime assembles `ChildLayoutInfo` entries
/// from measured/placed children and passes them via `CustomLayoutContext`.
priv struct CustomChildrenLayout {
  measure : (@core.CustomLayoutContext) -> @core.Size // declaration-exempt: consumed only by the Uncacheable layout channel
  place : (@core.CustomPlacementContext) -> Array[@core.Rect] // declaration-exempt: consumed only by the Uncacheable layout channel
  paint : (@common.PaintContext, @core.Rect) -> Unit // declaration-exempt: consumed only by the Uncacheable paint channel
  semantics_role : @core.SemanticsRole
  semantics_label : String
  kind : String
  key : String?
}

///|
impl @core.ViewNode for CustomChildrenLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for CustomChildrenLayout with fn declaration(self) {
  @common.view_declaration(
    layout=@core.DeclarationChannel::Uncacheable,
    paint=@core.DeclarationChannel::Uncacheable,
    semantics=@common.view_exact_channel(
      @common.view_record_key("CustomChildrenLayout.semantics", [
        ("role", @common.view_semantics_role_key(self.semantics_role)),
        ("label", @core.DeclarationKey::string(self.semantics_label)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for CustomChildrenLayout with fn layout(self, ctx) {
  let children : Array[@core.ChildLayoutInfo] = []
  for size in ctx.child_sizes {
    children.push(@core.ChildLayoutInfo::new(size~))
  }
  let layout_context = @core.CustomLayoutContext::{
    constraints: ctx.constraints,
    children,
    layout_direction: ctx.environment.layout_direction,
    safe_area: @core.Insets::symmetric(),
    viewport: None,
  }
  let size = (self.measure)(layout_context)
  let absolute_frame = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=size.width,
    height=size.height,
  )
  let placement_context = @core.CustomPlacementContext::{
    frame: absolute_frame,
    measured_size: size,
    children,
    layout_direction: ctx.environment.layout_direction,
    safe_area: @core.Insets::symmetric(),
    viewport: None,
  }
  @core.ViewLayoutResult::new(
    size~,
    child_frames=(self.place)(placement_context).map(frame => {
      @core.Rect::new(
        x=frame.origin.x - absolute_frame.origin.x,
        y=frame.origin.y - absolute_frame.origin.y,
        width=frame.size.width,
        height=frame.size.height,
      )
    }),
  )
}

///|
impl @core.ViewNode for CustomChildrenLayout with fn paint(self, ctx) {
  let pctx = @common.PaintContext::new()
  (self.paint)(pctx, ctx.frame)
  @core.ViewPaintPlan::commands(@common.PaintContext::finish(pctx))
}

///|
impl @core.ViewNode for CustomChildrenLayout with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=if self.semantics_label == "" &&
      self.semantics_role == @core.SemanticsRole::Group {
      @core.SemanticsComposition::Transparent
    } else {
      @core.SemanticsComposition::Boundary
    },
    role=self.semantics_role,
    label=self.semantics_label,
    value=self.semantics_label,
  )
}
