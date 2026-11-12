///|
/// Live scroll state owned by the markdown editor element.
///
/// The app should not receive a message per wheel tick: that turns a scroll
/// gesture into a stream of root rebuilds while the content itself only moves
/// inside the editor's paint. The element keeps the glide here, paints it from
/// the frame clock, and reports one settled offset at the end of the gesture.
///
/// The slot survives root rebuilds while the editor element identity is reused
/// (the app keys the editor), so a settle message and the following rebuild do
/// not reset the visible position.
priv struct MarkdownSessionScrollState {
  /// The eased offset. `from_y == to_y` means at rest.
  glide : MarkdownScrollGlide
  /// Monotonic `ScrollRequest` cursor. `-2` means the slot has never been
  /// seeded from the node's controlled glide; `-1` means seeded with no
  /// request applied.
  applied_request_id : Int32
  /// Motion happened and the settled notification has not fired yet.
  settle_pending : Bool
  /// The settled notification already fired for this gesture.
  settle_notified : Bool
  /// Animation clock time of the most recent wheel input, used to classify a
  /// dense stream and to debounce the settle notification.
  last_motion_ms : Double
}

///|
/// A wheel event closer than this to the previous one belongs to one stream
/// (trackpad gesture or platform momentum). Mirrors the MoMark app's previous
/// classification so the feel does not change with ownership.
fn markdown_session_scroll_stream_gap_ms() -> Double {
  24.0
}

///|
/// After the glide reaches its target, wait this long for another wheel event
/// before reporting the settled offset. A momentum tail emits events faster
/// than this; a finished gesture does not.
fn markdown_session_scroll_settle_gap_ms() -> Double {
  80.0
}

///|
/// Time constant for a dense stream: just enough smoothing to land the OS's
/// irregular event cadence on the display's frame grid.
fn markdown_session_scroll_stream_tau_ms() -> Double {
  28.0
}

///|
/// Time constant for an isolated wheel notch: a visible ease the user can aim
/// with.
fn markdown_session_scroll_notch_tau_ms() -> Double {
  90.0
}

///|
impl @core.ViewStateValue for MarkdownSessionScrollState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui_richtext.MarkdownSessionScrollState.v1")
}

///|
impl @core.ViewStateValue for MarkdownSessionScrollState with fn encode_view_state(
  self,
) {
  let output = Buffer(size_hint=46)
  output.write_double_be(self.glide.from_y)
  output.write_double_be(self.glide.to_y)
  output.write_double_be(self.glide.start_ms)
  output.write_double_be(self.glide.tau_ms)
  output.write_int_be(self.applied_request_id)
  output.write_byte(if self.settle_pending { 1 } else { 0 })
  output.write_byte(if self.settle_notified { 1 } else { 0 })
  output.write_double_be(self.last_motion_ms)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for MarkdownSessionScrollState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 46 {
    return None
  }
  match
    (
      @core.ViewStateValue::decode_view_state(0.0, bytes[0:8].to_owned()),
      @core.ViewStateValue::decode_view_state(0.0, bytes[8:16].to_owned()),
      @core.ViewStateValue::decode_view_state(0.0, bytes[16:24].to_owned()),
      @core.ViewStateValue::decode_view_state(0.0, bytes[24:32].to_owned()),
      @core.ViewStateValue::decode_view_state(0, bytes[32:36].to_owned()),
      @core.ViewStateValue::decode_view_state(0.0, bytes[38:46].to_owned()),
    ) {
    (
      Some(from_y),
      Some(to_y),
      Some(start_ms),
      Some(tau_ms),
      Some(id),
      Some(last_motion_ms),
    ) =>
      Some({
        glide: { from_y, to_y, start_ms, tau_ms, },
        applied_request_id: id,
        settle_pending: bytes[36].to_int() != 0,
        settle_notified: bytes[37].to_int() != 0,
        last_motion_ms,
      })
    _ => None
  }
}

///|
fn markdown_session_scroll_state_slot() -> @core.ViewStateSlot[
  MarkdownSessionScrollState,
] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui_richtext.editor.scroll"),
    initial={
      glide: MarkdownScrollGlide::settled(0.0),
      applied_request_id: -2,
      settle_pending: false,
      settle_notified: true,
      last_motion_ms: 0.0,
    },
  )
}

///|
/// Seed the slot from the controlled glide on first use and apply a newer
/// programmatic scroll request. Read-only: callers that paint use this without
/// mutating the slot; event handlers write the returned value back.
fn markdown_session_effective_scroll_state(
  stored : MarkdownSessionScrollState,
  seed_glide : MarkdownScrollGlide,
  scroll_request : @core.ScrollRequest?,
  max_scroll~ : Double,
) -> MarkdownSessionScrollState {
  let base = if stored.applied_request_id == -2 {
    { ..stored, glide: seed_glide, applied_request_id: -1, }
  } else {
    stored
  }
  match scroll_request {
    Some(request) if request.id > base.applied_request_id =>
      {
        glide: MarkdownScrollGlide::settled(
          request.offset.y.max(0.0).min(max_scroll),
        ),
        applied_request_id: request.id,
        settle_pending: false,
        settle_notified: true,
        last_motion_ms: 0.0,
      }
    _ => base
  }
}

///|
/// Maximum scroll offset for the editor's current document and viewport.
fn markdown_session_max_scroll_y(
  session : MarkdownDocumentSession,
  font : @core.FontSpec,
  source_mode~ : Bool,
  viewport_height : Double,
  content_width : Double,
) -> Double {
  if viewport_height <= 0.0 {
    return 0.0
  }
  let content_height = session.estimated_content_height(
      base=font,
      source_mode~,
      content_width~,
    ) +
    96.0
  (content_height - viewport_height).max(0.0)
}

///|
/// Apply one wheel delta to the live state. Returns `None` when the offset is
/// already at a hard edge and nothing is moving, so the host can use the
/// platform's edge behavior.
fn markdown_session_transient_wheel(
  state : MarkdownSessionScrollState,
  wheel_delta_y : Double,
  now_ms : Double,
  max_scroll : Double,
) -> MarkdownSessionScrollState? {
  if wheel_delta_y == 0.0 {
    return None
  }
  let shown = state.glide.exact_offset_at(now_ms).max(0.0).min(max_scroll)
  let target = (state.glide.to_y - wheel_delta_y).max(0.0).min(max_scroll)
  let moving = state.glide.is_animating(now_ms) || state.settle_pending
  if target == shown && !moving {
    return None
  }
  let since_last = now_ms - state.last_motion_ms
  let continuous = state.last_motion_ms > 0.0 &&
    since_last >= 0.0 &&
    since_last <= markdown_session_scroll_stream_gap_ms() &&
    moving
  let glide = MarkdownScrollGlide::new(
    from_y=shown,
    to_y=target,
    start_ms=now_ms,
    tau_ms=if continuous {
      markdown_session_scroll_stream_tau_ms()
    } else {
      markdown_session_scroll_notch_tau_ms()
    },
  )
  Some({
    glide,
    applied_request_id: state.applied_request_id,
    settle_pending: true,
    settle_notified: false,
    last_motion_ms: now_ms,
  })
}

///|
/// Freeze the glide at the offset currently shown. Called before a text edit so
/// content reflow starts from the position the user sees, not from a target
/// that may still be easing.
fn markdown_session_pin_scroll(
  state : MarkdownSessionScrollState,
  now_ms : Double,
  max_scroll : Double,
) -> MarkdownSessionScrollState {
  if !state.glide.is_animating(now_ms) && !state.settle_pending {
    return state
  }
  let shown = state.glide.exact_offset_at(now_ms).max(0.0).min(max_scroll)
  {
    glide: MarkdownScrollGlide::settled(shown),
    applied_request_id: state.applied_request_id,
    settle_pending: false,
    settle_notified: true,
    last_motion_ms: state.last_motion_ms,
  }
}

///|
/// If the glide has reached its target and the stream has been quiet long
/// enough, clear the settle latch and return the offset to report exactly once.
fn markdown_session_transient_settle(
  state : MarkdownSessionScrollState,
  now_ms : Double,
  max_scroll : Double,
) -> (MarkdownSessionScrollState, Double?) {
  if !state.settle_pending || state.glide.is_animating(now_ms) {
    return (state, None)
  }
  if now_ms - state.last_motion_ms < markdown_session_scroll_settle_gap_ms() {
    return (state, None)
  }
  let shown = state.glide.exact_offset_at(now_ms).max(0.0).min(max_scroll)
  ({ ..state, settle_pending: false, settle_notified: true, }, Some(shown))
}

///|
/// Event entry for the transient-scroll editor mode.
///
/// Wheel input writes only the element slot: `changed=true` keeps the host
/// consuming the wheel, `activated=false` and an empty message list keep the
/// program root untouched. Pointer hit-testing, keyboard caret moves and text
/// input use the same frame-local slot sample as paint. A `FrameTick` reports
/// the offset once after the gesture settles.
fn[Msg] markdown_session_editor_event_transient(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int32, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int32) -> Msg)?,
  on_command_click~ : ((Int32) -> Msg)?,
  accepts_tab_input~ : Bool,
  seed_glide~ : MarkdownScrollGlide,
  scroll_request~ : @core.ScrollRequest?,
  on_scroll_settled~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  let slot = markdown_session_scroll_state_slot()
  let content_width = rich_text_editor_content_rect(ctx.frame).size.width
  let max_scroll = markdown_session_max_scroll_y(
    session,
    font,
    source_mode~,
    visible_viewport_height,
    content_width,
  )
  let stored = markdown_session_effective_scroll_state(
    ctx.state.read_slot(slot),
    seed_glide,
    scroll_request,
    max_scroll~,
  )
  match ctx.event {
    Pointer(event) =>
      if ctx.frame.contains(event.position) &&
        (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
        let mut state = stored
        let compensation = markdown_scroll_take_geometry_compensation()
        if compensation != 0.0 {
          state = {
            ..state,
            glide: state.glide.with_anchor_compensation(
              compensation,
              max_scroll,
              now_ms=ctx.now_ms,
            ),
          }
        }
        match
          markdown_session_transient_wheel(
            state,
            event.wheel_delta.y,
            ctx.now_ms,
            max_scroll,
          ) {
          Some(next) =>
            return view_event_result(
              changed=true,
              captured=true,
              state=Some(ctx.state.with_slot(slot, next)),
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
            )
          None => return @core.ViewEventResult::ignored()
        }
      }
    FrameTick(frame) => {
      let (next, settled) = markdown_session_transient_settle(
        stored,
        frame.time_ms,
        max_scroll,
      )
      if next.settle_pending == stored.settle_pending {
        return @core.ViewEventResult::ignored()
      }
      let messages : Array[Msg] = match (settled, on_scroll_settled) {
        (Some(y), Some(handler)) => [handler(y)]
        _ => []
      }
      return view_event_result(
        state=Some(ctx.state.with_slot(slot, next)),
        messages~,
      )
    }
    _ => ()
  }
  let visible_scroll_y = stored.glide.display_offset(
    ctx.now_ms,
    compensation=markdown_scroll_peek_geometry_compensation(),
  )
  let result = markdown_session_editor_event(
    ctx,
    session~,
    selection~,
    on_transaction~,
    font~,
    source_mode~,
    focus_mode~,
    base_dir~,
    on_selection_change~,
    on_prefix_click~,
    on_command_click~,
    accepts_tab_input~,
    visible_scroll_y~,
    on_scroll=None,
    visible_viewport_height~,
    visible_overscan~,
  )
  match ctx.event {
    Keyboard(_) | TextInput(_) => {
      let pinned = markdown_session_pin_scroll(stored, ctx.now_ms, max_scroll)
      let base = result.state.unwrap_or(ctx.state)
      { ..result, state: Some(base.with_slot(slot, pinned)), }
    }
    _ => result
  }
}
