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
                modifiers=@core.KeyModifiers::new(
                  shift~,
                  control=!meta,
                  meta~,
                ),
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
  bind(
    "e",
    false,
    "app.command.file.export",
    Submit,
    true,
    ExportRequested,
  )
  bind("Enter", false, "app.command.run.start", Submit, true, RunStart)
  // 撤销/重做：从按钮载体迁移到全局表（按钮壳的 stack 顶对齐导致图标
  // 偏上；全局表接管快捷键后按钮恢复与芯片对齐的 icon_button）
  bind("z", false, "app.edit.undo", Undo, true, Undo)
  bind("z", true, "app.edit.redo", Undo, true, Redo)
  // 命令面板：Ctrl/Cmd+K
  bind("k", false, "app.command.open", Activate, true, CommandPaletteOpen)
  // Ctrl+Space：补全候选（编辑器情报）
  bind(" ", false, "app.command.code.complete", Activate, true, TriggerCompletion)
  bind(
    "1",
    false,
    "app.command.workspace.visual",
    Activate,
    true,
    SetWorkSpace(WsVisual),
  )
  bind(
    "2",
    false,
    "app.command.workspace.code",
    Activate,
    true,
    SetWorkSpace(WsCode),
  )
  bind(
    "j",
    false,
    "app.command.bottom.toggle",
    Activate,
    true,
    ToggleBottom,
  )
  bind(
    "d",
    false,
    "app.command.control.duplicate",
    Activate,
    has_selection,
    DuplicateControl(model.selected_control),
  )
  commands
}
