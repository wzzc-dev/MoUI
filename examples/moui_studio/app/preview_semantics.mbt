///|
/// 语义树点选 + 字面量属性补丁(M1-3)。
///
/// 数据流:预览帧的 `semantics`(JSON 节点数组,扁平 + children 引用)→
/// 投影成可命中节点(frame + label + role 标签)→ 画布点击命中(取**最深**
/// 命中,即最后一个匹配——数组顺序即父先子后)→ 属性条编辑 label →
/// 在工程源码里定位**同文的字符串字面量**(引号感知扫描)→ 转义补丁回写
/// → 自动走 BkFramePreview 重建出帧。
///
/// 边界(诚实):字面量定位是**精确全文匹配**的首个出现——重复文案或
/// 插值模板里的动态段不在 v1 能力内(重复时报错让用户改源码)。

///|
/// 可命中的语义节点(扁平投影;选择身份 = 投影数组下标)。
pub(all) struct SemanticHitNode {
  role : String
  label : String
  frame : @geometry.Rect
}

///|
/// 帧 → 可命中节点(无 frame 的节点跳过——不可点击)。
pub fn semantic_hit_nodes(frame : PreviewFrame) -> Array[SemanticHitNode] {
  let nodes : Array[SemanticHitNode] = []
  for node in frame.semantics {
    match node {
      Object(fields) => {
        let label = match fields.get("label") {
          Some(String(text)) => text
          _ => ""
        }
        let role = match fields.get("role") {
          Some(String(tag)) => tag
          _ => ""
        }
        let rect = match fields.get("frame") {
          Some(v) => json_as_rect(v)
          None => None
        }
        match rect {
          Some(rect) =>
            nodes.push(SemanticHitNode::{ role, label, frame: rect, })
          None => ()
        }
      }
      _ => ()
    }
  }
  nodes
}

///|
/// 命中测试:点在哪个节点里(取**最后一个**匹配 = 最深/最上层绘制者);
/// 未命中返回 -1。
pub fn semantic_hit_index(
  nodes : Array[SemanticHitNode],
  x : Double,
  y : Double,
) -> Int {
  let mut hit = -1
  let mut i = 0
  for node in nodes {
    if x >= node.frame.origin.x &&
      x <= node.frame.origin.x + node.frame.size.width &&
      y >= node.frame.origin.y &&
      y <= node.frame.origin.y + node.frame.size.height {
      hit = i
    }
    i = i + 1
  }
  hit
}

///|
/// 字面量补丁请求(纯数据;FileServices 在任务里注入)。
pub(all) struct SemanticPatchRequest {
  /// 待查源文件(绝对路径,顺序 = 程序包里的 .mbt 列表)
  paths : Array[String]
  /// 现字面量(精确全文匹配)
  label : String
  /// 新文本(未转义;写入时按 MoonBit 字符串转义)
  new_text : String
}

///|
/// MoonBit 字符串字面量转义(最小集:反斜杠/引号/换行/回车/制表)。
fn escape_moon_string(text : String) -> String {
  let mut out = ""
  for c in text {
    if c == '\\' {
      out = out + "\\\\"
    } else if c == '"' {
      out = out + "\\\""
    } else if c == '\n' {
      out = out + "\\n"
    } else if c == '\r' {
      out = out + "\\r"
    } else if c == '\t' {
      out = out + "\\t"
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
/// 在源码里找 `"` + label + `"` 的字面量 span(引号感知,处理 `\"` 转义;
/// 内容**精确等于** label 才算)。多个出现取首个(v1 边界)。
pub fn find_literal_span(source : String, label : String) -> (Int, Int)? {
  let chars = text_to_chars(source)
  let n = chars.length()
  let mut i = 0
  while i < n {
    if chars[i] == '"' {
      // 读字符串 span
      let content_start = i + 1
      let mut j = content_start
      let mut escaped = false
      let mut content = ""
      let mut end = -1
      while j < n {
        let c = chars[j]
        if escaped {
          content = content + c.to_string()
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == '"' {
          end = j
          break
        } else {
          content = content + c.to_string()
        }
        j = j + 1
      }
      if end < 0 {
        return None
      }
      if content == label {
        return Some((i, end + 1))
      }
      i = end + 1
      continue
    }
    i = i + 1
  }
  None
}

///|
/// 属性补丁任务:逐文件读取 → 找字面量 span → 转义补丁 → 写回。
/// 成功 = Ok(被补丁的文件路径);全部文件都没找到 = Err(明确说明)。
/// 写盘失败 = Err(服务错误信息)。
pub fn semantic_label_patch_task(
  files : @services.FileServices,
  request : SemanticPatchRequest,
) -> @services.ServiceTask[Result[String, String]] {
  @services.ServiceTask::new(key="semantic:patch", label="应用属性修改", start=complete => {
    let state : PatchWalkState = PatchWalkState::{
      files,
      paths: request.paths,
      cursor: 0,
      label: request.label,
      new_text: request.new_text,
    }
    patch_step(state, complete)
    None
  })
}

///|
priv struct PatchWalkState {
  files : @services.FileServices
  paths : Array[String]
  mut cursor : Int
  label : String
  new_text : String
}

///|
fn patch_step(
  state : PatchWalkState,
  complete : (@services.ServiceTaskResult[Result[String, String]]) -> Unit,
) -> Unit {
  if state.cursor >= state.paths.length() {
    complete(
      Success(
        Err(
          "在工程源码里没有找到「\{state.label}」对应的字符串字面量(动态拼接的文本暂不支持在预览中修改)",
        ),
      ),
    )
    return
  }
  let path = state.paths[state.cursor]
  let _ = (state.files.read_text_fn)(path).start(result => {
    match result {
      @services.Success(source) => {
        let span = find_literal_span(source, state.label)
        match span {
          Some((start, end)) => {
            let patched = source[:start].to_owned() +
              escape_moon_string(state.new_text) +
              source[end:].to_owned()
            let _ = (state.files.write_text_fn)(path, patched).start(write_result => {
              match write_result {
                @services.Success(_) => complete(@services.Success(Ok(path)))
                @services.Failure(error) => complete(@services.Failure(error))
                @services.Cancelled => complete(@services.Cancelled)
              }
            })
          }
          None => {
            state.cursor = state.cursor + 1
            patch_step(state, complete)
          }
        }
      }
      @services.Failure(error) => complete(@services.Failure(error))
      @services.Cancelled => complete(@services.Cancelled)
    }
  })
}

///|
/// 提交请求装配(纯):工程/帧/选中/草稿逐项把关,全部就绪才给出补丁
/// 请求。None = 没有可提交的东西(静默无操作);Some(Err) = 显式报错。
pub fn semantic_commit_request(
  model : Model,
) -> Result[SemanticPatchRequest, String]? {
  let project = match active_project_of(model) {
    Some(project) => project
    None => return Some(Err("先导入一个 MoonBit 工程"))
  }
  let frame = match model.preview_frame {
    Some(frame) => frame
    None => return Some(Err("还没有预览画面——先构建一次预览"))
  }
  let index = match model.selected_semantic {
    Some(index) => index
    None => return Some(Err("先在预览画布上点选一个元素"))
  }
  let nodes = semantic_hit_nodes(frame)
  if index < 0 || index >= nodes.length() {
    return Some(
      Err("选中的元素已不存在(预览刷新后失效),请重新点选"),
    )
  }
  let node = nodes[index]
  if node.label == "" {
    return Some(Err("这个元素没有可编辑的文本"))
  }
  if model.semantic_draft == "" || model.semantic_draft == node.label {
    return None
  }
  // 程序包的 .mbt 源文件(绝对路径;来自扫描快照,不重新列目录)
  let program_rel = match project.scanned.program_packages {
    [first, ..] => first
    [] => return Some(Err("该工程没有逻辑入口包"))
  }
  let paths : Array[String] = []
  for pkg in project.scanned.packages {
    if pkg.rel_path == program_rel {
      for name in pkg.files {
        if name.has_suffix(".mbt") {
          paths.push("\{project.root}/\{program_rel}/\{name}")
        }
      }
    }
  }
  if paths.length() == 0 {
    return Some(Err("程序包里没有 .mbt 源文件"))
  }
  Some(
    Ok(SemanticPatchRequest::{
      paths,
      label: node.label,
      new_text: model.semantic_draft,
    }),
  )
}
