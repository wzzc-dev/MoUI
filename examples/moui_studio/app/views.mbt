///|
/// MoUI Studio 视图层：顶栏 + 左栏（控件/子程序）+ 中部（三模式）+
/// 右栏（属性 / AI 提案）+ 运行区。全部文案过 i18n 翻译器。

///|
/// 顶栏（两行，带内边距——单行 14 个按钮会在 1280 宽窗口溢出裁切）：
/// 第一行 = 标题 + 模式 tab + 双轨切换 + 命令面板 + 运行 + 语言；
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
  // 双轨切换：解释轨（沙箱指令机）/ 编译轨（真编译闭包执行面）。
  // Web 端不隐藏事实——编译轨按钮照常显示，切过去弹「本端不可达」提示。
  let track_items = [
    @views.action_item(
      id="interpret",
      label=text(t, "app.track.interpret"),
      message=SetRunTrack(Interpret),
    ),
    @views.action_item(
      id="compile",
      label=text(t, "app.track.compile"),
      message=SetRunTrack(Compile),
    ),
  ]
  let selected_track = match current_track(model) {
    Interpret => "interpret"
    Compile => "compile"
  }
  let running = match current_track(model) {
    Interpret => model.run is Some(_)
    Compile => model.compiled_run is Some(_)
  }
  @views.container(
    @views.column(
      [
        // 品牌标记与标题保持稳定宽度；模式导航和运行操作各自成组，
        // 路演时先看到 MoUI Studio，再看到当前工作模式。标题后的 ● = 有未保存修改。
        @views.row(
          [
            @views.row(
              [
                @views.container(
                  @views.center(
                    @views.text("卯").foreground(@graphics.Color::white()),
                    width=30.0,
                    height=26.0,
                  ),
                  background=@graphics.Color::rgba(r=0.78, g=0.26, b=0.20),
                  corner_radius=8.0,
                  width=30.0,
                  height=26.0,
                  padding=0.0,
                ),
                @views.text(
                  text(t, "app.title") + (if model.dirty { " ●" } else { "" }),
                  role=Title,
                ),
              ],
              spacing=8.0,
            ),
            @views.button_group(mode_items, selected=selected_mode),
            @views.button_group(
              track_items,
              selected=selected_track,
              button_width=76.0,
              height=36.0,
            ),
            // 命令面板入口：技术风 IDE 的键盘优先通道（Ctrl/Cmd+K）。
            // 放首行轨道组之后：第二行撤销/重做徽标 + 模板 + 文件操作在
            // 1280 宽已贴满，再放 150px 入口会把「导出应用」挤出窗口。
            // 链式追加 Cmd 变体：shortcut modifier 按修饰键精确匹配。
            @views.button(
              text(t, "app.command.open"),
              on_click=CommandPaletteOpen,
              variant=Ghost,
              width=140.0,
              height=40.0,
            )
            .keyboard_shortcut(
              @core.KeyboardShortcut::new(
                key="k",
                modifiers=@core.KeyModifiers::new(control=true),
              ),
            )
            .keyboard_shortcut(
              @core.KeyboardShortcut::new(
                key="k",
                modifiers=@core.KeyModifiers::new(meta=true),
              ),
            ),
            @views.button(
              if running {
                text(t, "app.run.stop")
              } else {
                text(t, "app.run.start")
              },
              on_click=if running { RunStop } else { RunStart },
              variant=if running { Outline } else { Primary },
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
          ],
          spacing=10.0,
        ),
        // 单行工具栏：撤销/重做 + 模板 + 文件操作合并（原第三行整行省下，
        // 把垂直空间还给主区）。固定 12pt 弹性隔离块分组；不用竖直 divider
        // ——它按可用高度测量，会把行撑到窗口高。
        @views.row(
          [
            // 快捷键 chip 里的 mono 16px 文案是宽度大头：Ctrl+Shift+Z 实测
            // ~116px，chip 宽度必须 ≥ 文案+内边距，否则文字被左右裁切。
            // 撤销/重做带键盘快捷键（Ctrl+Z / Ctrl+Shift+Z，链式追加 Cmd 变体
            // 兼容 macOS——shortcut modifier 按修饰键精确匹配，需各注册一份）
            @views.shortcut_button(
              text(t, "app.edit.undo"),
              on_click=Undo,
              shortcut=@core.KeyboardShortcut::new(
                key="z",
                modifiers=@core.KeyModifiers::new(control=true),
              ),
              variant=Ghost,
              width=160.0,
              height=40.0,
              shortcut_width=84.0,
            ).keyboard_shortcut(
              @core.KeyboardShortcut::new(
                key="z",
                modifiers=@core.KeyModifiers::new(meta=true),
              ),
            ),
            @views.shortcut_button(
              text(t, "app.edit.redo"),
              on_click=Redo,
              shortcut=@core.KeyboardShortcut::new(
                key="z",
                modifiers=@core.KeyModifiers::new(control=true, shift=true),
              ),
              variant=Ghost,
              width=216.0,
              height=40.0,
              shortcut_width=140.0,
            ).keyboard_shortcut(
              @core.KeyboardShortcut::new(
                key="z",
                modifiers=@core.KeyModifiers::new(meta=true, shift=true),
              ),
            ),
            @views.spacer(min_length=12.0, weight=0.0),
            @views.button(
              text(t, "app.templates.hello"),
              on_click=SelectTemplate(0),
              variant=Tonal,
              height=40.0,
            ),
            @views.button(
              text(t, "app.templates.roll_call"),
              on_click=SelectTemplate(1),
              variant=Tonal,
              height=40.0,
            ),
            @views.button(
              text(t, "app.templates.drill"),
              on_click=SelectTemplate(2),
              variant=Tonal,
              height=40.0,
            ),
            @views.button(
              text(t, "app.templates.store"),
              on_click=SelectTemplate(3),
              variant=Tonal,
              height=40.0,
            ),
            @views.spacer(min_length=12.0, weight=0.0),
            @views.button(
              text(t, "app.file.save"),
              on_click=SaveRequested,
              variant=Outline,
              icon=Some(Save),
              width=90.0,
              height=40.0,
            ),
            @views.button(
              text(t, "app.file.open"),
              on_click=OpenRequested,
              variant=Outline,
              icon=Some(FolderOpen),
              width=90.0,
              height=40.0,
            ),
            @views.button(
              text(t, "app.file.export"),
              on_click=ExportRequested,
              variant=Outline,
              icon=Some(FileNew),
              width=120.0,
              height=40.0,
            ),
          ],
          spacing=6.0,
        ),
      ],
      spacing=8.0,
    ),
    padding=10.0,
  )
}

///|
/// 左栏：控件面板（仅设计模式——放控件是画布动作，积木/代码编辑的是
/// 已选子程序，显示添加入口只会误导）+ 事件子程序列表（全部模式可用，
/// 积木/代码靠它切换要编辑的子程序）。
fn left_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  // 分节标题文字必须给显式宽度：text 默认宽 160，加上徽章会把滚动内容
  // 撑过内容预算（224 卡片 − 2×10 内垫 = 184），按钮跟拉伸后会被指示器
  // 压住。140 = 184 内容宽 − 徽章 28 − 间距 10 − 6 余量（英文
  // "Event handlers" 也放得下）。
  // align=TextStart：text 默认在盒内居中，标题会悬在中间偏左，与下方按钮错位。
  let palette : Array[@moui.View[Msg]] = []
  if model.mode is ModeDesign {
    palette.push(
      @views.row(
        [
          @views.text(
            text(t, "app.palette"),
            role=Subtitle,
            width=140.0,
            align=TextStart,
          ),
          @views.badge(
            theme=studio_theme(),
            model.program.controls.length().to_string(),
            tone=@style.BadgeTone::Neutral,
            width=28.0,
            height=20.0,
          ),
        ],
        justify=Between,
      ),
    )
    // 控件两列网格：面板纵向预算省一半，事件子程序列表得以进入首屏
    let kinds = [
      @ir.Button,
      @ir.Label,
      @ir.TextField,
      @ir.CheckBox,
      @ir.ListBox,
      @ir.Table,
    ]
    let mut kind_index = 0
    while kind_index < kinds.length() {
      let cells : Array[@moui.View[Msg]] = []
      let mut cell = 0
      while cell < 2 && kind_index + cell < kinds.length() {
        cells.push(
          @views.button(
            text(t, "control.\{kinds[kind_index + cell].tag()}"),
            on_click=AddControl(kinds[kind_index + cell]),
            variant=Tonal,
            width=84.0,
          ),
        )
        cell = cell + 1
      }
      palette.push(@views.row(cells, spacing=8.0))
      kind_index = kind_index + 2
    }
  }
  let handlers : Array[@moui.View[Msg]] = [
    @views.divider(),
    @views.row(
      [
        @views.text(
          text(t, "app.handlers"),
          role=Subtitle,
          width=140.0,
          align=TextStart,
        ),
        @views.badge(
          theme=studio_theme(),
          model.program.handlers.length().to_string(),
          tone=@style.BadgeTone::Neutral,
          width=28.0,
          height=20.0,
        ),
      ],
      justify=Between,
    ),
  ]
  for handler in model.program.handlers {
    let key = handler_key(handler.control_name, handler.event.tag())
    // 子程序入口是列表项不是主操作，用 Tonal 避免一列实心红块
    handlers.push(
      @views.button(key, on_click=SelectHandler(key), variant=Tonal),
    )
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
        handlers.push(
          @views.text(
            text(t, "app.handler.new"),
            role=Subtitle,
            width=140.0,
            align=TextStart,
          ),
        )
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
  // 与右栏同一套滚动布局：视口全出血到卡片边（卡片 padding=0、视口 224），
  // 指示器画在视口右缘内缩 7pt 处——贴住面板最右侧；内容列被视口宽紧约束
  // 拉伸，用限宽容器居中吸收，右侧槽位留给指示器，不再压住按钮。
  // 224 = 分节标题行 178（文字 140 + 徽章 28 + 间距 10）+ 两侧内垫 20 + 槽位余量。
  // min_height=580（视口 600 − 内垫 20）：容器会把矮内容在帧内垂直居中，
  // 内容列撑满视口高度后从顶部排布，与「面板从上往下用」的直觉一致。
  @views.card(
    @views.scroll_view(
      @views.container(
        @views.column(palette_items).frame(min_height=580.0),
        background=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.0),
        padding=10.0,
      ),
      width=224.0,
      height=600.0,
      shows_indicator=true,
    ),
    width=224.0,
    height=600.0,
    padding=0.0,
  )
}

///|
/// 中部：按模式切换（设计画布 / 积木链 / 代码编辑器）。
fn center_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.mode {
    ModeDesign => {
      // 缩放工具条：适应窗口（0 = 画布等比铺满画布列）或固定档位
      // （画布逻辑尺寸 = 640×zoom，超出视口由滚动接管）。绘制与命中
      // 都按 帧宽/640 现算同一比例，指针换算无需额外分支。
      let zoom_items = [
        @views.action_item(
          id="fit",
          label=text(t, "app.design.zoom.fit"),
          message=SetDesignZoom(0.0),
        ),
        @views.action_item(id="z50", label="50%", message=SetDesignZoom(0.5)),
        @views.action_item(id="z75", label="75%", message=SetDesignZoom(0.75)),
        @views.action_item(id="z100", label="100%", message=SetDesignZoom(1.0)),
        @views.action_item(id="z150", label="150%", message=SetDesignZoom(1.5)),
      ]
      let selected = if model.design_zoom <= 0.0 {
        "fit"
      } else if model.design_zoom == 0.5 {
        "z50"
      } else if model.design_zoom == 0.75 {
        "z75"
      } else if model.design_zoom == 1.0 {
        "z100"
      } else {
        "z150"
      }
      let canvas_view = {
        // 舞台控件：与运行舞台同一构造器（form_widget，无回调 = 纯展示，
        // 手势覆盖层拦截指针输入）。外观与运行时由构造保证一致。
        let stage_widgets : Array[@moui.View[Msg]] = []
        let stage_rects : Array[@geometry.Rect] = []
        for control in model.program.controls {
          stage_widgets.push(
            form_widget(control, control.text, false, control.items, -1),
          )
          stage_rects.push(
            @geometry.Rect::new(
              x=control.x.to_double(),
              y=control.y.to_double(),
              width=control.width.to_double(),
              height=control.height.to_double(),
            ),
          )
        }
        design_stage(
          model.program,
          model.selected_control,
          match model.drag {
            Some(drag) => Some(drag.control)
            None => None
          },
          stage_widgets,
          stage_rects,
          // 可读文案过翻译器：画布语义标签不烤进画布实现
          text(t, "app.design.canvas"),
          // 空画布引导（i18n）：没有控件时画布中央的提示
          text(t, "app.design.empty"),
        )
      }
      let canvas_area = if model.design_zoom <= 0.0 {
        // 适应窗口：显式高度帧（556 = 列高 600 − 工具条 38 − 间距 6），
        // 宽度由画布列拉伸提供，画布按 min(帧宽/640, 帧高/480) 等比缩放。
        // 不用 .flexible()：加权子树的指针派发会在 tight 重排下丢手势
        // （runtime_pointer_input_test 的设计舞台回归锁定此行为）。
        canvas_view.frame(height=556.0)
      } else {
        // 固定档位：舞台逻辑尺寸 = 640×zoom，超出视口（画布列宽 × 548 高）
        // 由滚动容器双向接管；指示器画在滚动视口右缘。
        @views.scroll_view(
          @views.container(
            canvas_view,
            width=@ir.DESIGN_WIDTH.to_double() * model.design_zoom,
            height=@ir.DESIGN_HEIGHT.to_double() * model.design_zoom,
            padding=0.0,
          ),
          width=640.0,
          height=548.0,
          shows_indicator=true,
        )
      }
      @views.column(
        [@views.button_group(zoom_items, selected~), canvas_area],
        spacing=6.0,
      )
      // 锚定高度：设计列处于 CrossStart 行里，按「测量高度」布局，而
      // 加权子级（flexible 舞台）不占测量基底——列会被压成 44pt
      // （工具条+间距），舞台帧高度归零、命中区域为空，拖拽/点选全部
      // 失效。显式 600 = 主行高度，flex 余量恢复给舞台。
      .frame(height=600.0)
    }
    ModeBlocks => blocks_panel(model, t)
    ModeCode => code_panel(model, t)
    ModePreview => preview_panel(model, t)
    ModeHelp => help_panel(model, t)
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
      let blocks = @blocks.block_chain(handler.body)
      // 展示名预渲染（画布 draw 闭包拿不到翻译器）：
      // 有文本的语句 = 分类标签 + 语句文本；控制流块 = 分类标签
      let display_texts : Array[String] = []
      for item in blocks {
        let label = text(t, @blocks.block_label_key(item.kind))
        display_texts.push(
          if item.text == "" {
            label
          } else {
            "\{label}  \{item.text}"
          },
        )
      }
      let rects = blocks_item_rects(blocks)
      let canvas_height = rects.length().to_double() * 40.0 + 24.0
      let blocks_view = blocks_canvas(
        blocks,
        display_texts,
        model.selected_block,
        spotlight,
        model.block_drag,
        canvas_height,
        text(t, "app.blocks.canvas"),
      )
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
      let panel : Array[@moui.View[Msg]] = [
        @views.text(
          "\{text(t, "blocks.event")}：\{handler.control_name} . \{text(t, "event.\{handler.event.tag()}")}",
          role=Subtitle,
        ),
        @views.text(text(t, "app.blocks.reorder_hint"), role=Caption),
        blocks_view,
      ]
      for item_view in editor {
        panel.push(item_view)
      }
      @views.scroll_view(
        @views.column(panel),
        width=480.0,
        height=600.0,
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
        if record.op is @studio_lang.OpAssign ||
          record.op is @studio_lang.OpMessage ||
          record.op is @studio_lang.OpCommand ||
          record.op is @studio_lang.OpGate {
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
      theme=studio_theme(),
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
    compiled_run_header(model, t),
  ]
  for line in source.split("\n") {
    lines.push(
      @views.text(line.to_owned(), role=Mono, width=460.0, align=TextStart),
    )
  }
  @views.scroll_view(
    @views.column(lines),
    width=480.0,
    height=600.0,
    shows_indicator=true,
  )
}

///|
/// 帮助视图：DSL 双语速查表——**从关键字表与内建目录数据生成**，
/// 不手抄第二份（关键字表改了，帮助页自动跟随）。
fn help_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let zh = @studio_lang.keywords_for(@studio_lang.ZhHans)
  let en = @studio_lang.keywords_for(@studio_lang.En)
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
  let kind_label = fn(kind : @studio_lang.BuiltinKind) -> String {
    match kind {
      @studio_lang.Command => text(t, "app.help.commands")
      @studio_lang.Function => text(t, "app.help.functions")
      @studio_lang.Gate => text(t, "app.help.gates")
    }
  }
  for spec in @studio_lang.builtin_catalog() {
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
    height=600.0,
    shows_indicator=true,
  )
}

///|
/// 审计时间线色点：操作类型 → 语义色（赋值蓝 / 信息框绿 / 闸门朱砂 /
/// 命令紫 / 条件橙 / 循环青）。
fn audit_dot_color(op : @studio_lang.StepOp) -> @graphics.Color {
  match op {
    @studio_lang.OpAssign => @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
    @studio_lang.OpMessage => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    @studio_lang.OpGate => @graphics.Color::rgba(r=0.78, g=0.26, b=0.20)
    @studio_lang.OpCommand => @graphics.Color::rgba(r=0.55, g=0.40, b=0.75)
    @studio_lang.OpCondition => @graphics.Color::rgba(r=0.85, g=0.55, b=0.16)
    @studio_lang.OpLoop => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
  }
}

///|
/// 编译轨审计色点：与解释轨逐类同色（两轨审计视图不应有色差）。
fn compiled_audit_dot_color(op : @compiled_runtime.StepOp) -> @graphics.Color {
  match op {
    @compiled_runtime.OpAssign => @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
    @compiled_runtime.OpMessage => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    @compiled_runtime.OpGate => @graphics.Color::rgba(r=0.78, g=0.26, b=0.20)
    @compiled_runtime.OpCommand => @graphics.Color::rgba(r=0.55, g=0.40, b=0.75)
    @compiled_runtime.OpCondition =>
      @graphics.Color::rgba(r=0.85, g=0.55, b=0.16)
    @compiled_runtime.OpLoop => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
  }
}

///|
/// 表单控件唯一构造点：运行舞台与设计舞台共用同一批 widget——设计态
/// 外观与运行态由构造保证一致（治本：不再有"效果图 vs 真控件"两套渲染）。
/// handlers 缺省 = 纯展示：设计舞台的手势覆盖层拦截全部指针输入，控件
/// 收不到事件；文本类回调必填处给 Noop 兜底，防漏网点击改动状态。
fn form_widget(
  control : @ir.Control,
  value : String,
  checked : Bool,
  rows : Array[String],
  selected_row : Int,
  on_click? : Msg,
  on_change? : (String, String) -> Msg,
  on_pick? : (String, Int) -> Msg,
  on_toggle? : (String, Bool) -> Msg,
) -> @moui.View[Msg] {
  match control.kind {
    @ir.Label => @views.text(value, align=TextStart)
    @ir.Button =>
      match on_click {
        Some(click) => @views.button(value, on_click=click)
        None => @views.button(value)
      }
    @ir.TextField =>
      match on_change {
        Some(change) =>
          @views.text_field(value, on_input=new_value => {
            change(control.name, new_value)
          })
        None => @views.text_field(value, on_input=_new_value => Msg::Noop)
      }
    @ir.CheckBox =>
      match on_toggle {
        Some(toggle) =>
          @views.checkbox(value, checked~, on_change=checked => {
            toggle(control.name, checked)
          })
        None =>
          @views.checkbox(value, checked~, on_change=_checked => Msg::Noop)
      }
    @ir.ListBox | @ir.Table => {
      // 列表框/表格是带视口的实物：行高 24，按设计高度截断可见行
      let max_rows = if control.height < 24 { 1 } else { control.height / 24 }
      let row_views : Array[@moui.View[Msg]] = []
      let mut row_index = 0
      for item in rows {
        if row_index >= max_rows {
          break
        }
        let index = row_index
        let selected = selected_row == index
        let label = if selected { "▶ " + item } else { item }
        row_views.push(
          match on_pick {
            Some(pick) =>
              @views.button(
                label,
                on_click=pick(control.name, index),
                variant=Tonal,
                height=24.0,
              )
            None => @views.button(label, variant=Tonal, height=24.0)
          },
        )
        row_index = row_index + 1
      }
      @views.column(row_views, spacing=0.0)
    }
  }
}

///|
/// 运行舞台唯一构造点：设计坐标绝对布局（StageLayout 按 IR 矩形分配子帧，
/// tight 重排让控件精确等于设计的尺寸与位置）——两轨共用同一舞台，
/// 只有数据源（解释轨 RunState / 编译轨 Runtime）不同。
fn run_stage(
  model : Model,
  texts : Map[String, String],
  checks : Map[String, Bool],
  rows : Map[String, Array[String]],
  selections : Map[String, Int],
) -> @moui.View[Msg] {
  let stage_widgets : Array[@moui.View[Msg]] = []
  let stage_rects : Array[@geometry.Rect] = []
  for control in model.program.controls {
    let value = texts.get(control.name).unwrap_or(control.text)
    stage_widgets.push(
      form_widget(
        control,
        value,
        checks.get(control.name).unwrap_or(false),
        rows.get(control.name).unwrap_or([]),
        selections.get(control.name).unwrap_or(-1),
        on_click=ControlClicked(control.name),
        on_change=(name, new_value) => ControlChanged(name, new_value),
        on_pick=(name, index) => ControlPicked(name, index),
        on_toggle=(name, checked) => RunToggle(name, checked),
      ),
    )
    stage_rects.push(
      @geometry.Rect::new(
        x=control.x.to_double(),
        y=control.y.to_double(),
        width=control.width.to_double(),
        height=control.height.to_double(),
      ),
    )
  }
  @views.container(
    stage_layout(stage_widgets, stage_rects),
    width=@ir.DESIGN_WIDTH.to_double(),
    height=@ir.DESIGN_HEIGHT.to_double(),
    // 运行舞台与设计画布同一底板：运行的就是设计出来的那一块，
    // 两轨共用，不因「运行」切成另一套外观（技术风深色画板）。
    background=studio_stage_background(),
    corner_radius=6.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(studio_stage_outline()),
        width=1.0,
      ),
    ),
    padding=0.0,
  )
}

///|
/// 编译轨运行视图：同一舞台 + 编译产物执行面读数（变量/消息/审计/闸门）。
/// 与解释轨的可见差异只有事实差异：没有单步（真编译产物没有暂停指令），
/// 因此隐藏单步/继续；闸门、审计跳积木、控件事件派发与解释轨同一套。
fn compiled_run_form(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.compiled_run {
    // 还没跑编译产物：报告 + 显式触发按钮仍要在运行视图可达
    // （编译失败时停在这里看诊断，不静默退回解释轨）。
    None => compiled_run_header(model, t)
    Some(run) => {
      let runtime = run.runtime
      let stage = run_stage(
        model,
        runtime.texts,
        run.checks,
        runtime.rows,
        runtime.selections,
      )
      let stage_head = @views.column([
        @views.row([
          @views.text(text(t, "app.run.compile_stage"), role=Caption),
          @views.text("\{run.handler_label}", role=Subtitle),
        ]),
        @views.row([
          @views.button(
            text(t, "app.run.stop"),
            on_click=RunStop,
            variant=Outline,
          ),
          match runtime.gate {
            Some(_) =>
              @views.badge(
                theme=studio_theme(),
                text(t, "app.run.gate_pending"),
                tone=@style.BadgeTone::Warning,
                width=64.0,
                height=24.0,
              )
            None => @views.text("")
          },
        ]),
        @views.text(text(t, "app.run.compile_noskip"), role=Caption),
      ])
      // 变量表：编译轨 Runtime.vars，按键名稳定排序（与解释轨同一口径）
      let variables_card : Array[@moui.View[Msg]] = []
      let variable_names : Array[String] = []
      for name in runtime.vars.keys() {
        variable_names.push(name)
      }
      variable_names.sort()
      if variable_names.length() > 0 {
        variables_card.push(
          @views.text(text(t, "app.run.variables"), role=Subtitle),
        )
        for name in variable_names {
          match runtime.vars.get(name) {
            Some(value) =>
              variables_card.push(
                @views.row([
                  @views.text(name, width=120.0),
                  @views.text(
                    @compiled_runtime.value_to_text(value),
                    width=280.0,
                  ),
                ]),
              )
            None => ()
          }
        }
      }
      // 闸门卡：与解释轨一致的确认/拒绝两键（闸门确认前零真实动作）
      let gate_card : Array[@moui.View[Msg]] = []
      match runtime.gate {
        Some(gate) => {
          let prompt = match gate.kind {
            @compiled_runtime.Submit =>
              text_with(t, "app.run.gate.submit", [
                ("target", gate.prompt),
                ("payload", gate.payload),
              ])
            @compiled_runtime.Ask =>
              text_with(t, "app.run.gate.ask", [("prompt", gate.prompt)])
          }
          gate_card.push(
            @views.column([
              @views.callout(
                theme=studio_theme(),
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
      let messages_card : Array[@moui.View[Msg]] = []
      if runtime.messages.length() > 0 {
        let messages : Array[@moui.View[Msg]] = [
          @views.text(text(t, "app.run.messages"), role=Subtitle),
        ]
        for message in runtime.messages {
          messages.push(@views.text(message))
        }
        messages_card.push(@views.column(messages))
      }
      // 审计时间线：与解释轨同一组 (line, op, detail)，按点跳积木
      let audit : Array[@moui.View[Msg]] = [
        @views.text(text(t, "app.run.audit"), role=Subtitle),
        @views.text(text(t, "app.run.audit_hint"), role=Caption),
      ]
      let mut audit_index = 0
      for record in runtime.audit {
        let op = match record.op {
          @compiled_runtime.OpAssign => "op.assign"
          @compiled_runtime.OpMessage => "op.message"
          @compiled_runtime.OpGate => "op.gate"
          @compiled_runtime.OpCommand => "op.command"
          @compiled_runtime.OpCondition => "op.condition"
          @compiled_runtime.OpLoop => "op.loop"
        }
        let dot = @views.container(
          @views.empty(),
          background=compiled_audit_dot_color(record.op),
          corner_radius=4.0,
          width=8.0,
          height=8.0,
        )
        let row_index = audit_index
        audit_index = audit_index + 1
        audit.push(
          @views.row([
            dot,
            @views.text("\{text(t, op)}  \{record.detail}", width=560.0),
          ]).on_tap(AuditJump(row_index)),
        )
      }
      let error_card : Array[@moui.View[Msg]] = []
      match runtime.error {
        Some(error) =>
          error_card.push(
            @views.inline_error(
              compiled_error_message(t, error),
              width=440.0,
              theme=studio_theme(),
            ),
          )
        None => ()
      }
      let panel : Array[@moui.View[Msg]] = [stage_head]
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
          width=600.0,
          height=180.0,
          shows_indicator=true,
        ),
      )
      for item in error_card {
        panel.push(item)
      }
      @views.scroll_view(
        @views.column(
          [
            compiled_run_header(model, t),
            stage,
            @views.card(
              @views.container(@views.column(panel), padding=10.0),
              width=640.0,
              padding=10.0,
            ),
          ],
          spacing=8.0,
        ),
        width=640.0,
        height=576.0,
        shows_indicator=true,
      )
    }
  }
}

///|
/// 运行视图：按当前轨分派。两轨运行态互相独立——切轨只换视图，
/// 不销毁另一轨已跑到的位置（模型层保证，视图层如实投影）。
fn run_form(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match current_track(model) {
    Interpret => interpret_run_form(model, t)
    Compile => compiled_run_form(model, t)
  }
}

///|
/// 解释轨运行视图：真实渲染程序窗体（窗体框舞台）+ 闸门确认卡 + 审计时间线。
fn interpret_run_form(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match model.run {
    None => @views.text("")
    Some(run) => {
      let stage = run_stage(
        model,
        run.state.texts,
        run.checks,
        run.state.rows,
        run.state.selections,
      )
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
            @studio_lang.Completed | @studio_lang.Failed => @views.text("")
            _ =>
              @views.button(
                text(t, "app.run.step"),
                on_click=RunStep,
                variant=Outline,
              )
          },
          match run.state.status {
            @studio_lang.Completed | @studio_lang.Failed => @views.text("")
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
                theme=studio_theme(),
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
                  @views.text(@studio_lang.value_to_text(value), width=280.0),
                ]),
              )
            None => ()
          }
        }
      }
      // 闸门卡：确认卡（Warning tone）+ 确认 Primary / 拒绝 Outline，
      // 确认前零真实动作
      let gate_card : Array[@moui.View[Msg]] = []
      match run.state.gate {
        Some(gate) => {
          let prompt = match gate.kind {
            @studio_lang.Submit =>
              text_with(t, "app.run.gate.submit", [
                ("target", gate.prompt),
                ("payload", gate.payload),
              ])
            @studio_lang.Ask =>
              text_with(t, "app.run.gate.ask", [("prompt", gate.prompt)])
          }
          gate_card.push(
            @views.column([
              @views.callout(
                theme=studio_theme(),
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
        @views.text(text(t, "app.run.audit_hint"), role=Caption),
      ]
      let mut audit_index = 0
      for record in run.state.audit {
        let op = match record.op {
          @studio_lang.OpAssign => "op.assign"
          @studio_lang.OpMessage => "op.message"
          @studio_lang.OpGate => "op.gate"
          @studio_lang.OpCommand => "op.command"
          @studio_lang.OpCondition => "op.condition"
          @studio_lang.OpLoop => "op.loop"
        }
        let dot = @views.container(
          @views.empty(),
          background=audit_dot_color(record.op),
          corner_radius=4.0,
          width=8.0,
          height=8.0,
        )
        let row_index = audit_index
        audit_index = audit_index + 1
        audit.push(
          @views.row([
            dot,
            @views.text("\{text(t, op)}  \{record.detail}", width=560.0),
          ]).on_tap(AuditJump(row_index)),
        )
      }
      let error_card : Array[@moui.View[Msg]] = []
      match run.state.error {
        Some(error) =>
          error_card.push(
            @views.inline_error(
              error_message(t, error),
              width=440.0,
              theme=studio_theme(),
            ),
          )
        None => ()
      }
      let panel : Array[@moui.View[Msg]] = [stage_head]
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
          width=600.0,
          height=180.0,
          shows_indicator=true,
        ),
      )
      for item in error_card {
        panel.push(item)
      }
      // 运行界面 = 舞台在上（640×480，所见即所得）+ 数据面卡片在下，
      // 装进同一个可滚动列——审计时间线较长时舞台滚出视野有停止按钮兜底。
      @views.scroll_view(
        @views.column(
          [
            compiled_run_header(model, t),
            stage,
            @views.card(
              @views.container(@views.column(panel), padding=10.0),
              width=640.0,
              padding=10.0,
            ),
          ],
          spacing=8.0,
        ),
        width=640.0,
        height=576.0,
        shows_indicator=true,
      )
    }
  }
}

///|
/// 右栏：属性检查器（仅设计模式——位置/尺寸是画布概念）+ AI 提案面板
/// （设计/积木/代码都可用：AI 改的是程序，不只是画布）。
fn right_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let sections : Array[@moui.View[Msg]] = []
  if model.mode is ModeDesign {
    sections.push(inspector_panel(model, t))
    sections.push(@views.divider())
  }
  sections.push(ai_panel(model, t))
  // 滚动指示器画在「视口右缘内缩 7pt」处：视口贴到卡片边（卡片 padding=0、
  // 视口 300 全出血），指示器才落在面板最右侧。内容列会被视口宽紧约束
  // 拉伸，用限宽 250 的居中容器吸收：输入框在面板内对称居中，右侧空出的
  // 槽位正好给指示器。透明背景只要留白，不要 Base 底色。
  // min_height=580（视口 600 − 内垫 20）：积木/代码模式下 AI 面板内容可能
  // 矮于视口，不撑满会被容器垂直居中——与左栏同一纪律。
  @views.card(
    @views.scroll_view(
      @views.container(
        @views.column(sections).frame(min_height=580.0),
        background=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.0),
        padding=10.0,
      ),
      width=300.0,
      height=600.0,
      shows_indicator=true,
    ),
    width=300.0,
    height=600.0,
    padding=0.0,
  )
}

///|
/// 危险按钮样式：朱砂前景 + 半透明朱砂描边，悬停淡红底——与中性
/// Outline 区分破坏性操作（删除控件），不给实心主色。
fn danger_button_style() -> @style.ButtonStyle {
  let danger = @core.Color::rgba(r=0.78, g=0.26, b=0.20)
  let border = @core.BorderStyle::new(
    brush=@core.Brush::solid(danger.multiply_alpha(0.5)),
    width=1.0,
  )
  fn state(
    foreground : @core.Color,
    background : @core.Color,
  ) -> @style.ControlStateStyle {
    @style.ControlStateStyle::{
      foreground,
      background: @core.Brush::solid(background),
      border: Some(border),
      radius: 6.0,
      shadow: None,
      bottom_border_only: false,
      inner_focus_border: None,
    }
  }
  @style.ButtonStyle::new(
    normal=state(danger, @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    hovered=state(danger, @core.Color::rgba(r=0.235, g=0.129, b=0.121)),
    pressed=state(danger, @core.Color::rgba(r=0.318, g=0.157, b=0.145)),
    disabled=state(
      @core.Color::rgba(r=0.78, g=0.26, b=0.20).multiply_alpha(0.4),
      @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    ),
  )
}

///|
/// 属性检查器：名称 / 文本 / 选项 / 删除。
fn inspector_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  match find_selected_control(model) {
    None => @views.text(text(t, "app.inspector.none"), align=TextStart)
    Some(control) =>
      @views.column([
        @views.text(text(t, "app.inspector"), align=TextStart),
        @views.text(text(t, "app.inspector.name"), align=TextStart),
        @views.text_field(
          control.name,
          on_input=new_value => SetControlName(control.name, new_value),
          width=250.0,
        ),
        @views.text(text(t, "app.inspector.text"), align=TextStart),
        @views.text_field(
          control.text,
          on_input=new_value => SetControlText(control.name, new_value),
          width=250.0,
        ),
        @views.text(text(t, "app.inspector.position"), align=TextStart),
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
        @views.text(text(t, "app.inspector.size"), align=TextStart),
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
            @views.text(text(t, "app.inspector.items"), align=TextStart),
            @views.text_area(
              join_lines(control.items),
              on_input=new_value => SetControlItems(control.name, new_value),
              lines=4,
              width=250.0,
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
          // 删除是破坏性操作：危险样式（朱砂描边/悬停淡红），不是实心主色
          @views.button(
            text(t, "app.inspector.delete"),
            on_click=DeleteControl(control.name),
            style=danger_button_style(),
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
    @views.row(
      [
        // 标题限宽：text 默认 160 会把这一行撑到 262，几乎吃满滚动视口
        @views.text(
          text(t, "app.ai.title"),
          role=Subtitle,
          width=130.0,
          align=TextStart,
        ),
        @views.badge(
          theme=studio_theme(),
          if model.provider_mode is Fake {
            text(t, "app.ai.fake")
          } else {
            text(t, "app.ai.real")
          },
          tone=if model.provider_mode is Fake {
            @style.BadgeTone::Neutral
          } else {
            @style.BadgeTone::Accent
          },
          width=92.0,
          height=22.0,
        ),
      ],
      justify=Between,
    ),
    @views.text_field(
      model.prompt_draft,
      on_input=value => SetPrompt(value),
      placeholder=text(t, "app.ai.prompt"),
      width=250.0,
    ),
    // 每组只保留一个实心主按钮（生成提案）；讲解/模型切换是次级操作，
    // 用 Outline 避免右栏变成一堵红墙。
    @views.button(text(t, "app.ai.generate"), on_click=GenerateProposal),
    @views.button(
      text(t, "app.ai.explain"),
      on_click=ExplainHandler,
      variant=Outline,
    ),
  ]
  let prompt_error_card : Array[@moui.View[Msg]] = []
  if model.prompt_error != "" {
    prompt_error_card.push(
      @views.inline_error(model.prompt_error, width=250.0, theme=studio_theme()),
    )
  }
  // 真实 provider 请求进行中：加载态占位
  let busy_card : Array[@moui.View[Msg]] = []
  if model.ai_busy {
    busy_card.push(
      @views.loading_state(
        title=text(t, "app.ai.busy"),
        width=250.0,
        theme=studio_theme(),
      ),
    )
  }
  // 待采纳提案
  let proposal_card : Array[@moui.View[Msg]] = []
  // 空态把 AI 的工作方式说清楚，避免右栏只剩一组输入框和按钮。
  // 有提案/讲解时让结果替代空态，保持面板信息密度稳定。
  if model.pending is None && !model.ai_busy && model.explanation == "" {
    proposal_card.push(
      @views.empty_state(
        theme=studio_theme(),
        text(t, "app.ai.title"),
        text(t, "app.ai.prompt"),
        width=250.0,
      ),
    )
  }
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
            @views.badge(
              text(t, op),
              tone~,
              width=52.0,
              height=20.0,
              theme=studio_theme(),
            ),
            @views.text(
              "\{entry.path}：\{entry.old_text} → \{entry.new_text}",
              width=180.0,
            ),
          ]),
        )
      }
      proposal_card.push(
        @views.scroll_view(@views.column(entries), width=250.0, height=140.0),
      )
      if !pending.valid {
        for error in pending.errors {
          proposal_card.push(@views.text(error))
        }
      }
      proposal_card.push(
        @views.row([
          @views.button(text(t, "app.ai.accept"), on_click=AcceptProposal),
          @views.button(
            text(t, "app.ai.reject"),
            on_click=RejectProposal,
            variant=Outline,
          ),
        ]),
      )
    }
  }
  // 讲解
  let explanation_card : Array[@moui.View[Msg]] = []
  if model.explanation != "" {
    explanation_card.push(
      @views.text(text(t, "app.ai.explanation"), align=TextStart),
    )
    explanation_card.push(@views.text(model.explanation))
  }
  // provider 设置收进折叠区：三输入框常驻占了近半面板，默认收起后
  // 提案/讲解区获得首屏空间；需要时一键展开。
  // 密钥用 password 掩码：语义树/读屏只能看到星号，点「显示」才暴露
  // （掩码态下的编辑在 update 层忽略，防星号写穿真值）。
  let provider_section = @views.disclosure(
    theme=studio_theme(),
    text(t, "app.ai.settings"),
    content=@views.column(
      [
        @views.button(
          text(t, "app.ai.fake"),
          on_click=SetProviderMode(Fake),
          variant=Outline,
        ),
        @views.button(
          text(t, "app.ai.real"),
          on_click=SetProviderMode(Real),
          variant=Outline,
        ),
        @views.text_field(
          model.provider_endpoint,
          on_input=value => SetProviderEndpoint(value),
          placeholder=text(t, "app.ai.endpoint"),
          width=220.0,
        ),
        @views.text_field(
          model.provider_model,
          on_input=value => SetProviderModel(value),
          placeholder=text(t, "app.ai.model"),
          width=220.0,
        ),
        @views.password_field(
          model.provider_key,
          on_input=value => SetProviderKey(value),
          revealed=model.provider_key_revealed,
          on_toggle_reveal=ToggleProviderKeyReveal,
          placeholder=text(t, "app.ai.key"),
          width=220.0,
        ),
      ],
      spacing=8.0,
    ),
    expanded=model.provider_settings_open,
    on_toggle=ToggleProviderSettings,
    width=250.0,
  )
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
    panel.push(
      @views.text(text(t, "app.ai.history"), role=Subtitle, align=TextStart),
    )
    for record in model.proposal_history {
      panel.push(
        @views.row([
          @views.badge(
            theme=studio_theme(),
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
  panel.push(provider_section)
  @views.column(panel)
}

///|
/// 顶层组合。
pub fn view(model : Model) -> @moui.View[Msg] {
  let t = translator(model)
  // 侧栏按模式显隐：设计=控件+事件子程序+属性+AI；积木/代码=事件子程序
  // （切换编辑目标）+AI（改程序）；MoonBit 预览/帮助/运行是只读或执行
  // 场景，两侧面板都收起，内容在窗口内居中。
  let show_panels = match model.mode {
    ModeDesign | ModeBlocks | ModeCode => true
    ModePreview | ModeHelp | ModeRun => false
  }
  let main_row = if show_panels {
    @views.row(
      [
        // 固定 24pt 端边距（弹性 spacer 会被弹性画布列吃掉 slack，面板又会
        // 贴回窗口边缘）；剩余 slack 全给画布列等比放大。
        @views.spacer(min_length=24.0, weight=0.0),
        left_panel(model, t),
        @views.divider(axis=Vertical),
        // 画布列弹性伸缩：剩余宽度全部给画布，画布按约束等比铺满
        // （缩放因子 = 帧宽/640，命中测试同比例换算），不再是固定 640
        // 两侧吃留白。
        center_panel(model, t).flexible(),
        @views.divider(axis=Vertical),
        right_panel(model, t),
        @views.spacer(min_length=24.0, weight=0.0),
      ],
      align=Start,
    ).frame(height=600.0)
  } else {
    @views.row(
      [@views.spacer(), center_panel(model, t), @views.spacer()],
      align=Start,
    ).frame(height=600.0)
  }
  let base = @views.container(
    @views.column([
      top_bar(model, t),
      @views.divider(),
      // 主行必须钳制高度：行内竖直 divider 按「可用高度」测量（和横 divider
      // 按可用宽度测量是同一约定），不钳制时把行撑到接近窗口高，画布再被
      // 容器垂直居中，顶部就空出一条大空白、底部 notice 被推出窗口。
      // 600 与左右面板卡同高；顶栏合并成两行后主区从 560 长到 600。
      main_row,
      @views.text(model.notice),
    ]),
    background=studio_window_background(),
    padding=0.0,
  )
  // 技术风暗色主题：石墨工程面板 + 朱砂唯一强调色，不随系统深浅漂移。
  command_palette_host(base, model, t).theme(studio_theme())
}
