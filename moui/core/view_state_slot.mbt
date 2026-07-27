///|
/// A value that can be stored in a runtime-owned view-state slot.
///
/// The type key is part of slot identity, so two slots with the same logical
/// key but different value types cannot alias. Implementations must use a
/// stable, versioned type key and an exact, deterministic byte encoding.
pub(open) trait ViewStateValue {
  fn view_state_type_key() -> DeclarationKey
  fn encode_view_state(Self) -> Bytes
  fn decode_view_state(Self, Bytes) -> Self?
}

///|
/// A typed descriptor for one node-scoped transient state value.
///
/// Descriptors are immutable declaration-time values. The stored bytes live in
/// the reconciled runtime element and are preserved only while that element's
/// identity is reused.
pub struct ViewStateSlot[T] {
  priv key : DeclarationKey
  priv initial : T
}

///|
/// Runtime-owned storage behind `ViewStateContext`.
pub struct ViewStateSlots {
  priv values : Map[DeclarationKey, Bytes]
} derive(Eq, Debug)

///|
pub fn[T : ViewStateValue] ViewStateSlot::new(
  key~ : DeclarationKey,
  initial~ : T,
) -> ViewStateSlot[T] {
  {
    key: DeclarationKey::record(type_tag="moui.core.ViewStateSlot.v1", fields=[
      ("type", T::view_state_type_key()),
      ("slot", key),
    ]),
    initial,
  }
}

///|
pub fn ViewStateSlots::empty() -> ViewStateSlots {
  { values: Map([]) }
}

///|
/// Read a typed slot, returning the descriptor's initial value when this
/// element has not written the slot yet.
pub fn[T : ViewStateValue] ViewStateContext::read_slot(
  self : ViewStateContext,
  slot : ViewStateSlot[T],
) -> T {
  match self.slots.values.get(slot.key) {
    Some(bytes) => slot.initial.decode_view_state(bytes).unwrap_or(slot.initial)
    None => slot.initial
  }
}

///|
/// Return a state proposal with one typed slot updated. The current context is
/// never mutated, so runtimes can validate an event or semantic action before
/// committing the returned state.
pub fn[T : ViewStateValue] ViewStateContext::with_slot(
  self : ViewStateContext,
  slot : ViewStateSlot[T],
  value : T,
) -> ViewStateContext {
  let encoded = value.encode_view_state()
  match self.slots.values.get(slot.key) {
    Some(current) if current == encoded => self
    _ => {
      let values = self.slots.values.copy()
      values[slot.key] = encoded
      { ..self, slots: { values, } }
    }
  }
}

///|
/// Return a state proposal with one slot reset to its initial value.
pub fn[T] ViewStateContext::without_slot(
  self : ViewStateContext,
  slot : ViewStateSlot[T],
) -> ViewStateContext {
  if !self.slots.values.contains(slot.key) {
    self
  } else {
    let values = self.slots.values.copy()
    values.remove(slot.key)
    { ..self, slots: { values, } }
  }
}

///|
pub impl ViewStateValue for Bool with fn view_state_type_key() {
  DeclarationKey::string("moonbit.Bool")
}

///|
pub impl ViewStateValue for Bool with fn encode_view_state(self) {
  if self {
    b"\x01"
  } else {
    b"\x00"
  }
}

///|
pub impl ViewStateValue for Bool with fn decode_view_state(_self, bytes) {
  match bytes {
    b"\x00" => Some(false)
    b"\x01" => Some(true)
    _ => None
  }
}

///|
pub impl ViewStateValue for Int with fn view_state_type_key() {
  DeclarationKey::string("moonbit.Int32")
}

///|
pub impl ViewStateValue for Int with fn encode_view_state(self) {
  let output = Buffer(size_hint=4)
  output.write_int_be(self)
  output.to_bytes()
}

///|
pub impl ViewStateValue for Int with fn decode_view_state(_self, bytes) {
  if bytes.length() != 4 {
    None
  } else {
    let bits = (bytes[0].to_uint() << 24) |
      (bytes[1].to_uint() << 16) |
      (bytes[2].to_uint() << 8) |
      bytes[3].to_uint()
    Some(bits.reinterpret_as_int())
  }
}

///|
pub impl ViewStateValue for Double with fn view_state_type_key() {
  DeclarationKey::string("moonbit.Double64")
}

///|
pub impl ViewStateValue for Double with fn encode_view_state(self) {
  self.reinterpret_as_uint64().to_be_bytes()
}

///|
pub impl ViewStateValue for Double with fn decode_view_state(_self, bytes) {
  if bytes.length() != 8 {
    None
  } else {
    let mut bits = 0UL
    for byte in bytes {
      bits = (bits << 8) | byte.to_uint64()
    }
    Some(bits.reinterpret_as_double())
  }
}

///|
pub impl ViewStateValue for String with fn view_state_type_key() {
  DeclarationKey::string("moonbit.String.utf8")
}

///|
pub impl ViewStateValue for String with fn encode_view_state(self) {
  @utf8.encode(self[:], bom=false)
}

///|
pub impl ViewStateValue for String with fn decode_view_state(_self, bytes) {
  Some(@utf8.decode(bytes[:], ignore_bom=false)) catch {
    _ => None
  }
}

///|
pub impl ViewStateValue for Bytes with fn view_state_type_key() {
  DeclarationKey::string("moonbit.Bytes")
}

///|
pub impl ViewStateValue for Bytes with fn encode_view_state(self) {
  self
}

///|
pub impl ViewStateValue for Bytes with fn decode_view_state(_self, bytes) {
  Some(bytes)
}
