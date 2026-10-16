///|
/// TUI 出口:`moon run examples/counter/terminal`。
///
/// 入口只做两件事——挑一个应用、把退出原因在离开 alt screen 之后说一次。
/// raw mode、alt screen、鼠标与键盘协议、`tui-ansi` 渲染器的声明都属于
/// `moui_terminal_host`;把它们复制到每个 example 里,迟早会有一份忘记还原
/// 终端,把用户的 shell 留在 raw mode。
///
/// 退出键是 Ctrl-C:raw mode 关掉了 `ISIG`,所以它到不了 SIGINT。
fn main {
  let exit = @terminal_host.run_program(program=@counter_app.program())
  let reason = exit.describe()
  if reason.length() > 0 {
    println(reason)
  }
}
