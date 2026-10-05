///|
/// moon.pkg 清单解析。
///
/// 与 moon.mod 同族但有三点差异:① 导入分**三轨**(默认 / `for "test"` /
/// `for "wbtest"`);② 无 name 等必填键;③ 有 `supported_targets` 与
/// `options(...)`。真实样例:`examples/counter/app/moon.pkg`、
/// `examples/moui_studio/app/moon.pkg`(含 `"wzzc-dev/moui_i18n" @i18n` 别名)。
///
/// rel_path 由调用方传入(包目录相对模块根,根包为 ""),报错信息带它——
/// 「哪个包的 moon.pkg 坏了」是资源管理器必须能回答的问题。

///|
/// 包级导入条目(模块内路径或外部模块路径;无版本段)。
pub(all) struct PackageImport {
  path : String
  alias_name : String
}

///|
pub(all) struct PackageManifest {
  rel_path : String
  imports : Array[PackageImport]
  test_imports : Array[PackageImport]
  wbtest_imports : Array[PackageImport]
  supported_targets : String
}

///|
pub fn parse_package_manifest(
  rel_path~ : String,
  source : String,
) -> Result[PackageManifest, String] {
  let file = if rel_path == "" { "moon.pkg" } else { "\{rel_path}/moon.pkg" }
  let imports : Array[PackageImport] = []
  let test_imports : Array[PackageImport] = []
  let wbtest_imports : Array[PackageImport] = []
  let mut supported = ""
  let mut in_import = false
  // 当前块的收集缓冲:桶(`for "test"` 子句)在**块闭合处**才揭晓,
  // 所以先收集、闭合时按子句入桶。
  let mut pending : Array[ImportEntry] = []
  let mut paren_depth = 0
  let mut line_no = 0
  for view in source.split("\n") {
    line_no = line_no + 1
    let text = strip_comment(view.to_owned()).trim(chars=" \t\r").to_owned()
    if text == "" {
      continue
    }
    if paren_depth > 0 {
      paren_depth = paren_depth + paren_delta(text)
      continue
    }
    if in_import {
      if text.has_prefix("}") {
        in_import = false
        // 尾文从 `}` 之后开始:`} for "test"` 的子句在闭括号后面
        push_entries(
          pending,
          text[1:].to_owned(),
          imports,
          test_imports,
          wbtest_imports,
        )
        pending = []
        continue
      }
      match parse_import_line(text, file, line_no) {
        Ok(entries) =>
          for entry in entries {
            pending.push(entry)
          }
        Err(msg) => return Err(msg)
      }
      continue
    }
    if text.has_prefix("options") && text.contains("(") {
      paren_depth = paren_delta(text)
      continue
    }
    if text.has_prefix("import") && text.contains("{") {
      let open = index_of_char(text, '{', 0)
      let close = index_of_char(text, '}', open + 1)
      if close > open {
        let inner = text[open + 1:close].to_owned()
        match parse_import_line(inner, file, line_no) {
          Ok(entries) => {
            let buffer : Array[ImportEntry] = []
            for entry in entries {
              buffer.push(entry)
            }
            push_entries(
              buffer,
              text[close + 1:].to_owned(),
              imports,
              test_imports,
              wbtest_imports,
            )
          }
          Err(msg) => return Err(msg)
        }
      } else {
        in_import = true
      }
      continue
    }
    match parse_key_value(text) {
      Some((key, value)) => if key == "supported_targets" { supported = value }
      None => ()
    }
  }
  if in_import {
    return Err("\{file}:import 块未闭合(文件在块中间结束)")
  }
  Ok(PackageManifest::{
    rel_path,
    imports,
    test_imports,
    wbtest_imports,
    supported_targets: supported,
  })
}

///|
/// 把收集完的条目按 `for` 子句入桶。`tail` 是块闭合 `}` **之后**的余文
/// (多行块的 `} for "test"` 行尾、单行块的 `} for "test"` 后缀)。
fn push_entries(
  entries : Array[ImportEntry],
  tail : String,
  imports : Array[PackageImport],
  test_imports : Array[PackageImport],
  wbtest_imports : Array[PackageImport],
) -> Unit {
  let bucket = trailing_for_clause(tail)
  let target = match bucket {
    "test" => test_imports
    "wbtest" => wbtest_imports
    _ => imports
  }
  for entry in entries {
    target.push(PackageImport::{
      path: entry.path,
      alias_name: entry.alias_name,
    })
  }
}
