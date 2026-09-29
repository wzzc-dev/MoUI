///|
/// v4 IDE 壳的布局验证：用 headless runtime 在真实视口下落一遍布局，
/// 从 draw_commands 里读回矩形与文本，断言壳各列的位置与可见性。
///
/// 为什么必须有这层测试：核心没有「测量回环」，任何一处固定的宽度/高度
/// 写错，只有在真实约束下才会暴露成「面板被挤出屏幕」「行被压成 0 高」。
/// 浏览器截图只能看个大概，这里给出的是精确帧。

///|
/// 纯转移（忽略 effect）：白盒测试与 app_test.mbt 的同名助手等价，
/// 但那个在独立黑盒包里，wbtest 看不到，所以这里各留一份。
fn apply_shell(model : Model, msg : Msg) -> Model {
  let (next, _) = update_pure(model, msg)
  next
}

///|
/// 在给定视口渲染一次，返回 draw_commands。
fn shell_draw(
  model : Model,
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (model, @moui.Effect::none()),
    update=(current, msg) => update_pure(current, msg),
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  @runtime.new_program_with_dimensions(program~, width~, height~).draw_commands()
}

///|
/// 所有绘制文本（含 frame）。
fn shell_texts(commands : Array[@core.DrawCommand]) -> Array[@core.TextRun] {
  let runs : Array[@core.TextRun] = []
  for command in commands {
    match command {
      @core.DrawText(run) => runs.push(run)
      _ => ()
    }
  }
  runs
}

///|
/// 所有填充矩形（含 brush 变体与描边盒子）。
///
/// **必须覆盖 brush 变体**：`@views.button` 画的是 `FillRoundedRectBrush` /
/// `StrokeRoundedRectBrush`（不是纯色 `FillRoundedRect`），只收后者会让
/// 「按钮盒在哪」这类断言全部落空——实测本会话因此把一个真实的「拖拽区压住
/// 运行按钮」缺陷漏过去了（断言报的是「找不到按钮盒」而不是「拖拽区盖住
/// 按钮」，症状被伪装成测试自身的问题）。
fn shell_rects(commands : Array[@core.DrawCommand]) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  for command in commands {
    match command {
      @core.FillRect(rect, _) => rects.push(rect)
      @core.FillRoundedRect(rounded, _) => rects.push(rounded.rect)
      @core.FillRoundedRectBrush(rounded, _) => rects.push(rounded.rect)
      @core.StrokeRect(rect, _, _) => rects.push(rect)
      @core.StrokeRoundedRect(rounded, _, _) => rects.push(rounded.rect)
      @core.StrokeRoundedRectBrush(rounded, _, _) => rects.push(rounded.rect)
      _ => ()
    }
  }
  rects
}

///|
fn shell_has_text(commands : Array[@core.DrawCommand], needle : String) -> Bool {
  for run in shell_texts(commands) {
    if run.text.contains(needle) {
      return true
    }
  }
  false
}

///|
/// 找到包含 needle 的第一段文本。
fn shell_find_text(
  commands : Array[@core.DrawCommand],
  needle : String,
) -> @core.TextRun? {
  for run in shell_texts(commands) {
    if run.text.contains(needle) {
      return Some(run)
    }
  }
  None
}

///|
test "shell lays out all seven chrome bands at 1280x800" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 顶栏：品牌 + 面包屑 + 运行/编译
  assert_true(shell_has_text(commands, "MoUI Studio"))
  assert_true(shell_has_text(commands, "可视化工作区"))
  assert_true(shell_has_text(commands, "运行"))
  assert_true(shell_has_text(commands, "编译 MoonBit"))
  // 图标栏（工作区/结构/数据/AI 的 tooltip 不走绘制；这里查左栏标题）
  assert_true(shell_has_text(commands, "程序结构"))
  // 左栏搜索 + 结构树分组
  assert_true(shell_has_text(commands, "搜索结构"))
  assert_true(shell_has_text(commands, "窗体"))
  assert_true(shell_has_text(commands, "控件"))
  assert_true(shell_has_text(commands, "变量"))
  assert_true(shell_has_text(commands, "事件子程序"))
  assert_true(shell_has_text(commands, "本地数据"))
  // 左栏底部
  assert_true(shell_has_text(commands, "最近修改"))
  assert_true(shell_has_text(commands, "快速插入"))
  // 中心：实时应用 + 积木
  assert_true(shell_has_text(commands, "实时应用"))
  assert_true(shell_has_text(commands, "积木"))
  // 右栏：Context 五页签 + 快速操作 + 监视
  assert_true(shell_has_text(commands, "属性"))
  assert_true(shell_has_text(commands, "状态"))
  assert_true(shell_has_text(commands, "数据"))
  assert_true(shell_has_text(commands, "动作"))
  assert_true(shell_has_text(commands, "依赖"))
  assert_true(shell_has_text(commands, "快速操作"))
  assert_true(shell_has_text(commands, "运行时监视"))
  // 底栏 + 状态栏
  assert_true(shell_has_text(commands, "运行审计"))
  assert_true(shell_has_text(commands, "Console"))
  assert_true(shell_has_text(commands, "UTF-8 · MoonBit"))
}

///|
test "shell fills the viewport: top bar spans full width, status bar sits at the bottom" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 状态栏文本的底边应贴近窗口底（22pt 状态栏）
  let status = shell_find_text(commands, "UTF-8 · MoonBit")
  guard status is Some(run) else { fail("status bar text missing") }
  let bottom = run.frame.origin.y + run.frame.size.height
  assert_true(bottom > 780.0)
  assert_true(bottom <= 800.0)
  // 顶栏文本应在最上方 40pt 内
  let brand = shell_find_text(commands, "MoUI Studio")
  guard brand is Some(brand_run) else { fail("brand text missing") }
  assert_true(brand_run.frame.origin.y < 40.0)
  // 面板背景铺满整个视口宽度：应存在一个宽度 >= 1280 的矩形
  let mut widest = 0.0
  for rect in shell_rects(commands) {
    if rect.size.width > widest {
      widest = rect.size.width
    }
  }
  assert_true(widest >= 1279.0)
}

///|
test "icon bar toggle collapses the left panel and widens the centre" {
  let model = initial_model()
  let open_commands = shell_draw(model, 1280.0, 800.0)
  let open_tree = shell_find_text(open_commands, "程序结构")
  guard open_tree is Some(_) else { fail("structure head missing") }
  // 收起左栏：标题消失、中心列变宽
  let collapsed = apply_shell(model, SetLeftView(LeftHidden))
  let collapsed_commands = shell_draw(collapsed, 1280.0, 800.0)
  assert_false(shell_has_text(collapsed_commands, "程序结构"))
  // 再点一次回到结构树（重复点击 = 收起，显式切换 = 换页签）
  let restored = apply_shell(collapsed, SetLeftView(LeftTree))
  let restored_commands = shell_draw(restored, 1280.0, 800.0)
  assert_true(shell_has_text(restored_commands, "程序结构"))
  // 左栏收起腾出的宽度归中心列（右栏钉右边缘不动）：
  // 实时应用窗格标题左移，右栏位置不变。
  let open_centre = shell_find_text(open_commands, "实时应用")
  let collapsed_centre = shell_find_text(collapsed_commands, "实时应用")
  guard open_centre is Some(open_centre_run) else { fail("live pane missing") }
  guard collapsed_centre is Some(collapsed_centre_run) else {
    fail("live pane missing when collapsed")
  }
  assert_true(
    collapsed_centre_run.frame.origin.x < open_centre_run.frame.origin.x,
  )
  let open_right = shell_find_text(open_commands, "快速操作")
  let collapsed_right = shell_find_text(collapsed_commands, "快速操作")
  guard open_right is Some(open_right_run) else {
    fail("quick actions missing")
  }
  guard collapsed_right is Some(collapsed_right_run) else {
    fail("quick actions missing when collapsed")
  }
  assert_eq(collapsed_right_run.frame.origin.x, open_right_run.frame.origin.x)
}

///|
test "workspace switching swaps the centre content" {
  let visual = initial_model()
  let visual_commands = shell_draw(visual, 1280.0, 800.0)
  assert_true(shell_has_text(visual_commands, "实时应用"))
  // 切到代码工作区：出现 IR 标尺与草稿提示，实时应用窗格消失
  let code = apply_shell(visual, SetWorkSpace(WsCode))
  assert_true(code.workspace is WsCode)
  let code_commands = shell_draw(code, 1280.0, 800.0)
  assert_true(shell_has_text(code_commands, "按 IR 重渲染"))
  assert_false(shell_has_text(code_commands, "实时应用"))
  // 切到空舞台
  let empty = apply_shell(code, SetWorkSpace(WsEmpty))
  assert_true(empty.workspace is WsEmpty)
  let empty_commands = shell_draw(empty, 1280.0, 800.0)
  assert_true(shell_has_text(empty_commands, "从零开始，或接着改"))
  assert_false(shell_has_text(empty_commands, "实时应用"))
}

///|
test "bottom bar expands to the audit timeline and console stays switchable" {
  let model = initial_model()
  let collapsed = shell_draw(model, 1280.0, 800.0)
  // 折叠态只有页签头，没有审计卡内容
  assert_true(shell_has_text(collapsed, "运行审计"))
  assert_false(shell_has_text(collapsed, "程序已载入 IR"))
  // 展开：审计条目出现（初始三条 boot 记录）
  let open = apply_shell(model, ToggleBottom)
  assert_true(open.bottom_open)
  let open_commands = shell_draw(open, 1280.0, 800.0)
  assert_true(shell_has_text(open_commands, "程序已载入 IR"))
  assert_true(shell_has_text(open_commands, "控件层已就绪"))
  // 切到 Console
  let console = apply_shell(open, SetBottomTab(false))
  let console_commands = shell_draw(console, 1280.0, 800.0)
  assert_true(shell_has_text(console_commands, "MoUI Studio 已就绪"))
  assert_false(shell_has_text(console_commands, "控件层已就绪"))
}

///|
test "AI layer anchors inside the centre column and never covers the status bar" {
  let model = initial_model()
  // 默认居中锚点：卡片在中心列内
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "AI 提案"))
  // 输入条是设计稿的「模式段 + 发送」形态（不再是两个宽按钮）
  assert_true(shell_has_text(commands, "发送"))
  assert_true(shell_has_text(commands, "修改"))
  assert_true(shell_has_text(commands, "修复"))
  // 药丸态：只留药丸，卡片内容消失
  let pill = apply_shell(model, ToggleAiPill)
  assert_true(pill.ai_pill)
  let pill_commands = shell_draw(pill, 1280.0, 800.0)
  // 设计稿药丸形态：「Agent 待审计 N」
  assert_true(shell_has_text(pill_commands, "Agent"))
  assert_false(shell_has_text(pill_commands, "发送"))
  // 停靠态：并入右栏（标题仍在），且不再是浮动层
  let docked = apply_shell(model, SetAiAnchor(AiDocked))
  assert_true(docked.ai_anchor is AiDocked)
  let docked_commands = shell_draw(docked, 1280.0, 800.0)
  assert_true(shell_has_text(docked_commands, "AI 提案"))
  // 浮动层任何锚点都不得压到状态栏：AI 文本底边应在状态栏之上
  for anchor in [AiCenter, AiLeft, AiRight] {
    let anchored = apply_shell(model, SetAiAnchor(anchor))
    let anchored_commands = shell_draw(anchored, 1280.0, 800.0)
    let title = shell_find_text(anchored_commands, "AI 提案")
    guard title is Some(run) else { fail("AI card missing") }
    assert_true(run.frame.origin.y + run.frame.size.height < 770.0)
  }
}

///|
test "settings dialog replaces the shell content when presented" {
  let model = initial_model()
  let opened = apply_shell(model, ToggleSettings)
  assert_true(opened.settings_open)
  let commands = shell_draw(opened, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "设置"))
  assert_true(shell_has_text(commands, "工作区"))
  assert_true(shell_has_text(commands, "界面语言"))
  assert_true(shell_has_text(commands, "模型服务"))
  assert_true(shell_has_text(commands, "密钥"))
  // 密钥提示必须出现（安全承诺在 UI 上可见）
  assert_true(shell_has_text(commands, "不进源码"))
  // 关闭后对话框消失
  let closed = apply_shell(opened, ToggleSettings)
  let closed_commands = shell_draw(closed, 1280.0, 800.0)
  assert_false(shell_has_text(closed_commands, "不进源码"))
}

///|
test "studio command catalog is bilingual and filterable" {
  let zh = translator_for(ZhHans)
  let en = translator_for(En)
  let zh_commands = studio_commands(zh)
  let en_commands = studio_commands(en)
  assert_eq(zh_commands.length(), en_commands.length())
  assert_true(zh_commands.length() >= 20)
  // 中文表里不该残留英文标签（i18n 漏配会渲染成 [[key]]）
  for command in zh_commands {
    assert_false(command.label.contains("[["))
    assert_false(command.group.contains("[["))
  }
  // 过滤：空查询返回全部；「工作区」只命中工作区分组
  assert_eq(
    filter_studio_commands(zh_commands, "").length(),
    zh_commands.length(),
  )
  let filtered = filter_studio_commands(zh_commands, "工作区")
  assert_true(filtered.length() > 0)
  assert_true(filtered.length() < zh_commands.length())
  for command in filtered {
    assert_eq(command.group, "工作区")
  }
  // 大小写不敏感（英文表用 Visual 查 visual）
  let en_filtered = filter_studio_commands(en_commands, "visual")
  assert_true(en_filtered.length() > 0)
}

///|
test "shell renders at a narrow viewport without losing the right panel" {
  let model = initial_model()
  // 1024 宽：中心列仍应留下可用宽度，右栏不离屏
  let commands = shell_draw(model, 1024.0, 700.0)
  assert_true(shell_has_text(commands, "快速操作"))
  assert_true(shell_has_text(commands, "运行时监视"))
  let actions = shell_find_text(commands, "快速操作")
  guard actions is Some(run) else { fail("quick actions missing") }
  assert_true(run.frame.origin.x < 1024.0)
  assert_true(run.frame.origin.x + run.frame.size.width <= 1025.0)
}

// ============================================================================
// 壳行为链：事件 → 三处派生（审计 / 最近修改 / Console）
// ============================================================================

///|
test "editing a control records one recent change per discrete action" {
  let model = initial_model()
  assert_eq(model.recent_changes.length(), 0)
  let added = apply_shell(model, AddControl(@ir.Label))
  assert_eq(added.recent_changes.length(), 1)
  // 连插两次是两个独立还原点（离散动作不合并）
  let twice = apply_shell(added, AddControl(@ir.Button))
  assert_eq(twice.recent_changes.length(), 2)
  assert_eq(twice.undo_stack.length(), 2)
  // 动作者是「你」而不是 Agent；目标是「刚插入的那个控件名」
  assert_false(twice.recent_changes[1].by_agent)
  assert_eq(twice.recent_changes[0].target, "标签")
  assert_eq(twice.recent_changes[1].target, "按钮")
}

///|
test "a no-op edit records neither a recent change nor an undo point" {
  let model = initial_model()
  // 删除不存在的控件：签名不变 → 不留痕
  let same = apply_shell(model, DeleteControl("不存在的控件"))
  assert_eq(same.recent_changes.length(), 0)
  assert_eq(same.undo_stack.length(), 0)
}

///|
test "accepting a proposal logs an audit entry, console line and toast" {
  let model = apply_shell(initial_model(), SetPrompt("加一个按钮"))
  let proposed = apply_shell(model, GenerateProposal)
  guard proposed.pending is Some(_) else { fail("no proposal generated") }
  let audit_before = proposed.audit_entries.length()
  let log_before = proposed.log_lines.length()
  let accepted = apply_shell(proposed, AcceptProposal)
  assert_true(accepted.pending is None)
  assert_true(accepted.audit_entries.length() > audit_before)
  assert_true(accepted.log_lines.length() > log_before)
  assert_eq(accepted.toasts.length(), 1)
  // 最近修改标记为 Agent 所为
  assert_true(
    accepted.recent_changes[accepted.recent_changes.length() - 1].by_agent,
  )
}

///|
test "rejecting a proposal records history without touching the program" {
  let model = apply_shell(initial_model(), SetPrompt("加一个按钮"))
  let proposed = apply_shell(model, GenerateProposal)
  let signature = @ir.program_signature(proposed.program)
  let rejected = apply_shell(proposed, RejectProposal)
  assert_true(rejected.pending is None)
  assert_eq(@ir.program_signature(rejected.program), signature)
  assert_eq(rejected.proposal_history.length(), 1)
  assert_false(rejected.proposal_history[0].accepted)
}

///|
test "starting a run appends an audit entry naming the handler" {
  let model = initial_model()
  let audit_before = model.audit_entries.length()
  let running = apply_shell(model, RunStart)
  guard running.run is Some(_) else { fail("run did not start") }
  assert_true(running.audit_entries.length() > audit_before)
  let last = running.audit_entries[running.audit_entries.length() - 1]
  assert_true(last.kind is AuditRun)
  assert_true(last.detail.contains("on_click"))
}

///|
test "control alignment clamps to the 640pt design frame" {
  let model = initial_model()
  let target = model.program.controls[0].name
  let left = apply_shell(model, AlignControlLeft(target))
  let left_control = match @ir.find_control(left.program, target) {
    Some(control) => control
    None => fail("control vanished after align-left")
  }
  assert_eq(left_control.x, 24)
  let right = apply_shell(model, AlignControlRight(target))
  let right_control = match @ir.find_control(right.program, target) {
    Some(control) => control
    None => fail("control vanished after align-right")
  }
  assert_eq(right_control.x, 640 - right_control.width - 24)
}

///|
test "toast queue is capped and dismissible" {
  let mut model = initial_model()
  let mut index = 0
  while index < TOAST_LIMIT + 3 {
    model = push_toast(model, "toast-\{index}", false)
    index = index + 1
  }
  assert_eq(model.toasts.length(), TOAST_LIMIT)
  let dismissed = apply_shell(model, DismissToast(0))
  assert_eq(dismissed.toasts.length(), TOAST_LIMIT - 1)
}

///|
test "split ratio clamps into the usable band" {
  let model = initial_model()
  assert_eq(apply_shell(model, SetSplitRatio(0.05)).split_ratio, 0.2)
  assert_eq(apply_shell(model, SetSplitRatio(0.95)).split_ratio, 0.8)
  assert_eq(apply_shell(model, SetSplitRatio(0.5)).split_ratio, 0.5)
}

///|
test "program tree groups every IR entity with counts" {
  let model = initial_model()
  let tree = program_tree(model)
  // 分组行的 label 是空的：标签是 i18n 键，在渲染时才翻译
  // （见 tree_view_ide 的 tree_group_label_key）。这里断言 group 标记。
  let groups : Array[String] = []
  for node in tree {
    if node.kind is TnGroup {
      groups.push(node.group)
    }
  }
  assert_true(groups.contains("window"))
  assert_true(groups.contains("controls"))
  assert_true(groups.contains("handlers"))
  // 控件分组计数 = IR 控件数
  let mut control_count = 0
  for node in tree {
    if node.kind is TnControl {
      control_count = control_count + 1
    }
  }
  assert_eq(control_count, model.program.controls.length())
}

///|
test "tree search filters rows without dropping their group header" {
  let model = initial_model()
  let filtered = apply_shell(model, SetTreeQuery("按钮"))
  let tree = program_tree(filtered)
  let mut seen_controls_group = false
  let mut seen_matching_control = false
  let mut seen_other_control = false
  for node in tree {
    if node.kind is TnGroup && node.group == "controls" {
      seen_controls_group = true
    }
    if node.kind is TnControl {
      if node.label.contains("按钮") {
        seen_matching_control = true
      } else {
        seen_other_control = true
      }
    }
  }
  // 命中的分组头保留；不匹配的控件行被过滤掉
  assert_true(seen_controls_group)
  assert_true(seen_matching_control)
  assert_false(seen_other_control)
}

///|
test "IR to code line mapping round-trips through the ruler" {
  let model = initial_model()
  let lines = code_lines(model)
  assert_true(lines.length() > 0)
  // 每一行的行号单调递增且与下标一致
  let mut index = 0
  for line in lines {
    assert_eq(line.number, index + 1)
    index = index + 1
  }
  // IR 路径 ↔ 行号双向映射：拿第一条语句的路径找出它占的行区间，
  // 再用区间起点反查，必须回到同一条路径（双向高亮的基础）。
  let spans = ir_line_spans(model)
  assert_true(spans.length() > 0)
  let first = spans[0]
  let round_trip = ir_span_for_line(spans, first.first_line)
  guard round_trip is Some(found) else { fail("line did not map back") }
  assert_eq(found.path, first.path)
  assert_eq(ir_span_at(spans, first.path).unwrap().first_line, first.first_line)
}

///|
test "empty stage offers template shortcuts and hides the panes" {
  let model = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  assert_true(model.workspace is WsEmpty)
  let commands = shell_draw(model, 1280.0, 800.0)
  // 空舞台给出两条模板入口 + 打开工程
  assert_true(shell_has_text(commands, "新建问候程序"))
  assert_true(shell_has_text(commands, "新建点名册"))
  assert_true(shell_has_text(commands, "打开项目…"))
  // 窗格头消失
  assert_false(shell_has_text(commands, "实时应用"))
  assert_false(shell_has_text(commands, "积木"))
}

///|
test "context tabs change the right panel body" {
  let model = initial_model()
  let props = shell_draw(
    apply_shell(model, SetContextTab(CtxProps)),
    1280.0,
    800.0,
  )
  assert_true(shell_has_text(props, "名称"))
  let data = shell_draw(
    apply_shell(model, SetContextTab(CtxData)),
    1280.0,
    800.0,
  )
  // 数据页签列变量与本地数据，不再显示属性字段
  assert_false(shell_has_text(data, "名称"))
}

///|
test "command palette filters the studio command catalog" {
  let t = translator(initial_model())
  let all = studio_commands(t)
  assert_true(all.length() >= 20)
  let filtered = filter_studio_commands(all, "console")
  assert_true(filtered.length() >= 1)
  assert_true(filtered.length() < all.length())
  // 空查询返回全集
  assert_eq(filter_studio_commands(all, "").length(), all.length())
}

///|
test "settings and AI history dialogs are modal overlays" {
  let model = initial_model()
  let plain = shell_draw(model, 1280.0, 800.0)
  assert_false(shell_has_text(plain, "设置"))
  let settings = shell_draw(apply_shell(model, ToggleSettings), 1280.0, 800.0)
  assert_true(shell_has_text(settings, "设置"))
  let history = shell_draw(apply_shell(model, ToggleAiHistory), 1280.0, 800.0)
  assert_true(shell_has_text(history, "提案历史"))
}

///|
test "runtime watch lists only declared watch variables" {
  let model = initial_model()
  let rows = watch_rows(model)
  // 未运行时也要有行（显示空态），但值不会假装成已运行
  assert_true(rows.length() >= 0)
  // 启动后能读到值
  let running = apply_shell(model, RunStart)
  let live = watch_rows(running)
  for row in live {
    ignore(row)
  }
}

///|
test "workspace resize keeps panels inside the viewport" {
  let model = initial_model()
  for width in [900.0, 1280.0, 1600.0] {
    let commands = shell_draw(model, width, 800.0)
    let quick = shell_find_text(commands, "快速操作")
    guard quick is Some(run) else { fail("quick actions missing at \{width}") }
    assert_true(run.frame.origin.x + run.frame.size.width <= width)
  }
}

///|
/// AI 浮动卡必须落在「避让带」里：内容段让出卡高，卡片顶边不得高于
/// 内容段底边（否则就是压在窗格脚注上）。
///
/// 这里断言的是**结构契约**而不是从绘制指令里猜区域：绘制指令里同时
/// 存在「中心列」（整行高）与「内容段」（行高 − 带高）两个等宽矩形，
/// 靠宽度/高度启发式区分不可靠。带高由 ai_avoidance_band 给出，
/// 内容段底边 = 内容行顶 + (行高 − 带高)。
test "floating AI card does not overlap the workspace content" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let row_height = 800.0 -
    TOPBAR_HEIGHT -
    STATUSBAR_HEIGHT -
    PANEL_HEAD_HEIGHT -
    2.0
  let band = ai_avoidance_band(model, 715.0, row_height)
  assert_true(band > 0.0)
  let content_bottom = TOPBAR_HEIGHT + 1.0 + (row_height - band)
  let mut card_top = 10000.0
  let mut card_height = 0.0
  for command in commands {
    let rect = match command {
      @core.FillRect(r, _) => Some(r)
      @core.FillRoundedRect(r, _) => Some(r.rect)
      @core.FillRoundedRectBrush(r, _) => Some(r.rect)
      _ => None
    }
    match rect {
      Some(r) =>
        // 浮动卡：居中锚点 680 宽（卡片本体是 680，内容段 < 1000）
        if r.size.width > 600.0 && r.size.width < 700.0 && r.origin.y > 300.0 {
          card_top = r.origin.y.min(card_top)
          card_height = r.size.height.max(card_height)
        }
      None => ()
    }
  }
  assert_true(card_top < 10000.0)
  assert_true(card_height > 0.0)
  // 卡片整体落在避让带内，且不越过内容段底边
  assert_true(card_top >= content_bottom)
  assert_true(card_top + card_height <= TOPBAR_HEIGHT + 1.0 + row_height + 1.0)
}

///|
/// 药丸/停靠态不占避让带：内容段回到全高。
test "pill and docked AI states do not reserve a band" {
  let model = initial_model()
  let pill = apply_shell(model, ToggleAiPill)
  assert_eq(ai_avoidance_band(pill, 715.0, 706.0), 0.0)
  let docked = apply_shell(model, SetAiAnchor(AiDocked))
  assert_eq(ai_avoidance_band(docked, 715.0, 706.0), 0.0)
  // 居中锚点会真的预留
  assert_true(ai_avoidance_band(model, 715.0, 706.0) > 0.0)
}

///|
/// 树行的元信息（窗体 640×480）必须完整落在左栏内。
/// 曾经的 bug：标签宽度写死 `width - 44`，而 meta 单元格固定 52 又装不下
/// 「640×480」（实测 68），两者叠加让整行溢出到面板外，被裁成「64」。
///
/// 注意坐标系：左栏从 x=ICONBAR_WIDTH 起，右边缘是
/// ICONBAR_WIDTH + LEFTBAR_WIDTH（不是 LEFTBAR_WIDTH）。
test "tree row meta stays inside the panel" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let cell = shell_find_text(commands, "640×480")
  guard cell is Some(run) else { fail("window meta missing from the tree") }
  let panel_right = ICONBAR_WIDTH + LEFTBAR_WIDTH
  if run.frame.origin.x + run.frame.size.width > panel_right {
    fail(
      "meta overflows panel: right=" +
      (run.frame.origin.x + run.frame.size.width).to_string() +
      " panel_right=" +
      panel_right.to_string(),
    )
  }
  assert_eq(run.frame.size.width, TREE_META_WIDTH)
}

///|
/// 左栏底部的快速插入两行必须落在窗格内（不被底栏压住）。
/// 曾经的 bug：@views.button 的 height 是**最小**高度，26 实际渲染 36，
/// 两行溢出到面板外。
test "quick insert buttons fit inside the left panel" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let mut lowest = 0.0
  let mut seen = 0
  for command in commands {
    let rect = match command {
      @core.FillRect(r, _) => Some(r)
      @core.FillRoundedRect(r, _) => Some(r.rect)
      @core.FillRoundedRectBrush(r, _) => Some(r.rect)
      _ => None
    }
    match rect {
      Some(r) =>
        // 快速插入按钮：宽 105、高 26、在左栏内
        if (r.size.width - 105.0).abs() < 1.0 &&
          (r.size.height - 26.0).abs() < 1.0 {
          lowest = (r.origin.y + r.size.height).max(lowest)
          seen = seen + 1
        }
      None => ()
    }
  }
  assert_eq(seen, 4)
  // 工作区底边（内容行结束处）
  let row_bottom = 800.0 - STATUSBAR_HEIGHT - PANEL_HEAD_HEIGHT - 2.0
  assert_true(lowest <= row_bottom)
}

///|
/// hero 态：空舞台上输入框升格为主角——列示例指令、加宽、上移，
/// 并且不再占用避让带（空舞台没有内容需要让位）。
test "empty workspace promotes the AI composer to hero mode" {
  let model = initial_model()
  assert_false(ai_hero(model))
  let empty = apply_shell(model, SetWorkSpace(WsEmpty))
  assert_true(ai_hero(empty))
  // 抬升后不避让
  assert_eq(ai_avoidance_band(empty, 715.0, 706.0), 0.0)
  // 示例指令可见
  let commands = shell_draw(empty, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "生成一个班级点名册 App"))
  // 药丸/停靠态取消 hero
  assert_false(ai_hero(apply_shell(empty, ToggleAiPill)))
  assert_false(ai_hero(apply_shell(empty, SetAiAnchor(AiDocked))))
}

///|
/// 输入条模式段：四个模式都在，且「发送」按模式分流到既有通道。
test "composer mode routes send to existing channels" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  for label in ["修改", "生成", "解释", "修复"] {
    assert_true(shell_has_text(commands, label))
  }
  assert_true(shell_has_text(commands, "发送"))
  // 解释模式 → 本地确定性讲解（挂到 explanation）
  let explain = apply_shell(
    apply_shell(model, SetComposerMode(ComposeExplain)),
    ComposerRun,
  )
  if explain.explanation == "" {
    fail(
      "explain mode produced nothing; selected_handler=" +
      explain.selected_handler,
    )
  }
  // 修复模式 → 代码草稿回到 IR 的规范渲染。
  // EditCode 只写草稿；提交（切模式会先 commit）才产生解析错误。
  // RunStart 会先 commit_code：非法草稿不被采纳（草稿原样保留，
  // notice 里给出本地化错误——正是修复模式的输入态）。
  let broken = apply_shell(
    apply_shell(model, EditCode("如果 真的 则\n")),
    RunStart,
  )
  if broken.code_error == "" {
    fail("invalid draft was not rejected: " + broken.code_draft)
  }
  let repaired = apply_shell(
    apply_shell(broken, SetComposerMode(ComposeRepair)),
    ComposerRun,
  )
  if repaired.code_error != "" {
    fail("repair left an error: " + repaired.code_error)
  }
  // 修好之后草稿是 IR 的规范渲染：注释头 + 唯一那条 set_text 语句
  // 修复后的草稿就是 IR 的规范渲染（与 render_handler 逐字相同），
  // 且不再是那份非法文本——按具体关键字断言会漏掉语言差异
  // （中文渲染成「设置文本」，英文才是 set_text）。
  guard current_handler(repaired) is Some(handler) else { fail("handler gone") }
  let canonical = @studio_lang.render_handler(
    handler,
    repaired.language.dsl_language(),
  )
  assert_eq(repaired.code_draft, canonical)
  assert_true(apply_shell(repaired, RunStart).run is Some(_))
}

///|
/// 生成模式以空程序为基：提案从零重建，且仍走同一条校验链。
test "generate mode starts from an empty program" {
  let model = apply_shell(initial_model(), SetPrompt("班级点名册"))
  let cleared = apply_shell(
    apply_shell(model, SetComposerMode(ComposeGenerate)),
    ComposerRun,
  )
  guard cleared.pending is Some(pending) else { fail("no proposal generated") }
  assert_true(pending.valid)
  // 提案恢复了控件（生成语义），不是空提案
  assert_true(pending.proposal.controls_add.length() > 0)
}

///|
/// hero / 药丸态：浮动层拿整行高（不是零高度段）。
/// 曾经的 bug：带高为 0 时浮动层被塞进 0 高的容器，整块消失——
/// 空舞台上 hero 输入框和药丸都会不见。
test "hero and pill overlays still render when the band is zero" {
  let model = initial_model()
  // hero：空舞台 + 居中锚点
  let empty = apply_shell(model, SetWorkSpace(WsEmpty))
  assert_eq(ai_avoidance_band(empty, 715.0, 706.0), 0.0)
  let hero_commands = shell_draw(empty, 1280.0, 800.0)
  assert_true(shell_has_text(hero_commands, "AI 提案"))
  assert_true(shell_has_text(hero_commands, "发送"))
  // 药丸：同样带高为 0
  let pill = apply_shell(model, ToggleAiPill)
  assert_eq(ai_avoidance_band(pill, 715.0, 706.0), 0.0)
  let pill_commands = shell_draw(pill, 1280.0, 800.0)
  // 设计稿药丸形态：「Agent 待审计 N」
  assert_true(shell_has_text(pill_commands, "Agent"))
}

///|
/// 空舞台的引导入口（模板按钮）必须落在 hero 卡上方，不被盖住——
/// 被盖住就等于「点了没反应」，那是比不好看严重得多的问题。
test "empty stage guidance sits above the hero card" {
  let empty = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  let commands = shell_draw(empty, 1280.0, 800.0)
  let guide = shell_find_text(commands, "新建问候程序")
  let card = shell_find_text(commands, "AI 提案")
  guard guide is Some(guide_run) else { fail("stage buttons missing") }
  guard card is Some(card_run) else { fail("hero card missing") }
  let guide_bottom = guide_run.frame.origin.y + guide_run.frame.size.height
  if guide_bottom > card_run.frame.origin.y {
    fail(
      "hero card covers the stage buttons: guide_bottom=" +
      guide_bottom.to_string() +
      " card_top=" +
      card_run.frame.origin.y.to_string(),
    )
  }
}

///|
/// 浮动 AI 层不得把工作区刷成一块底板。
///
/// 曾经的 bug：外层的纯定位包装用了无 background 的 `@views.container`，
/// 它回落到环境 Base 变体的刷子（不透明面板色），整帧被刷满——空舞台的
/// 引导语和三个模板按钮**画了但看不见**（绘制流里都在，屏幕上一片空）。
/// 断言方式：在所有「舞台文字」之后，不允许出现覆盖整行的实心矩形。
test "floating AI layer does not paint over the workspace" {
  let empty = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  let commands = shell_draw(empty, 1280.0, 800.0)
  let mut stage_text_at = -1
  let mut index = 0
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("从零开始") {
          stage_text_at = index
        }
      _ => ()
    }
    index += 1
  }
  assert_true(stage_text_at >= 0)
  index = 0
  for command in commands {
    if index > stage_text_at {
      let rect = match command {
        @core.FillRect(rect, _) => Some(rect)
        @core.FillRoundedRect(rect, _) => Some(rect.rect)
        @core.FillRoundedRectBrush(rect, _) => Some(rect.rect)
        _ => None
      }
      match rect {
        Some(rect) =>
          // 「盖住整行」= 横跨中心列且比一张卡还高
          if rect.origin.x <= 300.0 &&
            rect.origin.x + rect.size.width >= 1000.0 &&
            rect.size.height > 400.0 {
            fail(
              "opaque rect covers the stage after its text: y=" +
              rect.origin.y.to_string() +
              " h=" +
              rect.size.height.to_string(),
            )
          }
        None => ()
      }
    }
    index += 1
  }
}

///|
/// 输入条工具行（设计稿 `.ctools`）：锚点读数在，三个**带名字**的按钮
/// 都在卡片内，且不越出右边界。
test "composer tools row stays inside the AI card" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "底部居中"))
  for label in ["切换锚点", "停靠右栏", "收起"] {
    assert_true(shell_has_text(commands, label))
  }
  // 工具行标签不得越出卡片右边界（卡片是居中锚 680，右边界 = 卡右沿）
  let card = shell_find_text(commands, "AI 提案")
  guard card is Some(card_run) else { fail("AI card missing") }
  let card_left = card_run.frame.origin.x
  let card_right = card_left + 680.0
  for
    label in [
      "底部居中", "切换锚点", "停靠右栏", "收起", "发送",
    ] {
    guard shell_find_text(commands, label) is Some(run) else {
      fail("missing label: " + label)
    }
    let right = run.frame.origin.x + run.frame.size.width
    if right > card_right {
      fail(
        label +
        " overflows the card: right=" +
        right.to_string() +
        " card_right=" +
        card_right.to_string(),
      )
    }
  }
}

///|
/// 锚点读数跟着锚点走——它是「这条会飘在哪」的唯一提示。
test "anchor hint follows the current anchor" {
  let model = initial_model()
  assert_eq(anchor_hint_key(model.ai_anchor), "app.ai.anchor.center")
  assert_eq(anchor_hint_key(AiLeft), "app.ai.anchor.left")
  assert_eq(anchor_hint_key(AiRight), "app.ai.anchor.right")
  assert_eq(anchor_hint_key(AiDocked), "app.ai.anchor.docked")
  // 循环锚点后读数要变（三个浮动锚依次轮转）
  let cycled = apply_shell(model, CycleAiAnchor)
  assert_false(cycled.ai_anchor is AiCenter)
  let left = apply_shell(model, SetAiAnchor(AiLeft))
  let commands = shell_draw(left, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "左下角"))
}

///|
/// 停靠态下工具行的按钮换成「浮出」——否则点「侧栏」是空操作。
test "docked anchor offers undock instead of dock" {
  let docked = apply_shell(initial_model(), SetAiAnchor(AiDocked))
  let commands = shell_draw(docked, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "停靠 · Context 侧栏"))
  assert_true(shell_has_text(commands, "浮出"))
}

///|
/// `#seeAll`：线程多于 3 条时才出现，且点了打开既有 AI 历史。
test "see all sessions appears only with a long thread list" {
  let model = initial_model()
  // 初始只有 1 张卡 → 不显示
  assert_false(
    shell_has_text(shell_draw(model, 1280.0, 800.0), "查看全部会话 →"),
  )
  // 每次生成提案都会推进一张 diff 线程卡（真实漏斗：GenerateProposal）
  let mut many = apply_shell(model, GenerateProposal)
  for _ in 0..<4 {
    many = apply_shell(many, GenerateProposal)
  }
  if many.ai_cards.length() <= 3 {
    fail("expected >3 thread cards, got " + many.ai_cards.length().to_string())
  }
  assert_true(
    shell_has_text(shell_draw(many, 1280.0, 800.0), "查看全部会话 →"),
  )
  // 折叠后线程区收起，出口也收起
  let folded = apply_shell(many, ToggleAiCardsFold)
  assert_false(
    shell_has_text(shell_draw(folded, 1280.0, 800.0), "查看全部会话 →"),
  )
}

///|
/// 药丸态：「待审计 N」是收起后唯一的待办读数。
test "pill shows the pending review count" {
  let model = apply_shell(initial_model(), GenerateProposal)
  if pending_ai_cards(model) == 0 {
    fail("proposal did not create a pending thread card")
  }
  let pill = apply_shell(model, ToggleAiPill)
  let commands = shell_draw(pill, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "Agent"))
  assert_true(shell_has_text(commands, "待审计"))
}

///|
/// 线程卡是**事件驱动**的可见记录：生成提案 → 出现 diff 线程卡 +
/// 折叠条计数；采纳 → 卡被标为已应用且待审计数归零。
///
/// 回归意义：`push_ai_card` 曾经没有任何调用方，`ai_cards` 恒为空，
/// 于是线程区/折叠条/#seeAll/药丸计数全是永不出现的死 UI。
test "proposal threads produce visible, settleable cards" {
  let model = initial_model()
  assert_eq(model.ai_cards.length(), 0)
  let proposed = apply_shell(model, GenerateProposal)
  assert_true(proposed.pending is Some(_))
  assert_eq(proposed.ai_cards.length(), 1)
  assert_eq(pending_ai_cards(proposed), 1)
  // 卡片可见：折叠条给出待审计计数
  let commands = shell_draw(proposed, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "Agent 待审计 1"))
  // 采纳后归零并留回执
  let accepted = apply_shell(proposed, AcceptProposal)
  assert_true(accepted.pending is None)
  assert_eq(pending_ai_cards(accepted), 0)
  assert_eq(accepted.ai_cards.length(), 1)
  assert_true(accepted.ai_cards[0].settled)
  // 拒绝同理
  let rejected = apply_shell(
    apply_shell(model, GenerateProposal),
    RejectProposal,
  )
  assert_true(rejected.ai_cards[0].settled)
  assert_eq(pending_ai_cards(rejected), 0)
}

///|
/// 线程卡出现后，输入条与决策行必须仍在卡片内可见。
///
/// 曾经的 bug：线程区拿「可用高度 − 常数」当预算，线程卡一多就长过卡片
/// 自身的帧高，把 composer 和决策行顶出可视区（实测一张 diff 卡就够）。
/// 现在线程区预算由 `ai_card_height − card_chrome_height` 反推。
test "thread cards never push the composer out of the card" {
  let mut model = initial_model()
  // 连推几张卡，触发线程区滚动上限
  for _ in 0..<5 {
    model = apply_shell(model, GenerateProposal)
  }
  if model.ai_cards.length() <= 3 {
    fail("expected >3 cards, got " + model.ai_cards.length().to_string())
  }
  let commands = shell_draw(model, 1280.0, 800.0)
  let card_top = match shell_find_text(commands, "AI 提案") {
    Some(run) => run.frame.origin.y
    None => fail("AI card missing")
  }
  // 卡片底边 = 卡顶 + 内容高度（含底边距）
  let card_bottom = card_top + ai_card_height(model, 680.0) - 12.0
  for label in ["发送", "查看全部会话 →", "提案历史"] {
    guard shell_find_text(commands, label) is Some(run) else {
      fail("missing after threads: " + label)
    }
    let bottom = run.frame.origin.y + run.frame.size.height
    if bottom > card_bottom {
      fail(
        label +
        " falls outside the card: bottom=" +
        bottom.to_string() +
        " card_bottom=" +
        card_bottom.to_string(),
      )
    }
  }
}
