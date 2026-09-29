///|
/// v4 IDE 壳控件库：顶栏、图标栏、面板头、树行、徽标、分段控件、状态栏、
/// toast。全部是 @views 既有控件的组合（不新增 core 视觉枚举），
/// 样式一律取 theme.mbt 的 IDE 角色色。
///
/// 尺寸口径来自设计稿：顶栏 40 / 图标栏 48 / 面板头 30 / 树行 24 /
/// 状态栏 22 / 输入 26。行高是硬编码的（IDE 壳不做响应式缩排）。

// ============================================================================
// 尺寸常量（设计稿口径，集中一处便于比对）
// ============================================================================

///|
pub const TOPBAR_HEIGHT : Double = 40.0

///|
pub const ICONBAR_WIDTH : Double = 48.0

///|
pub const PANEL_HEAD_HEIGHT : Double = 30.0

///|
pub const TREE_ROW_HEIGHT : Double = 24.0

///|
/// 左栏「最近修改」最多显示几行（设计稿是短尾列表，超出就截断——
/// 它只是提示，不是完整历史）。
pub const RECENT_STRIP_ROWS : Int = 3

///|
/// 树行尾部元信息单元格宽：要装得下最宽的元信息（`640×480` 实测 68），
/// 否则整行溢出、面板把它裁掉一半。
pub const TREE_META_WIDTH : Double = 68.0

///|
pub const STATUSBAR_HEIGHT : Double = 22.0

///|
pub const FIELD_HEIGHT : Double = 26.0

///|
pub const LEFTBAR_MIN_WIDTH : Double = 200.0

///|
/// 左栏固定宽度：结构树/数据行宽都按它算。IDE 左栏不做拖拽改宽——
/// core 只暴露 drag 手势（无 pointer-move 流），改宽需要逐帧位置反馈。
pub const LEFTBAR_WIDTH : Double = 232.0

///|
pub const LEFTBAR_MAX_WIDTH : Double = 260.0

///|
pub const RIGHTBAR_WIDTH : Double = 272.0

// ============================================================================
// 基础件
// ============================================================================

///|
/// 铺满行的行：**所有带权重 spacer 的行都必须走这里**。
///
/// 为什么：容器盒（ContainerBox）把子节点居中摆放，`padding_layout` 又把
/// 子节点钳到「自己量出来的宽」。一条没显式定宽的 row 只会量到「子节点
/// 宽度之和」，于是权重 spacer 分不到任何 slack、整行还会被容器居中——
/// 表现就是顶栏内容挤在窗口中间而不是左右贴边。给 row 显式定宽后，
/// slack 才有来源。这是本项目最容易踩的布局陷阱。
pub fn fill_row(
  cells : Array[@moui.View[Msg]],
  width : Double,
  spacing : Double,
  align : @style.CrossAlign,
) -> @moui.View[Msg] {
  @views.row(cells, spacing~, align~).frame(width~)
}

///|
/// 发丝分隔线：面板之间的 1px 边。水平分隔按「可用宽度」测量——放进 column
/// 里必须用默认 Horizontal；放进 row 里必须显式 Vertical（横线会量到整行宽
/// 并盖住后面的兄弟，2026-09-27 面板消失事故的根因）。
pub fn hairline() -> @moui.View[Msg] {
  @views.divider(color=ide_border())
}

///|
/// 竖发丝：row 里的列分隔。
pub fn hairline_v() -> @moui.View[Msg] {
  @views.divider(axis=Vertical, color=ide_border())
}

///|
/// 面板头：全大写小标题 + 右侧元信息（计数/徽标槽）。
/// 30pt 高，左右各 8pt 内垫，底部 1px 边。
pub fn panel_head(
  label : String,
  meta : String,
  trailing : Array[@moui.View[Msg]],
  width : Double,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      label,
      theme=studio_theme(),
      width=140.0,
      height=18.0,
      align=TextStart,
    ).foreground(ide_text_faint()),
    @views.spacer(min_length=6.0, weight=0.0),
  ]
  if meta != "" {
    cells.push(
      @views.text(
        meta,
        theme=studio_theme(),
        width=48.0,
        height=18.0,
        align=TextEnd,
      ).foreground(ide_text_faint()),
    )
  }
  for item in trailing {
    cells.push(item)
  }
  @views.container(
    fill_row(cells, (width - 16.0).max(80.0), 4.0, Center),
    background=ide_panel(),
    height=PANEL_HEAD_HEIGHT,
    padding=0.0,
  )
}

///|
/// 面板空态提示：居中弱文字（整块区域无内容时用）。
pub fn empty_hint(label : String, height : Double) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width=240.0, height=20.0).foreground(
        ide_text_faint(),
      ),
      width=260.0,
      height~,
    ),
    height~,
    padding=0.0,
  )
}

///|
/// 计数徽标：中性灰底 + 弱文字（比 @views.badge 更小更淡，贴合 24pt 行高）。
pub fn count_badge(label : String, tone : Int) -> @moui.View[Msg] {
  let color = match tone {
    1 => ide_success()
    2 => ide_warning()
    3 => ide_danger()
    4 => ide_accent()
    _ => ide_text_faint()
  }
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width=52.0, height=14.0).foreground(
        color,
      ),
      width=56.0,
      height=18.0,
    ),
    background=ide_panel_alt(),
    corner_radius=9.0,
    width=56.0,
    height=18.0,
    padding=0.0,
  )
}

///|
/// 药丸标签：小圆角描边标签（顶栏语言/轨道、状态栏读数）。
pub fn pill(
  label : String,
  text_color : @graphics.Color,
  width : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width=width - 12.0, height=16.0).foreground(
        text_color,
      ),
      width~,
      height=20.0,
    ),
    background=ide_panel_alt(),
    corner_radius=4.0,
    width~,
    height=20.0,
    padding=0.0,
  )
}

///|
/// 图标按钮：图标栏与工具条共用。选中态用强调色弱底 + 强调色图标。
/// 无 hover 回调（core 只暴露 hovered 状态给节点），所以只有「选中/未选中」
/// 两态——设计稿的悬停底色由内置按钮的 Ghost 样式自然给出。
pub fn icon_button(
  icon : @style.IconName,
  tip : String,
  selected : Bool,
  on_click : Msg,
  width : Double,
  height : Double,
  icon_size : Double,
) -> @moui.View[Msg] {
  let tint = if selected { ide_accent() } else { ide_text_muted() }
  @views.container(
    @views.center(
      @views.icon(icon, size=icon_size, color=tint),
      width=width - 8.0,
      height=height - 8.0,
    ),
    background=if selected { ide_selection() } else { ide_panel() },
    corner_radius=6.0,
    width~,
    height~,
    padding=0.0,
  )
  .accessibility_label(tip)
  .on_tap(on_click)
}

///|
/// 文本芯片按钮：一眼可读的小动作（快速插入、快速操作、分类条）。
pub fn text_chip(
  label : String,
  on_click : Msg,
  width : Double,
  selected : Bool,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width=width - 10.0, height=16.0).foreground(
        if selected {
          ide_accent()
        } else {
          ide_text_muted()
        },
      ),
      width~,
      height=22.0,
    ),
    background=if selected { ide_selection() } else { ide_panel_alt() },
    corner_radius=4.0,
    width~,
    height=22.0,
    padding=0.0,
  ).on_tap(on_click)
}

///|
/// 树行：24pt 高、按层级缩进、可选前置箭头与尾部元信息。
/// 手搓而不是用 @views.tree_view —— 内置树行只有 id/label，没有图标、
/// 元信息与锁定态，而设计稿的结构树三样都要。
pub fn tree_row(
  label : String,
  meta : String,
  depth : Int,
  selected : Bool,
  has_children : Bool,
  expanded : Bool,
  on_click : Msg?,
  on_toggle : Msg?,
  width : Double,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = []
  // 展开箭头：只有分组行有；叶子占位保持缩进对齐
  match on_toggle {
    Some(message) =>
      cells.push(
        @views.container(
          @views.center(
            @views.icon(
              if expanded {
                ChevronDown
              } else {
                ChevronRight
              },
              size=12.0,
              color=if has_children {
                ide_text_muted()
              } else {
                ide_text_faint()
              },
            ),
            width=14.0,
            height=16.0,
          ),
          width=14.0,
          height=16.0,
          padding=0.0,
        ).on_tap(message),
      )
    None =>
      cells.push(
        @views.container(
          @views.text("", width=14.0, height=16.0),
          width=14.0,
          height=16.0,
          padding=0.0,
        ),
      )
  }
  // 标签宽度必须**从剩余空间反推**，不能写死 `width - 44`：
  // 有 meta 时会多出一个单元格加一条间距，写死的宽度会让整行溢出，
  // 行尾的 meta 被裁成「64」（窗体的 640×480 就撞过这个）。
  let indent = 8.0 + depth.to_double() * 12.0
  let available = (width - indent - 8.0).max(60.0)
  let arrow_width = 14.0
  // 52 装不下「640×480」（实测 68），元信息会溢出到面板外被裁成「64」。
  let meta_width = TREE_META_WIDTH
  let gap = 2.0
  let gaps = if meta != "" { 2.0 } else { 1.0 }
  let label_width = (available -
  arrow_width -
  meta_width * (if meta != "" { 1.0 } else { 0.0 }) -
  gap * gaps).max(40.0)
  cells.push(
    @views.text(
      label,
      theme=studio_theme(),
      width=label_width,
      height=18.0,
      align=TextStart,
    ).foreground(if selected { ide_text() } else { ide_text_muted() }),
  )
  if meta != "" {
    cells.push(
      @views.text(
        meta,
        theme=studio_theme(),
        width=meta_width,
        height=16.0,
        align=TextEnd,
      ).foreground(ide_text_faint()),
    )
  }
  let row = @views.container(
    @views.padding_edges(
      fill_row(cells, available, gap, Center),
      left=indent,
      right=8.0,
    ),
    background=if selected { ide_selection() } else { ide_panel() },
    height=TREE_ROW_HEIGHT,
    width~,
    padding=0.0,
  )
  match on_click {
    Some(message) => row.on_tap(message)
    None => row
  }
}

///|
/// 键值行：右栏 Context 的属性/状态/数据页签共用（左标签 + 右值）。
pub fn kv_row(
  label : String,
  value : String,
  width : Double,
  mono : Bool,
) -> @moui.View[Msg] {
  @views.container(
    fill_row(
      [
        @views.text(
          label,
          theme=studio_theme(),
          width=(width * 0.42).max(48.0),
          height=18.0,
          align=TextStart,
        ).foreground(ide_text_faint()),
        @views.text(
          value,
          theme=studio_theme(),
          role=if mono { Mono } else { Body },
          width=(width * 0.52).max(56.0),
          height=18.0,
          align=TextStart,
        ).foreground(ide_text()),
      ],
      width,
      6.0,
      Center,
    ),
    height=22.0,
    width~,
    padding=0.0,
  )
}

///|
/// 内联卡：AI 线程卡 / 审计卡 / 计划卡的共同外形（抬起面 + 圆角 + 左边色条）。
/// 左边色条用 3pt 容器实现——设计稿每类卡都有左侧语义色。
pub fn inline_card(
  accent : @graphics.Color,
  body : @moui.View[Msg],
  width : Double,
  settled : Bool,
) -> @moui.View[Msg] {
  let content = @views.container(
    body,
    background=if settled { ide_panel() } else { ide_elevated() },
    corner_radius=4.0,
    width~,
    padding=8.0,
  )
  let card = @views.row(
    [
      @views.container(
        @views.text("", width=3.0, height=1.0),
        background=accent,
        width=3.0,
        padding=0.0,
      ),
      content,
    ],
    spacing=0.0,
    align=Start,
  )
  card
}

///|
/// 进度条：AI 计划卡的进度（4pt 高，两段容器拼）。
pub fn progress_bar(percent : Int, width : Double) -> @moui.View[Msg] {
  let clamped = percent.max(0).min(100)
  let filled = width * clamped.to_double() / 100.0
  @views.container(
    @views.row(
      [
        @views.container(
          @views.text("", width=filled, height=4.0),
          background=ide_accent(),
          corner_radius=2.0,
          width=filled,
          height=4.0,
          padding=0.0,
        ),
        @views.container(
          @views.text("", width=(width - filled).max(0.0), height=4.0),
          background=ide_panel_alt(),
          corner_radius=2.0,
          width=(width - filled).max(0.0),
          height=4.0,
          padding=0.0,
        ),
      ],
      spacing=0.0,
    ),
    width~,
    height=4.0,
    padding=0.0,
  )
}

///|
/// 差分行：diff 卡的 ± 行（等宽，前缀着色）。
pub fn diff_row(
  marker : String,
  text : String,
  width : Double,
) -> @moui.View[Msg] {
  let color = match marker {
    "+" => ide_success()
    "-" => ide_danger()
    _ => ide_text_faint()
  }
  @views.row(
    [
      @views.text(
        marker,
        theme=studio_theme(),
        role=Mono,
        width=12.0,
        height=16.0,
      ).foreground(color),
      @views.text(
        text,
        theme=studio_theme(),
        role=Mono,
        width=(width - 30.0).max(40.0),
        height=16.0,
        align=TextStart,
      ).foreground(if marker == " " { ide_text_muted() } else { ide_text() }),
    ],
    spacing=2.0,
    align=Center,
  )
}

// ============================================================================
// 顶栏
// ============================================================================

///|
/// 品牌标记：2×2 四色方块（设计稿的 logo）。
pub fn brand_mark() -> @moui.View[Msg] {
  let cell = fn(color : @graphics.Color) -> @moui.View[Msg] {
    @views.container(
      @views.text("", width=7.0, height=7.0),
      background=color,
      corner_radius=1.0,
      width=7.0,
      height=7.0,
      padding=0.0,
    )
  }
  @views.container(
    @views.column(
      [
        @views.row([cell(ide_accent()), cell(ide_success())], spacing=2.0),
        @views.row([cell(ide_warning()), cell(ide_danger())], spacing=2.0),
      ],
      spacing=2.0,
    ),
    width=18.0,
    height=18.0,
    padding=0.0,
  )
}

///|
/// 顶栏左侧：品牌 + 产品名 + 脏标 + 面包屑。
pub fn topbar_brand(
  title : String,
  dirty : Bool,
  crumb : String,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    brand_mark(),
    @views.text(
      title,
      theme=studio_theme(),
      width=110.0,
      height=20.0,
      align=TextStart,
    ).foreground(ide_text()),
  ]
  if dirty {
    cells.push(
      @views.text("●", theme=studio_theme(), width=8.0, height=18.0).foreground(
        ide_warning(),
      ),
    )
  }
  if crumb != "" {
    cells.push(
      @views.text(
        crumb,
        theme=studio_theme(),
        width=220.0,
        height=18.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
    )
  }
  @views.row(cells, spacing=8.0, align=Center)
}

///|
/// 沉浸式标题带高度（无边框窗口的窗口控制面）。
///
/// **不是额外的一条带子**：沉浸态下这一带与顶栏合并成**同一条 56pt 标题栏**
/// （IDEA 口径），所以它只描述「标题栏总高」，不再描述「顶栏之上额外加多少」。
/// 旧实现是 26 + 40 两条：上一条只放一句居中提示文字、底色
/// `studio_window_background()`（#16181c），下一条顶栏 `ide_panel()`（#2b2d30），
/// 交界处出现一条明显的两截色缝，且标题栏区域一半是空的——这正是「最上面的
/// 窗口边框不沉浸」的直接成因。
pub const WINDOW_CHROME_HEIGHT : Double = 56.0

///|
/// 左上角留给系统信号灯的宽度（三个 12pt 圆 + 间距 + 左右边距）。
///
/// 实测原生窗口：三灯直径 13pt，圆心 y = 15.8（窗口顶往下），最右一颗右缘
/// 68pt。所以自绘内容的左边距取 78 才不会钻到绿灯底下——这是 AppKit 的固定
/// 几何，不是主题值，所以不跟着主题变。
pub const TRAFFIC_LIGHT_INSET : Double = 78.0

///|
/// 拖拽区语义：沉浸态整条顶栏都是「按住可以拖窗口」。
///
/// **这里不自绘三个信号点。** `transparent_titlebar` 只把标题栏变透明 +
/// 内容延伸到顶端，系统信号灯（关闭/最小化/缩放）照常浮在左上角；再画三
/// 个假点会叠成六个，而且自绘的缩放按钮没有可用的窗口请求
/// （`WindowRequest` 没有 zoom 变体）——那就是死 UI。用系统的，三个都是
/// 真的，还自带悬停反馈与键盘可达性。
///
/// 自绘内容只需让出左侧 `TRAFFIC_LIGHT_INSET`（别钻到信号灯底下）；
/// 拖拽矩形由入口在视图构建期交给 `WindowDragRegionSource`，
/// 宿主按 revision 去重后下发 AppKit。
///
/// **拖拽区必须避开右侧动作簇**（宽度见 `topbar_drag_width`）：AppKit 的
/// presenter 命中拖拽区时直接 `performWindowDragWithEvent:`，不再把事件交给
/// 运行时，所以落在动作簇上的按下会变成拖窗口而不是点按钮。

// ============================================================================
// 状态栏
// ============================================================================

///|
/// 文本宽度估算：ASCII 按 7.9、全角按 13.0（与 `token_width` 同一口径）。
/// 状态栏这类「等宽读数条」必须按内容给宽度——固定 112 会让长标签越出
/// 窗口右缘（实测 w=1000 时「空闲」右缘 1133）。
pub fn text_estimate_width(label : String) -> Double {
  let mut ascii = 0
  let mut wide = 0
  for c in label {
    if c.to_int() < 0x80 {
      ascii = ascii + 1
    } else {
      wide = wide + 1
    }
  }
  (ascii.to_double() * 7.9 + wide.to_double() * 13.0).max(6.0)
}

///|
/// 状态栏：等宽读数条。cells 为空时只留品牌段（不塌成 0 高）。
/// 单元格宽度按内容算，并整体钳进可用宽度（窗口窄时截断而不是溢出）。
pub fn status_cells(
  cells : Array[(String, Int)],
  width : Double,
) -> @moui.View[Msg] {
  let views : Array[@moui.View[Msg]] = []
  // 先算「内容 + 分隔符」的总宽，超出可用宽度时按比例压缩每格。
  let inner = (width - 20.0).max(120.0)
  let mut needed = 0.0
  let mut index = 0
  for cell in cells {
    if index > 0 {
      needed = needed + 8.0 + 6.0
    }
    needed = needed + text_estimate_width(cell.0) + 6.0
    index = index + 1
  }
  let scale = if needed > inner { inner / needed } else { 1.0 }
  index = 0
  for cell in cells {
    if index > 0 {
      views.push(
        @views.text("·", theme=studio_theme(), width=8.0, height=16.0).foreground(
          ide_text_faint(),
        ),
      )
    }
    let (label, tone) = cell
    views.push(
      @views.text(
        label,
        theme=studio_theme(),
        role=Mono,
        width=(text_estimate_width(label) * scale).max(8.0),
        height=16.0,
        align=TextStart,
      ).foreground(
        match tone {
          1 => ide_success()
          2 => ide_warning()
          3 => ide_danger()
          4 => ide_accent()
          _ => ide_text_muted()
        },
      ),
    )
    index = index + 1
  }
  views.push(@views.spacer(min_length=0.0, weight=1.0))
  @views.padding_xy(
    fill_row(views, (width - 20.0).max(120.0), 6.0, Center),
    horizontal=10.0,
    vertical=0.0,
  )
}
