///|
/// v4 IDE 壳顶层装配：顶栏 / 图标栏 / 左栏 / 中心工作区 / 右栏 /
/// 底栏 / 状态栏 / AI 浮动层 / 对话框与 toast。
///
/// 布局纪律（踩过的坑，逐条注释在对应位置）：
/// 1. 含竖直分隔线的行必须钳高——竖直 divider 按可用高度测量。
/// 2. 交互画布子树不用 .flexible()——加权子树会在 tight 重排下丢手势。
/// 3. 浮动层用 stack + align + offset 绝对摆放，保留带（reserve）按底栏
///    展开态补偿——不做 DOM 式测量（core 没有测量回环）。

///|
/// 顶层视图：壳 + 内容。运行/帮助/预览三个全屏页仍走旧视图（执行与只读
/// 场景不属于工作区编排），其余走 v4 工作区。
pub fn view(model : Model) -> @moui.View[Msg] {
  view_with_viewport(model, default_viewport_size())
}

///|
/// 视口未知时的回退尺寸：1280×800 与两个平台入口一致（macos_skia /
/// web_wasm 都以它开窗）。真实运行走 view_with_viewport，测试与
/// 无环境入口用这个。
pub fn default_viewport_size() -> @core.Size {
  @core.Size::new(width=1280.0, height=800.0)
}

///|
/// 带视口的顶层视图：壳的各列宽/行高都按真实视口算（顶栏铺满、
/// 中心列吃掉剩余宽度、底栏按视口宽铺）。这是 v4 IDE 壳能自适应窗口的
/// 唯一入口——写死 1280 会在别的窗口尺寸下把右侧栏挤出屏幕。
pub fn view_with_viewport(
  model : Model,
  viewport : @core.Size,
) -> @moui.View[Msg] {
  let t = translator(model)
  let width = if viewport.width > 0.0 { viewport.width } else { 1280.0 }
  let height = if viewport.height > 0.0 { viewport.height } else { 800.0 }
  let base = shell_view(model, t, width, height)
  // 命令面板 / 设置 / AI 历史三个模态共用一个 overlay_host（顶层唯一宿主）：
  // 多个宿主会各自维护 layer_stack，Escape 的「最上层优先」就失效了。
  studio_overlay_host(base, model, t).theme(studio_theme())
}

///|
/// 壳主体（不含模态）：顶栏 + 内容行 + 底栏 + 状态栏 + AI 层。
fn shell_view(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let fullscreen = match model.mode {
    ModePreview | ModeHelp | ModeRun => true
    _ => false
  }
  // 底栏高：展开时按**内容**算（AI 页签要装下线程卡，见 `ai_bar_height`），
  // 收起时只留页签头。写成「模型里那个数」会让 AI 页签在有提案时裁掉线程区
  // ——高度是算出来的，不是存下来的（`bottom_height` 只作为用户拖拽的下限）。
  let bottom_height = if model.bottom_open {
    if model.bottom_tab is BtAi {
      ai_bar_height(model, center_width_of(model, width), height).max(
        model.bottom_height,
      )
    } else {
      model.bottom_height
    }
  } else {
    PANEL_HEAD_HEIGHT
  }
  let window_bar = if model.immersive {
    WINDOW_CHROME_HEIGHT - TOPBAR_HEIGHT
  } else {
    0.0
  }
  // VS Code 骨架：**活动栏全高贯通左侧**（从窗口顶到状态栏），状态栏
  // 横贯整个底边。右列（顶栏+内容+底栏面板）在活动栏右侧。
  let body_height = (height - STATUSBAR_HEIGHT - 1.0).max(200.0)
  let chrome = TOPBAR_HEIGHT +
    bottom_height +
    window_bar +
    2.0
  let content_height = (body_height - chrome).max(200.0)
  let content = if fullscreen {
    // 全屏页（预览/帮助/运行）：两侧栏收起，内容居中占满
    @views.container(
      center_panel(model, t),
      background=ide_editor_background(),
      width=(width - ICONBAR_WIDTH).max(120.0),
      height=content_height,
      padding=0.0,
    )
  } else {
    // 非全屏的正文在下方 main_col 里装配（工作区 + 底栏面板 + 全高右栏）；
    // 这里只放一个占位，保持 content 类型完整。
    @views.text("", width=1.0, height=1.0)
  }
  // 右列各段高度**全部显式**：顶栏带（沉浸 32 / 普通 40）+ 发丝线 +
  // 内容段 + 底栏面板。`height~` 在这套嵌套里不按剩余空间填充——
  // 实测它会撑到外层 body 高，把底栏面板推出窗口（「点运行没反应」轮次
  // 的 12 个布局回归全是它）。
  let topbar_height = if model.immersive {
    WINDOW_CHROME_HEIGHT
  } else {
    TOPBAR_HEIGHT
  }
  let side_width = (width - ICONBAR_WIDTH).max(120.0)
  let lower_height = (body_height - topbar_height - 1.0).max(200.0)
  let pane_height = (lower_height - bottom_height).max(200.0)
  // VS Code 骨架第三轮：**左栏也全高**（顶栏之下直抵状态栏），底栏面板
  // 只铺中心列（左缘 = 左栏右缘，右缘 = 右栏左缘）。lower_row 从左到右：
  // [左栏全高段 | 竖发丝线 | 中心列(工作区+底栏面板) | 竖发丝线 | 右栏全高段]。
  // AI 停靠时右栏段顶上 340 是 AI 卡。
  let chrome_widths = shell_chrome_widths(model, side_width)
  let center_width = chrome_widths.center
  let workspace_seg = if fullscreen {
    content
  } else {
    @views.container(
      center_workspace(model, t, center_width, pane_height),
      background=ide_editor_background(),
      width=center_width,
      height=pane_height,
      padding=0.0,
    )
  }
  let main_col = @views.column(
    [workspace_seg, ide_bottom_bar(model, t, center_width, bottom_height)],
    spacing=0.0,
  ).frame(width=center_width, height=lower_height)
  let lower_cells : Array[@moui.View[Msg]] = []
  if !fullscreen {
    match chrome_widths.left {
      Some(left_width) => {
        lower_cells.push(ide_left_panel(model, t, left_width, lower_height))
        lower_cells.push(hairline_v())
      }
      None => ()
    }
  }
  lower_cells.push(main_col)
  if !fullscreen && chrome_widths.right > 0.0 {
    lower_cells.push(hairline_v())
    if model.ai_anchor is AiDocked {
      lower_cells.push(
        @views.column(
          [
            @views.container(
              match ai_layer(model, t, chrome_widths.right, 340.0) {
                Some(layer) => layer
                None => @views.text("", width=1.0, height=1.0)
              },
              width=chrome_widths.right,
              height=340.0,
              padding=0.0,
            ),
            ide_right_panel(
              model,
              t,
              chrome_widths.right,
              lower_height - 340.0,
            ),
          ],
          spacing=0.0,
        ).frame(width=chrome_widths.right, height=lower_height),
      )
    } else {
      lower_cells.push(
        ide_right_panel(model, t, chrome_widths.right, lower_height),
      )
    }
  }
  let lower_row = @views.row(lower_cells, spacing=0.0, align=Stretch).frame(
    width=side_width,
    height=lower_height,
  )
  let right_side = @views.column(
    [ide_top_bar(model, t, side_width), hairline(), lower_row],
    spacing=0.0,
  ).frame(width=side_width, height=body_height)
  // VS Code 骨架终稿：**活动栏通到窗口最底边**（状态栏不再从它下方穿过，
  // 设置图标随之贴住窗口底边）；**状态栏从活动栏右缘铺到窗口右缘**，
  // 其上发丝线同样止于活动栏右缘——左缘即活动栏，无空隙。
  @views.container(
    @views.row(
      [
        ide_icon_bar(model, t, height),
        @views.column(
          [right_side, hairline(), ide_status_bar(model, t, side_width)],
          spacing=0.0,
        ).frame(width=side_width, height=height),
      ],
      spacing=0.0,
      align=Stretch,
    ).frame(width~, height~),
    background=studio_window_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 中心列的工作区段：**直接**铺满整行，不再有任何 AI 叠放层或避让带。
///
/// **历史（重要）**：这里曾经是「工作区内容 + AI 浮动层」的叠放宿主，并为
/// 贴底浮卡在中心列底部预留一条 134pt 的「AI 保留带」——带横跨左右两个
/// 窗格，与相邻面只差 1.05:1 而读不出边界，用户报的「这块区域不协调」
/// 就是它。浮层形态被两种内联落点（底栏页签 / 右栏停靠）取代后，带、
/// 避让计算、分隔线一并删除：**中心列拿回全部高度**，输入条改由它所在的
/// 那个面板自己承载，不再需要「预留区」这种跨窗格的结构。
fn center_workspace(
  model : Model,
  t : @i18n.Translator,
  center_width : Double,
  row_height : Double,
) -> @moui.View[Msg] {
  workspace_content(model, t, center_width, row_height)
}

///|
/// 三列宽度：窗口宽 − 图标栏后由左/中/右分配。
pub(all) struct ShellChromeWidths {
  left : Double?
  center : Double
  /// 右栏宽。`0.0` 表示右栏收起（不占宽、不画分隔线）。
  right : Double
}

///|
/// 三列宽度分配。宽窗口用设计稿的确定值（左 232 / 右 272 / 中心吃剩余）；
/// 窄窗口按比例收窄两侧并**优先保住中心**——否则固定宽的三列加起来超过
/// 窗口宽，右栏会被挤出屏幕（实际截图里右栏贴边、页签被切就是这个形态）。
///
/// 中心列有 320 的下限（三工作区都在这个宽度下仍然可用）。当
/// 图标栏 + 左 + 中心下限 + 右都放不下时，**左栏自动让位**（返回 None）：
/// 设计师在窄窗口下最需要的是中心舞台，左栏可以从图标栏再点开。
///
/// `right` 返回 0.0 有两种来源，调用方**不必区分**（都是「不画右栏」）：
/// 用户显式收起（`right_visible = false`），或窄窗口下让位。这里优先保住
/// 右栏而不是让它让位——它是属性面板，收起了就没地方改属性；
/// 真正需要腾空间时先让左栏（树可以从图标栏再点开）。
fn shell_chrome_widths(model : Model, width : Double) -> ShellChromeWidths {
  // `width` = 活动栏右侧的可用宽（调用方已扣除 48 的活动栏）。
  let usable = (width - 2.0).max(120.0)
  let center_min = 320.0
  let wants_left = !(model.left_view is LeftHidden)
  let wants_right = model.right_visible
  let left_want = LEFTBAR_WIDTH
  let right_want = RIGHTBAR_WIDTH
  if !wants_right {
    // 右栏收起：中心吃满「可用 − 左栏」
    let left_room = if wants_left { left_want + 1.0 } else { 0.0 }
    return ShellChromeWidths::{
      left: if wants_left {
        Some(left_want)
      } else {
        None
      },
      center: (usable - left_room).max(center_min),
      right: 0.0,
    }
  }
  if usable >= left_want + right_want + center_min {
    // 宽窗口：设计稿确定值
    ShellChromeWidths::{
      left: if wants_left {
        Some(left_want)
      } else {
        None
      },
      center: usable -
      (if wants_left { left_want + 1.0 } else { 0.0 }) -
      right_want -
      1.0,
      right: right_want,
    }
  } else {
    // 窄窗口：右栏收到 232（仍放得下 5 个页签与读数），中心吃剩下的。
    let right_shrunk = 232.0
    let needed_left = left_want + 1.0
    let room = usable - right_shrunk - 1.0
    if wants_left && room >= needed_left + center_min {
      ShellChromeWidths::{
        left: Some(left_want),
        center: room - needed_left,
        right: right_shrunk,
      }
    } else {
      // 左栏让位：中心拿满「可用 − 右栏」
      ShellChromeWidths::{
        left: None,
        center: (usable - right_shrunk - 1.0).max(center_min),
        right: right_shrunk,
      }
    }
  }
}

///|
/// 中心列宽（只读快照，供避让带计算与测试使用）。
pub fn center_width_of(model : Model, width : Double) -> Double {
  shell_chrome_widths(model, width).center
}

///|
/// 中心内容：可视化工作区 / 代码工作区 / 空舞台。
fn workspace_content(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  match model.workspace {
    WsVisual => visual_workspace(model, t, width, height)
    WsCode => code_workspace(model, t, width, height)
    WsEmpty => empty_stage(model, t, width, height)
  }
}

///|
/// 模态宿主：命令面板 / 设置 / AI 历史。
/// 三个都是 Modal + Dialog：Dialog 自动居中，Modal 给遮罩与背景语义隐藏，
/// Escape/点击外部由 dismiss.message 收敛回各自的开关键。
fn studio_overlay_host(
  base : @moui.View[Msg],
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let specs : Array[@views.PresentationSpec[Msg]] = [
    @views.PresentationSpec::new(
      id="studio-command-palette",
      kind=@views.PresentationKind::Dialog,
      content=command_palette_dialog(model, t),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(CommandPaletteClose),
      ),
      presented=model.command_palette_open,
    ),
    @views.PresentationSpec::new(
      id="studio-settings",
      kind=@views.PresentationKind::Dialog,
      content=settings_dialog(model, t),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(ToggleSettings),
      ),
      presented=model.settings_open,
    ),
    @views.PresentationSpec::new(
      id="studio-ai-history",
      kind=@views.PresentationKind::Dialog,
      content=ai_history_dialog(model, t),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(ToggleAiHistory),
      ),
      presented=model.ai_history_open,
    ),
    // **积木右键菜单**：挂在**顶层**宿主上（viewport 大小），而不是画布
    // 窗格里。
    //
    // 为什么必须在顶层：菜单要「点别处关闭」，而关闭靠的是浮层屏障接住
    // 菜单之外的按下。屏障的覆盖范围 = 宿主的范围——挂在窗格里就只有窗格
    // 那么大（实测 233×536），在窗口其它地方点根本到不了屏障，菜单
    // **永远不消失**。顶层宿主铺满视口，屏障才盖得住整个窗口。
    //
    // 锚点用 `block_menu` 里存的**视口坐标**（右键点），所以菜单弹在指针处。
    @views.PresentationSpec::new(
      id="studio-block-menu",
      kind=@views.PresentationKind::ContextMenu,
      content=block_context_menu(model, t),
      anchor=match model.block_menu {
        Some((_, x, y)) => @views.PresentationAnchor::Viewport(
          @core.Point::new(x~, y~),
        )
        None => @views.PresentationAnchor::HostBase
      },
      placement=Some(
        @views.PresentationPlacement::new(
          candidates=[
            @views.PresentationPlacementCandidate::BelowEnd,
            @views.PresentationPlacementCandidate::AboveEnd,
            @views.PresentationPlacementCandidate::BelowStart,
            @views.PresentationPlacementCandidate::AboveStart,
          ],
          viewport_insets=@core.Insets::all(8.0),
        ),
      ),
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        escape=true,
        message=Some(BlocksContextMenuClose),
      ),
      presented=model.block_menu is Some(_),
    ),
    // 破坏性操作确认卡：Escape / 点外部 = 取消（confirm.mbt 纪律）。
    @views.PresentationSpec::new(
      id="studio-confirm",
      kind=@views.PresentationKind::Dialog,
      content=confirm_dialog(model, t),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(ConfirmDismissed),
      ),
      presented=model.pending_confirm is Some(_),
    ),
  ]
  // toast 单独一层（非模态，最上层）：它不该拦输入，也不参与 Escape 顺序
  let with_modals = @views.overlay_host(base, specs)
  toast_host(with_modals, model)
}
