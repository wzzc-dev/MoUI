///|
/// `wzzc-dev/moui/backend/web` 的**宿主入口 ABI**：Moon 的 wasm 链接器只导出
/// 「可执行包自身定义」的函数，所以宿主入口必须在工程自己的入口包里逐个转发。
/// 这份名单与转发实现是 `moui new` 生成工程与 Studio 导出 bundle **共用**的
/// 契约——后端加一个入口，两边必须同一批改；各写一遍就是两次漂移的机会。

///|
pub let web_abi_exports : ReadOnlyArray[String] = [
  "web_dispatch_event", "web_dispatch_pointer_input", "web_dispatch_semantics_action",
  "web_dispatch_route", "web_complete_async_clipboard_read", "web_complete_async_file_dialog",
]

///|
/// 与 `web_abi_exports` 逐条对应的机械转发（只含宿主入口，不含 `fn main`）。
/// 前提：调用方的入口包以 `@web` 别名导入 `wzzc-dev/moui/backend/web`。
///
/// 参数表跟着**已发布**的那条 ABI 走，不跟工作区：生成的工程按 `moon.mod`
/// 里的版本号从 registry 解析 `wzzc-dev/moui`，而它的 `browser_runtime.js`
/// 也来自同一份 `.mooncakes`，两边必须同一批 arity。工作区里领先发布线的
/// 入口改动只改 `examples/*/web_wasm/abi.mbt` 与 `website/web_wasm/main.mbt`
/// （它们是 workspace 成员），发布线移动后再一起改这里。
pub fn web_abi_shim_mbt() -> String {
  let shim =
    #|///|
    #|pub fn web_dispatch_event(
    #|  kind : Int,
    #|  raw_id : Int,
    #|  arg0 : Int,
    #|  arg1 : Int,
    #|  argd : Double,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_pointer_input(
    #|  raw_id : Int,
    #|  kind : Int,
    #|  x_px : Double,
    #|  y_px : Double,
    #|  delta_x_px : Double,
    #|  delta_y_px : Double,
    #|  button : Int,
    #|  modifiers : Int,
    #|) -> Int {
    #|  @web.web_dispatch_pointer_input(
    #|    raw_id,
    #|    kind,
    #|    x_px,
    #|    y_px,
    #|    delta_x_px,
    #|    delta_y_px,
    #|    button,
    #|    modifiers,
    #|  )
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
    #|  @web.web_dispatch_route(source_code, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_semantics_action(
    #|  raw_id : Int,
    #|  node_id_text_id : Int,
    #|  generation_text_id : Int,
    #|  action_code : Int,
    #|  value_id : Int,
    #|  direction_code : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_semantics_action(
    #|    raw_id,
    #|    node_id_text_id,
    #|    generation_text_id,
    #|    action_code,
    #|    value_id,
    #|    direction_code,
    #|  )
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_clipboard_read(
    #|  request_id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_clipboard_read(request_id, ok, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_file_dialog(
    #|  request_id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_file_dialog(request_id, ok, text_id)
    #|}
  shim
}
