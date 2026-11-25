///|
/// Platform state decoded from the plugin's most recent frame. The bridge host
/// presents the plugin's pixels through the host runtime, but semantics, text
/// input, platform views, overlay bounds and the frame clear belong to the
/// plugin and are published here for the host driver hooks and platform-view
/// wrappers.
priv struct DevHostState {
  mut payload : @protocol.FramePayload?
  mut text_input : @core.TextInputState?
  /// Synthetic generations keep `read_semantics` monotonic across a plugin
  /// swap even though a fresh plugin runtime restarts its own counter.
  mut semantics_cleared_generation : UInt64
  mut semantics_present : Bool
  mut semantics_force_full : Bool
}

///|
fn DevHostState::new() -> DevHostState {
  {
    payload: None,
    text_input: None,
    semantics_cleared_generation: 1UL,
    semantics_present: false,
    // The first read after startup must be a Full snapshot, not Unchanged.
    semantics_force_full: true,
  }
}

///|
let dev_host_state : Ref[DevHostState?] = Ref(None)

///|
fn host_state() -> DevHostState {
  match dev_host_state.val {
    Some(state) => state
    None => {
      let state = DevHostState::new()
      dev_host_state.val = Some(state)
      state
    }
  }
}

///|
/// Publish the platform state carried by one decoded plugin frame. The host
/// paint path already decoded the frame, so callers pass the payload directly.
fn publish_frame(payload : @protocol.FramePayload) -> Array[@core.DrawCommand] {
  let state = host_state()
  state.payload = Some(payload)
  state.text_input = payload.text_input()
  match payload.semantics() {
    Some(_) =>
      if !state.semantics_present {
        // Coming back from a frame without semantics needs a forced Full
        // read: a plugin-swap generation may collide with a stale cursor.
        state.semantics_present = true
        state.semantics_force_full = true
      }
    None =>
      if state.semantics_present {
        state.semantics_present = false
        state.semantics_cleared_generation = state.semantics_cleared_generation +
          1UL
      }
  }
  payload.commands()
}

///|
/// Drop generation-scoped state after a successful plugin swap. The new
/// generation republishes on its first frame; until then the host exposes an
/// empty semantics tree and no text input, so no node or focus from the old
/// generation survives.
pub fn clear_after_reload() -> Unit {
  let state = host_state()
  state.payload = None
  state.text_input = None
  state.semantics_present = false
  state.semantics_force_full = true
  state.semantics_cleared_generation = state.semantics_cleared_generation + 1UL
}

///|
/// Layer plugin-owned fields onto the frame painted by the host runtime.
/// Commands and damage stay host-owned: the bridge view paints the plugin's
/// commands and the runtime tracks dirty regions for them. The damage is forced
/// full so a transparent platform-view frame is never skipped by a raster
/// renderer that only redraws dirty rectangles.
pub fn augment_frame(frame : @core.DrawFrame) -> @core.DrawFrame {
  match host_state().payload {
    Some(payload) =>
      {
        ..frame,
        platform_views: match payload.platform_views() {
          Some(views) => views
          None => []
        },
        overlay_bounds: payload.overlay_bounds(),
        damage: @core.DamageRegion::full("dev hot bridge frame"),
        clear_color: payload.clear_color(),
        semantics: payload.semantics(),
      }
    None => frame
  }
}

///|
pub fn focused_text_input() -> @core.TextInputState {
  match host_state().text_input {
    Some(input) => input
    None => @core.TextInputState::none()
  }
}

///|
fn read_empty_semantics(
  state : DevHostState,
  since : @core.SemanticsGeneration?,
) -> Result[@runtime.SemanticsRead, @runtime.SemanticsReadError] {
  let generation = @core.SemanticsGeneration::new(
    state.semantics_cleared_generation,
  )
  if !state.semantics_force_full && since == Some(generation) {
    Ok(@runtime.SemanticsRead::Unchanged(generation))
  } else {
    state.semantics_force_full = false
    let empty = @core.SemanticsFramePayload::new(generation~, nodes=[])
    Ok(
      @runtime.SemanticsRead::Full(
        @runtime.SemanticsSnapshot::from_frame_payload(empty),
      ),
    )
  }
}

///|
/// Serve the host accessibility bridge from the last committed plugin frame.
/// A frame without semantics yields an empty Full snapshot (after a swap, or
/// when the plugin stops publishing a tree), which removes stale nodes.
pub fn read_semantics(
  since : @core.SemanticsGeneration?,
) -> Result[@runtime.SemanticsRead, @runtime.SemanticsReadError] {
  let state = host_state()
  match state.payload {
    Some(payload) =>
      match payload.semantics() {
        Some(manifest) => {
          let generation = manifest.generation()
          if !state.semantics_force_full && since == Some(generation) {
            Ok(@runtime.SemanticsRead::Unchanged(generation))
          } else {
            state.semantics_force_full = false
            Ok(
              @runtime.SemanticsRead::Full(
                @runtime.SemanticsSnapshot::from_frame_payload(manifest),
              ),
            )
          }
        }
        None => read_empty_semantics(state, since)
      }
    None => read_empty_semantics(state, since)
  }
}

///|
/// Route a semantics action across the plugin boundary. Plugins built before
/// the optional action entry point are reported as not exposing the action
/// instead of dropping the request silently.
pub fn dispatch_semantics_action(
  request : @runtime.PerformSemanticsActionRequest,
) -> Result[
  @runtime.SemanticsActionReceipt,
  @runtime.SemanticsActionDispatchError,
] {
  let payload = @protocol.encode_semantics_action_request(request)
  let bytes = utf8_bytes(payload)
  let response = moui_devhost_semantics_action(bytes, bytes.length())
  if response.length() == 0 {
    return Err(
      @runtime.SemanticsActionDispatchError::ActionUnavailable(
        request.target,
        request.action.kind(),
      ),
    )
  }
  let text = @utf8.decode_lossy(response[:], ignore_bom=true)
  match @protocol.decode_semantics_action_result(text) {
    Some(result) => result
    None =>
      Err(
        @runtime.SemanticsActionDispatchError::ActionUnavailable(
          request.target,
          request.action.kind(),
        ),
      )
  }
}

///|
/// Build the host-driver overrides a generated bridge host passes to its
/// platform backend options.
pub fn driver_hooks() -> @apphost.HostDriverHooks {
  @apphost.HostDriverHooks::new(
    read_semantics=Some(read_semantics),
    perform_semantics_action=Some(dispatch_semantics_action),
    focused_text_input=Some(focused_text_input),
    augment_frame=Some(augment_frame),
  )
}
