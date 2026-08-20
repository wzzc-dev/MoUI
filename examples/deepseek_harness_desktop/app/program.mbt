///|
pub fn program(
  capability~ : WebViewCapability,
  controller? : @webview_host.WebViewController? = None,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  url? : String = default_url,
  on_navigation_finished? : (String) -> Unit = _ => (),
) -> @moui.Program[Model, Msg] {
  let controller = match controller {
    Some(value) => Some(value)
    None if capability.available => Some(test_or_preview_controller())
    None => None
  }
  let services = environment.services()
  @moui.Program::new_with_environment(
    init=() => {
      let initial = Model::new(capability~, url~)
      let settings = request_settings_load(services)
      let navigation = match controller {
        Some(controller) =>
          controller
          .navigate(initial.url)
          .effect(map=result => {
            match result {
              @webview_host.WebViewTaskResult::Success(_) =>
                WebViewEvent(@webview_host.WebViewEvent::Ready([]))
              _ => WebViewEvent(@webview_host.WebViewEvent::Disposed)
            }
          })
        None => @moui.Effect::none()
      }
      (initial, @moui.Effect::batch([settings, navigation]))
    },
    update=(model, msg) => {
      let (next, effect) = update_with_services(model, msg, services)
      let navigation = match (controller, msg) {
        (Some(controller), SwitchSite) =>
          controller
          .navigate(next.url)
          .effect(map=result => {
            match result {
              @webview_host.WebViewTaskResult::Success(_) =>
                WebViewEvent(@webview_host.WebViewEvent::Ready([]))
              _ => WebViewEvent(@webview_host.WebViewEvent::Disposed)
            }
          })
        _ => @moui.Effect::none()
      }
      match msg {
        WebViewEvent(@webview_host.WebViewEvent::NavigationFinished(navigation)) =>
          on_navigation_finished(navigation.url)
        _ => ()
      }
      (next, @moui.Effect::batch([effect, navigation]))
    },
    view=(model, view_environment) => {
      view_with_environment(model, view_environment, controller)
    },
  ).with_commands(commands=_model => program_commands())
}

///|
/// Preview/test fallback. Native composition roots inject the policy-bound
/// controller from `runtime.mbt`; tests still get a controller when available.
fn test_or_preview_controller() -> @webview_host.WebViewController {
  let host = @webview_host.WebViewHost::new()
  let security = @webview_host.WebViewSecurityPolicy::new(allowed_origins=[
    @webview_host.WebViewOrigin::parse(default_url).unwrap(),
    @webview_host.WebViewOrigin::parse(default_chat_url).unwrap(),
  ])
  host
  .create_controller(
    id="dsh-desktop-surface",
    config=@webview_host.WebViewControllerConfig::new(security~),
  )
  .unwrap()
}
