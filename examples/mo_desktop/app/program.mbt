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
      let updated = initial
        .update(UseSystemAppearance)
        .update(LoadDesktopSettings)
      let effect = @moui.Effect::batch([
        request_system_appearance(services),
        load_desktop_settings(services),
      ])
      (updated, effect)
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
  let before = model.persisted_snapshot()
  let effect = match message {
    UseSystemAppearance => request_system_appearance(services)
    RequestFileImport => request_file_import(services)
    OpenFavorite(value) => request_external_url(services, value)
    LoadDesktopSettings => load_desktop_settings(services)
    ResetDesktopSettings | RunMenuCommand(ResetDesktopSettingsCommand) =>
      remove_desktop_settings(services)
    _ => @moui.Effect::none()
  }
  let updated = model.update(message)
  // Persist after the fact: any state change that alters the snapshot issues
  // a settings write once loading has completed. Load/reset are excluded so
  // restoration never re-writes and reset actually clears.
  let save_effect = if updated.settings_loaded &&
    !(message is (DesktopSettingsLoaded(_) | DesktopSettingsResetCompleted(_))) &&
    updated.persisted_snapshot() != before {
    save_desktop_settings(services, updated.persisted_snapshot())
  } else {
    @moui.Effect::none()
  }
  let combined = match effect {
    @moui.Effect::NoEffect => save_effect
    other => @moui.Effect::batch([other, save_effect])
  }
  (updated, combined)
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

///|
fn load_desktop_settings(services : @services.AppServices) -> @moui.Effect[Msg] {
  services
  .settings()
  .read(SETTINGS_STORAGE_KEY)
  .effect(map=result => DesktopSettingsLoaded(result))
}

///|
fn save_desktop_settings(
  services : @services.AppServices,
  snapshot : DesktopSnapshot,
) -> @moui.Effect[Msg] {
  services
  .settings()
  .write(SETTINGS_STORAGE_KEY, encode_desktop_snapshot(snapshot))
  .effect(map=result => DesktopSettingsSaved(result))
}

///|
fn remove_desktop_settings(
  services : @services.AppServices,
) -> @moui.Effect[Msg] {
  services
  .settings()
  .remove(SETTINGS_STORAGE_KEY)
  .effect(map=result => DesktopSettingsResetCompleted(result))
}
