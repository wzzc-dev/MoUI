///|
using @views {
  button,
  canvas,
  card,
  column,
  fill_rounded_rect,
  pop_opacity,
  push_opacity,
  row,
  text,
}

///|
/// Host Effect / Subscription recipes, canvas paint, and mobile service probe.
/// Not an ordinary app dependency example: this package may use `backend/host`.
pub struct Model {
  route : String
  timer_running : Bool
  ticks : Int
  window_width : Double
  window_height : Double
  clipboard_text : String
  last_event : String
  pending_service : @host.HostServiceRequestId?
  stroke_points : Array[@geometry.Point]
  anim_phase : Double
  services : @host.HostAppServices
  timer_source : @runtime.HostTimerSource?
  window_events : @runtime.HostWindowEventSource?
  probe_text : String
  probe_action_count : Int
  probe_submit_count : Int
  host_label : String
}

///|
pub(all) enum Msg {
  Navigate(String)
  ToggleTimer
  TimerTick
  WindowResized(Double, Double)
  WriteClipboard
  ReadClipboard
  OpenFile
  HostCompleted(@host.HostCompletedServiceResponse)
  CanvasDrag(@geometry.Point)
  ClearCanvas
  AnimTick
  ShortcutTick
  ProbeTextChanged(String)
  ProbeAction
  ProbeSubmit
}

///|
pub fn platform_routes() -> Array[String] {
  ["host-services", "canvas", "mobile-service-probe", "route-session"]
}

///|
pub fn normalize_platform_route(route : String) -> String {
  if platform_routes().contains(route) {
    route
  } else if route == "overview" || route == "timer" || route == "" {
    "host-services"
  } else {
    "host-services"
  }
}

///|
pub fn Model::new(
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @runtime.HostTimerSource? = None,
  window_events? : @runtime.HostWindowEventSource? = None,
  timer_running? : Bool = false,
  route? : String = "host-services",
  host_label? : String = "Showcase platform host",
) -> Model {
  {
    route: normalize_platform_route(route),
    timer_running,
    ticks: 0,
    window_width: 0.0,
    window_height: 0.0,
    clipboard_text: "",
    last_event: "Showcase Platform ready",
    pending_service: None,
    stroke_points: [],
    anim_phase: 0.0,
    services,
    timer_source,
    window_events,
    probe_text: "mobile-service-probe",
    probe_action_count: 0,
    probe_submit_count: 0,
    host_label,
  }
}

///|
pub fn Model::route(self : Model) -> String {
  self.route
}

///|
pub fn Model::open(self : Model, route : String) -> Model {
  { ..self, route: normalize_platform_route(route) }
}

///|
pub fn Model::with_host_label(self : Model, host_label : String) -> Model {
  { ..self, host_label, }
}

///|
/// Inject host adapters after the root shell is constructed. Canvas animation
/// and host-service recipes require a real timer/service bridge from the
/// platform entrypoint.
pub fn Model::with_host_adapters(
  self : Model,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @runtime.HostTimerSource? = None,
  window_events? : @runtime.HostWindowEventSource? = None,
) -> Model {
  { ..self, services, timer_source, window_events }
}

///|
pub fn update(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match msg {
    Navigate(route) => (model.open(route), @moui.Effect::none())
    ToggleTimer =>
      (
        {
          ..model,
          timer_running: !model.timer_running,
          last_event: if model.timer_running {
            "Timer stopped"
          } else {
            "Timer started"
          },
        },
        @moui.Effect::none(),
      )
    TimerTick =>
      (
        {
          ..model,
          ticks: model.ticks + 1,
          last_event: "Timer tick \{model.ticks + 1}",
        },
        @moui.Effect::none(),
      )
    WindowResized(width, height) =>
      (
        {
          ..model,
          window_width: width,
          window_height: height,
          last_event: "Window \{width}×\{height}",
        },
        @moui.Effect::none(),
      )
    WriteClipboard => {
      let text = "showcase-platform ticks=\{model.ticks}"
      (
        { ..model, last_event: "Writing clipboard…" },
        @moui.Effect::host_service(
          key="showcase-platform:clipboard-write",
          label="Write clipboard",
          run=dispatch => {
            dispatch(
              HostCompleted(
                completion_for(
                  model.services.write_clipboard_text(text),
                  @host.HostServiceRequest::Clipboard(
                    @host.HostClipboardRequest::WriteText(text),
                  ),
                ),
              ),
            )
          },
        ),
      )
    }
    ReadClipboard =>
      (
        { ..model, last_event: "Reading clipboard…" },
        @moui.Effect::host_service(
          key="showcase-platform:clipboard-read",
          label="Read clipboard",
          run=dispatch => {
            dispatch(
              HostCompleted(
                completion_for(
                  model.services.read_clipboard_text(),
                  @host.HostServiceRequest::Clipboard(
                    @host.HostClipboardRequest::ReadText,
                  ),
                ),
              ),
            )
          },
        ),
      )
    OpenFile =>
      (
        { ..model, last_event: "Opening file dialog…" },
        @moui.Effect::host_service(
          key="showcase-platform:file-open",
          label="Open file",
          run=dispatch => {
            dispatch(
              HostCompleted(
                completion_for(
                  model.services.open_file(title="Showcase Platform open", filters=[
                    "txt", "md", "json",
                  ]),
                  @host.HostServiceRequest::FileDialog(
                    @host.HostFileDialogOptions::new(
                      kind=@host.HostFileDialogKind::OpenFile,
                      title="Showcase Platform open",
                      filters=["txt", "md", "json"],
                    ),
                  ),
                ),
              ),
            )
          },
        ),
      )
    HostCompleted(completion) =>
      (apply_host_completion(model, completion), @moui.Effect::none())
    CanvasDrag(point) => {
      let points = model.stroke_points.copy()
      points.push(point)
      (
        {
          ..model,
          stroke_points: points,
          last_event: "Canvas drag \{point.x},\{point.y}",
        },
        @moui.Effect::none(),
      )
    }
    ClearCanvas =>
      (
        { ..model, stroke_points: [], last_event: "Canvas cleared" },
        @moui.Effect::none(),
      )
    AnimTick =>
      (
        {
          ..model,
          anim_phase: model.anim_phase + 0.08,
          last_event: "Animation tick",
        },
        @moui.Effect::none(),
      )
    ShortcutTick =>
      (
        {
          ..model,
          ticks: model.ticks + 1,
          last_event: "Shortcut (Cmd/Ctrl+T) tick",
        },
        @moui.Effect::none(),
      )
    ProbeTextChanged(value) =>
      ({ ..model, probe_text: value }, @moui.Effect::none())
    ProbeAction =>
      (
        {
          ..model,
          probe_action_count: model.probe_action_count + 1,
          last_event: "Probe action \{model.probe_action_count + 1}",
        },
        @moui.Effect::none(),
      )
    ProbeSubmit =>
      (
        {
          ..model,
          probe_submit_count: model.probe_submit_count + 1,
          last_event: "Probe submit \{model.probe_submit_count + 1}",
        },
        @moui.Effect::none(),
      )
  }
}

///|
fn host_services_page(model : Model) -> @moui.View[Msg] {
  column(
    [
      text("Host services").title(),
      text("Timer, window resize, clipboard, file open, and host shortcuts."),
      text("Last: \{model.last_event}"),
      card(
        column([
          text("Timer ticks: \{model.ticks}"),
          text(if model.timer_running { "Running" } else { "Stopped" }),
          row([
            button(
              if model.timer_running {
                "Stop timer"
              } else {
                "Start timer"
              },
              on_click=ToggleTimer,
            ),
          ]),
        ]),
      ),
      card(
        column([
          text("Window size: \{model.window_width} × \{model.window_height}"),
          text("Resize the host window to update this card."),
        ]),
      ),
      card(
        column([
          text(
            if model.clipboard_text == "" {
              "Clipboard: (empty)"
            } else {
              "Clipboard: \{model.clipboard_text}"
            },
          ),
          row([
            button("Write clipboard", on_click=WriteClipboard),
            button("Read clipboard", on_click=ReadClipboard),
            button("Open file…", on_click=OpenFile),
          ]),
        ]),
      ),
      text(
        "Keyboard: entrypoint installs ActionCommandMap (meta/ctrl+T → Activate).",
      ),
    ],
    spacing=12.0,
  )
}

///|
fn canvas_page(model : Model) -> @moui.View[Msg] {
  column(
    [
      text("Canvas").title(),
      text("Drag inside the canvas to add stroke points."),
      text("Last: \{model.last_event}"),
      card(
        column([
          canvas(
            measure=constraints => {
              constraints.constrain(
                @geometry.Size::new(width=360.0, height=160.0),
              )
            },
            draw=(ctx, frame) => {
              let phase = model.anim_phase
              let opacity = 0.55 + 0.45 * ((@math.sin(phase * 0.5) + 1.0) * 0.5)
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=frame, radius=12.0),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.93, g=0.95, b=0.98),
                ),
              )
              push_opacity(ctx, opacity)
              let orb = @geometry.Rect::new(
                x=frame.origin.x + 24.0 + 18.0 * @math.sin(phase),
                y=frame.origin.y + 24.0,
                width=48.0,
                height=48.0,
              )
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=orb, radius=24.0),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.2, g=0.45, b=0.9),
                ),
              )
              pop_opacity(ctx)
              for point in model.stroke_points {
                let dot = @geometry.Rect::new(
                  x=point.x - 3.0,
                  y=point.y - 3.0,
                  width=6.0,
                  height=6.0,
                )
                fill_rounded_rect(
                  ctx,
                  @graphics.RoundedRect::new(rect=dot, radius=3.0),
                  @graphics.Brush::solid(
                    @graphics.Color::rgba(r=0.1, g=0.1, b=0.15),
                  ),
                )
              }
            },
            semantics_label="Showcase platform canvas",
          ).on_drag(event => CanvasDrag(event.position)),
          row([button("Clear canvas", on_click=ClearCanvas)]),
        ]),
      ),
    ],
    spacing=12.0,
  )
}

///|
fn mobile_service_probe_image_source() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
fn mobile_service_probe_page(model : Model) -> @moui.View[Msg] {
  column(
    [
      text("Mobile Service Probe").title(),
      text("IME, action, image, and viewport checks for mobile host sessions."),
      text("Last: \{model.last_event}"),
      card(
        column(
          [
            text("Host: \{model.host_label}"),
            @views.text_field(
              model.probe_text,
              on_input=value => ProbeTextChanged(value),
              on_submit=Some(ProbeSubmit),
              placeholder="Service probe text",
              variant=@views.TextFieldVariant::Outline,
            ),
            text("IME value: " + model.probe_text).accessibility_label(
              "Service probe value " + model.probe_text,
            ),
            button("Activate service probe", on_click=ProbeAction),
            text("Action count: \{model.probe_action_count}").accessibility_label(
              "Service probe action count \{model.probe_action_count}",
            ),
            text("Submit count: \{model.probe_submit_count}"),
            text(
              "Viewport: \{model.window_width.to_int()} x \{model.window_height.to_int()}",
            ).accessibility_label(
              "Service probe viewport \{model.window_width.to_int()} by \{model.window_height.to_int()}",
            ),
            @views.image(
              mobile_service_probe_image_source(),
              width=160.0,
              height=240.0,
              corner_radius=6.0,
              fit=@graphics.ImageFit::Contain,
            ).accessibility_label("Service probe async image"),
            text("Service probe end"),
          ],
          spacing=8.0,
        ),
      ),
    ],
    spacing=12.0,
  )
}

///|
fn route_session_page(model : Model) -> @moui.View[Msg] {
  column(
    [
      text("Route & session").title(),
      text("Current platform workspace route and host session labels."),
      card(
        column(
          [
            text("Route: platform/\{model.route}"),
            text("Host label: \{model.host_label}"),
            text("Timer running: \{model.timer_running}"),
            text("Pending service: \{to_repr(model.pending_service)}"),
            text("Last event: \{model.last_event}"),
          ],
          spacing=8.0,
        ),
      ),
    ],
    spacing=12.0,
  )
}

///|

///|
/// Hosted body for the unified Showcase shell (no local chrome).
pub fn view_body(model : Model, width? : Double = 0.0) -> @moui.View[Msg] {
  ignore(width)
  match model.route {
    "canvas" => canvas_page(model)
    "mobile-service-probe" => mobile_service_probe_page(model)
    "route-session" => route_session_page(model)
    _ => host_services_page(model)
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  view_body(model).padding(16.0)
}

///|
/// Timer and pending-service subscriptions stay active regardless of the
/// visible platform route so root workspace switches do not tear them down.
pub fn subscriptions(model : Model) -> @moui.Subscription[Msg] {
  let subs : Array[@moui.Subscription[Msg]] = []
  match model.pending_service {
    Some(id) =>
      subs.push(
        model.services.completion_subscription(
          id,
          map=completion => HostCompleted(completion),
          key="showcase-platform:service:" + id.value.to_string(),
          label="Showcase platform host completion",
        ),
      )
    None => ()
  }
  match model.timer_source {
    Some(source) => {
      if model.timer_running {
        subs.push(
          source.subscription(
            interval_ms=500.0,
            key="showcase-platform:timer",
            label="Showcase platform timer",
            map=_ => TimerTick,
          ),
        )
      }
      if model.route == "canvas" {
        subs.push(
          source.subscription(
            interval_ms=50.0,
            key="showcase-platform:anim",
            label="Showcase platform animation",
            map=_ => AnimTick,
          ),
        )
      }
    }
    None => ()
  }
  match model.window_events {
    Some(source) =>
      subs.push(
        source.subscription(
          key="showcase-platform:window",
          label="Showcase platform window events",
          map=window_event => {
            match window_event.event {
              @host.HostEvent::Resized(metrics) =>
                Some(
                  WindowResized(
                    metrics.logical_size.width,
                    metrics.logical_size.height,
                  ),
                )
              _ => None
            }
          },
        ),
      )
    None => ()
  }
  @moui.Subscription::batch(subs)
}

///|
pub fn program(
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @runtime.HostTimerSource? = None,
  window_events? : @runtime.HostWindowEventSource? = None,
  route? : String = "host-services",
) -> @moui.Program[Model, Msg] {
  let init = Model::new(services~, timer_source~, window_events~, route~)
  @moui.Program::new(
    init=() => (init, @moui.Effect::none()),
    update~,
    view~,
    subscriptions~,
  )
}

///|
/// Host keyboard shortcut metadata. Entrypoints call
/// `runtime.set_action_commands(action_command_map())`.
pub fn action_command_map() -> @views.ActionCommandMap {
  let command = @views.ActionCommand::new(
    intent=@views.CommandIntent::Activate,
    label="Platform tick",
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key="t",
        modifiers=@views.KeyModifiers::new(meta=true),
      ),
    ),
    group="Showcase Platform",
    description="Demo shortcut installed on the host action-command map",
  )
  @views.ActionCommandMap::new(bindings=[
    @views.CommandBinding::new(command~, handle=() => ()),
  ])
}

///|
fn completion_for(
  response : @host.HostServiceResponse,
  request : @host.HostServiceRequest,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  { id, request, response }
}

///|
fn apply_host_completion(
  model : Model,
  completion : @host.HostCompletedServiceResponse,
) -> Model {
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      {
        ..model,
        pending_service: Some(id),
        last_event: "Host service pending \{id.value}",
      }
    @host.HostServiceResponse::ClipboardWritten =>
      { ..model, pending_service: None, last_event: "Clipboard written" }
    @host.HostServiceResponse::ClipboardText(text) =>
      {
        ..model,
        pending_service: None,
        clipboard_text: text,
        last_event: "Clipboard read",
      }
    @host.HostServiceResponse::FileDialogSelection(paths) => {
      let summary = if paths.length() == 0 { "(no files)" } else { paths[0] }
      { ..model, pending_service: None, last_event: "Opened \{summary}" }
    }
    @host.HostServiceResponse::Unavailable(reason) =>
      { ..model, pending_service: None, last_event: "Unavailable: \{reason}" }
    _ =>
      { ..model, pending_service: None, last_event: "Host service completed" }
  }
}
