///|
/// 导出的领域内核源码：`app/graph_validation.mbt` 的逐字节副本。
/// 由 tools/sync_kernel 生成，勿手改；与源文件不一致时
/// `tools/sync_kernel -- --check` 会报 DRIFT。

///|
pub fn kernel_graph_validation() -> String {
  let source =
    #|///|
    #|/// 校验错误种类。校验器只报告，不自动授权。
    #|pub(all) enum ValidationError {
    #|  InvalidJson
    #|  InvalidProject
    #|  InvalidProposal
    #|  FormatMismatch(String)
    #|  UnsupportedVersion
    #|  UnknownKind(String)
    #|  DuplicateNodeId(Int)
    #|  EdgeMissingEndpoint(Int, Int)
    #|  UnknownPort(Int, String)
    #|  UnknownConfigKey(Int, String)
    #|  BadConfigValue(Int, String)
    #|  TypeMismatch(Int, String, Int, String, PortType, PortType)
    #|  InputOccupied(Int, String)
    #|  MissingEntrypoint
    #|  UnreachableNode(Int)
    #|  CycleDetected
    #|  NodeBudgetExceeded(Int)
    #|  EdgeBudgetExceeded(Int)
    #|  IterationBudgetExceeded(Int)
    #|  MissingConfirmation(Int)
    #|}
    #|
    #|///|
    #|/// 执行预算上限（比赛版有界性硬约束）。
    #|pub fn max_nodes() -> Int {
    #|  64
    #|}
    #|
    #|///|
    #|pub fn max_edges() -> Int {
    #|  96
    #|}
    #|
    #|///|
    #|pub fn max_foreach_limit() -> Int {
    #|  64
    #|}
    #|
    #|///|
    #|/// 端口类型相等（零 derive 风格的手工比较）。
    #|pub fn port_types_equal(a : PortType, b : PortType) -> Bool {
    #|  match (a, b) {
    #|    (Text, Text) => true
    #|    (Number, Number) => true
    #|    (Bool, Bool) => true
    #|    (Json, Json) => true
    #|    (FileRef, FileRef) => true
    #|    (Table, Table) => true
    #|    (ChatMessage, ChatMessage) => true
    #|    (ToolResult, ToolResult) => true
    #|    (Unit, Unit) => true
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|/// 手写数字解析：接受带符号十进制文本，其余一律拒绝（配置契约）。
    #|fn double_try_parse(text : String) -> Double? {
    #|  if text.is_empty() {
    #|    return None
    #|  }
    #|  let chars : Array[Char] = []
    #|  for c in text {
    #|    chars.push(c)
    #|  }
    #|  let mut i = 0
    #|  if chars[0] == '-' {
    #|    i = 1
    #|  }
    #|  if i >= chars.length() {
    #|    return None
    #|  }
    #|  let digit_start = i
    #|  let mut digits = 0
    #|  let mut dots = 0
    #|  while i < chars.length() {
    #|    let c = chars[i]
    #|    if c == '.' {
    #|      dots = dots + 1
    #|      if dots > 1 {
    #|        return None
    #|      }
    #|    } else if c < '0' || c > '9' {
    #|      return None
    #|    } else {
    #|      digits = digits + 1
    #|    }
    #|    i = i + 1
    #|  }
    #|  if digits == 0 {
    #|    return None
    #|  }
    #|  let mut value = 0.0
    #|  let mut fraction_int = 0
    #|  let mut scale = 1.0
    #|  let mut in_fraction = false
    #|  for j = digit_start; j < chars.length(); j = j + 1 {
    #|    let c = chars[j]
    #|    if c == '.' {
    #|      in_fraction = true
    #|    } else if in_fraction {
    #|      scale = scale * 10.0
    #|      fraction_int = fraction_int * 10 + (c.to_int() - '0'.to_int())
    #|    } else {
    #|      value = value * 10.0 + (c.to_int() - '0'.to_int()).to_double()
    #|    }
    #|  }
    #|  let fraction = fraction_int.to_double() / scale
    #|  if chars[0] == '-' {
    #|    Some(-(value + fraction))
    #|  } else {
    #|    Some(value + fraction)
    #|  }
    #|}
    #|
    #|///|
    #|/// 从给定起点沿边可达的节点集合（含起点本身）。
    #|pub fn reachable_from(graph : BlockGraph, starts : Array[Int]) -> Array[Int] {
    #|  let seen : Array[Int] = []
    #|  let stack : Array[Int] = []
    #|  for start in starts {
    #|    stack.push(start)
    #|  }
    #|  while !stack.is_empty() {
    #|    match stack.pop() {
    #|      Some(id) =>
    #|        if !seen.contains(id) {
    #|          seen.push(id)
    #|          for edge in graph.edges {
    #|            if edge.from == id {
    #|              stack.push(edge.to)
    #|            }
    #|          }
    #|        }
    #|      None => break
    #|    }
    #|  }
    #|  seen
    #|}
    #|
    #|///|
    #|fn dfs_cycle(graph : BlockGraph, id : Int, state : Map[Int, Int]) -> Bool {
    #|  state[id] = 1
    #|  for edge in graph.edges {
    #|    if edge.from == id {
    #|      let mark = state.get(edge.to).unwrap_or(0)
    #|      if mark == 1 {
    #|        return true
    #|      }
    #|      if mark == 0 && dfs_cycle(graph, edge.to, state) {
    #|        return true
    #|      }
    #|    }
    #|  }
    #|  state[id] = 2
    #|  false
    #|}
    #|
    #|///|
    #|/// 三色 DFS 判环。
    #|pub fn has_cycle(graph : BlockGraph) -> Bool {
    #|  let state : Map[Int, Int] = Map([], capacity=16)
    #|  for node in graph.nodes {
    #|    if state.get(node.id).unwrap_or(0) == 0 && dfs_cycle(graph, node.id, state) {
    #|      return true
    #|    }
    #|  }
    #|  false
    #|}
    #|
    #|///|
    #|/// Kahn 拓扑排序，仅覆盖 reachable 集合内的节点。
    #|pub fn topo_order(graph : BlockGraph, reachable : Array[Int]) -> Array[Int] {
    #|  let indegree : Map[Int, Int] = Map([], capacity=16)
    #|  for id in reachable {
    #|    indegree[id] = 0
    #|  }
    #|  for edge in graph.edges {
    #|    if reachable.contains(edge.from) && reachable.contains(edge.to) {
    #|      indegree[edge.to] = indegree.get(edge.to).unwrap_or(0) + 1
    #|    }
    #|  }
    #|  let queue : Array[Int] = []
    #|  for id in reachable {
    #|    if indegree.get(id).unwrap_or(0) == 0 {
    #|      queue.push(id)
    #|    }
    #|  }
    #|  let order : Array[Int] = []
    #|  while !queue.is_empty() {
    #|    let id = queue.remove(0)
    #|    order.push(id)
    #|    for edge in graph.edges {
    #|      if edge.from == id && reachable.contains(edge.to) {
    #|        let remaining = indegree.get(edge.to).unwrap_or(0) - 1
    #|        indegree[edge.to] = remaining
    #|        if remaining == 0 {
    #|          queue.push(edge.to)
    #|        }
    #|      }
    #|    }
    #|  }
    #|  order
    #|}
    #|
    #|///|
    #|/// 节点配置按 schema 校验：未知 key 拒绝，值类型不符拒绝。
    #|pub fn validate_node_config(
    #|  node : BlockNode,
    #|  spec : BlockSpec,
    #|) -> Array[ValidationError] {
    #|  let errors : Array[ValidationError] = []
    #|  for entry in node.config {
    #|    match find_config_spec(spec, entry.0) {
    #|      None => errors.push(UnknownConfigKey(node.id, entry.0))
    #|      Some(cfg) => {
    #|        let ok = match cfg.value_type {
    #|          CfgString => true
    #|          CfgNumber => double_try_parse(entry.1) is Some(_)
    #|          CfgBool => entry.1 == "true" || entry.1 == "false"
    #|        }
    #|        if !ok {
    #|          errors.push(BadConfigValue(node.id, entry.0))
    #|        }
    #|      }
    #|    }
    #|  }
    #|  errors
    #|}
    #|
    #|///|
    #|/// 从图推导单步的执行策略：上游有 Retry → 最多 attempts 次重试；
    #|/// 上游有 Timeout → 单步预算（取上游所有 Timeout 配置的最小值）。
    #|pub fn step_policy(graph : BlockGraph, node_id : Int) -> (Int, Int) {
    #|  let retries = ["Retry"]
    #|  let timeouts = ["Timeout"]
    #|  let retry_sources = graph.nodes
    #|    .filter(fn(node) { retries.contains(node.kind) })
    #|    .map(fn(node) { node.id })
    #|  let retry_reach = reachable_from(graph, retry_sources)
    #|  let max_attempts = if retry_reach.contains(node_id) { 4 } else { 1 }
    #|  let timeout_sources = graph.nodes
    #|    .filter(fn(node) { timeouts.contains(node.kind) })
    #|    .map(fn(node) { node.id })
    #|  let timeout_reach = reachable_from(graph, timeout_sources)
    #|  let mut budget = 0
    #|  if timeout_reach.contains(node_id) {
    #|    for node in graph.nodes {
    #|      if timeout_sources.contains(node.id) {
    #|        let value = match find_config_value(node, "budget_ms") {
    #|          Some(text) =>
    #|            match double_try_parse(text) {
    #|              Some(n) => n.to_int()
    #|              None => 3000
    #|            }
    #|          None => 3000
    #|        }
    #|        if budget == 0 || value < budget {
    #|          budget = value
    #|        }
    #|      }
    #|    }
    #|  }
    #|  (max_attempts, budget)
    #|}
    #|
    #|///|
    #|pub fn find_config_value(node : BlockNode, key : String) -> String? {
    #|  for entry in node.config {
    #|    if entry.0 == key {
    #|      return Some(entry.1)
    #|    }
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|/// 完整图校验：schema、类型、单输入占用、入口、可达性、环、预算、权限路径。
    #|/// 权限规则：每个 external_submit 级节点必须从某个 UserConfirmation 积木的
    #|/// approved 输出端口接线（精确闸门）；无 approved 端口的外发积木退回可达性判定。
    #|pub fn validate_graph(
    #|  graph : BlockGraph,
    #|  specs : Array[BlockSpec],
    #|) -> Array[ValidationError] {
    #|  let errors : Array[ValidationError] = []
    #|  for node in graph.nodes {
    #|    match find_spec(specs, node.kind) {
    #|      None => errors.push(UnknownKind(node.kind))
    #|      Some(spec) => {
    #|        for error in validate_node_config(node, spec) {
    #|          errors.push(error)
    #|        }
    #|        // ForEach 的遍历上限预算
    #|        if node.kind == "ForEach" {
    #|          let current = match find_config_value(node, "limit") {
    #|            Some(text) =>
    #|              match double_try_parse(text) {
    #|                Some(n) => n.to_int()
    #|                None => 0
    #|              }
    #|            None =>
    #|              match find_config_spec(spec, "limit") {
    #|                Some(cfg) =>
    #|                  match double_try_parse(cfg.default) {
    #|                    Some(n) => n.to_int()
    #|                    None => 0
    #|                  }
    #|                None => 0
    #|              }
    #|          }
    #|          if current > max_foreach_limit() {
    #|            errors.push(IterationBudgetExceeded(node.id))
    #|          }
    #|        }
    #|      }
    #|    }
    #|  }
    #|  for i = 0; i < graph.nodes.length(); i = i + 1 {
    #|    for j = i + 1; j < graph.nodes.length(); j = j + 1 {
    #|      if graph.nodes[i].id == graph.nodes[j].id {
    #|        errors.push(DuplicateNodeId(graph.nodes[i].id))
    #|      }
    #|    }
    #|  }
    #|  if graph.nodes.length() > max_nodes() {
    #|    errors.push(NodeBudgetExceeded(graph.nodes.length()))
    #|  }
    #|  if graph.edges.length() > max_edges() {
    #|    errors.push(EdgeBudgetExceeded(graph.edges.length()))
    #|  }
    #|  // 每条边：端点存在、端口存在、类型匹配
    #|  for edge in graph.edges {
    #|    let from_node = graph.find_node(edge.from)
    #|    let to_node = graph.find_node(edge.to)
    #|    match (from_node, to_node) {
    #|      (Some(from_node), Some(to_node)) => {
    #|        let from_spec = find_spec(specs, from_node.kind)
    #|        let to_spec = find_spec(specs, to_node.kind)
    #|        match (from_spec, to_spec) {
    #|          (Some(from_spec), Some(to_spec)) => {
    #|            let out_port = find_output_port(from_spec, edge.from_port)
    #|            let in_port = find_input_port(to_spec, edge.to_port)
    #|            match (out_port, in_port) {
    #|              (None, _) => errors.push(UnknownPort(edge.from, edge.from_port))
    #|              (_, None) => errors.push(UnknownPort(edge.to, edge.to_port))
    #|              (Some(out_port), Some(in_port)) =>
    #|                if !port_types_equal(out_port.port_type, in_port.port_type) {
    #|                  errors.push(
    #|                    TypeMismatch(
    #|                      edge.from,
    #|                      edge.from_port,
    #|                      edge.to,
    #|                      edge.to_port,
    #|                      out_port.port_type,
    #|                      in_port.port_type,
    #|                    ),
    #|                  )
    #|                }
    #|            }
    #|          }
    #|          _ => ()
    #|        }
    #|      }
    #|      _ => errors.push(EdgeMissingEndpoint(edge.from, edge.to))
    #|    }
    #|  }
    #|  // 单输入占用：每个输入的入边至多一条
    #|  let occupied : Map[String, Int] = Map([], capacity=16)
    #|  for edge in graph.edges {
    #|    let key = "\{edge.to}:\{edge.to_port}"
    #|    let count = occupied.get(key).unwrap_or(0) + 1
    #|    occupied[key] = count
    #|    if count > 1 {
    #|      errors.push(InputOccupied(edge.to, edge.to_port))
    #|    }
    #|  }
    #|  let entrypoints = graph.nodes
    #|    .filter(fn(node) { node.kind == "AppStart" })
    #|    .map(fn(node) { node.id })
    #|  if entrypoints.is_empty() {
    #|    errors.push(MissingEntrypoint)
    #|  }
    #|  let reachable = reachable_from(graph, entrypoints)
    #|  if !entrypoints.is_empty() {
    #|    for node in graph.nodes {
    #|      if !reachable.contains(node.id) {
    #|        errors.push(UnreachableNode(node.id))
    #|      }
    #|    }
    #|  }
    #|  if has_cycle(graph) {
    #|    errors.push(CycleDetected)
    #|  }
    #|  let confirmations = graph.nodes
    #|    .filter(fn(node) { node.kind == "UserConfirmation" })
    #|    .map(fn(node) { node.id })
    #|  let confirmed = reachable_from(graph, confirmations)
    #|  for node in graph.nodes {
    #|    match find_spec(specs, node.kind) {
    #|      Some(spec) =>
    #|        if spec.risk_class is ExternalSubmit {
    #|          // 精确闸门：外发节点必须从 UserConfirmation 积木的 approved 输出接线
    #|          // （数据路径上的显式授权），仅仅"图上可达"不够——确认节点挂在无关
    #|          // 支路上时不能放行外发。没有 approved 端口的外发积木（未来扩展）
    #|          // 退回可达性判定。
    #|          match find_input_port(spec, "approved") {
    #|            Some(_) => {
    #|              let wired = graph.edges.any(fn(edge) {
    #|                edge.to == node.id &&
    #|                edge.to_port == "approved" &&
    #|                confirmations.contains(edge.from)
    #|              })
    #|              if !wired {
    #|                errors.push(MissingConfirmation(node.id))
    #|              }
    #|            }
    #|            None =>
    #|              if !confirmed.contains(node.id) {
    #|                errors.push(MissingConfirmation(node.id))
    #|              }
    #|          }
    #|        }
    #|      None => ()
    #|    }
    #|  }
    #|  errors
    #|}
    #|
    #|///|
    #|/// 面向用户的中文校验错误描述。
    #|pub fn validation_error_label(error : ValidationError) -> String {
    #|  match error {
    #|    InvalidJson => "模型输出不是合法 JSON"
    #|    InvalidProject => "项目文件结构不完整或字段类型错误"
    #|    InvalidProposal => "提案结构不完整或字段类型错误"
    #|    FormatMismatch(actual) =>
    #|      "文件格式不受支持（需要 moblocks.project v1，实际为 \{actual}）"
    #|    UnsupportedVersion => "版本不受支持（需要 version = 1）"
    #|    UnknownKind(kind) => "未知积木类型：\{kind}"
    #|    DuplicateNodeId(id) => "节点 id 重复：#\{id}"
    #|    EdgeMissingEndpoint(from, to) =>
    #|      "连线端点不存在：#\{from} → #\{to}"
    #|    UnknownPort(node, port) => "节点 #\{node} 上不存在端口 \{port}"
    #|    UnknownConfigKey(node, key) =>
    #|      "节点 #\{node} 的配置 \{key} 不在 schema 中"
    #|    BadConfigValue(node, key) =>
    #|      "节点 #\{node} 的配置 \{key} 值类型不符"
    #|    TypeMismatch(from, from_port, to, to_port, out_type, in_type) =>
    #|      "连线类型不匹配：#\{from}.\{from_port}(\{port_type_label(out_type)}) → #\{to}.\{to_port}(\{port_type_label(in_type)})"
    #|    InputOccupied(node, port) =>
    #|      "节点 #\{node} 的输入 \{port} 已被占用（单输入占用规则）"
    #|    MissingEntrypoint => "缺少入口积木（应用启动）"
    #|    UnreachableNode(id) => "节点不可达：#\{id}"
    #|    CycleDetected => "图中存在环"
    #|    NodeBudgetExceeded(count) =>
    #|      "节点数超出预算：\{count} > \{max_nodes()}"
    #|    EdgeBudgetExceeded(count) =>
    #|      "连线数超出预算：\{count} > \{max_edges()}"
    #|    IterationBudgetExceeded(id) => "节点 #\{id} 的遍历上限超出预算"
    #|    MissingConfirmation(id) =>
    #|      "数据外发积木缺少人工确认闸门：#\{id}（需从「人工确认」积木的 approved 端口连线）"
    #|  }
    #|}
    #|
    #|///|
    #|pub fn port_type_label(port_type : PortType) -> String {
    #|  match port_type {
    #|    Text => "文本"
    #|    Number => "数字"
    #|    Bool => "布尔"
    #|    Json => "JSON"
    #|    FileRef => "文件"
    #|    Table => "表格"
    #|    ChatMessage => "对话消息"
    #|    ToolResult => "工具结果"
    #|    Unit => "执行流"
    #|  }
    #|}
    #|
  source
}
