///|
/// Platform-neutral composition for the DSH WebView program. Native roots
/// wrap this program in `@runtime.new_program_with_dimensions` before adding
/// their renderer and backend.
pub fn runtime(
  capabilities~ : @webview_host.HostWebViewCapabilities,
  controller~ : @webview_host.WebViewController,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  url? : String = default_url,
  on_navigation_finished? : (String) -> Unit = _ => (),
) -> @moui.Program[Model, Msg] {
  program(
    capability=if capabilities.available {
      WebViewCapability::available(description=capabilities.description)
    } else {
      WebViewCapability::unavailable(description=capabilities.description)
    },
    controller=Some(controller),
    environment~,
    url~,
    on_navigation_finished~,
  )
}

///|
/// Composition-root configuration is the only place that grants navigation
/// and patch capabilities to the controller. Origins are exact native policy
/// values; the page cannot widen them through a bridge envelope.
pub fn create_controller(
  host : @webview_host.WebViewHost,
) -> @webview_host.WebViewController {
  let origins = [
    @webview_host.WebViewOrigin::parse(default_url).unwrap(),
    @webview_host.WebViewOrigin::parse(default_chat_url).unwrap(),
  ]
  let security = @webview_host.WebViewSecurityPolicy::new(
    allowed_origins=origins.copy(),
    allowed_channels=[
      @webview_host.WebViewChannelPolicy::new(
        name="dsh.event",
        direction=@webview_host.WebViewChannelDirection::Bidirectional,
      ),
      @webview_host.WebViewChannelPolicy::new(
        name="dsh.request",
        direction=@webview_host.WebViewChannelDirection::Bidirectional,
      ),
    ],
  )
  let patch = @webview_host.HostPatchBundle::new(
    id="dsh-shell",
    version="1.0.0",
    allowed_origins=origins.copy(),
    stylesheet=Some(
      ".hHd-Xa_root{padding-top:27px!important}.hHd-Xa_root.hHd-Xa_collapsed.hHd-Xa_railIn{padding-top:37px!important}.pI_x6G_frame[data-moui-collapsed-rail-safe=true]{grid-template-columns:80px minmax(0,1fr) 0px!important}.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .pI_x6G_sidebarCol{width:80px!important}.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_root{width:80px!important}.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_toggle,.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_newSession,.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .qDHVXG_root,.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_settingsArea{margin-left:auto!important;margin-right:auto!important}.dshDesktopUpstreamSidebar{padding-top:32px!important}",
    ),
    document_end_script=Some(
      "(function(){function syncRail(){var frame=document.querySelector('.pI_x6G_frame');var root=document.querySelector('.hHd-Xa_root');if(!frame||!root)return;if(root.classList.contains('hHd-Xa_collapsed'))frame.setAttribute('data-moui-collapsed-rail-safe','true');else frame.removeAttribute('data-moui-collapsed-rail-safe')}syncRail();if(window.MutationObserver&&document.documentElement)new MutationObserver(syncRail).observe(document.documentElement,{subtree:true,attributes:true,attributeFilter:['class']})})();",
    ),
  )
  host
  .create_controller(
    id="dsh-desktop-surface",
    config=@webview_host.WebViewControllerConfig::new(
      security~,
      host_patches=[patch],
      capabilities=["bridge-v1", "host-patch-v1"],
    ),
  )
  .unwrap()
}
