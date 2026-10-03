///|
/// 积木窗格：分类轨 + 积木画布（选中块处就地展开编辑卡）。
///
/// 从 `workspace.mbt` 拆出来（该文件已到 1200 行硬上限）：积木窗格与代码
/// 窗格是两条独立的展示路径，按「窗格」拆文件比按「视图/辅助」拆更贴近
/// 阅读顺序。

///|
/// 积木行的**展示文本**与**引导文本**（一份产出，两处消费）：
/// - 展示 = 引导 + 语句文本——画布上的整行文字；
/// - 引导 = 本地化标签 + 两个空格——插槽洞的游标从它的宽度之后开始累加
///   段宽，所以洞要落在字形上就必须与展示**同源**（两处各拼会错位）。
///   语句文本为空的行（装饰块）没有段，引导为空串。
///
/// 画布绘制（`blocks_canvas` 的 `display_texts`/`lead_texts`）与 update 层
/// 的命中测试（`blocks_hit_index` 的 `display_texts`）都必须吃这一份。
pub fn block_row_texts(
  t : @i18n.Translator,
  blocks : Array[@blocks.BlockItem],
) -> (Array[String], Array[String]) {
  let display : Array[String] = []
  let lead : Array[String] = []
  for item in blocks {
    let label = text(t, @blocks.block_label_key(item.kind))
    if item.text == "" {
      display.push(label)
      lead.push("")
    } else {
      display.push("\{label}  \{item.text}")
      lead.push("\{label}  ")
    }
  }
  (display, lead)
}

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
      let (display_texts, lead_texts) = block_row_texts(t, blocks)
      // 落槽指示线一次算好（链条坐标）。矩形必须与画布绘制**同一组入参**
      // （真实画布宽 + 展示文本）：块宽随内容收紧后，宽度进了几何，
      // 两处各算一份宽度，指示线与块体就对不上了。
      let rects = blocks_item_rects(
        blocks,
        avail_width=canvas_width,
        display_texts~,
      )
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
      // **脚本说明横幅**：有说明时在积木链上方留出一条，并把同一高度
      // 加进画布高度——两处不一致会让横幅被裁掉（画布太矮）或与第一块
      // 积木重叠（偏移与高度不匹配）。
      let script_note = target_note(model)
      let note_height = if script_note == "" { 0.0 } else { BLOCKS_NOTE_HEIGHT }
      let canvas_height = (rects.length().to_double() * BLOCK_ROW_HEIGHT +
        24.0 + note_height)
        .max(body_height)
        .max(120.0)
      // **画布不再自带上下文菜单宿主**：菜单改由**顶层**
      // `studio_overlay_host`（viewport 大小）承载。
      //
      // 为什么必须搬到顶层：`context_menu_region` 用的是 `popup_host`
      // （`BaseSized`），宿主只有**窗格那么大**（实测屏障 233×536），
      // 于是「点别处关闭」的屏障最多只盖住这一个窗格——在窗口其它任何
      // 地方点，指针根本到不了屏障，菜单**永远不消失**（用户报的缺陷）。
      // 屏障要覆盖整个窗口，宿主就必须是 viewport 大小的那一层。
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
          palette_drag=model.palette_drag is Some(_),
          expr_drag=model.expr_drag is Some(_),
          script_note~,
          note_height~,
          lead_texts~,
        ),
        width=canvas_width,
        height=body_height,
        // **受控滚动**：偏移来自模型，拖到边缘时由 `BlocksAutoScroll`
        // 推进。不受控的话自动滚动无处落笔（滚动位置是控件内部状态，
        // update 层看不到也改不了）。
        offset=@core.Point::new(
          x=0.0,
          y=model.blocks_scroll_y,
        ),
        // 手动滚动要回报，否则下一次重渲会把用户滚到的位置弹回模型值。
        on_scroll=Some(offset => BlocksScrolled(offset.y)),
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
  // **变量分类里给出「新建变量」入口**（Scratch 的「建立一个变量」按钮）。
  //
  // 为什么必须在这里：此前新建变量只能去左栏结构树的「+」——而用户此刻
  // 正在积木画布上想加一个变量，视线与心智都在这里。Scratch 把入口放在
  // 变量分类底部正是这个理由。复用既有的 `AddVariable`（自动命名、过撤销
  // 点），不新开一条创建路径。
  if category is Some(@blocks.CatVariable) {
    rows.push(
      @views.container(
        @views.padding_xy(
          @views.text(
            fit_label(text(t, "app.variable.new"), width - 24.0),
            theme=studio_theme(),
            width=(width - 20.0).max(60.0),
            height=18.0,
            align=TextStart,
          ).foreground(ide_accent()),
          horizontal=8.0,
          vertical=0.0,
        ),
        background=ide_panel_alt(),
        corner_radius=4.0,
        width=(width - 12.0).max(60.0),
        height=28.0,
        padding=0.0,
      )
      .on_tap(AddVariable)
      .accessibility_label(text(t, "app.variable.new")),
    )
  }
  // **报告块**（运算分类）：这些是**表达式**，只作为洞里的内容。
  //
  // 与语句骨架分开渲染的理由：报告块不能「插一行」（`1 + 1` 单独成句在
  // 语言里非法），所以它们没有点击插入，只有拖拽——面板上给出这条提示，
  // 否则用户点了没反应会以为坏了。
  if category is Some(@blocks.CatExpression) {
    rows.push(
      @views.padding_xy(
        hint_lines_view(
          text(t, "app.expr.palette.hint"),
          width - 24.0,
          ide_text_faint(),
          2,
        ),
        horizontal=8.0,
        vertical=0.0,
      ),
    )
    let mut expr_index = 0
    for template in expression_templates() {
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
        // 只可拖，不可点：表达式不能单独成句。拖动时记下模板下标，
        // 落点（哪个洞）由画布侧按指针算。
        .on_drag(_event => PaletteExprDragStart(expr_index))
        .accessibility_label(label),
      )
      expr_index = expr_index + 1
    }
  }
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
        // 拖动 = 从调色板拖到画布（Scratch 的字面手势）。这里只记下
        // 「拖动源」，落点由画布侧按指针算——两个视图互相看不到对方的帧。
        .on_drag(
          _event => PaletteDragStart(model.selected_category, index),
        )
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

///|
/// 积木右键菜单（Scratch/IDE 口径）。
///
/// 动作全部复用**既有消息**——`DuplicateBlock` / `DeleteBlock` 已经是右栏
/// 编辑卡上的按钮载体，这里只是把同一批动作搬到指针处。**不新开执行路径**：
/// 菜单是「同一动作的第二个入口」，不是第二套语义。
///
/// 每一项都先发 `BlocksContextMenuClose`（见各行的 `on_tap` 串联）——
/// 点完不关菜单，用户会以为没生效。
pub fn block_context_menu(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let has_block = model.selected_block >= 0
  let rows : Array[@moui.View[Msg]] = []
  if has_block {
    // 「运行这一块」放最前：Scratch 里点击积木的直接动作就是运行。
    rows.push(
      menu_action_row(
        text(t, "app.run.single"),
        ide_success(),
        RunSingleBlock,
        true,
      ),
    )
    rows.push(
      menu_action_row(
        text(t, "app.block.duplicate"),
        ide_text(),
        DuplicateBlock,
        true,
      ),
    )
    rows.push(
      menu_action_row(
        text(t, "app.block.delete"),
        ide_danger(),
        DeleteBlock,
        true,
      ),
    )
  } else {
    // 点空白处：给画布级动作（至少要有可插入语句的入口，否则菜单是空的）
    rows.push(
      menu_action_row(
        text(t, "app.blocks.rail.hint"),
        ide_text_muted(),
        ToggleStatementPalette(model.selected_category),
        true,
      ),
    )
  }
  @views.container(
    @views.column(rows, spacing=0.0),
    background=ide_panel_alt(),
    corner_radius=6.0,
    width=168.0,
    padding=0.0,
  )
}

///|
/// 菜单行：文字 + 点击派发。动作后**先关菜单**再执行——菜单留着会挡住
/// 结果（删除后菜单还悬在那里，用户以为没删掉）。
fn menu_action_row(
  label : String,
  color : @core.Color,
  action : Msg,
  enabled : Bool,
) -> @moui.View[Msg] {
  @views.container(
    @views.padding_xy(
      @views.text(
        fit_label(label, 140.0),
        theme=studio_theme(),
        width=140.0,
        height=18.0,
        align=TextStart,
      ).foreground(if enabled { color } else { ide_text_faint() }),
      horizontal=12.0,
      vertical=0.0,
    ),
    height=28.0,
    width=168.0,
    padding=0.0,
  ).on_tap(
    // 禁用项也要能点（关掉菜单），所以包一层而不是挂 Noop。
    if enabled { BlocksMenuAction(action) } else { BlocksContextMenuClose },
  )
}
