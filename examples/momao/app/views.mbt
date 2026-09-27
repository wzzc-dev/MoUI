///|
/// MoMao Studio 视图层：顶栏 + 左栏（控件/子程序）+ 中部（三模式）+
/// 右栏（属性 / AI 提案）+ 运行区。全部文案过 i18n 翻译器。

///|
/// 顶栏：标题、语言切换、模式 tab、模板、文件操作、运行控制。
fn top_bar(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  @views.row([
    @views.text(text(t, "app.title")),
    @views.button(text(t, "app.lang.switch"), on_click=SwitchLanguage),
    @views.button(text(t, "app.mode.design"), on_click=SetMode(ModeDesign)),
    @views.button(text(t, "app.mode.blocks"), on_click=SetMode(ModeBlocks)),
    @views.button(text(t, "app.mode.code"), on_click=SetMode(ModeCode)),
    @views.button(text(t, "app.templates.hello"), on_click=SelectTemplate(0)),
    @views.button(
      text(t, "app.templates.roll_call"),
      on_click=SelectTemplate(1),
    ),
    @views.button(text(t, "app.templates.drill"), on_click=SelectTemplate(2)),
    @views.button(text(t, "app.templates.store"), on_click=SelectTemplate(3)),
    @views.button(text(t, "app.file.save"), on_click=SaveRequested),
    @views.button(text(t, "app.file.open"), on_click=OpenRequested),
    @views.button(text(t, "app.file.export"), on_click=ExportRequested),
    @views.button(
      if model.run is Some(_) {
        text(t, "app.run.stop")
      } else {
        text(t, "app.run.start")
      },
      on_click=if model.run is Some(_) { RunStop } else { RunStart },
    ),
  ])
}

///|
/// 左栏：控件面板（设计模式）+ 事件子程序列表（全部模式可用）。
fn left_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let palette : Array[@moui.View[Msg]] = [@views.text(text(t, "app.palette"))]
  for
    kind in [
      @ir.Button,
      @ir.Label,
      @ir.TextField,
      @ir.CheckBox,
      @ir.ListBox,
      @ir.Table,
    ] {
    palette.push(
      @views.button(text(t, "control.\{kind.tag()}"), on_click=AddControl(kind)),
    )
  }
  let handlers : Array[@moui.View[Msg]] = [@views.text(text(t, "app.handlers"))]
  for handler in model.program.handlers {
    let key = handler_key(handler.control_name, handler.event.tag())
    handlers.push(@views.button(key, on_click=SelectHandler(key)))
  }
  let palette_items : Array[@moui.View[Msg]] = []
  for item in palette {
    palette_items.push(item)
  }
  for item in handlers {
    palette_items.push(item)
  }
  @views.scroll_view(@views.column(palette_items), width=180.0, height=560.0)
}

///|
/// 中部：按模式切换（设计画布 / 积木链 / 代码编辑器）。
fn center_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.mode {
    ModeDesign => design_canvas(model.program, model.selected_control)
    ModeBlocks => blocks_panel(model, t)
    ModeCode => code_panel(model, t)
    ModeRun => run_form(model, t)
  }
}

///|
/// 积木视图：IR 语句的 Scratch 式投影 + 编辑回写。
/// 点块选中 → 下方编辑器改这一条语句（DSL）→ 应用即写回 IR，
/// 代码视图/设计视图随之刷新；运行中按审计细节高亮当前块。
fn blocks_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match current_handler(model) {
    None => @views.text(text(t, "app.handler.none"))
    Some(handler) => {
      let spotlight = current_spotlight(model)
      let rows : Array[@moui.View[Msg]] = [
        @views.text(
          "\{text(t, "blocks.event")}：\{handler.control_name} . \{handler.event.tag()}",
        ),
      ]
      let blocks = @blocks.block_chain(handler.body)
      let mut index = 0
      for item in blocks {
        let label = text(t, @blocks.block_label_key(item.kind))
        let text_part = if item.text == "" {
          label
        } else {
          "\{label}  \{item.text}"
        }
        let indent = repeat_spaces(item.depth)
        let highlighted = item.text != "" && item.text == spotlight
        let marker = if highlighted { "▶ " } else { "" }
        let selected = index == model.selected_block
        let row_text = if selected {
          "\{marker}\{indent}【\{text_part}】"
        } else {
          "\{marker}\{indent}\{text_part}"
        }
        if item.path.length() > 0 {
          let row_index = index
          rows.push(@views.button(row_text, on_click=SelectBlock(row_index)))
        } else {
          rows.push(@views.text(row_text))
        }
        index = index + 1
      }
      let editor : Array[@moui.View[Msg]] = []
      if model.selected_block >= 0 && model.selected_block < blocks.length() {
        editor.push(
          @views.text_area(
            model.block_draft,
            on_input=source => EditBlock(source),
            lines=4,
            width=440.0,
          ),
        )
        editor.push(
          @views.row([
            @views.button(text(t, "app.block.apply"), on_click=CommitBlock),
            @views.button(text(t, "app.block.delete"), on_click=DeleteBlock),
          ]),
        )
      }
      let panel : Array[@moui.View[Msg]] = []
      for row in rows {
        panel.push(row)
      }
      for item_view in editor {
        panel.push(item_view)
      }
      @views.scroll_view(@views.column(panel), width=480.0, height=560.0)
    }
  }
}

///|
/// 当前聚光灯文本：最后一条命令/赋值审计的规范细节。
fn current_spotlight(model : Model) -> String {
  match model.run {
    None => ""
    Some(run) => {
      let mut spotlight = ""
      for record in run.state.audit {
        if record.op is @momao_lang.OpAssign ||
          record.op is @momao_lang.OpMessage ||
          record.op is @momao_lang.OpCommand ||
          record.op is @momao_lang.OpGate {
          spotlight = record.detail
        }
      }
      spotlight
    }
  }
}

///|
/// 代码视图：当前子程序的双语源码 + 实时错误 + 速查表。
fn code_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let error_line = if model.code_error == "" {
    @views.text("")
  } else {
    @views.text("\{text(t, "app.code.error")}：\{model.code_error}")
  }
  @views.column([
    @views.text(text(t, "app.code.title")),
    @views.text_area(
      model.code_draft,
      on_input=source => EditCode(source),
      placeholder=text(t, "app.code.cheatsheet"),
      lines=18,
      width=460.0,
    ),
    error_line,
  ])
}

///|
/// 运行视图：真实渲染程序窗体 + 闸门卡 + 审计 + 变量。
fn run_form(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.run {
    None => @views.text("")
    Some(run) => {
      let texts = run.state.texts
      let controls : Array[@moui.View[Msg]] = []
      for control in model.program.controls {
        let value = texts.get(control.name).unwrap_or(control.text)
        let widget = match control.kind {
          @ir.Label => @views.text(value)
          @ir.Button =>
            @views.button(value, on_click=ControlClicked(control.name))
          @ir.TextField =>
            @views.text_field(
              value,
              on_input=new_value => ControlChanged(control.name, new_value),
              width=control.width.to_double(),
            )
          @ir.CheckBox => @views.text("[ ] \{value}")
          @ir.ListBox | @ir.Table => {
            let rows : Array[@moui.View[Msg]] = []
            for item in run.state.rows.get(control.name).unwrap_or([]) {
              rows.push(@views.text("· \{item}"))
            }
            @views.column(rows)
          }
        }
        controls.push(widget)
      }
      let head : Array[@moui.View[Msg]] = [
        @views.text("\{run.handler_label}"),
        @views.column(controls),
      ]
      // 闸门卡：确认前零真实动作
      let gate_card : Array[@moui.View[Msg]] = []
      match run.state.gate {
        Some(gate) => {
          let prompt = match gate.kind {
            @momao_lang.Submit =>
              text_with(t, "app.run.gate.submit", [
                ("target", gate.prompt),
                ("payload", gate.payload),
              ])
            @momao_lang.Ask =>
              text_with(t, "app.run.gate.ask", [("prompt", gate.prompt)])
          }
          gate_card.push(
            @views.column([
              @views.text(prompt),
              @views.button(
                text(t, "app.run.gate.confirm"),
                on_click=AnswerGate(true),
              ),
              @views.button(
                text(t, "app.run.gate.reject"),
                on_click=AnswerGate(false),
              ),
            ]),
          )
        }
        None => ()
      }
      // 消息
      let messages_card : Array[@moui.View[Msg]] = []
      if run.state.messages.length() > 0 {
        let messages : Array[@moui.View[Msg]] = [
          @views.text(text(t, "app.run.messages")),
        ]
        for message in run.state.messages {
          messages.push(@views.text(message))
        }
        messages_card.push(@views.column(messages))
      }
      // 审计
      let audit : Array[@moui.View[Msg]] = [
        @views.text(text(t, "app.run.audit")),
      ]
      for record in run.state.audit {
        let op = match record.op {
          @momao_lang.OpAssign => "op.assign"
          @momao_lang.OpMessage => "op.message"
          @momao_lang.OpGate => "op.gate"
          @momao_lang.OpCommand => "op.command"
          @momao_lang.OpCondition => "op.condition"
          @momao_lang.OpLoop => "op.loop"
        }
        audit.push(@views.text("\{text(t, op)}  \{record.detail}"))
      }
      let error_card : Array[@moui.View[Msg]] = []
      match run.state.error {
        Some(error) => error_card.push(@views.text(error_message(t, error)))
        None => ()
      }
      let panel : Array[@moui.View[Msg]] = []
      for item in head {
        panel.push(item)
      }
      for item in gate_card {
        panel.push(item)
      }
      for item in messages_card {
        panel.push(item)
      }
      panel.push(
        @views.scroll_view(@views.column(audit), width=460.0, height=180.0),
      )
      for item in error_card {
        panel.push(item)
      }
      @views.scroll_view(@views.column(panel), width=480.0, height=560.0)
    }
  }
}

///|
/// 右栏：属性检查器（设计模式）+ AI 提案面板。
fn right_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let inspector = inspector_panel(model, t)
  let ai = ai_panel(model, t)
  @views.scroll_view(
    @views.column([inspector, @views.divider(), ai]),
    width=300.0,
    height=560.0,
  )
}

///|
/// 属性检查器：名称 / 文本 / 选项 / 删除。
fn inspector_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match find_selected_control(model) {
    None => @views.text(text(t, "app.inspector.none"))
    Some(control) =>
      @views.column([
        @views.text(text(t, "app.inspector")),
        @views.text(text(t, "app.inspector.name")),
        @views.text_field(
          control.name,
          on_input=new_value => SetControlName(control.name, new_value),
          width=240.0,
        ),
        @views.text(text(t, "app.inspector.text")),
        @views.text_field(
          control.text,
          on_input=new_value => SetControlText(control.name, new_value),
          width=240.0,
        ),
        @views.text(text(t, "app.inspector.position")),
        @views.row([
          @views.text_field(
            control.x.to_string(),
            on_input=raw => SetControlRect(control.name, @ir.RectX, raw),
            width=70.0,
          ),
          @views.text_field(
            control.y.to_string(),
            on_input=raw => SetControlRect(control.name, @ir.RectY, raw),
            width=70.0,
          ),
        ]),
        @views.text(text(t, "app.inspector.size")),
        @views.row([
          @views.text_field(
            control.width.to_string(),
            on_input=raw => SetControlRect(control.name, @ir.RectWidth, raw),
            width=70.0,
          ),
          @views.text_field(
            control.height.to_string(),
            on_input=raw => SetControlRect(control.name, @ir.RectHeight, raw),
            width=70.0,
          ),
        ]),
        if control.kind is @ir.ListBox || control.kind is @ir.Table {
          @views.column([
            @views.text(text(t, "app.inspector.items")),
            @views.text_area(
              join_lines(control.items),
              on_input=new_value => SetControlItems(control.name, new_value),
              lines=4,
              width=240.0,
            ),
          ])
        } else {
          @views.text("")
        },
        @views.button(
          text(t, "app.inspector.delete"),
          on_click=DeleteControl(control.name),
        ),
      ])
  }
}

///|
fn find_selected_control(model : Model) -> @ir.Control? {
  if model.selected_control == "" {
    None
  } else {
    @ir.find_control(model.program, model.selected_control)
  }
}

///|
/// AI 面板：prompt + 生成 + 提案 diff 预览 + 采纳/拒绝 + provider 设置。
fn ai_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let head : Array[@moui.View[Msg]] = [
    @views.text(text(t, "app.ai.title")),
    @views.text_field(
      model.prompt_draft,
      on_input=value => SetPrompt(value),
      placeholder=text(t, "app.ai.prompt"),
      width=260.0,
    ),
    @views.button(text(t, "app.ai.generate"), on_click=GenerateProposal),
    @views.button(text(t, "app.ai.explain"), on_click=ExplainHandler),
  ]
  let prompt_error_card : Array[@moui.View[Msg]] = []
  if model.prompt_error != "" {
    prompt_error_card.push(@views.text(model.prompt_error))
  }
  // 待采纳提案
  let proposal_card : Array[@moui.View[Msg]] = []
  match model.pending {
    None => ()
    Some(pending) => {
      proposal_card.push(
        @views.text("\{text(t, "app.ai.reason")}：\{pending.summary}"),
      )
      let entries : Array[@moui.View[Msg]] = [
        @views.text(text(t, "app.ai.diff.title")),
      ]
      for entry in pending.diff {
        let op = match entry.op {
          @proposals.Added => "diff.added"
          @proposals.Changed => "diff.changed"
          @proposals.Removed => "diff.removed"
        }
        entries.push(
          @views.text(
            "\{text(t, op)} \{entry.path}：\{entry.old_text} → \{entry.new_text}",
          ),
        )
      }
      proposal_card.push(
        @views.scroll_view(@views.column(entries), width=260.0, height=140.0),
      )
      if !pending.valid {
        for error in pending.errors {
          proposal_card.push(@views.text(error))
        }
      }
      proposal_card.push(
        @views.row([
          @views.button(text(t, "app.ai.accept"), on_click=AcceptProposal),
          @views.button(text(t, "app.ai.reject"), on_click=RejectProposal),
        ]),
      )
    }
  }
  // 讲解
  let explanation_card : Array[@moui.View[Msg]] = []
  if model.explanation != "" {
    explanation_card.push(@views.text(text(t, "app.ai.explanation")))
    explanation_card.push(@views.text(model.explanation))
  }
  // provider 设置（key 只进会话内存）
  let provider_card : Array[@moui.View[Msg]] = [
    @views.text(
      if model.provider_mode is Fake {
        text(t, "app.ai.fake")
      } else {
        text(t, "app.ai.real")
      },
    ),
    @views.button(text(t, "app.ai.fake"), on_click=SetProviderMode(Fake)),
    @views.button(text(t, "app.ai.real"), on_click=SetProviderMode(Real)),
    @views.text_field(
      model.provider_endpoint,
      on_input=value => SetProviderEndpoint(value),
      placeholder=text(t, "app.ai.endpoint"),
      width=260.0,
    ),
    @views.text_field(
      model.provider_model,
      on_input=value => SetProviderModel(value),
      placeholder=text(t, "app.ai.model"),
      width=260.0,
    ),
    @views.text_field(
      model.provider_key,
      on_input=value => SetProviderKey(value),
      placeholder=text(t, "app.ai.key"),
      width=260.0,
    ),
  ]
  let panel : Array[@moui.View[Msg]] = []
  for item in head {
    panel.push(item)
  }
  for item in prompt_error_card {
    panel.push(item)
  }
  for item in proposal_card {
    panel.push(item)
  }
  for item in explanation_card {
    panel.push(item)
  }
  for item in provider_card {
    panel.push(item)
  }
  @views.column(panel)
}

///|
/// 顶层组合。
pub fn view(model : Model) -> @moui.View[Msg] {
  let t = translator(model)
  @views.column([
    top_bar(model, t),
    @views.divider(),
    @views.row([
      left_panel(model, t),
      @views.divider(),
      center_panel(model, t),
      @views.divider(),
      right_panel(model, t),
    ]),
    @views.text(model.notice),
  ])
}

///|
/// 行拼接（Array::join 不可用，显式拼接）。
fn join_lines(items : Array[String]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for item in items {
    if !first {
      buf.write_string("\n")
    }
    buf.write_string(item)
    first = false
  }
  buf.to_string()
}

///|
/// 缩进空格（String 无重复运算）。
fn repeat_spaces(depth : Int) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < depth {
    buf.write_string("  ")
    i = i + 1
  }
  buf.to_string()
}
