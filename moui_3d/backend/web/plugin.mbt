///|
/// Web composition-root plugin for a secondary WebGPU canvas. The browser
/// host owns DOM placement; this addon only forwards the neutral viewport
/// bridge and does not depend on the concrete WebGPU renderer.
pub fn plugin(
  host? : @moui_3d.ThreeDViewportHost? = None,
) -> @host.PlatformViewPlugin {
  let bridge = match host {
    Some(value) => value
    None =>
      @moui_3d.ThreeDViewportHost::new(
        binding=@moui_3d.ThreeDViewportBinding::new(),
      )
  }
  let dispatcher : @ref.Ref[@host.PlatformViewEventCallback?] = @ref.Ref(None)
  let active_window : @ref.Ref[UInt64?] = @ref.Ref(None)
  let active_id : @ref.Ref[String?] = @ref.Ref(None)
  let last_status : @ref.Ref[@moui_3d.ViewportStatus?] = @ref.Ref(None)
  let notify_status = () => {
    match (dispatcher.val, active_window.val, active_id.val) {
      (Some(callback), Some(window), Some(id)) => {
        let status = bridge.binding().status()
        if last_status.val != Some(status) {
          last_status.val = Some(status)
          callback(
            window,
            id,
            @core.PlatformViewEvent::Named(
              name="renderer_status",
              value="",
              detail="",
              flag=false,
            ),
          )
        }
      }
      _ => ()
    }
  }
  bridge.set_invalidate_handler(notify_status)
  @host.PlatformViewPlugin::new(
    kind="moui_3d_viewport",
    capabilities_summary="available: secondary WebGPU canvas host",
    install_event_dispatcher=callback => dispatcher.val = Some(callback),
    sync_platform_views=(window, frame, offset) => {
      let mut found = false
      for placement in frame.platform_views {
        if placement.kind == "moui_3d_viewport" {
          found = true
          active_window.val = Some(window)
          active_id.val = Some(placement.id)
          let canvas = web_3d_canvas(window)
          let main_canvas = web_3d_get_canvas(
            web_3d_string("moonbit-window-web-\{window}"),
          )
          let overlay_active = frame.overlay_bounds is Some(_)
          if web_3d_canvas_valid(main_canvas) {
            web_3d_set_canvas_layer(
              main_canvas,
              if overlay_active {
                1
              } else {
                0
              },
            )
          }
          web_3d_set_canvas_position(
            canvas,
            placement.frame.origin.x,
            placement.frame.origin.y + offset,
            placement.frame.size.width,
            placement.frame.size.height,
            if overlay_active {
              0
            } else {
              1
            },
          )
          web_3d_set_canvas_visible(canvas, true)
          bridge.sync_platform_view(
            window,
            placement,
            window,
            frame,
            offset,
            scale_factor=web_3d_canvas_scale_factor(canvas),
          )
          notify_status()
        }
      }
      if !found {
        active_window.val = None
        active_id.val = None
        let canvas = web_3d_existing_canvas(window)
        if web_3d_canvas_valid(canvas) {
          web_3d_set_canvas_visible(canvas, false)
        }
        bridge.dispose_platform_views(window)
      }
    },
    drain_commands=_window => (),
    dispose_platform_views=window => {
      bridge.dispose_platform_views(window)
      active_window.val = None
      active_id.val = None
      let canvas = web_3d_existing_canvas(window)
      if web_3d_canvas_valid(canvas) {
        web_3d_remove_platform_canvas_events(window.to_int(), canvas)
        web_3d_destroy_canvas(canvas)
      }
    },
  )
}

///|
#external
priv type Web3DCanvas

///|
extern "wasm" fn web_3d_begin_string() -> Int = "window_web" "begin_create_string"

///|
extern "wasm" fn web_3d_string_append(handle : Int, code_point : Int) -> Unit = "window_web" "string_append_char"

///|
extern "wasm" fn web_3d_finish_string(handle : Int) -> Int = "window_web" "finish_create_string"

///|
fn web_3d_string(value : String) -> Int {
  let handle = web_3d_begin_string()
  for index in 0..<value.length() {
    web_3d_string_append(
      handle,
      value.code_unit_at(index).unsafe_to_char().to_int(),
    )
  }
  web_3d_finish_string(handle)
}

///|
extern "wasm" fn web_3d_create_canvas(
  id : Int,
  width : Int,
  height : Int,
) -> Web3DCanvas = "window_web" "create_canvas"

///|
extern "wasm" fn web_3d_get_canvas(id : Int) -> Web3DCanvas = "window_web" "get_canvas_by_id"

///|
extern "wasm" fn web_3d_canvas_valid(canvas : Web3DCanvas) -> Bool = "window_web" "canvas_is_valid"

///|
extern "wasm" fn web_3d_set_canvas_visible(
  canvas : Web3DCanvas,
  visible : Bool,
) -> Unit = "window_web" "set_canvas_visible"

///|
extern "wasm" fn web_3d_set_canvas_position(
  canvas : Web3DCanvas,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  z_index : Int,
) -> Unit = "window_web" "set_canvas_position"

///|
extern "wasm" fn web_3d_set_canvas_layer(
  canvas : Web3DCanvas,
  z_index : Int,
) -> Unit = "window_web" "set_canvas_layer"

///|
extern "wasm" fn web_3d_canvas_scale_factor(canvas : Web3DCanvas) -> Double = "window_web" "canvas_scale_factor"

///|
extern "wasm" fn web_3d_destroy_canvas(canvas : Web3DCanvas) -> Unit = "window_web" "destroy_canvas"

///|
extern "wasm" fn web_3d_install_platform_canvas_events(
  raw_id : Int,
  canvas : Web3DCanvas,
  platform_view_id : Int,
) -> Unit = "window_web" "install_platform_canvas_events"

///|
extern "wasm" fn web_3d_remove_platform_canvas_events(
  raw_id : Int,
  canvas : Web3DCanvas,
) -> Unit = "window_web" "remove_platform_canvas_events"

///|
fn web_3d_existing_canvas(window : UInt64) -> Web3DCanvas {
  web_3d_get_canvas(web_3d_string("moui-3d-viewport-\{window}"))
}

///|
fn web_3d_canvas(window : UInt64) -> Web3DCanvas {
  let id = "moui-3d-viewport-\{window}"
  let handle = web_3d_existing_canvas(window)
  if web_3d_canvas_valid(handle) {
    handle
  } else {
    let canvas = web_3d_create_canvas(web_3d_string(id), 1, 1)
    web_3d_install_platform_canvas_events(
      window.to_int(),
      canvas,
      web_3d_string("moui-3d-viewport"),
    )
    canvas
  }
}
