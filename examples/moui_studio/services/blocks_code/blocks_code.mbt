///|
/// 积木可编辑 MoonBit 子集(M5-5a):子集契约 + 逆解析。
///
/// 生成形状(`moonbit_codegen`)定义了积木可编辑 MoonBit 的封闭语法:
/// 每个 IR 语句生成一组以 `rt.audit_assign(...)` / `rt.record(...)` 为
/// 首的调用行,行内最后一个字符串字面量是**规范文本**(`canonical_expr`
/// 渲染),解析端用 `@studio_lang.parse_handler_body` / `parse_expression_text`
/// 从规范文本重建语句。子集契约 = `parse∘gen == id`(逐字段相等)。
///
/// 子集外检测:生成形状之外的行(注释/空行/分派表/harness)不可积木。

///|
/// 一个可积木语句的解析产物:
/// - `path`:IR 语句路径(与 stmt_lines 同源)
/// - `canonical`:规范文本(可重解析为语句)
/// - `start_line` / `end_line`:生成源码中的行范围(1-based)
/// - `editable`:子集内可编辑
pub(all) struct HandlerBlock {
  path : Array[Int]
  canonical : String
  start_line : Int
  end_line : Int
  editable : Bool
}

///|
/// 逆解析产物:一段生成源码的全部可积木语句。
pub(all) struct ParsedHandlerSource {
  blocks : Array[HandlerBlock]
  /// 子集外(不可积木)的行号列表(诚实报告)
  non_editable_lines : Array[Int]
}

///|
pub fn ParsedHandlerSource::blocks(
  self : ParsedHandlerSource,
) -> Array[HandlerBlock] {
  self.blocks
}

///|
pub fn ParsedHandlerSource::non_editable_lines(
  self : ParsedHandlerSource,
) -> Array[Int] {
  self.non_editable_lines
}

///|
/// 哨兵:audit_assign 调用的前缀(生成器确定性,封闭集)。
const AUDIT_ASSIGN_PREFIX : String = "rt.audit_assign("

///|
/// 哨兵:record 调用的前缀。
const RECORD_PREFIX : String = "rt.record("

///|
const DISPATCH_AUDIT_MARK : String = "@compiled_runtime.OpCondition"

///|
/// 从生成源码提取可积木语句(逆解析)。
///
/// 策略:逐行扫描 `rt.audit_assign(...)` / `rt.record(...)` 行,提取行内
/// 最后一个字符串字面量(规范文本),与 `stmt_lines` 的 path/line 对齐。
/// 不匹配已知模式的行记入 non_editable_lines。
pub fn parse_generated_source(
  source : String,
  stmt_lines : Array[@export.StmtLine],
) -> ParsedHandlerSource {
  let lines = source.split("\n")
  let blocks : Array[HandlerBlock] = []
  let non_editable : Array[Int] = []
  let mut line_no = 0
  for view in lines {
    line_no = line_no + 1
    let line = view.to_owned()
    // 判据:生成器的封闭形状中,**有字符串字面量的代码行**都携带审计
    // 规范文本;无字面量的行是结构性的(条件表达式、花括号、变量赋值)。
    // 这比逐个枚举方法名更稳健——moonbit_codegen 增加新的 rt 方法时
    // 无需同步此解析器。
    let has_string = extract_last_string_literal(line) is Some(_)
    let is_code = line.trim(chars=" \t\r") != "" &&
      !line.has_prefix("//") &&
      !line.has_prefix("pub ") &&
      !line.has_prefix("fn ")
    // 匹配分派的审计行(M5-5d)带字符串字面量但不是语句——它的
    // 「canonical」是拼接表达式，不能当积木文本。诚实记为不可积木。
    let is_dispatch_audit = line.contains(DISPATCH_AUDIT_MARK)
    if is_code && is_dispatch_audit {
      non_editable.push(line_no)
    } else if is_code && has_string {
      let canonical = match extract_last_string_literal(line) {
        Some(text) => text
        None => ""
      }
      let mut path : Array[Int] = []
      for entry in stmt_lines {
        if entry.audit_line == line_no {
          path = entry.path
          break
        }
      }
      blocks.push(HandlerBlock::{
        path,
        canonical,
        start_line: line_no,
        end_line: line_no,
        editable: true,
      })
    }
  }
  { blocks, non_editable_lines: non_editable, }
}

///|
/// 从一行中提取最后一个字符串字面量的内容(引号感知,处理 \" 转义)。
fn extract_last_string_literal(line : String) -> String? {
  let chars : Array[Char] = []
  for c in line {
    chars.push(c)
  }
  let n = chars.length()
  let mut result : String? = None
  let mut i = 0
  while i < n {
    if chars[i] == '"' {
      // 读字符串
      let mut content = ""
      let mut j = i + 1
      let mut escaped = false
      let mut closed = false
      while j < n {
        let c = chars[j]
        if escaped {
          content = content + c.to_string()
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == '"' {
          closed = true
          break
        } else {
          content = content + c.to_string()
        }
        j = j + 1
      }
      if closed {
        result = Some(content)
        i = j + 1
      } else {
        i = j
      }
    } else {
      i = i + 1
    }
  }
  result
}

///|
/// 检测一行生成代码是否匹配已知的积木子集模式。
pub fn is_block_editable_line(line : String) -> Bool {
  line.contains(AUDIT_ASSIGN_PREFIX) ||
  (line.contains(RECORD_PREFIX) && !line.contains(DISPATCH_AUDIT_MARK)) ||
  line.contains("rt.require_declared(") ||
  line.contains("let existing_") ||
  line.contains("@compiled_runtime.set_index_values(") ||
  line.contains("if condition_") ||
  line.contains("} else if condition_") ||
  line.contains("} else {") ||
  line.contains("for ") ||
  line.contains("while ") ||
  line.trim(chars=" \t\r") == "break"
}
