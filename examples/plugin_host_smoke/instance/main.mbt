///|
/// 把 counter 插件暴露成**可实例化的 wasm 模块**（P2.5 决策门的插件侧）。
///
/// 在这之前 `examples/plugin_host_smoke` 里的两个「实例」只是同进程的两份
/// `CounterModel`，注释也承认它们「stand in for two isolated wasm instances」。
/// 这个文件把它变成真的：包声明为 `executable`，并在 `moon.pkg` 的
/// `options(link.wasm-gc.exports)` 里登记四个 ABI 函数。
///
/// **导出形参只能用标量与句柄**（见 `moui_studio/web_wasm/abi.mbt` 的同款教训）：
/// 所以 `plugin_init(w, h)` 收 `Double`，`plugin_handle_event` 收 `text_id`，
/// `plugin_render` 回一个句柄 id，宿主用 `take_host_string` 读。

///|
/// 插件的全部状态。一个实例一份——这正是隔离的意义。
let state : Ref[@app.CounterModel] = Ref(@app.CounterModel::new("counter"))

///|
/// 插件的视口尺寸，`plugin_init` 写入。
let viewport : Ref[@core.Size] = Ref(@core.Size::new(width=120.0, height=80.0))

///|
/// `window_web` 的字符串协议。**在实例包里自己声明**，不 import `@web`：
/// 插件没有渲染器，而「有后端 import 就必须有渲染器」这条边界规则是对的——
/// 插件不是平台根。这 6 个 extern 就是插件实例对宿主的全部要求。
extern "wasm" fn host_begin_create_string() -> Int = "window_web" "begin_create_string"

///|
extern "wasm" fn host_string_append_char(handle : Int, code : Int) -> Unit = "window_web" "string_append_char"

///|
extern "wasm" fn host_finish_create_string(handle : Int) -> Int = "window_web" "finish_create_string"

///|
extern "wasm" fn host_begin_read_string(id : Int) -> Int = "window_web" "begin_read_string"

///|
extern "wasm" fn host_string_read_char(handle : Int) -> Int = "window_web" "string_read_char"

///|
extern "wasm" fn host_finish_read_string(handle : Int) -> Unit = "window_web" "finish_read_string"

///|
/// 把字符串变成一个句柄 id（标量），可以跨导出边界。
fn to_handle(value : String) -> Int {
  let handle = host_begin_create_string()
  for ch in value {
    host_string_append_char(handle, ch.to_int())
  }
  ignore(host_finish_create_string(handle))
  handle
}

///|
/// 读回宿主投进来的字符串（游标语义：每次读一个码点，-1 结束）。
fn from_handle(id : Int) -> String {
  let handle = host_begin_read_string(id)
  let buffer = StringBuilder::new()
  while true {
    let code = host_string_read_char(handle)
    if code == -1 {
      break
    }
    buffer.write_char(code.unsafe_to_char())
  }
  host_finish_read_string(handle)
  buffer.to_string()
}

///|
/// `plugin_init(w, h)`：宿主告诉实例它拿到多大的矩形。
///
/// 返回 `Bool` 而不是 `Unit`：宿主需要知道初始化是否成功，而 `extern` 导出
/// 用返回码比抛异常可靠（trap 的代价是整个实例失效）。
pub fn plugin_init(width : Double, height : Double) -> Bool {
  if width < 0.0 || height < 0.0 {
    return false
  }
  viewport.val = @core.Size::new(width~, height~)
  true
}

///|
/// `plugin_handle_event(text_id)`：把一条事件 JSON 投给实例。
///
/// 返回 `Int`：0 = 无变化，1 = 需要重绘，2 = 请求退出形态。用整数而不是枚举
/// 是因为导出边界只认标量。
pub fn plugin_handle_event(text_id : Int) -> Int {
  let event = from_handle(text_id)
  // 这一版只认「bump」这个词：决策门要验证的是**跨实例的事件路由**，不是事件
  // 解析的完整度。真实插件会在这里解 P0 的 `AppEvent` JSON。
  if event.contains("bump") {
    state.val = @app.counter_update(state.val, @app.Bump)
    1
  } else {
    0
  }
}

///|
/// `plugin_render()`：渲染当前状态，返回命令帧的宿主字符串句柄。
pub fn plugin_render() -> Int {
  let runtime = @runtime.new_view(
    root=@app.counter_view(state.val),
    size=viewport.val,
  )
  let json = @core.draw_commands_to_json(runtime.draw_commands())
  // 走 `window_web` 的既有字符串协议（`begin_create_string` / `append` /
  // `finish`），宿主侧用同一套 `takeString` 读回。**这意味着插件实例的宿主
  // 必须提供 `window_web` 的字符串导入**——那是 P2 实例宿主的真实成本之一，
  // 也是这个决策门要暴露的事实。
  to_handle(json)
}

///|
/// 可执行包需要一个 ；插件实例不跑自己的事件循环（宿主驱动它），
/// 所以这里立刻返回。 被调用只意味着「实例起来了」。
fn main {
  ()
}
