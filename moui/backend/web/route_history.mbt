///|
let web_active_route_source : Ref[@services.RouteSource?] = Ref(None)

///|
pub fn web_history_push_route(route : String) -> Unit {
  web_history_push_route_host(web_host_string(route))
}

///|
pub fn web_history_replace_route(route : String) -> Unit {
  web_history_replace_route_host(web_host_string(route))
}

///|
pub fn web_history_back() -> Unit {
  web_history_back_host()
}

///|
pub fn web_history_forward() -> Unit {
  web_history_forward_host()
}

///|
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  ignore(web_dispatch_route_text(source_code, web_host_string_from_id(text_id)))
}

///|
fn set_web_route_source(source : @services.RouteSource?) -> Unit {
  web_active_route_source.val = source
}

///|
fn web_dispatch_route_text(source_code : Int, route : String) -> Int {
  match web_active_route_source.val {
    Some(source) =>
      source.publish(
        @services.RouteEvent::from_route(
          route~,
          source=web_route_source_label(source_code),
        ),
      )
    None => 0
  }
}

///|
fn web_route_source_label(source_code : Int) -> String {
  match source_code {
    0 => "web-initial"
    1 => "web-popstate"
    2 => "web-pushstate"
    3 => "web-replacestate"
    _ => "web-route"
  }
}

///|
fn web_history_push_route_host(route : WebHostString) -> Unit = "window_web" "history_push_route"

///|
fn web_history_replace_route_host(route : WebHostString) -> Unit = "window_web" "history_replace_route"

///|
fn web_history_back_host() -> Unit = "window_web" "history_back"

///|
fn web_history_forward_host() -> Unit = "window_web" "history_forward"
