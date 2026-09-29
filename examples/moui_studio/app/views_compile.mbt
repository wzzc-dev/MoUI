///|
/// 编译轨视图：真编译报告（工具链退出码 + 结构化诊断 + 原始输出）。
/// 「编译失败不静默降级」的界面半边——失败诊断在此逐条渲染，
/// 点击跳回对应积木；原始输出默认折叠，诊断优先。

///|
/// 真编译动作条：显式触发（切轨不隐式编译）+ 忙态提示 + 当前轨说明。
pub fn compile_action_bar(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let trigger = if model.compile_busy {
    @views.button(
      text(t, "app.compile.running"),
      on_click=CompileRun,
      variant=Tonal,
      width=140.0,
    )
  } else {
    @views.button(
      text(t, "app.compile.ok"),
      on_click=CompileRun,
      variant=Primary,
      width=140.0,
    )
  }
  @views.row(
    [
      trigger,
      @views.text(
        if model.compile_track_available {
          text(t, "app.track.compile_note")
        } else {
          text(t, "app.track.unavailable_web")
        },
        role=Caption,
        width=420.0,
        align=TextStart,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
/// 真编译报告卡：无报告且不在编译时渲染空视图（调用方不必分支）。
pub fn compile_report_card(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  if model.compile_busy {
    return @views.card(
      @views.row(
        [
          @views.badge(
            theme=studio_theme(),
            text(t, "app.compile.running"),
            tone=@style.BadgeTone::Warning,
            width=140.0,
            height=24.0,
          ),
          @views.text(text(t, "app.track.compile_note"), role=Caption),
        ],
        spacing=8.0,
      ),
      width=600.0,
      padding=10.0,
    )
  }
  match model.compile_report {
    None => @views.text("")
    Some(report) => {
      let badge = @views.badge(
        theme=studio_theme(),
        if report.ok {
          text(t, "app.compile.ok")
        } else {
          text(t, "app.compile.failed")
        },
        tone=if report.ok {
          @style.BadgeTone::Success
        } else {
          @style.BadgeTone::Danger
        },
        width=140.0,
        height=24.0,
      )
      let rows : Array[@moui.View[Msg]] = [
        @views.row(
          [
            badge,
            @views.text(
              "\{text(t, "app.compile.target")}：\{report.target}",
              width=160.0,
            ),
            @views.text(
              "\{text(t, "app.compile.exit_code")}：\{report.exit_code}",
              width=160.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ]
      let errors = report.errors()
      if errors.length() > 0 {
        rows.push(
          @views.text(text(t, "app.compile.diagnostics"), role=Subtitle),
        )
        rows.push(@views.text(text(t, "app.compile.jump"), role=Caption))
        for diagnostic in errors {
          rows.push(diagnostic_row(diagnostic, t))
        }
      }
      let output_lines : Array[@moui.View[Msg]] = []
      if model.compile_output_open {
        let output_views : Array[@moui.View[Msg]] = []
        for line in report.output.split("\n") {
          output_views.push(
            @views.text(
              line.to_owned(),
              role=Mono,
              width=548.0,
              align=TextStart,
            ),
          )
        }
        output_lines.push(
          @views.container(
            @views.scroll_view(
              @views.column(output_views),
              width=564.0,
              height=156.0,
              shows_indicator=true,
            ),
            background=studio_console_background(),
            corner_radius=4.0,
            padding=8.0,
          ),
        )
      }
      @views.card(
        @views.column(
          [
            @views.column(rows, spacing=6.0),
            @views.row(
              [
                @views.button(
                  text(t, "app.compile.output"),
                  on_click=ToggleCompileOutput,
                  variant=Ghost,
                  width=140.0,
                ),
                @views.badge(
                  theme=studio_theme(),
                  report.output.split("\n").length().to_string(),
                  tone=@style.BadgeTone::Neutral,
                  width=48.0,
                  height=20.0,
                ),
              ],
              spacing=8.0,
              align=Center,
            ),
            @views.column(output_lines),
          ],
          spacing=6.0,
        ),
        width=600.0,
        padding=10.0,
      )
    }
  }
}

///|
/// 单条诊断行：`文件:行:列` + 错误码 + 正文；行号已知时可点击跳积木。
fn diagnostic_row(
  diagnostic : @export.CompileDiagnostic,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let location = if diagnostic.line > 0 {
    "\{short_file(diagnostic.file)}:\{diagnostic.line}:\{diagnostic.column}"
  } else {
    short_file(diagnostic.file)
  }
  let code = if diagnostic.code == "" { "" } else { "[\{diagnostic.code}] " }
  let row = @views.row(
    [
      @views.badge(
        theme=studio_theme(),
        diagnostic.severity,
        tone=if diagnostic.severity == "error" {
          @style.BadgeTone::Danger
        } else {
          @style.BadgeTone::Warning
        },
        width=72.0,
        height=20.0,
      ),
      @views.text(location, role=Mono, width=220.0),
      @views.text("\{code}\{diagnostic.text}", role=Mono, width=280.0),
    ],
    spacing=8.0,
    align=Center,
  )
  if diagnostic.line > 0 {
    row.on_tap(CompileJump(diagnostic.line))
  } else {
    ignore(t)
    row
  }
}

///|
/// 诊断里的文件路径可能很长（工作区外 bundle 路径）：只留文件名段。
fn short_file(file : String) -> String {
  let chars : Array[Char] = []
  for c in file {
    chars.push(c)
  }
  let mut slash = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '/' {
      slash = i
    }
    i = i + 1
  }
  if slash < 0 {
    file
  } else {
    let buf = StringBuilder()
    let mut j = slash + 1
    while j < chars.length() {
      buf.write_char(chars[j])
      j = j + 1
    }
    buf.to_string()
  }
}

///|
/// 编译轨头部（触发条 + 报告卡）：预览视图与运行视图共用同一入口，
/// 视图层只需要一行接线（保持 views.mbt 的行数预算）。
pub fn compiled_run_header(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  @views.column([compile_action_bar(model, t), compile_report_card(model, t)])
}
