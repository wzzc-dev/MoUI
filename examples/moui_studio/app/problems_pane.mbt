///|
/// 问题面板（底栏第三页签）：把分散的诊断收进一张表——
/// 各子程序的语法问题（逐 handler 解析，带行号归属，可点击跳转）、
/// 全程序语言级校验问题、以及当前草稿未提交的实时诊断。
///
/// 成本说明：`problem_rows` 每次调用会对每个 handler 渲染 + 解析一遍。
/// 教学规模（≤64 个 handler、每个 ≤512 语句）下单次微秒级，且只在
/// 底栏绘制时发生；若未来程序规模上探，再引入脏标记缓存。

///|
/// 问题行：`handler_key` 以 "build:" / "compile:" 开头时是工具链诊断
/// （`file` 非空，GotoProblem 跳资源管理器定位文件）；否则是程序内
/// 诊断（跳积木/代码草稿）。
pub(all) struct ProblemRow {
  handler_key : String
  label : String
  message : String
  line : Int
  /// 工具链诊断的文件路径(程序内诊断为空串)
  file : String
}

///|
/// 汇总当前全部问题。
pub fn problem_rows(model : Model, t : @i18n.Translator) -> Array[ProblemRow] {
  let rows : Array[ProblemRow] = []
  let language = model.language.dsl_language()
  // 已提交 IR：逐 handler 解析（渲染 → 解析同代码视图同一通道），
  // 这样每条问题都有 handler 归属与行号，可跳转。
  for handler in model.program.handlers {
    let source = @studio_lang.render_handler(handler, language)
    match @studio_lang.check_syntax(source, language) {
      None => ()
      Some(error) =>
        rows.push(ProblemRow::{
          handler_key: handler_key(handler.control_name, handler.event.tag()),
          label: handler.control_name,
          message: error_message(t, error),
          line: error.line(),
          file: "",
        })
    }
  }
  // 全程序语言级校验（保留字/未声明/往返一致性——无行号归属）
  for error in @studio_lang.validate_program_language(model.program) {
    rows.push(ProblemRow::{
      handler_key: "",
      label: text(t, "app.problems.program"),
      message: error_message(t, error),
      line: 0,
      file: "",
    })
  }
  // 工具链诊断合流(M0-7):构建服务报告 + 真编译报告,统一进一张表。
  // label = 诊断文件路径(file 非空 → GotoProblem 跳资源管理器定位)。
  for report in build_reports(model) {
    for diagnostic in report.diagnostics {
      rows.push(ProblemRow::{
        handler_key: "build:" + diagnostic.file,
        label: text(t, "app.problems.build"),
        message: diagnostic.text,
        line: diagnostic.line,
        file: diagnostic.file,
      })
    }
  }
  // 当前草稿的实时诊断（未提交；行号可跳）
  if model.code_error != "" {
    for diagnostic in model.code_diagnostics {
      rows.push(ProblemRow::{
        handler_key: model.selected_handler,
        label: text(t, "app.problems.draft"),
        message: diagnostic.message,
        line: line_of_offset(model.code_draft, diagnostic.range.start),
        file: "",
      })
    }
  }
  rows
}

///|
/// 偏移 → 1 起行号（越界归 1）。
fn line_of_offset(source : String, offset : Int) -> Int {
  let mut line = 1
  let mut index = 0
  for c in source {
    if index >= offset {
      break
    }
    if c == '\n' {
      line = line + 1
    }
    index = index + 1
  }
  line
}

///|
/// 问题面板主体。
pub fn problems_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let rows = problem_rows(model, t)
  if rows.is_empty() {
    return @views.container(
      @views.center(
        @views.text(
          text(t, "app.problems.empty"),
          theme=studio_theme(),
          width=(width - 40.0).max(80.0),
          height=20.0,
        ).foreground(ide_text_faint()),
        width~,
        height~,
      ),
      background=ide_panel(),
      width~,
      height~,
      padding=0.0,
    )
  }
  let cells : Array[@moui.View[Msg]] = []
  for row in rows {
    let jumpable = row.handler_key != "" && row.line > 0
    let row_cells : Array[@moui.View[Msg]] = [
      @views.container(
        @views.text("", width=1.0, height=1.0),
        background=ide_danger(),
        corner_radius=2.0,
        width=6.0,
        height=6.0,
        padding=0.0,
      ),
      @views.text(
        row.label,
        theme=studio_theme(),
        width=(text_estimate_width(row.label) * 1.02 + 8.0).min(120.0),
        height=18.0,
        align=TextStart,
      ).foreground(ide_text_muted()),
      @views.text(
        row.message,
        theme=studio_theme(),
        width=(width - 150.0).max(120.0),
        height=18.0,
        align=TextStart,
      ).foreground(ide_text()),
    ]
    if row.line > 0 {
      row_cells.push(
        @views.text(
          text_with(t, "err.line", [("line", "\{row.line}")]),
          theme=studio_theme(),
          role=Mono,
          width=76.0,
          height=18.0,
          align=TextEnd,
        ).foreground(ide_text_faint()),
      )
    }
    let action = if jumpable {
      GotoProblem(row.handler_key, row.line)
    } else {
      SetBottomTab(BtProblems)
    }
    cells.push(
      @views.container(
        @views.padding_edges(
          @views.row(row_cells, spacing=6.0, align=Center).frame(
            width=(width - 20.0).max(120.0),
          ),
          left=8.0,
          right=8.0,
        ),
        background=ide_panel(),
        height=26.0,
        width~,
        padding=0.0,
      )
      .accessibility_label(row.label + " " + row.message)
      .on_tap(action),
    )
  }
  @views.scroll_view(
    @views.column(cells, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 参与问题合流的工具链报告(最近的在前):构建服务报告 + 真编译报告。
fn build_reports(model : Model) -> Array[@export.CompileReport] {
  let reports : Array[@export.CompileReport] = []
  match model.last_build {
    Some(report) =>
      reports.push(@export.CompileReport::{
        ok: report.ok,
        exit_code: report.exit_code,
        target: report.kind.tag(),
        source_path: "",
        output: report.output,
        diagnostics: report.diagnostics,
        artifacts: [],
        work_root: "",
      })
    None => ()
  }
  match model.compile_report {
    Some(report) => reports.push(report)
    None => ()
  }
  reports
}
