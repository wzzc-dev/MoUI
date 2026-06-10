///|
pub(all) enum WebViewNavigationPolicy {
  AllowHttpHttpsFile
  AllowHttpHttps
  AllowAll
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebViewEvent {
  NavigationRequested(String)
  NavigationStarted(String)
  NavigationCommitted(String)
  NavigationFinished(String)
  NavigationFailed(String, String)
  TitleChanged(String)
  CanGoBackChanged(Bool)
  CanGoForwardChanged(Bool)
  JavaScriptResult(String, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebViewCommand {
  LoadUrl(String)
  Reload
  Stop
  GoBack
  GoForward
  EvaluateJavaScript(String, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebViewSpec {
  key : Key?
  id : String
  url : String
  width : Double?
  height : Double?
  title : String
  policy : WebViewNavigationPolicy
  on_event : ((WebViewEvent) -> Unit)?
}

///|
pub(all) struct PlatformViewPlacement {
  id : String
  kind : String
  frame : Rect
  clip : Rect?
  url : String
  title : String
  policy : WebViewNavigationPolicy
} derive(Eq, Debug, ToJson)

///|
pub fn WebViewSpec::new(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : WebViewNavigationPolicy = WebViewNavigationPolicy::AllowHttpHttpsFile,
  on_event? : ((WebViewEvent) -> Unit)? = None,
) -> WebViewSpec {
  { key: None, id, url, width, height, title, policy, on_event }
}

///|
pub fn WebViewSpec::allows_url(self : WebViewSpec, url : String) -> Bool {
  match self.policy {
    AllowAll => true
    AllowHttpHttpsFile =>
      web_view_url_has_any_scheme(url, ["http:", "https:", "file:"])
    AllowHttpHttps => web_view_url_has_any_scheme(url, ["http:", "https:"])
  }
}

///|
pub fn WebViewCommand::load_url(url : String) -> WebViewCommand {
  LoadUrl(url)
}

///|
pub fn WebViewCommand::evaluate_javascript(
  script~ : String,
  request_id? : String = "",
) -> WebViewCommand {
  EvaluateJavaScript(script, request_id)
}

///|
pub fn PlatformViewPlacement::web_view(
  spec~ : WebViewSpec,
  frame~ : Rect,
  clip? : Rect? = None,
) -> PlatformViewPlacement {
  {
    id: spec.id,
    kind: "web_view",
    frame,
    clip,
    url: spec.url,
    title: spec.title,
    policy: spec.policy,
  }
}

///|
fn web_view_url_has_any_scheme(url : String, schemes : Array[String]) -> Bool {
  let lower = url.to_lower()
  schemes.any(scheme => web_view_string_starts_with(lower, scheme))
}

///|
fn web_view_string_starts_with(text : String, prefix : String) -> Bool {
  let chars = text.to_array()
  let prefix_chars = prefix.to_array()
  if prefix_chars.length() > chars.length() {
    false
  } else {
    for index in 0..<prefix_chars.length() {
      if chars[index] != prefix_chars[index] {
        return false
      }
    }
    true
  }
}
