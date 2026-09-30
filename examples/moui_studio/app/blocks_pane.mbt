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
      // 落槽指示线一次算好（链条坐标），两段画布各取所需
      let mark = blocks_insert_mark(blocks, rects, model.block_drag)
      let spotlight = current_spotlight(model)
      let sel = model.selected_block
      let editing = sel >= 0 && sel < blocks.length() && blocks[sel].path.length() > 0
      if editing {
        // Scratch/Blockly 的就地编辑口径：编辑器**嵌在链条里**——画布在
        // 选中块处拆成上下两段，编辑卡夹在中间（真实视图行，全宽）。
        // 拆段只在选中变化（两次手势之间）发生；拖拽全程布局稳定，
        // 指针捕获不会丢。
        let seg1_count = sel + 1
        let tail_count = blocks.length() - seg1_count
        // 下段本地 y=0 的链条原点：下段首行链上顶缘 − 行顶部边距
        // （行顶部边距取自首行矩形，避免跨文件引画布私有常量）。
        // 选中块是链尾时没有下段，原点保持 0（不参与任何换算）。
        let seg2_origin = if tail_count > 0 {
          rects[seg1_count].origin.y - rects[0].origin.y
        } else {
          0.0
        }
        // 段高从链条矩形反推：上段 = 选中块底缘 + 6pt 呼吸缝；下段与
        // 整链画布同一尾部口径（末块底缘 + 20pt），但要从链条坐标减去
        // 下段原点换算成本地高度。
        let seg1_h = rects[sel].max_y() + 6.0
        let seg2_h = if tail_count > 0 {
          rects[blocks.length() - 1].max_y() - seg2_origin + 20.0
        } else {
          0.0
        }
        // 落槽指示线按段归属：链上 y 落在上段范围（含其底缝）归上段，
        // 否则换算成下段本地 y。±6pt 的判据覆盖「行上/行下 3pt」两种落点。
        // 没有下段时指示线全部归上段（画到链尾）。
        let mark1 = match mark {
          Some((y, w)) =>
            if tail_count == 0 || y < seg2_origin - 6.0 {
              Some((y, w))
            } else {
              None
            }
          None => None
        }
        let mark2 = match mark {
          Some((y, w)) => {
            let local_y = y - seg2_origin
            if tail_count > 0 && local_y >= -6.0 {
              Some((local_y, w))
            } else {
              None
            }
          }
          None => None
        }
        let head_texts : Array[String] = []
        let head_blocks : Array[@blocks.BlockItem] = []
        for i in 0..<seg1_count {
          head_blocks.push(blocks[i])
          head_texts.push(display_texts[i])
        }
        let seg1 = blocks_canvas(
          head_blocks,
          head_texts,
          sel,
          spotlight,
          mark1,
          canvas_width,
          seg1_h,
          text(t, "app.blocks.canvas"),
        )
        let editor = block_editor_row(model, t, blocks[sel].kind, canvas_width)
        let parts : Array[@moui.View[Msg]] = [seg1, editor]
        if tail_count > 0 {
          let tail_texts : Array[String] = []
          let tail_blocks : Array[@blocks.BlockItem] = []
          for i in seg1_count..<blocks.length() {
            tail_blocks.push(blocks[i])
            tail_texts.push(display_texts[i])
          }
          parts.push(
            blocks_canvas(
              tail_blocks,
              tail_texts,
              -1,
              spotlight,
              mark2,
              canvas_width,
              seg2_h,
              text(t, "app.blocks.canvas"),
              y_offset=seg2_origin,
            ),
          )
        }
        // 画布内容至少占满视口（scroll_view 会把**短于视口**的子节点垂直
        // 居中——块链必须永远从顶部开始排）：给列追加一段视口剩余高的
        // 透明填充，列的测量高 ≥ 视口高，居中就没有了施展空间。
        let content_height = seg1_h + BLOCK_EDITOR_ROW_HEIGHT + seg2_h
        let filler_h = (body_height - content_height).max(0.0)
        if filler_h > 0.0 {
          parts.push(
            @views.container(
              @views.text("", width=1.0, height=1.0),
              width=canvas_width,
              height=filler_h,
              padding=0.0,
            ),
          )
        }
        @views.scroll_view(
          @views.column(parts, spacing=0.0),
          width=canvas_width,
          height=body_height,
          shows_indicator=true,
        )
      } else {
        // 画布高度 = max(内容高, 视口高)：scroll_view 会把**短于视口**的子
        // 节点垂直居中——块链一短就悬浮在画布中段（Scratch 是顶对齐的）。
        // 让画布节点至少占满视口，块永远从顶部开始排。
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
  }
  let body = @views.row([catbar, canvas], spacing=0.0, align=Start)
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
/// 编辑卡行高：卡体 34pt（与积木行同高）+ 底部 12pt 间隔。上方的 6pt
/// 呼吸缝由上段画布的段高给出。
pub const BLOCK_EDITOR_ROW_HEIGHT : Double = 46.0

///|
/// 积木编辑卡（Scratch/Blockly 的就地字段编辑口径）：选中块的语句编辑器
/// **嵌在链条里**——画布在选中块处拆成两段，本卡片夹在中间，不再占用
/// 窗格底部常驻高度，也不再被两个文字按钮挤成一条 90pt 的缝隙（旧编辑
/// 条的输入框在窄窗格下只剩「变量 序号 =」能看到）。
///
/// 卡内：分类色徽章（本块的种类，与上方积木同色）+ 全宽单行 DSL 编辑框
/// （Enter 提交）+ 三个图标动作：应用 / 复制语句 / 删除语句。
fn block_editor_row(
  model : Model,
  t : @i18n.Translator,
  kind : @blocks.BlockKind,
  width : Double,
) -> @moui.View[Msg] {
  let label = text(t, @blocks.block_label_key(kind))
  // 徽章宽按标签算（中英混排，同 `button_label_width` 口径），不写死：
  // 「否则如果」比「否则」宽一倍，写死会截字。
  let chip_w = button_label_width(label).max(40.0)
  let icon_w = 26.0
  // 卡体内部预算：卡宽 = 画布宽 − 20（左右各 10 外边距）；内垫左右各 8；
  // 徽章 + 输入框 + 三颗图标 + 间距 4×8。输入框吃剩余全部宽度——预算
  // 必须从**卡宽**起算，从画布宽起算会让行比卡宽 4pt，末位图标被推出
  // 圆角边缘（顶栏动作簇踩过的同一个坑：先定输入框宽必挤掉图标，
  // 顺序反过来才对）。
  let card_w = (width - 20.0).max(120.0)
  let field_w = (card_w - 16.0 - chip_w - icon_w * 3.0 - 32.0).max(80.0)
  let card = @views.container(
    @views.padding_xy(
      @views.row(
      [
        @views.container(
          @views.center(
            @views.text(label, theme=studio_theme(), width=chip_w - 8.0, height=16.0).foreground(
              block_text_color(),
            ),
            width=chip_w,
            height=22.0,
          ),
          background=block_fill(kind),
          corner_radius=4.0,
          width=chip_w,
          height=22.0,
          padding=0.0,
        ),
        // 单行语句编辑用 text_field：原生单行控件（自带水平滚动），
        // Enter 直接应用草稿（text_area 的 8pt×2 垂直内垫会竖切字形）。
        @views.text_field(
          model.block_draft,
          on_input=source => EditBlock(source),
          on_submit=Some(CommitBlock),
          placeholder=text(t, "app.block.editor_hint"),
          variant=Outline,
          width=field_w,
          height=FIELD_HEIGHT,
        ),
        ghost_icon_button(
          Check,
          text(t, "app.block.apply"),
          false,
          CommitBlock,
          icon_w,
          icon_w,
          14.0,
          ide_elevated(),
        ),
        ghost_icon_button(
          Clipboard,
          text(t, "app.block.duplicate"),
          false,
          DuplicateBlock,
          icon_w,
          icon_w,
          14.0,
          ide_elevated(),
        ),
        ghost_icon_button(
          Trash,
          text(t, "app.block.delete"),
          false,
          DeleteBlock,
          icon_w,
          icon_w,
          14.0,
          ide_elevated(),
        ),
      ],
      spacing=8.0,
      align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_elevated(),
    corner_radius=8.0,
    width=card_w,
    height=34.0,
    padding=0.0,
  )
  @views.container(
    @views.padding_xy(card, horizontal=10.0, vertical=0.0),
    width~,
    height=BLOCK_EDITOR_ROW_HEIGHT,
    padding=0.0,
  )
}
