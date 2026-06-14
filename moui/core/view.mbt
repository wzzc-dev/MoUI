///|
pub struct View[Msg] {
  priv node : ViewNode[Msg]
}

///|
pub struct RuntimeViewSpec {
  priv spec : ViewSpec
}

///|
fn[Msg] view_from_node(node : ViewNode[Msg]) -> View[Msg] {
  { node, }
}

///|
fn[Msg] modify_view(
  view : View[Msg],
  modifier : ViewModifierNode[Msg],
) -> View[Msg] {
  view_from_node(ModifiedNode(modifier, view.node))
}

///|
fn[Msg] modify_realized_view(
  view : View[Msg],
  modifier : (ViewSpec) -> ViewSpec,
) -> View[Msg] {
  modify_view(view, RealizedModifier(modifier))
}

///|
fn[Msg] realize_view(view : View[Msg], emit : (Msg) -> Unit) -> ViewSpec {
  realize_view_node(view.node, emit)
}

///|
pub fn[Msg] View::runtime_realize(
  self : View[Msg],
  emit : (Msg) -> Unit,
) -> RuntimeViewSpec {
  { spec: realize_view(self, emit) }
}

///|
pub fn RuntimeViewSpec::runtime_kind_label(self : RuntimeViewSpec) -> String {
  self.spec.inspector_kind_label()
}
