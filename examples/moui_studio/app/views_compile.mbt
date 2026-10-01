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
      // 产物段：真编译「编出了什么」的事实面。没有这一段，工具链输出里
      // 一个产物路径都不出现，用户读到的是「编译没编出二进制产物」——
      // 而产物其实一直躺在 TMPDIR 的 bundle 里。
      rows.push(
        @views.row(
          [
            @views.text(text(t, "app.compile.artifacts"), role=Subtitle),
            @views.badge(
              theme=studio_theme(),
              report.artifacts.length().to_string(),
              tone=if report.artifacts.length() > 0 {
                @style.BadgeTone::Success
              } else {
                @style.BadgeTone::Neutral
              },
              width=48.0,
              height=20.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      )
      if report.artifacts.length() == 0 {
        rows.push(
          @views.text(text(t, "app.compile.artifacts.none"), role=Caption),
        )
      } else {
        rows.push(@views.text(text(t, "app.compile.open_hint"), role=Caption))
        for artifact in report.artifacts {
          rows.push(artifact_row(artifact))
        }
      }
      if report.work_root != "" {
        rows.push(
          @views.row(
            [
              @views.text(
                text(t, "app.compile.work_root"),
                role=Caption,
                width=72.0,
              ),
              @views.text(report.work_root, role=Mono, width=496.0),
            ],
            spacing=8.0,
            align=Center,
          ),
        )
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
/// 单条产物行：类型徽标 + **绝对路径** + 字节数。
///
/// 路径宽按整卡预算算（不是写死 340）：卡宽 600、内垫 10×2、
/// 徽标 104 + 大小 88 + 两处间隙 16 ⇒ 路径拿 ~272。写死会把长路径截成
/// 半句，而「产物在哪」正是这一段存在的唯一理由——截断等于白写。
/// 路径用等宽 + TextStart：它是可复制的标识，不是居中标题。
fn artifact_row(artifact : @export.CompileArtifact) -> @moui.View[Msg] {
  let path_width = (600.0 - 20.0 - 104.0 - 88.0 - 16.0).max(120.0)
  @views.row(
    [
      @views.badge(
        theme=studio_theme(),
        artifact.label,
        tone=@style.BadgeTone::Success,
        width=104.0,
        height=20.0,
      ),
      @views.text(artifact.path, role=Mono, width=path_width, align=TextStart),
      @views.text(
        byte_size_label(artifact.bytes),
        role=Mono,
        width=88.0,
        align=TextEnd,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
/// 字节数 → 紧凑可读串（KB/MB 档；源码文件按字节直出）。
fn byte_size_label(bytes : Int) -> String {
  if bytes <= 0 {
    "—"
  } else if bytes < 1024 {
    "\{bytes} B"
  } else if bytes < 1024 * 1024 {
    "\{(bytes.to_double() / 1024.0).round().to_int()} KB"
  } else {
    "\{(bytes.to_double() / (1024.0 * 1024.0) * 10.0).round().to_int().to_double() / 10.0} MB"
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
