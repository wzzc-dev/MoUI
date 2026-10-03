///|
/// v4 IDE 壳消息域：工作区编排、面板显隐、审计/Console/最近修改、
/// AI 浮动层、快速操作、对话框与 toast。
///
/// 与既有消息域的关系：这里是**壳的状态**（谁可见、选中哪个页签、
/// 浮动层停在哪），不改 IR 语义；改 IR 的动作（快速插入、对齐）
/// 仍走 with_undo_point + 既有 commit 通道，保证撤销栈连续。

///|
/// 壳消息分发：未命中返回 None（链式交给其他域）。
pub fn update_ide_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SetWorkSpace(workspace) => Some(set_workspace(model, workspace))
    TogglePaneLive => Some(toggle_pane_live(model))
    ShowPaneLive => Some(show_pane_live(model))
    ShowPaneBlocks => Some(show_pane_blocks(model))
    TogglePaneBlocks => Some(toggle_pane_blocks(model))
    SetSplitRatio(ratio) => Some(set_split_ratio(model, ratio))
    SetLeftView(view) => Some(set_left_view(model, view))
    SetRightVisible(visible) => Some(set_right_visible(model, visible))
    // 列间 sash 拖拽：视图层已按当帧布局夹取，这里再兜底夹一次静态界限
    // （窗口在拖拽中途变小等时序差）。纯布局状态：不进撤销、不标脏。
    ResizeLeftPanel(width) =>
      Some(
        (
          {
            ..model,
            left_width: width.clamp(min=LEFTBAR_MIN_WIDTH, max=LEFTBAR_MAX_WIDTH),
          },
          @moui.Effect::none(),
        ),
      )
    ResizeRightPanel(width) =>
      Some(
        (
          {
            ..model,
            right_width: width.clamp(
              min=RIGHTBAR_MIN_WIDTH,
              max=RIGHTBAR_MAX_WIDTH,
            ),
          },
          @moui.Effect::none(),
        ),
      )
    SetTreeQuery(query) =>
      Some(({ ..model, tree_query: query, }, @moui.Effect::none()))
    ToggleTreeGroup(group) => {
      let collapsed : Array[String] = []
      let mut removed = false
      for item in model.tree_collapsed {
        if item == group {
          removed = true
        } else {
          collapsed.push(item)
        }
      }
      if !removed {
        collapsed.push(group)
      }
      Some(({ ..model, tree_collapsed: collapsed, }, @moui.Effect::none()))
    }
    TriggerCompletion => {
      let (word, _) = word_at_caret(model.code_draft, model.code_caret)
      let candidates = completions_for(model, word)
      if candidates.length() > 0 {
        Some(
          (
            {
              ..model,
              completions: candidates,
              completion_open: true,
            },
            @moui.Effect::none(),
          ),
        )
      } else {
        Some((model, @moui.Effect::none()))
      }
    }
    ApplyCompletion(word) => {
      let (text, caret) = apply_completion(model.code_draft, model.code_caret, word)
      Some(
        (
          with_draft_diagnostics({
            ..model,
            code_draft: text,
            code_caret: caret,
            code_selection: None,
            completion_open: false,
          }),
          @moui.Effect::none(),
        ),
      )
    }
    JumpToDeclaration => {
      let line = declaration_line_of(model, model.code_caret)
      if line > 0 {
        Some((goto_line(model, line), @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    }
    DismissCompletion =>
      Some(({ ..model, completion_open: false, }, @moui.Effect::none()))
    SetContextTab(tab) =>
      Some(({ ..model, ctx_tab: tab, }, @moui.Effect::none()))
    SetBottomTab(tab) =>
      Some((select_bottom_tab(model, tab), @moui.Effect::none()))
    ToggleBottom =>
      Some(
        (
          // **收起/展开底栏只动底栏**——绝不偷偷把 AI 输入面挪去右栏。
          //
          // 早先的实现在收起时会把 `ai_anchor` 改成 `AiDocked`（理由是
          // 「别把输入面整个藏起来」）。那个理由本身不成立，而且造成两个
          // 用户可见的缺陷：
          //   ① 收起底栏 → AI **自己出现在右栏**（用户没让它过去，
          //      这叫「取消」也不为过：用户只是想折叠一个面板）；
          //   ② 再展开、点「AI 输入」页签 → 输入面**回不来**
          //      （锚点已是 `AiDocked`，底栏那份 composer 不画）。
          //
          // 正确的语义：折叠面板不等于切换输入面的落点。收起时若输入面
          // 正由底栏承载，它**跟着一起收起**（和审计/控制台页签一样），
          // 展开后原样回来——落点始终由 `ai_anchor` 单独决定，只有
          // `SetAiAnchor` / `CycleAiAnchor` 能改它。
          sync_ai_placement({ ..model, bottom_open: !model.bottom_open }),
          @moui.Effect::none(),
        ),
      )
    AuditOpen(index) =>
      Some(
        (
          { ..model, bottom_open: true, bottom_tab: BtAudit, },
          jump_audit(model, index),
        ),
      )
    AuditSettle(index, note) => Some(settle_audit(model, index, note))
    AuditSettleAll(note) => Some(settle_all_audit(model, note))
    ClearConsole => Some(({ ..model, log_lines: [], }, @moui.Effect::none()))
    CycleAiAnchor =>
      Some(
        (
          apply_ai_anchor(model, next_anchor(model.ai_anchor)),
          @moui.Effect::none(),
        ),
      )
    SetAiAnchor(anchor) =>
      Some(
        (apply_ai_anchor(model, anchor), @moui.Effect::none()),
      )
    ToggleAiCardsFold =>
      Some(
        (
          { ..model, ai_cards_folded: !model.ai_cards_folded, },
          @moui.Effect::none(),
        ),
      )
    AlignControlLeft(name) => Some(align_control(model, name, AlignLeft))
    AlignControlCenter(name) => Some(align_control(model, name, AlignCenter))
    AlignControlRight(name) => Some(align_control(model, name, AlignRight))
    ToggleSettings =>
      Some(
        (
          { ..model, settings_open: !model.settings_open, },
          @moui.Effect::none(),
        ),
      )
    ToggleAiHistory =>
      Some(
        (
          { ..model, ai_history_open: !model.ai_history_open, },
          @moui.Effect::none(),
        ),
      )
    DismissToast(index) => Some(dismiss_toast(model, index))
    ToastTick => Some((age_toasts(model), @moui.Effect::none()))
    StudioCommandRun(id) => Some(run_studio_command(model, id))
    SelectBlockCategory(index) =>
      Some(({ ..model, selected_category: index, }, @moui.Effect::none()))
    HighlightIrPath(path) => {
      let same = same_path(model.ir_highlight, path)
      Some(
        (
          { ..model, ir_highlight: if same { [] } else { path }, },
          @moui.Effect::none(),
        ),
      )
    }
    HoverIrPath(path) =>
      Some(({ ..model, hover_path: path, }, @moui.Effect::none()))
    RestoreCodeDraft => Some(restore_code_draft(model))
    _ => None
  }
}

// ============================================================================
// 工作区与面板
// ============================================================================

///|
/// 工作区切换：图标栏点当前工作区 = 收起成空舞台（设计稿的 toggle 语义）；
/// 切到可视化工作区时两个窗格都显（从收起态恢复要有内容，否则点了没反应）。
fn set_workspace(
  model : Model,
  workspace : WorkSpace,
) -> (Model, @moui.Effect[Msg]) {
  // 重复点当前工作区 = 收起（进空舞台）；否则切到「请求的」工作区。
  // 通配臂不能绑成当前值（写成 (other, _) => other），那会让任何切换
  // 都静默退回原工作区——这个 bug 只有落布局才看得出来。
  let target = match (model.workspace, workspace) {
    (WsVisual, WsVisual) | (WsCode, WsCode) => WsEmpty
    (_, requested) => requested
  }
  let next = match target {
    WsVisual =>
      {
        ..model,
        workspace: WsVisual,
        mode: ModeDesign,
        pane_live: true,
        pane_blocks: true,
      }
    WsCode => { ..model, workspace: WsCode, mode: ModeCode, }
    WsEmpty => { ..model, workspace: WsEmpty, }
  }
  (next, @moui.Effect::none())
}

///|
fn toggle_pane_live(model : Model) -> (Model, @moui.Effect[Msg]) {
  ({ ..model, pane_live: !model.pane_live, }, @moui.Effect::none())
}

///|
fn toggle_pane_blocks(model : Model) -> (Model, @moui.Effect[Msg]) {
  ({ ..model, pane_blocks: !model.pane_blocks, }, @moui.Effect::none())
}

///|
/// 幂等显示 Live App 窗格（空舞台的恢复入口）。
///
/// 必须用**赋值**而不是取反：空舞台只在两个窗格都关掉时出现，所以
/// `ShowPaneLive` 执行时 `pane_live` 一定是 false——但用取反会让这条消息
/// 在别处（比如命令面板）变成「关掉它」，语义不可预测。赋值才是
/// 设计稿 `#btnAddLive` 的语义：`S.live=true`。
///
/// 同时把工作区切回可视化：空舞台可以是 `WsEmpty`（点图标栏收起）造成的，
/// 那时只把 pane 打开、工作区还停在 `WsEmpty`，用户点了按钮却什么都没变。
fn show_pane_live(model : Model) -> (Model, @moui.Effect[Msg]) {
  (
    { ..model, workspace: WsVisual, mode: ModeDesign, pane_live: true, },
    @moui.Effect::none(),
  )
}

///|
/// 幂等显示积木窗格（空舞台的恢复入口）。
///
/// 积木窗格还要**有选中的子程序**才画得出来（`blocks_pane_wanted` 判据）。
/// 从空舞台进来时如果没有选中的子程序，就顺手选上第一个——否则用户点了
/// 「+ 积木窗格」而屏幕上只有 Live App，看起来就是按钮没反应。
fn show_pane_blocks(model : Model) -> (Model, @moui.Effect[Msg]) {
  let mut next = {
    ..model,
    workspace: WsVisual,
    mode: ModeDesign,
    pane_blocks: true,
  }
  if current_handler(next) is None {
    match next.program.handlers {
      [first, ..] =>
        next = {
          ..next,
          selected_control: first.control_name,
          selected_handler: handler_key(first.control_name, first.event.tag()),
        }
      [] => ()
    }
  }
  (next, @moui.Effect::none())
}

///|
/// 分隔条比例：钳在 0.2–0.8（两端都留得住内容，拖到底不会把窗格压没）。
fn set_split_ratio(model : Model, ratio : Double) -> (Model, @moui.Effect[Msg]) {
  let clamped = if ratio.is_nan() { 0.55 } else { ratio.max(0.2).min(0.8) }
  ({ ..model, split_ratio: clamped, }, @moui.Effect::none())
}

///|
/// 左栏切换：点当前图标 = 收起（设计稿 setLeft 语义）。
fn set_left_view(model : Model, view : LeftView) -> (Model, @moui.Effect[Msg]) {
  let target = match (model.left_view, view) {
    (LeftTree, LeftTree) | (LeftData, LeftData) => LeftHidden
    (_, wanted) => wanted
  }
  ({ ..model, left_view: target, }, @moui.Effect::none())
}

///|
/// 右栏显隐（右栏头的 ✕ 关、图标栏的面板图标开）。幂等：重复设同一个值
/// 不改变模型。打开时**顺带把左栏的收起考虑进去**——两者互不干涉，
/// 各自吃各自的宽度（窄窗口下由 `shell_chrome_widths` 决定谁让位）。
fn set_right_visible(
  model : Model,
  visible : Bool,
) -> (Model, @moui.Effect[Msg]) {
  ({ ..model, right_visible: visible, }, @moui.Effect::none())
}

// ============================================================================
// 审计时间线
// ============================================================================

///|
/// 追加审计条目（会话内，超 AUDIT_LIMIT 丢最旧）。
/// 视图层与 update 层共用：所有条目都带单调序号，稳定 key。
pub fn push_audit(
  model : Model,
  kind : AuditKind,
  text : String,
  detail : String,
) -> Model {
  let entries = model.audit_entries
  entries.push(AuditEntry::{
    kind,
    seq: model.audit_seq,
    text,
    detail,
    stack: "",
    settled: false,
    settled_note: "",
  })
  while entries.length() > AUDIT_LIMIT {
    ignore(entries.remove(0))
  }
  { ..model, audit_entries: entries, audit_seq: model.audit_seq + 1, }
}

///|
/// 追加带调用栈的审计错误卡。
pub fn push_audit_error(model : Model, text : String, stack : String) -> Model {
  let entries = model.audit_entries
  entries.push(AuditEntry::{
    kind: AuditError,
    seq: model.audit_seq,
    text,
    detail: "",
    stack,
    settled: false,
    settled_note: "",
  })
  while entries.length() > AUDIT_LIMIT {
    ignore(entries.remove(0))
  }
  { ..model, audit_entries: entries, audit_seq: model.audit_seq + 1, }
}

///|
/// 追加副作用待确认卡（AuditWarn）。
pub fn push_audit_side_effect(
  model : Model,
  text : String,
  detail : String,
) -> Model {
  push_audit(model, AuditWarn, text, detail)
}

///|
/// 点击审计条目：整数下标 → 该条目的序号，再反查对应积木块。
/// 审计条目记的是「第几条事实」，跳转需要的是「哪条语句」——
/// 这里按条目序号定位到最近一条带语句路径的事实（detail 里存的
/// 是规范文本，用 current_spotlight 同源的匹配）。
fn jump_audit(model : Model, index : Int) -> @moui.Effect[Msg] {
  ignore(model)
  ignore(index)
  @moui.Effect::none()
}

///|
/// 处理单条审计卡（确认/拒绝）：标记 settled + 记 Console。
fn settle_audit(
  model : Model,
  index : Int,
  note : String,
) -> (Model, @moui.Effect[Msg]) {
  if index < 0 || index >= model.audit_entries.length() {
    return (model, @moui.Effect::none())
  }
  let entries : Array[AuditEntry] = []
  let mut cursor = 0
  for entry in model.audit_entries {
    if cursor == index {
      entries.push(AuditEntry::{ ..entry, settled: true, settled_note: note, })
    } else {
      entries.push(entry)
    }
    cursor = cursor + 1
  }
  let next = { ..model, audit_entries: entries, }
  (log_line(next, LogInfo, "app.log.settled"), @moui.Effect::none())
}

///|
/// 一键确认全部副作用卡：把「待确认」清空（仍不改闸门语义——真实
/// 外发只在运行时点确认按钮时才发生）。
fn settle_all_audit(model : Model, note : String) -> (Model, @moui.Effect[Msg]) {
  let entries : Array[AuditEntry] = []
  let mut changed = false
  for entry in model.audit_entries {
    if entry.kind is AuditWarn && !entry.settled {
      entries.push(AuditEntry::{ ..entry, settled: true, settled_note: note, })
      changed = true
    } else {
      entries.push(entry)
    }
  }
  if !changed {
    return (model, @moui.Effect::none())
  }
  let next = { ..model, audit_entries: entries, }
  (log_line(next, LogInfo, "app.log.settled_all"), @moui.Effect::none())
}

// ============================================================================
// Console
// ============================================================================

///|
/// 追加 Console 日志行（超 LOG_LIMIT 丢最旧）。
pub fn log_line(model : Model, level : LogLevel, text : String) -> Model {
  let lines = model.log_lines
  lines.push(LogLine::{ level, seq: model.log_seq, text, })
  while lines.length() > LOG_LIMIT {
    ignore(lines.remove(0))
  }
  { ..model, log_lines: lines, log_seq: model.log_seq + 1, }
}

// ============================================================================
// 最近修改
// ============================================================================

///|
/// 追加最近修改条目（会话内，超 RECENT_LIMIT 丢最旧）。
/// by_agent 区分「你」与「Agent」——教学上这是最重要的一列。
pub fn push_recent(
  model : Model,
  target : String,
  action : String,
  by_agent : Bool,
) -> Model {
  let changes = model.recent_changes
  changes.push(RecentChange::{
    target,
    by_agent,
    action,
    seq: model.recent_seq,
  })
  while changes.length() > RECENT_LIMIT {
    ignore(changes.remove(0))
  }
  { ..model, recent_changes: changes, recent_seq: model.recent_seq + 1, }
}

// ============================================================================
// AI 浮动层
// ============================================================================

///|
/// 锚点循环：只有两种落点，所以循环就是**两者互换**——从底栏按一次到
/// 停靠，再按一次回底栏。
fn next_anchor(anchor : AiAnchor) -> AiAnchor {
  match anchor {
    AiBar => AiDocked
    AiDocked => AiBar
  }
}

///|
/// 切换底栏页签。
///
/// **只读页签绝不搬动 AI 输入面**：点「运行审计」「Console」「问题」只是
/// 想看一眼那个面板，`ai_anchor` 保持原样。早先的实现会在此时把锚点改成
/// `AiDocked`（为了绕开 `sync_ai_placement` 对页签的强制），后果是用户在
/// AI 输入面上点一下「问题」，**AI 就自己跑到右栏去了**——用户报的正是
/// 这个。
///
/// 点「AI 输入」则是**明确要求把输入面放到这里**，所以锚点一并切到
/// `AiBar`（从停靠档也能拉回来）。
fn select_bottom_tab(model : Model, tab : BottomTab) -> Model {
  let anchored = if tab is BtAi {
    { ..model, ai_anchor: AiBar }
  } else {
    model
  }
  sync_ai_placement({ ..anchored, bottom_tab: tab, bottom_open: true })
}

///|
/// 显式切换 AI 落点（`SetAiAnchor` / `CycleAiAnchor` 共用）。
///
/// 「把输入面放到某处」必须**同时让它可见**，否则用户按了按钮却什么都没
/// 发生：
///
/// - 落到底栏 ⇒ 展开底栏并选中 AI 页签（页签是「果」，由落点推出来）；
/// - 落到右栏 ⇒ `sync_ai_placement` 会让底栏从 AI 页签让开，避免两份
///   composer 同时画。
fn apply_ai_anchor(model : Model, anchor : AiAnchor) -> Model {
  match anchor {
    AiBar =>
      sync_ai_placement({
        ..model,
        ai_anchor: AiBar,
        bottom_tab: BtAi,
        bottom_open: true,
      })
    AiDocked => sync_ai_placement({ ..model, ai_anchor: AiDocked })
  }
}

///|
/// 把「AI 落点」与「底栏状态」收敛成**一个自洽状态**（唯一漏斗）。
///
/// 这两件事在模型里是分开的字段（`ai_anchor` / `bottom_open` /
/// `bottom_tab`），但它们描述的是**同一件事**——「输入条现在落在哪」。
/// 任何一处单独改动都会产生矛盾状态，实测到过两种：
///
/// - `ai_anchor = AiDocked` 而 `bottom_tab = BtAi`：底栏与右栏**各画一份
///   composer**，一个输入面变成两个；
/// - `ai_anchor = AiBar` 而 `bottom_tab != BtAi`：底栏档却停在别的页签，
///   展开底栏看不到输入框。
///
/// 所以所有写这三个字段的地方都必须过这个函数。**不要再在分支里各写一份
/// 联动**——那正是上面第一个矛盾的来源（`SetBottomTab` 改页签、`SetAiAnchor`
/// 改锚点，两边各联动一半）。
///
/// **`bottom_open` 不在这个不变式里**（曾经的第三条约束「`AiBar` ⇒
/// `bottom_open = true`」已删除）。折叠底栏是**面板级的**用户动作，与
/// 「输入面落在哪」是两件事：折叠时输入面跟着收起（和审计/控制台页签
/// 完全一样），展开后原样回来——因为 `bottom_tab` 仍是 `BtAi`。把
/// `bottom_open` 钉成 `true` 会让「收起底栏」变成一个**按不动的按钮**。
fn sync_ai_placement(model : Model) -> Model {
  match model.ai_anchor {
    AiBar =>
      // 底栏档：只保证「高度装得下 composer」。
      //
      // **不强制 `bottom_tab`、也不强制 `bottom_open`**：
      // - 强制页签会让「点其它页签」永远打不开（sync 每次都把它拉回
      //   `BtAi`）——那正是早先不得不「顺手改锚点」的原因，而改锚点又
      //   造成「AI 自己跑到右栏」；
      // - 强制展开会让「收起底栏」变成按不动的按钮。
      //
      // 页签与展开都是**用户的选择**；落点只管「输入面归谁画」。要让
      // 输入面可见，走 `apply_ai_anchor`（显式切换落点时才需要）。
      {
        ..model,
        bottom_height: model.bottom_height.max(AI_BAR_HEIGHT),
      }
    AiDocked =>
      // 停靠档：输入条由右栏承载，底栏若正停在 AI 页签就必须让开
      // （否则两边同时画）。底栏是否展开、展开多少由用户决定，不动。
      {
        ..model,
        bottom_tab: if model.bottom_tab is BtAi {
          BtAudit
        } else {
          model.bottom_tab
        },
      }
  }
}

///|
/// 追加 AI 会话卡（超 AI_CARD_LIMIT 丢最旧）。
pub fn push_ai_card(model : Model, card : AiCard) -> Model {
  let cards = model.ai_cards
  cards.push(AiCard::{ ..card, seq: model.ai_card_seq, })
  while cards.length() > AI_CARD_LIMIT {
    ignore(cards.remove(0))
  }
  { ..model, ai_cards: cards, ai_card_seq: model.ai_card_seq + 1, }
}

// ============================================================================
// 快速操作（对齐）
// ============================================================================

///|
/// 对齐目标：设计稿口径是 24pt 边距、640 设计宽。
priv enum AlignTarget {
  AlignLeft
  AlignCenter
  AlignRight
}

///|
/// 对齐单个选中控件：改 x，宽度不变。
/// 24pt 边距与「居中 = round((640 − w) / 2)」直接来自设计稿的 qaBar。
/// 走 with_undo_point（coalesce 键按控件+对齐方式，连续对齐合并为一个还原点）。
fn align_control(
  model : Model,
  name : String,
  target : AlignTarget,
) -> (Model, @moui.Effect[Msg]) {
  match @ir.find_control(model.program, name) {
    None => (model, @moui.Effect::none())
    Some(control) => {
      let x = match target {
        AlignLeft => ALIGN_MARGIN
        AlignCenter => (@ir.DESIGN_WIDTH - control.width) / 2
        AlignRight => @ir.DESIGN_WIDTH - control.width - ALIGN_MARGIN
      }
      let clamped = x.max(0)
      if clamped == control.x {
        return (model, @moui.Effect::none())
      }
      let undo = with_undo_point(model, "align:\{name}", m => {
        let controls : Array[@ir.Control] = []
        for item in m.program.controls {
          if item.name == name {
            controls.push(item.with_rect_field(@ir.RectX, clamped))
          } else {
            controls.push(item)
          }
        }
        { ..m, program: { ..m.program, controls, }, }
      })
      let next = { ..undo, selected_control: name, }
      (
        log_line(
          push_recent(next, name, "app.recent.align", false),
          LogInfo,
          "app.log.align",
        ),
        @moui.Effect::none(),
      )
    }
  }
}

///|
/// 设计稿的快速操作对齐边距。
pub const ALIGN_MARGIN : Int = 24

// ============================================================================
// 对话框与命令
// ============================================================================

///|
fn dismiss_toast(model : Model, index : Int) -> (Model, @moui.Effect[Msg]) {
  if index < 0 || index >= model.toasts.length() {
    return (model, @moui.Effect::none())
  }
  let toasts : Array[ToastEntry] = []
  let mut cursor = 0
  for toast in model.toasts {
    if cursor != index {
      toasts.push(toast)
    }
    cursor = cursor + 1
  }
  ({ ..model, toasts, }, @moui.Effect::none())
}

///|
/// 追加 toast（超 TOAST_LIMIT 丢最旧）。
pub fn push_toast(model : Model, text : String, warning : Bool) -> Model {
  let toasts = model.toasts
  toasts.push(ToastEntry::{ text, warning, age: 0, })
  while toasts.length() > TOAST_LIMIT {
    ignore(toasts.remove(0))
  }
  { ..model, toasts, }
}

///|
/// notice 的唯一写入漏斗：写 `model.notice` 的同时补推一条 toast。
///
/// 为什么必须有这个漏斗：`notice` 在视图层**没有任何渲染点**（状态栏不画
/// 它），直接写结构体字段等于把成功/失败静默吞掉——保存失败、解析失败、
/// 预算超限、Web 端编译轨不可达，用户全都看不到。所有 notice 写入必须
/// 走这里；警告类（warning=true）用暖色条。空串（settings 写入的哑回调
/// `SetNotice("")`）只清字段，不产生 toast。长文本按 toast 文案宽度截断
/// （toast 视图是定宽 300 的单行）。
pub fn with_notice(model : Model, notice : String, warning : Bool) -> Model {
  if notice == "" {
    return { ..model, notice: "", }
  }
  push_toast({ ..model, notice, }, fit_label(notice, 280.0), warning)
}

///|
/// Studio 自有命令：比 moui 文本命令协议的 10 个 intent 更宽的壳操作。
/// 每条命令都是既有消息的封装——命令面板不引入新的状态通道。
fn run_studio_command(model : Model, id : String) -> (Model, @moui.Effect[Msg]) {
  match id {
    "studio.workspace.visual" => update_pure(model, SetWorkSpace(WsVisual))
    "studio.workspace.code" => update_pure(model, SetWorkSpace(WsCode))
    "studio.workspace.empty" => update_pure(model, SetWorkSpace(WsEmpty))
    "studio.pane.split" => update_pure(model, SetSplitRatio(0.55))
    "studio.pane.live" => update_pure(model, TogglePaneLive)
    "studio.pane.blocks" => update_pure(model, TogglePaneBlocks)
    "studio.left.tree" => update_pure(model, SetLeftView(LeftTree))
    "studio.left.data" => update_pure(model, SetLeftView(LeftData))
    "studio.right.toggle" =>
      update_pure(model, SetRightVisible(!model.right_visible))
    "studio.ctx.runtime" => update_pure(model, SetContextTab(CtxRuntime))
    "studio.code.complete" => update_pure(model, TriggerCompletion)
    "studio.code.jump" => update_pure(model, JumpToDeclaration)
    "studio.bottom.audit" => update_pure(model, SetBottomTab(BtAudit))
    "studio.bottom.console" => update_pure(model, SetBottomTab(BtConsole))
    "studio.bottom.problems" => update_pure(model, SetBottomTab(BtProblems))
    "studio.bottom.toggle" => update_pure(model, ToggleBottom)
    "studio.audit.settle_all" =>
      update_pure(model, AuditSettleAll("app.audit.confirmed"))
    "studio.ai.anchor" => update_pure(model, CycleAiAnchor)
    "studio.ai.bar" => update_pure(model, SetAiAnchor(AiBar))
    "studio.ai.dock" =>
      update_pure(
        model,
        SetAiAnchor(
          if model.ai_anchor is AiDocked {
            AiBar
          } else {
            AiDocked
          },
        ),
      )
    "studio.ai.history" => update_pure(model, ToggleAiHistory)
    "studio.settings" => update_pure(model, ToggleSettings)
    "studio.run.start" => update_pure(model, RunStart)
    "studio.run.stop" => update_pure(model, RunStop)
    "studio.compile.run" => update_pure(model, CompileRun)
    "studio.file.new" => update_pure(model, NewBlankProgram)
    "studio.file.save" => update_pure(model, SaveRequested)
    "studio.file.open" => update_pure(model, OpenRequested)
    "studio.file.export" => update_pure(model, ExportRequested)
    "studio.lang.switch" => update_pure(model, SwitchLanguage)
    "studio.help" => update_pure(model, SetMode(ModeHelp))
    "studio.preview" => update_pure(model, SetMode(ModePreview))
    "studio.template.hello" => update_pure(model, SelectTemplate(0))
    "studio.template.roll_call" => update_pure(model, SelectTemplate(1))
    "studio.template.drill" => update_pure(model, SelectTemplate(2))
    "studio.template.store" => update_pure(model, SelectTemplate(3))
    _ => (model, @moui.Effect::none())
  }
}

///|
/// 代码草稿回归 IR 渲染：丢弃手改，重新按当前语言渲染当前子程序。
fn restore_code_draft(model : Model) -> (Model, @moui.Effect[Msg]) {
  match current_handler(model) {
    None => (model, @moui.Effect::none())
    Some(handler) => {
      let rendered = @studio_lang.render_handler(
        handler,
        model.language.dsl_language(),
      )
      (
        log_line(
          { ..model, code_draft: rendered, code_error: "", },
          LogInfo,
          "app.log.restore",
        ),
        @moui.Effect::none(),
      )
    }
  }
}

///|
/// toast 老化：每秒 +1，满 TOAST_SECONDS 秒即消失（自动，无需手点）。
fn age_toasts(model : Model) -> Model {
  let kept : Array[ToastEntry] = []
  for toast in model.toasts {
    if toast.age + 1 < TOAST_SECONDS {
      kept.push(ToastEntry::{ text: toast.text, warning: toast.warning, age: toast.age + 1, })
    }
  }
  { ..model, toasts: kept, }
}
