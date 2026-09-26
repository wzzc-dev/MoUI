///|
/// AI 生成契约：模型只产出版本化 BlockGraphProposal（JSON 文本），
/// 不产出任意可执行代码；未知 kind/version 一律拒绝。
/// proposal v2：节点带可选 title/config；边为 [from, from_port, to, to_port]。
/// 本探针使用 deterministic fake model，离线可演示。

///|
/// 确定性假模型：无论提示词内容，固定返回「对话机器人」工作流提案。
/// 真实 provider 在 M3 接入，协议保持不变。
pub fn fake_model_completion(_prompt : String) -> Json {
  {
    "version": 2,
    "nodes": [
      { "id": 1, "kind": "AppStart", "title": "应用启动" },
      { "id": 2, "kind": "UserPrompt", "title": "用户提问" },
      { "id": 3, "kind": "ConversationMemory", "title": "会话记忆" },
      { "id": 4, "kind": "PromptTemplate", "title": "人设模板" },
      { "id": 5, "kind": "ParseJson", "title": "确认信封解析" },
      { "id": 6, "kind": "UserConfirmation", "title": "外发确认" },
      {
        "id": 7,
        "kind": "ModelCall",
        "title": "模型调用",
        "config": { "temperature": "0.5" },
      },
      { "id": 8, "kind": "ShowMarkdown", "title": "渲染回复" },
    ],
    "edges": [
      [1, "flow", 2, "trigger"],
      [2, "flow", 3, "trigger"],
      [3, "flow", 4, "trigger"],
      [4, "flow", 5, "trigger"],
      [5, "flow", 6, "trigger"],
      [6, "flow", 7, "trigger"],
      [7, "flow", 8, "trigger"],
      [2, "prompt", 4, "topic"],
      [2, "prompt", 7, "prompt"],
      [2, "message", 3, "append"],
      [3, "history", 7, "context"],
      [4, "rendered", 5, "text"],
      [5, "value", 6, "action"],
      [6, "approved", 7, "approved"],
      [7, "reply", 8, "content"],
    ],
  }
}

///|
/// 解码版本化提案 JSON 文本：严格字段检查，未知 kind 拒绝；
/// 解码成功后跑完整图校验，任何错误都使提案被拒绝。
pub fn decode_proposal(
  source : String,
  specs : Array[BlockSpec],
) -> Result[BlockGraph, Array[ValidationError]] {
  let payload = @json.parse(source) catch { _ => return Err([InvalidJson]) }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err([InvalidProposal])
  }
  match fields.get("version") {
    Some(Number(n, ..)) => if n != 2.0 { return Err([UnsupportedVersion]) }
    _ => return Err([UnsupportedVersion])
  }
  let node_values = match fields.get("nodes") {
    Some(Array(values)) => values
    _ => return Err([InvalidProposal])
  }
  let edge_values = match fields.get("edges") {
    Some(Array(values)) => values
    _ => return Err([InvalidProposal])
  }
  let errors : Array[ValidationError] = []
  let nodes : Array[BlockNode] = []
  let mut max_id = 0
  for value in node_values {
    match value {
      Object(item) => {
        let id = match item.get("id") {
          Some(Number(n, ..)) => n.to_int()
          _ => {
            errors.push(InvalidProposal)
            continue
          }
        }
        let kind = match item.get("kind") {
          Some(String(kind)) => kind
          _ => {
            errors.push(InvalidProposal)
            continue
          }
        }
        let title = match item.get("title") {
          Some(String(title)) => title
          _ =>
            match find_spec(specs, kind) {
              Some(spec) => spec.title
              None => kind
            }
        }
        if find_spec(specs, kind) is None {
          errors.push(UnknownKind(kind))
        }
        let config : Array[(String, String)] = []
        match item.get("config") {
          Some(Object(config_fields)) =>
            for pair in config_fields.to_array() {
              match pair.1 {
                String(text) => config.push((pair.0, text))
                Number(n, ..) => config.push((pair.0, n.to_string()))
                True => config.push((pair.0, "true"))
                False => config.push((pair.0, "false"))
                _ => errors.push(InvalidProposal)
              }
            }
          _ => ()
        }
        if id > max_id {
          max_id = id
        }
        nodes.push({ id, kind, title, x: 0.0, y: 0.0, config, })
      }
      _ => errors.push(InvalidProposal)
    }
  }
  let edges : Array[BlockEdge] = []
  for value in edge_values {
    match value {
      Array([Number(a, ..), String(from_port), Number(b, ..), String(to_port)]) =>
        edges.push({ from: a.to_int(), from_port, to: b.to_int(), to_port, })
      _ => errors.push(InvalidProposal)
    }
  }
  if !errors.is_empty() {
    return Err(errors)
  }
  let graph = auto_layout({ nodes, edges, next_id: max_id + 1, })
  let validation = validate_graph(graph, specs)
  if validation.is_empty() {
    Ok(graph)
  } else {
    Err(validation)
  }
}

///|
/// 探针 B 入口：fake model JSON 文本 → 提案解码 → 校验 → 图。
pub fn generate_from_prompt(
  prompt : String,
  specs : Array[BlockSpec],
) -> Result[BlockGraph, Array[ValidationError]] {
  decode_proposal(fake_model_completion(prompt).stringify(), specs)
}

///|
/// 假模型的自然语言路由：按提示词关键词选择最接近的内置模板，未命中时退回
/// 固定的对话机器人提案。全程确定性、离线可回放——评审现场改口述描述也能得到
/// 一张不同的合法图，而真实 provider 模式下同一段文字会发给远端模型。
pub fn fake_generate_from_prompt(
  prompt : String,
  specs : Array[BlockSpec],
) -> Result[BlockGraph, Array[ValidationError]] {
  match fake_template_source(prompt) {
    Some(source) =>
      match decode_project(source, specs) {
        Ok(project) => Ok(project.graph)
        Err(errors) => Err(errors)
      }
    None => generate_from_prompt(prompt, specs)
  }
}

///|
/// 提示词 → 内置模板项目 JSON 的路由表（纯关键词，不做任何网络请求）。
fn fake_template_source(prompt : String) -> String? {
  let text = prompt
  if text.contains("csv") ||
    text.contains("CSV") ||
    text.contains("表格") ||
    text.contains("数据") {
    Some(template_csv_assistant_json())
  } else if text.contains("文档") ||
    text.contains("论文") ||
    text.contains("资料") ||
    text.contains("doc") {
    Some(template_doc_assistant_json())
  } else {
    None
  }
}

///|
/// 真实 provider 的系统提示：把提案 v2 schema 讲清楚，约束模型只产出 JSON。
pub fn proposal_system_prompt() -> String {
  "你是 MoBlocks Studio 的工作流生成器。只输出一个 JSON 对象，不要输出任何多余文字。格式：{\"version\":2,\"nodes\":[{\"id\":<int>,\"kind\":<积木类型>,\"title\":<可选标题>,\"config\":<可选配置对象>}],\"edges\":[[<from_id>,\"<from_port>\",<to_id>,\"<to_port>\"]]}。可用 kind：AppStart, UserPrompt, FileSelected, ModelCall, StructuredModelCall, PromptTemplate, ConversationMemory, UserConfirmation, Sequence, IfElse, ForEach, Retry, Timeout, CatchError, ParseJson, ShowMarkdown, ShowTable。规则：节点 id 唯一且从 1 开始；除 AppStart 外每个节点应有 trigger 输入与 flow 输出构成执行链；ModelCall/StructuredModelCall 为数据外发节点，必须有一条从 UserConfirmation 的 approved 端口到其 approved 端口的连线；端口类型必须严格匹配（Text/Number/Bool/Json/FileRef/Table/ChatMessage/ToolResult/Unit）。"
}

///|
/// 真实生成回路的纯函数收尾：provider 文本 → 提案解码 → 校验。
/// 容忍 ```json 围栏与前后缀散文：取首个 `{` 到末个 `}` 之间的内容。
pub fn finish_real_generation(
  text : String,
  specs : Array[BlockSpec],
) -> Result[BlockGraph, Array[ValidationError]] {
  let start = match text.find("{") {
    Some(index) => index
    None => return Err([InvalidJson])
  }
  let tail = text.exact_view(start~).to_owned()
  let end = match json_object_end(tail) {
    Some(index) => index
    None => tail.length()
  }
  decode_proposal(tail.exact_view(end~).to_owned(), specs)
}

///|
/// 从首个 `{` 开始的字符串中，扫描到与之配对的 `}` 之后的偏移（含）。
/// 感知字符串字面量与转义；没有配对时返回 None。
fn json_object_end(text : String) -> Int? {
  let mut i = 0
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  let mut started = false
  for c in text {
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
    } else if c == '"' {
      in_string = true
    } else if c == '{' {
      depth = depth + 1
      started = true
    } else if c == '}' {
      depth = depth - 1
      if started && depth == 0 {
        return Some(i + 1)
      }
    }
    i = i + 1
  }
  None
}
