///|
/// S7 八项验收入口:`moon run examples/tui_layers/terminal`。
///
/// 一个 app 同时压住八条:双栏(左图层右文件树)、Tab 跨面板、带边框列表、
/// 树折叠、方向键选中、点击 + 滚轮、不提交的即时输入、resize 重排。
/// 键位全在 `examples/tui_layers/app` 的 `program_commands` 里,入口不碰它们;
/// raw mode、SGR 鼠标与 `tui-ansi` 渲染器在 `moui_terminal_host` 里,入口也不碰。
///
/// `--theme dark` 是主题接线演示:app 不知道颜色,入口把 `@core.Theme`
/// 交给宿主,宿主量化进 cell。PTY 门用这个开关证明主题能走完
/// Theme → palette → 终端可见的 SGR 全链路。
///
/// 退出键 Ctrl-C 由宿主拥有(raw mode 下 SIGINT 不会触发)。
fn launch_theme(args : Array[String]) -> @core.Theme? {
  let mut i = 0
  while i + 1 < args.length() {
    if args[i] == "--theme" && args[i + 1] == "dark" {
      return Some(
        @core.Theme::neutral().with_palette(@core.ColorPalette::dark()),
      )
    }
    i = i + 1
  }
  None
}

///|
fn main {
  let theme = launch_theme(@env.args())
  let exit = @terminal_host.run_program(program=@layers_app.program(), theme~)
  let reason = exit.describe()
  if reason.length() > 0 {
    println(reason)
  }
}
