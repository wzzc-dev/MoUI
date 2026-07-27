///|
fn[Msg] runtime_component_view(
  build : (@core.ComponentContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @core.View::from_node(
    RuntimeComponentViewNode::{  },
    build_child=Some((_node, context) => build(context)),
  )
}

///|
priv struct RuntimeComponentViewNode {}

///|
impl @core.ViewNode for RuntimeComponentViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Component")
}

///|
impl @core.ViewNode for RuntimeComponentViewNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for RuntimeComponentViewNode with fn layout(_self, context) {
  let child_size = if context.child_sizes.length() > 0 {
    context.child_sizes[0]
  } else {
    @core.Size::new(width=0.0, height=0.0)
  }
  let size = context.constraints.constrain(child_size)
  @core.ViewLayoutResult::new(
    size~,
    child_frames=if context.child_sizes.length() > 0 {
      [@core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)]
    } else {
      []
    },
  )
}
