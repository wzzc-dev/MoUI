///|
/// Mo易 Studio 视图层：三模式 IDE（设计/代码/运行）。
/// 只读 Model、派发既有 Msg；业务规则在 app.mbt 的 update 链。
using @views {
  badge,
  button,
  column,
  divider,
  row,
  text,
  text_area,
  text_field,
  scroll_view,
  frame,
  stack,
}

///|
fn mode_label(mode : Mode) -> String {
  match mode {
    Design => "设计"
    Code => "代码"
    Run => "运行"
  }
}

///|
/// 顶栏：项目操作 + 模式切换 + provider 状态。
fn top_bar(model : Model) -> @moui.View[Msg] {
  row(
    [
      text("\{model.project.name}\{if model.dirty { " *" } else { "" }}").title(),
      badge(
        if model.fake_provider {
          "假模型"
        } else {
          "真实 provider"
        },
        tone=if model.fake_provider {
          @views.BadgeTone::Success
        } else {
          @views.BadgeTone::Warning
        },
        width=96.0,
      ),
      button("新建", on_click=NewProject, width=64.0),
      button("打开", on_click=OpenRequested, width=64.0),
      button("保存", on_click=SaveRequested, width=64.0),
      text("模式："),
      button(
        "设计",
        on_click=SwitchMode(Design),
        width=64.0,
        variant=if model.mode is Design {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Ghost
        },
      ),
      button(
        "代码",
        on_click=SwitchMode(Code),
        width=64.0,
        variant=if model.mode is Code {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Ghost
        },
      ),
      button(
        "运行",
        on_click=StartRun,
        width=64.0,
        variant=if model.mode is Run {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Ghost
        },
      ),
      button("停止", on_click=StopRun, width=64.0),
    ],
    spacing=6.0,
  )
}

///|
/// ---------- 设计模式 ----------

///|
/// 左侧组件面板：点击即添加控件。
fn control_palette(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [
    text("组件工具箱").title(),
    text("点击添加到窗体，拖动画布上的控件调整位置。"),
    button("+ 按钮", on_click=AddControl(Button), width=150.0),
    button("+ 标签", on_click=AddControl(Label), width=150.0),
    button("+ 输入框", on_click=AddControl(TextField), width=150.0),
    divider(),
    text("选中控件：\{selection_label(model)}"),
    text("窗体尺寸：640 × 480"),
  ]
  frame(scroll_view(column(items, spacing=8.0), width=190.0), height=520.0)
}

///|
fn selection_label(model : Model) -> String {
  match model.selection {
    Some(id) =>
      match model.project.find_control(id) {
        Some(control) => "\{control.name}（\{control.kind.label()}）"
        None => "无"
      }
    None => "无"
  }
}

///|
fn prop_row(
  label : String,
  value : String,
  on_input : (String) -> Msg,
) -> @moui.View[Msg] {
  row(
    [text(label, width=52.0), text_field(value, on_input~, width=200.0)],
    spacing=6.0,
  )
}

///|
/// 选中控件的属性检查器。
fn selection_panel(model : Model) -> Array[@moui.View[Msg]] {
  let items : Array[@moui.View[Msg]] = []
  match model.selection {
    None => items.push(text("未选中控件"))
    Some(id) =>
      match model.project.find_control(id) {
        None => items.push(text("选中：#\{id}（已删除）"))
        Some(control) => {
          items.push(text("\{control.name} · \{control.kind.label()}").title())
          items.push(
            prop_row("名称", control.name, fn(input) {
              PropInput(control.id, PropName, input)
            }),
          )
          items.push(
            prop_row("文本", control.text, fn(input) {
              PropInput(control.id, PropText, input)
            }),
          )
          items.push(
            prop_row("X", number_to_text(control.x), fn(input) {
              PropInput(control.id, PropX, input)
            }),
          )
          items.push(
            prop_row("Y", number_to_text(control.y), fn(input) {
              PropInput(control.id, PropY, input)
            }),
          )
          items.push(
            prop_row("宽", number_to_text(control.width), fn(input) {
              PropInput(control.id, PropW, input)
            }),
          )
          items.push(
            prop_row("高", number_to_text(control.height), fn(input) {
              PropInput(control.id, PropH, input)
            }),
          )
          items.push(text("事件子程序").title())
          for event in control.kind.events() {
            let has = model.project.handler_of(control.name, event).is_some()
            items.push(
              button(
                "\{if has { "编辑" } else { "+ 新建" }} \{control.name}.\{event}",
                on_click=if has {
                  EditHandler(control.name, event)
                } else {
                  NewHandler(control.name, event)
                },
                width=260.0,
              ),
            )
          }
          items.push(
            button("删除控件", on_click=DeleteSelected, width=150.0),
          )
        }
      }
  }
  items
}

///|
/// AI 生成面板：提示词 + provider 设置 + 提案预览。
fn ai_panel(model : Model) -> Array[@moui.View[Msg]] {
  let items : Array[@moui.View[Msg]] = [text("AI 生成").title()]
  match model.pending_proposal {
    Some(proposal) => {
      items.push(
        text(
          "新窗体：\{proposal.controls.length()} 个控件 / \{proposal.handlers.length()} 个子程序，校验通过",
        ),
      )
      items.push(button("接受替换", on_click=AcceptProposal))
      items.push(button("取消提案", on_click=CancelProposal))
    }
    None => {
      items.push(
        text_field(
          model.prompt_draft,
          on_input=fn(prompt) { PromptInput(prompt) },
          placeholder="用一句话描述应用，例如：做个加法计算器",
          width=270.0,
        ),
      )
      items.push(button("生成", on_click=GenerateFromPrompt, width=130.0))
      items.push(text("假模型按关键词路由到内置模板；"))
      items.push(text("真实模式下同段描述发给远端模型。"))
      items.push(divider())
      items.push(
        button(
          if model.fake_provider {
            "切换到真实 provider"
          } else {
            "切换到假模型"
          },
          on_click=ToggleProviderMode,
          width=270.0,
        ),
      )
      if !model.fake_provider {
        items.push(
          text_field(
            model.provider_endpoint,
            on_input=fn(endpoint) { ProviderEndpointInput(endpoint) },
            placeholder="OpenAI 兼容 endpoint",
            width=270.0,
          ),
        )
        items.push(
          text_field(
            model.provider_key,
            on_input=fn(key) { ProviderKeyInput(key) },
            placeholder="API Key（不写入项目文件）",
            width=270.0,
          ),
        )
      }
    }
  }
  items
}

///|
fn design_right_panel(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [text("属性检查器").title()]
  for item in selection_panel(model) {
    items.push(item)
  }
  items.push(divider())
  for item in ai_panel(model) {
    items.push(item)
  }
  frame(scroll_view(column(items, spacing=8.0), width=300.0), height=520.0)
}

///|
/// ---------- 代码模式 ----------

///|
/// 左侧事件子程序列表：每个控件 × 每个支持的事件。
fn handler_list(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [text("事件子程序").title()]
  for control in model.project.controls {
    for event in control.kind.events() {
      let has = model.project.handler_of(control.name, event).is_some()
      let is_editing = match model.editing_handler {
        Some((c, e)) => c == control.name && e == event
        None => false
      }
      items.push(
        button(
          "\{if has { "·" } else { "+ " }}\{control.name}.\{event}\{if is_editing { " ←" } else { "" }}",
          on_click=if has {
            EditHandler(control.name, event)
          } else {
            NewHandler(control.name, event)
          },
          width=190.0,
        ),
      )
    }
  }
  frame(scroll_view(column(items, spacing=6.0), width=210.0), height=520.0)
}

///|
/// 中间代码编辑器：当前子程序源码 + 实时语法检查。
fn code_editor(model : Model) -> @moui.View[Msg] {
  match model.editing_handler {
    None =>
      column([
        text("代码编辑").title(),
        text("从左侧选择或新建一个事件子程序。"),
      ])
    Some((control, event)) => {
      let source = model.project
        .handler_of(control, event)
        .unwrap_or(starter_source(event))
      let status = match check_source(source) {
        None => text("✓ 语法正确")
        Some(error) => text("✗ 行 \{error.line()}：\{error.message()}")
      }
      let has_handler = model.project.handler_of(control, event).is_some()
      column(
        [
          row(
            [
              text("\{control}.\{event}").title(),
              button(
                "运行这段",
                on_click=if has_handler {
                  RunHandler(control, event)
                } else {
                  NewHandler(control, event)
                },
                width=96.0,
              ),
            ],
            spacing=10.0,
          ),
          status,
          text_area(
            source,
            on_input=fn(input) { HandlerCodeInput(control, event, input) },
            placeholder="写中文代码，例如：\n变量 名字 = 取文本(\"姓名框\")\n信息框(\"你好，\" + 名字)",
            lines=14,
            width=560.0,
          ),
        ],
        spacing=8.0,
      )
    }
  }
}

///|
/// 右侧 DSL 速查表。
fn dsl_cheatsheet() -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [
    text("Mo易 速查").title(),
    text("变量 总价 = 0"),
    text("总价 = 总价 + 1"),
    text("如果 分数 >= 60 则"),
    text("  …"),
    text("否则"),
    text("  …"),
    text("结束"),
    divider(),
    text("计次循环 5 次 为 i"),
    text("  …"),
    text("结束"),
    divider(),
    text("当 i <= 3 循环"),
    text("  …"),
    text("结束"),
    divider(),
    text("内置命令 / 函数"),
    text("信息框(文本)"),
    text("设置文本(控件名, 文本)"),
    text("取文本(控件名)"),
    text("取数值(控件名)"),
    text("转文本(值)"),
    text("取长度(文本)"),
    text("文本包含(文本, 子串)"),
  ]
  frame(scroll_view(column(items, spacing=6.0), width=220.0), height=520.0)
}

///|
/// ---------- 运行模式 ----------

///|
/// 信息框横幅（解释器 信息框 命令写入）。
fn message_banner(session : RunSession) -> @moui.View[Msg] {
  match session.message {
    Some(content) =>
      row(
        [
          text("【信息框】\{content}").flexible(),
          button("关闭", on_click=DismissMessage, width=72.0),
        ],
        spacing=8.0,
      )
    None => text("运行中… 点击控件触发子程序")
  }
}

///|
/// 运行画面：stack + offset + frame 把真实控件按设计坐标摆放。
fn run_form(model : Model) -> @moui.View[Msg] {
  let session = match model.run {
    Some(session) => session
    None => RunSession::start(model.project)
  }
  let children : Array[@moui.View[Msg]] = []
  for control in model.project.controls {
    let live = session.text_of(control.name, control.text)
    let child = match control.kind {
      Button =>
        button(live, on_click=RunButtonClicked(control.name)).frame(
          width=control.width,
          height=control.height,
        )
      Label =>
        text(live, width=control.width).frame(
          width=control.width,
          height=control.height,
        )
      TextField =>
        text_field(live, on_input=fn(input) {
          RunTextChanged(control.name, input)
        }).frame(width=control.width, height=control.height)
    }
    children.push(child.offset(dx=control.x, dy=control.y))
  }
  stack(children)
  .frame(width=design_width, height=design_height)
  .background(@graphics.Color::rgba(r=0.98, g=0.98, b=0.99))
  .corner_radius(10.0)
}

///|
fn run_right_panel(model : Model) -> @moui.View[Msg] {
  let session = match model.run {
    Some(session) => session
    None => RunSession::start(model.project)
  }
  let items : Array[@moui.View[Msg]] = [text("实时状态").title()]
  for control in model.project.controls {
    items.push(
      text(
        "\{control.name} = 「\{session.text_of(control.name, control.text)}」",
        width=270.0,
      ),
    )
  }
  frame(scroll_view(column(items, spacing=6.0), width=300.0), height=520.0)
}

///|
/// ---------- 整体布局 ----------

///|
fn center_panel(model : Model) -> @moui.View[Msg] {
  match model.mode {
    Design =>
      column([design_canvas(model.project, model.selection)], spacing=8.0)
    Code => code_editor(model)
    Run =>
      column([message_banner(session_of(model)), run_form(model)], spacing=10.0)
  }
}

///|
fn session_of(model : Model) -> RunSession {
  match model.run {
    Some(session) => session
    None => RunSession::start(model.project)
  }
}

///|
fn left_panel(model : Model) -> @moui.View[Msg] {
  match model.mode {
    Design => control_palette(model)
    Code => handler_list(model)
    Run => {
      let items : Array[@moui.View[Msg]] = [
        text("运行").title(),
        text("点击按钮触发「被单击」；"),
        text("修改输入框触发「内容改变」。"),
        divider(),
        text("运行状态独立于设计，"),
        text("停止即丢弃。"),
      ]
      frame(scroll_view(column(items, spacing=6.0), width=190.0), height=520.0)
    }
  }
}

///|
fn right_panel(model : Model) -> @moui.View[Msg] {
  match model.mode {
    Design => design_right_panel(model)
    Code => dsl_cheatsheet()
    Run => run_right_panel(model)
  }
}

///|
/// 三区 IDE 布局：通知条 + 顶栏 + （左面板 | 中央 | 右面板）。
pub fn view(model : Model) -> @moui.View[Msg] {
  column(
    [
      frame(text(model.notice), height=32.0),
      top_bar(model),
      row([
        left_panel(model),
        center_panel(model).flexible(),
        right_panel(model),
      ]).flexible(),
    ],
    spacing=4.0,
  )
}
