///|
/// 导出的领域内核源码：`app/block_graph.mbt` 的逐字节副本。
/// 由 tools/sync_kernel 生成，勿手改；与源文件不一致时
/// `tools/sync_kernel -- --check` 会报 DRIFT。

///|
pub fn kernel_block_graph() -> String {
  let source =
    #|///|
    #|/// 积木端口类型：比赛版固定集合，不做用户自定义泛型。
    #|pub(all) enum PortType {
    #|  Text
    #|  Number
    #|  Bool
    #|  Json
    #|  FileRef
    #|  Table
    #|  ChatMessage
    #|  ToolResult
    #|  Unit
    #|}
    #|
    #|///|
    #|/// 端口规格名称 + 类型。类型相同的端口之间才允许连线。
    #|pub(all) struct PortSpec {
    #|  name : String
    #|  port_type : PortType
    #|}
    #|
    #|///|
    #|/// 配置值规格：应用侧属性表单按此渲染与校验。
    #|pub(all) enum ConfigType {
    #|  CfgString
    #|  CfgNumber
    #|  CfgBool
    #|}
    #|
    #|///|
    #|pub(all) struct ConfigSpec {
    #|  key : String
    #|  label : String
    #|  value_type : ConfigType
    #|  default : String
    #|}
    #|
    #|///|
    #|/// 图中的一个积木节点。坐标为画布本地坐标（左上角原点）。
    #|pub(all) struct BlockNode {
    #|  id : Int
    #|  kind : String
    #|  title : String
    #|  x : Double
    #|  y : Double
    #|  config : Array[(String, String)]
    #|}
    #|
    #|///|
    #|/// 一条有向连线：from 输出端口流向 to 输入端口。
    #|pub(all) struct BlockEdge {
    #|  from : Int
    #|  from_port : String
    #|  to : Int
    #|  to_port : String
    #|}
    #|
    #|///|
    #|/// 积木图。plain data；所有编辑经 typed Msg 进 reducer。
    #|pub(all) struct BlockGraph {
    #|  nodes : Array[BlockNode]
    #|  edges : Array[BlockEdge]
    #|  next_id : Int
    #|}
    #|
    #|///|
    #|pub fn BlockGraph::empty() -> BlockGraph {
    #|  { nodes: [], edges: [], next_id: 1, }
    #|}
    #|
    #|///|
    #|pub fn BlockGraph::find_node(self : BlockGraph, id : Int) -> BlockNode? {
    #|  for node in self.nodes {
    #|    if node.id == id {
    #|      return Some(node)
    #|    }
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|pub fn BlockGraph::add_node(
    #|  self : BlockGraph,
    #|  kind : String,
    #|  title : String,
    #|  x : Double,
    #|  y : Double,
    #|) -> BlockGraph {
    #|  let node : BlockNode = { id: self.next_id, kind, title, x, y, config: [], }
    #|  { nodes: [..self.nodes, node], edges: self.edges, next_id: self.next_id + 1, }
    #|}
    #|
    #|///|
    #|pub fn BlockGraph::move_node(
    #|  self : BlockGraph,
    #|  id : Int,
    #|  x : Double,
    #|  y : Double,
    #|) -> BlockGraph {
    #|  let nodes = self.nodes.map(fn(node) {
    #|    if node.id == id {
    #|      { ..node, x, y, }
    #|    } else {
    #|      node
    #|    }
    #|  })
    #|  { ..self, nodes, }
    #|}
    #|
    #|///|
    #|/// 数据端口之外的标准流控制：每个非入口积木有 trigger 输入与 flow 输出，
    #|/// 执行顺序即 flow 链的拓扑序；数据端口单独类型检查。
    #|pub fn flow_in_port() -> String {
    #|  "trigger"
    #|}
    #|
    #|///|
    #|pub fn flow_out_port() -> String {
    #|  "flow"
    #|}
    #|
    #|///|
    #|pub fn add_flow_edge(graph : BlockGraph, from : Int, to : Int) -> BlockGraph {
    #|  {
    #|    ..graph,
    #|    edges: [
    #|      ..graph.edges,
    #|      { from, from_port: flow_out_port(), to, to_port: flow_in_port(), },
    #|    ],
    #|  }
    #|}
    #|
    #|///|
    #|/// 按入口 BFS 深度做分层自动布局：x 按层推进，同层按序纵向排列。
    #|/// 属于领域内核（导出应用同样需要）：提案/project 形状的图没有坐标时
    #|/// 由 project_codec 调用它布局，因此不能住在只有 Studio 才有的文件里。
    #|pub fn auto_layout(graph : BlockGraph) -> BlockGraph {
    #|  let depth : Map[Int, Int] = Map([], capacity=16)
    #|  let queue : Array[Int] = []
    #|  for node in graph.nodes {
    #|    if node.kind == "AppStart" {
    #|      depth[node.id] = 0
    #|      queue.push(node.id)
    #|    }
    #|  }
    #|  while !queue.is_empty() {
    #|    let id = queue.remove(0)
    #|    let d = depth.get(id).unwrap_or(0)
    #|    for edge in graph.edges {
    #|      if edge.from == id && depth.get(edge.to) is None {
    #|        depth[edge.to] = d + 1
    #|        queue.push(edge.to)
    #|      }
    #|    }
    #|  }
    #|  let counters : Map[Int, Int] = Map([], capacity=16)
    #|  let nodes = graph.nodes.map(fn(node) {
    #|    let d = depth.get(node.id).unwrap_or(0)
    #|    let row = counters.get(d).unwrap_or(0)
    #|    counters[d] = row + 1
    #|    {
    #|      ..node,
    #|      x: 60.0 + d.to_double() * 220.0,
    #|      y: 60.0 + row.to_double() * 110.0,
    #|    }
    #|  })
    #|  { ..graph, nodes, }
    #|}
    #|
  source
}
