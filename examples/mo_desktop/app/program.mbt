///|
pub fn program(
  wallpaper_source? : String = "examples/mo_desktop/web_wasm/assets/tahoe-day.jpg",
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  wall_clock? : () -> DesktopClock = default_desktop_clock,
) -> @moui.Program[DesktopModel, Msg] {
  let services = environment.services()
  let initial = DesktopModel::new(wallpaper_source~, clock=wall_clock())
  @moui.Program::new_with_environment(
    init=() => {
      (initial.update(UseSystemAppearance), request_system_appearance(services))
    },
    update=(model, message) => update_with_services(model, message, services),
    view~,
    subscriptions=model => desktop_subscriptions(model, environment, wall_clock),
  )
}

///|
fn update_with_services(
  model : DesktopModel,
  message : Msg,
  services : @services.AppServices,
) -> (DesktopModel, @moui.Effect[Msg]) {
  let effect = match message {
    UseSystemAppearance => request_system_appearance(services)
    RequestFileImport => request_file_import(services)
    OpenFavorite(value) => request_external_url(services, value)
    _ => @moui.Effect::none()
  }
  (model.update(message), effect)
}

///|
fn desktop_subscriptions(
  _model : DesktopModel,
  environment : @services.AppEnvironment,
  wall_clock : () -> DesktopClock,
) -> @moui.Subscription[Msg] {
  match environment.timer() {
    Some(source) =>
      source.subscription(
        interval_ms=1000.0,
        key="mo-desktop:clock",
        label="Mo Desktop live clock",
        map=_frame => ClockUpdated(wall_clock()),
      )
    None => @moui.Subscription::none()
  }
}

///|
fn request_system_appearance(
  services : @services.AppServices,
) -> @moui.Effect[Msg] {
  services
  .appearance()
  .system_color_scheme()
  .effect(map=result => SystemAppearanceCompleted(result))
}

///|
fn request_file_import(services : @services.AppServices) -> @moui.Effect[Msg] {
  services
  .files()
  .open_file(
    options=@services.FileDialogOptions::new(title="Import into Mo Desktop", filters=[
      "txt", "md", "pdf", "png", "jpg", "zip",
    ]),
  )
  .map(path => [path])
  .effect(map=result => FileImportCompleted(result))
}

///|
fn request_external_url(
  services : @services.AppServices,
  value : String,
) -> @moui.Effect[Msg] {
  let url = if value.has_prefix("http://") || value.has_prefix("https://") {
    value
  } else {
    "https://" + value
  }
  services.urls().open(url).effect(map=result => UrlOpenCompleted(result))
}
