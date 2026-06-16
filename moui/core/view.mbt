///|
pub struct View[Msg] {
  priv node : ViewNode[Msg]
}

///|
fn[Msg] view_from_node(node : ViewNode[Msg]) -> View[Msg] {
  { node, }
}

///|
pub fn[Msg] View::widget(ops : WidgetOps[Msg]) -> View[Msg] {
  view_from_node(WidgetNode(ops))
}

///|
pub fn[Msg] View::widget_ops(self : View[Msg]) -> WidgetOps[Msg]? {
  match self.node {
    WidgetNode(ops) => Some(ops)
    _ => None
  }
}

///|
fn[Msg] modify_view(
  view : View[Msg],
  modifier : ViewModifierNode[Msg],
) -> View[Msg] {
  view_from_node(ModifiedNode(modifier, view.node))
}
