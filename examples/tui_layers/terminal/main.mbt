///|
/// S7 八项验收入口:`moon run examples/tui_layers/terminal`。
///
/// 一个 app 同时压住八条:双栏(左图层右文件树)、Tab 跨面板、带边框列表、
/// 树折叠、方向键选中、点击 + 滚轮、不提交的即时输入、resize 重排。
/// 键位全在 `examples/tui_layers/app` 的 `program_commands` 里,入口不碰它们;
/// raw mode、SGR 鼠标与 `tui-ansi` 渲染器在 `moui_terminal_host` 里,入口也不碰。
///
/// 退出键 Ctrl-C 由宿主拥有(raw mode 下 SIGINT 不会触发)。
fn main {
  let exit = @terminal_host.run_program(program=@layers_app.program())
  let reason = exit.describe()
  if reason.length() > 0 {
    println(reason)
  }
}
