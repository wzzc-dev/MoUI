///|
struct DownstreamSlotValue {
  count : Int
  progress : Double
} derive(Eq, Debug)

///|
impl @core.ViewStateValue for DownstreamSlotValue with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.core.test.DownstreamSlotValue.v1")
}

///|
impl @core.ViewStateValue for DownstreamSlotValue with fn encode_view_state(
  self,
) {
  let output = Buffer(size_hint=12)
  output.write_int_be(self.count)
  output.write_double_be(self.progress)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for DownstreamSlotValue with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 12 {
    None
  } else {
    let count = @core.ViewStateValue::decode_view_state(
      0,
      bytes[0:4].to_owned(),
    )
    let progress = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[4:12].to_owned(),
    )
    match (count, progress) {
      (Some(count), Some(progress)) => Some({ count, progress })
      _ => None
    }
  }
}

///|
fn slot_test_state() -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
}

///|
test "ViewStateSlot: typed values update immutably and reset" {
  let slot = @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("downstream.progress"),
    initial=DownstreamSlotValue::{ count: 0, progress: 0.0 },
  )
  let initial = slot_test_state()
  let updated = initial.with_slot(slot, DownstreamSlotValue::{
    count: 7,
    progress: 0.625,
  })
  debug_inspect(initial.read_slot(slot), content="{ count: 0, progress: 0 }")
  debug_inspect(
    updated.read_slot(slot),
    content="{ count: 7, progress: 0.625 }",
  )
  debug_inspect(
    updated.without_slot(slot).read_slot(slot),
    content="{ count: 0, progress: 0 }",
  )
}

///|
test "ViewStateSlot: value type participates in slot identity" {
  let logical_key = @core.DeclarationKey::string("same-logical-key")
  let int_slot = @core.ViewStateSlot::new(key=logical_key, initial=0)
  let string_slot = @core.ViewStateSlot::new(key=logical_key, initial="unset")
  let state = slot_test_state()
    .with_slot(int_slot, 42)
    .with_slot(string_slot, "set")
  inspect(state.read_slot(int_slot), content="42")
  inspect(state.read_slot(string_slot), content="set")
}

///|
test "ViewStateSlot: primitive codecs preserve exact values" {
  let key = @core.DeclarationKey::string("exact-double")
  let slot = @core.ViewStateSlot::new(key~, initial=0.0)
  let negative_zero = (-0.0).reinterpret_as_uint64()
  let round_trip = slot_test_state().with_slot(slot, -0.0).read_slot(slot)
  inspect(round_trip.reinterpret_as_uint64() == negative_zero, content="true")
}
