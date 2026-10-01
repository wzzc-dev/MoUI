///|
/// MoUI Studio 命令面板：技术风 IDE 的键盘优先入口（Ctrl/Cmd+K）。
///
/// **命令表是 Studio 原生的 `StudioCommand`**（`ide_dialogs.mbt`），不是
/// moui 的 `@core.ActionCommand`。原因：`@core.CommandIntent` 只有 10 个
/// 稳定 id（Activate/Submit/Undo/…），而 Studio 的壳操作用 30 条；
/// 早期版本把命令硬塞进那 10 个 intent，结果「撤销」槽位被映射成了
/// `RunStart`（撤销变成了运行）、四个模板只剩两个、v4 的工作区命令整表
/// 不可达——一套借来的 id 空间承担不了自己的命令集。
///
/// 现在面板直接产 `StudioCommandRun(id)`，`run_studio_command` 是唯一
/// 执行通道；副作用消息（保存/生成/编译）经 `Effect::send` 重新走
/// Program 顶层，与点按钮完全同一条状态转移。

///|
/// 命令面板内容：标题 + 过滤输入 + 命令列表 + 快捷键提示。
pub fn command_palette_dialog(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let commands = filter_studio_commands(
    studio_commands(t),
    model.command_palette_query,
  )
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
        command_palette_list(model, commands, t),
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

///|
/// 命令列表：每个命令一行（标签 + 分组），点击即运行。
/// 空结果给一条本地化提示，不留空白框（用户会以为面板坏了）。
fn command_palette_list(
  model : Model,
  commands : Array[StudioCommand],
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  if commands.length() == 0 {
    rows.push(
      @views.container(
        @views.text(
          text(t, "app.command.empty"),
          theme=studio_theme(),
          width=396.0,
          height=24.0,
          align=TextStart,
        ).foreground(ide_text_faint()),
        width=420.0,
        height=36.0,
        padding=0.0,
      ),
    )
  } else {
    for command in commands {
      rows.push(command_palette_row(command, model.hover_studio_command, t))
    }
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width=420.0,
    height=260.0,
  )
}

///|
/// 单条命令行：标签左、分组右，整行可点（`on_tap` 带 Semantics 角色，
/// 与左栏树行同一纪律——面板行不是按钮，不该有按钮盒）。
fn command_palette_row(
  command : StudioCommand,
  hovered_id : String,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  // 悬停反馈：与左栏树行同一口径（ide_selection 底）。
  let hovered = hovered_id != "" && hovered_id == command.id
  let row_width = 420.0
  let group_width = 96.0
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.text(
            fit_label(command.label, row_width - group_width - 28.0),
            theme=studio_theme(),
            width=(row_width - group_width - 24.0).max(80.0),
            height=20.0,
            align=TextStart,
          ).foreground(ide_text()),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            fit_label(command.group, group_width - 4.0),
            theme=studio_theme(),
            width=group_width,
            height=18.0,
            align=TextEnd,
          ).foreground(ide_text_faint()),
        ],
        row_width - 16.0,
        6.0,
        Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=if hovered { ide_selection() } else { ide_panel() },
    height=30.0,
    width=row_width,
    padding=0.0,
  )
  .on_hover(active => HoverStudioCommand(if active { command.id } else { "" }))
  .on_tap(StudioCommandRun(command.id))
  .accessibility_label(command.label)
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
