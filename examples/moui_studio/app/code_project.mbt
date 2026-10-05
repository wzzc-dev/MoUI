///|
/// 代码工程生成器（M6①）：模板/教案切换时把代码真源骨架落盘——
/// form.mbt（坐标布局子集，设计器的回写目标）+ handlers.mbt（事件
/// 子程序的 MoonBit 源码，与导出 bundle 逐字节同源）。
///
/// 两份文件与内存 IR 由同一条链派生：form 腿经
/// `ir_controls_to_form_model`（form 子集边界内）+ `render_form`；
/// handlers 腿经 `generate_source`。生成物在 `code_project_files`
/// 的测试里锁「parse ∘ render == id」与函数名同源。

///|
/// 生成的两份代码真源骨架。
pub(all) struct CodeProjectFiles {
  form_mbt : String
  handlers_mbt : String
}

///|
/// IR 程序 → 代码工程骨架。函数名经 `handler_function_name` 同源：
/// form.mbt 的 `on_click=` 与 handlers.mbt 的 `fn studio_…` 指向同一实现。
pub fn code_project_files(program : @ir.StudioProgram) -> CodeProjectFiles {
  let form_model = @form_designer.ir_controls_to_form_model(
    program.window,
    program.controls,
    program.handlers,
    @export.handler_function_name,
  )
  CodeProjectFiles::{
    form_mbt: @form_designer.render_form(form_model),
    handlers_mbt: @export.generate_source(program).source,
  }
}

///|
/// 代码骨架的落点：工程第一个 `pub fn program` 包（逻辑/预览挂载点，
/// 与 form_design_rel 的探测口径一致）。无程序包 = 无处可写。
pub fn code_project_target(project : ProjectRecord) -> String? {
  match project.scanned.program_packages {
    [first, ..] => Some(first)
    [] => None
  }
}

///|
/// 代码真源文本 diff（M6②）：行级前缀/后缀裁剪——中间的删改以
/// 「- 旧行 / + 新行」成对输出。提案卡与采纳历史的 diff 都从这里来，
/// 与结构化 DiffEntry（IR 层预览用）并存：**显示层展示的是代码 diff**。
pub fn code_text_diff(
  old_source : String,
  new_source : String,
) -> Array[(String, String)] {
  let old_lines = split_nonempty_lines(old_source)
  let new_lines = split_nonempty_lines(new_source)
  let lines : Array[(String, String)] = []
  // 公共前缀
  let mut prefix = 0
  while prefix < old_lines.length() &&
    prefix < new_lines.length() &&
    old_lines[prefix] == new_lines[prefix] {
    prefix = prefix + 1
  }
  // 公共后缀（不越过前缀）
  let mut suffix = 0
  while suffix < old_lines.length() - prefix &&
    suffix < new_lines.length() - prefix &&
    old_lines[old_lines.length() - 1 - suffix] ==
    new_lines[new_lines.length() - 1 - suffix] {
    suffix = suffix + 1
  }
  let old_end = old_lines.length() - suffix
  let new_end = new_lines.length() - suffix
  let mut i = prefix
  while i < old_end {
    lines.push(("-", old_lines[i]))
    i = i + 1
  }
  let mut j = prefix
  while j < new_end {
    lines.push(("+", new_lines[j]))
    j = j + 1
  }
  lines
}

///|
fn split_nonempty_lines(source : String) -> Array[String] {
  let raw = source.split("\n")
  let lines : Array[String] = []
  for line in raw {
    let owned = line.to_owned()
    if owned != "" {
      lines.push(owned)
    }
  }
  lines
}

///|
/// 代码真源的合并文本（diff 用）：form.mbt 与 handlers.mbt 以文件界标
/// 相接——行级 diff 的输出天然带出「改在哪个文件」。
pub fn code_project_text(program : @ir.StudioProgram) -> String {
  let files = code_project_files(program)
  files.form_mbt + "=== handlers.mbt ===\n" + files.handlers_mbt
}

///|
/// 迁移结果（M6③）：解码出的 IR + 写盘目标与内容。组合根据此把
/// form.mbt/handlers.mbt 落到旧文件所在目录，一次性完成格式转换。
pub(all) struct MigrationOutcome {
  program : @ir.StudioProgram
  form_path : String
  handlers_path : String
  files : CodeProjectFiles
}

///|
/// .studio.json → form.mbt + handlers.mbt 一次性迁移器。
///
/// 解码失败不是笼统的「打开失败」：报错携带 codec 的结构化原因并
/// 指向迁移器口径（旧格式文件从此不再被当作程序真源直接加载）。
pub fn migrate_studio_source(
  dir : String,
  source : String,
) -> Result[MigrationOutcome, String] {
  match @codec.decode_program(source) {
    Err(errors) => {
      let parts : Array[String] = []
      for error in errors {
        parts.push(codec_error_label(error))
      }
      let detail = parts.join("; ")
      Err(
        "旧版 .studio.json 无法作为程序真源读取（\{detail}）——已按迁移器口径拒绝，请重新保存为 form.mbt + handlers.mbt 代码工程",
      )
    }
    Ok(program) => {
      let files = code_project_files(program)
      Ok(MigrationOutcome::{
        program,
        form_path: "\{dir}/form.mbt",
        handlers_path: "\{dir}/handlers.mbt",
        files,
      })
    }
  }
}

///|
fn codec_error_label(error : @codec.CodecError) -> String {
  match error {
    @codec.InvalidJson => "JSON 语法无效"
    @codec.BadFormat => "format 不是 moui.studio.project"
    @codec.UnsupportedVersion(v) => "版本 \{v.to_string()} 不受支持"
    @codec.MissingField(field) => "缺少字段 \{field}"
    @codec.BadControlKind(kind) => "控件种类 \{kind} 无效"
    @codec.BadEventKind(kind) => "事件 \{kind} 无效"
    @codec.BadStatement(op) => "语句 \{op} 无效"
    @codec.BadExpr(kind) => "表达式 \{kind} 无效"
    @codec.LanguageIssue(name, _) => "语言层问题 \{name}"
    @codec.Structural(_) => "结构校验未通过"
  }
}

///|
/// 打开文件的所在目录（迁移器写盘目标）。
pub fn dirname_of(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for index, c in chars {
    if c == '/' {
      last = index
    }
  }
  if last <= 0 {
    "."
  } else {
    String::from_array(chars[:last])
  }
}
