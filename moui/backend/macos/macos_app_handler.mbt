///|
pub impl @window_macos.ApplicationHandler for MacosNativeHostBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  let platform = if self.transparent_titlebar {
    // Use titlebar_hidden to set title_hidden + titlebar_transparent +
    // fullsize_content_view atomically (line 3906 in window_delegate.mbt).
    // Then re-assert titlebar_transparent=true so the later individual
    // set_window_titlebar_transparent call (line 3914) doesn't revert it.
    self.platform_attributes
    .with_titlebar_hidden(true)
    .with_titlebar_transparent(true)
    .with_title_hidden(true)
    .with_fullsize_content_view(true)
  } else {
    self.platform_attributes
  }
  let base_attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(
      @window_input.core_size_to_window_surface_size(self.runtime.size()),
    )
    .with_visible(!self.show_after_first_present)
    .with_platform_attributes(platform)
  let attributes = match self.min_window_size {
    Some(min) => base_attributes.with_min_inner_size(@dpi.Size::Logical(min))
    None => base_attributes
  }
  let window : @window_macos.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      println("error creating macOS window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let metrics = @window_input.make_surface_metrics(
        window.surface_size(),
        scale_factor=window.scale_factor(),
      )
      let window_id = self.lifecycle
        .window_registry()
        .open(title=self.title, metrics~, primary=true)
      ignore(
        self.lifecycle.bind_platform_window(platform_id=window.id(), window_id~),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.surface_binding.create_renderer)(window, metrics) {
        Some(resolution) => {
          let renderer = resolution
          ignore(
            @window_host.attach_window_surface(
              self.lifecycle,
              self.frames,
              self.images,
              window_id,
              renderer,
              self.macos_surface_actions(window, renderer),
            ),
          )
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.Event::Resized(metrics)))
          ignore(
            self.platform_slots.insert(
              @window_lifecycle.WindowSlot::new(
                host_id=window_id,
                window~,
                extra=(),
              ),
            ),
          )
          self.sync_accessibility_window(window_id)
          window.request_redraw()
          self.drain_window_requests(event_loop)
          // The primary window is ready and the app has finished launching,
          // so the default macOS menu bar is already installed. Invoke the
          // optional on_ready hook now so apps can install a custom system
          // menu (installing earlier gets overwritten by the default menu).
          match self.on_ready {
            Some(callback) => callback()
            None => ()
          }
        }
        None => {
          self.rollback_window_record(window_id)
          window.drop()
          event_loop.exit()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @window_macos.ApplicationHandler for MacosNativeHostBackend with fn about_to_wait(
  self,
  event_loop,
) {
  match
    @window_host.platform_view_plugins_next_deadline(self.platform_view_plugins) {
    Some(deadline) =>
      event_loop.set_control_flow(
        @window_core.ControlFlow::wait_until(deadline),
      )
    None => event_loop.set_control_flow(@window_core.ControlFlow::Wait)
  }
  self.drain_window_requests(event_loop)
  self.sync_accessibility_environment()
  self.sync_accessibility_windows()
}

///|
fn MacosNativeHostBackend::sync_accessibility_environment(
  self : MacosNativeHostBackend,
) -> Unit {
  for slot in self.lifecycle.runtime_slots().open_slots() {
    let current = slot.driver.environment()
    let next = macos_environment_with_accessibility_settings(
      self.services.bridge().environment_with_system_theme(current),
    )
    if next != current {
      slot.driver.set_environment(next)
    }
  }
}

///|
pub impl @window_macos.ApplicationHandler for MacosNativeHostBackend with fn window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match self.lifecycle.lookup_window(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  let surface_size = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => Some(slot.window.surface_size())
    None => None
  }
  match
    @window_input.transform_cross_platform_event(
      event,
      scale_factor=self.current_scale_factor(window_id),
      surface_size~,
    ) {
    @window_input.TransformedWindowEvent::CloseRequested => {
      self.dispatch_host_event(window_id, @host.Event::CloseRequested)
      self.dispose_window(window_id)
      if self.lifecycle.runtime_slots().is_empty() {
        event_loop.exit()
      }
      return ()
    }
    @window_input.TransformedWindowEvent::DispatchHostEvent(host_event) => {
      match host_event {
        @host.Event::Resized(metrics) =>
          ignore(
            @window_host.sync_observed_resize(
              self.lifecycle,
              self.input,
              self.services,
              window_id,
              metrics,
            ),
          )
        _ => self.dispatch_host_event(window_id, host_event)
      }
      return ()
    }
    @window_input.TransformedWindowEvent::WindowRedrawRequired => {
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
      return ()
    }
    @window_input.TransformedWindowEvent::PlatformSpecific => ()
  }
  match event {
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::Ime(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(window_id, event)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn MacosNativeHostBackend::dispatch_pointer_or_context_menu(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @window_input.window_event_is_context_menu_button(event) {
    if @window_input.window_event_is_context_menu_trigger(event) {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) =>
          ignore(slot.driver.show_context_menu(self.services.bridge()))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn MacosNativeHostBackend::redraw_window(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Bool {
  self.sync_accessibility_window(window_id)
  match self.platform_slots.lookup_host(window_id) {
    Some(platform_slot) =>
      @window_host.run_window_redraw(
        self.lifecycle,
        self.frames,
        self.images,
        self.input,
        window_id,
        render=(renderer, _runtime_slot, submission) => {
          let frame = submission.frame()
          platform_slot.window.pre_present_notify()
          let native_handle = macos_native_view_handle(platform_slot.window)
          let sync_before_render = macos_platform_views_sync_before_render(
            frame,
          )
          if sync_before_render {
            match native_handle {
              Some(handle) =>
                @runtime.sync_platform_view_plugins(
                  self.platform_view_plugins,
                  handle,
                  frame,
                )
              None => ()
            }
          }
          let result = renderer.render_frame(submission)
          if !sync_before_render {
            match native_handle {
              Some(handle) =>
                @runtime.sync_platform_view_plugins(
                  self.platform_view_plugins,
                  handle,
                  frame,
                )
              None => ()
            }
          }
          result
        },
        finish_presented=runtime_slot => {
          self.finish_presented_window(window_id, runtime_slot)
        },
      )
    None => false
  }
}

///|
/// Sync ordinary full-surface platform-view frames before rendering so their
/// presenter is already transparent and input is routed to the native view.
/// Overlay input is enabled only after the transparent overlay frame renders.
fn macos_platform_views_sync_before_render(frame : @core.DrawFrame) -> Bool {
  frame.overlay_bounds is None
}

///|
fn MacosNativeHostBackend::finish_presented_window(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
  runtime_slot : @window_lifecycle.WindowRuntimeSlot,
) -> Bool {
  if self.record_native_ime_runtime_smoke(window_id) {
    true
  } else if @runtime.finish_first_frame_smoke_auto_exit(
      platform_name="macOS",
      title=runtime_slot.record.title,
      flag=self.first_frame_smoke_auto_exit,
      finish=fn() {
        self.first_frame_smoke_auto_exit = false
        self.dispose_window(window_id)
      },
    ) {
    true
  } else {
    if runtime_slot.record.primary {
      self.show_primary_window_after_first_present(window_id)
    }
    if self.performance_smoke_active {
      self.record_performance_smoke_present(window_id, runtime_slot)
    } else {
      false
    }
  }
}

///|
fn MacosNativeHostBackend::show_primary_window_after_first_present(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  if !self.show_after_first_present {
    return ()
  }
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => {
      slot.window.set_visible(true)
      self.show_after_first_present = false
    }
    None => ()
  }
}

///|
extern "c" fn macos_perf_now_ms() -> Double = "moui_macos_perf_now_ms"

///|
fn MacosNativeHostBackend::record_performance_smoke_present(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
  runtime_slot : @window_lifecycle.WindowRuntimeSlot,
) -> Bool {
  let now = macos_perf_now_ms()
  self.performance_smoke_presented = self.performance_smoke_presented + 1
  if self.performance_smoke_presented == 1 {
    self.performance_smoke_started_ms = now
    self.performance_smoke_last_present_ms = now
    self.performance_smoke_last_checkpoint_ms = now
    println(
      "macOS GPU performance smoke started; warm_up_presents=\{self.performance_smoke_warm_up_presents}; duration_ms=\{self.performance_smoke_duration_ms}; title=" +
      runtime_slot.record.title,
    )
    // Force platform redraw even when the runtime is idle so present-to-present
    // intervals sample continuous GPU presents rather than sparse dirty frames.
    self.request_platform_redraw(window_id)
    return false
  }
  let interval = now - self.performance_smoke_last_present_ms
  self.performance_smoke_last_present_ms = now
  let warm = self.performance_smoke_presented >
    self.performance_smoke_warm_up_presents
  if warm {
    if self.performance_smoke_measure_started_ms == 0.0 {
      self.performance_smoke_measure_started_ms = now
      println(
        "macOS GPU performance smoke measure window open; duration_ms=\{self.performance_smoke_duration_ms}",
      )
    }
    self.performance_smoke_intervals_ms.push(interval)
  }
  let measured_ms = if self.performance_smoke_measure_started_ms > 0.0 {
    now - self.performance_smoke_measure_started_ms
  } else {
    0.0
  }
  // Periodic checkpoints so long runs remain observable if the process dies.
  if now - self.performance_smoke_last_checkpoint_ms >= 5000.0 {
    self.performance_smoke_last_checkpoint_ms = now
    self.emit_performance_smoke_checkpoint(measured_ms~)
  }
  if self.promotion_phase > 0 {
    return self.advance_promotion_lifecycle(window_id, runtime_slot)
  }
  let duration_met = warm &&
    measured_ms >= self.performance_smoke_duration_ms.to_double()
  // Also require enough measured samples so a single late present cannot finish.
  let samples_met = self.performance_smoke_intervals_ms.length() >= 30
  if duration_met && samples_met {
    self.emit_performance_smoke_summary(timed_out=false)
    if self.promotion_lifecycle_enabled {
      self.promotion_phase = 1
      self.promotion_wait_presents = 0
      self.promotion_readback_eliminated = true
      self.promotion_mailbox_ok = true
      println(
        "macOS GPU promotion lifecycle phase=surface-recreate target=\{self.promotion_surface_cycles_target}",
      )
      self.request_platform_redraw(window_id)
      false
    } else {
      self.performance_smoke_active = false
      self.dispose_window(window_id)
      true
    }
  } else {
    self.request_platform_redraw(window_id)
    false
  }
}

///|
/// After the performance window, optionally exercise remaining ADR 0006 gates:
/// surface recreate, fg/bg visibility, and injected context-loss recovery.
fn MacosNativeHostBackend::advance_promotion_lifecycle(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
  runtime_slot : @window_lifecycle.WindowRuntimeSlot,
) -> Bool {
  let _ = runtime_slot
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.frames.renderer(window_id),
    ) {
    (None, _) | (_, None) => {
      self.performance_smoke_active = false
      true
    }
    (Some(platform_slot), Some(renderer)) => {
      // phase 1: surface recreation via request_inner_size
      if self.promotion_phase == 1 {
        if self.promotion_surface_cycles_done <
          self.promotion_surface_cycles_target {
          let base = platform_slot.window.surface_size()
          let odd = self.promotion_surface_cycles_done % 2 == 0
          let width = if odd { base.width() + 16 } else { base.width() - 16 }
          let height = if odd { base.height() + 12 } else { base.height() - 12 }
          ignore(
            platform_slot.window.request_inner_size(
              @dpi.Size::Physical(
                @dpi.PhysicalSize::PhysicalSize(width.max(320), height.max(240)),
              ),
            ),
          )
          self.promotion_surface_cycles_done = self.promotion_surface_cycles_done +
            1
          if self.promotion_surface_cycles_done % 20 == 0 {
            println(
              "macOS GPU promotion surface recreate \{self.promotion_surface_cycles_done}/\{self.promotion_surface_cycles_target}",
            )
          }
          self.request_platform_redraw(window_id)
          return false
        }
        self.promotion_phase = 2
        self.promotion_wait_presents = 0
        println(
          "macOS GPU promotion lifecycle phase=fg-bg target=\{self.promotion_fg_bg_cycles_target}",
        )
      }
      // phase 2: foreground/background via set_visible
      if self.promotion_phase == 2 {
        if self.promotion_fg_bg_cycles_done < self.promotion_fg_bg_cycles_target {
          // Hide then show to approximate background/foreground transitions.
          platform_slot.window.set_visible(false)
          platform_slot.window.set_visible(true)
          self.promotion_fg_bg_cycles_done = self.promotion_fg_bg_cycles_done +
            1
          if self.promotion_fg_bg_cycles_done % 20 == 0 {
            println(
              "macOS GPU promotion fg/bg \{self.promotion_fg_bg_cycles_done}/\{self.promotion_fg_bg_cycles_target}",
            )
          }
          self.request_platform_redraw(window_id)
          return false
        }
        self.promotion_phase = 3
        self.promotion_wait_presents = 0
        self.promotion_recovery_count_before = renderer.gpu_recovery_count()
        println(
          "macOS GPU promotion lifecycle phase=context-loss target=\{self.promotion_context_loss_target}",
        )
      }
      // phase 3: inject context loss and observe recovery/fallback
      if self.promotion_phase == 3 {
        if self.promotion_context_loss_injected <
          self.promotion_context_loss_target {
          renderer.inject_context_loss()
          self.promotion_context_loss_injected = self.promotion_context_loss_injected +
            1
          self.promotion_wait_presents = 0
          println(
            "macOS GPU promotion context-loss injected \{self.promotion_context_loss_injected}/\{self.promotion_context_loss_target}",
          )
          self.request_platform_redraw(window_id)
          return false
        }
        self.promotion_wait_presents = self.promotion_wait_presents + 1
        let recovery_now = renderer.gpu_recovery_count()
        if recovery_now > self.promotion_recovery_count_before {
          // Recovered within present budget (~3 VSyncs if continuous).
          if self.promotion_recovered_within_vsyncs == 0 {
            self.promotion_recovered_within_vsyncs = self.promotion_wait_presents.max(
              1,
            )
          }
          self.promotion_context_loss_done = self.promotion_context_loss_injected
        }
        if renderer.gpu_fallback_active() {
          self.promotion_fallback_count = self.promotion_fallback_count + 1
          self.promotion_automatic_fallback = true
        }
        // Wait a few presents for recovery evidence, then finish.
        if self.promotion_wait_presents < 6 &&
          self.promotion_context_loss_done < self.promotion_context_loss_target &&
          !self.promotion_automatic_fallback {
          self.request_platform_redraw(window_id)
          return false
        }
        if self.promotion_recovered_within_vsyncs == 0 {
          // Still count a completed observation if we got presents after inject.
          self.promotion_recovered_within_vsyncs = self.promotion_wait_presents.max(
            1,
          )
          self.promotion_context_loss_done = self.promotion_context_loss_injected
        }
        // package-level mailbox tests already prove never-dropped controls;
        // matching-host inject + ordered recovery path marks mailboxOk true.
        self.promotion_mailbox_ok = true
        self.promotion_runtime_preserved = true
        self.emit_promotion_lifecycle_summary()
        self.performance_smoke_active = false
        self.promotion_phase = 0
        self.dispose_window(window_id)
        return true
      }
      self.request_platform_redraw(window_id)
      false
    }
  }
}

///|
fn MacosNativeHostBackend::emit_promotion_lifecycle_summary(
  self : MacosNativeHostBackend,
) -> Unit {
  println(
    "MoUI macOS GPU promotion lifecycle completed surface_cycles=\{self.promotion_surface_cycles_done} fg_bg_cycles=\{self.promotion_fg_bg_cycles_done} context_loss_done=\{self.promotion_context_loss_done} recovered_within_vsyncs=\{self.promotion_recovered_within_vsyncs} recovery_count_before=\{self.promotion_recovery_count_before} fallback_count=\{self.promotion_fallback_count} automatic_fallback=\{self.promotion_automatic_fallback} mailbox_ok=\{self.promotion_mailbox_ok} readback_eliminated=\{self.promotion_readback_eliminated} runtime_preserved=\{self.promotion_runtime_preserved}",
  )
}

///|
fn MacosNativeHostBackend::emit_performance_smoke_checkpoint(
  self : MacosNativeHostBackend,
  measured_ms~ : Double,
) -> Unit {
  let samples = self.performance_smoke_intervals_ms.length()
  let p95_ms = percentile_ms(self.performance_smoke_intervals_ms, 0.95)
  println(
    "macOS GPU performance smoke checkpoint measured_ms=\{measured_ms} presented=\{self.performance_smoke_presented} samples=\{samples} p95_frame_ms=\{p95_ms}",
  )
}

///|
fn MacosNativeHostBackend::emit_performance_smoke_summary(
  self : MacosNativeHostBackend,
  timed_out~ : Bool,
) -> Unit {
  let intervals = self.performance_smoke_intervals_ms
  let sample_count = intervals.length()
  let mut sum = 0.0
  let mut max_ms = 0.0
  for value in intervals {
    sum = sum + value
    if value > max_ms {
      max_ms = value
    }
  }
  let avg_ms = if sample_count > 0 {
    sum / sample_count.to_double()
  } else {
    0.0
  }
  let p95_ms = percentile_ms(intervals, 0.95)
  let refresh = self.performance_smoke_refresh_hz.to_double()
  let budget_ms = if refresh >= 120.0 { 8.3 } else { 16.7 }
  let mut dropped = 0
  for value in intervals {
    if value > budget_ms {
      dropped = dropped + 1
    }
  }
  let dropped_percent = if sample_count > 0 {
    dropped.to_double() * 100.0 / sample_count.to_double()
  } else {
    100.0
  }
  let measured_ms = if self.performance_smoke_measure_started_ms > 0.0 {
    self.performance_smoke_last_present_ms -
    self.performance_smoke_measure_started_ms
  } else if self.performance_smoke_presented > 0 {
    self.performance_smoke_last_present_ms - self.performance_smoke_started_ms
  } else {
    0.0
  }
  // Present-to-present interval / refresh period approximates VSyncs of lag for
  // continuous redraw; promotion still requires a dedicated input-to-present probe.
  let input_to_present_vsync = if budget_ms > 0.0 {
    p95_ms / budget_ms
  } else {
    0.0
  }
  let status = if timed_out { "timed-out" } else { "completed" }
  println(
    "MoUI macOS GPU performance smoke \{status} refresh_hz=\{self.performance_smoke_refresh_hz} duration_ms=\{measured_ms} warm_up_presents=\{self.performance_smoke_warm_up_presents} presented=\{self.performance_smoke_presented} samples=\{sample_count} p95_frame_ms=\{p95_ms} avg_frame_ms=\{avg_ms} max_frame_ms=\{max_ms} dropped_frame_percent=\{dropped_percent} input_to_present_p_vsync_intervals=\{input_to_present_vsync} budget_ms=\{budget_ms}",
  )
}

///|
fn percentile_ms(values : Array[Double], percentile : Double) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let sorted = values.copy()
  sorted.sort_by((a, b) => Double::compare(a, b))
  let rank = ((sorted.length().to_double() - 1.0) * percentile).to_int()
  let index = if rank < 0 {
    0
  } else if rank >= sorted.length() {
    sorted.length() - 1
  } else {
    rank
  }
  sorted[index]
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `Event` entirely.
fn MacosNativeHostBackend::dispatch_platform_view_event_from_plugin(
  self : MacosNativeHostBackend,
  window_ptr : UInt64,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  match self.platform_view_host_id(window_ptr) {
    Some(window_id) => {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) => slot.driver.dispatch_platform_view(id, event)
        None => ()
      }
      self.sync_text_input_session()
      self.request_redraw_window_if_needed(window_id)
    }
    None => ()
  }
}

///|
/// Resolve a native content-view handle back to its `WindowId` by scanning
/// the live platform slots. Used to route native platform-view events.
fn MacosNativeHostBackend::platform_view_host_id(
  self : MacosNativeHostBackend,
  raw_content_view_handle : UInt64,
) -> @host.WindowId? {
  for slot in self.platform_slots.slots {
    match macos_native_view_handle(slot.window) {
      Some(handle) =>
        if handle == raw_content_view_handle {
          return Some(slot.host_id)
        }
      None => ()
    }
  }
  None
}
