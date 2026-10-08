///|
/// 全局键盘命令表（`Program::with_commands`）：不依赖焦点载体的快捷键。
///
/// 背景（差距分析 §2.1）：此前只有 3 个快捷键（撤销/重做/面板），且全部
/// 挂在 `@views.button` 上——按钮不在视口或被遮挡时快捷键就失效。
/// 这张表把保存/打开/导出/运行/工作区切换/底栏折叠补齐为**程序级**绑定。
///
/// 每条绑定注册 **meta（macOS）与 control（Windows/Linux）两个变体**——
/// `KeyboardShortcut::matches` 对修饰键做精确相等比较，双注册是既定口径
/// （与顶栏按钮上的撤销/重做一致）。命令面板（Cmd/Ctrl+K）仍留在顶栏
/// 按钮上，避免同一快捷键双触发。
pub fn studio_program_commands(
  model : Model,
) -> Array[@moui.ProgramCommand[Msg]] {
  let t = translator(model)
  let commands : Array[@moui.ProgramCommand[Msg]] = []
  let bind = fn(
    key : String,
    shift : Bool,
    label_key : String,
    intent : @core.CommandIntent,
    enabled : Bool,
    message : Msg,
  ) {
    for meta in [true, false] {
      commands.push(
        @moui.ProgramCommand::new(
          command=@views.ActionCommand::new(
            intent~,
            label=text(t, label_key),
            shortcut=Some(
              @core.KeyboardShortcut::new(
                key~,
                modifiers=@core.KeyModifiers::new(shift~, control=!meta, meta~),
              ),
            ),
            enabled~,
            group="Studio",
          ),
          message~,
        ),
      )
    }
  }
  let has_selection = model.selected_control != ""
  bind("s", false, "app.command.file.save", Submit, true, SaveRequested)
  bind("o", false, "app.command.file.open", Activate, true, OpenRequested)
  bind("e", false, "app.command.file.export", Submit, true, ExportRequested)
  bind("Enter", false, "app.command.run.start", Submit, true, RunStart)
  // 撤销/重做：从按钮载体迁移到全局表（按钮壳的 stack 顶对齐导致图标
  // 偏上；全局表接管快捷键后按钮恢复与芯片对齐的 icon_button）
  bind("z", false, "app.edit.undo", Undo, true, Undo)
  bind("z", true, "app.edit.redo", Undo, true, Redo)
  // 命令面板：Ctrl/Cmd+K
  bind("k", false, "app.command.open", Activate, true, CommandPaletteOpen)
  // Ctrl+Space：补全候选（编辑器情报）
  bind(
    " ",
    false,
    "app.command.code.complete",
    Activate,
    true,
    TriggerCompletion,
  )
  // 新建 AI 会话 / 会话搜索（M6,对白转录）：meta+control 双注册由 bind 统一
  bind(
    "n",
    false,
    "app.command.ai.new_session",
    Activate,
    true,
    AiSessionOp(AiSessionCreate(civil_seconds(model.clock))),
  )
  bind(
    "f",
    false,
    "app.command.ai.search_sessions",
    Activate,
    model.perspective is PsAi,
    ToggleAiSessionSearch,
  )
  bind(
    "1",
    false,
    "app.command.perspective.visual",
    Activate,
    true,
    SetPerspective(PsVisual),
  )
  bind(
    "2",
    false,
    "app.command.perspective.code",
    Activate,
    true,
    SetPerspective(PsCode),
  )
  bind(
    "3",
    false,
    "app.command.perspective.ai",
    Activate,
    true,
    SetPerspective(PsAi),
  )
  bind("j", false, "app.command.bottom.toggle", Activate, true, ToggleBottom)
  // Ctrl+T：底栏切到终端页签（M8 用户反馈：键盘直达终端）
  bind(
    "t",
    false,
    "app.command.bottom.terminal",
    Activate,
    true,
    SetBottomTab(BtTerminal),
  )
  // Ctrl+Shift+T：关闭终端（kill PTY + 收起页签）——开关全程键盘可达
  bind(
    "t",
    true,
    "app.command.bottom.terminal.close",
    Activate,
    true,
    TerminalTabClose,
  )
  bind(
    "d",
    false,
    "app.command.control.duplicate",
    Activate,
    has_selection,
    DuplicateControl(model.selected_control),
  )
  // ── 画布交互键盘（G7.2 P3e）────────────────────────────────────
  // 复制/粘贴（Ctrl+C / Ctrl+V,编辑器内部的剪贴板优先由编辑器消费）
  bind(
    "c",
    false,
    "app.command.control.copy",
    Activate,
    has_selection,
    CopySelectedControl,
  )
  bind(
    "v",
    false,
    "app.command.control.paste",
    Activate,
    model.control_clipboard is Some(_),
    PasteControl,
  )
  // 置顶/置底（Ctrl+] / Ctrl+[）
  bind(
    "]",
    false,
    "app.command.control.front",
    Activate,
    has_selection,
    BringToFront(model.selected_control),
  )
  bind(
    "[",
    false,
    "app.command.control.back",
    Activate,
    has_selection,
    SendToBack(model.selected_control),
  )
  // 多选模式开关（Ctrl+M;命中切换成员,方向键整组微调）
  bind(
    "m",
    false,
    "app.command.control.multi",
    Activate,
    true,
    ToggleMultiSelectMode,
  )
  // F5：继续到断点（G7.4 断点调试）
  bind(
    "F5",
    false,
    "app.command.run.to_breakpoint",
    Activate,
    model.run is Some(_),
    RunToBreakpoint,
  )
  // 方向键微调（1px/按;多选模式下整组移动）
  bind(
    "ArrowLeft",
    false,
    "app.command.control.nudge.left",
    Activate,
    has_selection,
    NudgeControl(model.selected_control, -1, 0),
  )
  bind(
    "ArrowRight",
    false,
    "app.command.control.nudge.right",
    Activate,
    has_selection,
    NudgeControl(model.selected_control, 1, 0),
  )
  bind(
    "ArrowUp",
    false,
    "app.command.control.nudge.up",
    Activate,
    has_selection,
    NudgeControl(model.selected_control, 0, -1),
  )
  bind(
    "ArrowDown",
    false,
    "app.command.control.nudge.down",
    Activate,
    has_selection,
    NudgeControl(model.selected_control, 0, 1),
  )
  // ── 积木域键盘（Scratch/IDE 口径）────────────────────────────────────
  //
  // 判据用 `selected_block >= 0`（选中了积木）而不是「在积木工作区」：
  // 选中态本身就是「用户正在编辑积木」的可靠信号，而工作区可能在代码页。
  // 三条都**只在有积木选中时**启用——否则 Delete 会变成「删掉一个看不见
  // 的东西」，那是危险的空操作。
  let has_block = model.selected_block >= 0
  bind(
    "ArrowUp",
    false,
    "app.command.block.prev",
    Activate,
    has_block,
    SelectBlockStep(-1),
  )
  bind(
    "ArrowDown",
    false,
    "app.command.block.next",
    Activate,
    has_block,
    SelectBlockStep(1),
  )
  bind(
    "Delete",
    false,
    "app.command.block.delete",
    Activate,
    has_block,
    DeleteBlock,
  )
  bind(
    "Backspace",
    false,
    "app.command.block.delete",
    Activate,
    has_block,
    DeleteBlock,
  )
  bind(
    "d",
    false,
    "app.command.block.duplicate",
    Activate,
    has_block,
    DuplicateBlock,
  )
  bind(
    "Enter",
    true,
    "app.command.block.commit",
    Submit,
    has_block,
    CommitBlock,
  )
  // 「运行这一块」（Scratch 的点击运行）：Cmd/Ctrl+R。
  // **不能用 Cmd+Enter**——那个已经给了「提交积木编辑」，同一组合绑两条
  // 命令会双触发（`ActionCommandMap` 按 key 匹配，不按 intent 去重）。
  bind("r", false, "app.run.single", Activate, has_block, RunSingleBlock)
  // Escape 取消**值编辑**：只在值编辑进行中启用。值编辑是个「就地小输入」，
  // 没有取消路径的话用户只能提交（或点走），而提交会改 IR——想放弃却改了。
  bind(
    "Escape",
    false,
    "app.command.block.cancel_value",
    Activate,
    model.block_value_edit is Some(_),
    BlockValueCancel,
  )
  // Escape 收起**补全弹层**：`completion_open` 此前只有「打开」没有「关闭」
  // 的生产者（`DismissCompletion` 有处理分支却没人发），于是弹出后按 Esc
  // 关不掉——只能选中某一项或点走。与值编辑的 Escape 是**互斥**的两态
  // （补全弹层与值编辑不会同时在），所以同一个键不会双触发。
  bind(
    "Escape",
    false,
    "app.command.code.dismiss_completion",
    Activate,
    model.completion_open,
    DismissCompletion,
  )
  // Escape 放弃会话行内改名（M6）：与补全/值编辑互斥（AI 模式左栏编辑态）
  bind(
    "Escape",
    false,
    "app.command.ai.dismiss_rename",
    Activate,
    model.session_rename is Some(_),
    AiSessionRenameDismiss,
  )
  commands
}
