///|
priv struct RichTextComponentNode {
  kind : String
  key : String?
}

///|
impl @core.ViewNode for RichTextComponentNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for RichTextComponentNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for RichTextComponentNode with fn layout(_self, ctx) {
  match ctx.child_sizes {
    [child, ..] =>
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(child), child_frames=[
        @core.Rect::new(x=0.0, y=0.0, width=child.width, height=child.height),
      ])
    [] =>
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=0.0, height=0.0)),
      )
  }
}

///|
fn[Msg] rich_text_component(
  kind : String,
  key : String?,
  build : (@core.ComponentContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @core.View::from_node(
    RichTextComponentNode::{ kind, key },
    build_child=Some((_node, context) => build(context)),
  )
}
