///|
/// v4 IDE 壳装配：顶栏 40 / 图标栏 48 / 左栏 / 中心工作区 / 右栏 /
/// 底栏（审计 + Console）/ 状态栏 / AI 浮动层 / 对话框与 toast。
///
/// 布局纪律（三条硬约束，都是踩过的坑）：
/// 1. row 里的竖直分隔线必须显式 axis=Vertical——横线按可用宽度测量，
///    会盖住后面的兄弟（2026-09-27 面板消失事故）。
/// 2. 含分隔线的行必须钳高（.frame(height=…)）——竖直分隔线按可用高度
///    测量，不钳会把行撑到窗口高。
/// 3. 交互画布子树不用 .flexible()——加权子树的指针派发会在 tight 重排
///    下丢手势；用显式 .frame(height=…) 换空间。

// ============================================================================
// 顶栏（40pt 单行）
// ============================================================================

///|
/// 顶栏右侧动作簇的簇内间隙。
pub const TOPBAR_ACTION_GAP : Double = 6.0

///|
/// 顶栏图标按钮的**实际渲染宽**。
///
/// 不能用更小的声明值：`@views.button` 的 `content_width` 是
/// `max(declared, measured_text + padding_horizontal × 2)`，而
/// `studio_theme` 的 `spacing_scale.lg = 16`，所以空标签按钮的**硬下限是
/// 32**（实测：声明 26 渲染 32）。拖拽区预算按 26 算就会少算 6pt/个，
/// 三个按钮少算 16pt，拖拽区直接盖住最左侧的运行按钮——只在原生无框窗口
/// 复现，点运行变成拖窗口。这条正是既有回归测试抓到的。
pub const TOPBAR_ICON_BUTTON_WIDTH : Double = 32.0

///|
/// 动作簇预算的安全余量。渲染宽与预算**恰好相等**时，任何文案变长或内垫
/// 微调都会立刻让拖拽区盖住按钮；留一点余量让「低估」不可能发生
/// （高估只少几个点可拖，低估直接废掉按钮——两种误差代价极不对称）。
pub const TOPBAR_ACTIONS_SAFETY : Double = 8.0

///|
/// 撤销/重做快捷键。**必须两个修饰键各注册一份**：
/// `KeyboardShortcut::matches` 是 `event.modifiers == self.modifiers` 的
/// 精确相等比较，macOS 发 meta、Windows/Linux 发 control——只注册一个
/// 就会有一整端按不动，而且本机测不出来。
///
/// 重做在 macOS 的主流口径是 `Cmd+Shift+Z`（`Cmd+Y` 是 Windows 习惯），
/// 这里跟随平台习惯；两者都注册会让 Shift 组合与单 Shift 判别变复杂，
/// 收益不抵成本。

///|
/// 运行/停止芯片标签：运行中变停止。宽度计算与渲染共用同一来源。
fn run_label(model : Model, t : @i18n.Translator) -> String {
  if app_running(model) {
    text(t, "app.run.stop")
  } else {
    text(t, "app.run.start")
  }
}

///|
/// 顶栏右侧动作簇总宽的**保守上界**（含簇内间隙，不含容器右内垫）。
///
/// **渲染与拖拽区声明共用这一个函数**。两处各算一份就会出现「按钮被拖拽区
/// 盖住」的漂移——本仓已经为同类「两处各算一份」付出过代价（浮动卡高度、
/// 树行元信息宽度），所以这里只留一个计算源。
pub fn topbar_actions_width(model : Model, t : @i18n.Translator) -> Double {
  topbar_chip_bound(run_label(model, t), 56.0) +
  topbar_chip_bound(text(t, "app.run.step"), 48.0) +
  topbar_chip_bound(text(t, "app.topbar.compile"), 72.0) +
  // 图标簇：撤销/重做/搜索（32）+ 底栏/右栏开关（28）+ 设置（28）
  TOPBAR_ICON_BUTTON_WIDTH * 3.0 +
  28.0 * 3.0 +
  TOPBAR_ACTION_GAP * 8.0 +
  TOPBAR_ACTIONS_SAFETY
}

///|
/// 左上角左栏开关占据的宽度（VS Code 口径:信号灯后的第一个窗控钮）。
/// 拖拽区必须从它右侧开始,否则点开关会变成拖窗口（原生无边框窗口实测）。
pub const TOPBAR_LEFT_TOGGLE_ZONE : Double = 34.0

///|
/// 拖拽区起点（绝对 x）：顶栏行起点 + 左栏开关带宽。
pub fn topbar_drag_x(model : Model) -> Double {
  (if model.immersive {
    TRAFFIC_LIGHT_INSET
  } else {
    10.0
  }) + TOPBAR_LEFT_TOGGLE_ZONE
}

///|
/// 沉浸式标题栏里**可拖拽**的宽度：从窗口左缘到动作簇左缘为止。
///
/// 为什么必须显式让开动作簇：AppKit presenter 命中拖拽区时直接
/// `performWindowDragWithEvent:` 并 return，事件**不再进入运行时**——拖拽区
/// 一旦盖住运行/单步/编译，点它们就会变成拖窗口，表现成「按钮点了没反应」。
/// 这种缺陷只在原生无边框窗口里出现，绘制断言完全抓不到。
///
/// 这个函数是**唯一**计算源：视图布局（右内垫 10 + 动作簇贴右）与入口的
/// 拖拽声明都走它，两边不会漂移。返回值恰好等于动作簇左缘的 x。
pub fn topbar_drag_width(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> Double {
  // 从左栏开关右侧到动作簇左缘。**宽度从 drag_x 起算**（矩形 x = drag_x）:
  // 若再减 LEFT_TOGGLE_ZONE,拖拽区右缘会越过动作簇,运行/单步/编译
  // 被拖拽区盖住——点击变成拖窗口（原生无边框窗口实测缺陷）。
  (width - topbar_drag_x(model) - 10.0 - topbar_actions_width(model, t)).max(
    0.0,
  )
}

///|
/// 顶栏：品牌 + 面包屑 | 运行/单步/编译 | 语言 | 命令面板 | 设置。
///
/// **沉浸式下这一条就是窗口标题栏本身**：不再有额外的窗控带。旧实现是
/// 「26pt 窗控带（只有一句居中提示文字、底色更深）+ 40pt 顶栏」两条，交界处
/// 一条两截色缝加半条空带，看起来就是「顶上的边框没沉浸」。合并后：
/// 左侧让出 `TRAFFIC_LIGHT_INSET` 给原生信号灯，其余照常放品牌与动作，
/// 底色与内容区一致（`ide_panel()`），整条读起来是一个窗口头。
///
/// 非沉浸态（Web 入口没有窗口头可言）保持设计稿的 40pt 与 10pt 内垫。
pub fn ide_top_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let running = app_running(model)
  let crumb = match model.workspace {
    WsVisual => text(t, "app.crumb.visual")
    WsCode => "\{text(t, "app.crumb.code")} › \{handler_crumb(model)}"
    WsPreview => text(t, "app.ws.preview")
    WsEmpty => text(t, "app.crumb.empty")
  }
  // 左上角：左栏收起/展开（VS Code 的侧栏开关口径,信号灯后第一钮）。
  let left = @views.row(
    [
      icon_button(
        Sidebar,
        text(t, "app.topbar.left_panel"),
        !(model.left_view is LeftHidden),
        StudioCommandRun("studio.left.toggle"),
        28.0,
        26.0,
        14.0,
      ),
      topbar_brand(text(t, "app.title"), model.dirty, crumb),
    ],
    spacing=8.0,
    align=Center,
  )
  // 动作簇：24pt 紧凑芯片（IDEA/VSCode 标题栏口径）。运行是唯一主行动作
  // （强调色填充）；单步仅在活运行（含闸门暂停）时可用——编译轨不支持单步，
  // 芯片仍显示但禁用（诚实反映「本轨没有单步」而不是藏起来）。
  let right : Array[@moui.View[Msg]] = [
    // 运行/停止：运行中变停止（同一键位的心智：它是「运行」的总闸）
    topbar_action(
      run_label(model, t),
      if running {
        Some(RunStop)
      } else {
        Some(RunStart)
      },
      !running,
      topbar_chip_bound(run_label(model, t), 56.0),
    ),
    topbar_action(
      text(t, "app.run.step"),
      if running && current_track(model) is Interpret {
        Some(RunStep)
      } else {
        None
      },
      false,
      topbar_chip_bound(text(t, "app.run.step"), 48.0),
    ),
    topbar_action(
      text(t, "app.topbar.compile"),
      Some(CompileRun),
      false,
      topbar_chip_bound(text(t, "app.topbar.compile"), 72.0),
    ),
    // 撤销/重做：必须有键位（Ctrl/Cmd+Z、Ctrl/Cmd+Shift+Z），且两个修饰键
    // 各注册一份——`KeyboardShortcut::matches` 是修饰键**精确相等**，
    // macOS 走 meta、Windows/Linux 走 control，只注册一个就会有一端失灵。
    icon_button(
      ChevronLeft,
      text(t, "app.edit.undo"),
      false,
      Undo,
      32.0,
      26.0,
      14.0,
    ),
    icon_button(
      ChevronRight,
      text(t, "app.edit.redo"),
      false,
      Redo,
      32.0,
      26.0,
      14.0,
    ),
    // 命令面板：Ctrl/Cmd+K（快捷键走全局命令表；设置面板负责语言切换）
    icon_button(
      Search,
      text(t, "app.command.open"),
      model.command_palette_open,
      CommandPaletteOpen,
      32.0,
      26.0,
      14.0,
    ),
    icon_button(
      Settings,
      text(t, "app.settings.title"),
      model.settings_open,
      ToggleSettings,
      28.0,
      26.0,
      14.0,
    ),
    // 右上角：底栏收起/展开 + 右栏收起/展开（VS Code 的两个布局开关口径）
    icon_button(
      PanelBottom,
      text(t, "app.topbar.bottom_panel"),
      model.bottom_open,
      StudioCommandRun("studio.bottom.toggle"),
      28.0,
      26.0,
      14.0,
    ),
    icon_button(
      Columns,
      text(t, "app.topbar.right_panel"),
      !(model.right_view is RvHidden),
      StudioCommandRun("studio.right.toggle"),
      28.0,
      26.0,
      14.0,
    ),
  ]
  // 内垫：沉浸式左侧让出系统信号灯（78），否则常规 10。
  // 内部行宽 = width − 左内垫 − 右内垫；行必须显式定宽，否则权重 spacer
  // 拿不到 slack，顶栏内容会挤在中间（见 fill_row 注释）。
  // 顶栏起点在活动栏（48）右侧：信号灯避让量相应收窄 48。
  let inset = if model.immersive {
    TRAFFIC_LIGHT_INSET - ICONBAR_WIDTH
  } else {
    10.0
  }
  let inner = (width - inset - 10.0).max(120.0)
  // 沉浸态这一条同时承担窗口标题栏，所以是 `WINDOW_CHROME_HEIGHT`（32，
  // 与系统信号灯共线）；非沉浸态（Web）没有窗口头，保持设计稿的 40。
  let bar_height = if model.immersive {
    WINDOW_CHROME_HEIGHT
  } else {
    TOPBAR_HEIGHT
  }
  let bar = @views.container(
    @views.padding_edges(
      fill_row(
        [
          left,
          @views.spacer(min_length=8.0, weight=1.0),
          @views.row(right, spacing=TOPBAR_ACTION_GAP, align=Center),
        ],
        inner,
        8.0,
        Center,
      ),
      left=inset,
      right=10.0,
    ),
    background=ide_panel(),
    width~,
    height=bar_height,
    padding=0.0,
  )
  if model.immersive {
    // 整条带子是可拖拽的窗口头；视觉上不再画那句提示文字（IDEA 风格的
    // 标题栏靠系统约定即可发现），但保留为可访问名，别让拖拽能力只对
    // 鼠标用户可见。
    bar.accessibility_label(text(t, "app.window.drag_hint"))
  } else {
    bar
  }
}

///|
/// 面包屑尾段：当前子程序（控件.事件）。
fn handler_crumb(model : Model) -> String {
  match current_handler(model) {
    None => "—"
    Some(handler) => "\{handler.control_name}.\{handler.event.tag()}"
  }
}

// ============================================================================
// 图标栏（34pt）
// ============================================================================

///|
/// 活动栏（M2 三模式工作台）：**唯一的职责 = 「我在哪个任务里」**——
/// 三个模式项 + 钉底的设置。点击语义全局同质：选模式；同值再点 no-op
/// （预设不重放）。左右栏各自的临时收放由面板头 ✕ 与命令面板承担，
/// 不再占活动栏槽位（此前 8 个按钮混排四种职责、五种再点语义——
/// 收敛记录见计划文档）。
///
/// **紧凑活动栏口径（参考 VS Code 截图实测）**：栏宽 34、单项节距 28、
/// 字形 17。仍是「全高贯通」骨架：从窗口顶直抵窗口底边；图标从信号灯带
/// 之下开始；设置钉在最底（贴窗口底边框）。
pub fn ide_icon_bar(
  model : Model,
  t : @i18n.Translator,
  height : Double,
) -> @moui.View[Msg] {
  let top_clearance = if model.immersive {
    WINDOW_CHROME_HEIGHT
  } else {
    TOPBAR_HEIGHT
  }
  let mode_button = fn(
    icon : @style.IconName,
    label : String,
    perspective : StudioPerspective,
  ) {
    icon_button(
      icon,
      label,
      model.perspective == perspective,
      SetPerspective(perspective),
      28.0,
      28.0,
      17.0,
      tile=false,
    )
  }
  let mode_items : Array[@moui.View[Msg]] = [
    // 图形化编辑：左栏结构树 / 中心可视化（预览是中心形态）/ 右栏检查器
    mode_button(Eye, text(t, "app.perspective.visual"), PsVisual),
  ]
  // 教学版 profile（M7）：只渲染图形化模式项（无终端/无工程/AI）
  let mode_items = if !(model.profile is Teaching) {
    mode_items +
    [
      // 代码编辑：左栏工程文件树 / 中心代码编辑器 / 右栏 AI 停靠（VS Code 口径）
      mode_button(CodeInline, text(t, "app.perspective.code"), PsCode),
      // AI 工作台：中心会话流 / 底栏终端（M3/M5 逐级落地）
      mode_button(Focus, text(t, "app.perspective.ai"), PsAi),
    ]
  } else {
    mode_items
  }
  let items : Array[@moui.View[Msg]] = [
      @views.spacer(min_length=0.0, weight=0.0).frame(
        width=1.0,
        height=top_clearance,
      ),
    ] +
    mode_items +
    [
      // 模式组与工具组分隔（组间分文的可见边界）
      @views.container(hairline(), width=20.0, height=1.0, padding=0.0),
      @views.spacer(min_length=4.0, weight=1.0),
      // 设置钉在最底：与整体同规格（28×28/17）——VS Code 的齿轮也是同一
      // 槽位节奏，缩小一号反而显得孤立。按钮贴窗口底边框。
      icon_button(
        Gear,
        text(t, "app.settings.title"),
        model.settings_open,
        ToggleSettings,
        28.0,
        28.0,
        17.0,
        tile=false,
      ),
    ]
  @views.container(
    // 列必须显式定宽高：权重 spacer 只有在确定了主轴尺寸后才拿得到 slack。
    @views.column(items, spacing=0.0, align=Center).frame(
      width=ICONBAR_WIDTH,
      height~,
    ),
    background=ide_panel(),
    width=ICONBAR_WIDTH,
    height~,
    padding=0.0,
  )
}

// ============================================================================
// 左栏
// ============================================================================

///|
/// 左栏：搜索 + 结构树（或本地数据）+ 底部（最近修改 + 快速插入）。
pub fn ide_left_panel(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let head = panel_head(
    if model.left_view is LeftData {
      text(t, "app.left.data")
    } else if model.left_view is LeftProject {
      text(t, "app.left.project")
    } else if model.left_view is LeftAiSessions {
      text(t, "app.ai.sessions")
    } else {
      text(t, "app.left.tree")
    },
    "",
    [
      icon_button(
        Close,
        text(t, "app.left.hide"),
        false,
        SetLeftView(LeftHidden),
        22.0,
        20.0,
        11.0,
      ),
    ],
    width,
  )
  let search = @views.container(
    @views.padding_xy(
      @views.text_field(
        model.tree_query,
        on_input=query => SetTreeQuery(query),
        placeholder=text(t, "app.left.search"),
        variant=Outline,
        width=(width - 16.0).max(80.0),
        height=FIELD_HEIGHT,
      ),
      horizontal=8.0,
      vertical=4.0,
    ),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
  // 高度预算：头 + 搜索 + 底部条（高度由内容算，见 bottom_strip_height），
  // 其余全给结构树。底部块必须显式定高——不定高的子树会按内容一路长高，
  // 把结构树挤没。
  let strip_height = bottom_strip_height(model)
  // 搜索框只服务结构树(树查询);工程页/数据页不占这 34pt,还给正文
  let search_visible = model.left_view is LeftTree
  let body_height = (height -
  PANEL_HEAD_HEIGHT -
  (if search_visible { 34.0 } else { 0.0 }) -
  strip_height).max(120.0)
  let body = if model.left_view is LeftData {
    data_view(model, t, width, body_height)
  } else if model.left_view is LeftProject {
    project_explorer(model, t, width, body_height)
  } else if model.left_view is LeftAiSessions {
    ai_session_list(model, t, width, body_height)
  } else {
    tree_view_ide(model, t, width, body_height)
  }
  @views.container(
    @views.column(
      (if search_visible { [head, search, body] } else { [head, body] }) +
      [
        @views.container(
          bottom_strip(model, t, width),
          width~,
          height=strip_height,
          padding=0.0,
        ),
      ],
      spacing=0.0,
    ),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 分组头的「+」动作：返回（视图, 占宽）。视图为 `None` 表示该组没有可
/// 创建的对象——本地数据是从列表/表格控件的行**派生**的，没有独立创建
/// 语义，所以不给「+」，而不是给一个点了没用的按钮。
///
/// **为什么放在分组头**：创建入口应该贴着它创建的东西。本 App 另外两处
/// 创建都是上下文相关的——右栏「动作」页签建事件子程序、积木分类轨建语句
/// ——只有控件/变量曾经挤在面板底部一个全局按钮块里（占掉左栏约 35% 高度，
/// 而树才是那个会长、会滚动的区域）。
///
/// 展开态用内联菜单（与积木的语句插入面板同一手法），不用 `@views.dropdown`：
/// 后者自带按钮锚点与 `DropdownState`，塞进 24pt 的树行会撑破行高。
fn group_create_action(
  group : String,
  t : @i18n.Translator,
) -> (@moui.View[Msg]?, Double) {
  if !group_can_create(group) {
    return (None, 0.0)
  }
  let action = @views.container(
      @views.center(
        @views.text(
          "+",
          theme=studio_theme(),
          role=Caption,
          width=14.0,
          height=14.0,
        ).foreground(ide_accent()),
        width=18.0,
        height=16.0,
      ),
      background=ide_panel(),
      corner_radius=3.0,
      width=18.0,
      height=16.0,
      padding=0.0,
    )
    .on_tap(ToggleTreeCreate(group))
    .accessibility_label(
      if group == tree_group_variables() {
        text(t, "app.tree.create.variable")
      } else if group == tree_group_controls() {
        text(t, "app.tree.create.control")
      } else if group == tree_group_handlers() {
        text(t, "app.tree.create.handler")
      } else {
        text(t, "app.tree.create.window")
      },
    )
  (Some(action), 18.0)
}

///|
/// 该分组是否有「新建」语义。本地数据没有（派生视图）。
pub fn group_can_create(group : String) -> Bool {
  group == tree_group_window() ||
  group == tree_group_controls() ||
  group == tree_group_variables() ||
  group == tree_group_handlers()
}

///|
/// 分组头菜单展开时，在该组子节点**之后**插入的候选行。
/// 返回空数组 = 该组菜单没展开（不占高度）。
fn group_create_menu(
  model : Model,
  group : String,
  t : @i18n.Translator,
  width : Double,
) -> Array[@moui.View[Msg]] {
  if model.tree_create_group != group {
    return []
  }
  let rows : Array[@moui.View[Msg]] = []
  let add = fn(label : String, message : Msg) {
    rows.push(
      @views.container(
        @views.padding_edges(
          @views.text(
            "+ " + label,
            theme=studio_theme(),
            width=(width - 44.0).max(60.0),
            height=18.0,
            align=TextStart,
          ).foreground(ide_accent()),
          left=20.0,
          right=8.0,
        ),
        background=ide_panel_alt(),
        height=TREE_ROW_HEIGHT,
        width~,
        padding=0.0,
      ).on_tap(message),
    )
  }
  if group == tree_group_controls() {
    // 6 种控件**全部**列出：与 `ControlKind` 枚举等长。曾经只有 4 种，
    // 选择框与表格只能靠 AI 提案或打开模板才会出现。
    add(text(t, "control.button"), AddControl(@ir.Button))
    add(text(t, "control.label"), AddControl(@ir.Label))
    add(text(t, "control.text_field"), AddControl(@ir.TextField))
    add(text(t, "control.check_box"), AddControl(@ir.CheckBox))
    add(text(t, "control.list_box"), AddControl(@ir.ListBox))
    add(text(t, "control.table"), AddControl(@ir.Table))
    add(text(t, "control.dropdown"), AddControl(@ir.Dropdown))
    add(text(t, "control.progress_bar"), AddControl(@ir.ProgressBar))
    add(text(t, "control.image"), AddControl(@ir.Image))
  } else if group == tree_group_variables() {
    add(text(t, "app.tree.create.variable"), AddVariable)
  } else if group == tree_group_functions() {
    // 「制作一个积木」：直接建一个空体积木并选中它（右栏立刻可改名）
    add(text(t, "app.function.new"), AddFunction)
  } else if group == tree_group_handlers() {
    // 子程序挂在（控件, 事件）对上：先选一个控件，右栏「动作」页签里
    // 列出该控件支持的事件，点未建的那个即建。这里给一条直达引导。
    add(text(t, "app.tree.create.handler"), SelectSide(SideWindow))
  } else if group == tree_group_window() {
    // 窗体只有「标题」一处可改，已经在右栏属性面里——给一条直达入口，
    // 避免「分组头有 + 但点开是空的」。
    add(text(t, "app.tree.create.window_title"), SelectSide(SideWindow))
  }
  rows
}

///|
/// 程序结构树：分组头 + 行。搜索非空时全部展开。
fn tree_view_ide(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let nodes = program_tree(model)
  let groups = visible_groups(nodes)
  let rows : Array[@moui.View[Msg]] = []
  for group in groups {
    let children = group_children(nodes, group)
    let expanded = tree_group_expanded(model, group)
    let action = group_create_action(group, t)
    rows.push(
      tree_row(
        text(t, tree_group_label_key(group)),
        children.length().to_string(),
        0,
        false,
        children.length() > 0,
        expanded,
        None,
        Some(ToggleTreeGroup(group)),
        width,
        trailing=action.0,
        trailing_width=action.1,
      ),
    )
    if expanded {
      for child in children {
        rows.push(tree_node_row(model, child, width))
      }
    }
    // 分组头的「+」菜单：展开时紧跟该组子节点之后（贴着它创建的东西）。
    for extra in group_create_menu(model, group, t, width) {
      rows.push(extra)
    }
  }
  if rows.length() == 0 {
    return empty_hint(text(t, "app.left.no_match"), width, height)
  }
  // 结构树按内容自适应高度，超出交给滚动容器（避免行被压扁）
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 单个树节点行 → 消息映射（视图层把 kind 收成 typed Msg）。
fn tree_node_row(
  model : Model,
  node : TreeNode,
  width : Double,
) -> @moui.View[Msg] {
  // 选中态与点击动作都按节点种类分派。**窗体 / 变量 / 数据文件此前没有
  // `on_tap`，点了完全没反应**；变量与数据行的 `select_key` 还曾是空串。
  // 选中判据集中在 `tree_node_selected`，避免视图层与右栏各写一份漂移。
  let selected = tree_node_selected(model, node.kind, node.select_key)
  let on_click = match node.kind {
    TnControl => Some(SelectControl(node.select_key))
    TnHandler => Some(SelectHandler(node.select_key))
    TnFunction => Some(SelectSide(SideFunction(node.select_key)))
    TnWindow => Some(SelectSide(SideWindow))
    TnVariable => Some(SelectSide(SideVariable(node.select_key)))
    TnDataFile => Some(SelectSide(SideData(node.select_key)))
    TnGroup => None
  }
  tree_row(
    node.label,
    node.meta,
    node.depth,
    selected,
    false,
    false,
    on_click,
    None,
    width,
  )
}

///|
/// 本地数据视图：文件列表 + 选中预览（只读）。
/// 条目来自程序里的列表/表格控件与变量——不是假文件系统。
fn data_view(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let files = data_file_entries(model)
  if files.length() == 0 {
    return empty_hint(text(t, "app.data.none"), width, height)
  }
  let rows : Array[@moui.View[Msg]] = []
  for file in files {
    rows.push(
      @views.container(
        @views.padding_edges(
          @views.column(
            [
              @views.row(
                [
                  @views.text(
                    file.name,
                    theme=studio_theme(),
                    width=(width - 100.0).max(60.0),
                    height=18.0,
                    align=TextStart,
                  ).foreground(ide_text()),
                  @views.text(
                    if file.locked {
                      text(t, "app.data.readonly")
                    } else {
                      text(t, "app.data.live")
                    },
                    theme=studio_theme(),
                    width=56.0,
                    height=16.0,
                    align=TextEnd,
                  ).foreground(
                    if file.locked {
                      ide_warning()
                    } else {
                      ide_success()
                    },
                  ),
                ],
                spacing=4.0,
                align=Center,
              ),
              @views.text(
                file.meta,
                theme=studio_theme(),
                role=Mono,
                width=(width - 24.0).max(60.0),
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_faint()),
              @views.text(
                if file.preview == "app.data.empty" {
                  text(t, "app.data.empty")
                } else {
                  file.preview
                },
                theme=studio_theme(),
                role=Mono,
                width=(width - 24.0).max(60.0),
                height=(preview_height(file.preview).to_double() * 16.0).max(
                  16.0,
                ),
                align=TextStart,
              ).foreground(code_plain_color()),
            ],
            spacing=2.0,
          ),
          left=8.0,
          right=8.0,
          top=6.0,
          bottom=6.0,
        ),
        background=ide_panel(),
        width~,
        padding=0.0,
      ),
    )
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 预览行数：按换行数估算（限制 8 行以内，避免一块数据吃掉整个左栏）。
fn preview_height(preview : String) -> Int {
  let mut lines = 1
  for c in preview {
    if c == '\n' {
      lines = lines + 1
    }
  }
  lines.min(8)
}

///|
/// 左栏底部：最近修改列表 + 快速插入按钮组。

///|
/// 底部条的高度是**内容决定**的：最近修改行数可变，写死高度不是裁掉
/// 最后一行就是把面板撑破。左右两条（最近修改 + 快速插入）都定高。
pub fn bottom_strip_height(model : Model) -> Double {
  let rows = recent_tail(model.recent_changes, RECENT_STRIP_ROWS).length()
  let row_count = if rows == 0 { 1 } else { rows }
  PANEL_HEAD_HEIGHT + row_count.to_double() * TREE_ROW_HEIGHT + 4.0
}

///|
fn bottom_strip(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let header = panel_head(text(t, "app.recent.title"), "", [], width)
  let rows : Array[@moui.View[Msg]] = []
  let recent = recent_tail(model.recent_changes, RECENT_STRIP_ROWS)
  if recent.length() == 0 {
    rows.push(
      @views.container(
        @views.padding_edges(
          @views.text(
            text(t, "app.recent.empty"),
            theme=studio_theme(),
            width=(width - 20.0).max(60.0),
            height=18.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          left=8.0,
          right=8.0,
        ),
        height=TREE_ROW_HEIGHT,
        width~,
        padding=0.0,
      ),
    )
  } else {
    for change in recent {
      rows.push(
        @views.container(
          @views.padding_edges(
            @views.row(
              [
                @views.text(
                  change.target,
                  theme=studio_theme(),
                  width=64.0,
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text()),
                @views.text(
                  actor_label(t, change.by_agent),
                  theme=studio_theme(),
                  width=38.0,
                  height=18.0,
                  align=TextStart,
                ).foreground(
                  if change.by_agent {
                    ide_accent()
                  } else {
                    ide_text_faint()
                  },
                ),
                @views.text(
                  text(t, change.action),
                  theme=studio_theme(),
                  width=(width - 128.0).max(40.0),
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text_muted()),
              ],
              spacing=4.0,
              align=Center,
            ),
            left=8.0,
            right=8.0,
          ),
          height=TREE_ROW_HEIGHT,
          width~,
          padding=0.0,
        ),
      )
    }
  }
  // 创建入口已上移到**分组头**（见 `group_create_action`）——底部不再有
  // 全局按钮块。这是有意的：底部块占掉左栏约 35% 高度，而结构树才是那个
  // 会长、会滚动的区域；创建入口贴着它创建的东西，也与本 App 另外两处
  // 创建入口（右栏「动作」页签建子程序、积木分类轨建语句）保持同一范式。
  let strip_height = bottom_strip_height(model)
  @views.container(
    @views.column([header, @views.column(rows, spacing=0.0)], spacing=0.0).frame(
      width~,
      height=strip_height,
    ),
    background=ide_panel(),
    width~,
    height=strip_height,
    padding=0.0,
  )
}

///|
fn actor_label(t : @i18n.Translator, by_agent : Bool) -> String {
  if by_agent {
    text(t, "app.recent.agent")
  } else {
    text(t, "app.recent.you")
  }
}

///|
/// 最近修改尾部 N 条（新的在下——设计稿是最近在最上，取尾部后反转）。
fn recent_tail(
  changes : Array[RecentChange],
  count : Int,
) -> Array[RecentChange] {
  let tail : Array[RecentChange] = []
  let mut index = changes.length() - 1
  while index >= 0 && tail.length() < count {
    tail.push(changes[index])
    index = index - 1
  }
  tail
}

// ============================================================================
// 底栏（审计 + Console）
// ============================================================================

///|
/// 底栏：拖动条 + 页签头 + 面板体。收起时只剩 26pt 页签头。

///|
/// 底栏：页签头 + 当前页签的体。
///
/// `height` 由**调用方**给（`shell_view` 里按内容算出的 `bottom_height`），
/// 不再读 `model.bottom_height`——那两个值会分叉：AI 页签的内容高随线程卡
/// 数量变化，模型里存的仍是用户上次的拖拽值，于是面板被算成 164pt、
/// 体内的卡片却按 168pt 布局，多出的部分把窗口底色（`#16181C`）露在底栏里
/// （实测底栏底部一条 14px 的暗带）。高度只有一个来源。
pub fn ide_bottom_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let pending = pending_side_effects(model)
  let errors = audit_error_count(model)
  let problems = problem_rows(model, t).length()
  // AI 宿主推导（M2）：底栏页签只在「AI 没有停靠右栏、也不在 AI 模式中心」
  // 时出现——任何时刻输入面恰好一个宿主可见（见 ide_ai.mbt 的 host 注释）。
  let ai_in_bottom = !(model.right_view is RvAi) && !(model.perspective is PsAi)
  let head_cells : Array[@moui.View[Msg]] = [
    tab_button(
      text(t, "app.bottom.audit"),
      model.bottom_tab is BtAudit,
      SetBottomTab(BtAudit),
      pending,
    ),
    tab_button(
      text(t, "app.bottom.console"),
      model.bottom_tab is BtConsole,
      SetBottomTab(BtConsole),
      model.log_lines.length(),
    ),
    tab_button(
      text(t, "app.bottom.problems"),
      model.bottom_tab is BtProblems,
      SetBottomTab(BtProblems),
      problems,
    ),
    // AI 输入条页签：与只读面板并列。计数用待审计提案数——它是
    // 「这里有没有等你处理的东西」的唯一读数（与药丸徽标同一个来源）。
  ]
  let ai_tab_cells : Array[@moui.View[Msg]] = if ai_in_bottom {
    [
      tab_button(
        text(t, "app.bottom.ai"),
        model.bottom_tab is BtAi,
        SetBottomTab(BtAi),
        pending_ai_cards(model),
      ),
    ]
  } else {
    []
  }
  let head_cells = head_cells + ai_tab_cells
  // 真终端页签（M5）：AI 模式专属（预设表：模式 3 底栏 = 真终端）
  // 终端页签（M8）：全模式可用——关闭态点击重开（重派生）；选中态再点
  // = 关闭（kill + 收起，见 select_bottom_tab 的开关语义）
  // 终端页签（M8）：关闭态点击 = 重开（SetBottomTab）；开+选中态再点 =
  // 关闭（TerminalTabClose → kill + 收起）
  let terminal_tab_cells : Array[@moui.View[Msg]] = [
    tab_button(
      text(t, "app.bottom.terminal"),
      model.bottom_tab is BtTerminal && model.terminal_open,
      if model.bottom_tab is BtTerminal && model.terminal_open {
        TerminalTabClose
      } else {
        SetBottomTab(BtTerminal)
      },
      0,
    ),
  ]
  let head_cells = head_cells + terminal_tab_cells
  if model.bottom_tab is BtAudit && pending > 0 {
    head_cells.push(
      action_chip(
        text(t, "app.audit.confirm_all"),
        AuditSettleAll("app.audit.confirmed"),
        Quiet,
        22.0,
      ),
    )
  }
  if model.bottom_tab is BtConsole {
    head_cells.push(
      action_chip(text(t, "app.console.clear"), ClearConsole, Ghost, 22.0),
    )
  }
  head_cells.push(
    pill(
      if errors > 0 {
        "\{errors}"
      } else {
        "0"
      },
      if errors > 0 {
        ide_danger()
      } else {
        ide_success()
      },
      30.0,
    ),
  )
  // 收起/展开按钮贴页签行最右端（右缘即右栏左缘）——VS Code 面板口径。
  head_cells.push(@views.spacer(min_length=8.0, weight=1.0))
  head_cells.push(
    icon_button(
      if model.bottom_open {
        ChevronDown
      } else {
        ChevronRight
      },
      if model.bottom_open {
        text(t, "app.bottom.collapse")
      } else {
        text(t, "app.bottom.expand")
      },
      model.bottom_open,
      ToggleBottom,
      22.0,
      22.0,
      12.0,
    ),
  )
  let head = @views.container(
    @views.padding_xy(
      fill_row(head_cells, (width - 16.0).max(120.0), 6.0, Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
  if !model.bottom_open {
    // 收起 = **整个底栏隐藏**（页签行也不留——重开入口在标题栏右上的底栏
    // 开关 / J 键 / 命令面板,VS Code 面板口径）。零高容器必须显式给底色,
    // 否则回落环境刷子在缝隙里露一条（本仓反复踩的 ambient 坑）。
    return @views.container(
      @views.text("", width=1.0, height=0.0),
      background=ide_panel(),
      width~,
      height=0.0,
      padding=0.0,
    )
  }
  let body = match model.bottom_tab {
    BtAudit => audit_pane(model, t, width, height - 30.0)
    BtConsole => console_pane(model, t, width, height - 30.0)
    BtProblems => problems_pane(model, t, width, height - 30.0)
    // AI 输入面：与停靠档**同一个** `ai_card_body`（折叠条 + 线程区 +
    // 输入盒 + 决策行），宿主换成底栏。
    //
    // 高度**显式给**（body 区 = 总高 − 页签头）：卡片必须待在自己的格子里，
    // 否则它会按内容自然高画出去、越过底栏边界，把窗口底色露在底栏里
    // （实测底栏底部一条 14px 的暗带）。线程区自己会滚动，所以这里不套
    // 外层 scroll_view——两层滚动会让线程卡的滚动量与预期不符。
    BtAi =>
      // 防御性门控：页签列表已按宿主推导过滤，但 stale 的页签选择仍可能
      // 指到 BtAi（如停靠后再展开）。宿主不在底栏时诚实显示空态，
      // 绝不画第二份 composer。
      if ai_host_is_bottom(model) {
        ai_bar_composer(model, t, width, (height - PANEL_HEAD_HEIGHT).max(80.0))
      } else {
        empty_hint(
          text(t, "app.ai.elsewhere"),
          width,
          height - PANEL_HEAD_HEIGHT,
        )
      }
    // 真终端（M5）：可用 = 屏行滚动 + 输入行；不可用（web/无头/教学版）
    // = 显式空态
    // 真终端（M5/M8 交互式）：不可用端（web/无头/教学版）上层已降级空态
    BtTerminal => terminal_pane(model, t, width, height - PANEL_HEAD_HEIGHT)
  }
  @views.container(
    @views.column([hairline(), head, body], spacing=0.0),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
}

///|
/// 页签按钮：选中态用强调色下边框式的高亮（这里用底色 + 亮文字表达）。
/// 标签宽按内容算——写死 88 会在长页签名（本地化）下截掉半边。
fn tab_button(
  label : String,
  selected : Bool,
  on_click : Msg,
  count : Int,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      label,
      theme=studio_theme(),
      width=(text_estimate_width(label) * 1.02 + 8.0).max(40.0),
      height=18.0,
      align=TextStart,
    ).foreground(if selected { ide_text() } else { ide_text_faint() }),
  ]
  if count > 0 {
    cells.push(count_badge(count.to_string(), if selected { 4 } else { 0 }))
  }
  @views.container(
    @views.padding_xy(
      @views.row(cells, spacing=6.0, align=Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=if selected { ide_selection() } else { ide_panel_alt() },
    corner_radius=4.0,
    height=22.0,
    padding=0.0,
  )
  .accessibility_label(label + (if count > 0 { " (\{count})" } else { "" }))
  .on_tap(on_click)
}

///|
/// 审计时间线：逐条卡片（时间点 + 文字），副作用卡带确认按钮，
/// 错误卡带调用栈。
pub fn audit_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  if model.audit_entries.length() == 0 {
    return empty_hint(text(t, "app.audit.empty"), width, height)
  }
  let cards : Array[@moui.View[Msg]] = []
  let mut index = 0
  for entry in model.audit_entries {
    cards.push(audit_card(model, t, entry, index, width - 20.0))
    index = index + 1
  }
  @views.container(
    @views.scroll_view(
      @views.column(cards, spacing=6.0),
      width~,
      height~,
      shows_indicator=true,
    ),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 单条审计卡：左侧语义色条 + 文本 + （副作用）确认按钮 + （错误）调用栈。
/// 点击卡片跳转到对应积木（AuditOpen）。
fn audit_card(
  model : Model,
  t : @i18n.Translator,
  entry : AuditEntry,
  index : Int,
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  let accent = match entry.kind {
    AuditOk => ide_success()
    AuditRun => ide_accent()
    AuditWarn => ide_warning()
    AuditError => ide_danger()
  }
  let body : Array[@moui.View[Msg]] = [
    @views.text(
      text(t, entry.text),
      theme=studio_theme(),
      width=(width - 40.0).max(80.0),
      height=18.0,
      align=TextStart,
    ).foreground(ide_text()),
  ]
  if entry.detail != "" {
    body.push(
      @views.text(
        entry.detail,
        theme=studio_theme(),
        role=Mono,
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_muted()),
    )
  }
  if entry.stack != "" {
    body.push(
      @views.text(
        entry.stack,
        theme=studio_theme(),
        role=Mono,
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(code_comment_color()),
    )
  }
  if entry.kind is AuditWarn && !entry.settled {
    // 芯片严格 22 高：审计卡在 scroll_view 里按内容排，36pt 的
    // @views.button 会把确认行撑得忽高忽低。
    body.push(
      @views.row(
        [
          action_chip(
            text(t, "app.audit.confirm"),
            AuditSettle(index, "app.audit.confirmed"),
            Primary,
            22.0,
          ),
          action_chip(
            text(t, "app.audit.reject"),
            AuditSettle(index, "app.audit.rejected"),
            Quiet,
            22.0,
          ),
          @views.text(
            fit_label(text(t, "app.audit.gate_hint"), (width - 220.0).max(60.0)),
            theme=studio_theme(),
            width=(width - 200.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
        ],
        spacing=6.0,
        align=Center,
      ),
    )
  } else if entry.settled {
    body.push(
      @views.text(
        entry.settled_note,
        theme=studio_theme(),
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(ide_success()),
    )
  }
  inline_card(accent, @views.column(body, spacing=4.0), width, entry.settled).on_tap(
    AuditOpen(index),
  )
}

///|
/// Console：等宽日志行，级别着色。
pub fn console_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  if model.log_lines.length() == 0 {
    return empty_hint("", width, height)
  }
  let rows : Array[@moui.View[Msg]] = []
  for line in model.log_lines {
    let (tag, color) = match line.level {
      LogInfo => ("INFO ", ide_text_muted())
      LogWarn => ("WARN ", ide_warning())
      LogError => ("ERROR", ide_danger())
    }
    rows.push(
      @views.row(
        [
          @views.text(
            tag,
            theme=studio_theme(),
            role=Mono,
            width=44.0,
            height=16.0,
          ).foreground(color),
          @views.text(
            text(t, line.text),
            theme=studio_theme(),
            role=Mono,
            width=(width - 70.0).max(80.0),
            height=16.0,
            align=TextStart,
          ).foreground(code_plain_color()),
        ],
        spacing=6.0,
        align=Center,
      ),
    )
  }
  @views.container(
    @views.scroll_view(
      @views.column(rows, spacing=0.0),
      width~,
      height~,
      shows_indicator=true,
    ),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 终端面板（M5；M8② 交互式键入回退到行输入——keyboard_input 直通的
/// 焦点路由未通，见计划 M8 真机复核记录）：行缓冲屏滚动 + 输入行
/// （回车/执行芯片提交给 PTY）。回显由 PTY 输出流返回（真终端语义）。
pub fn terminal_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let term = model.terminal
  let screen_height = height
  let screen_rows : Array[@moui.View[Msg]] = []
  if term.screen.length() == 0 {
    screen_rows.push(
      empty_hint(
        if term.running() {
          ""
        } else {
          text(t, "app.terminal.waiting")
        },
        width,
        screen_height,
      ),
    )
  } else {
    let total = term.screen.length()
    let mut line_index = 0
    for line in term.screen {
      let is_last = line_index == total - 1
      // 光标（M8 用户反馈①）：末行按 col 插入光标符号（▌）——会话运行时
      // 可见，指示下一个键入位置（列光标模型与 write_at_col 同源）
      let display = if is_last && term.running() {
        let chars : Array[Char] = []
        for c in line {
          chars.push(c)
        }
        let col = term.col.clamp(min=0, max=chars.length())
        let buf = StringBuilder()
        for i in 0..<col {
          buf.write_char(chars[i])
        }
        buf.write_string("▌")
        for i in col..<chars.length() {
          buf.write_char(chars[i])
        }
        buf.to_string()
      } else {
        line
      }
      screen_rows.push(
        @views.text(
          if display == "" {
            " "
          } else {
            display
          },
          theme=studio_theme(),
          role=Mono,
          width=(width - 16.0).max(60.0),
          height=16.0,
          align=TextStart,
        ).foreground(code_plain_color()),
      )
      line_index = line_index + 1
    }
  }
  // 滚动受控（M8 用户反馈②）：offset 跟随模型（用户手动滚动经
  // TerminalScrolled 回写）；新输出时模型置 (0, 1e9) + 序号自增 →
  // ScrollRequest 强制滚到底部（容器 clamp）
  let screen = @views.container(
    @views.padding_edges(
      @views.scroll_view(
        @views.column(screen_rows, spacing=0.0),
        offset=model.terminal_scroll,
        width=width - 16.0,
        height=screen_height - 16.0,
        on_scroll=Some(offset => TerminalScrolled(offset)),
        request=@core.ScrollRequest::new(
          id=model.terminal_scroll_seq,
          offset=model.terminal_scroll,
        ),
        shows_indicator=true,
      ),
      left=8.0,
      right=8.0,
    ),
    background=ide_editor_background(),
    width~,
    height=screen_height,
    padding=0.0,
  )
  // 键盘直通（M8② 交互式）：keyboard_input 节点（identity key =
  // "terminal-input"，Ctrl+T/AI 进入时 focus_key 聚焦）——键入经
  // TerminalWrite 直写 PTY，回显由 PTY 输出流返回（真终端语义）
  @terminal.keyboard_input(
    screen,
    fn(event) {
      match @terminal.encode_key(event) {
        Some(seq) => Some(TerminalWrite(seq))
        None => None
      }
    },
    fn(text) { Some(TerminalWrite(text)) },
  )
}
