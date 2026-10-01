///|
/// 真编译报告：`moon check` / `moon build` 的退出码 + 结构化诊断。
///
/// 为什么在这里：编译轨的「真编译」发生在工作区外的导出 bundle 里，
/// Studio 需要把工具链输出解析成 `file/line/col/code/text` 才能在代码与
/// 运行视图展示、并把行号映射回积木。解析是纯函数（native 与 wasm-gc 都能
/// 编译），真正起进程的执行器在 `services/compile_native`。
///
/// 不静默降级契约：`ok=false` 时调用方**必须**把诊断交给用户看，
/// 不允许悄悄回退解释轨。

///|
/// 单条结构化的 moon 诊断。
pub(all) struct CompileDiagnostic {
  severity : String // "error" | "warning"
  code : String // 例如 "4014"，无码时为空串
  file : String // 诊断里的文件路径（可能是绝对路径）
  line : Int // 1-based；未知为 0
  column : Int // 1-based；未知为 0
  text : String // 诊断正文（已去掉行号边框与装饰线）
}

///|
/// 真编译的一个**阶段**：工具链五步 + 落盘准备。
///
/// 为什么是枚举而不是裸字符串：阶段既驱动进度条（第几步 / 共几步），
/// 也驱动审计与 Console 文案（i18n 按 tag 查表）。裸字符串会让
/// 「加一步忘了改一处」变成静默的界面缺行。
///
/// 顺序即真实执行顺序（`compile_bundle_at` 逐个走），进度条的「已完成
/// 步数」直接取序号，不另存一份计数。
pub(all) enum CompilePhase {
  /// 清目录 + 落 bundle（`compile_project` 的准备段）
  CompilePrepare
  /// `moon update`：解析/锁定依赖
  CompileUpdate
  /// `moon check --target native`：编译诊断的第一现场
  CompileCheck
  /// `moon build --target wasm-gc`：Web 产物
  CompileWasm
  /// `moon build ./native_smoke --target native`：native 可执行产物
  CompileNative
  /// 启动 native 产物跑一遍生成 handler（可判定存活）
  CompileSmoke
  /// 收尾：收集产物、组装报告
  CompileCollect
}

///|
/// 阶段 → 稳定 tag（i18n 键尾 + 审计 detail；不随中英文变化）。
pub fn CompilePhase::tag(self : CompilePhase) -> String {
  match self {
    CompilePrepare => "prepare"
    CompileUpdate => "update"
    CompileCheck => "check"
    CompileWasm => "wasm"
    CompileNative => "native"
    CompileSmoke => "smoke"
    CompileCollect => "collect"
  }
}

///|
/// 全部阶段的规范顺序（进度条总步数的**唯一**来源）。
pub fn compile_phases() -> Array[CompilePhase] {
  [
    CompilePrepare,
    CompileUpdate,
    CompileCheck,
    CompileWasm,
    CompileNative,
    CompileSmoke,
    CompileCollect,
  ]
}

///|
/// 阶段序号（1-based）：进度读数「第 N 步 / 共 M 步」。
pub fn CompilePhase::ordinal(self : CompilePhase) -> Int {
  let mut index = 0
  for phase in compile_phases() {
    index = index + 1
    if phase.tag() == self.tag() {
      return index
    }
  }
  index
}

///|
/// 阶段总数（进度条分母）。
pub fn compile_phase_total() -> Int {
  compile_phases().length()
}

///|
/// 一次编译进度事件：worker 在**每一步开始前**推一条。
///
/// `started=true` 表示该步刚开始（进度条点亮该格），`false` 表示已结束
/// （点满）。两者都要发：只发「开始」的话，界面永远显示「正在做第 N 步」，
/// 最后一步的完成态没有落点。
pub(all) struct CompileProgress {
  phase : CompilePhase
  started : Bool
}

///|
/// 一次真编译的**产物**：构建真正落在磁盘上的文件。
///
/// 为什么必须回传：用户点「编译」要的是**二进制产物**。工具链输出里只有
/// 进度与告警，产物路径一个都不出现，于是「编译到底编出了什么、在哪」在
/// 界面上完全不可见——读起来就像「编译没编译出二进制产物」。
/// 这里把产物作为报告的一等字段回传，视图直接列出可复制/可打开的路径。
pub(all) struct CompileArtifact {
  kind : String // "native-exe" | "wasm" | "source"
  label : String // 人类可读名（"native 可执行" / "Web wasm 模块" …）
  path : String // 绝对路径
  bytes : Int // 文件大小（0 = 未知/不存在）
}

///|
/// 一次真编译的结果。
pub(all) struct CompileReport {
  ok : Bool
  exit_code : Int
  target : String // "native" | "wasm-gc"
  source_path : String // 被检查的生成源码路径（可为空）
  output : String // 原始工具链输出（视图可展开）
  diagnostics : Array[CompileDiagnostic]
  /// 构建产物（本地产物路径 + 字节数）。空数组 = 尚未产出/编译失败。
  artifacts : Array[CompileArtifact]
  /// 本次编译的工作根目录（bundle 落地处）。用户要接着跑产物就得知道它。
  work_root : String
}

///|
pub fn CompileReport::empty(target : String) -> CompileReport {
  {
    ok: true,
    exit_code: 0,
    target,
    source_path: "",
    output: "",
    diagnostics: [],
    artifacts: [],
    work_root: "",
  }
}

///|
pub fn CompileReport::errors(self : CompileReport) -> Array[CompileDiagnostic] {
  let items : Array[CompileDiagnostic] = []
  for diagnostic in self.diagnostics {
    if diagnostic.severity == "error" {
      items.push(diagnostic)
    }
  }
  items
}

///|
pub fn CompileReport::first_error(self : CompileReport) -> CompileDiagnostic? {
  for diagnostic in self.diagnostics {
    if diagnostic.severity == "error" {
      return Some(diagnostic)
    }
  }
  None
}

///|
/// 工具链输出 → 结构化诊断（纯函数，可单测）。
///
/// 识别 moon 的两类头部：
///   `Error: [4014]` / `Warning: [0002]`（无码时为 `Error:`）
///   紧随其后的 `╭─[ /abs/path/src.mbt:12:7 ]`
/// 后续正文行取到 `───╯` 之前，去掉 Unicode 边框字符。
pub fn parse_moon_diagnostics(output : String) -> Array[CompileDiagnostic] {
  let lines : Array[String] = []
  for view in output.split("\n") {
    lines.push(view.to_owned())
  }
  let diagnostics : Array[CompileDiagnostic] = []
  let mut index = 0
  while index < lines.length() {
    let header = lines[index].trim(chars=" \t")
    let severity = header_severity(header)
    if severity != "" {
      let code = header_code(header)
      let mut file = ""
      let mut line = 0
      let mut column = 0
      let mut cursor = index + 1
      // 头部与位置行之间允许隔着空行/竖线
      while cursor < lines.length() && cursor <= index + 3 {
        let probe = lines[cursor].trim(chars=" \t")
        if probe.has_prefix("╭─[") {
          match parse_location(probe) {
            Some(parsed) => {
              file = parsed.0
              line = parsed.1
              column = parsed.2
            }
            None => ()
          }
          break
        }
        cursor = cursor + 1
      }
      let text_lines : Array[String] = []
      let mut body = cursor + 1
      while body < lines.length() {
        let probe = lines[body].trim(chars=" \t")
        if probe.has_prefix("─") ||
          probe.has_prefix("Error:") ||
          probe.has_prefix("Warning:") ||
          probe.has_prefix("Failed with") {
          break
        }
        let cleaned = clean_diagnostic_line(lines[body])
        if cleaned != "" {
          text_lines.push(cleaned)
        }
        body = body + 1
      }
      // 纯摘要行（无错误码、无位置，如末尾的
      // `Error: failed to run check for target Native`）不是结构化诊断，跳过。
      if code == "" && file == "" {
        index = index + 1
        continue
      }
      diagnostics.push(CompileDiagnostic::{
        severity,
        code,
        file,
        line,
        column,
        text: join_lines(text_lines),
      })
      index = body
    } else {
      index = index + 1
    }
  }
  diagnostics
}

///|
/// `Error: [4014]` → ("error", "4014")；`Warning: [0002]` → ("warning", "0002")。
fn header_severity(header : StringView) -> String {
  if header.has_prefix("Error:") || header.has_prefix("error:") {
    "error"
  } else if header.has_prefix("Warning:") || header.has_prefix("warning:") {
    "warning"
  } else {
    ""
  }
}

///|
fn header_code(header : StringView) -> String {
  match header.find("[") {
    Some(open) =>
      match header.find("]") {
        Some(close) =>
          if close > open + 1 {
            header[open + 1:close].to_owned()
          } else {
            ""
          }
        None => ""
      }
    None => ""
  }
}

///|
/// `╭─[ /abs/src/main.mbt:12:7 ]` → (path, line, col)。
fn parse_location(probe : StringView) -> (String, Int, Int)? {
  let open = match probe.find("[") {
    Some(index) => index
    None => return None
  }
  let close = match probe.find("]") {
    Some(index) => index
    None => return None
  }
  if close <= open + 1 {
    return None
  }
  let inner = probe[open + 1:close].trim(chars=" ")
  let last_colon = match inner.rev_find(":") {
    Some(index) => index
    None => return None
  }
  let before_col = inner[:last_colon]
  let col_text = inner[last_colon + 1:]
  let second_colon = match before_col.rev_find(":") {
    Some(index) => index
    None => return None
  }
  let path = before_col[:second_colon].to_owned()
  let line_text = before_col[second_colon + 1:]
  let line = parse_decimal(line_text)
  let column = parse_decimal(col_text)
  if path.is_empty() || line == 0 {
    None
  } else {
    Some((path, line, column))
  }
}

///|
/// 十进制解析（诊断里的行列号一定是十进制；失败返回 0）。
fn parse_decimal(text : StringView) -> Int {
  if text.is_empty() {
    return 0
  }
  let mut value = 0
  let mut any_digit = false
  for c in text {
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - 0x30)
      any_digit = true
    } else {
      return 0
    }
  }
  if any_digit {
    value
  } else {
    0
  }
}

///|
/// 诊断正文行去掉边框字符与左侧行号装订线，只留可读正文。
fn clean_diagnostic_line(raw : String) -> String {
  let mut out = ""
  for c in raw {
    if c == '│' {
      out = ""
    } else if c == '╭' ||
      c == '╰' ||
      c == '├' ||
      c == '─' ||
      c == '┆' ||
      c == '▶' {
      // 装饰线跳过
    } else {
      out = out + c.to_string()
    }
  }
  out.trim(chars=" \t").to_owned()
}

///|
fn join_lines(items : Array[String]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for item in items {
    if !first {
      buf.write_string(" ")
    }
    buf.write_string(item)
    first = false
  }
  buf.to_string()
}
