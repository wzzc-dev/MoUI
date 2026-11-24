///|
/// Optional platform-owned frame state. `None` means "this plugin image does
/// not carry the field" (an older image), while an empty platform-view list
/// means "supported, currently none" — the distinction lets the host clean up
/// native views after a swap without guessing from an absent field.
fn nullable_semantics_json(payload : @core.SemanticsFramePayload?) -> Json {
  match payload {
    Some(payload) => semantics_payload_json(payload)
    None => Json::null()
  }
}

///|
fn nullable_text_input_json(state : @core.TextInputState?) -> Json {
  match state {
    Some(state) => text_input_state_json(state)
    None => Json::null()
  }
}
