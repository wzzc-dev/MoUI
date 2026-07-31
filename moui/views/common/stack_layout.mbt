///|
/// Shared stack layout (children stacked at the same origin). Single
/// implementation for the root facade and every view sub-package.
pub fn[Msg] stack_layout(
  children~ : Array[@core.View[Msg]],
  kind? : String = "Stack",
  key? : String? = None,
) -> @core.View[Msg] {
  let child_views : (StackLayout) -> Array[@core.View[Msg]] = _node => {
    let captured_children = children
    captured_children
  }
  @core.View::from_node(StackLayout::{ kind, key }, children=child_views)
}

///|
priv struct StackLayout {
  kind : String
  key : String?
}

///|
impl @core.ViewNode for StackLayout with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for StackLayout with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for StackLayout with fn layout(_self, ctx) {
  let mut width = 0.0
  let mut height = 0.0
  let frames : Array[@core.Rect] = []
  for size in ctx.child_sizes {
    width = view_max_double(width, size.width)
    height = view_max_double(height, size.height)
  }
  let size = ctx.constraints.constrain(@core.Size::new(width~, height~))
  for _child in ctx.child_sizes {
    frames.push(
      @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
    )
  }
  @core.ViewLayoutResult::new(size~, child_frames=frames)
}

///|
impl @core.ViewNode for StackLayout with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}
