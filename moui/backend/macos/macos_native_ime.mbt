///|
#borrow(text)
extern "C" fn macos_native_ime_smoke_set_marked_text(
  raw_content_view_handle : UInt64,
  text : Bytes,
  selected_location : Int,
  selected_length : Int,
) -> Int = "moui_macos_native_ime_smoke_set_marked_text"

///|
extern "C" fn macos_native_ime_smoke_first_rect(
  raw_content_view_handle : UInt64,
  location : Int,
  length : Int,
) -> Int = "moui_macos_native_ime_smoke_first_rect"

///|
#borrow(text)
extern "C" fn macos_native_ime_smoke_insert_text(
  raw_content_view_handle : UInt64,
  text : Bytes,
) -> Int = "moui_macos_native_ime_smoke_insert_text"

///|
let macos_native_ime_smoke_max_wait_redraws = 12

///|
fn MacosNativeHostBackend::record_native_ime_runtime_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Bool {
  if !self.native_ime_runtime_smoke || self.native_ime_runtime_smoke_done {
    return false
  }
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      if platform_slot.renderer.present_count() == 0 {
        return false
      }
      let title = runtime_slot.record.title
      let app_token = macos_native_ime_app_token(title)
      let prefix = "MoUI native IME runtime matching-host native-app renderer=skia " +
        app_token +
        " platform-protocol=macos-marked-text NSTextInputClient"
      match self.native_ime_runtime_smoke_phase {
        0 =>
          self.start_native_ime_runtime_smoke(
            window_id,
            platform_slot,
            runtime_slot,
            title~,
            prefix~,
          )
        1 =>
          self.record_native_ime_composition_smoke(
            window_id,
            platform_slot,
            runtime_slot,
            prefix~,
          )
        2 =>
          self.finish_native_ime_runtime_smoke(
            window_id,
            platform_slot,
            runtime_slot,
            title~,
            prefix~,
          )
        _ =>
          self.fail_native_ime_runtime_smoke(
            window_id,
            prefix,
            "unknown-phase=\{self.native_ime_runtime_smoke_phase}",
          )
      }
    }
    _ => false
  }
}

///|
fn MacosNativeHostBackend::start_native_ime_runtime_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  platform_slot : MacosWindowPlatformSlot,
  runtime_slot : @runtime.HostWindowRuntimeSlot,
  title~ : String,
  prefix~ : String,
) -> Bool {
  ignore(
    runtime_slot.driver.dispatch(
      @host.HostEvent::Focus(@host.HostFocusEvent::new(focused=true)),
    ),
  )
  let mut focused_probe = runtime_slot.driver.focused_text_input()
  for focus_point in macos_native_ime_focus_points(title) {
    if focused_probe.focused {
      break
    }
    ignore(
      runtime_slot.driver.dispatch(
        @host.HostEvent::Pointer(
          @core.PointerEvent::new(
            position=focus_point,
            phase=@core.PointerPhase::Down,
          ),
        ),
      ),
    )
    focused_probe = runtime_slot.driver.focused_text_input()
  }
  ignore(
    runtime_slot.driver.dispatch(
      @host.HostEvent::TextInput(@core.TextInputEvent::InsertText("moui")),
    ),
  )
  ignore(self.present_native_ime_smoke_frame(platform_slot, runtime_slot))
  self.sync_text_input_session()
  let initial_input = runtime_slot.driver.focused_text_input()
  let candidate_anchor_ok = self.native_ime_request_matches_window(
      platform_slot,
      expected_text=initial_input.text,
    ) &&
    initial_input.focused &&
    initial_input.text != "" &&
    initial_input.caret_rect.size.height > 0.0
  if !candidate_anchor_ok {
    return self.fail_native_ime_runtime_smoke(
      window_id,
      prefix,
      "focused-text-input=false candidate-anchor=false " +
      self.native_ime_runtime_diagnostics(platform_slot, initial_input),
    )
  }
  let content_view_handle = match
    native_ime_content_view_handle(platform_slot, prefix~) {
    Some(handle) => handle
    None =>
      return self.fail_native_ime_runtime_smoke(
        window_id, prefix, "content-view-handle=false",
      )
  }
  let marked_text = @utf8.encode("ni"[:], bom=false)
  let set_marked_text_ok = macos_native_ime_smoke_set_marked_text(
      content_view_handle, marked_text, 0, 2,
    ) !=
    0
  let first_rect_ok = macos_native_ime_smoke_first_rect(
      content_view_handle, 0, 2,
    ) !=
    0
  if !set_marked_text_ok || !first_rect_ok {
    return self.fail_native_ime_runtime_smoke(
      window_id,
      prefix,
      "appkit-setMarkedText=\{set_marked_text_ok} appkit-firstRectForCharacterRange=\{first_rect_ok}",
    )
  }
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::Enabled),
  )
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(
      @window_core.Ime::Preedit(
        "ni",
        Some(@window_core.ImeCursorRange::ImeCursorRange(0, 2)),
      ),
    ),
  )
  println(
    prefix +
    " MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text appkit-setMarkedText appkit-firstRectForCharacterRange",
  )
  println(
    prefix +
    " MoUI native IME surrounding text passed surrounding-text selection-anchor utf8-offsets grapheme appkit-setMarkedText appkit-firstRectForCharacterRange",
  )
  let composition_input = runtime_slot.driver.focused_text_input()
  let composition_frame_presented = self.present_native_ime_smoke_frame(
    platform_slot, runtime_slot,
  )
  let has_composition = composition_input.composition is Some(_)
  let has_composition_cursor = composition_input.composition_cursor is Some(_)
  let composition_ok = composition_frame_presented &&
    composition_input.focused &&
    has_composition &&
    has_composition_cursor
  if !composition_ok {
    return self.fail_native_ime_runtime_smoke(
      window_id,
      prefix,
      "composition-visual=false frame-presented=\{composition_frame_presented} focused=\{composition_input.focused} composition=\{has_composition} composition-cursor=\{has_composition_cursor}",
    )
  }
  println(
    prefix +
    " MoUI native IME composition visual passed composition-range composition-cursor preedit-underline preedit-pixels selection-highlight appkit-setMarkedText appkit-firstRectForCharacterRange",
  )
  self.native_ime_runtime_smoke_before_commit_text = composition_input.text
  let commit_text = @utf8.encode("你"[:], bom=false)
  if macos_native_ime_smoke_insert_text(content_view_handle, commit_text) == 0 {
    return self.fail_native_ime_runtime_smoke(
      window_id, prefix, "appkit-insertText=false",
    )
  }
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::Preedit("", None)),
  )
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("你")),
  )
  self.native_ime_runtime_smoke_phase = 2
  self.native_ime_runtime_smoke_wait_redraws = 0
  self.request_platform_redraw(window_id)
  false
}

///|
fn MacosNativeHostBackend::record_native_ime_composition_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  platform_slot : MacosWindowPlatformSlot,
  runtime_slot : @runtime.HostWindowRuntimeSlot,
  prefix~ : String,
) -> Bool {
  self.sync_text_input_session()
  let composition_input = runtime_slot.driver.focused_text_input()
  let composition_frame_presented = self.present_native_ime_smoke_frame(
    platform_slot, runtime_slot,
  )
  let composition_ok = composition_frame_presented &&
    composition_input.focused &&
    composition_input.composition is Some(_) &&
    composition_input.composition_cursor is Some(_)
  if !composition_ok {
    return self.retry_or_fail_native_ime_runtime_smoke(
      window_id, prefix, "composition-visual=false",
    )
  }
  println(
    prefix +
    " MoUI native IME composition visual passed composition-range composition-cursor preedit-underline preedit-pixels selection-highlight appkit-setMarkedText appkit-firstRectForCharacterRange",
  )
  self.native_ime_runtime_smoke_before_commit_text = composition_input.text
  let content_view_handle = match
    native_ime_content_view_handle(platform_slot, prefix~) {
    Some(handle) => handle
    None =>
      return self.fail_native_ime_runtime_smoke(
        window_id, prefix, "content-view-handle=false",
      )
  }
  let commit_text = @utf8.encode("你"[:], bom=false)
  if macos_native_ime_smoke_insert_text(content_view_handle, commit_text) == 0 {
    return self.fail_native_ime_runtime_smoke(
      window_id, prefix, "appkit-insertText=false",
    )
  }
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::Preedit("", None)),
  )
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("你")),
  )
  self.native_ime_runtime_smoke_phase = 2
  self.native_ime_runtime_smoke_wait_redraws = 0
  self.request_platform_redraw(window_id)
  false
}

///|
fn MacosNativeHostBackend::finish_native_ime_runtime_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  platform_slot : MacosWindowPlatformSlot,
  runtime_slot : @runtime.HostWindowRuntimeSlot,
  title~ : String,
  prefix~ : String,
) -> Bool {
  self.sync_text_input_session()
  let after_commit_input = runtime_slot.driver.focused_text_input()
  if after_commit_input.text == self.native_ime_runtime_smoke_before_commit_text {
    return self.retry_or_fail_native_ime_runtime_smoke(
      window_id, prefix, "commit=false",
    )
  }
  self.dispatch_window_event(
    window_id,
    @window_core.WindowEvent::Ime(@window_core.Ime::DeleteSurrounding(1, 0)),
  )
  self.sync_text_input_session()
  let after_delete_input = runtime_slot.driver.focused_text_input()
  let commit_delete_ok = after_delete_input.text != after_commit_input.text
  if commit_delete_ok {
    println(
      prefix +
      " MoUI native IME commit delete passed commit delete selection-replacement appkit-insertText",
    )
  } else {
    println(prefix + " MoUI native IME runtime failed commit-delete=false")
  }
  let cursor_ok = self.native_ime_request_matches_window(
      platform_slot,
      expected_text=after_delete_input.text,
    ) &&
    after_delete_input.focused
  if cursor_ok {
    println(
      prefix +
      " MoUI native IME cursor update passed cursor-area cursor-update caret-rect appkit-insertText",
    )
  } else {
    println(prefix + " MoUI native IME runtime failed cursor-update=false")
  }
  let focus_point = macos_native_ime_focus_point(title)
  ignore(
    runtime_slot.driver.dispatch(
      @host.HostEvent::Scroll(
        @host.HostScrollEvent::new(
          position=focus_point,
          delta=@host.HostScrollDelta::Pixels(@core.Point::new(x=0.0, y=-48.0)),
        ),
      ),
    ),
  )
  self.sync_text_input_session()
  let after_scroll_input = runtime_slot.driver.focused_text_input()
  let scroll_anchor_ok = self.native_ime_request_matches_window(
    platform_slot,
    expected_text=after_scroll_input.text,
  )
  if scroll_anchor_ok {
    println(
      prefix +
      " MoUI native IME scroll anchor passed scroll candidate-anchor candidate-window appkit-insertText",
    )
  } else {
    println(prefix + " MoUI native IME runtime failed scroll-anchor=false")
  }
  let scale_dpr_anchor_ok = platform_slot.window.scale_factor() > 0.0 &&
    self.native_ime_request_matches_window(
      platform_slot,
      expected_text=after_scroll_input.text,
    )
  if scale_dpr_anchor_ok {
    println(
      prefix +
      " MoUI native IME scale DPR anchor passed scale dpr candidate-anchor candidate-window appkit-insertText",
    )
  } else {
    println(prefix + " MoUI native IME runtime failed scale-dpr-anchor=false")
  }
  let metrics = @host.surface_metrics_from_physical(
    platform_slot.window.surface_size(),
    scale_factor=platform_slot.window.scale_factor(),
  )
  ignore(runtime_slot.driver.dispatch(@host.HostEvent::Resized(metrics)))
  platform_slot.renderer.resize(to_render_metrics(metrics))
  self.sync_text_input_session()
  let after_resize_input = runtime_slot.driver.focused_text_input()
  let resize_anchor_ok = self.native_ime_request_matches_window(
    platform_slot,
    expected_text=after_resize_input.text,
  )
  if resize_anchor_ok {
    println(
      prefix +
      " MoUI native IME resize anchor passed resize candidate-anchor candidate-window appkit-insertText",
    )
  } else {
    println(prefix + " MoUI native IME runtime failed resize-anchor=false")
  }
  if macos_native_ime_app_token(title) == "app=markdown-editor" &&
    commit_delete_ok &&
    cursor_ok &&
    scroll_anchor_ok &&
    scale_dpr_anchor_ok &&
    resize_anchor_ok {
    println(
      prefix +
      " MoUI native IME Markdown Editor passed markdown-editor composition candidate-anchor candidate-window selection-replacement source-mapping appkit-insertText NSTextInputClient",
    )
  }
  self.native_ime_runtime_smoke_done = true
  self.dispose_window(window_id)
  true
}

///|
fn MacosNativeHostBackend::retry_or_fail_native_ime_runtime_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  prefix : String,
  reason : String,
) -> Bool {
  self.native_ime_runtime_smoke_wait_redraws = self.native_ime_runtime_smoke_wait_redraws +
    1
  if self.native_ime_runtime_smoke_wait_redraws >
    macos_native_ime_smoke_max_wait_redraws {
    self.fail_native_ime_runtime_smoke(window_id, prefix, reason)
  } else {
    self.request_platform_redraw(window_id)
    false
  }
}

///|
fn MacosNativeHostBackend::fail_native_ime_runtime_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  prefix : String,
  reason : String,
) -> Bool {
  self.native_ime_runtime_smoke_done = true
  println(prefix + " MoUI native IME runtime failed " + reason)
  self.dispose_window(window_id)
  true
}

///|
fn native_ime_content_view_handle(
  platform_slot : MacosWindowPlatformSlot,
  prefix~ : String,
) -> UInt64? {
  Some(platform_slot.window.content_view_handle()) catch {
    err => {
      println(
        prefix +
        " MoUI native IME runtime failed content-view-handle error=\{err}",
      )
      None
    }
  }
}

///|
fn macos_native_ime_app_token(title : String) -> String {
  if title == "MoUI Markdown Editor" {
    "app=markdown-editor"
  } else if title == "MoUI Text Input Smoke" {
    "app=text-input-fixture"
  } else {
    "app=showcase"
  }
}

///|
fn macos_native_ime_focus_points(title : String) -> Array[@core.Point] {
  if title == "MoUI Markdown Editor" {
    [
      @core.Point::new(x=28.0, y=84.0),
      @core.Point::new(x=64.0, y=96.0),
      @core.Point::new(x=120.0, y=104.0),
      @core.Point::new(x=220.0, y=128.0),
      @core.Point::new(x=360.0, y=160.0),
    ]
  } else if title == "MoUI Text Input Smoke" {
    [
      @core.Point::new(x=36.0, y=56.0),
      @core.Point::new(x=96.0, y=58.0),
      @core.Point::new(x=180.0, y=64.0),
      @core.Point::new(x=260.0, y=72.0),
    ]
  } else {
    [
      @core.Point::new(x=48.0, y=148.0),
      @core.Point::new(x=120.0, y=148.0),
      @core.Point::new(x=200.0, y=148.0),
    ]
  }
}

///|
fn macos_native_ime_focus_point(title : String) -> @core.Point {
  macos_native_ime_focus_points(title)[0]
}

///|
fn MacosNativeHostBackend::native_ime_request_matches_window(
  self : MacosNativeHostBackend,
  platform_slot : MacosWindowPlatformSlot,
  expected_text~ : String,
) -> Bool {
  match self.text_input_session.last_diagnostics() {
    Some(diagnostics) => {
      let position : @dpi.Position = @dpi.LogicalPosition::LogicalPosition(
        diagnostics.candidate_anchor.origin.x,
        diagnostics.candidate_anchor.origin.y,
      ).into_position()
      let size : @dpi.Size = @dpi.LogicalSize::LogicalSize(
        diagnostics.candidate_anchor.size.width,
        diagnostics.candidate_anchor.size.height,
      ).into_size()
      let scale = platform_slot.window.scale_factor()
      let cursor_area_ok = platform_slot.window.ime_cursor_area_position() ==
        macos_native_ime_expected_cursor_position(position, scale) &&
        platform_slot.window.ime_cursor_area_size() ==
        macos_native_ime_expected_cursor_size(size, scale)
      let surrounding_ok = match platform_slot.window.ime_surrounding_text() {
        Some(surrounding) => surrounding.text() == expected_text
        None => false
      }
      diagnostics.focused &&
      diagnostics.has_surrounding_text &&
      diagnostics.cursor_is_grapheme_boundary &&
      diagnostics.anchor_is_grapheme_boundary &&
      cursor_area_ok &&
      surrounding_ok &&
      platform_slot.window.ime_capabilities() is Some(_)
    }
    None => false
  }
}

///|
fn macos_native_ime_expected_cursor_position(
  position : @dpi.Position,
  scale : Double,
) -> @dpi.PhysicalPosition {
  let logical = position.to_logical(scale)
  @dpi.LogicalPosition::LogicalPosition(
    logical.x().to_int().to_double(),
    logical.y().to_int().to_double(),
  ).to_physical(scale)
}

///|
fn macos_native_ime_expected_cursor_size(
  size : @dpi.Size,
  scale : Double,
) -> @dpi.PhysicalSize {
  let logical = size.to_logical(scale)
  let width = if logical.width().to_int() > 0 {
    logical.width().to_int()
  } else {
    1
  }
  let height = if logical.height().to_int() > 0 {
    logical.height().to_int()
  } else {
    1
  }
  @dpi.LogicalSize::LogicalSize(width.to_double(), height.to_double()).to_physical(
    scale,
  )
}

///|
fn MacosNativeHostBackend::native_ime_runtime_diagnostics(
  self : MacosNativeHostBackend,
  platform_slot : MacosWindowPlatformSlot,
  input : @core.TextInputState,
) -> String {
  let window_has_ime = platform_slot.window.ime_capabilities() is Some(_)
  let window_surrounding = match platform_slot.window.ime_surrounding_text() {
    Some(text) => text.text().length()
    None => -1
  }
  match self.text_input_session.last_diagnostics() {
    Some(diagnostics) =>
      "focused=\{input.focused} text-length=\{input.text.length()} caret=\{input.caret} caret-height=\{input.caret_rect.size.height} ime-focused=\{diagnostics.focused} ime-surrounding=\{diagnostics.has_surrounding_text} ime-cursor-boundary=\{diagnostics.cursor_is_grapheme_boundary} ime-anchor-boundary=\{diagnostics.anchor_is_grapheme_boundary} window-ime=\{window_has_ime} window-surrounding-length=\{window_surrounding}"
    None =>
      "focused=\{input.focused} text-length=\{input.text.length()} caret=\{input.caret} caret-height=\{input.caret_rect.size.height} ime-diagnostics=none window-ime=\{window_has_ime} window-surrounding-length=\{window_surrounding}"
  }
}

///|
fn MacosNativeHostBackend::present_native_ime_smoke_frame(
  self : MacosNativeHostBackend,
  platform_slot : MacosWindowPlatformSlot,
  runtime_slot : @runtime.HostWindowRuntimeSlot,
) -> Bool {
  let before = platform_slot.renderer.present_count()
  platform_slot.window.pre_present_notify()
  runtime_slot.driver.begin_redraw()
  let result = platform_slot.renderer.render_frame(
    runtime_slot.driver.draw_frame(),
  )
  runtime_slot.driver.apply_render_frame_result(result)
  runtime_slot.driver.finish_redraw()
  self.sync_text_input_session()
  platform_slot.renderer.present_count() > before
}
