///|
/// Runtime-owned HostRuntimeDriver (ADR 0018). Moved from backend so
/// that backend carries platform-neutral host contracts only.
pub(all) struct HostRuntimeDriver {
  runtime : AppRuntime
  scheduler : RedrawScheduler
  mut close_requested : Bool
  mut frame_time_ms : Double
}

///|
pub fn HostRuntimeDriver::new(
  runtime~ : AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> HostRuntimeDriver {
  let driver = {
    runtime,
    scheduler: RedrawScheduler::new(schedule=schedule_redraw),
    close_requested: false,
    frame_time_ms: 0.0,
  }
  runtime.set_redraw_callback(() => driver.request_redraw())
  driver
}

///|
pub fn HostRuntimeDriver::dispatch(
  self : HostRuntimeDriver,
  event : @backend_host.Event,
) -> @backend_host.EventResult {
  match event {
    Resized(metrics) => {
      self.runtime.dispatch_event(@core.AppEvent::Resize(metrics.logical_size))
      self.request_redraw()
    }
    Pointer(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Pointer(event))
      self.request_redraw_if_needed()
    }
    Scroll(event) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Pointer(event.to_pointer_event()),
      )
      self.request_redraw_if_needed()
    }
    Focus(event) =>
      match event.to_core() {
        Some(core_event) => {
          self.runtime.dispatch_event(core_event)
          self.request_redraw_if_needed()
        }
        None => ()
      }
    Keyboard(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Keyboard(event))
      self.request_redraw_if_needed()
    }
    TextInput(event) => {
      self.runtime.dispatch_event(@core.AppEvent::TextInput(event))
      self.request_redraw_if_needed()
    }
    DragDrop(event) => {
      self.runtime.dispatch_event(@core.AppEvent::DragDrop(event))
      self.request_redraw_if_needed()
    }
    ThemeChanged(scheme) => {
      self.runtime.set_environment(
        self.runtime.environment().with_system_scheme(scheme),
      )
      self.request_redraw_if_needed()
    }
    Command(intent) =>
      if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    RedrawRequested => {
      self.begin_redraw()
      self.finish_redraw()
    }
    CloseRequested => {
      if !self.runtime.dispatch_presentation_host_close() {
        self.close_requested = true
      }
      self.request_redraw_if_needed()
    }
  }
  self.event_result()
}

///|
/// Dispatch a platform view event directly to the runtime tree.
/// Used by the `PlatformViewPlugin` infrastructure to route decoded native
/// platform-view events without going through `Event` (which no longer
/// carries a platform-view variant).
pub fn HostRuntimeDriver::dispatch_platform_view(
  self : HostRuntimeDriver,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  self.runtime.dispatch_event(@core.AppEvent::PlatformView(id, event))
  self.request_redraw()
}

///|
pub fn HostRuntimeDriver::perform_semantics_action(
  self : HostRuntimeDriver,
  request : PerformSemanticsActionRequest,
) -> Result[SemanticsActionReceipt, SemanticsActionDispatchError] {
  match self.runtime.perform_semantics_action(request) {
    Ok(receipt) => {
      self.request_redraw_if_needed()
      Ok(receipt)
    }
    Err(error) => Err(error)
  }
}

///|
/// Reads the same atomically committed stream used by Agent hosts. Native
/// adapters keep their own cursor and do not inspect the runtime tree directly.
pub fn HostRuntimeDriver::read_semantics(
  self : HostRuntimeDriver,
  since? : @core.SemanticsGeneration,
) -> Result[SemanticsRead, SemanticsReadError] {
  match since {
    Some(generation) => self.runtime.read_semantics(since=generation)
    None => self.runtime.read_semantics()
  }
}

///|
pub fn HostRuntimeDriver::dispatch_command_with_services(
  self : HostRuntimeDriver,
  intent : @core.CommandIntent,
  services : @backend_host.HostServiceBridge,
) -> @backend_host.EventResult {
  match intent {
    @core.CommandIntent::Copy | @core.CommandIntent::Cut => {
      let result = self.runtime.dispatch_focused_text_command(intent)
      if result.handled {
        match result.clipboard_text {
          Some(text) =>
            ignore(
              services.dispatch(
                @backend_host.HostServiceRequest::Clipboard(
                  @backend_host.HostClipboardRequest::WriteText(text),
                ),
              ),
            )
          None => ()
        }
        self.request_redraw_if_needed()
      } else if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    }
    @core.CommandIntent::Paste => {
      let mut handled = false
      match
        services.dispatch(
          @backend_host.HostServiceRequest::Clipboard(
            @backend_host.HostClipboardRequest::ReadText,
          ),
        ) {
        @backend_host.HostServiceResponse::ClipboardText(text) => {
          let result = self.runtime.dispatch_focused_text_command(
            intent,
            paste_text=Some(text),
          )
          if result.handled {
            handled = true
          }
          self.request_redraw_if_needed()
        }
        @backend_host.HostServiceResponse::Pending(_) => handled = true
        _ => ()
      }
      if !handled && self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    }
    _ =>
      if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
  }
  self.event_result()
}

///|
pub fn HostRuntimeDriver::dispatch_action_command_with_services(
  self : HostRuntimeDriver,
  command : @core.ActionCommand,
  services : @backend_host.HostServiceBridge,
) -> @backend_host.EventResult {
  match command.intent {
    @core.CommandIntent::Copy
    | @core.CommandIntent::Cut
    | @core.CommandIntent::Paste =>
      self.dispatch_command_with_services(command.intent, services)
    _ => {
      if self.runtime.dispatch_action_command(command) {
        self.request_redraw_if_needed()
      } else if command.intent != @core.CommandIntent::Activate {
        ignore(self.dispatch_command_with_services(command.intent, services))
      }
      self.event_result()
    }
  }
}

///|
pub fn HostRuntimeDriver::dispatch_keyboard_with_services(
  self : HostRuntimeDriver,
  event : @core.KeyboardEvent,
  services : @backend_host.HostServiceBridge,
) -> @backend_host.EventResult {
  match keyboard_service_command_intent(event) {
    Some(intent) => self.dispatch_command_with_services(intent, services)
    None => self.dispatch(@backend_host.Event::Keyboard(event))
  }
}

///|
/// Route Escape and platform Back through the same top-most presentation
/// dismissal path. Enter remains owned by the focused/default action.
pub fn HostRuntimeDriver::dispatch_escape(
  self : HostRuntimeDriver,
) -> @backend_host.EventResult {
  ignore(
    self.runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
    ),
  )
  self.request_redraw_if_needed()
  self.event_result()
}

///|
pub fn HostRuntimeDriver::dispatch_system_back(
  self : HostRuntimeDriver,
) -> @backend_host.EventResult {
  ignore(self.runtime.dispatch_presentation_back())
  self.request_redraw_if_needed()
  self.event_result()
}

///|
pub fn HostRuntimeDriver::show_context_menu(
  self : HostRuntimeDriver,
  services : @backend_host.HostServiceBridge,
) -> @backend_host.EventResult {
  let commands = self.context_menu_commands()
  if commands.length() == 0 {
    return self.event_result()
  }
  match
    services.dispatch(@backend_host.HostServiceRequest::ShowMenu(commands)) {
    @backend_host.HostServiceResponse::MenuAction(command) =>
      ignore(self.dispatch_action_command_with_services(command, services))
    @backend_host.HostServiceResponse::MenuCommand(intent) =>
      ignore(self.dispatch_command_with_services(intent, services))
    _ => ()
  }
  self.event_result()
}

///|
fn HostRuntimeDriver::context_menu_commands(
  self : HostRuntimeDriver,
) -> Array[@core.ActionCommand] {
  let input = self.runtime.focused_text_input()
  if input.focused && text_input_state_has_active_selection(input) {
    focused_text_context_menu_commands(input)
  } else {
    let commands = self.document_context_menu_commands()
    if commands.length() > 0 || !input.focused {
      commands
    } else {
      focused_text_context_menu_commands(input)
    }
  }
}

///|
fn HostRuntimeDriver::document_context_menu_commands(
  self : HostRuntimeDriver,
) -> Array[@core.ActionCommand] {
  self.runtime
  .action_commands()
  .filter(command => command.context_menu)
  .dedupe_context_menu_commands()
}

///|
fn focused_text_context_menu_commands(
  input : @core.TextInputState,
) -> Array[@core.ActionCommand] {
  let has_selection = text_input_state_has_active_selection(input)
  @core.default_text_commands().map(command => {
    match command.intent {
      @core.CommandIntent::Copy | @core.CommandIntent::Cut =>
        { ..command, enabled: has_selection }
      _ => command
    }
  })
}

///|
fn text_input_state_has_active_selection(input : @core.TextInputState) -> Bool {
  match input.selection {
    Some(selection) => !selection.normalized().is_collapsed()
    None => false
  }
}

///|
fn Array::dedupe_context_menu_commands(
  self : Array[@core.ActionCommand],
) -> Array[@core.ActionCommand] {
  let commands : Array[@core.ActionCommand] = []
  for command in self {
    if !commands.any(existing => same_context_menu_command(existing, command)) {
      commands.push(command)
    }
  }
  commands
}

///|
fn same_context_menu_command(
  left : @core.ActionCommand,
  right : @core.ActionCommand,
) -> Bool {
  left.intent == right.intent &&
  left.label == right.label &&
  left.enabled == right.enabled &&
  left.group == right.group &&
  left.description == right.description &&
  left.context_menu == right.context_menu
}

///|
fn keyboard_service_command_intent(
  event : @core.KeyboardEvent,
) -> @core.CommandIntent? {
  if !event.pressed ||
    event.repeat ||
    event.modifiers.alt ||
    event.modifiers.shift ||
    !(event.modifiers.meta || event.modifiers.control) {
    None
  } else if event.key == "c" || event.key == "C" {
    Some(@core.CommandIntent::Copy)
  } else if event.key == "x" || event.key == "X" {
    Some(@core.CommandIntent::Cut)
  } else if event.key == "v" || event.key == "V" {
    Some(@core.CommandIntent::Paste)
  } else {
    None
  }
}

///|
pub fn HostRuntimeDriver::request_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.request()
}

///|
pub fn HostRuntimeDriver::set_redraw_scheduler(
  self : HostRuntimeDriver,
  schedule_redraw : () -> Unit,
) -> Unit {
  self.scheduler.set_schedule(schedule_redraw)
}

///|
pub fn HostRuntimeDriver::request_redraw_if_needed(
  self : HostRuntimeDriver,
) -> Unit {
  if self.runtime.needs_redraw() {
    self.scheduler.request_dirty()
  }
}

///|
pub fn HostRuntimeDriver::begin_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.begin_redraw()
  self.frame_time_ms = self.frame_time_ms + 16.0
  self.runtime.dispatch_event(
    @core.AppEvent::FrameTick(
      @core.Frame::new(time_ms=self.frame_time_ms, delta_ms=16.0),
    ),
  )
}

///|
pub fn HostRuntimeDriver::finish_redraw(self : HostRuntimeDriver) -> Unit {
  self.runtime.dispatch_event(
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
  )
  self.scheduler.finish_redraw()
}

///|
pub fn HostRuntimeDriver::draw_commands(
  self : HostRuntimeDriver,
) -> Array[@core.DrawCommand] {
  self.runtime.draw_commands()
}

///|
pub fn HostRuntimeDriver::draw_frame(
  self : HostRuntimeDriver,
) -> @core.DrawFrame {
  self.runtime.draw_frame()
}

///|
pub fn HostRuntimeDriver::environment(
  self : HostRuntimeDriver,
) -> @core.Environment {
  self.runtime.environment()
}

///|
pub fn HostRuntimeDriver::set_environment(
  self : HostRuntimeDriver,
  environment : @core.Environment,
) -> Unit {
  self.runtime.set_environment(environment)
}

///|
pub fn HostRuntimeDriver::set_text_system(
  self : HostRuntimeDriver,
  text_system : @core.TextSystem,
) -> Unit {
  self.runtime.set_text_system(text_system)
}

///|
pub fn HostRuntimeDriver::focused_text_input(
  self : HostRuntimeDriver,
) -> @core.TextInputState {
  self.runtime.focused_text_input()
}

///|
pub fn HostRuntimeDriver::size(self : HostRuntimeDriver) -> @core.Size {
  self.runtime.size()
}

///|
pub fn HostRuntimeDriver::event_result(
  self : HostRuntimeDriver,
) -> @backend_host.EventResult {
  {
    needs_rebuild: self.runtime.needs_rebuild(),
    needs_redraw: self.runtime.needs_redraw(),
    redraw_requested: self.scheduler.is_redraw_requested(),
    close_requested: self.close_requested,
  }
}

///|
/// Dispatch a service completion through the runtime driver. Moved from
/// backend per ADR 0018 so backend stays runtime-neutral.
pub fn HostRuntimeDriver::dispatch_service_completion(
  self : HostRuntimeDriver,
  completion : @backend_host.HostCompletedServiceResponse,
  services : @backend_host.HostServiceBridge,
) -> @backend_host.EventResult {
  match (completion.request, completion.response) {
    (
      @backend_host.HostServiceRequest::Clipboard(
        @backend_host.HostClipboardRequest::ReadText
      ),
      @backend_host.HostServiceResponse::ClipboardText(text),
    ) => {
      let result = self.runtime.dispatch_focused_text_command(
        @core.CommandIntent::Paste,
        paste_text=Some(text),
      )
      if result.handled {
        self.request_redraw_if_needed()
      } else if self.runtime.dispatch_command(@core.CommandIntent::Paste) {
        self.request_redraw_if_needed()
      }
    }
    (
      @backend_host.HostServiceRequest::ShowMenu(_),
      @backend_host.HostServiceResponse::MenuAction(command),
    ) => ignore(self.dispatch_action_command_with_services(command, services))
    (
      @backend_host.HostServiceRequest::ShowMenu(_),
      @backend_host.HostServiceResponse::MenuCommand(intent),
    ) => ignore(self.dispatch_command_with_services(intent, services))
    (
      @backend_host.HostServiceRequest::QuerySystemTheme,
      @backend_host.HostServiceResponse::SystemTheme(scheme),
    ) => {
      self.runtime.set_environment(
        self.runtime.environment().with_system_scheme(scheme),
      )
      self.request_redraw_if_needed()
    }
    _ => ()
  }
  self.event_result()
}
