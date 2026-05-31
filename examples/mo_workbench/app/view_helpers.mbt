///|
using @views {
  badge,
  button,
  column,
  empty,
  row,
  scroll_view,
  spacer,
  surface,
  text,
  text_field,
}

///|
pub fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  let theme = @views.light_theme()
  surface(
    row(
      [self.app_sidebar(theme), self.conversation_surface(theme)],
      spacing=0.0,
      align=Stretch,
    ),
    width=1200.0,
    height=750.0,
    background=ui_color(0.98, 0.98, 0.97),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::app_sidebar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.sidebar_brand(theme),
        self.sidebar_actions(theme),
        self.sidebar_section_label("置顶", theme),
        self.pinned_threads(theme),
        self.sidebar_section_label("项目", theme),
        self.project_threads(theme),
        spacer(min_length=8.0, weight=1.0),
        self.sidebar_footer(theme),
      ],
      spacing=theme.spacing_scale.sm,
      align=Stretch,
    ),
    width=292.0,
    height=750.0,
    background=ui_color(0.91, 0.92, 0.92),
    corner_radius=0.0,
    theme~,
    padding=14.0,
  )
}

///|
fn WorkbenchModel::sidebar_brand(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      text("Mo Workbench", role=Title, theme~, width=246.0, height=34.0),
      text("A Pi agent desktop", role=Caption, theme~, width=246.0, height=24.0),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::sidebar_actions(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      sidebar_text_row("新对话", theme),
      sidebar_text_row("搜索", theme),
      sidebar_text_row("插件 - 已解锁", theme),
      sidebar_text_row("自动化", theme),
    ],
    spacing=2.0,
    align=Stretch,
  )
}

///|
fn WorkbenchModel::pinned_threads(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      self.thread_button(
        "分析这个项目",
        SelectSession("moui-skia"),
        theme,
        selected=self.selected_session_id == "moui-skia",
        meta="",
      ),
      self.thread_button(
        "回复问候",
        SelectSession("pi-rpc"),
        theme,
        selected=self.selected_session_id == "pi-rpc",
        meta="15 小时",
      ),
      self.thread_button(
        "推进 TEA/Skia 基线",
        SelectSession("docs-research"),
        theme,
        selected=self.selected_session_id == "docs-research",
        meta="5 小时",
      ),
    ],
    spacing=2.0,
    align=Stretch,
  )
}

///|
fn WorkbenchModel::project_threads(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      sidebar_text_row("MoUI", theme),
      sidebar_text_row("实现 Mo Workbench 原型        42 分", theme),
      sidebar_text_row("新增 Mo Workbench 原型        3 小时", theme),
      sidebar_text_row("评估项目拆分方式              3 小时", theme),
      sidebar_text_row("定位当前渲染方式              3 小时", theme),
      sidebar_text_row("Fix render/skia linker flags   5 小时", theme),
      sidebar_text_row("展开显示", theme),
    ],
    spacing=2.0,
    align=Stretch,
  )
}

///|
fn WorkbenchModel::sidebar_footer(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  row(
    [
      text("设置", role=Control, theme~, width=164.0, height=28.0),
      text("▯", role=Caption, theme~, width=28.0, height=28.0),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::thread_button(
  self : WorkbenchModel,
  label : String,
  message : WorkbenchMsg,
  theme : @core.Theme,
  selected~ : Bool,
  meta~ : String,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let background = if selected {
    ui_color(0.84, 0.85, 0.85)
  } else {
    ui_color(0.91, 0.92, 0.92)
  }
  surface(
    row(
      [
        button(
          label,
          on_click=message,
          variant=Ghost,
          theme~,
          width=188.0,
          height=32.0,
        ),
        text(meta, role=Caption, theme~, width=54.0, height=28.0),
      ],
      spacing=4.0,
      align=Center,
    ),
    width=260.0,
    height=38.0,
    background~,
    corner_radius=10.0,
    theme~,
    padding=2.0,
  )
}

///|
fn WorkbenchModel::conversation_surface(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.top_bar(theme),
        divider(908.0),
        scroll_view(self.chat_transcript(theme), width=908.0, height=594.0),
        self.composer(theme),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=908.0,
    height=750.0,
    background=@core.Color::white(),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::top_bar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    row(
      [
        text("◆", role=Caption, theme~, width=26.0, height=30.0),
        text(
          "在 MoUI 仓库 examples/mo_workbench，交付 Mo Workbench",
          role=Control,
          theme~,
          width=520.0,
          height=30.0,
        ),
        spacer(min_length=10.0, weight=1.0),
        text(active.branch, role=Caption, theme~, width=132.0, height=28.0),
        text("…", role=Title, theme~, width=34.0, height=30.0),
      ],
      spacing=6.0,
      align=Center,
    ),
    width=908.0,
    height=48.0,
    background=@core.Color::white(),
    theme~,
    padding=10.0,
  )
}

///|
fn WorkbenchModel::chat_transcript(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      self.assistant_summary(theme),
      self.transcript_panel(theme),
      self.command_catalog_panel(theme),
      self.command_block(theme),
      self.status_paragraph(theme),
      self.file_attachment_card(
        "examples.md", "文档 · MD", "打开方式⌄", theme,
      ),
      self.file_attachment_card(
        "mo-workbench.md", "文档 · MD", "打开方式⌄", theme,
      ),
      self.diff_summary_card(theme),
      self.message_toolbar(theme),
    ],
    spacing=12.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for item in self.transcript {
    if visible < 3 {
      rows.push(transcript_row(item, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(
      text(
        "No Pi messages loaded yet",
        role=Caption,
        theme~,
        width=650.0,
        height=28.0,
      ),
    )
  }
  surface(
    column(
      [
        row(
          [
            text(
              "Pi transcript",
              role=Control,
              theme~,
              width=520.0,
              height=28.0,
            ),
            badge(
              self.transcript.length().to_string() + " messages",
              tone=Neutral,
              theme~,
              width=116.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        column(rows, spacing=6.0, align=Start),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=690.0,
    height=178.0,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
}

///|
fn transcript_row(
  item : TranscriptItem,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        item.role,
        tone=transcript_badge_tone(item.tone),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(item.summary, role=Control, theme~, width=520.0, height=24.0),
          text(item.detail, role=Caption, theme~, width=520.0, height=22.0),
        ],
        spacing=0.0,
        align=Start,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn transcript_badge_tone(tone : String) -> @views.BadgeTone {
  match tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "info" => Accent
    _ => Neutral
  }
}

///|
fn WorkbenchModel::command_catalog_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for command in self.command_catalog {
    if visible < 3 {
      rows.push(command_catalog_row(command, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(
      text(
        "No Pi commands loaded yet",
        role=Caption,
        theme~,
        width=650.0,
        height=28.0,
      ),
    )
  }
  surface(
    column(
      [
        row(
          [
            text("Pi commands", role=Control, theme~, width=520.0, height=28.0),
            badge(
              self.command_catalog.length().to_string() + " commands",
              tone=Accent,
              theme~,
              width=116.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        column(rows, spacing=6.0, align=Start),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=690.0,
    height=178.0,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
}

///|
fn command_catalog_row(
  command : PiCommandInfo,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        command.source,
        tone=command_source_tone(command.source),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(
            "/" + command.name,
            role=Control,
            theme~,
            width=520.0,
            height=24.0,
          ),
          text(
            command_catalog_detail(command),
            role=Caption,
            theme~,
            width=520.0,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn command_catalog_detail(command : PiCommandInfo) -> String {
  let description = if command.description == "" {
    "No description"
  } else {
    command.description
  }
  let scope = if command.source_scope == "" {
    ""
  } else {
    " · " + command.source_scope
  }
  let path = if command.source_path == "" {
    ""
  } else {
    " · " + command.source_path
  }
  description + scope + path
}

///|
fn command_source_tone(source : String) -> @views.BadgeTone {
  match source {
    "prompt" => Accent
    "skill" => Success
    "extension" => Warning
    _ => Neutral
  }
}

///|
fn WorkbenchModel::assistant_summary(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      text("验证已通过：", role=Control, theme~, width=680.0, height=30.0),
      text(
        "Mo Workbench 已接入 native owned Pi session，并保持 PiTransport 平台无关。",
        role=Body,
        theme~,
        width=680.0,
        height=34.0,
      ),
    ],
    spacing=2.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::command_block(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  surface(
    column(
      [
        text("sh", role=Caption, theme~, width=660.0, height=24.0),
        code_line("moon test examples/mo_workbench/app --target native", theme),
        code_line("moon test examples/mo_workbench/app --target wasm-gc", theme),
        code_line(
          "moon test examples/mo_workbench/native_transport --target native", theme,
        ),
        code_line(
          "moon build examples/mo_workbench/macos_skia --target native", theme,
        ),
        code_line("moon info examples/mo_workbench/app --target native", theme),
        code_line(
          "moon info examples/mo_workbench/native_transport --target native", theme,
        ),
        code_line("node --check scripts/validate-package-manifest.mjs", theme),
        code_line("git diff --check", theme),
      ],
      spacing=0.0,
      align=Start,
    ),
    width=690.0,
    height=230.0,
    background=ui_color(0.93, 0.93, 0.93),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::status_paragraph(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      text(
        "当前 UI 已切到截图式会话流；macOS app 现在持有长生命周期 Pi session owner，",
        role=Body,
        theme~,
        width=690.0,
        height=28.0,
      ),
      text(
        "Skia window pump 与 moonbitlang/async transport worker 在同一 native 主循环轮转。",
        role=Body,
        theme~,
        width=690.0,
        height=28.0,
      ),
      text(
        "Transport: " +
        self.transport.status_label() +
        " · Queued: " +
        self.pending_transport_count().to_string(),
        role=Caption,
        theme~,
        width=690.0,
        height=24.0,
      ),
      text(
        "Pi agent: " + self.pi_agent.status_label(),
        role=Caption,
        theme~,
        width=690.0,
        height=24.0,
      ),
      text(
        "Pi session: " + self.active_pi_session_binding().status_label(),
        role=Caption,
        theme~,
        width=690.0,
        height=24.0,
      ),
      row(
        [
          button(
            "同步标题",
            on_click=SyncSessionName,
            variant=Outline,
            theme~,
            width=86.0,
            height=34.0,
          ),
          text(
            "Pi title target: " + self.active_session().title,
            role=Caption,
            theme~,
            width=560.0,
            height=30.0,
          ),
        ],
        spacing=8.0,
        align=Center,
      ),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::file_attachment_card(
  self : WorkbenchModel,
  title : String,
  subtitle : String,
  action : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  surface(
    row(
      [
        surface(
          text("▣", role=Control, theme~, width=32.0, height=32.0),
          width=42.0,
          height=42.0,
          background=ui_color(0.95, 0.95, 0.95),
          corner_radius=8.0,
          theme~,
          padding=5.0,
        ),
        column(
          [
            text(title, role=Control, theme~, width=430.0, height=26.0),
            text(subtitle, role=Caption, theme~, width=430.0, height=24.0),
          ],
          spacing=0.0,
          align=Start,
        ),
        spacer(min_length=8.0, weight=1.0),
        button(
          action,
          on_click=SelectPanel("files"),
          variant=Outline,
          theme~,
          width=110.0,
          height=36.0,
        ),
      ],
      spacing=10.0,
      align=Center,
    ),
    width=690.0,
    height=76.0,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::diff_summary_card(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        row(
          [
            surface(
              text("⊞", role=Control, theme~, width=32.0, height=32.0),
              width=42.0,
              height=42.0,
              background=ui_color(0.95, 0.95, 0.95),
              corner_radius=8.0,
              theme~,
              padding=5.0,
            ),
            column(
              [
                text(
                  "已编辑 " +
                  self.diff.changed_files.to_string() +
                  " 个文件",
                  role=Control,
                  theme~,
                  width=350.0,
                  height=26.0,
                ),
                text(
                  "+" +
                  self.diff.additions.to_string() +
                  " -" +
                  self.diff.deletions.to_string(),
                  role=Caption,
                  theme~,
                  width=150.0,
                  height=24.0,
                ),
              ],
              spacing=0.0,
              align=Start,
            ),
            spacer(min_length=8.0, weight=1.0),
            button(
              "撤销 ↶",
              on_click=CancelRun,
              variant=Ghost,
              theme~,
              width=74.0,
              height=34.0,
            ),
            button(
              "审核",
              on_click=SelectPanel("files"),
              variant=Outline,
              theme~,
              width=64.0,
              height=34.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        divider(666.0),
        diff_row("docs/examples.md", "+1 -0", theme),
        diff_row("examples/mo_workbench/app/pkg.generated.mbti", "+0 -2", theme),
        diff_row(
          "examples/mo_workbench/native_transport/native_transport.mbt", "+92 -4",
          theme,
        ),
        text(
          "再显示 3 个文件⌄",
          role=Control,
          theme~,
          width=660.0,
          height=30.0,
        ),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=690.0,
    height=218.0,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::message_toolbar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  row(
    [
      text("复制", role=Caption, theme~, width=42.0, height=26.0),
      text("赞", role=Caption, theme~, width=28.0, height=26.0),
      text("踩", role=Caption, theme~, width=28.0, height=26.0),
      text("展开", role=Caption, theme~, width=42.0, height=26.0),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::composer(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        text_field(
          self.prompt,
          on_input=value => PromptChanged(value),
          on_submit=Some(DispatchPrompt),
          placeholder="要求后续变更",
          variant=Plain,
          theme~,
          width=748.0,
          height=54.0,
        ),
        row(
          [
            button(
              "+",
              on_click=ToggleContext("repo"),
              variant=Ghost,
              theme~,
              width=38.0,
              height=34.0,
            ),
            badge("自动审查", tone=Accent, theme~, width=86.0),
            text("目标", role=Caption, theme~, width=42.0, height=28.0),
            badge("fast", tone=Success, theme~, width=60.0),
            spacer(min_length=10.0, weight=1.0),
            badge("custom", tone=Neutral, theme~, width=82.0),
            text("5.5 超高", role=Control, theme~, width=78.0, height=30.0),
            button(
              "↑",
              on_click=DispatchPrompt,
              variant=Primary,
              theme~,
              width=42.0,
              height=36.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ],
      spacing=6.0,
      align=Stretch,
    ),
    width=760.0,
    height=126.0,
    background=@core.Color::white(),
    corner_radius=18.0,
    theme~,
    padding=12.0,
  )
}

///|
fn code_line(line : String, theme : @core.Theme) -> @core.View[WorkbenchMsg] {
  text(line, role=Mono, theme~, width=660.0, height=24.0)
}

///|
fn diff_row(
  path : String,
  change : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text(path, role=Body, theme~, width=532.0, height=30.0),
      text(change, role=Control, theme~, width=78.0, height=30.0),
      text("⌄", role=Caption, theme~, width=24.0, height=30.0),
    ],
    spacing=4.0,
    align=Center,
  )
}

///|
fn sidebar_text_row(
  label : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  text(label, role=Control, theme~, width=246.0, height=34.0)
}

///|
fn WorkbenchModel::sidebar_section_label(
  self : WorkbenchModel,
  label : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  text(label, role=Caption, theme~, width=246.0, height=30.0)
}

///|
fn divider(width : Double) -> @core.View[WorkbenchMsg] {
  surface(
    empty(),
    width~,
    height=1.0,
    background=ui_color(0.90, 0.90, 0.90),
    padding=0.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}
