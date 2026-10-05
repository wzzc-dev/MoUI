///|
/// moon.mod 清单解析。
///
/// 工程工作台只需要子集:name / version / preferred_target / 模块级依赖。
/// 真实样例:`examples/counter/moon.mod`(key=value + 多行 import 块,
/// 条目 `"wzzc-dev/moui@0.2.0"`)。未知构造按行跳过;name 缺失或
/// import 块未闭合才报错——资源管理器对畸形工程要给出**结构化**拒绝,
/// 而不是静默读出空工程。

///|
/// 模块级依赖条目。version 来自路径内 `@版本`(模块路径本身不含 @);
/// alias_name 来自条目尾部的 `@别名`。
pub(all) struct ModuleImport {
  path : String
  version : String
  alias_name : String
}

///|
pub(all) struct ModuleManifest {
  name : String
  version : String
  preferred_target : String
  imports : Array[ModuleImport]
}

///|
pub fn parse_module_manifest(source : String) -> Result[ModuleManifest, String] {
  let mut name = ""
  let mut version = ""
  let mut preferred = ""
  let imports : Array[ModuleImport] = []
  let mut in_import = false
  // options(...) 可能跨行:深度 > 0 时整行跳过
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
        // 模块级导入不分轨;`} for "..."` 子句容错忽略
        in_import = false
        continue
      }
      match parse_import_line(text, "moon.mod", line_no) {
        Ok(entries) =>
          for entry in entries {
            imports.push(ModuleImport::{
              path: entry.path,
              version: entry.version,
              alias_name: entry.alias_name,
            })
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
      // 单行块 `import { "a", "b" }`:解析花括号之间后即闭合
      let open = index_of_char(text, '{', 0)
      let close = index_of_char(text, '}', open + 1)
      if close > open {
        let inner = text[open + 1:close].to_owned()
        match parse_import_line(inner, "moon.mod", line_no) {
          Ok(entries) =>
            for entry in entries {
              imports.push(ModuleImport::{
                path: entry.path,
                version: entry.version,
                alias_name: entry.alias_name,
              })
            }
          Err(msg) => return Err(msg)
        }
      } else {
        in_import = true
      }
      continue
    }
    match parse_key_value(text) {
      Some((key, value)) =>
        match key {
          "name" => name = value
          "version" => version = value
          "preferred_target" => preferred = value
          _ => ()
        }
      None => ()
    }
  }
  if in_import {
    return Err("moon.mod:import 块未闭合(文件在块中间结束)")
  }
  if name == "" {
    return Err(
      "moon.mod:缺少 name 字段(工程资源管理器无法定位模块名)",
    )
  }
  Ok(ModuleManifest::{ name, version, preferred_target: preferred, imports, })
}
