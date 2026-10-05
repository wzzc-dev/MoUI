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
  let chrome = TOPBAR_HEIGHT + bottom_height + window_bar + 2.0
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
    [
      workspace_seg,
      // 底栏宽度跟随 main_col：全屏页（运行/预览/帮助）没有左右栏，
      // 若仍用 `center_width`（按「左栏+右栏都在」分配的宽），底栏只铺
      // 左半段，右侧留一条空白（实测运行页 AI 栏右侧全空）。
      ide_bottom_bar(
        model,
        t,
        if fullscreen {
          side_width
        } else {
          center_width
        },
        bottom_height,
      ),
    ],
    spacing=0.0,
  ).frame(
    width=if fullscreen { side_width } else { center_width },
    height=lower_height,
  )
  let lower_cells : Array[@moui.View[Msg]] = []
  // sash 拖拽的宽度界限：**另一侧面板 + 两条 sash + 中心下限**之外都是
  // 自己的余量。界限在视图构建期算好闭进闭包（拖拽期间窗口不变，界限
  // 是常量），update 只兜底夹静态界限。
  let left_drag_max = (side_width -
    (if chrome_widths.right > 0.0 {
      chrome_widths.right + SASH_WIDTH
    } else {
      0.0
    }) -
    320.0)
    .max(LEFTBAR_MIN_WIDTH)
    .min(LEFTBAR_MAX_WIDTH)
  let right_drag_max = (side_width -
    (match chrome_widths.left {
      Some(left_width) => left_width + SASH_WIDTH
      None => 0.0
    }) -
    320.0)
    .max(RIGHTBAR_MIN_WIDTH)
    .min(RIGHTBAR_MAX_WIDTH)
  if !fullscreen {
    match chrome_widths.left {
      Some(left_width) => {
        lower_cells.push(ide_left_panel(model, t, left_width, lower_height))
        lower_cells.push(
          v_sash(
            fn(x) {
              ResizeLeftPanel(
                (x - ICONBAR_WIDTH - SASH_WIDTH / 2.0).clamp(
                  min=LEFTBAR_MIN_WIDTH,
                  max=left_drag_max,
                ),
              )
            },
            lower_height,
          ),
        )
      }
      None => ()
    }
  }
  lower_cells.push(main_col)
  if !fullscreen && chrome_widths.right > 0.0 {
    lower_cells.push(
      v_sash(
        fn(x) {
          ResizeRightPanel(
            (width - x - SASH_WIDTH / 2.0).clamp(
              min=RIGHTBAR_MIN_WIDTH,
              max=right_drag_max,
            ),
          )
        },
        lower_height,
      ),
    )
    if model.ai_anchor is AiDocked {
      // VS Code 口径（实测反馈）：AI 输入**钉在右栏最底部**（属性页签
      // 之下），卡片按内容自适应——线程空时只占输入盒一条，不再固定
      // 340 顶在右栏上部留一大块空白。
      let ai_card_h = ai_card_height(model, chrome_widths.right)
      let ai_slice = (ai_card_h + PANEL_HEAD_HEIGHT + 8.0).min(
        (lower_height - 200.0).max(0.0),
      )
      lower_cells.push(
        @views.column(
          [
            ide_right_panel(
              model,
              t,
              chrome_widths.right,
              (lower_height - ai_slice).max(200.0),
            ),
            @views.container(
              match ai_layer(model, t, chrome_widths.right, ai_slice) {
                Some(layer) => layer
                None => @views.text("", width=1.0, height=1.0)
              },
              width=chrome_widths.right,
              height=ai_slice,
              padding=0.0,
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
        ).frame(width=side_width, height~),
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
/// 竖直 sash：三列之间**可拖拽的分隔区**（VS Code 口径）。
///
/// - 视觉：`SASH_WIDTH`（4pt）的竖带，底色 `ide_border_soft`——比两侧
///   面板略亮一档，读作「这里是分隔」，又不抢过发丝线的克制。
/// - 交互：拖拽把指针 x 经 `on_drag_x` 换算成目标宽度（界限由调用方
///   闭包夹取）。**绝对映射**——指针在哪面板就到哪，不需要拖拽起点状态，
///   来回拖也不会漂。
/// - 捕获：拖拽激活期手势持有指针捕获（runtime 对捕获元素在指针出界时
///   照常派发），所以 sash 自己随面板移动也不丢事件——与积木画布拖拽
///   同一机制。
fn v_sash(on_drag_x : (Double) -> Msg, height : Double) -> @moui.View[Msg] {
  @views.container(
    @views.empty(),
    background=ide_border_soft(),
    width=SASH_WIDTH,
    height~,
    padding=0.0,
  ).on_drag_with_frame(fn(event, _frame) {
    match event.phase {
      @views.DragGesturePhase::Started | @views.DragGesturePhase::Changed =>
        on_drag_x(event.position.x)
      _ => Msg::Noop
    }
  })
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
/// 三列宽度分配。**左/右栏宽度是用户可调的**（列间 sash 拖拽，存
/// `model.left_width`/`right_width`，默认 = LEFTBAR/RIGHTBAR_WIDTH）；
/// 中心列吃剩余。分隔区是 4pt 的 sash（`SASH_WIDTH`），预算按它显式扣。
///
/// 中心列有 320 的下限（三工作区都在这个宽度下仍然可用）。当用户宽度
/// + 中心下限放不下时（窗口太小），**右栏紧急收缩到 232**、仍不够则
/// **左栏让位**（返回 None）——与旧的设计稿定宽行为同构，只是把定宽
/// 换成了用户可调宽。`right` 返回 0.0 有两种来源（用户收起 / 让位），
/// 调用方不必区分。
fn shell_chrome_widths(model : Model, width : Double) -> ShellChromeWidths {
  // `width` = 活动栏右侧的可用宽（调用方已扣除活动栏）。
  let sash = SASH_WIDTH
  let usable = width.max(120.0)
  let center_min = 320.0
  let wants_left = !(model.left_view is LeftHidden)
  let wants_right = model.right_visible
  let left_want = model.left_width.clamp(
    min=LEFTBAR_MIN_WIDTH,
    max=LEFTBAR_MAX_WIDTH,
  )
  let right_want = model.right_width.clamp(
    min=RIGHTBAR_MIN_WIDTH,
    max=RIGHTBAR_MAX_WIDTH,
  )
  if !wants_right {
    // 右栏收起：中心吃满「可用 − 左栏 − 左 sash」
    let left_room = if wants_left { left_want + sash } else { 0.0 }
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
  if usable >= left_want + right_want + sash * 2.0 + center_min {
    // 宽窗口：用户的宽度原样生效，中心吃剩余
    ShellChromeWidths::{
      left: if wants_left {
        Some(left_want)
      } else {
        None
      },
      center: usable -
      (if wants_left { left_want + sash } else { 0.0 }) -
      right_want -
      sash,
      right: right_want,
    }
  } else {
    // 窄窗口紧急收缩：右栏压到 232（仍放得下 5 个页签与读数），中心吃
    // 剩下的；再不够左栏让位。
    let right_shrunk = right_want.min(232.0).max(170.0)
    let room = usable - right_shrunk - sash
    let needed_left = left_want + sash
    if wants_left && room >= needed_left + center_min {
      ShellChromeWidths::{
        left: Some(left_want),
        center: room - needed_left,
        right: right_shrunk,
      }
    } else {
      // 左栏让位：中心拿满「可用 − 右栏 − sash」
      ShellChromeWidths::{
        left: None,
        center: (usable - right_shrunk - sash).max(center_min),
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
    WsPreview => preview_workspace(model, t, width, height)
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
        Some((_, x, y)) =>
          @views.PresentationAnchor::Viewport(@core.Point::new(x~, y~))
        None => @views.PresentationAnchor::HostBase
      },
      placement=Some(
        @views.PresentationPlacement::new(
          // 候选顺序 = 右键菜单的方向偏好。锚点是**零尺寸**的指针点，
          // `…End` 会把菜单**右缘**对齐到指针（向左展开）、`…Start` 把
          // **左缘**对齐到指针（向右展开）。此前 BelowEnd 打头，菜单
          // 永远向左弹（用户报的缺陷）；成熟菜单（macOS/Windows/Scratch）
          // 的主方向都是「向右下展开」，仅在视口边缘翻转：
          // 先右下 → 右上（贴底时）→ 左下（贴右缘时）→ 左上（角落）。
          candidates=[
            @views.PresentationPlacementCandidate::BelowStart,
            @views.PresentationPlacementCandidate::AboveStart,
            @views.PresentationPlacementCandidate::BelowEnd,
            @views.PresentationPlacementCandidate::AboveEnd,
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
