///|
/// 积木窗格：分类轨 + 积木画布（选中块处就地展开编辑卡）。
///
/// 从 `workspace.mbt` 拆出来（该文件已到 1200 行硬上限）：积木窗格与代码
/// 窗格是两条独立的展示路径，按「窗格」拆文件比按「视图/辅助」拆更贴近
/// 阅读顺序。

///|
/// 积木窗格：分类条 + 积木画布（选中块处就地展开编辑卡）。
/// 分类条点分类滚动到该类首块（选中分类记忆在 model.selected_category）。
pub fn blocks_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let handler_label = match current_handler(model) {
    None => text(t, "app.handler.none")
    Some(handler) =>
      "\{handler.control_name} . \{text(t, "event.\{handler.event.tag()}")}"
  }
  // 「IR 映射 · 与代码同步」走 `tail` 槽：它的宽度由 `pane_head_layout` 与
  // 标题/副标题/两个动作一起分配。**不要在这里自己算宽度**——同一行两处
  // 各算一份预算，口径一不同就会溢出（实测第一版在 1440 宽度上尾巴画到
  // 1253.2，而窗格右缘只有 1166）。
  let head = pane_head(
    text(t, "app.pane.blocks"),
    handler_label,
    width,
    [
      icon_button(
        Columns,
        if model.pane_live {
          text(t, "app.pane.hide_live")
        } else {
          text(t, "app.pane.show_live")
        },
        model.pane_live,
        TogglePaneLive,
        24.0,
        22.0,
        13.0,
      ),
      // 隐藏此窗格（设计稿 #btnHideBlocks）
      icon_button(
        Close,
        text(t, "app.pane.hide"),
        false,
        TogglePaneBlocks,
        24.0,
        22.0,
        13.0,
      ),
    ],
    tail=text(t, "app.pane.blocks.sub"),
  )
  // 分类轨**永远**在（没有选中子程序时全灰）：它是画布左侧的固定列，
  // 「今天没有块」本身就是分类轨要传达的信息之一。它并排在画布左侧
  // （设计稿 #catbar），而不是压在画布上方——积木视图纵向最紧，把分类
  // 移到画布旁边的空白里等于白赚 30pt 画布高。
  let body_height = blocks_body_height(model, height)
  let catbar = category_rail(model, t, body_height)
  // 语句插入面板：分类轨点开时，在轨与画布之间插一列骨架卡片（240pt）。
  // 宽度必须从 canvas_width **扣**：画布是自适应测量节点，让它先占满再把
  // 面板塞进去，面板会被挤到窗格外。顺序不能反（先算宽度、再建画布）。
  let palette_open = model.statement_palette_open &&
    model.selected_category >= 0 &&
    category_at(model.selected_category) is Some(_)
  // 面板宽度**自适应**：积木窗格常是中心列的两个窗格之一（实测 1280 窗口
  // 下只有 ~374pt），固定 240pt 会把画布挤到 ~44pt（内容全被裁）。
  // 取可用宽的一半并双向夹取，保证画布永远有可用的最小宽度。
  let available = (width - CATEGORY_RAIL_WIDTH - 4.0).max(0.0)
  let palette_width = if palette_open {
    (available * 0.5).max(STATEMENT_PALETTE_MIN_WIDTH).min(240.0)
  } else {
    0.0
  }
  let canvas_width = if palette_open {
    (available - palette_width).max(CANVAS_MIN_WIDTH)
  } else {
    (width - CATEGORY_RAIL_WIDTH - 2.0).max(CANVAS_MIN_WIDTH)
  }
  let canvas = match current_handler(model) {
    None =>
      @views.container(
        empty_hint(
          text(t, "app.handler.none"),
          canvas_width,
          body_height - 20.0,
        ),
        width=canvas_width,
        height=body_height,
        padding=0.0,
      )
    Some(handler) => {
      let blocks = @blocks.block_chain(handler.body)
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
      // 落槽指示线一次算好（链条坐标）
      let mark = blocks_insert_mark(blocks, rects, model.block_drag)
      let spotlight = current_spotlight(model)
      let sel = model.selected_block
      // **选中不再在链条里插编辑卡**（旧版做法）：卡片夹在上下两段之间，
      // 把画布硬切成三段，块多的时候整条链被挤得只剩几行可见——用户读到
      // 的就是「点积木后下面内容显示不全」。编辑面移到右栏 Context（见
      // ide_context.mbt 的 context_block_editor），画布保持**一条连续的链**：
      // 选中只体现在块的描边上，几何零变化，滚动位置也不跳。
      //
      // 代价是「编辑入口离选中远了一步」——用右栏自动切到属性页签 + 画布
      // 选中描边两个信号补回来（成熟 IDE 的检查器同样是「选中在画布、
      // 编辑在侧栏」，IDEA 的 Properties 面板就是这个分工）。
      let canvas_height = (rects.length().to_double() * BLOCK_ROW_HEIGHT + 24.0)
        .max(body_height)
        .max(120.0)
      @views.scroll_view(
        blocks_canvas(
          blocks,
          display_texts,
          sel,
          spotlight,
          mark,
          canvas_width,
          canvas_height,
          text(t, "app.blocks.canvas"),
        ),
        width=canvas_width,
        height=body_height,
        shows_indicator=true,
      )
    }
  }
  let body = if palette_open {
    @views.row(
      [
        catbar,
        @views.divider(axis=Vertical, color=ide_border()),
        statement_palette_panel(model, t, palette_width, body_height),
        @views.divider(axis=Vertical, color=ide_border()),
        canvas,
      ],
      spacing=0.0,
      align=Start,
    )
  } else {
    @views.row([catbar, canvas], spacing=0.0, align=Start)
  }
  @views.container(
    @views.column(
      // 成熟画布工具（Scratch/Figma）不在画布上放常驻用法提示：旧版的
      // 脚注提示与编辑条空态提示两条 24-30pt 的截断文字是纯噪音，删掉后
      // 高度还给画布。交互说明留给空态提示与控件 tooltip。
      [head, body],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 积木画布可用高度：头 + 画布（编辑卡嵌在链条里，不再占窗格高度）。
pub fn blocks_body_height(model : Model, height : Double) -> Double {
  let _ = model
  (height - PANEL_HEAD_HEIGHT - 2.0).max(80.0)
}

///|
/// 积木分类轨（设计稿 `#catbar`）：**竖排**在画布左侧的 86pt 分类栏，
/// 每行 = 分类色点 + 名称，选中项左侧有一条 2pt 强调边。
///
/// 原来是横排芯片条，改竖排有两个理由：① 设计稿就是这个形态；② 横排会
/// 和画布抢纵向空间（积木视图纵向最紧），竖排把分类放到画布旁边的空白里，
/// 一举两得。
///
/// 「全部」永远可点；具体分类只有**本子程序真的有这类块**时才点亮——灰显
/// 但可点（点了会选中一个空分类，诚实地反映「这里没有块」）。
pub fn category_rail(
  model : Model,
  t : @i18n.Translator,
  height : Double,
) -> @moui.View[Msg] {
  let entries = block_category_entries(model)
  let rows : Array[@moui.View[Msg]] = [
    category_rail_row(
      text(t, "app.blocks.cat.all"),
      ide_text_muted(),
      model.selected_category < 0,
      SelectBlockCategory(-1),
    ),
  ]
  let mut index = 0
  for entry in entries {
    let selected = model.selected_category == index
    let has_blocks = entry.first_index >= 0
    rows.push(
      category_rail_row(
        text(t, block_category_label_key(entry.category)),
        if has_blocks {
          block_category_fill(entry.category)
        } else {
          ide_border()
        },
        selected,
        // 点分类 = 打开该分类的**语句插入面板**（此前只改一个高亮标志位，
        // 画布纹丝不动——分类轨长得像 Scratch 的积木调色板却点不出东西）。
        // 「全部」仍是纯过滤（它没有可插入的语义）。
        ToggleStatementPalette(index),
      ),
    )
    index = index + 1
  }
  let rail = @views.column(rows, spacing=0.0).frame(
    width=CATEGORY_RAIL_WIDTH,
    height~,
  )
  @views.container(
    rail,
    background=ide_panel(),
    width=CATEGORY_RAIL_WIDTH,
    height~,
    padding=0.0,
  )
}

///|
/// 语句插入面板：分类轨旁边拉出的一列骨架卡片。
///
/// 它是「没有 AI 也能写程序」的入口——选中一条骨架即插入到当前块之后。
/// 分类为空（事件分类：事件头由控件决定，不能凭空插入）时给一行明确说明，
/// 而不是留一片空白。
pub fn statement_palette_panel(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let category = category_at(model.selected_category)
  let templates = match category {
    None => ([] : Array[StatementTemplate])
    Some(category) => templates_for_category(category)
  }
  let rows : Array[@moui.View[Msg]] = [
    @views.padding_xy(
      @views.text(
        fit_label(statement_palette_title(t), width - 28.0),
        theme=studio_theme(),
        width=(width - 24.0).max(60.0),
        height=18.0,
        align=TextStart,
      ).foreground(ide_text()),
      horizontal=8.0,
      vertical=0.0,
    ),
  ]
  if templates.length() == 0 {
    rows.push(
      @views.padding_xy(
        hint_lines_view(
          text(t, "app.stmt.palette.empty"),
          width - 24.0,
          ide_text_faint(),
          2,
        ),
        horizontal=8.0,
        vertical=0.0,
      ),
    )
  } else {
    let mut index = 0
    for template in templates {
      let label = text(t, template.label_key)
      rows.push(
        @views.container(
          @views.padding_xy(
            @views.text(
              fit_label(label, width - 24.0),
              theme=studio_theme(),
              width=(width - 20.0).max(60.0),
              height=18.0,
              align=TextStart,
            ).foreground(ide_text()),
            horizontal=8.0,
            vertical=0.0,
          ),
          background=ide_panel_alt(),
          corner_radius=4.0,
          width=(width - 12.0).max(60.0),
          height=28.0,
          padding=0.0,
        )
        .on_tap(InsertStatement(model.selected_category, index))
        .accessibility_label(label),
      )
      index = index + 1
    }
    rows.push(
      @views.padding_xy(
        hint_lines_view(
          text(t, "app.stmt.palette.hint"),
          width - 24.0,
          ide_text_faint(),
          2,
        ),
        horizontal=8.0,
        vertical=0.0,
      ),
    )
  }
  @views.container(
    @views.column(rows, spacing=6.0).frame(width~, height~),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 分类轨宽度（设计稿 `#catbar` 86pt）。
pub const CATEGORY_RAIL_WIDTH : Double = 86.0

///|
/// 语句插入面板的最小宽度（保证骨架标签不被截成一个字）。
pub const STATEMENT_PALETTE_MIN_WIDTH : Double = 132.0

///|
/// 积木画布的最小宽度。低于这个值块内文字必然被裁，不如让面板更窄。
pub const CANVAS_MIN_WIDTH : Double = 120.0

///|
/// 分类轨的一行：2pt 左侧强调边 + 色点 + 名称。
/// 强调边用 `padding_edges` 而不是 border——core 没有单边描边，垫一层
/// 窄容器画背景是这里唯一能表达「左边一条线」的方式。
fn category_rail_row(
  label : String,
  swatch : @core.Color,
  selected : Bool,
  on_click : Msg,
) -> @moui.View[Msg] {
  let content = fill_row(
    [
      @views.container(
        @views.text("", width=1.0, height=1.0),
        background=swatch,
        corner_radius=4.0,
        width=8.0,
        height=8.0,
        padding=0.0,
      ),
      @views.text(
        label,
        theme=studio_theme(),
        width=(CATEGORY_RAIL_WIDTH - 20.0 - 12.0).max(20.0),
        height=16.0,
        align=TextStart,
      ).foreground(if selected { ide_text() } else { ide_text_muted() }),
    ],
    (CATEGORY_RAIL_WIDTH - 14.0).max(40.0),
    7.0,
    Center,
  )
  let inner = @views.padding_edges(
    @views.padding_xy(content, horizontal=8.0, vertical=0.0),
    left=2.0,
  )
  @views.container(
    // 选中：左侧 2pt 强调边铺满行高
    @views.row(
      [
        @views.container(
          @views.text("", width=1.0, height=1.0),
          background=if selected { ide_accent() } else { ide_panel() },
          width=2.0,
          height=24.0,
          padding=0.0,
        ),
        inner,
      ],
      spacing=0.0,
      align=Center,
    ),
    background=if selected { ide_selection() } else { ide_panel() },
    height=24.0,
    width=CATEGORY_RAIL_WIDTH,
    padding=0.0,
  ).on_tap(on_click)
}
