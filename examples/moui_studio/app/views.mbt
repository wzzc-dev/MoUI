///|
/// MoUI Studio 视图层：顶栏 + 左栏（控件/子程序）+ 中部（三模式）+
/// 右栏（属性 / AI 提案）+ 运行区。全部文案过 i18n 翻译器。

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
      // 展示名与引导文本同源产出（画布 draw 闭包拿不到翻译器）：
      // 有文本的语句 = 分类标签 + 语句文本；控制流块 = 分类标签。
      // 引导文本决定插槽洞的起点，必须与展示一起给画布。
      let (display_texts, lead_texts) = block_row_texts(t, blocks)
      let rects = blocks_item_rects(blocks, avail_width=420.0, display_texts~)
      let canvas_height = rects.length().to_double() * 40.0 + 24.0
      let blocks_view = blocks_canvas(
        blocks,
        display_texts,
        model.selected_block,
        spotlight,
        blocks_insert_mark(blocks, rects, model.block_drag),
        420.0,
        canvas_height,
        text(t, "app.blocks.canvas"),
        lead_texts~,
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
/// 全屏页（预览/帮助）顶部的返回行：这两页此前没有任何 UI 入口可达，
/// 命令面板接通入口的同时必须有出口——没有返回行，进来就是死胡同。
/// `SetMode(ModeDesign)` 保留当前工作区（从哪里来回哪里去）。
fn fullscreen_back_row(t : @i18n.Translator) -> @moui.View[Msg] {
  @views.row([
    @views.button(
      text(t, "app.back.edit"),
      on_click=SetMode(ModeDesign),
      variant=Outline,
      width=button_label_width(text(t, "app.back.edit")) + 32.0,
      height=30.0,
    ),
  ])
}

///|
/// MoonBit 预览视图：把当前程序渲染成可读 MoonBit 源码（毕业通道 v1.1）。
/// 只读展示——生成的文本是审阅材料，不是编辑器输入。
fn preview_panel(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let source = @export.moonbit_preview(model.program)
  let lines : Array[@moui.View[Msg]] = [
    fullscreen_back_row(t),
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
  ignore(model)
  let zh = @studio_lang.keywords_for(@studio_lang.ZhHans)
  let en = @studio_lang.keywords_for(@studio_lang.En)
  let rows : Array[@moui.View[Msg]] = [
    fullscreen_back_row(t),
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
  progress_value? : Double = 0.0,
  on_input_done? : (String) -> Msg,
) -> @moui.View[Msg] {
  // 属性 v2（G7.2）：不可见 = 空视图（占位保持 stage 配对不串位）
  if !control.props.visible {
    return @views.empty()
  }
  let props = control.props
  let theme = prop_theme(props)
  let fg = prop_color(props.text_color)
  let bg = prop_color(props.back_color)
  let view = match control.kind {
    @ir.Label =>
      // 仅在属性定制（字号/加粗）时传主题覆盖——默认沿用环境主题
      // （舞台继承产品浅色主题，显式传 studio_theme 会打回 IDE 暗色）
      match theme {
        Some(t) => @views.text(value, align=prop_align(props.align), theme=t)
        None => @views.text(value, align=prop_align(props.align))
      }
    @ir.Button =>
      match on_click {
        Some(click) =>
          if props.disabled {
            @views.button(value)
          } else {
            @views.button(value, on_click=click)
          }
        None => @views.button(value)
      }
    @ir.TextField =>
      match on_change {
        Some(change) =>
          if props.disabled {
            @views.text_field(value, on_input=_new_value => Msg::Noop)
          } else {
            @views.text_field(
              value,
              on_input=new_value => change(control.name, new_value),
              on_submit=on_input_done.map(done => done(control.name)),
              placeholder=props.placeholder,
            )
          }
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
    // 下拉框：点一下循环到下一项（教学语义：选项轮换即换值，无弹层状态）
    @ir.Dropdown => {
      let items = if control.items.length() > 0 {
        control.items
      } else {
        ["选项 A", "选项 B"]
      }
      let index = selected_row.clamp(min=0, max=items.length() - 1)
      let current = items[index]
      let next_index = (index + 1) % items.length()
      match on_pick {
        Some(pick) =>
          @views.button(
            "▼ " + current,
            on_click=pick(control.name, next_index),
            variant=Tonal,
          )
        None => @views.button("▼ " + current, variant=Tonal)
      }
    }
    // 进度条：items[0] 是绑定的变量名（0..100），比例由调用方算好传入
    @ir.ProgressBar =>
      @views.progress(
        progress_value.clamp(min=0.0, max=1.0),
        width=control.width.to_double(),
      )
    // 图片：items[0] 是资源路径（缺省占位）
    @ir.Image =>
      @views.image(
        match control.items {
          [path, ..] => path
          [] => ""
        },
        width=control.width.to_double(),
        height=control.height.to_double(),
      )
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
  finish_prop_view(view, fg, bg)
}

///|
/// 属性收口（G7.2）：文字颜色/背景色修饰器（空值跳过）。
fn finish_prop_view(
  view : @moui.View[Msg],
  fg : @core.Color?,
  bg : @core.Color?,
) -> @moui.View[Msg] {
  let view = match fg {
    Some(color) => view.foreground(color)
    None => view
  }
  match bg {
    Some(color) => view.background_brush(@graphics.Brush::solid(color))
    None => view
  }
}

///|
/// 属性 → 主题排版覆盖（G7.2）：字号/加粗统一到全部角色;
/// 默认属性返回 None（沿用主题零开销）。
fn prop_theme(props : @ir.ControlProps) -> @core.Theme? {
  if props.font_size <= 0 && !props.bold {
    return None
  }
  let base = studio_theme()
  let ty = base.typography
  let size = if props.font_size > 0 {
    props.font_size.to_double()
  } else {
    ty.body.size
  }
  let weight = if props.bold { 600 } else { 400 }
  fn role(spec : @core.FontSpec) -> @core.FontSpec {
    { ..spec, size, weight, }
  }
  Some(
    @core.Theme::with_typography(base, {
      display: role(ty.display),
      headline: role(ty.headline),
      title: role(ty.title),
      subtitle: role(ty.subtitle),
      body: role(ty.body),
      label: role(ty.label),
      caption: role(ty.caption),
      overline: role(ty.overline),
      control: role(ty.control),
    }),
  )
}

///|
/// 属性 → 颜色：#RRGGBB → Color;空串/非 7 位 = None。
pub fn prop_color(hex : String) -> @core.Color? {
  if hex.length() != 7 {
    return None
  }
  fn hex_pair(high : Char, low : Char) -> Int? {
    fn digit(c : Char) -> Int? {
      let code = c.to_int()
      if code >= 48 && code <= 57 {
        Some(code - 48)
      } else if code >= 97 && code <= 102 {
        Some(code - 87)
      } else if code >= 65 && code <= 70 {
        Some(code - 55)
      } else {
        None
      }
    }
    match (digit(high), digit(low)) {
      (Some(h), Some(l)) => Some(h * 16 + l)
      _ => None
    }
  }
  let chars : Array[Char] = []
  for ch in hex {
    chars.push(ch)
  }
  if chars[0] != '#' {
    return None
  }
  match
    (
      hex_pair(chars[1], chars[2]),
      hex_pair(chars[3], chars[4]),
      hex_pair(chars[5], chars[6]),
    ) {
    (Some(r), Some(g), Some(b)) =>
      Some(
        @core.Color::rgba(
          r=r.to_double() / 255.0,
          g=g.to_double() / 255.0,
          b=b.to_double() / 255.0,
        ),
      )
    _ => None
  }
}

///|
/// 属性 → 文本对齐（空 = start）。
fn prop_align(align : String) -> @core.TextAlign {
  match align {
    "center" => TextCenter
    "end" => TextEnd
    _ => TextStart
  }
}

///|
/// 编译轨 Runtime 的变量表 → 解释轨值表（进度条绑定等只读展示用；
/// 与 update_run 的 interpreted_value 同一转换）。
fn compiled_values_map(
  run : @compiled_runtime.Runtime,
) -> Map[String, @studio_lang.Value] {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=8)
  for key in run.vars.keys() {
    match run.vars.get(key) {
      Some(value) => values[key] = interpreted_value(value)
      None => ()
    }
  }
  values
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
  values : Map[String, @studio_lang.Value],
  avail_width : Double,
  avail_height : Double,
) -> @moui.View[Msg] {
  let stage_widgets : Array[@moui.View[Msg]] = []
  let stage_rects : Array[@geometry.Rect] = []
  for control in model.program.controls {
    let value = texts.get(control.name).unwrap_or(control.text)
    // 进度条：绑定变量名（items[0]）的数值（0..100）
    let progress = match control.kind {
      @ir.ProgressBar =>
        match control.items {
          [bound, ..] =>
            match values.get(bound) {
              Some(@studio_lang.VInt(n)) => n.to_double() / 100.0
              Some(@studio_lang.VNum(n)) => n / 100.0
              _ => 0.0
            }
          [] => 0.0
        }
      _ => 0.0
    }
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
        progress_value=progress,
        on_input_done=name => ControlInputDone(name),
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
  // 运行舞台与设计舞台同一套「适应窗口」缩放：窗格比 640×480 窄时
  // 等比缩小，而不是把内容切掉（实测 w=900 时舞台里的标签文字被裁）。
  let fit = fit_scale(
    avail_width - 2.0,
    avail_height,
    @ir.DESIGN_WIDTH.to_double(),
    @ir.DESIGN_HEIGHT.to_double(),
  )
  @views.container(
    stage_layout(stage_widgets, stage_rects),
    width=@ir.DESIGN_WIDTH.to_double() * fit,
    height=@ir.DESIGN_HEIGHT.to_double() * fit,
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
      // 全屏运行视图：可用空间充足，给设计尺寸即 fit=1（不放大不缩小）。
      let stage = run_stage(
        model,
        runtime.texts,
        run.checks,
        runtime.rows,
        runtime.selections,
        compiled_values_map(runtime),
        @ir.DESIGN_WIDTH.to_double(),
        @ir.DESIGN_HEIGHT.to_double(),
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
      // 全屏运行视图：可用空间充足，给设计尺寸即 fit=1（不放大不缩小）。
      let stage = run_stage(
        model,
        run.state.texts,
        run.checks,
        run.state.rows,
        run.state.selections,
        run.state.vars,
        @ir.DESIGN_WIDTH.to_double(),
        @ir.DESIGN_HEIGHT.to_double(),
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
          let is_ask = gate.kind is @studio_lang.Ask
          let prompt = match gate.kind {
            @studio_lang.Submit =>
              text_with(t, "app.run.gate.submit", [
                ("target", gate.prompt),
                ("payload", gate.payload),
              ])
            @studio_lang.Ask =>
              text_with(t, "app.run.gate.ask", [("prompt", gate.prompt)])
          }
          let rows : Array[@moui.View[Msg]] = [
            @views.callout(
              theme=studio_theme(),
              text(t, "app.run.gate.title"),
              prompt,
              tone=@style.Warning,
              width=420.0,
            ),
          ]
          // **`询问` 要能打字**：回答才是它的返回值。
          //
          // 此前闸门卡片只给「确认/拒绝」两个按钮——用户没有任何地方输入
          // 回答，于是 `询问` 只能当「是/否」用，而 Scratch 的 `询问` 是
          // 「把回答当值用」（`说 (回答)`）。输入框只在 Ask 闸门出现：
          // `提交数据` 的确认不需要填内容。
          if is_ask {
            rows.push(
              @views.text_field(
                model.gate_answer_draft,
                on_input=text_value => GateAnswerInput(text_value),
                on_submit=Some(GateAnswerSubmit),
                placeholder=text(t, "app.run.gate.answer_hint"),
                variant=Outline,
                width=420.0,
                height=32.0,
              ),
            )
          }
          rows.push(
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
          )
          gate_card.push(@views.column(rows))
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
      //
      // **不挂 `compiled_run_header`**：那是编译轨的动作条与报告卡
      // （「真编译通过 / 目标 / 退出码」）。解释轨的运行视图挂上它，用户
      // 点「运行」后第一眼看到的是「真编译通过」＋「编译轨…（无解释器）」
      // ——那是上一轮编译的残留读数，既不属于本次运行，也解释了为什么
      // 看起来「点了运行没反应」。解释轨的运行头由 `stage_head` 自己给。
      @views.scroll_view(
        @views.column(
          [
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
fn find_selected_control(model : Model) -> @ir.Control? {
  if model.selected_control == "" {
    None
  } else {
    @ir.find_control(model.program, model.selected_control)
  }
}

///|
/// 顶层组合（v4 IDE 壳）已迁至 ide_root.mbt：那里按「顶栏 + 图标栏 +
/// 左栏 + 中心工作区 + 右栏 + 底栏 + 状态栏 + AI 层 + 模态宿主」装配。
/// 本文件保留各功能面板与运行视图（它们是内容，不是壳）。
