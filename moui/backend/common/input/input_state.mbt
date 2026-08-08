///|
/// Shared mutable input state. Platform packages keep raw event decoding and
/// feed normalized facts through this common owner.
pub(all) struct InputState {
  mut focused : Bool
  mut modifiers : @core.KeyModifiers
  contract : @backend_host.HostInputContract
}

///|
pub fn InputState::new(
  focused? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
  contract? : @backend_host.HostInputContract = @backend_host.HostInputContract::new(),
) -> InputState {
  { focused, modifiers, contract }
}

///|
pub fn InputState::focus(self : InputState) -> Unit {
  self.focused = true
}

///|
pub fn InputState::blur(self : InputState) -> Unit {
  self.focused = false
}

///|
pub fn InputState::set_modifiers(
  self : InputState,
  modifiers : @core.KeyModifiers,
) -> Unit {
  self.modifiers = modifiers
}

///|
pub fn InputState::capabilities(
  self : InputState,
) -> @backend_host.HostInputCapabilities {
  self.contract.capabilities
}

///|
pub fn InputState::coordinate_policy(
  self : InputState,
) -> @backend_host.HostCoordinatePolicy {
  self.contract.coordinates
}

///|
pub fn InputState::focus_event(
  self : InputState,
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> @backend_host.Event? {
  if self.contract.capabilities.focus {
    self.focused = focused
    Some(
      @backend_host.Event::Focus(
        @backend_host.HostFocusEvent::new(focused~, pointer_cancel_position~),
      ),
    )
  } else {
    None
  }
}

///|
pub fn InputState::keyboard_event(
  self : InputState,
  key~ : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
) -> @backend_host.Event? {
  if self.contract.capabilities.keyboard {
    Some(
      @backend_host.Event::Keyboard(
        @core.KeyboardEvent::new(
          key~,
          text~,
          pressed~,
          repeat~,
          modifiers=self.modifiers,
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn InputState::text_event(
  self : InputState,
  event : @core.TextInputEvent,
) -> @backend_host.Event? {
  if self.focused && self.contract.capabilities.text_input {
    Some(@backend_host.Event::TextInput(event))
  } else {
    None
  }
}

///|
pub fn InputState::insert_text(
  self : InputState,
  text : String,
) -> @backend_host.Event? {
  self.text_event(@core.TextInputEvent::InsertText(text))
}
