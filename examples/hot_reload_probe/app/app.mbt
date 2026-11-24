///|
/// Probe model for the native hot-reload smoke: a click-incremented count
/// proves opt-in state survives a plugin swap, and a timer-driven tick count
/// proves host frames keep the plugin clock and subscriptions alive.
pub struct Model {
  count : Int32
  ticks : Int32
}

///|
pub(all) enum Msg {
  Increment
  Tick
}

///|
pub fn Model::new() -> Model {
  { count: 0, ticks: 0, }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { ..model, count: model.count + 1, }
    Tick => { ..model, ticks: model.ticks + 1, }
  }
}

///|
fn app_view(model : Model) -> @moui.View[Msg] {
  let content = @views.column(
    [
      @views.text("Hot Reload Probe"),
      @views.text("Count: \{model.count}"),
      @views.text("Ticks: \{model.ticks}"),
      @views.text("Shared: \{@widgets.shared_badge_text()}"),
      @views.image(
        "resource/branding/moui-mark.png",
        width=48.0,
        height=48.0,
        corner_radius=10.0,
        accessibility_label="MoUI mark",
      ),
      @views.divider(),
      @views.card(@views.text("Shadowed card")).shadow(
        @graphics.ShadowStyle::new(
          color=@graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.24),
          offset=@geometry.Point::new(x=0.0, y=4.0),
          blur_radius=16.0,
          spread=0.0,
        ),
      ),
      @widgets.status_card(model.ticks),
    ],
    spacing=8.0,
  )
  @views.center(content, width=520.0, height=360.0).on_tap(Increment)
}

///|
fn subscriptions(timer : @services.TimerSource?) -> @moui.Subscription[Msg] {
  match timer {
    Some(timer) =>
      @services.TimerSource::subscription(
        timer,
        interval_ms=100.0,
        map=_frame => Tick,
        key="hot-reload-probe:tick",
        label="Hot reload probe tick",
      )
    None => @moui.Subscription::none()
  }
}

///|
pub fn program_with_dev_environment(
  environment : @services.AppEnvironment,
) -> @moui.Program[Model, Msg] {
  let timer = environment.timer()
  @moui.Program::new_with_environment(
    init=() => (Model::new(), @moui.Effect::none()),
    update=(model, msg) => (update(model, msg), @moui.Effect::none()),
    view=(model, _env) => app_view(model),
    subscriptions=_model => subscriptions(timer),
  ).with_state_persistence(
    save=model => Json::number(model.count.to_double()).stringify(),
    load=payload => {
      let parsed = @json.parse(payload) catch { _ => return None }
      match parsed {
        Json::Number(count, repr=_) =>
          Some({ count: count.to_int(), ticks: 0, })
        _ => None
      }
    },
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  program_with_dev_environment(@services.AppEnvironment::new())
}
