///|
/// MoMao Studio 视图层：顶栏 + 左栏（控件/子程序）+ 中部（三模式）+
/// 右栏（属性 / AI 提案）+ 运行区。全部文案过 i18n 翻译器。

///|
/// 顶栏（两行，带内边距——单行 13 个按钮会在 1280 宽窗口溢出裁切）：
/// 第一行 = 标题（Title）+ 模式 tab（button_group 选中态）+ 运行 + 语言；
/// 第二行 = 模板（Tonal）+ 文件操作（Outline + 图标）。
fn top_bar(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let mode_items = [
    @views.action_item(
      id="design",
      label=text(t, "app.mode.design"),
      message=SetMode(ModeDesign),
    ),
    @views.action_item(
      id="blocks",
      label=text(t, "app.mode.blocks"),
      message=SetMode(ModeBlocks),
    ),
    @views.action_item(
      id="code",
      label=text(t, "app.mode.code"),
      message=SetMode(ModeCode),
    ),
    @views.action_item(
      id="preview",
      label=text(t, "app.mode.preview"),
      message=SetMode(ModePreview),
    ),
  ]
  let selected_mode = match model.mode {
    ModeDesign => "design"
    ModeBlocks => "blocks"
    ModeCode => "code"
    ModePreview => "preview"
    ModeHelp => ""
    ModeRun => ""
  }
  @views.container(
    @views.column([
      @views.row([
        @views.text(text(t, "app.title"), role=Title),
        @views.button_group(mode_items, selected=selected_mode),
        @views.button(
          if model.run is Some(_) {
            text(t, "app.run.stop")
          } else {
            text(t, "app.run.start")
          },
          on_click=if model.run is Some(_) { RunStop } else { RunStart },
          variant=if model.run is Some(_) { Outline } else { Primary },
        ),
        @views.button(
          text(t, "app.lang.switch"),
          on_click=SwitchLanguage,
          variant=Ghost,
        ),
        @views.button(
          text(t, "app.help.title"),
          on_click=SetMode(ModeHelp),
          variant=Ghost,
        ),
      ]),
      @views.row([
        @views.button(text(t, "app.edit.undo"), on_click=Undo, variant=Ghost),
        @views.button(text(t, "app.edit.redo"), on_click=Redo, variant=Ghost),
        @views.button(
          text(t, "app.templates.hello"),
          on_click=SelectTemplate(0),
          variant=Tonal,
        ),
        @views.button(
          text(t, "app.templates.roll_call"),
          on_click=SelectTemplate(1),
          variant=Tonal,
        ),
        @views.button(
          text(t, "app.templates.drill"),
          on_click=SelectTemplate(2),
          variant=Tonal,
        ),
        @views.button(
          text(t, "app.templates.store"),
          on_click=SelectTemplate(3),
          variant=Tonal,
        ),
        @views.button(
          text(t, "app.file.save"),
          on_click=SaveRequested,
          variant=Outline,
          icon=Some(Save),
        ),
        @views.button(
          text(t, "app.file.open"),
          on_click=OpenRequested,
          variant=Outline,
          icon=Some(FolderOpen),
        ),
        @views.button(
          text(t, "app.file.export"),
          on_click=ExportRequested,
          variant=Outline,
          icon=Some(FileNew),
        ),
      ]),
    ]),
    padding=10.0,
  )
}

///|
/// 左栏：控件面板（设计模式）+ 事件子程序列表（全部模式可用）。
fn left_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let palette : Array[@moui.View[Msg]] = [
    @views.text(text(t, "app.palette"), role=Subtitle),
  ]
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
      @views.button(
        text(t, "control.\{kind.tag()}"),
        on_click=AddControl(kind),
        variant=Tonal,
      ),
    )
  }
  let handlers : Array[@moui.View[Msg]] = [
    @views.text(text(t, "app.handlers"), role=Subtitle),
  ]
  for handler in model.program.handlers {
    let key = handler_key(handler.control_name, handler.event.tag())
    handlers.push(@views.button(key, on_click=SelectHandler(key)))
  }
  // 新建子程序入口：选中控件支持、但尚无 handler 的事件，点击即建空子程序
  match find_selected_control(model) {
    None => ()
    Some(control) => {
      let missing : Array[@moui.View[Msg]] = []
      for event in control_events(control) {
        if @ir.find_handler(model.program, control.name, event) is None {
          missing.push(
            @views.button(
              "＋ \{control.name} · \{text(t, "event.\{event.tag()}")}",
              on_click=CreateHandler(control.name, event),
              variant=Tonal,
            ),
          )
        }
      }
      if missing.length() > 0 {
        handlers.push(@views.text(text(t, "app.handler.new"), role=Subtitle))
        for item in missing {
          handlers.push(item)
        }
      }
    }
  }
  let palette_items : Array[@moui.View[Msg]] = []
  for item in palette {
    palette_items.push(item)
  }
  for item in handlers {
    palette_items.push(item)
  }
  // 卡片化 + 内边距：面板不贴窗口边缘，按钮有呼吸距离
  @views.card(
    @views.scroll_view(
      @views.column(palette_items),
      width=158.0,
      height=532.0,
      shows_indicator=true,
    ),
    width=180.0,
    height=560.0,
    padding=10.0,
  )
}

///|
/// 中部：按模式切换（设计画布 / 积木链 / 代码编辑器）。
fn center_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.mode {
    ModeDesign =>
      design_canvas(
        model.program,
        model.selected_control,
        match model.drag {
          Some(drag) => Some(drag.control)
          None => None
        },
        // 可读文案过翻译器：画布语义标签不烤进画布实现
        text(t, "app.design.canvas"),
      )
    ModeBlocks => blocks_panel(model, t)
    ModeCode => code_panel(model, t)
    ModePreview => preview_panel(model, t)
    ModeHelp => help_panel(model, t)
    ModeRun => run_form(model, t)
  }
}

///|
/// 积木分类底色：与设计画布的控件色系呼应——存值蓝 / 分支橙 /
/// 循环绿 / 跳出红 / 调用紫（浅阶 tint，深色文字可读）。
fn block_fill(kind : @blocks.BlockKind) -> @graphics.Color {
  match kind {
    @blocks.BkDeclare | @blocks.BkAssign =>
      @graphics.Color::rgba(r=0.90, g=0.93, b=0.99)
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkEnd =>
      @graphics.Color::rgba(r=0.99, g=0.94, b=0.86)
    @blocks.BkCountLoop | @blocks.BkWhile =>
      @graphics.Color::rgba(r=0.89, g=0.96, b=0.90)
    @blocks.BkBreak => @graphics.Color::rgba(r=0.99, g=0.90, b=0.89)
    @blocks.BkCall => @graphics.Color::rgba(r=0.95, g=0.92, b=0.99)
  }
}

///|
/// 积木品牌描边（选中态）——朱砂色，与主题主色一致。
fn block_selected_border() -> @graphics.BorderStyle {
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(@graphics.Color::rgba(r=0.78, g=0.26, b=0.20)),
    width=2.0,
  )
}

///|
/// 单块视觉：分类底色圆角块 + 深度缩进；可编辑块挂 tap 选中。
fn block_row_view(
  item : @blocks.BlockItem,
  marker : String,
  label : String,
  selected : Bool,
  row_index : Int,
) -> @moui.View[Msg] {
  let block = @views.container(
    @views.text("\{marker}\{label}", width=380.0),
    background=block_fill(item.kind),
    corner_radius=6.0,
    border=if selected { Some(block_selected_border()) } else { None },
    padding=6.0,
    width=400.0,
  )
  let indented = if item.depth > 0 {
    @views.padding_edges(block, left=item.depth.to_double() * 18.0)
  } else {
    block
  }
  if item.path.length() > 0 {
    indented.on_tap(SelectBlock(row_index))
  } else {
    indented
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
          role=Subtitle,
        ),
      ]
      let blocks = @blocks.block_chain(handler.body)
      let mut index = 0
      for item in blocks {
        let label = if item.text == "" {
          text(t, @blocks.block_label_key(item.kind))
        } else {
          "\{text(t, @blocks.block_label_key(item.kind))}  \{item.text}"
        }
        let highlighted = item.text != "" && item.text == spotlight
        let marker = if highlighted { "▶ " } else { "" }
        let selected = index == model.selected_block
        let row_index = index
        rows.push(block_row_view(item, marker, label, selected, row_index))
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
            @views.button(
              text(t, "app.block.apply"),
              on_click=CommitBlock,
              variant=Primary,
            ),
            @views.button(
              text(t, "app.block.delete"),
              on_click=DeleteBlock,
              variant=Outline,
            ),
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
      @views.scroll_view(
        @views.column(panel),
        width=480.0,
        height=560.0,
        shows_indicator=true,
      )
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
    @views.inline_error(
      "\{text(t, "app.code.error")}：\{model.code_error}",
      width=440.0,
    )
  }
  @views.column([
    @views.text(text(t, "app.code.title"), role=Subtitle),
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
/// MoonBit 预览视图：把当前程序渲染成可读 MoonBit 源码（毕业通道 v1.1）。
/// 只读展示——生成的文本是审阅材料，不是编辑器输入。
fn preview_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let source = @export.moonbit_preview(model.program)
  let lines : Array[@moui.View[Msg]] = [
    @views.text(text(t, "app.preview.title"), role=Subtitle),
    @views.text(text(t, "app.preview.note"), role=Caption),
  ]
  for line in source.split("\n") {
    lines.push(@views.text(line.to_string(), width=460.0, align=TextStart))
  }
  @views.scroll_view(
    @views.column(lines),
    width=480.0,
    height=560.0,
    shows_indicator=true,
  )
}

///|
/// 帮助视图：DSL 双语速查表——**从关键字表与内建目录数据生成**，
/// 不手抄第二份（关键字表改了，帮助页自动跟随）。
fn help_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let zh = @momao_lang.keywords_for(@momao_lang.ZhHans)
  let en = @momao_lang.keywords_for(@momao_lang.En)
  let rows : Array[@moui.View[Msg]] = [
    @views.text(text(t, "app.help.title"), role=Title),
    @views.text(text(t, "app.help.intro"), role=Caption),
    @views.text(text(t, "app.help.keywords"), role=Subtitle),
  ]
  // (概念, 中文写法, 英文写法)
  let keyword_rows : Array[(String, String, String)] = [
    (
      text(t, "blocks.declare"),
      "\{zh.declare_kw} x = 1",
      "\{en.declare_kw} x = 1",
    ),
    (
      text(t, "blocks.if"),
      "\{zh.if_kw} c \{zh.then_kw} … \{zh.else_kw} … \{zh.end_kw}",
      "\{en.if_kw} c \{en.then_kw} … \{en.else_kw} … \{en.end_kw}",
    ),
    (
      text(t, "blocks.else_if"),
      "\{zh.else_if_kw} c \{zh.then_kw} …",
      "\{en.else_if_kw} c \{en.then_kw} …",
    ),
    (
      text(t, "blocks.count_loop"),
      "\{zh.count_kw} 5 \{zh.times_kw} [\{zh.as_kw} i] … \{zh.end_kw}",
      "\{en.count_kw} 5 \{en.times_kw} [\{en.as_kw} i] … \{en.end_kw}",
    ),
    (
      text(t, "blocks.while"),
      "\{zh.while_kw} c \{zh.do_kw} … \{zh.end_kw}",
      "\{en.while_kw} c \{en.do_kw} … \{en.end_kw}",
    ),
    (text(t, "blocks.break"), zh.break_kw, en.break_kw),
    (
      text(t, "app.help.logic"),
      "\{zh.and_kw} \{zh.or_kw} \{zh.not_kw}",
      "\{en.and_kw} \{en.or_kw} \{en.not_kw}",
    ),
    (
      text(t, "app.help.literals"),
      "\{zh.true_kw} / \{zh.false_kw}",
      "\{en.true_kw} / \{en.false_kw}",
    ),
  ]
  for row in keyword_rows {
    let (label, zh_text, en_text) = row
    rows.push(
      @views.row([
        @views.text(label, width=90.0),
        @views.text(zh_text, width=200.0),
        @views.text(en_text, width=170.0),
      ]),
    )
  }
  rows.push(@views.text(text(t, "app.help.builtins"), role=Subtitle))
  let kind_label = fn(kind : @momao_lang.BuiltinKind) -> String {
    match kind {
      @momao_lang.Command => text(t, "app.help.commands")
      @momao_lang.Function => text(t, "app.help.functions")
      @momao_lang.Gate => text(t, "app.help.gates")
    }
  }
  for spec in @momao_lang.builtin_catalog() {
    rows.push(
      @views.row([
        @views.text(kind_label(spec.kind), width=60.0),
        @views.text("\{spec.zh}", width=100.0),
        @views.text("\{spec.en}", width=120.0),
        @views.text("\{spec.arity}", width=30.0),
      ]),
    )
  }
  @views.scroll_view(
    @views.column(rows),
    width=480.0,
    height=560.0,
    shows_indicator=true,
  )
}

///|
/// 审计时间线色点：操作类型 → 语义色（赋值蓝 / 信息框绿 / 闸门朱砂 /
/// 命令紫 / 条件橙 / 循环青）。
fn audit_dot_color(op : @momao_lang.StepOp) -> @graphics.Color {
  match op {
    @momao_lang.OpAssign => @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
    @momao_lang.OpMessage => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    @momao_lang.OpGate => @graphics.Color::rgba(r=0.78, g=0.26, b=0.20)
    @momao_lang.OpCommand => @graphics.Color::rgba(r=0.55, g=0.40, b=0.75)
    @momao_lang.OpCondition => @graphics.Color::rgba(r=0.85, g=0.55, b=0.16)
    @momao_lang.OpLoop => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
  }
}

///|
/// 运行视图：真实渲染程序窗体（窗体框舞台）+ 闸门确认卡 + 审计时间线。
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
          @ir.CheckBox =>
            // 真勾选控件：勾选态在 app 层 RunModel.checks（指令机语义外）
            @views.checkbox(
              value,
              checked=run.checks.get(control.name).unwrap_or(false),
              on_change=checked => RunToggle(control.name, checked),
            )
          @ir.ListBox | @ir.Table => {
            let rows : Array[@moui.View[Msg]] = []
            let mut row_index = 0
            for item in run.state.rows.get(control.name).unwrap_or([]) {
              let row = if row_index % 2 == 0 {
                @views.container(
                  @views.text(item, width=140.0),
                  background=@graphics.Color::rgba(r=0.957, g=0.957, b=0.961),
                  corner_radius=4.0,
                  padding=2.0,
                  width=160.0,
                )
              } else {
                @views.text(item, width=160.0)
              }
              rows.push(row)
              row_index = row_index + 1
            }
            @views.column(rows)
          }
        }
        controls.push(widget)
      }
      // 舞台条两行：标题行（正在运行 + 子程序）+ 按钮行（单步/继续/停止）。
      // 单行挤 436px 会把继续/停止裁掉（实测）；按钮仅在运行中显示，
      // 闸门待确认时追加 Warning 徽标提醒（确认卡可能滚出视野）。
      let stage_head = @views.column([
        @views.row([
          @views.text(text(t, "app.run.stage"), role=Caption),
          @views.text("\{run.handler_label}", role=Subtitle),
        ]),
        @views.row([
          // 单步/继续在活运行（含闸门暂停）时显示——闸门暂停正是
          // 「单步冻结计时器再确认」教学手法的入口
          match run.state.status {
            @momao_lang.Completed | @momao_lang.Failed => @views.text("")
            _ =>
              @views.button(
                text(t, "app.run.step"),
                on_click=RunStep,
                variant=Outline,
              )
          },
          match run.state.status {
            @momao_lang.Completed | @momao_lang.Failed => @views.text("")
            _ =>
              @views.button(
                text(t, "app.run.resume"),
                on_click=RunResume,
                variant=Outline,
              )
          },
          match run.state.gate {
            Some(_) =>
              @views.badge(
                text(t, "app.run.gate_pending"),
                tone=@style.BadgeTone::Warning,
                width=64.0,
                height=24.0,
              )
            None => @views.text("")
          },
          @views.button(
            text(t, "app.run.stop"),
            on_click=RunStop,
            variant=Outline,
          ),
        ]),
      ])
      // 变量表：当前变量 → 值，按键名稳定排序（运行即讲解的数据面）
      let variables_card : Array[@moui.View[Msg]] = []
      let variable_names : Array[String] = []
      for name in run.state.vars.keys() {
        variable_names.push(name)
      }
      variable_names.sort()
      if variable_names.length() > 0 {
        variables_card.push(
          @views.text(text(t, "app.run.variables"), role=Subtitle),
        )
        for name in variable_names {
          match run.state.vars.get(name) {
            Some(value) =>
              variables_card.push(
                @views.row([
                  @views.text(name, width=120.0),
                  @views.text(@momao_lang.value_to_text(value), width=280.0),
                ]),
              )
            None => ()
          }
        }
      }
      let head : Array[@moui.View[Msg]] = [stage_head, @views.column(controls)]
      // 闸门卡：确认卡（Warning tone）+ 确认 Primary / 拒绝 Outline，
      // 确认前零真实动作
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
              @views.callout(
                text(t, "app.run.gate.title"),
                prompt,
                tone=@style.Warning,
                width=420.0,
              ),
              @views.row([
                @views.button(
                  text(t, "app.run.gate.confirm"),
                  on_click=AnswerGate(true),
                  variant=Primary,
                ),
                @views.button(
                  text(t, "app.run.gate.reject"),
                  on_click=AnswerGate(false),
                  variant=Outline,
                ),
              ]),
            ]),
          )
        }
        None => ()
      }
      // 消息
      let messages_card : Array[@moui.View[Msg]] = []
      if run.state.messages.length() > 0 {
        let messages : Array[@moui.View[Msg]] = [
          @views.text(text(t, "app.run.messages"), role=Subtitle),
        ]
        for message in run.state.messages {
          messages.push(@views.text(message))
        }
        messages_card.push(@views.column(messages))
      }
      // 审计时间线：操作类型色点 + 本地化操作名 + 规范细节
      let audit : Array[@moui.View[Msg]] = [
        @views.text(text(t, "app.run.audit"), role=Subtitle),
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
        let dot = @views.container(
          @views.empty(),
          background=audit_dot_color(record.op),
          corner_radius=4.0,
          width=8.0,
          height=8.0,
        )
        audit.push(
          @views.row([
            dot,
            @views.text("\{text(t, op)}  \{record.detail}", width=400.0),
          ]),
        )
      }
      let error_card : Array[@moui.View[Msg]] = []
      match run.state.error {
        Some(error) =>
          error_card.push(
            @views.inline_error(error_message(t, error), width=440.0),
          )
        None => ()
      }
      let panel : Array[@moui.View[Msg]] = []
      for item in head {
        panel.push(item)
      }
      for item in variables_card {
        panel.push(item)
      }
      for item in gate_card {
        panel.push(item)
      }
      for item in messages_card {
        panel.push(item)
      }
      panel.push(
        @views.scroll_view(
          @views.column(audit),
          width=460.0,
          height=180.0,
          shows_indicator=true,
        ),
      )
      for item in error_card {
        panel.push(item)
      }
      // 窗体框舞台：Raised 卡片承载整个运行区，与设计画布呼应
      @views.card(
        @views.scroll_view(
          @views.column(panel),
          width=436.0,
          height=532.0,
          shows_indicator=true,
        ),
        width=480.0,
        height=560.0,
        padding=10.0,
      )
    }
  }
}

///|
/// 右栏：属性检查器（设计模式）+ AI 提案面板。
fn right_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let inspector = inspector_panel(model, t)
  let ai = ai_panel(model, t)
  @views.card(
    @views.scroll_view(
      @views.container(
        @views.column([inspector, @views.divider(), ai]),
        padding=2.0,
      ),
      width=272.0,
      height=532.0,
      shows_indicator=true,
    ),
    width=300.0,
    height=560.0,
    padding=10.0,
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
        @views.row([
          @views.button(
            text(t, "app.inspector.duplicate"),
            on_click=DuplicateControl(control.name),
            variant=Outline,
          ),
          @views.button(
            text(t, "app.inspector.delete"),
            on_click=DeleteControl(control.name),
          ),
        ]),
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
    @views.text(text(t, "app.ai.title"), role=Subtitle),
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
    prompt_error_card.push(@views.inline_error(model.prompt_error, width=250.0))
  }
  // 真实 provider 请求进行中：加载态占位
  let busy_card : Array[@moui.View[Msg]] = []
  if model.ai_busy {
    busy_card.push(
      @views.loading_state(title=text(t, "app.ai.busy"), width=250.0),
    )
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
        @views.text(text(t, "app.ai.diff.title"), role=Caption),
      ]
      for entry in pending.diff {
        let op = match entry.op {
          @proposals.Added => "diff.added"
          @proposals.Changed => "diff.changed"
          @proposals.Removed => "diff.removed"
        }
        // 语义 tone 徽标：新增绿 / 修改强调 / 删除红，随主题解析
        let tone = match entry.op {
          @proposals.Added => @style.BadgeTone::Success
          @proposals.Changed => @style.BadgeTone::Accent
          @proposals.Removed => @style.BadgeTone::Danger
        }
        entries.push(
          @views.row([
            @views.badge(text(t, op), tone~, width=52.0, height=20.0),
            @views.text(
              "\{entry.path}：\{entry.old_text} → \{entry.new_text}",
              width=180.0,
            ),
          ]),
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
  for item in busy_card {
    panel.push(item)
  }
  for item in proposal_card {
    panel.push(item)
  }
  // 提案历史（会话内）：回放 AI 干了什么
  if model.proposal_history.length() > 0 {
    panel.push(@views.text(text(t, "app.ai.history"), role=Subtitle))
    for record in model.proposal_history {
      panel.push(
        @views.row([
          @views.badge(
            text(
              t,
              if record.accepted {
                "app.ai.hist_accepted"
              } else {
                "app.ai.hist_rejected"
              },
            ),
            tone=if record.accepted {
              @style.BadgeTone::Success
            } else {
              @style.BadgeTone::Danger
            },
            width=56.0,
            height=20.0,
          ),
          @views.text("\{record.seq}. \{record.summary}", width=180.0),
        ]),
      )
    }
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
      // 行内分隔线必须用 Vertical 轴：Horizontal divider 会测量成整行宽
      // （它按约束最大宽填充），把后面的画布与右栏全部挤出窗口。
      @views.divider(axis=Vertical),
      center_panel(model, t),
      @views.divider(axis=Vertical),
      right_panel(model, t),
    ]),
    @views.text(model.notice),
  ])
  // 固定浅色主题：课堂/路演场景要求确定的演示外观，不随系统深色模式漂移
  // （深色系统 + 浅色底板会出现白字白底）。
  .theme(momao_theme())
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
