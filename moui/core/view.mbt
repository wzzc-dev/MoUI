///|
pub struct View[Msg] {
  priv ops : WidgetOps[Msg]
}

///|
fn[Msg] view_from_ops(ops : WidgetOps[Msg]) -> View[Msg] {
  { ops, }
}

///|
pub fn[Msg] View::widget(ops : WidgetOps[Msg]) -> View[Msg] {
  view_from_ops(ops)
}

///|
pub fn[Msg] View::widget_ops(self : View[Msg]) -> WidgetOps[Msg]? {
  Some(self.ops)
}

///|
pub fn[Msg] View::ops(self : View[Msg]) -> WidgetOps[Msg] {
  self.ops
}
