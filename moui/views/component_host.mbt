///|
fn[Msg] component_host(
  build : (@core.ComponentContext) -> @core.View[Msg],
  kind? : String = "Component",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    ComponentHost::{ kind, key },
    build_child=Some((_node, context) => build(context)),
  )
}

///|
priv struct ComponentHost {
  kind : String
  key : String?
}

///|
impl @core.ViewNode for ComponentHost with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for ComponentHost with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for ComponentHost with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(first_child_size(context.child_sizes)),
    child_frames=if context.child_sizes.length() > 0 {
      let size = first_child_size(context.child_sizes)
      [@core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)]
    } else {
      []
    },
  )
}
