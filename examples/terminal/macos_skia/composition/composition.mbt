///|
fn default_shell() -> String {
  match @env.get_env_var("SHELL") {
    Some(shell) => shell
    None => "/bin/sh"
  }
}

///|
/// 输入队列工作项:文本写入 PTY,或关闭信号。
pub enum InputWork {
  Write(String)
  Shutdown
}

///|
/// 终端初始行列(与窗口画布尺寸、PTY 初始窗口尺寸保持一致)。
fn terminal_size() -> (Int, Int) {
  (90, 26)
}

///|
/// 主题偏好 → 菜单/命令共用的 ActionCommand。
/// 菜单安装与 Program commands 注册共用此构造,保证 dispatch 匹配
/// (ActionCommandMap 按全等比较)。
pub fn theme_command(pref : @app.ThemePreference) -> @core.ActionCommand {
  @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    label=pref.label(),
    group="Theme",
    description="Switch terminal theme to \{pref.label()}",
  )
}

///|
/// 系统菜单(安装到 macOS 菜单栏)。AppKit 会在启动完成时替换默认菜单,
/// 因此通过 `MacosHostAppOptions::on_ready` 在 `did_finish_launching` 之后安装。
pub fn theme_menus() -> Array[@services.ApplicationMenu] {
  [
    @services.ApplicationMenu::new(title="Terminal", items=[
      @services.ApplicationMenuItem::MenuCommand(
        theme_command(@app.ThemePreference::System),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        theme_command(@app.ThemePreference::Light),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        theme_command(@app.ThemePreference::Dark),
      ),
    ]),
  ]
}

///|
/// 终端 Program 组装:
/// - init 阶段经 Effect::run 捕获 UI dispatch,供 PTY worker 注入 Feed;
/// - WriteInput 经 Effect::run 入队,由 worker 写入 PTY;
/// - view 用 addon 键盘透传节点,⌘+方向键滚动回看,其余按键编码透传。
pub fn terminal_program(
  _pty : @pty.Pty,
  dispatch_ref : Ref[((@app.Msg) -> Unit)?],
  input_queue : @async.Queue[InputWork],
  runtime_ref : Ref[@runtime.AppRuntime?],
) -> @moui.Program[@app.Model, @app.Msg] {
  let program = @moui.Program::new(
    init=() => {
      (
        @app.Model::new(terminal_size().0, terminal_size().1),
        @moui.Effect::run(
          key="capture-dispatch",
          kind="terminal",
          label="Capture UI dispatch",
          run=dispatch => dispatch_ref.val = Some(dispatch),
        ),
      )
    },
    update=(model, msg) => {
      match msg {
        @app.Msg::WriteInput(text) =>
          (
            @app.update(model, msg),
            @moui.Effect::run(
              key="pty-write",
              kind="terminal",
              label="PTY input",
              run=_dispatch => {
                ignore(
                  input_queue.try_put(InputWork::Write(text)) catch {
                    _ => false
                  },
                )
              },
            ),
          )
        @app.Msg::Copy => {
          let text = @app.selection_text(model.screen, model.selection)
          (
            @app.update(model, msg),
            if text.is_empty() {
              @moui.Effect::none()
            } else {
              @moui.Effect::run(
                key="terminal-copy",
                kind="terminal",
                label="Copy selection to clipboard",
                run=_dispatch => {
                  ignore(@macos_host.macos_clipboard_write_text(text))
                },
              )
            },
          )
        }
        @app.Msg::SetTheme(pref) =>
          (
            @app.update(model, msg),
            @moui.Effect::run(
              key="theme-apply",
              kind="terminal",
              label="Apply theme preference",
              run=_dispatch => {
                match runtime_ref.val {
                  Some(runtime) =>
                    runtime.set_environment(
                      runtime
                      .environment()
                      .with_theme_spec(theme_spec_for(pref)),
                    )
                  None => ()
                }
              },
            ),
          )
        _ => (@app.update(model, msg), @moui.Effect::none())
      }
    },
    view=terminal_view_wrapped,
    subscriptions=_model => @moui.Subscription::none(),
  )
  program.with_commands(commands=_model => {
    let mk = fn(pref : @app.ThemePreference) -> @core.ProgramCommand[@app.Msg] {
      @core.ProgramCommand::new(
        command=theme_command(pref),
        message=@app.Msg::SetTheme(pref),
      )
    }
    [
      mk(@app.ThemePreference::System),
      mk(@app.ThemePreference::Light),
      mk(@app.ThemePreference::Dark),
    ]
  })
}

///|
/// 主题偏好 → ThemeSpec:System 用默认 spec(跟随宿主注入的系统外观),
/// Light/Dark 强制对应 scheme。
fn theme_spec_for(pref : @app.ThemePreference) -> @core.ThemeSpec {
  match pref {
    @app.ThemePreference::System => @core.ThemeSpec::default()
    @app.ThemePreference::Light => @core.ThemeSpec::minimal_light()
    @app.ThemePreference::Dark => @core.ThemeSpec::minimal_dark()
  }
}

///|
/// 键盘事件 → 消息:
/// - ⌘+C:复制选中文本(不发送给终端);
/// - ⌘+方向键:滚动回看;
/// - 其它按键:编码为终端输入。
fn keyboard_to_msg(event : @core.KeyboardEvent) -> @app.Msg? {
  if event.modifiers.meta {
    match event.key {
      "ArrowUp" => Some(@app.Msg::ScrollBy(-3))
      "ArrowDown" => Some(@app.Msg::ScrollBy(3))
      "Home" => Some(@app.Msg::ScrollBy(-100000))
      "End" => Some(@app.Msg::ScrollBy(100000))
      "c" => Some(@app.Msg::Copy)
      _ => None
    }
  } else {
    @addon.encode_key(event).map(text => @app.Msg::WriteInput(text))
  }
}

///|
pub fn terminal_view_wrapped(model : @app.Model) -> @moui.View[@app.Msg] {
  let theme = @app.theme_for_pref(model.theme_pref)
  let screen = model.screen()
  let selection_view = @addon.terminal_selection_input(
    @app.view(model),
    (row, col) => Some(@app.Msg::SelectionBegin(row, col)),
    (row, col) => Some(@app.Msg::SelectionMove(row, col)),
    () => Some(@app.Msg::SelectionEnd),
    cell_width=@app.cell_width(theme),
    cell_height=@app.cell_height(theme),
    scroll_offset=model.scroll_offset(),
    total_lines=screen.total_lines(),
    rows=screen.rows(),
    cols=screen.cols(),
  )
  @addon.keyboard_input(selection_view, keyboard_to_msg, text => {
    Some(@app.Msg::WriteInput(text))
  })
}

///|
pub async fn run_terminal() -> Unit {
  let shell = default_shell()
  let pty = match @pty.Pty::spawn(shell, terminal_size().0, terminal_size().1) {
    Some(value) => value
    None => {
      println("Failed to spawn shell: \{shell}")
      return
    }
  }
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  // 窗口画布尺寸与等宽单元格度量联动:列数 × cell_width × 行数 × cell_height
  // (构建期度量;终端文本/按钮渲染色由 runtime environment 驱动)。
  let theme = @app.theme_for_pref(@app.ThemePreference::System)
  let (cols, rows) = terminal_size()
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let runtime = @runtime.new_program_with_dimensions(
    program=terminal_program(pty, dispatch_ref, input_queue, runtime_ref),
    width=cols.to_double() * @app.cell_width(theme),
    height=rows.to_double() * @app.cell_height(theme),
  )
  runtime_ref.val = Some(runtime)
  let window_task : async () -> Unit = async fn() {
    @runtime.run_app("MoUI Terminal", runtime)
    .render_all(
      @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
    )
    .backend(
      @macos_host.entry(
        options=@macos_host.MacosHostAppOptions::new(
          on_ready=Some(() => {
            @macos_host.application_menu_on_ready(theme_menus(), runtime)()
            // 启动即聚焦终端键盘节点:无需先点击窗口即可输入
            // (键盘事件只派发给 focused 元素)
            ignore(runtime.focus_next())
          }),
        ),
      ),
    )
    .run_async_pump()
    // 窗口关闭后通知 worker 退出并关闭 PTY
    ignore(input_queue.try_put(InputWork::Shutdown) catch { _ => false })
  }
  let worker_task : async () -> Unit = async fn() {
    // 等待 UI dispatch 就绪(init effect 执行)
    while dispatch_ref.val is None {
      @async.sleep(10)
    }
    let emit = fn(bytes : Bytes) -> Unit {
      match dispatch_ref.val {
        Some(dispatch) => dispatch(@app.Msg::Feed(bytes))
        None => ()
      }
    }
    // 读循环与输入写入循环并行
    @async.with_task_group(group => {
      let reader_task = group.spawn(no_wait=true, allow_failure=true) <| () => {
        @pty.pty_read_loop(pty, emit)
      }
      while true {
        let work = input_queue.get()
        match work {
          InputWork::Write(text) =>
            ignore(pty.write_input(@utf8.encode(text)) catch { _ => 0 })
          InputWork::Shutdown => {
            // 先取消读循环(避免与 close 竞争同一 fd),再关闭 PTY
            reader_task.cancel()
            pty.close()
            break
          }
        }
      }
    })
  }
  try {
    let _ = @async.all([window_task, worker_task])
  } catch {
    err => println("App exited with error: \{err}")
  }
}
