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
  // 壳高分配：顶栏 40 + 状态栏 22 + 两条发丝线 + 底栏（展开态 bottom_height，
  // 否则 30 的页签头）。内容行吃掉剩下的全部高度。
  let bottom_height = if model.bottom_open {
    model.bottom_height
  } else {
    PANEL_HEAD_HEIGHT
  }
  // 沉浸式：顶栏之上多一条窗控带（信号点 + 拖拽区）。它属于窗口外壳，
  // 不占 IDE 的操作面高度——所以从内容高度里扣掉，顶栏本身保持 40。
  let window_bar = if model.immersive { WINDOW_CHROME_HEIGHT } else { 0.0 }
  let chrome = TOPBAR_HEIGHT +
    STATUSBAR_HEIGHT +
    bottom_height +
    window_bar +
    2.0
  let content_height = (height - chrome).max(200.0)
  let content = if fullscreen {
    // 全屏页（预览/帮助/运行）：两侧栏与图标栏都收起，内容居中占满
    @views.container(
      center_panel(model, t),
      background=ide_editor_background(),
      width~,
      height=content_height,
      padding=0.0,
    )
  } else {
    workspace_row(model, t, width, content_height)
  }
  let bottom = ide_bottom_bar(model, t, width)
  let bands : Array[@moui.View[Msg]] = []
  if model.immersive {
    bands.push(window_chrome_bar(model, t, width))
  }
  bands.push(ide_top_bar(model, t, width))
  bands.push(hairline())
  bands.push(content)
  bands.push(bottom)
  bands.push(hairline())
  bands.push(ide_status_bar(model, t, width))
  @views.container(
    @views.column(bands, spacing=0.0).frame(width~, height~),
    background=studio_window_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 内容行：图标栏 | 左栏 | 中心工作区 | 右栏。
/// 高度不写死——由窗口高度决定；但含竖直分隔线的 row 必须有确定高度，
/// 所以这里用固定 640（1280×800 窗口减去顶栏 40 + 状态栏 22 + 底栏 30 +
/// 两条发丝线），与旧实现 600 的口径一致（多了图标栏与底栏折叠态）。
fn workspace_row(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  row_height : Double,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    ide_icon_bar(model, t, row_height),
    hairline_v(),
  ]
  let chrome = shell_chrome_widths(model, width)
  // 左栏：树/数据/收起（收起时整列不占宽；窗口过窄时自动让位给中心）
  match chrome.left {
    Some(left_width) => {
      cells.push(ide_left_panel(model, t, left_width, row_height))
      cells.push(hairline_v())
    }
    None => ()
  }
  // 中心：工作区内容 + AI 浮动层的叠放宿主
  let center_width = chrome.center
  // 避让带：浮动卡（非停靠、非药丸）贴着中心列底部，把内容区按卡高让出来，
  // 卡片就不会压住窗格脚注或底栏。停靠态在右栏内联，不占中心高度。
  // stack 给每个子整帧，所以「让出高度」不能靠在 stack 里改子高度做
  // ——内容仍会被撑满整帧。正确做法是把中心列拆成**上下两段**：
  // 内容段拿 row_height − 带高，浮动卡段拿带高（卡片在段内贴底）。
  let band = ai_avoidance_band(model, center_width, row_height)
  // 两种叠放形态，按「要不要让位」选：
  //
  // - band > 0（浮动卡贴底）：**上下两段**。内容段拿 row_height − band，
  //   浮动卡段拿 band。stack 做不到这件事——stack 给每个子整帧，内容仍会
  //   被撑满，卡片就压在内容上。
  // - band == 0（hero / 药丸 / 停靠）：**stack 覆盖**。此时浮动层本就该叠在
  //   工作区之上（药丸是角标、hero 是空舞台主角）。若仍用两段式，两段各要
  //   整行高，第二段会被列框裁掉——hero 输入框与药丸会整块消失。
  let content_height = row_height - band
  let center = if band > 0.0 {
    @views.column(
      [
        @views.container(
          workspace_content(model, t, center_width, content_height),
          width=center_width,
          height=content_height,
          padding=0.0,
        ),
        @views.container(
          ai_overlay_layer(model, t, center_width, band),
          width=center_width,
          height=band,
          padding=0.0,
        ),
      ],
      spacing=0.0,
    ).frame(width=center_width, height=row_height)
  } else {
    @views.stack([
      workspace_content(model, t, center_width, row_height),
      ai_overlay_layer(model, t, center_width, row_height),
    ]).frame(width=center_width, height=row_height)
  }
  cells.push(center)
  // 右栏：Context + 快速操作 + 监视（AI 停靠时并入右栏顶部）
  cells.push(hairline_v())
  if model.ai_anchor is AiDocked && !model.ai_pill {
    cells.push(
      @views.column(
        [
          @views.container(
            match ai_layer(model, t, chrome.right, 340.0, 0.0) {
              Some(layer) => layer
              None => @views.text("", width=1.0, height=1.0)
            },
            width=chrome.right,
            height=340.0,
            padding=0.0,
          ),
          ide_right_panel(model, t, chrome.right, row_height - 340.0),
        ],
        spacing=0.0,
      ).frame(height=row_height),
    )
  } else {
    cells.push(ide_right_panel(model, t, chrome.right, row_height))
  }
  @views.row(cells, spacing=0.0, align=Start).frame(height=row_height)
}

///|
/// 三列宽度：窗口宽 − 图标栏后由左/中/右分配。
pub(all) struct ShellChromeWidths {
  left : Double?
  center : Double
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
fn shell_chrome_widths(model : Model, width : Double) -> ShellChromeWidths {
  let usable = (width - ICONBAR_WIDTH - 2.0).max(120.0)
  let center_min = 320.0
  let wants_left = !(model.left_view is LeftHidden)
  let left_want = LEFTBAR_WIDTH
  let right_want = RIGHTBAR_WIDTH
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
/// 避让带高度：浮动卡实际会占的高度；停靠/药丸态为 0（它们不盖内容）。
/// 与 ai_card_height 同源——两处各算一份，预留量和实际遮挡就会对不上。
fn ai_avoidance_band(
  model : Model,
  center_width : Double,
  row_height : Double,
) -> Double {
  if model.ai_pill || model.ai_anchor is AiDocked {
    return 0.0
  }
  // hero 态不避让：它本身就是空舞台的主角（占了内容区反而没意义，
  // 而且空舞台没有内容会被遮住）。
  if ai_hero(model) {
    return 0.0
  }
  let card_width = match model.ai_anchor {
    AiCenter => (center_width - 20.0).max(320.0).min(680.0)
    _ => (center_width * 0.42).max(300.0).min(360.0)
  }
  let needed = ai_card_height(model, card_width) + 24.0
  // 卡比工作区还高时不避让（避让只会把内容压没），让它盖着。
  if needed > row_height * 0.6 {
    0.0
  } else {
    needed
  }
}

///|
/// AI 浮动层：药丸态 → 药丸；展开态 → 浮动卡；无内容 → 空占位
/// （stack 的子必须占位，否则 stack 尺寸塌成 0）。
fn ai_overlay_layer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 停靠态由 workspace_row 并入右栏，这里不重复画
  if model.ai_anchor is AiDocked {
    return @views.text("", width=1.0, height=1.0)
  }
  // 保留带：底栏展开时把浮动层抬起来，避免压住审计时间线
  let reserve = if model.bottom_open { model.bottom_height } else { 30.0 }
  if model.ai_pill {
    return ai_pill_view(model, t, width, height, reserve)
  }
  match ai_layer(model, t, width, height, reserve) {
    Some(layer) => layer
    None => @views.text("", width=1.0, height=1.0)
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
  ]
  // toast 单独一层（非模态，最上层）：它不该拦输入，也不参与 Escape 顺序
  let with_modals = @views.overlay_host(base, specs)
  toast_host(with_modals, model)
}
