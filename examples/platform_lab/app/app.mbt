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
/// Copy-paste lab for host Effect / Subscription recipes and canvas paint.
pub struct Model {
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
  timer_source : @host.HostTimerSource?
  window_events : @host.HostWindowEventSource?
}

///|
pub(all) enum Msg {
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
}

///|
pub fn Model::new(
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @host.HostTimerSource? = None,
  window_events? : @host.HostWindowEventSource? = None,
  timer_running? : Bool = false,
) -> Model {
  {
    timer_running,
    ticks: 0,
    window_width: 0.0,
    window_height: 0.0,
    clipboard_text: "",
    last_event: "Platform Lab ready",
    pending_service: None,
    stroke_points: [],
    anim_phase: 0.0,
    services,
    timer_source,
    window_events,
  }
}

///|
pub fn update(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match msg {
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
      let text = "platform-lab ticks=\{model.ticks}"
      (
        { ..model, last_event: "Writing clipboard…" },
        @moui.Effect::host_service(
          key="platform-lab:clipboard-write",
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
          key="platform-lab:clipboard-read",
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
          key="platform-lab:file-open",
          label="Open file",
          run=dispatch => {
            dispatch(
              HostCompleted(
                completion_for(
                  model.services.open_file(
                    title="Platform Lab open",
                    filters=["txt", "md", "json"],
                  ),
                  @host.HostServiceRequest::FileDialog(
                    @host.HostFileDialogOptions::new(
                      kind=@host.HostFileDialogKind::OpenFile,
                      title="Platform Lab open",
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
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  column(
    [
      text("MoUI Platform Lab").title(),
      text(
        "Recipes: timer, window resize, clipboard, file open, shortcuts, canvas.",
      ),
      text("Last: \{model.last_event}"),
      card(
        column([
          text("Timer ticks: \{model.ticks}"),
          text(
            if model.timer_running {
              "Running"
            } else {
              "Stopped"
            },
          ),
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
      card(
        column([
          text("Canvas lab (drag inside to add points)"),
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
            semantics_label="Platform lab canvas",
          ).on_drag(event => CanvasDrag(event.position)),
          row([button("Clear canvas", on_click=ClearCanvas)]),
        ]),
      ),
      text("Keyboard: entrypoint installs ActionCommandMap (meta/ctrl+T → Activate)."),
    ],
    spacing=12.0,
  )
  .padding(16.0)
}

///|
pub fn subscriptions(model : Model) -> @moui.Subscription[Msg] {
  let subs : Array[@moui.Subscription[Msg]] = []
  match model.pending_service {
    Some(id) =>
      subs.push(
        model.services.completion_subscription(
          id,
          map=completion => HostCompleted(completion),
          key="platform-lab:service:" + id.value.to_string(),
          label="Platform lab host completion",
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
            key="platform-lab:timer",
            label="Platform lab timer",
            map=_ => TimerTick,
          ),
        )
      }
      subs.push(
        source.subscription(
          interval_ms=50.0,
          key="platform-lab:anim",
          label="Platform lab animation",
          map=_ => AnimTick,
        ),
      )
    }
    None => ()
  }
  match model.window_events {
    Some(source) =>
      subs.push(
        source.subscription(
          key="platform-lab:window",
          label="Platform lab window events",
          map=window_event =>
            match window_event.event {
              @host.HostEvent::Resized(metrics) =>
                Some(
                  WindowResized(
                    metrics.logical_size.width,
                    metrics.logical_size.height,
                  ),
                )
              _ => None
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
  timer_source? : @host.HostTimerSource? = None,
  window_events? : @host.HostWindowEventSource? = None,
) -> @moui.Program[Model, Msg] {
  let init = Model::new(services~, timer_source~, window_events~)
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
    label="Lab tick",
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key="t",
        modifiers=@views.KeyModifiers::new(meta=true),
      ),
    ),
    group="Platform Lab",
    description="Demo shortcut installed on the host action-command map",
  )
  @views.ActionCommandMap::new(
    bindings=[@views.CommandBinding::new(command~, handle=() => ())],
  )
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
      let summary = if paths.length() == 0 {
        "(no files)"
      } else {
        paths[0]
      }
      { ..model, pending_service: None, last_event: "Opened \{summary}" }
    }
    @host.HostServiceResponse::Unavailable(reason) =>
      {
        ..model,
        pending_service: None,
        last_event: "Unavailable: \{reason}",
      }
    _ => { ..model, pending_service: None, last_event: "Host service completed" }
  }
}
