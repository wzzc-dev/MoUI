///|
/// 全链路:Program 模式(与 production 相同的 program/commands/update/effect
/// 接线)下,dispatch 系统菜单的 ActionCommand(等价于 macOS 菜单栏点击
/// `application_menu_on_ready` 安装的命令)→ 匹配 Program commands 绑定
/// → dispatch SetTheme → effect 执行 → runtime environment 实际变化。
async test "theme menu command applies environment in program mode" {
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let pty = match @pty.Pty::spawn("/bin/sh", 24, 6) {
    Some(value) => value
    None => return
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=terminal_program(pty, dispatch_ref, input_queue, runtime_ref),
    size=@core.Size::new(width=864.0, height=520.0),
  )
  runtime_ref.val = Some(runtime)
  // 菜单命令必须与 Program commands 注册的命令全等(dispatch 按 Eq 匹配)
  inspect(
    theme_command(@app.ThemePreference::Dark) ==
    theme_command(@app.ThemePreference::Dark),
    content="true",
  )
  inspect(
    theme_command(@app.ThemePreference::Dark) !=
    theme_command(@app.ThemePreference::Light),
    content="true",
  )
  // 菜单里恰好包含三个主题命令
  let menus = theme_menus()
  inspect(menus.length(), content="1")
  inspect(menus[0].items.length(), content="3")
  // 点击 Dark 菜单项:dispatch_action_command → Program 绑定 → SetTheme
  // → effect → set_environment
  let before = runtime.environment()
  let dispatched = runtime.dispatch_action_command(
    theme_command(@app.ThemePreference::Dark),
  )
  inspect(dispatched, content="true")
  let after = runtime.environment()
  inspect(after.theme_spec.color_mode == @core.ColorMode::Dark, content="true")
  inspect(after.color_scheme() == @core.ColorScheme::Dark, content="true")
  inspect(after.theme.palette != before.theme.palette, content="true")
  // System 菜单项回到跟随系统(theme_spec 恢复默认)
  ignore(
    runtime.dispatch_action_command(theme_command(@app.ThemePreference::System)),
  )
  let back = runtime.environment()
  inspect(back.theme_spec.color_mode == @core.ColorMode::System, content="true")
  pty.close()
}

///|
/// Program commands 注册的三个主题命令映射到正确的 SetTheme 消息。
async test "program commands map theme commands to SetTheme messages" {
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let pty = match @pty.Pty::spawn("/bin/sh", 24, 6) {
    Some(value) => value
    None => return
  }
  let program = terminal_program(pty, dispatch_ref, input_queue, runtime_ref)
  let commands = program.runtime_commands(@app.Model::new(24, 6))
  inspect(commands.length(), content="3")
  match commands[0].message() {
    @app.Msg::SetTheme(pref) => inspect(pref.id(), content="system")
    _ => inspect("unexpected", content="system")
  }
  match commands[1].message() {
    @app.Msg::SetTheme(pref) => inspect(pref.id(), content="light")
    _ => inspect("unexpected", content="light")
  }
  match commands[2].message() {
    @app.Msg::SetTheme(pref) => inspect(pref.id(), content="dark")
    _ => inspect("unexpected", content="dark")
  }
  pty.close()
}
