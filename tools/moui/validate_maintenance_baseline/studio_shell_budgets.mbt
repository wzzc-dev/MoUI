///|
/// Studio 壳收敛预算(ADR 0039):app 包 = 壳 + 组合根,四项只降不升。
///
/// 口径:`moui_studio/app` 下的 .mbt 源文件,排除 `*_test.mbt`、
/// `*wbtest.mbt`、`i18n_catalog_generated.mbt`(测试与生成物不占源码预算)。
/// Model 字段 = `pub(all) struct Model` 块内的字段行(含 `mut` 字段);
/// Msg 变体 = `pub(all) enum Msg` 块内的变体声明行(载荷可跨行,只数声明行)。
///
/// 预算只降不升:上调必须改下表并写 reason(即审计记录,见 ADR 0039 与
/// docs/plans/active/moui-studio-shell-completion.md)。
///
/// 注:上表的 `max_count` 始终绑定**当前实测值**(每次提取完成即降),它与
/// ADR 0040 的完成线分档是两件事——分档是目标,棘轮是上限,不混用。

///|
fn studio_shell_budgets() -> Array[CountBudget] {
  [
    {
      kind: "studio shell lines",
      label: "moui_studio/app",
      path: "moui_studio/app",
      // 基线冻结(2026-10-12 实测 37,279;ADR 0039 完成线 ≤ 18,000)。
      // S1 chrome 出壳(2026-10-12):theme.mbt(606)+ ide_chrome 共享原子
      // (~910,含 fit_label)迁出 moui_studio/chrome → 35,721。
      // S2a 工程域出壳(2026-10-12):行模型/纯工具/工程类型迁
      // plugins/project(壳留包装),app 35,721 → 35,034。
      // S2b-1 状态切片(2026-10-12):17 字段并入 ProjectState → 35,251;S2b-2 子消息臂迁出 → 34865
      // 壳卫生清理(2026-10-12):删 2 个切片后遗留的未用包装
      // (section_collapsed / collapse_all_tree_keys) → 33,535。
      // S5 blocks 捆绑出壳(2026-10-12):blocks_slot_hit 全文 + blocks_canvas 的
      // 15 个纯几何函数 + BlocksDrawOp + BlocksDragState + 2 常量 + row_arrow
      // 迁 plugins/blocks(1,054 行);壳侧 blocks_pane.mbt 收画布视图函数
      // → 32,481。
      // 右栏 VS Code 侧栏分页(2026-10-13):检查器页与 AI 页分开,新增页块
      // 切换器 / 对象条 / 圆角输入卡;同时把子页签条、对象条、页切换头三个
      // **通用**原子搬进 chrome(无预算)——净 32,481 → 32,341。
      // 同日真机复查三轮修了四个缺陷(转录宽与裁剪区不同源导致文字被切、
      // diff 长行不截断、卡标题不吃徽标宽、恢复会话残留 in-flight 卡) →
      // 32,341 → 32,421;仍在 S5 之后的下降通道内,低于本轮起点 32,480。
      max_count: 32421,
    },
    {
      kind: "studio shell files",
      label: "moui_studio/app",
      path: "moui_studio/app",
      // 基线冻结(2026-10-12 实测 53;完成线 ≤ 30)。
      // S1 chrome 出壳:theme.mbt 整文件迁出 → 52。
      // 壳卫生清理(2026-10-12):仅删函数不动文件 → 51。
      // S5 blocks 捆绑出壳(2026-10-12):blocks_canvas.mbt(视图函数并入
      // blocks_pane.mbt)与 blocks_slot_hit.mbt(整文件迁插件)两个文件消失 → 49。
      max_count: 49,
    },
    {
      kind: "studio model fields",
      label: "moui_studio/app/model.mbt",
      path: "moui_studio/app/model.mbt",
      // 基线冻结(2026-10-12 实测 161,含 6 个 mut 字段;完成线 ≤ 55)。
      // S2b-1 工程域状态切片(2026-10-12):17 个工程/资源管理器字段并入
      // plugins/project 的 ProjectState(壳持单一 project_state 字段)→ 145。
      max_count: 145,
    },
    {
      kind: "studio msg variants",
      label: "moui_studio/app/model.mbt",
      path: "moui_studio/app/model.mbt",
      // 基线冻结(2026-10-12 实测 291;完成线 ≤ 90)。
      // S2b-2 工程域子消息(2026-10-12):14 个纯态臂迁 plugins/project
      // 的 ProjectMsg,壳持单一 ProjectOp 委托臂 → 278。
      max_count: 278,
    },
  ]
}

///|
/// 源文件口径:排除测试与 i18n 生成物(它们由各自机制独立治理——
/// source-file-policy 的 generated 清单与测试自身的预算)。
fn studio_shell_source_file(path : String) -> Bool {
  !path.has_suffix("_test.mbt") &&
  !path.has_suffix("wbtest.mbt") &&
  !path.has_suffix("i18n_catalog_generated.mbt")
}

///|
fn collect_studio_shell_files(
  repo_root : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let all : Array[String] = []
  collect_mbt_files(repo_root, "moui_studio/app", all, failures)
  for path in all {
    if studio_shell_source_file(path) {
      files.push(path)
    }
  }
}

///|
/// `String[index]` 的返回类型是 UTF-16 码元(UInt16);与 Char 字面量的
/// 比较(如 `>= 'a'`)是合法的,这里保持同一形态。
fn studio_shell_is_ascii_ident_char(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// Model 字段行:恰两空格缩进 + 可选 `mut ` + 小写/下划线开头的标识符 +
/// 空白 + `:`。更深缩进(载荷续行)与注释行天然不匹配。
fn studio_shell_is_model_field_line(line : String) -> Bool {
  if line.length() < 3 || line[0] != ' ' || line[1] != ' ' || line[2] == ' ' {
    return false
  }
  let mut pos = 2
  if line.has_prefix("  mut ") {
    pos = 6
  }
  if pos >= line.length() {
    return false
  }
  let lead = line[pos]
  if !((lead >= 'a' && lead <= 'z') || lead == '_') {
    return false
  }
  while pos < line.length() && studio_shell_is_ascii_ident_char(line[pos]) {
    pos += 1
  }
  while pos < line.length() && line[pos] == ' ' {
    pos += 1
  }
  pos < line.length() && line[pos] == ':'
}

///|
/// Msg 变体声明行:恰两空格缩进 + 大写开头标识符,其后是行尾、载荷 `(`、
/// 空白(注释前)或 `/`(行注释)。载荷跨行续行的缩进更深,不匹配。
fn studio_shell_is_msg_variant_line(line : String) -> Bool {
  if line.length() < 3 || line[0] != ' ' || line[1] != ' ' || line[2] == ' ' {
    return false
  }
  let lead = line[2]
  if !(lead >= 'A' && lead <= 'Z') {
    return false
  }
  let mut pos = 2
  while pos < line.length() && studio_shell_is_ascii_ident_char(line[pos]) {
    pos += 1
  }
  if pos >= line.length() {
    return true
  }
  let c = line[pos]
  c == '(' || c == ' ' || c == '/'
}

///|
/// 取 `decl` 声明行之后、配对 `}` 之前的所有行。找不到声明返回 None
/// (由调用方记 failure,不让预算静默通过)。
fn studio_shell_decl_span_lines(text : String, decl : String) -> Array[String]? {
  let mut inside = false
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if !inside {
      if line == decl {
        inside = true
      }
    } else if line == "}" {
      return Some(lines)
    } else {
      lines.push(line)
    }
  }
  if inside {
    // 无配对右括号:按文件尾处理(计数继续),语法问题由 moon check 兜底。
    Some(lines)
  } else {
    None
  }
}

///|
fn count_studio_shell_decl(
  repo_root : String,
  path : String,
  decl : String,
  is_member : (String) -> Bool,
  failures : Array[String],
) -> Int {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match studio_shell_decl_span_lines(text, decl) {
        Some(lines) => {
          let mut count = 0
          for line in lines {
            if is_member(line) {
              count += 1
            }
          }
          count
        }
        None => {
          failures.push(
            "studio shell budget could not find decl: " + decl + " in " + path,
          )
          0
        }
      }
    Err(message) => {
      failures.push(message)
      0
    }
  }
}

///|
fn collect_studio_shell_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[CountBudgetOverflow] {
  let overflows : Array[CountBudgetOverflow] = []
  let source_files : Array[String] = []
  collect_studio_shell_files(repo_root, source_files, failures)
  let mut source_lines = 0
  for path in source_files {
    match read_repo_text(repo_root, path) {
      Ok(text) => source_lines += line_count(text)
      Err(message) => failures.push(message)
    }
  }
  let model_fields = count_studio_shell_decl(
    repo_root, "moui_studio/app/model.mbt", "pub(all) struct Model {", studio_shell_is_model_field_line,
    failures,
  )
  let msg_variants = count_studio_shell_decl(
    repo_root, "moui_studio/app/model.mbt", "pub(all) enum Msg {", studio_shell_is_msg_variant_line,
    failures,
  )
  for budget in studio_shell_budgets() {
    let count = if budget.kind == "studio shell lines" {
      source_lines
    } else if budget.kind == "studio shell files" {
      source_files.length()
    } else if budget.kind == "studio model fields" {
      model_fields
    } else {
      msg_variants
    }
    record_count_budget_overflow(budget, count, overflows)
  }
  overflows
}
