///|
/// .moblocks.json v1：BlockProject 的磁盘/传输格式。
/// 编码对字段顺序、缩进与默认值展开稳定；解码严格拒绝未知格式与结构。
pub fn project_format() -> String {
  "moblocks.project"
}

///|
pub(all) struct ProjectMetadata {
  id : String
  name : String
  revision : Int
}

///|
pub(all) struct StudioViewport {
  x : Double
  y : Double
  zoom : Double
}

///|
/// 项目级权限策略：产品域设置，AI 提案不得覆盖。
pub(all) struct ProjectPolicy {
  require_confirmation : Bool
  allow_external_submit : Bool
  allow_file_read : Bool
  allow_file_write : Bool
}

///|
pub fn default_policy() -> ProjectPolicy {
  {
    require_confirmation: true,
    allow_external_submit: false,
    allow_file_read: true,
    allow_file_write: false,
  }
}

///|
pub(all) struct Project {
  metadata : ProjectMetadata
  graph : BlockGraph
  viewport : StudioViewport
  policy : ProjectPolicy
  template_origin : String
}

///|
pub fn Project::new(name : String, graph : BlockGraph) -> Project {
  {
    metadata: { id: "project", name, revision: 1, },
    graph,
    viewport: { x: 0.0, y: 0.0, zoom: 1.0, },
    policy: default_policy(),
    template_origin: "",
  }
}

///|
fn encode_config_entry(entry : (String, String)) -> Json {
  Json::array([Json::string(entry.0), Json::string(entry.1)])
}

///|
fn encode_node(node : BlockNode) -> Json {
  let object = Map([], capacity=16)
  object["id"] = Json::number(node.id.to_double())
  object["kind"] = Json::string(node.kind)
  object["title"] = Json::string(node.title)
  object["x"] = Json::number(node.x)
  object["y"] = Json::number(node.y)
  object["config"] = Json::array(node.config.map(encode_config_entry))
  Json::object(object)
}

///|
fn encode_edge(edge : BlockEdge) -> Json {
  Json::array([
    Json::number(edge.from.to_double()),
    Json::string(edge.from_port),
    Json::number(edge.to.to_double()),
    Json::string(edge.to_port),
  ])
}

///|
pub fn encode_project(project : Project) -> String {
  let root = Map([], capacity=16)
  root["format"] = Json::string(project_format())
  root["version"] = Json::number(1.0)
  let metadata = Map([], capacity=16)
  metadata["id"] = Json::string(project.metadata.id)
  metadata["name"] = Json::string(project.metadata.name)
  metadata["revision"] = Json::number(project.metadata.revision.to_double())
  root["metadata"] = Json::object(metadata)
  let graph = Map([], capacity=16)
  graph["nodes"] = Json::array(project.graph.nodes.map(encode_node))
  graph["edges"] = Json::array(project.graph.edges.map(encode_edge))
  graph["next_id"] = Json::number(project.graph.next_id.to_double())
  root["graph"] = Json::object(graph)
  let viewport = Map([], capacity=16)
  viewport["x"] = Json::number(project.viewport.x)
  viewport["y"] = Json::number(project.viewport.y)
  viewport["zoom"] = Json::number(project.viewport.zoom)
  root["viewport"] = Json::object(viewport)
  let policy = Map([], capacity=16)
  policy["require_confirmation"] = Json::boolean(
    project.policy.require_confirmation,
  )
  policy["allow_external_submit"] = Json::boolean(
    project.policy.allow_external_submit,
  )
  policy["allow_file_read"] = Json::boolean(project.policy.allow_file_read)
  policy["allow_file_write"] = Json::boolean(project.policy.allow_file_write)
  root["policy"] = Json::object(policy)
  root["template_origin"] = Json::string(project.template_origin)
  Json::object(root).stringify(indent=2)
}

///|
fn decode_number(value : Json, fallback : Double) -> Double {
  match value {
    Number(n, ..) => n
    _ => fallback
  }
}

///|
fn decode_string_list(value : Json) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  match value {
    Array(items) =>
      for item in items {
        match item {
          Array([String(key), String(value)]) => entries.push((key, value))
          _ => ()
        }
      }
    _ => ()
  }
  entries
}

///|
/// 严格解码：格式/版本/结构不符一律拒绝；解码成功保证完整可回编码。
pub fn decode_project(
  source : String,
  specs : Array[BlockSpec],
) -> Result[Project, Array[ValidationError]] {
  let payload = @json.parse(source) catch { _ => return Err([InvalidJson]) }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err([InvalidProject])
  }
  let format = match fields.get("format") {
    Some(String(text)) => text
    _ => ""
  }
  if format != project_format() {
    return Err([FormatMismatch(format)])
  }
  match fields.get("version") {
    Some(Number(n, ..)) => if n != 1.0 { return Err([UnsupportedVersion]) }
    _ => return Err([UnsupportedVersion])
  }
  let metadata = match fields.get("metadata") {
    Some(Object(metadata)) => metadata
    _ => return Err([InvalidProject])
  }
  let meta_id = match metadata.get("id") {
    Some(String(text)) => text
    _ => return Err([InvalidProject])
  }
  let meta_name = match metadata.get("name") {
    Some(String(text)) => text
    _ => return Err([InvalidProject])
  }
  let revision = match metadata.get("revision") {
    Some(Number(n, ..)) => n.to_int()
    _ => 1
  }
  let graph_fields = match fields.get("graph") {
    Some(Object(graph_fields)) => graph_fields
    _ => return Err([InvalidProject])
  }
  let node_values = match graph_fields.get("nodes") {
    Some(Array(values)) => values
    _ => return Err([InvalidProject])
  }
  let edge_values = match graph_fields.get("edges") {
    Some(Array(values)) => values
    _ => return Err([InvalidProject])
  }
  let next_id = match graph_fields.get("next_id") {
    Some(Number(n, ..)) => n.to_int()
    _ => 1
  }
  let nodes : Array[BlockNode] = []
  let mut max_id = 0
  let mut has_coordinates = false
  for value in node_values {
    match value {
      Object(item) => {
        let id = match item.get("id") {
          Some(Number(n, ..)) => n.to_int()
          _ => return Err([InvalidProject])
        }
        let kind = match item.get("kind") {
          Some(String(text)) => text
          _ => return Err([InvalidProject])
        }
        let title = match item.get("title") {
          Some(String(text)) => text
          _ =>
            match find_spec(specs, kind) {
              Some(spec) => spec.title
              None => kind
            }
        }
        let x = match item.get("x") {
          Some(v) => {
            has_coordinates = true
            decode_number(v, 0.0)
          }
          None => 0.0
        }
        let y = match item.get("y") {
          Some(v) => {
            has_coordinates = true
            decode_number(v, 0.0)
          }
          None => 0.0
        }
        let config = match item.get("config") {
          Some(v) => decode_string_list(v)
          None => []
        }
        if id > max_id {
          max_id = id
        }
        nodes.push({ id, kind, title, x, y, config, })
      }
      _ => return Err([InvalidProject])
    }
  }
  let edges : Array[BlockEdge] = []
  for value in edge_values {
    match value {
      Array(
        [Number(from, ..), String(from_port), Number(to, ..), String(to_port)]
      ) =>
        edges.push({ from: from.to_int(), from_port, to: to.to_int(), to_port, })
      _ => return Err([InvalidProject])
    }
  }
  let viewport = match fields.get("viewport") {
    Some(Object(vp)) =>
      {
        x: decode_number(vp.get("x").unwrap_or(Json::number(0.0)), 0.0),
        y: decode_number(vp.get("y").unwrap_or(Json::number(0.0)), 0.0),
        zoom: decode_number(vp.get("zoom").unwrap_or(Json::number(1.0)), 1.0),
      }
    _ => { x: 0.0, y: 0.0, zoom: 1.0, }
  }
  let policy = match fields.get("policy") {
    Some(Object(pf)) => {
      let flag = fn(key : String, fallback : Bool) -> Bool {
        match pf.get(key) {
          Some(True) => true
          Some(False) => false
          _ => fallback
        }
      }
      let defaults = default_policy()
      {
        require_confirmation: flag(
          "require_confirmation",
          defaults.require_confirmation,
        ),
        allow_external_submit: flag(
          "allow_external_submit",
          defaults.allow_external_submit,
        ),
        allow_file_read: flag("allow_file_read", defaults.allow_file_read),
        allow_file_write: flag("allow_file_write", defaults.allow_file_write),
      }
    }
    _ => default_policy()
  }
  let template_origin = match fields.get("template_origin") {
    Some(String(text)) => text
    _ => ""
  }
  // 提案形状的项目（节点不带坐标）解码后按入口深度自动布局：否则所有节点
  // 会叠在原点。带坐标的项目（Studio 保存/导出的）原样保留，不做重排。
  let graph = if has_coordinates {
    { nodes, edges, next_id, }
  } else {
    auto_layout({ nodes, edges, next_id, })
  }
  Ok({
    metadata: { id: meta_id, name: meta_name, revision, },
    graph,
    viewport,
    policy,
    template_origin,
  })
}
