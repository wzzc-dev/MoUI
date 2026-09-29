///|
/// MoUI Studio 命令面板：技术风 IDE 的键盘优先入口（Ctrl/Cmd+K）。
/// 命令表、命令→消息映射、面板内容与 presentation 宿主集中在本文件；
/// 视图层只把顶层内容包一层 overlay_host，保持 views.mbt 的行数预算。

///|
/// 命令面板命令表（视图与纯转移共用同一份）：@core.CommandIntent 是
/// moui 文本命令协议的 10 个稳定 id；Studio 借它承载自己的命令，
/// label/group 全部走 i18n，选中后由 command_message 收敛回既有 Msg。
pub fn command_palette_commands(
  t : @i18n.Translator,
) -> Array[@core.ActionCommand] {
  [
    @core.ActionCommand::new(
      intent=@core.Activate,
      label=text(t, "app.command.mode.design"),
      group=text(t, "app.command.group.mode"),
    ),
    @core.ActionCommand::new(
      intent=@core.Submit,
      label=text(t, "app.command.mode.blocks"),
      group=text(t, "app.command.group.mode"),
    ),
    @core.ActionCommand::new(
      intent=@core.Cancel,
      label=text(t, "app.command.mode.code"),
      group=text(t, "app.command.group.mode"),
    ),
    @core.ActionCommand::new(
      intent=@core.Copy,
      label=text(t, "app.command.mode.preview"),
      group=text(t, "app.command.group.mode"),
    ),
    @core.ActionCommand::new(
      intent=@core.Cut,
      label=text(t, "app.command.track.interpret"),
      group=text(t, "app.command.group.track"),
    ),
    @core.ActionCommand::new(
      intent=@core.Paste,
      label=text(t, "app.command.track.compile"),
      group=text(t, "app.command.group.track"),
    ),
    @core.ActionCommand::new(
      intent=@core.Undo,
      label=text(t, "app.command.run.start"),
      group=text(t, "app.command.group.run"),
    ),
    @core.ActionCommand::new(
      intent=@core.Redo,
      label=text(t, "app.command.run.stop"),
      group=text(t, "app.command.group.run"),
    ),
    @core.ActionCommand::new(
      intent=@core.SelectAll,
      label=text(t, "app.command.file.save"),
      group=text(t, "app.command.group.file"),
    ),
    @core.ActionCommand::new(
      intent=@core.OpenContextMenu,
      label=text(t, "app.command.lang"),
      group=text(t, "app.command.group.lang"),
    ),
  ]
}

///|
/// 命令 id → 既有 Msg 的唯一映射：不新增第二条执行通道，
/// 选中命令与点按钮走同一条状态转移（副作用消息由外层 service 流接管）。
pub fn command_message(intent : @core.CommandIntent) -> Msg {
  match intent {
    @core.Activate => SetMode(ModeDesign)
    @core.Submit => SetMode(ModeBlocks)
    @core.Cancel => SetMode(ModeCode)
    @core.Copy => SetMode(ModePreview)
    @core.Cut => SetRunTrack(Interpret)
    @core.Paste => SetRunTrack(Compile)
    @core.Undo => RunStart
    @core.Redo => RunStop
    @core.SelectAll => SaveRequested
    @core.OpenContextMenu => SwitchLanguage
  }
}

///|
/// 共享字符串助手（Array::join 不可用，显式拼接）：Inspector 的选项列表
/// 与命令面板共用，放在本文件以避免 views.mbt 超过行数棘轮。
fn join_lines(items : Array[String]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for item in items {
    if !first {
      buf.write_string("\n")
    }
    buf.write_string(item)
    first = false
  }
  buf.to_string()
}

///|
/// 命令面板内容：标题 + 过滤输入 + 命令列表 + 快捷键提示。
/// 列表行由 @views.command_palette 渲染，本函数只负责对话框外壳。
pub fn command_palette_dialog(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.text(text(t, "app.command.open"), role=Subtitle, align=TextStart),
        @views.text_field(
          model.command_palette_query,
          on_input=query => CommandPaletteQuery(query),
          placeholder=text(t, "app.command.placeholder"),
          width=420.0,
        ),
        @views.command_palette(
          theme=studio_theme(),
          command_palette_commands(t),
          query=model.command_palette_query,
          on_select=intent => CommandPaletteRun(intent),
          width=420.0,
          max_height=260.0,
        ),
        @views.text(text(t, "app.command.hint"), role=Caption, align=TextStart),
      ],
      spacing=8.0,
    ),
    width=444.0,
    background=studio_console_background(),
    corner_radius=6.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(studio_stage_outline()),
        width=1.0,
      ),
    ),
    padding=12.0,
  )
}
