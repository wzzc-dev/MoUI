///|
/// Cross-backend WebView FFI codecs shared by the macOS, Windows, and Linux
/// native hosts. Each native bridge marshals strings as UTF-8 `Bytes` and
/// encodes events, navigation policies, and commands as plain integer codes;
/// these helpers own the single source of truth for that wire format so the
/// three platform hosts stay in sync.

///|
/// Encode a host string as UTF-8 bytes for a native webview bridge call.
pub fn webview_encode_ffi_string(text : String) -> Bytes {
  @utf8.encode(text[:], bom=false)
}

///|
/// Decode UTF-8 bytes received from a native webview bridge back into a host
/// string.
pub fn webview_decode_ffi_string(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes[:], ignore_bom=true)
}

///|
/// Decode a native webview event (identified by its integer kind code plus the
/// url/detail bytes and boolean flag) into a platform-neutral `WebViewEvent`.
/// Unknown kind codes fall back to `NavigationFailed` to preserve forward
/// compatibility with newer native bridges.
pub fn webview_decode_native_event(
  kind : Int,
  url : Bytes,
  detail : Bytes,
  flag : Int,
) -> WebViewEvent {
  let url_text = webview_decode_ffi_string(url)
  let detail_text = webview_decode_ffi_string(detail)
  match kind {
    0 => WebViewEvent::NavigationRequested(url_text)
    1 => WebViewEvent::NavigationStarted(url_text)
    2 => WebViewEvent::NavigationCommitted(url_text)
    3 => WebViewEvent::NavigationFinished(url_text)
    4 => WebViewEvent::NavigationFailed(url_text, detail_text)
    5 => WebViewEvent::TitleChanged(detail_text)
    6 => WebViewEvent::CanGoBackChanged(flag != 0)
    7 => WebViewEvent::CanGoForwardChanged(flag != 0)
    8 => WebViewEvent::JavaScriptResult(url_text, detail_text)
    _ => WebViewEvent::NavigationFailed(url_text, detail_text)
  }
}

///|
/// Encode a `WebViewNavigationPolicy` as the integer code expected by native
/// webview bridges.
pub fn webview_native_policy_code(policy : WebViewNavigationPolicy) -> Int {
  match policy {
    WebViewNavigationPolicy::AllowHttpHttpsFile => 0
    WebViewNavigationPolicy::AllowHttpHttps => 1
    WebViewNavigationPolicy::AllowAll => 2
  }
}

///|
/// Encode a `WebViewCommand` as the integer kind code plus the optional text
/// and detail fields expected by native webview bridges.
pub fn webview_encode_native_command(
  command : WebViewCommand,
) -> (Int, String, String) {
  match command {
    WebViewCommand::LoadUrl(url) => (0, url, "")
    WebViewCommand::Reload => (1, "", "")
    WebViewCommand::Stop => (2, "", "")
    WebViewCommand::GoBack => (3, "", "")
    WebViewCommand::GoForward => (4, "", "")
    WebViewCommand::EvaluateJavaScript(script, request_id) =>
      (5, script, request_id)
  }
}
