///|
/// 积木窗格：分类轨 + 积木画布 + 脚注 + 语句编辑条。
///
/// 从 `workspace.mbt` 拆出来（该文件已到 1200 行硬上限）：积木窗格与代码
/// 窗格是两条独立的展示路径，按「窗格」拆文件比按「视图/辅助」拆更贴近
/// 阅读顺序。

///|
/// 积木窗格：分类条 + 积木画布 + 语句编辑条。
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
  let body_height = (height - 130.0).max(80.0)
  let catbar = category_rail(model, t, body_height)
  let canvas_width = (width - CATEGORY_RAIL_WIDTH - 2.0).max(120.0)
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
      let canvas_height = (rects.length().to_double() * BLOCK_ROW_HEIGHT + 24.0).max(
        120.0,
      )
      let spotlight = current_spotlight(model)
      @views.scroll_view(
        blocks_canvas(
          blocks,
          display_texts,
          model.selected_block,
          spotlight,
          model.block_drag,
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
  let body = @views.row([catbar, canvas], spacing=0.0, align=Start)
  @views.container(
    @views.column(
      // 积木窗格脚注（设计稿 #blocksFoot，24pt）：灯泡 + 一句「画布底部已为
      // AI 层预留避让通道 · 悬停积木查看 ↔ 行映射」。它同时解释了画布底部
      // 那段留白是**有意的避让通道**，不是漏排。
      [
        head,
        body,
        blocks_foot_hint(t, width),
        block_editor_bar(model, t, width),
      ],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
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
        SelectBlockCategory(index),
      ),
    )
    index = index + 1
  }
  @views.container(
    @views.column(rows, spacing=0.0).frame(width=CATEGORY_RAIL_WIDTH, height~),
    background=ide_panel(),
    width=CATEGORY_RAIL_WIDTH,
    height~,
    padding=0.0,
  )
}

///|
/// 分类轨宽度（设计稿 `#catbar` 86pt）。
pub const CATEGORY_RAIL_WIDTH : Double = 86.0

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
/// 积木窗格脚注（设计稿 `#blocksFoot`）：11pt 图标 + 一句提示。
///
/// 文案用 `fit_label` 按可用宽截断：中文提示在窄窗格里放不下，直接画会
/// **穿过窗格边界**到隔壁 Live App 窗格上（实测文字右缘 1013 > 窗格右缘
/// 1004，被硬切在半个字上）。这里和积木块标签共用同一套省略号口径。
fn blocks_foot_hint(t : @i18n.Translator, width : Double) -> @moui.View[Msg] {
  // 让出图标(11) + 行内间距(6) + 左右内垫(20) + 估算误差余量(10)
  let text_width = (width - 48.0).max(40.0)
  let label = fit_label(text(t, "app.blocks.foot_hint"), text_width)
  @views.container(
    fill_row(
      [
        @views.icon(Info, size=11.0, color=ide_text_faint()),
        @views.text(
          label,
          theme=studio_theme(),
          width=text_width,
          height=15.0,
          align=TextStart,
        ).foreground(ide_text_faint()),
      ],
      (width - 20.0).max(60.0),
      6.0,
      Start,
    ),
    background=ide_panel(),
    height=24.0,
    width~,
    padding=0.0,
  )
}

///|
/// 积木编辑条：选中块的语句草稿 + 应用/删除（旧 blocks_panel 的编辑区，
/// 移入窗格脚注以把纵向空间还给画布）。
fn block_editor_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let blocks = match current_handler(model) {
    None => ([] : Array[@blocks.BlockItem])
    Some(handler) => @blocks.block_chain(handler.body)
  }
  if model.selected_block < 0 || model.selected_block >= blocks.length() {
    return @views.container(
      @views.text(
        text(t, "app.blocks.reorder_hint"),
        theme=studio_theme(),
        width=(width - 20.0).max(60.0),
        height=26.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
      background=ide_panel(),
      height=30.0,
      width~,
      padding=0.0,
    )
  }
  // 按钮宽度**必须按标签算**，不能写死 64：`@views.button` 的 `width` 是
  // **最小宽**，内容超了它会自己长大（内垫 `padding_horizontal×2 = 32`）。
  // 「应用修改 / 删除语句」各需 ~84pt，写死 64 时真实总宽 =
  // `16 + (w−190) + 84 + 84 + 12 = w + 6`——超出 6pt，最右那颗按钮被面板
  // 裁掉半个词（实际截图里「删除语句」只露出左边一半）。
  //
  // 这里把两个按钮的真实宽度算出来，再用剩余空间给输入框——顺序反过来
  // （先给输入框固定的 w−190）就一定会挤掉按钮。
  let apply_w = button_label_width(text(t, "app.block.apply"))
  let delete_w = button_label_width(text(t, "app.block.delete"))
  let draft_w = (width - 16.0 - apply_w - delete_w - 12.0).max(60.0)
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.text_area(
            model.block_draft,
            on_input=source => EditBlock(source),
            lines=1,
            width=draft_w,
            line_height=24.0,
          ),
          @views.button(
            text(t, "app.block.apply"),
            on_click=CommitBlock,
            variant=Primary,
            width=apply_w,
            height=26.0,
          ),
          @views.button(
            text(t, "app.block.delete"),
            on_click=DeleteBlock,
            variant=Outline,
            width=delete_w,
            height=26.0,
          ),
        ],
        spacing=6.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=34.0,
    width~,
    padding=0.0,
  )
}
