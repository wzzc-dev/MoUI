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
/// 图标栏宽度：参考 VS Code 紧凑活动栏口径（实测截图 ~34pt，原版默认
/// 48px 满格槽位；这里取窄栏 + 28pt 节距的组合）。顶栏/内容行的宽度
/// 分配都从它推导（`width - ICONBAR_WIDTH`）。
pub const ICONBAR_WIDTH : Double = 34.0

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
/// 面板头：小标题 + 可选右侧元信息 + 尾部动作（30pt 高）。
///
/// **尾部动作必须贴右缘。** 旧实现里权重 spacer 写的是 `weight=0.0`——它
/// 分不到任何 slack，于是行内容按「声明宽之和」靠左排，右端剩下的 40pt 空白
/// 堆在动作**之后**。表现就是左栏的关闭 ✕ 停在离右缘 40pt 的地方（实测 ✕
/// 中心 css x 221.8，而面板右缘 281），看起来「位置不对」。`fill_row` 的
/// 注释里早写过这条纪律，这里是把 `weight` 真的给上。
///
/// 标题宽按「面板宽 − 内垫 − 尾部占位 − 间隙」算：写死 140 会在窄面板里把
/// 动作挤出去，而尾部占位**按调用方声明的实际宽**给（见 `PanelHeadAction`）——
/// 统一按 22 预留是错的：`count_badge` 是 56 宽，按 22 留会让它越出右缘
/// （实测监视面板的计数徽标画到窗口外）。
pub fn panel_head(
  label : String,
  meta : String,
  trailing : Array[@moui.View[Msg]],
  width : Double,
  trailing_widths? : Array[Double] = [],
) -> @moui.View[Msg] {
  // 先扣掉尾部动作与元信息，剩下的才给标题
  let meta_w = (text_estimate_width(meta) * 1.02).max(28.0)
  let mut reserved = if meta != "" { meta_w } else { 0.0 }
  let mut i = 0
  for item in trailing {
    ignore(item)
    reserved = reserved +
      (if i < trailing_widths.length() { trailing_widths[i] } else { 22.0 })
    i = i + 1
  }
  let gaps = 4.0 * (trailing.length() + 1).to_double()
  // 标题按**内容**给宽，不把「面板宽 − 尾部」的剩余全部吃掉。
  //
  // 这一点是刻意的：标题一旦吃满剩余，权重 spacer 就永远拿不到余量，
  // 「尾部贴右缘」便成了由标题宽度**碰巧**保证的结果——spacer 的 `weight`
  // 写 0 还是 1 都看不出来。实测：标题吃满剩余时，故意把 weight 改回 0.0，
  // 那条「尾部贴右缘」的测试**仍然通过**（断言等于失效）。让标题只占内容
  // 宽，余量才真正交给 spacer，`weight` 才是起作用的那一环。
  let title_w = (text_estimate_width(label) * 1.02 + 8.0)
    .min((width - 16.0 - reserved - gaps).max(40.0))
    .max(28.0)
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      label,
      theme=studio_theme(),
      width=title_w,
      height=18.0,
      align=TextStart,
    ).foreground(ide_text_faint()),
    // 权重 1：把后面的动作推到右缘。`min_length` 只保证最小间隙。
    @views.spacer(min_length=6.0, weight=1.0),
  ]
  if meta != "" {
    cells.push(
      @views.text(
        meta,
        theme=studio_theme(),
        width=meta_w,
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
/// 提示文案的贪心换行：拉丁文按词断行（空格处），CJK 逐字断行。
///
/// `@views.text` 不折行（单 TextRun），而 `@views.text` 的布局又是
/// `max(声明宽, 实测宽)`——声明窄了文字会**自己长出去**溢出容器。长提示
/// （本地化文案动辄 500-800pt）必须在这里先切成能放下的行。
/// 估算口径与 `text_estimate_width` 一致（ASCII 7.9 / 全角 13.0）。
pub fn wrap_text_lines(label : String, max_width : Double) -> Array[String] {
  let lines : Array[String] = []
  let mut line = ""
  let mut line_w = 0.0
  let mut seg = ""
  let mut seg_w = 0.0
  let mut pending_gap = 0.0
  for c in label {
    if c == ' ' {
      if seg_w > 0.0 {
        // 先把攒着的拉丁段装进行
        if line_w == 0.0 || line == "" {
          line = seg
          line_w = seg_w
        } else if line_w + pending_gap + seg_w <= max_width {
          line = line + " " + seg
          line_w = line_w + pending_gap + seg_w
        } else {
          lines.push(line)
          line = seg
          line_w = seg_w
        }
        seg = ""
        seg_w = 0.0
        pending_gap = 0.0
      }
      if line_w > 0.0 {
        pending_gap = 7.9
      }
    } else if c.to_int() < 0x80 {
      seg = seg + c.to_string()
      seg_w = seg_w + 7.9
    } else {
      // CJK：先冲刷拉丁段，再逐字装行（每个字都是断行点）
      if seg_w > 0.0 {
        if line_w == 0.0 || line == "" {
          line = seg
          line_w = seg_w
        } else if line_w + pending_gap + seg_w <= max_width {
          line = line + " " + seg
          line_w = line_w + pending_gap + seg_w
        } else {
          lines.push(line)
          line = seg
          line_w = seg_w
        }
        seg = ""
        seg_w = 0.0
        pending_gap = 0.0
      }
      if line_w == 0.0 || line == "" {
        line = c.to_string()
        line_w = 13.0
      } else if line_w + 13.0 <= max_width {
        line = line + c.to_string()
        line_w = line_w + 13.0
      } else {
        lines.push(line)
        line = c.to_string()
        line_w = 13.0
      }
    }
  }
  if seg_w > 0.0 {
    if line_w == 0.0 || line == "" {
      line = seg
    } else if line_w + pending_gap + seg_w <= max_width {
      line = line + " " + seg
    } else {
      lines.push(line)
      line = seg
    }
  }
  if line != "" {
    lines.push(line)
  }
  lines
}

///|
/// 换行后的行数（给需要提前预算高度的地方用）。
pub fn wrapped_line_count(label : String, max_width : Double) -> Int {
  wrap_text_lines(label, max_width).length()
}

///|
/// 多行提示块：把长提示按可用宽折行后逐行渲染（每行 18pt + 2pt 间距）。
/// 超出 max_lines 的行用省略号截断——宁可少一句，也不要溢出容器。
pub fn hint_lines_view(
  label : String,
  width : Double,
  color : @graphics.Color,
  max_lines : Int,
) -> @moui.View[Msg] {
  let usable = (width - 4.0).max(60.0)
  let all = wrap_text_lines(label, usable)
  let views : Array[@moui.View[Msg]] = []
  let mut index = 0
  for line in all {
    if index >= max_lines {
      // 截断提示：把最后一行换成带省略号的版本
      if index == max_lines {
        let prev = all[max_lines - 1]
        views[views.length() - 1] = @views.text(
          fit_label(prev, usable),
          theme=studio_theme(),
          width=usable,
          height=18.0,
          align=TextStart,
        ).foreground(color)
      }
      break
    }
    views.push(
      @views.text(
        line,
        theme=studio_theme(),
        width=usable,
        height=18.0,
        align=TextStart,
      ).foreground(color),
    )
    index = index + 1
  }
  if views.length() == 0 {
    views.push(
      @views.text(
        "",
        theme=studio_theme(),
        width=usable,
        height=18.0,
        align=TextStart,
      ),
    )
  }
  @views.column(views, spacing=2.0)
}

///|
/// 面板空态提示：居中弱文字（整块区域无内容时用）。
/// 长提示按可用宽折行（最多 3 行）——写死一行宽在本地化长句上必然溢出。
pub fn empty_hint(
  label : String,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let usable = (width - 16.0).max(120.0).min(420.0)
  let block = hint_lines_view(label, usable, ide_text_faint(), 3)
  @views.container(
    @views.center(block, width=usable, height~),
    height~,
    padding=0.0,
  )
}

///|
/// 计数徽标：中性灰底 + 弱文字（比 @views.badge 更小更淡，贴合 24pt 行高）。
/// 宽度按内容算（「已处理」与「12」差一倍多，写死必然一侧截断或虚胖）。
pub fn count_badge(label : String, tone : Int) -> @moui.View[Msg] {
  let color = match tone {
    1 => ide_success()
    2 => ide_warning()
    3 => ide_danger()
    4 => ide_accent()
    _ => ide_text_faint()
  }
  let width = (text_estimate_width(label) * 1.02 + 12.0).max(24.0)
  @views.container(
    @views.center(
      @views.text(label, theme=studio_theme(), width~, height=14.0).foreground(
        color,
      ),
      width~,
      height=18.0,
    ),
    background=ide_panel_alt(),
    corner_radius=9.0,
    width~,
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
/// `tile`：是否画**常驻选中底块**。活动栏走紧凑口径（裸字形，选中只有
/// 字形亮度一层）时传 `false`；面板头等工具条按钮保持默认的底块两态。
pub fn icon_button(
  icon : @style.IconName,
  tip : String,
  selected : Bool,
  on_click : Msg,
  width : Double,
  height : Double,
  icon_size : Double,
  tile? : Bool = true,
) -> @moui.View[Msg] {
  // VS Code 活动栏口径：选中 = **深灰微高亮底 + 白色字形**（不是蓝底蓝字
  // ——蓝色块连排是「不协调」的主因）；未选中 = 灰字形裸露（底色与所在
  // 表面同色，即视觉透明）。`tile=false` 时选中也不画底块（颜色两态保留：
  // 亮字 = 活动态）。
  let tint = if selected { ide_text() } else { ide_text_muted() }
  @views.container(
    @views.center(
      @views.icon(icon, size=icon_size, color=tint),
      width=width - 8.0,
      height=height - 8.0,
    ),
    background=if selected && tile { ide_hover() } else { ide_panel() },
    corner_radius=4.0,
    width~,
    height~,
    padding=0.0,
  )
  .accessibility_label(tip)
  // 悬停把说明写进状态栏：图标按钮没有文字，状态栏提示是 IDE 的成熟口径
  // （VS Code/IDEA 的图标悬停解释区），且对键盘用户同样可达。
  //
  // 注：框架**有**可用的 `@views.tooltip`（见 controls/control_focus_overlay.mbt，
  // 走 presentation 定位浮层，`examples/excel` 在用）。这里不用它，是因为
  // tooltip 需要调用方自己持有 `visible` 状态与逐元素的 hover 追踪，而顶栏
  // 图标簇共用一处状态栏格已经够用；换成浮层是可选优化，不是能力缺失。
  .on_hover(active => HoverHint(if active { tip } else { "" }))
  .on_tap(on_click)
}

///|
/// Ghost 图标按钮：透明底（融入所在表面），选中态才点亮——现代 AI 面板
/// 的头部口径（Codex/ZCode）：标题行不留一排「小方块」，操作都在安静处。
/// `surface` 是所在表面的底色（ghost 态与它同色 = 视觉透明）。
pub fn ghost_icon_button(
  icon : @style.IconName,
  tip : String,
  selected : Bool,
  on_click : Msg,
  width : Double,
  height : Double,
  icon_size : Double,
  surface : @core.Color,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.icon(
        icon,
        size=icon_size,
        color=if selected {
          ide_accent()
        } else if tip == "" {
          ide_text_faint()
        } else {
          ide_text_muted()
        },
      ),
      width~,
      height~,
    ),
    background=if selected { ide_selection() } else { surface },
    corner_radius=6.0,
    width~,
    height~,
    padding=0.0,
  )
  .accessibility_label(tip)
  // 悬停把说明写进状态栏：图标按钮没有文字，状态栏提示是 IDE 的成熟口径
  // （VS Code/IDEA 的图标悬停解释区），且键盘用户同样可达。
  // 框架另有可用的 `@views.tooltip`（定位浮层，`examples/excel` 在用）——
  // 这里不用它是因为整簇图标共用一处状态栏格已经够用，不是能力缺失。
  .on_hover(active => HoverHint(if active { tip } else { "" }))
  .on_tap(on_click)
}

///|
/// 带键盘快捷键的图标按钮（撤销/重做这类「必须有键位」的动作）。
///
/// **为什么不用 `icon_button` + `.keyboard_shortcut(...)`**：runtime 的
/// 快捷键通路匹配后走的是 `activate_primary` → 给第一个子节点合成一个
/// **Enter 键盘事件**（`input_keyboard.mbt`），而 `on_tap` 只认 Pointer
/// 事件（`modifier_event.mbt` 的 `OnTapModifier` 分支）。所以
/// `keyboard_shortcut` 套在 `on_tap` 外壳上**永远不会触发**。
/// 这里改用真正的 `@views.button`——它的 event 分支显式处理
/// `Enter`/`Space`（`views/button/button.mbt`），是唯一对合成事件有反应的载体；
/// 图标盒由外层容器画，视觉与 `icon_button` 一致。
///
/// 快捷键徽标不进顶栏（24pt 高度放不下），键位在命令面板与快捷键表可见
/// ——IDEA 的口径也是标题栏图标不挂徽标。
pub fn shortcut_icon_button(
  icon : @style.IconName,
  tip : String,
  on_click : Msg,
  shortcut : @core.KeyboardShortcut,
  width : Double,
  height : Double,
  icon_size : Double,
  alt_shortcut? : @core.KeyboardShortcut? = None,
) -> @moui.View[Msg] {
  @views.stack([
    @views.container(
      @views.center(
        @views.icon(icon, size=icon_size, color=ide_text_muted()),
        width~,
        height~,
      ),
      background=ide_panel_alt(),
      corner_radius=4.0,
      width~,
      height~,
      padding=0.0,
    ),
    shortcut_button_shell(on_click, shortcut, alt_shortcut, width, height),
  ]).accessibility_label(tip)
}

///|
/// 快捷键按钮的载体：`@views.button`（唯一对合成 Enter 有反应的控件）+
/// 一条或两条 shortcut 链。两条覆盖 meta（macOS）与 control（Windows/Linux）。
fn shortcut_button_shell(
  on_click : Msg,
  shortcut : @core.KeyboardShortcut,
  alt_shortcut : @core.KeyboardShortcut?,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let base = @views.button(
    "",
    on_click~,
    variant=Ghost,
    theme=studio_theme(),
    width~,
    height~,
  ).keyboard_shortcut(shortcut)
  match alt_shortcut {
    Some(alt) => base.keyboard_shortcut(alt)
    None => base
  }
}

///|
/// 圆形主行动按钮（发送）：实心强调色圆 + 箭头图标——Codex/ZCode 输入盒
/// 的收尾形态。`enabled=false` 时降为面板色 + 弱图标（忙碌态）。
pub fn round_send_button(
  tip : String,
  on_click : Msg,
  enabled : Bool,
  size : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.icon(
        ArrowRight,
        size=(size - 12.0).max(10.0),
        color=if enabled {
          studio_theme().palette.on_primary
        } else {
          ide_text_faint()
        },
      ),
      width=size,
      height=size,
    ),
    background=if enabled { ide_accent() } else { ide_elevated() },
    corner_radius=size / 2.0,
    width=size,
    height=size,
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
/// 顶栏动作芯片高度：IDEA/VSCode 标题栏口径。标题栏与系统信号灯同排，
/// 36pt 的 `@views.button`（height 只是最小值，实测渲染 36+）和红黄绿
/// 挤在一排非常突兀；成熟 IDE 的标题栏动作都是 22-26pt 的安静芯片。
pub const TOPBAR_ACTION_HEIGHT : Double = 24.0

///|
/// 顶栏动作芯片的宽度**上界**（13pt caption 文本 + 两侧内垫 20）。
///
/// 拖拽区声明与渲染共用 `topbar_actions_width` → 这里，两处不会漂移。
/// 取上界是刻意的：估宽只少几个可拖点（无害），估窄会让芯片自己长出去
/// 把兄弟挤出动作簇左缘、被拖拽区盖住（严重，且只在原生窗口复现）。
pub fn topbar_chip_bound(label : String, declared : Double) -> Double {
  let mut ascii = 0
  let mut wide = 0
  for c in label {
    if c.to_int() < 0x80 {
      ascii = ascii + 1
    } else {
      wide = wide + 1
    }
  }
  (ascii.to_double() * 8.0 + wide.to_double() * 13.0 + 20.0).max(declared)
}

///|
/// 顶栏动作芯片：24pt 高、13pt 字。`primary` 是唯一主行动作（运行）——
/// 强调色填充；其余保持安静的面板二档底。`on_click` 为 None 时是禁用态
/// （弱文字、不可点）——诚实地表达「此动作当前不可用」而不是藏起来。
pub fn topbar_action(
  label : String,
  on_click : Msg?,
  primary : Bool,
  width : Double,
) -> @moui.View[Msg] {
  let enabled = on_click is Some(_)
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        role=Caption,
        width=(width - 20.0).max(20.0),
        height=14.0,
      ).foreground(
        if primary {
          studio_theme().palette.on_primary
        } else if enabled {
          ide_text()
        } else {
          ide_text_faint()
        },
      ),
      width~,
      height=TOPBAR_ACTION_HEIGHT,
    ),
    background=if primary && enabled { ide_accent() } else { ide_panel_alt() },
    corner_radius=4.0,
    width~,
    height=TOPBAR_ACTION_HEIGHT,
    padding=0.0,
  )
  .accessibility_label(label)
  .on_tap_with_frame(fn(_point, _frame) {
    match on_click {
      Some(message) => message
      None => Msg::Noop
    }
  })
}

///|
/// 动作芯片的语气：安静（面板二档底）/ 主行动（强调色填充）/ 幽灵（透明）。
pub(all) enum ChipTone {
  Quiet
  Primary
  Ghost
}

///|
/// 动作芯片的标签宽：16pt 正文字号口径 + 5% 安全系数 + 两侧内垫 20。
/// 芯片宽**必须按内容算**——写死会把某种语言下的标签截掉半个词
/// （本仓复发最多的缺陷族）。
pub fn chip_label_width(label : String) -> Double {
  text_estimate_width(label) * 1.05 + 20.0
}

///|
/// 通用动作芯片：AI 卡决策行 / 线程卡 / 卡片内的小动作。
/// 手搓而不用 `@views.button`：button 的宽高是**最小值**（实测声明 24
/// 渲染 36），会把「高度预算按芯片算」的容器撑溢出——凡是高度预算
/// 单点计算的容器，里面的动作必须用严格等高的芯片。
pub fn action_chip(
  label : String,
  on_click : Msg,
  tone : ChipTone,
  height : Double,
) -> @moui.View[Msg] {
  let width = chip_label_width(label)
  let (background, foreground) = match tone {
    Primary => (ide_accent(), studio_theme().palette.on_primary)
    Quiet => (ide_panel_alt(), ide_text())
    Ghost => (ide_panel(), ide_text_muted())
  }
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(width - 20.0).max(20.0),
        height=16.0,
      ).foreground(foreground),
      width~,
      height~,
    ),
    background~,
    corner_radius=4.0,
    width~,
    height~,
    padding=0.0,
  )
  .accessibility_label(label)
  .on_tap(on_click)
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
  trailing? : @moui.View[Msg]? = None,
  trailing_width? : Double = 0.0,
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
  // 尾部动作（分组头的「+」）也占一格加一条间距——**必须进宽度账**，
  // 漏算会让 meta 溢出到面板外被裁（这个文件里已有两次同类教训：
  // meta 写死 52 时「640×480」被裁成「64」，尾部动作漏算同源）。
  let has_trailing = trailing is Some(_)
  let gaps = (if meta != "" { 2.0 } else { 1.0 }) +
    (if has_trailing { 1.0 } else { 0.0 })
  let label_width = (available -
  arrow_width -
  meta_width * (if meta != "" { 1.0 } else { 0.0 }) -
  trailing_width -
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
  match trailing {
    Some(action) => cells.push(action)
    None => ()
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
    corner_radius=8.0,
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
/// 顶栏左侧：产品名 + 脏标 + 面包屑。
///
/// **不画 2×2 四色方块。** 那是设计稿的 `<div class="logo">` 占位 logo；
/// 无边框窗口里它紧挨着系统信号灯，四个彩色小方块和红黄绿挤在一行视觉上
/// 很吵，而且它不承载任何信息（产品名已经在旁边）。去掉后顶栏左端更干净，
/// 也把「窗口控件」与「应用品牌」两件事分开。
pub fn topbar_brand(
  title : String,
  dirty : Bool,
  crumb : String,
) -> @moui.View[Msg] {
  // 品牌与面包屑按内容给宽——面包屑是「代码 › 按钮.被单击」这类组合串，
  // 写死 220 会在长控件名（或英文界面）下被面板裁掉。
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      title,
      theme=studio_theme(),
      width=(text_estimate_width(title) * 1.02 + 8.0).min(220.0),
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
        width=(text_estimate_width(crumb) * 1.02 + 8.0).min(280.0),
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
/// **这一条就是顶栏本身**（不是顶栏之上再加一条带子）。它的高度由
/// **系统信号灯的垂直位置**决定：`transparent_titlebar` 不给移动信号灯的
/// 能力（自绘是死 UI，挪系统按钮要碰私有视图层级），AppKit 把三灯圆心
/// 固定在窗口顶往下 **15.8pt**（实测）。所以带高取 2 × 15.8 ≈ 32：内容在
/// 带内垂直居中，中心正好落在灯的圆心上——标题、芯片与红黄绿读起来是
/// **同一行**。旧值 56 把内容居中在 28pt，比灯低 12pt，截图里就是
/// 「信号灯和图标两条线」。
pub const WINDOW_CHROME_HEIGHT : Double = 32.0

///|
/// 系统信号灯的圆心 y（窗口顶往下，实测 15.8）。这是 AppKit 的固定几何，
/// 不随主题或带高变——沉浸标题栏的内容对齐目标就是这条线。
pub const TRAFFIC_LIGHT_CENTER_Y : Double = 15.8

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
  right_align : Bool,
) -> @moui.View[Msg] {
  let views : Array[@moui.View[Msg]] = []
  // 右组**贴右**：前缀 weight spacer；左组贴左（VS Code 状态栏口径：
  // 左组顶格、右组顶右，中间由外层 weight spacer 撑开）。
  if right_align {
    views.push(@views.spacer(min_length=0.0, weight=1.0))
  }
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
  @views.padding_xy(
    fill_row(views, (width - 20.0).max(120.0), 6.0, Center),
    horizontal=10.0,
    vertical=0.0,
  )
}
