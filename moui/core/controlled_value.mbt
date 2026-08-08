///|
/// Immutable controlled input for composite controls.
///
/// The current value is a snapshot from the application model. User
/// interaction can only construct a typed message; the control has no setter
/// or mutable model capability.
pub struct ControlledValue[T, Msg] {
  priv current : T
  priv changed_message : (T) -> Msg
}

///|
pub fn[T, Msg] ControlledValue::new(
  value~ : T,
  changed~ : (T) -> Msg,
) -> ControlledValue[T, Msg] {
  { current: value, changed_message: changed }
}

///|
pub fn[T, Msg] ControlledValue::value(self : ControlledValue[T, Msg]) -> T {
  self.current
}

///|
pub fn[T, Msg] ControlledValue::changed(
  self : ControlledValue[T, Msg],
  value : T,
) -> Msg {
  (self.changed_message)(value)
}
