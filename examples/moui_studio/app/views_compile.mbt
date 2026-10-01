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
    return compile_progress_card(model, t)
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
          rows.push(artifact_row(artifact, t))
        }
      }
      if report.work_root != "" {
        // 工作目录同样给完整读数（中间省略，与产物行同一把尺子）——它是
        // 「接着去哪找」的第二个入口，截一半同样等于没给。
        rows.push(
          @views.row(
            [
              @views.text(
                text(t, "app.compile.work_root"),
                role=Caption,
                width=72.0,
              ),
              @views.text(
                middle_ellipsis(report.work_root, 480.0),
                role=Mono,
                width=480.0,
                align=TextStart,
              ),
              ghost_icon_button(
                Clipboard,
                text(t, "app.compile.artifact.copy"),
                false,
                CopyArtifactPath(report.work_root),
                28.0,
                22.0,
                13.0,
                ide_elevated(),
              ),
              ghost_icon_button(
                FolderOpen,
                text(t, "app.compile.artifact.reveal"),
                false,
                RevealArtifact(report.work_root),
                28.0,
                22.0,
                13.0,
                ide_elevated(),
              ),
            ],
            spacing=6.0,
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
/// 编译进度卡：忙态下代替报告卡（两个读数不同时在场）。
///
/// 为什么要它：真编译要跑 `moon update/check/build ×2` + 产物自检，实测
/// 十几秒。旧版忙态只显示一个静态「正在真编译…」徽标——用户读到的现象是
/// 「点了编译之后什么都没发生（或者卡住了）」。这里把七个**真实步骤**逐格
/// 画出来：已完成的点满、进行中的高亮、未开始的暗色。
///
/// 步骤列表来自 `@export.compile_phases()`（与 worker 推进度用同一张表），
/// 因此界面永远不会出现「多画一格 / 少画一格」。
fn compile_progress_card(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let (done, total) = compile_progress_counts(model.compile_progress)
  let active = compile_active_phase(model.compile_progress)
  let steps : Array[@moui.View[Msg]] = []
  for phase in @export.compile_phases() {
    steps.push(compile_step_row(phase, model.compile_progress, t))
  }
  // 当前读数：进行中显式点名（比只点亮一格更好读——用户能读到「正在做什么」）
  let status = match active {
    Some(phase) => text(t, "app.compile.phase.\{phase.tag()}")
    None => text(t, "app.compile.running")
  }
  @views.card(
    @views.column(
      [
        @views.row(
          [
            @views.badge(
              theme=studio_theme(),
              text_with(t, "app.compile.step", [
                ("done", done.to_string()),
                ("total", total.to_string()),
              ]),
              tone=@style.BadgeTone::Warning,
              width=140.0,
              height=24.0,
            ),
            @views.text(status, role=Subtitle),
          ],
          spacing=8.0,
          align=Center,
        ),
        @views.column(steps, spacing=4.0),
        @views.text(text(t, "app.track.compile_note"), role=Caption),
      ],
      spacing=8.0,
    ),
    width=600.0,
    padding=10.0,
  )
}

///|
/// 进度里的一步：状态点（完成/进行中/未开始）+ 步骤名 + 状态字。
fn compile_step_row(
  phase : @export.CompilePhase,
  progress : Array[@export.CompileProgress],
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let (dot_color, label_color, state_text) = match
    compile_step_state(progress, phase) {
    Some(false) => (ide_success(), ide_text(), text(t, "app.compile.step_done"))
    Some(true) => (ide_accent(), ide_text(), text(t, "app.compile.step_active"))
    None => (ide_border(), ide_text_faint(), "")
  }
  @views.row(
    [
      @views.container(
        @views.text("", width=1.0, height=1.0),
        background=dot_color,
        corner_radius=4.0,
        width=8.0,
        height=8.0,
        padding=0.0,
      ),
      @views.text(
        text(t, "app.compile.phase.\{phase.tag()}"),
        theme=studio_theme(),
        width=380.0,
        height=18.0,
        align=TextStart,
      ).foreground(label_color),
      @views.text(
        state_text,
        theme=studio_theme(),
        width=80.0,
        height=18.0,
        align=TextEnd,
      ).foreground(
        if dot_color == ide_success() {
          ide_success()
        } else {
          ide_accent()
        },
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
/// 单条产物行：类型徽标 + **完整路径** + 字节数 + 动作。
///
/// 四个历史缺陷都在这一行里：
/// 1. **路径显示不全**：core 的 `Text` 把声明宽度当**最小值**，实测宽于
///    声明时盒子会长出去被父容器裁掉——于是 `/var/folders/…/moui-studio-`
///    这样从中间硬切。修法是主动做**中间省略**（保头保尾，`…` 居中），
///    让它在声明宽度内本来就放得下：首尾两段才是「哪个盘、哪个文件」的
///    识别信息，中段（那串随机 TMPDIR）删掉最不伤读。
/// 2. **没有复制入口**：路径写在界面里却选不中、复制不了，用户只能照着
///    抄——一个字的错就找不到文件。给「复制路径」按钮。
/// 3. **没有打开入口**：给「在文件夹中打开」（把产物所在目录交给系统
///    文件管理器）。
/// 4. **GUI 应用与无头探针分不清**：旧版把 `native_smoke`（打印标记就退出
///    的无头探针）标成「native 可执行」，用户运行后没有任何窗口。现在
///    GUI 应用用强调色徽标 + **运行产物**按钮（直接启动它），无头探针用
///    中性徽标并写明「不开窗」。
///
/// 路径单独占一行（整卡宽），动作与字节数在下一行：路径本身常 80–110
/// 字符，和徽章/按钮挤一行必然要截断——那正是问题 2 的成因。
fn artifact_row(
  artifact : @export.CompileArtifact,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  // 卡宽 600 − 内垫 10×2 = 580 可用；路径整行吃满。
  let path_width = 580.0
  // GUI 应用 = 用户真正要跑的东西：强调色徽标 + 多一个「运行产物」。
  let is_gui = artifact.kind == "native-app"
  let badge_label = if is_gui {
    text(t, "app.compile.artifact.gui")
  } else if artifact.kind == "native-smoke" {
    text(t, "app.compile.artifact.headless")
  } else {
    artifact.label
  }
  let badge_width = if is_gui || artifact.kind == "native-smoke" {
    132.0
  } else {
    104.0
  }
  let actions : Array[@moui.View[Msg]] = []
  if is_gui {
    // 「运行产物」= **一键启动**：直接起进程开窗，不再要求用户先去文件夹里
    // 自己双击。启动是脱离式的（见 services/launch_native）——进程 reparent
    // 到系统 init，Studio 退出/被关掉都不会带走正在用的导出应用。
    // 用**带文字的按钮**而不是图标：它是这一行唯一的主行动作，值得占宽度。
    actions.push(
      @views.button(
        text(t, "app.compile.run_artifact"),
        on_click=RunArtifact(artifact.path),
        variant=Primary,
        width=104.0,
        height=22.0,
      ),
    )
  }
  actions.push(
    ghost_icon_button(
      Clipboard,
      text(t, "app.compile.artifact.copy"),
      false,
      CopyArtifactPath(artifact.path),
      28.0,
      22.0,
      13.0,
      ide_elevated(),
    ),
  )
  actions.push(
    ghost_icon_button(
      FolderOpen,
      text(t, "app.compile.artifact.reveal"),
      false,
      RevealArtifact(artifact.path),
      28.0,
      22.0,
      13.0,
      ide_elevated(),
    ),
  )
  @views.column(
    [
      @views.row(
        [
          @views.badge(
            theme=studio_theme(),
            badge_label,
            tone=if is_gui {
              @style.BadgeTone::Success
            } else if artifact.kind == "native-smoke" {
              @style.BadgeTone::Neutral
            } else {
              @style.BadgeTone::Success
            },
            width=badge_width,
            height=20.0,
          ),
          @views.text(
            middle_ellipsis(artifact.path, path_width - 8.0 - badge_width),
            role=Mono,
            width=path_width - 8.0 - badge_width,
            height=20.0,
            align=TextStart,
          ),
        ],
        spacing=8.0,
        align=Center,
      ),
      @views.row(
        // 动作行：字节数靠左，动作靠右。数组直接拼装（`@views.row` 收
        // 数组），这样「GUI 多一颗运行按钮」不必复制两套收尾代码。
        {
          let cells : Array[@moui.View[Msg]] = [
            @views.text(
              byte_size_label(artifact.bytes),
              role=Mono,
              width=72.0,
              height=18.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            @views.spacer(min_length=4.0, weight=1.0),
          ]
          for action in actions {
            cells.push(action)
          }
          cells
        },
        spacing=4.0,
        align=Center,
      ),
    ],
    spacing=2.0,
  )
}

///|
/// 中间省略：保头保尾，中段折叠成 `…`。
///
/// **为什么不是尾部省略**：产物路径的信息分布是「头（哪个卷）+ 尾（哪个
/// 文件）」，中段是 TMPDIR 那一长串随机目录名。尾部省略会把最关键的
/// 文件名切掉，留下最没信息量的随机串——正好读反。
///
/// 宽度口径走 `text_estimate_width`（ASCII 7.9 / 全角 13.0），与壳里
/// 其他「按文字实测算宽」的地方同一把尺子。
pub fn middle_ellipsis(label : String, max_width : Double) -> String {
  if text_estimate_width(label) <= max_width {
    return label
  }
  let chars : Array[Char] = []
  for c in label {
    chars.push(c)
  }
  let ellipsis_cost = text_estimate_width("…")
  // 预算连省略号都放不下时输出空串：这是唯一不撒谎的读数（「这里什么都
  // 显示不了」比硬塞一个必然被裁的串诚实）。
  if max_width < ellipsis_cost {
    return ""
  }
  let budget = max_width - ellipsis_cost
  // 两侧**交替**取字符，因此 head 与 tail 的宽度天然接近——避免预算偏紧
  // 时一侧把另一侧挤成 0（那样剩下的是纯前缀，又退化成尾部省略的反面）。
  let mut head = 0
  let mut tail = 0
  let mut used = 0.0
  let mut take_head = true
  while head + tail < chars.length() {
    let index = if take_head { head } else { chars.length() - 1 - tail }
    let cost = if chars[index].to_int() < 0x80 { 7.9 } else { 13.0 }
    if used + cost > budget {
      break
    }
    used = used + cost
    if take_head {
      head = head + 1
    } else {
      tail = tail + 1
    }
    take_head = !take_head
  }
  // 头段正序 + `…` + 尾段正序（尾段从 `chars.length() - tail` 起**顺序**
  // 写出：逐字符从末尾倒着追加会把文件名写成镜像串）。
  let buf = StringBuilder()
  let mut i = 0
  while i < head {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.write_string("…")
  let mut j = chars.length() - tail
  while j < chars.length() {
    buf.write_char(chars[j])
    j = j + 1
  }
  buf.to_string()
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
