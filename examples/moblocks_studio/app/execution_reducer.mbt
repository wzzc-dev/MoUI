///|
/// 步骤状态：执行时间线上每一格的生命周期。
pub(all) enum StepStatus {
  Pending
  Running
  WaitingConfirmation
  Completed
  Failed(String)
  Skipped
}

///|
/// 整体运行状态。
pub(all) enum RunStatus {
  Idle
  Running
  WaitingConfirmation
  Completed
  Failed(String)
  Cancelled
}

///|
/// 单步记录：进入时间线。
pub(all) struct StepRecord {
  node_id : Int
  kind : String
  title : String
  status : StepStatus
  attempts : Int
  max_attempts : Int
  timeout_ms : Int
  started_ms : Int
  ended_ms : Int
  duration_ms : Int
  /// 计划期推导的输入摘要（如「prompt ← 用户提问」）；无则空串。
  input_summary : String
  /// 计划期推导的输出摘要（模型步骤为确定性回复）；无则空串，完成时回落「完成」。
  output_summary : String
  summary : String
}

///|
/// 执行状态机。plain data；全部经 typed Msg 驱动，时间只由 Tick 事件推进。
pub(all) struct ExecutionState {
  status : RunStatus
  steps : Array[StepRecord]
  cursor : Int
  now_ms : Int
  audit : Array[String]
}

///|
pub fn ExecutionState::idle() -> ExecutionState {
  { status: Idle, steps: [], cursor: 0, now_ms: 0, audit: [], }
}

///|
fn set_step(
  steps : Array[StepRecord],
  index : Int,
  step : StepRecord,
) -> Array[StepRecord] {
  let out = Array(capacity=steps.length())
  for i = 0; i < steps.length(); i = i + 1 {
    if i == index {
      out.push(step)
    } else {
      out.push(steps[i])
    }
  }
  out
}

///|
/// external_submit 级步骤在执行前必须暂停等待人工确认。
pub fn step_needs_confirmation(specs : Array[BlockSpec], kind : String) -> Bool {
  match find_spec(specs, kind) {
    Some(spec) => spec.risk_class is ExternalSubmit
    None => false
  }
}

///|
/// 单步的输入/输出摘要（计划期推导，纯函数无 IO）。
/// 模型步骤的回复由确定性假模型承担：人设取上游 PromptTemplate 的 persona 配置，
/// 因此时间线显示的是**可回放的真实内容**，而不是空泛的「完成」。
pub fn step_summaries(graph : BlockGraph, node : BlockNode) -> (String, String) {
  let config_or = fn(key : String, fallback : String) -> String {
    match find_config_value(node, key) {
      Some(text) => if text.is_empty() { fallback } else { text }
      None => fallback
    }
  }
  match node.kind {
    "ModelCall" | "StructuredModelCall" => {
      let persona = match upstream_persona(graph, node) {
        Some(text) => text
        None => default_persona(graph)
      }
      (
        "prompt ← \{input_source_title(graph, node, ["prompt", "text"])}",
        "【\{persona}】确定性回复（模型 \{config_or("model", "fake-gpt-mini")}）",
      )
    }
    "PromptTemplate" =>
      ("", "已渲染人设「\{config_or("persona", "友好助手")}」")
    "ConversationMemory" =>
      ("", "保留最近 \{config_or("entries", "8")} 轮上下文")
    "ParseJson" =>
      (
        "text ← \{input_source_title(graph, node, ["prompt", "text"])}",
        "已解析为 JSON 值",
      )
    "ShowMarkdown" => ("", "已渲染 Markdown 到界面")
    "ShowTable" => ("", "已渲染表格到界面")
    "UserConfirmation" =>
      (
        "action ← \{input_source_title(graph, node, ["action"])}",
        "用户确认后放行外发",
      )
    "AppStart" => ("", "应用启动，触发一次")
    _ => ("", "完成")
  }
}

///|
/// 完成时采用的摘要：计划期推导的输出摘要优先，无则「完成」。
fn summary_of(step : StepRecord) -> String {
  if step.output_summary.is_empty() {
    "完成"
  } else {
    step.output_summary
  }
}

///|
/// 沿 prompt/text 输入端口向上游走（有界深度）寻找 PromptTemplate 的人设配置。
/// 模型回复按图中配置的人设生成，而不是空泛的「完成」。
fn upstream_persona(graph : BlockGraph, node : BlockNode) -> String? {
  upstream_persona_from(graph, node, 4)
}

///|
fn upstream_persona_from(
  graph : BlockGraph,
  node : BlockNode,
  depth : Int,
) -> String? {
  if depth <= 0 {
    return None
  }
  for edge in graph.edges {
    if edge.to == node.id &&
      (edge.to_port == "prompt" || edge.to_port == "text") {
      match graph.find_node(edge.from) {
        Some(source) => {
          if source.kind == "PromptTemplate" {
            match find_config_value(source, "persona") {
              Some(text) => if !text.is_empty() { return Some(text) }
              None => ()
            }
          }
          match upstream_persona_from(graph, source, depth - 1) {
            Some(persona) => return Some(persona)
            None => ()
          }
        }
        None => ()
      }
    }
  }
  None
}

///|
/// 上游没有人设配置时，取图中第一个 PromptTemplate 的人设配置；
/// 图里也没配（提案/模板节点可能不带配置）则用积木目录里 persona 的规范
/// 默认值，最后才退回「助手」。
fn default_persona(graph : BlockGraph) -> String {
  for node in graph.nodes {
    if node.kind == "PromptTemplate" {
      match find_config_value(node, "persona") {
        Some(text) => if !text.is_empty() { return text }
        None => ()
      }
    }
  }
  match find_spec(block_catalog(), "PromptTemplate") {
    Some(spec) =>
      match find_config_spec(spec, "persona") {
        Some(cfg) => if cfg.default.is_empty() { "助手" } else { cfg.default }
        None => "助手"
      }
    None => "助手"
  }
}

///|
/// 该节点指定输入端口的来源节点标题（无来源时为「内置配置」）。
fn input_source_title(
  graph : BlockGraph,
  node : BlockNode,
  ports : Array[String],
) -> String {
  for edge in graph.edges {
    if edge.to == node.id && ports.contains(edge.to_port) {
      match graph.find_node(edge.from) {
        Some(source) => return source.title
        None => ()
      }
    }
  }
  "内置配置"
}

///|
/// 以入口可达节点的拓扑序构建执行计划，每步带重试/超时策略与摘要。
pub fn start_execution(graph : BlockGraph) -> ExecutionState {
  let entrypoints = graph.nodes
    .filter(fn(node) { node.kind == "AppStart" })
    .map(fn(node) { node.id })
  let reachable = reachable_from(graph, entrypoints)
  let order = topo_order(graph, reachable)
  let steps = order.map(fn(id) {
    let (max_attempts, timeout_ms) = step_policy(graph, id)
    let (input_summary, output_summary) = match graph.find_node(id) {
      Some(node) => step_summaries(graph, node)
      None => ("", "")
    }
    match graph.find_node(id) {
      Some(node) =>
        {
          node_id: node.id,
          kind: node.kind,
          title: node.title,
          status: Pending,
          attempts: 0,
          max_attempts,
          timeout_ms,
          started_ms: 0,
          ended_ms: 0,
          duration_ms: 0,
          input_summary,
          output_summary,
          summary: "",
        }
      None =>
        {
          node_id: id,
          kind: "Unknown",
          title: "未知节点",
          status: Pending,
          attempts: 0,
          max_attempts,
          timeout_ms,
          started_ms: 0,
          ended_ms: 0,
          duration_ms: 0,
          input_summary,
          output_summary,
          summary: "",
        }
    }
  })
  { status: Idle, steps, cursor: 0, now_ms: 0, audit: [], }
}

///|
pub(all) enum ExecEvent {
  Start
  StepOk
  StepFail(String)
  Tick(Int)
  Confirm
  Reject
  Cancel
}

///|
fn begin_step(
  state : ExecutionState,
  cursor : Int,
  now_ms : Int,
  specs : Array[BlockSpec],
) -> ExecutionState {
  if cursor >= state.steps.length() {
    return {
      status: Completed,
      steps: state.steps,
      cursor,
      now_ms,
      audit: [..state.audit, "运行完成"],
    }
  }
  let step = state.steps[cursor]
  if step_needs_confirmation(specs, step.kind) {
    let updated = set_step(state.steps, cursor, {
      ..step,
      status: WaitingConfirmation,
      summary: "等待人工确认：数据将外发",
    })
    {
      status: WaitingConfirmation,
      steps: updated,
      cursor,
      now_ms,
      audit: [
        ..state.audit,
        "步骤 \{cursor + 1}（\{step.title}）等待人工确认",
      ],
    }
  } else {
    let updated = set_step(state.steps, cursor, {
      ..step,
      status: Running,
      started_ms: now_ms,
    })
    { status: Running, steps: updated, cursor, now_ms, audit: state.audit, }
  }
}

///|
fn complete_step(
  state : ExecutionState,
  cursor : Int,
  now_ms : Int,
  summary : String,
  specs : Array[BlockSpec],
) -> ExecutionState {
  let step = state.steps[cursor]
  let updated = set_step(state.steps, cursor, {
    ..step,
    status: Completed,
    ended_ms: now_ms,
    duration_ms: now_ms - step.started_ms,
    summary,
  })
  begin_step({ ..state, steps: updated, }, cursor + 1, now_ms, specs)
}

///|
fn fail_step(
  state : ExecutionState,
  cursor : Int,
  now_ms : Int,
  reason : String,
) -> ExecutionState {
  let step = state.steps[cursor]
  let attempts = step.attempts + 1
  if attempts < step.max_attempts {
    let updated = set_step(state.steps, cursor, {
      ..step,
      status: Running,
      attempts,
      started_ms: now_ms,
      summary: "第 \{attempts} 次重试",
    })
    {
      status: Running,
      steps: updated,
      cursor,
      now_ms,
      audit: [
        ..state.audit,
        "步骤 \{cursor + 1}（\{step.title}）失败，第 \{attempts} 次重试：\{reason}",
      ],
    }
  } else {
    let failed = set_step(state.steps, cursor, {
      ..step,
      status: Failed(reason),
      attempts,
      ended_ms: now_ms,
      duration_ms: now_ms - step.started_ms,
      summary: "失败：\{reason}",
    })
    let mut steps = failed
    let mut i = cursor + 1
    while i < steps.length() {
      let downstream = steps[i]
      if downstream.status is Pending {
        steps = set_step(steps, i, {
          ..downstream,
          status: Skipped,
          summary: "上游失败，已跳过",
        })
      }
      i = i + 1
    }
    {
      status: Failed(reason),
      steps,
      cursor,
      now_ms,
      audit: [
        ..state.audit,
        "步骤 \{cursor + 1}（\{step.title}）最终失败：\{reason}",
      ],
    }
  }
}

///|
/// 执行事件化：全部为纯函数，时间只由 Tick 事件推进（确定性可测）。
pub fn apply_exec_event(
  state : ExecutionState,
  event : ExecEvent,
  specs : Array[BlockSpec],
) -> ExecutionState {
  match event {
    Start =>
      if state.status is Idle && !state.steps.is_empty() {
        begin_step(
          {
            ..state,
            audit: [
              ..state.audit,
              "开始执行（\{state.steps.length()} 步）",
            ],
          },
          0,
          0,
          specs,
        )
      } else {
        state
      }
    StepOk =>
      match state.status {
        Running =>
          complete_step(
            state,
            state.cursor,
            state.now_ms,
            summary_of(state.steps[state.cursor]),
            specs,
          )
        _ => state
      }
    StepFail(reason) =>
      match state.status {
        Running => fail_step(state, state.cursor, state.now_ms, reason)
        _ => state
      }
    Tick(delta_ms) => {
      let now_ms = state.now_ms + delta_ms
      match state.status {
        Running => {
          let step = state.steps[state.cursor]
          if step.timeout_ms > 0 && now_ms - step.started_ms > step.timeout_ms {
            fail_step(state, state.cursor, now_ms, "超时")
          } else {
            { ..state, now_ms, }
          }
        }
        _ => { ..state, now_ms, }
      }
    }
    Confirm =>
      match state.status {
        WaitingConfirmation =>
          complete_step(
            state,
            state.cursor,
            state.now_ms,
            "已确认并执行：\{summary_of(state.steps[state.cursor])}",
            specs,
          )
        _ => state
      }
    Reject =>
      match state.status {
        WaitingConfirmation => {
          let step = state.steps[state.cursor]
          let failed = set_step(state.steps, state.cursor, {
            ..step,
            status: Failed("确认被拒绝"),
            ended_ms: state.now_ms,
            duration_ms: state.now_ms - step.started_ms,
            summary: "用户拒绝：未产生副作用",
          })
          let mut steps = failed
          let mut i = state.cursor + 1
          while i < steps.length() {
            let downstream = steps[i]
            if downstream.status is Pending {
              steps = set_step(steps, i, {
                ..downstream,
                status: Skipped,
                summary: "已跳过",
              })
            }
            i = i + 1
          }
          {
            status: Failed("确认被拒绝"),
            steps,
            cursor: state.cursor,
            now_ms: state.now_ms,
            audit: [
              ..state.audit,
              "用户拒绝数据外发确认：未产生副作用",
            ],
          }
        }
        _ => state
      }
    Cancel =>
      match state.status {
        Running | WaitingConfirmation =>
          {
            status: Cancelled,
            steps: state.steps,
            cursor: state.cursor,
            now_ms: state.now_ms,
            audit: [..state.audit, "用户取消运行"],
          }
        _ => state
      }
  }
}

///|
pub fn step_status_label(status : StepStatus) -> String {
  match status {
    Pending => "等待"
    Running => "运行中"
    WaitingConfirmation => "等待确认"
    Completed => "完成"
    Failed(reason) => "失败：\{reason}"
    Skipped => "跳过"
  }
}

///|
pub fn run_status_label(status : RunStatus) -> String {
  match status {
    Idle => "空闲"
    Running => "运行中"
    WaitingConfirmation => "等待人工确认"
    Completed => "已完成"
    Failed(reason) => "失败：\{reason}"
    Cancelled => "已取消"
  }
}

///|
/// 时间线文本与审计的截断上限（参数/结果不整体倾泻到 UI）。
pub fn summary_max_chars() -> Int {
  120
}

///|
pub fn truncate_summary(text : String) -> String {
  if text.length() <= summary_max_chars() {
    text
  } else {
    text.exact_view(end=summary_max_chars()).to_owned() + "…"
  }
}

///|
/// 审计导出：Markdown 形式的运行报告（用于导出与赛后复盘）。
pub fn export_audit_markdown(state : ExecutionState) -> String {
  let mut out = "# MoBlocks Studio 运行审计\n\n"
  out = out + "- 状态：\{run_status_label(state.status)}\n"
  out = out + "- 步骤：\{state.steps.length()}\n\n"
  out = out + "| # | 积木 | 状态 | 尝试 | 耗时(ms) | 说明 |\n"
  out = out + "| --- | --- | --- | --- | --- | --- |\n"
  for step in state.steps {
    out = out +
      "| \{step.node_id} | \{step.title} | \{step_status_label(step.status)} | \{step.attempts} | \{step.duration_ms} | \{truncate_summary(step.summary)} |\n"
  }
  out = out + "\n## 审计事件\n\n"
  for entry in state.audit {
    out = out + "- \{entry}\n"
  }
  out
}
