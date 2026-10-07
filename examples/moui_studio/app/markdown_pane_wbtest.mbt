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
