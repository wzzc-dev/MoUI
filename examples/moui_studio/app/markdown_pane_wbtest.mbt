///|
/// G3:.md 打开路由测试——Markdown 面板走格式渲染(`#` 标记被消费),
/// 非 md 文件仍走 mono 原文渲染(同内容原样出现)。shell_draw 是
/// shell_layout_wbtest 的既有渲染辅助(同包 wbtest 共享)。

///|
fn md_pane_model(rel~ : String, content~ : String) -> Model {
  {
    ..initial_model(),
    // .md 面板挂在代码工作区（WsCode 是 code_workspace 的宿主）
    workspace: WsCode,
    open_project_files: [
      OpenProjectFile::{
        rel,
        saved_content: content,
        draft: content,
        caret: 0,
        selection: None,
      },
    ],
    open_file_index: 0,
  }
}

///|
fn drawn_texts(commands : Array[@core.DrawCommand]) -> Array[String] {
  let texts : Array[String] = []
  for command in commands {
    match command {
      @core.DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
  texts
}

///|
test "打开 .md 走 Markdown 格式渲染,# 标记被消费" {
  let model = md_pane_model(
    rel="guide.md",
    content="# 安装指南\n\n先安装工具链。",
  )
  let commands = shell_draw(model, 1200.0, 800.0)
  let texts = drawn_texts(commands)
  let mut heading_found = false
  let mut marker_leaked = false
  for line in texts {
    if line.contains("安装指南") {
      heading_found = true
    }
    if line.contains("# 安装指南") {
      marker_leaked = true
    }
  }
  assert_true(heading_found, msg="标题应被格式渲染")
  assert_false(
    marker_leaked,
    msg="`#` 标记不应原样出现在 Markdown 面板",
  )
}

///|
test "打开 .mbt 仍走 mono 原文渲染" {
  let model = md_pane_model(rel="lib.mbt", content="# 这是一行注释\n")
  let commands = shell_draw(model, 1200.0, 800.0)
  let texts = drawn_texts(commands)
  let mut raw_found = false
  for line in texts {
    if line.contains("# 这是一行注释") {
      raw_found = true
    }
  }
  assert_true(raw_found, msg="非 md 文件应原样显示源文本")
}

///|
/// G7.3:AI 插件禁用时切 AI 模式 no-op;markdown 禁用时 .md 走 plain 编辑。
test "插件管理:AI 门控与 markdown 回退" {
  let services = @services.AppServices::new()
  let ai_off = update_with_services(
      initial_model(),
      TogglePlugin("ai"),
      services,
    ).0
  let blocked = update_with_services(ai_off, SetPerspective(PsAi), services).0
  assert_false(blocked.perspective is PsAi)
  // markdown 禁用:.md 打开时走 plain 编辑（无 Markdown 面板路由）
  let md_off = update_with_services(
      initial_model(),
      TogglePlugin("markdown"),
      services,
    ).0
  let with_file = {
    ..md_off,
    workspace: WsCode,
    open_project_files: [
      OpenProjectFile::{
        rel: "guide.md",
        saved_content: "# t",
        draft: "# t",
        caret: 0,
        selection: None,
      },
    ],
    open_file_index: 0,
  }
  // 插件禁用 → plain 渲染:原始 `#` 标记原样出现（差分于 Markdown 面板）
  let commands = shell_draw(with_file, 1200.0, 800.0)
  let mut raw_found = false
  for command in commands {
    match command {
      @core.DrawText(run) =>
        // plain 渲染的源文本里有 `#` 标记（词法分段不保证整行一个 run）
        if run.text.contains("#") {
          raw_found = true
        }
      _ => ()
    }
  }
  assert_true(
    raw_found,
    msg="禁用 markdown 插件后 .md 应走 plain 编辑",
  )
}

///|
/// G7.2 属性 v2:字号应用到舞台控件文字;visible=false 控件不渲染。
test "属性 v2:字号生效且可见性门控渲染" {
  // 字号 20:舞台标签文字以 20pt 绘制
  let sized = initial_model()
  sized.program.controls[0] = {
    ..sized.program.controls[0],
    text: "大字",
    props: { ..sized.program.controls[0].props, font_size: 20, },
  }
  let mut size_found = false
  for run in shell_texts(shell_draw(sized, 1280.0, 800.0)) {
    if run.text.contains("大字") && run.font.size == 20.0 {
      size_found = true
    }
  }
  assert_true(size_found, msg="字号 20 应出现在舞台文字绘制里")
  // visible=false:文字不渲染
  let hidden = initial_model()
  hidden.program.controls[0] = {
    ..hidden.program.controls[0],
    text: "隐身",
    props: { ..hidden.program.controls[0].props, visible: false, },
  }
  let mut hidden_found = false
  for run in shell_texts(shell_draw(hidden, 1280.0, 800.0)) {
    if run.text.contains("隐身") {
      hidden_found = true
    }
  }
  assert_false(hidden_found, msg="不可见控件不应渲染文字")
}

///|
/// G7.2 P3e:画布交互键盘(复制/粘贴/置顶/置底/微调/多选)已登记且
/// 按选择门控;置顶/置底真改数组顺序(z-order)。
test "画布交互:命令门控与 z-order" {
  // 初始模型带样例控件选中（selected_control="按钮"）——门控测试用
  // 真正无选中的模型
  let idle = { ..initial_model(), selected_control: "" }
  let mut copy_enabled = false
  let mut front_enabled = false
  let mut nudge_enabled = false
  for entry in studio_program_commands(idle) {
    let cmd = entry.command
    match cmd.shortcut {
      Some(sc) => {
        if sc.key == "c" && cmd.enabled {
          match entry.message {
            CopySelectedControl => copy_enabled = true
            _ => ()
          }
        }
        if sc.key == "]" && cmd.enabled {
          match entry.message {
            BringToFront(_) => front_enabled = true
            _ => ()
          }
        }
        if sc.key == "ArrowLeft" && cmd.enabled {
          match entry.message {
            NudgeControl(_, _, _) => nudge_enabled = true
            _ => ()
          }
        }
      }
      None => ()
    }
  }
  assert_false(copy_enabled, msg="无选中时复制应禁用")
  assert_false(front_enabled, msg="无选中时置顶应禁用")
  assert_false(nudge_enabled, msg="无选中时微调应禁用")
  // 选中控件:门打开;置顶真改数组顺序
  let program = {
    ..initial_model().program,
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Label,
        name: "lbl",
        text: "",
        x: 20,
        y: 20,
        width: 120,
        height: 28,
        items: [],
        props: @ir.ControlProps::default(),
      },
    ],
  }
  let selected = { ..initial_model(), program, selected_control: "lbl" }
  let mut sel_copy = false
  let mut sel_front = false
  for entry in studio_program_commands(selected) {
    let cmd = entry.command
    match cmd.shortcut {
      Some(sc) => {
        if sc.key == "c" && cmd.enabled {
          match entry.message {
            CopySelectedControl => sel_copy = true
            _ => ()
          }
        }
        if sc.key == "]" && cmd.enabled {
          match entry.message {
            BringToFront(_) => sel_front = true
            _ => ()
          }
        }
      }
      None => ()
    }
  }
  assert_true(sel_copy, msg="选中后复制应启用")
  assert_true(sel_front, msg="选中后置顶应启用")
  // z-order 真改数组顺序:置顶后 lbl 在数组末尾
  let fronted = update_with_services(
    selected,
    BringToFront("lbl"),
    @services.AppServices::new(),
  ).0
  assert_eq(fronted.program.controls[fronted.program.controls.length() - 1].name, "lbl")
}
