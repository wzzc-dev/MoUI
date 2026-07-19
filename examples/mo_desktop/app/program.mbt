///|
pub fn program(
  wallpaper_source? : String = "examples/mo_desktop/web_wasm/assets/tahoe-day.jpg",
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @host.HostTimerSource? = None,
  wall_clock? : () -> @host.HostWallClock = default_desktop_clock,
) -> @moui.Program[DesktopModel, Msg] {
  let initial = DesktopModel::new(wallpaper_source~, clock=wall_clock())
  @moui.Program::new_with_environment(
    init=() => (initial, request_system_appearance(services)),
    update=(model, message) => update_with_host(model, message, services),
    view~,
    subscriptions=model => {
      desktop_subscriptions(model, services, timer_source, wall_clock)
    },
  )
}

///|
fn update_with_host(
  model : DesktopModel,
  message : Msg,
  services : @host.HostAppServices,
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
  model : DesktopModel,
  services : @host.HostAppServices,
  timer_source : @host.HostTimerSource?,
  wall_clock : () -> @host.HostWallClock,
) -> @moui.Subscription[Msg] {
  let subscriptions : Array[@moui.Subscription[Msg]] = []
  match timer_source {
    Some(source) =>
      subscriptions.push(
        source.subscription(
          interval_ms=1000.0,
          key="mo-desktop:clock",
          label="Mo Desktop live clock",
          map=_frame => ClockUpdated(wall_clock()),
        ),
      )
    None => ()
  }
  match model.pending_service {
    Some(id) =>
      subscriptions.push(
        services.completion_subscription(
          id,
          map=completion => HostCompleted(completion),
          key="mo-desktop:service:" + id.value.to_string(),
          label="Mo Desktop host service completion",
        ),
      )
    None => ()
  }
  @moui.Subscription::batch(subscriptions)
}

///|
fn request_system_appearance(
  services : @host.HostAppServices,
) -> @moui.Effect[Msg] {
  @moui.Effect::host_service(
    key="mo-desktop:system-appearance",
    label="Read system appearance",
    run=dispatch => {
      let response = services.request_system_theme()
      dispatch(
        HostCompleted(
          host_completion_for(
            response,
            @host.HostServiceRequest::QuerySystemTheme,
          ),
        ),
      )
    },
  )
}

///|
fn request_file_import(services : @host.HostAppServices) -> @moui.Effect[Msg] {
  let request = @host.HostServiceRequest::FileDialog(
    @host.HostFileDialogOptions::new(
      kind=@host.HostFileDialogKind::OpenFile,
      title="Import into Mo Desktop",
      filters=["txt", "md", "pdf", "png", "jpg", "zip"],
    ),
  )
  @moui.Effect::host_service(
    key="mo-desktop:file-import",
    label="Import desktop file",
    run=dispatch => {
      let response = services.open_file(title="Import into Mo Desktop", filters=[
        "txt", "md", "pdf", "png", "jpg", "zip",
      ])
      dispatch(HostCompleted(host_completion_for(response, request)))
    },
  )
}

///|
fn request_external_url(
  services : @host.HostAppServices,
  value : String,
) -> @moui.Effect[Msg] {
  let url = if value.has_prefix("http://") || value.has_prefix("https://") {
    value
  } else {
    "https://" + value
  }
  @moui.Effect::host_service(
    key="mo-desktop:open-url",
    label="Open Safari destination",
    run=dispatch => {
      let response = services.open_url(url)
      dispatch(
        HostCompleted(
          host_completion_for(response, @host.HostServiceRequest::OpenUrl(url)),
        ),
      )
    },
  )
}

///|
fn host_completion_for(
  response : @host.HostServiceResponse,
  request : @host.HostServiceRequest,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  { id, request, response }
}
