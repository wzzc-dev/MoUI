///|
/// S5 验收入口:`moon run examples/tui_split/terminal`。
///
/// 双栏 demo 是终端输出路径的验收面:Tab / Shift-Tab 跨面板、上下键选行、
/// 空格折叠树节点、瞬时按键、点击与滚轮、resize 重排。全部键位在
/// `examples/tui_split/app` 的 `program_commands` 里,入口不碰它们;
/// raw mode 与 `tui-ansi` 渲染器在 `moui_terminal_host` 里,入口也不碰。
///
/// 退出键 Ctrl-C 由宿主拥有(raw mode 下 SIGINT 不会触发)。
fn main {
  let exit = @terminal_host.run_program(program=@split_app.program())
  let reason = exit.describe()
  if reason.length() > 0 {
    println(reason)
  }
}
