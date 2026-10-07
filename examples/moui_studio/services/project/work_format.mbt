///|
/// moon.work 工作区清单解析。
///
/// 工作区导入只需要 members 列表；解析容忍规则与 moon.mod 同纪律：
/// `//` 行注释剥离（MoonBit 语法注释）、行内空白宽容、成员路径剥 `./`
/// 前缀。members 缺失或块未闭合 = 结构化报错——工作区导入要能指着说
/// 「清单哪里坏了」，而不是静默读出空列表。
///
/// 真实样例（本仓库根 moon.work）：
///
/// ```
/// members = [
///   "./moui",
///   "./examples/moui_studio",
/// ]
/// ```

///|
/// 解析 moon.work 的 members 列表。成员已归一（剥 `./`，拒绝空串与
/// 「根自身」条目），顺序保持清单原文。
pub fn parse_moon_work(source : String) -> Result[Array[String], String] {
  let members : Array[String] = []
  let mut found_key = false
  let mut in_members = false
  for view in source.split("\n") {
    let text = strip_comment(view.to_owned()).trim(chars=" \t\r").to_owned()
    if text == "" {
      continue
    }
    if in_members {
      // `]` 同行出现 = 块闭合；同行可能还挂着最后几个条目，先提取再闭合
      if text.contains("]") {
        in_members = false
      }
      extract_member_strings(text, members)
      continue
    }
    if !found_key && text.has_prefix("members") && text.contains("[") {
      found_key = true
      if text.contains("]") {
        // 单行块 `members = [ "./a", "./b" ]`
        extract_member_strings(text, members)
      } else {
        in_members = true
      }
    }
    // members 之前的未知键按行跳过（同 mod_format 容忍纪律）
  }
  if found_key && in_members {
    return Err("moon.work:members 块未闭合(文件在块中间结束)")
  }
  if !found_key {
    return Err(
      "moon.work:缺少 members 字段(工作区导入无法定位成员模块)",
    )
  }
  Ok(members)
}

///|
/// 逐个提取一行内的双引号字符串（奇数分片即在引号内），归一后入库。
fn extract_member_strings(text : String, out : Array[String]) -> Unit {
  let mut in_quote = false
  for piece in text.split("\"") {
    if in_quote {
      match normalize_workspace_member(piece.to_owned()) {
        Some(member_path) => out.push(member_path)
        None => ()
      }
    }
    in_quote = !in_quote
  }
}

///|
/// 成员路径归一：剥 `./` 前缀；空串与「根自身」（`.` / `./`）拒绝——
/// 把工作区根本身当成员会得到自我递归扫描。
pub fn normalize_workspace_member(raw : String) -> String? {
  let mut text = raw.trim(chars=" \t").to_owned()
  if text == "." || text == "./" {
    return None
  }
  if text.has_prefix("./") {
    text = text[2:].to_owned()
  }
  if text == "" {
    return None
  }
  Some(text)
}
