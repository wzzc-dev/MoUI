///|
/// `new_world` 作为 **Studio 插件实例**（计划 P5.3 的落地）。
///
/// 这个包只做三件事：持有实例状态、把宿主给的矩形转成布局、把一帧编码成命令
/// JSON。视图与更新逻辑全在 `@app`——它没有 `runtime`/`core` 依赖（app 包边界
/// 要求），所以实例壳必须单独一个包。
///
/// **对宿主的全部要求是 6 个字符串函数**（见下方 extern）：`plugin_init(w, h)`
/// 收尺寸，`plugin_handle_event(text_id)` 收事件，`plugin_render()` 回一个句柄。
/// 实测该模块 494 KB 量级、只 import `window_web` 的字符串协议。

///|
/// `window_web` 字符串协议（游标读：每次一个码点，-1 结束）。
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
fn to_handle(value : String) -> Int {
  let handle = host_begin_create_string()
  for ch in value {
    host_string_append_char(handle, ch.to_int())
  }
  ignore(host_finish_create_string(handle))
  handle
}

///|
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
/// 实例状态：一份模型 + 它拿到的矩形。
///
/// `layout` 由 P5.1 的 `Layout::for_width` 从矩形宽度算出——这正是布局参数化
/// 存在的理由：同一个 `app` 包既能撑满独立窗口，也能装进 Studio 分配的面板。
let model : Ref[@app.WorldModel] = Ref(@app.WorldModel::new())

///|
let size : Ref[@core.Size] = Ref(@core.Size::new(width=800.0, height=600.0))

///|
/// `plugin_init(w, h)`：宿主告诉实例它拿到多大的矩形。
pub fn plugin_init(width : Double, height : Double) -> Bool {
  if width < 0.0 || height < 0.0 {
    return false
  }
  size.val = @core.Size::new(width~, height~)
  true
}

///|
/// `plugin_handle_event(text_id)`：把一条事件 JSON 投给实例。
///
/// 返回 0 = 无变化、1 = 需要重绘。真实的事件分发要走 P0 的 `AppEvent` 解码与
/// `@app.update`，那需要 app 暴露 Msg 构造；这一版先只做「收到事件就重绘」，
/// 决策门要证明的是**实例装载与帧产出**，不是完整事件语义。
pub fn plugin_handle_event(text_id : Int) -> Int {
  let _event = from_handle(text_id)
  1
}

///|
/// `plugin_render()`：按当前矩形渲染一帧，返回命令 JSON 的句柄。
pub fn plugin_render() -> Int {
  let frame = @runtime.new_view(root=@app.view(model.val), size=size.val)
  to_handle(@core.draw_commands_to_json(frame.draw_commands()))
}

///|
/// 可执行包需要 `main`；插件实例不由自己驱动事件循环。
fn main {
  ()
}
