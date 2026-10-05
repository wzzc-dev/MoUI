///|
/// v4 IDE 中心工作区：可视化工作区（Live App 窗格 + 分隔条 + 积木窗格）/
/// 代码工作区（行号 + 高亮 + IR 行尺）/ 空舞台（新建入口）。
///
/// 与旧 center_panel 的分工：旧按 Mode 单一取视图；这里按 WorkSpace 编排
/// 多窗格，运行/帮助/预览三个全屏页仍走旧视图（它们是执行/只读场景）。
/// IR 是唯一事实来源——积木与代码都是投影，代码高亮只影响颜色。

// ============================================================================
// 可视化工作区
// ============================================================================

///|
/// Live App 窗格：设计舞台 / 运行舞台。宽度由 split_ratio 决定，
/// 舞台本身按帧等比缩放（与旧设计视图同一构造，外观零漂移）。
pub fn live_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let head = pane_head(
    text(t, "app.pane.live"),
    if app_running(model) {
      text(t, "app.pane.live.running")
    } else {
      text(t, "app.pane.live.idle")
    },
    width,
    [
      // 「运行中 · N%」：设计稿 runBadge。百分比就是舞台的适应比例——
      // 它是「现在看到的是缩略还是原尺寸」的唯一读数（fit_scale 算得）。
      if app_running(model) {
        run_badge(model, t, width, height)
      } else {
        @views.text("", width=1.0, height=1.0)
      },
      icon_button(
        Focus,
        text(t, "app.pane.solo"),
        false,
        TogglePaneBlocks,
        24.0,
        22.0,
        13.0,
      ),
      // 设计稿每个窗格头都有「隐藏此窗格」（#btnHideLive / #btnHideBlocks）
      icon_button(
        Close,
        text(t, "app.pane.hide"),
        false,
        TogglePaneLive,
        24.0,
        22.0,
        13.0,
      ),
    ],
  )
  // 舞台：运行中显示运行态（解释轨），否则显示设计态。
  //
  // 舞台盒 = 窗格内容区 − 四周呼吸缝（`live_stage_box` 是唯一计算源，
  // `run_badge` 的百分比读数读同一个盒子）。两个分支各自把 box 传给
  // run_stage / 外层 padding，所以「应用窗口」永远浮在一块底板上，
  // 而不是顶满窗格四边。
  let stage_area_height = (height - LIVE_PANE_HEAD_FOOT).max(120.0)
  let (box_w, box_h) = live_stage_box(width - 2.0, stage_area_height)
  let stage = match current_track(model) {
    Interpret =>
      match model.run {
        Some(run) =>
          run_stage(
            model,
            run.state.texts,
            run.checks,
            run.state.rows,
            run.state.selections,
            run.state.vars,
            box_w,
            box_h,
          )
        None => design_stage_view(model, t)
      }
    Compile =>
      match model.compiled_run {
        Some(run) =>
          run_stage(
            model,
            run.runtime.texts,
            run.checks,
            run.runtime.rows,
            run.runtime.selections,
            compiled_values_map(run.runtime),
            box_w,
            box_h,
          )
        None => design_stage_view(model, t)
      }
  }
  @views.container(
    // 列必须显式定尺：内容总高小于容器时容器盒会把整列**居中**，
    // 窗格头就会掉到中间（曾经的「标题浮在半空」现象）。
    @views.column(
      [
        head,
        @views.container(
          // `center` 在更大的帧里拿不到 slack 是空操作，所以呼吸缝用
          // **内垫**表达：帧仍是整格，内容被推进到留白之内。
          @views.padding_xy(
            @views.center(stage, width=box_w, height=box_h),
            horizontal=LIVE_STAGE_INSET_H,
            vertical=LIVE_STAGE_INSET_V,
          ),
          background=ide_editor_background(),
          height=stage_area_height,
          width~,
          padding=0.0,
        ),
        pane_foot(model, t, width),
      ],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// Live App 窗格的「头 + 脚」合计高度（舞台盒从这里扣）。
/// 头 `PANEL_HEAD_HEIGHT`(30) + 脚 24 + 发丝线 2 + 余量 6 = 62。
/// 单独成常量：舞台盒的计算与 `fit_scale` 读数必须同源。
pub const LIVE_PANE_HEAD_FOOT : Double = PANEL_HEAD_HEIGHT + 24.0 + 8.0

///|
/// 舞台四周的呼吸缝（设计稿口径的「画布留白」）。
///
/// 为什么必须有：舞台原本按**整格**可用空间算 fit——640×480 的应用窗口
/// 顶到窗格左右两边，视觉上像「被撑满了」，而不是一块浮在画布上的应用。
/// 成熟设计工具（Figma/IDEA 的预览、Xcode 的 Preview）都在舞台四周留一圈
/// 底板色，既区分「画布」与「应用」，也让缩放比例不至于贴着边缘。
///
/// 16/14 是折中：再大就明显吃掉可用高度（舞台本来就受高度约束）。
pub const LIVE_STAGE_INSET_H : Double = 16.0

///|
/// 舞台上下呼吸缝（见 `LIVE_STAGE_INSET_H`）。
pub const LIVE_STAGE_INSET_V : Double = 14.0

///|
/// 舞台可用盒（**唯一**计算源）：窗格内容区减去四周呼吸缝。
///
/// `live_pane` 的舞台与 `run_badge` 的适应比例读数必须用同一个盒子，
/// 否则徽标上的百分比与实际渲染的缩放对不上（本仓反复踩的「两处各算
/// 一份」）。
pub fn live_stage_box(width : Double, height : Double) -> (Double, Double) {
  (
    (width - LIVE_STAGE_INSET_H * 2.0).max(80.0),
    (height - LIVE_STAGE_INSET_V * 2.0).max(80.0),
  )
}

///|
/// 设计舞台视图（可视化工作区的默认面）：缩放工具条 + 画布。
/// 与旧设计模式同源——只不过这里是窗格而非整列。
fn design_stage_view(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
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
    text(t, "app.design.canvas"),
    text(t, "app.design.empty"),
  )
}

///|
/// 窗格头左右内垫。
pub const PANE_HEAD_INSET : Double = 8.0

///|
/// 窗格头单元格间隙。
pub const PANE_HEAD_GAP : Double = 6.0

///|
/// 窗格头里单个动作的**预留宽**（`icon_button` 一律 24）。
const PANE_HEAD_ACTION_WIDTH : Double = 24.0

///|
/// 一段文字的最小可读宽：低于这个值就整格不画。
/// 60 大约是「4 个全角字 + 省略号」——再窄就只剩省略号，画出来是噪音。
const PANE_HEAD_SUBTITLE_MIN : Double = 60.0

///|
/// `@views.button` 标签两侧的内垫合计（`padding_horizontal × 2`，
/// `spacing_scale.lg = 16`）。
pub const BUTTON_LABEL_PADDING : Double = 32.0

///|
/// 控制字号（`typography.control` = label = 16pt semibold）下每类字符的**上界**
/// 宽：ASCII 8.4、全角 16.0。
///
/// 为什么不复用 `text_estimate_width`（ASCII 7.9 / 全角 13.0）：那个口径是给
/// **正文字号**标定的，用在加粗 16pt 的按钮标签上会明显偏窄。实测：
/// 「应用修改」估 52.0、实际绘制 60.8（窄 17%）；「编译 MoonBit」估 89.2、
/// 实际 97.6（窄 9%）。按它算出的删除按钮盒是 920.72..1013.52，而窗格右缘
/// 1006——超出 7.5pt，按钮被面板裁掉半个词。
///
/// **取上界是刻意的**：`@views.button` 的宽度是 `max(declared, 实测 + 内垫)`，
/// 估宽了只是内垫多几个点（无害），估窄了按钮会自己长出去把兄弟挤出面板
/// （有害，且只在特定语言/宽度下复现）。
const BUTTON_LABEL_ASCII_WIDTH : Double = 8.4

///|
/// 全角字符上界宽（见 `BUTTON_LABEL_ASCII_WIDTH`）。
const BUTTON_LABEL_WIDE_WIDTH : Double = 16.0

///|
/// `@views.button` 放下这个标签所需的**真实**宽度上界。
///
/// `@views.button` 的 `width` 是**最小宽**：`content_width =
/// max(declared, measured_text + padding_horizontal × 2)`。所以写死一个小于
/// `label + 32` 的值，按钮会自己长出去，把它右边的兄弟挤出面板。
///
/// 这是本仓反复踩的坑（顶栏动作簇、积木编辑条各一次），所以统一用这个
/// 函数算——别在调用点写常量。
pub fn button_label_width(label : String) -> Double {
  let mut ascii = 0
  let mut wide = 0
  for c in label {
    if c.to_int() < 0x80 {
      ascii = ascii + 1
    } else {
      wide = wide + 1
    }
  }
  ascii.to_double() * BUTTON_LABEL_ASCII_WIDTH +
  wide.to_double() * BUTTON_LABEL_WIDE_WIDTH +
  BUTTON_LABEL_PADDING
}

///|
/// 窗格头的宽度分配结果。
///
/// 单独一个结构体是为了让「分配」与「建视图」分成两步：**分配逻辑是纯
/// 函数**，可以直接断言，不必从绘制结果反推。
pub(all) struct PaneHeadLayout {
  title_width : Double
  subtitle_width : Double
  tail_width : Double
}

///|
/// 窗格头宽度分配：**唯一**计算源。
///
/// 旧实现把宽度写死（标题 90 / 副标题 120 / 尾巴 140），整行需求与窗格无关，
/// 于是积木窗格头要 `8+8+90+120+(140+24+24)+5×6 = 444`，而窗格只有 ~398——
/// 尾巴被裁 71pt，截图里「IR 映射 · 与代码同步」变成「IR 映射 · 与」。
///
/// **教训：同一行的几个格子绝不能各自算各自的预算。** 第一版把「尾巴」的
/// 预算放进一个独立 helper、`pane_head` 又按 `trailing` 再算一遍动作占位，
/// 两处口径一旦不同就再次溢出（新测试立刻在 1440 宽度抓到 1253.2 > 1166）。
/// 所以整行只在这里分配一次，调用方拿结果建视图。
///
/// 顺序（先扣不可压缩的，再按优先级分）：
/// 1. 每个动作固定 `PANE_HEAD_ACTION_WIDTH`，格子之间固定 `PANE_HEAD_GAP`
///    （含 1 个权重 spacer 的位置）；
/// 2. 标题按内容宽，上限为剩余池的 35%（标题只有 2-4 个字，封顶是为了给
///    后面留位置）；
/// 3. 副标题（状态读数）优先于尾巴（说明文字）；
/// 4. 任何文字格低于 `PANE_HEAD_SUBTITLE_MIN` 就整格不画——宁可少一句
///    说明，也不要画半句被切掉的话。
pub fn pane_head_layout(
  title : String,
  subtitle : String,
  tail : String,
  pane_width : Double,
  action_count : Int,
  actions_width? : Double = -1.0,
) -> PaneHeadLayout {
  let content = (pane_width - PANE_HEAD_INSET * 2.0).max(40.0)
  let has_subtitle = subtitle != ""
  let has_tail = tail != ""
  let text_cells = 1 +
    (if has_subtitle { 1 } else { 0 }) +
    (if has_tail { 1 } else { 0 })
  // 格子数 = 文字格 + 1 个权重 spacer + 动作数；间隙数 = 格子数 − 1
  let cell_count = text_cells + 1 + action_count
  let gaps = (cell_count - 1).max(0).to_double() * PANE_HEAD_GAP
  // 动作宽度默认按图标钮 24/个；动作是**宽芯片**时调用方传实际合计
  //（实测缺陷：代码页签头的外观双芯片 108pt 按两个 24 算，溢出窗格）。
  let actions = if actions_width >= 0.0 {
    actions_width
  } else {
    action_count.to_double() * PANE_HEAD_ACTION_WIDTH
  }
  let pool = (content - gaps - actions).max(0.0)
  let title_want = (text_estimate_width(title) * 1.02).max(20.0)
  let title_width = title_want.min(pool * 0.35)
  let mut left = (pool - title_width).max(0.0)
  let mut subtitle_width = 0.0
  if has_subtitle && left >= PANE_HEAD_SUBTITLE_MIN + PANE_HEAD_GAP {
    left = left - PANE_HEAD_GAP
    let want = (text_estimate_width(subtitle) * 1.02).min(left * 0.5)
    if want < PANE_HEAD_SUBTITLE_MIN {
      // 放不下就整格不画，并把预扣的间隙还回去
      left = left + PANE_HEAD_GAP
    } else {
      subtitle_width = want
      left = (left - want).max(0.0)
    }
  }
  let mut tail_width = 0.0
  if has_tail && left >= PANE_HEAD_SUBTITLE_MIN + PANE_HEAD_GAP {
    tail_width = (left - PANE_HEAD_GAP).max(0.0)
  }
  PaneHeadLayout::{ title_width, subtitle_width, tail_width, }
}

///|
/// 窗格头：标题 + 状态副标题 + 权重 spacer + 可选尾巴文字 + 右侧动作
/// （30pt 高）。
///
/// 宽度分配全部交给 `pane_head_layout`——**这里不做任何算术**，避免
/// 「两处各算一份」再次漂移。
pub fn pane_head(
  title : String,
  subtitle : String,
  width : Double,
  actions : Array[@moui.View[Msg]],
  tail? : String = "",
  actions_width? : Double = -1.0,
) -> @moui.View[Msg] {
  let layout = pane_head_layout(
    title,
    subtitle,
    tail,
    width,
    actions.length(),
    actions_width~,
  )
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      title,
      theme=studio_theme(),
      width=layout.title_width,
      height=18.0,
      align=TextStart,
    ).foreground(ide_text()),
  ]
  if layout.subtitle_width > 0.0 {
    cells.push(
      @views.text(
        fit_label(subtitle, layout.subtitle_width),
        theme=studio_theme(),
        width=layout.subtitle_width,
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
    )
  }
  cells.push(@views.spacer(min_length=0.0, weight=1.0))
  if layout.tail_width > 0.0 {
    cells.push(
      @views.text(
        fit_label(tail, layout.tail_width),
        theme=studio_theme(),
        width=layout.tail_width,
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
    )
  }
  for item in actions {
    cells.push(item)
  }
  @views.container(
    @views.padding_xy(
      fill_row(
        cells,
        (width - PANE_HEAD_INSET * 2.0).max(40.0),
        PANE_HEAD_GAP,
        Center,
      ),
      horizontal=PANE_HEAD_INSET,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
}

///|
/// 「运行中 · N%」徽标（设计稿 `#runBadge`）：绿点 + 单行读数。
/// 百分比是舞台当前的适应比例——`fit_scale` 同一个来源，不另算一份。
fn run_badge(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 读数必须来自**舞台盒**（与 live_pane 同一个 live_stage_box），
  // 否则徽标上的百分比与实际渲染的缩放对不上。
  let live_width = (width * model.split_ratio).max(200.0)
  let (box_w, box_h) = live_stage_box(
    live_width - 2.0,
    (height - LIVE_PANE_HEAD_FOOT).max(120.0),
  )
  let percent = (fit_scale(
    box_w,
    box_h,
    @ir.DESIGN_WIDTH.to_double(),
    @ir.DESIGN_HEIGHT.to_double(),
  ) *
  100.0).round()
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.container(
            @views.text("", width=1.0, height=1.0),
            background=ide_success(),
            corner_radius=3.0,
            width=6.0,
            height=6.0,
            padding=0.0,
          ),
          @views.text(
            text_with(t, "app.pane.live.badge", [
              ("percent", percent.to_int().to_string()),
            ]),
            theme=studio_theme(),
            role=Mono,
            width=84.0,
            height=16.0,
            align=TextStart,
          ).foreground(ide_success()),
        ],
        spacing=5.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_success_soft(),
    corner_radius=9.0,
    height=18.0,
    padding=0.0,
  )
}

///|
/// 可视化工作区脚注：当前子程序 + 事件标签（设计稿的 foot 行）。
pub fn pane_foot(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let label = match current_handler(model) {
    None => text(t, "app.handler.none")
    Some(handler) =>
      "\{handler.control_name} . \{text(t, "event.\{handler.event.tag()}")}"
  }
  // 右侧计数按**文字实测宽**给：写死 90 会把「2 个控件」截掉（实测需要 102）。
  let count_label = text_with(t, "app.pane.foot_controls", [
    ("count", model.program.controls.length().to_string()),
  ])
  let count_w = text_estimate_width(count_label) + 6.0
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.text(
            label,
            theme=studio_theme(),
            width=(width - count_w - 30.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            count_label,
            theme=studio_theme(),
            role=Mono,
            width=count_w,
            height=16.0,
            align=TextEnd,
          ).foreground(ide_text_faint()),
        ],
        (width - 16.0).max(80.0),
        6.0,
        Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=24.0,
    width~,
    padding=0.0,
  )
}

///|
/// 积木窗格「该不该在场」。
///
/// **只有选中事件子程序时才需要积木。** 积木是 `Handler.body` 的投影，所以
/// 没有选中子程序时它必然是一块空画布——那既占掉一半中心列，又什么都没有，
/// 用户还得手动关掉它。判据取自「选中态」而不是「有没有块」：新建的空子程序
/// 也要显示积木窗格（用户正要在那里加块），但没选子程序时一块都不该显示。
///
/// `model.pane_blocks` 是**用户显式开关**：它只能在「需要积木」时把窗格关掉
/// （用户说不要），不能把不需要的窗格打开——否则一次误点之后，切回控件也会
/// 一直挂着空画布。
pub fn blocks_pane_wanted(model : Model) -> Bool {
  model.pane_blocks && current_handler(model) is Some(_)
}

///|
/// 可视化工作区：Live App 窗格 + 5pt 分隔条 + 积木窗格。
/// 分隔条用 on_drag_with_frame 换算成比例（0.2–0.8，update 侧钳制）。
///
/// **单窗格时不加任何「恢复带」。** 早先实现过一条顶部「+ 另一个窗格」的
/// 按钮带，那是我自己加的、设计稿里没有的东西——它在 Live App 头上凭空多压
/// 一条工具带，视觉噪音大且挤掉舞台高度。设计稿的规则更干净：
/// `btnHideLive`/`btnHideBlocks` 关掉**最后一个**窗格时直接进**空舞台**，
/// 而空舞台自带 `+ Live App` / `+ 积木` 两个入口（见 `empty_stage`）。
/// 少一个窗格时把剩下的那个占满即可，恢复入口统一在空舞台那一条路径上。
pub fn visual_workspace(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let want_blocks = blocks_pane_wanted(model)
  // 两个都关掉 → 空舞台（它带恢复入口）。判据与设计稿一致：
  // 「关掉最后一个窗格就进 empty」。
  if !model.pane_live && !want_blocks {
    return empty_stage(model, t, width, height)
  }
  // 只剩一个窗格：占满整个中心列，不加恢复带。
  if !want_blocks {
    return live_pane(model, t, width, height)
  }
  if !model.pane_live {
    return blocks_pane(model, t, width, height)
  }
  // 双窗格有最小可用宽度：640 设计宽按 fit_scale 的 0.5 下限缩放后仍需
  // ~320pt 才放得下，积木画布同理。中心列窄到放不下两个窗格时**只显示
  // Live App**——把积木窗格压到 160pt 只会让里面的积木文字被裁掉
  // （实测 w=900 时积木窗格 160pt、块内文字 410pt 宽被切）。
  let live_min = 320.0
  let blocks_min = 240.0
  let gap = 5.0
  if width < live_min + blocks_min + gap {
    return live_pane(model, t, width, height)
  }
  // 占比也要钳：拖拽后任一侧都不得小于各自下限。
  let max_live = width - blocks_min - gap
  let live_width = (width * model.split_ratio).max(live_min).min(max_live)
  let rest = (width - live_width - gap).max(blocks_min)
  @views.row(
    [
      live_pane(model, t, live_width, height),
      splitter(live_width, width),
      blocks_pane(model, t, rest, height),
    ],
    spacing=0.0,
    align=Start,
  ).frame(width~, height~)
}

///|
/// 分隔条：5pt 竖条，拖拽改 Live App 窗格占比。
/// 拖拽起点用 history 无关的绝对换算——on_drag_with_frame 给全局坐标，
/// 减去行原点即得窗格内 x；除以总宽得比例。
pub fn splitter(live_width : Double, total_width : Double) -> @moui.View[Msg] {
  let base = @views.container(
    @views.center(
      @views.text("", width=1.0, height=24.0),
      width=5.0,
      height=24.0,
    ),
    background=ide_panel(),
    width=5.0,
    height=600.0,
    padding=0.0,
  )
  let _ = live_width
  base.on_drag_with_frame(fn(event, frame) {
    let _ = event
    // 拖到哪算哪：全局 x − 帧原点 = 该点在行内的 x
    SetSplitRatio((event.position.x - frame.origin.x) / total_width)
  })
}
