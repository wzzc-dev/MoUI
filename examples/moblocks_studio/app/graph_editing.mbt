///|
/// 图编辑命令与撤销/重做（纯函数式：编辑返回新编辑器或 None 表示拒绝）。
/// 编辑层拒绝结构性非法操作（未知积木、未知端口、重复连线、未知配置键），
/// 其余交给校验器报告。

///|
pub(all) enum GraphEdit {
  AddNode(String, Double, Double)
  DeleteNode(Int)
  AddEdge(Int, String, Int, String)
  DeleteEdge(Int, String, Int, String)
  AddFlowEdge(Int, Int)
  MoveNode(Int, Double, Double)
  SetNodeTitle(Int, String)
  SetConfig(Int, String, String)
  ClearConfig(Int, String)
}

///|
pub(all) struct GraphEditor {
  graph : BlockGraph
  past : Array[BlockGraph]
  future : Array[BlockGraph]
  specs : Array[BlockSpec]
}

///|
pub fn GraphEditor::new(
  specs : Array[BlockSpec],
  graph : BlockGraph,
) -> GraphEditor {
  { graph, past: [], future: [], specs, }
}

///|
pub fn GraphEditor::graph(editor : GraphEditor) -> BlockGraph {
  editor.graph
}

///|
pub fn GraphEditor::can_undo(editor : GraphEditor) -> Bool {
  !editor.past.is_empty()
}

///|
pub fn GraphEditor::can_redo(editor : GraphEditor) -> Bool {
  !editor.future.is_empty()
}

///|
pub fn GraphEditor::undo_depth(editor : GraphEditor) -> Int {
  editor.past.length()
}

///|
fn push_history(editor : GraphEditor) -> GraphEditor {
  let mut past = editor.past
  past.push(editor.graph)
  if past.length() > 100 {
    let trimmed = Array(capacity=past.length() - 1)
    for i = 1; i < past.length(); i = i + 1 {
      trimmed.push(past[i])
    }
    past = trimmed
  }
  { ..editor, past, future: [], }
}

///|
fn accept(editor : GraphEditor, graph : BlockGraph) -> GraphEditor {
  { ..push_history(editor), graph, }
}

///|
fn spec_of(editor : GraphEditor, node : BlockNode) -> BlockSpec? {
  find_spec(editor.specs, node.kind)
}

///|
fn edge_exists(graph : BlockGraph, edge : BlockEdge) -> Bool {
  for existing in graph.edges {
    if existing.from == edge.from &&
      existing.from_port == edge.from_port &&
      existing.to == edge.to &&
      existing.to_port == edge.to_port {
      return true
    }
  }
  false
}

///|
fn with_config_defaults(spec : BlockSpec) -> Array[(String, String)] {
  spec.config_schema.map(fn(entry) { (entry.key, entry.default) })
}

///|
/// 执行一次编辑。None 表示编辑被拒绝（图不变）；Some 才入历史栈。
pub fn GraphEditor::apply(
  editor : GraphEditor,
  edit : GraphEdit,
) -> GraphEditor? {
  match edit {
    AddNode(kind, x, y) =>
      match find_spec(editor.specs, kind) {
        Some(spec) => {
          let node : BlockNode = {
            id: editor.graph.next_id,
            kind,
            title: spec.title,
            x,
            y,
            config: with_config_defaults(spec),
          }
          Some(
            accept(editor, {
              nodes: [..editor.graph.nodes, node],
              edges: editor.graph.edges,
              next_id: editor.graph.next_id + 1,
            }),
          )
        }
        None => None
      }
    DeleteNode(id) =>
      match editor.graph.find_node(id) {
        Some(_) =>
          Some(
            accept(editor, {
              nodes: editor.graph.nodes.filter(fn(node) { node.id != id }),
              edges: editor.graph.edges.filter(fn(edge) {
                edge.from != id && edge.to != id
              }),
              next_id: editor.graph.next_id,
            }),
          )
        None => None
      }
    AddEdge(from, from_port, to, to_port) => {
      let edge : BlockEdge = { from, from_port, to, to_port, }
      let input_taken = editor.graph.edges.any(fn(existing) {
        existing.to == edge.to && existing.to_port == edge.to_port
      })
      if from == to ||
        edge_exists(editor.graph, edge) ||
        input_taken ||
        editor.graph.find_node(from) is None ||
        editor.graph.find_node(to) is None {
        None
      } else {
        let from_ok = match editor.graph.find_node(from) {
          Some(node) =>
            match spec_of(editor, node) {
              Some(spec) => find_output_port(spec, from_port) is Some(_)
              None => false
            }
          None => false
        }
        let to_ok = match editor.graph.find_node(to) {
          Some(node) =>
            match spec_of(editor, node) {
              Some(spec) => find_input_port(spec, to_port) is Some(_)
              None => false
            }
          None => false
        }
        if from_ok && to_ok {
          Some(
            accept(editor, {
              nodes: editor.graph.nodes,
              edges: [..editor.graph.edges, edge],
              next_id: editor.graph.next_id,
            }),
          )
        } else {
          None
        }
      }
    }
    DeleteEdge(from, from_port, to, to_port) => {
      let edge : BlockEdge = { from, from_port, to, to_port, }
      if edge_exists(editor.graph, edge) {
        Some(
          accept(editor, {
            nodes: editor.graph.nodes,
            edges: editor.graph.edges.filter(fn(existing) {
              !(existing.from == edge.from &&
              existing.from_port == edge.from_port &&
              existing.to == edge.to &&
              existing.to_port == edge.to_port)
            }),
            next_id: editor.graph.next_id,
          }),
        )
      } else {
        None
      }
    }
    AddFlowEdge(from, to) =>
      if from == to ||
        edge_exists(editor.graph, {
          from,
          from_port: flow_out_port(),
          to,
          to_port: flow_in_port(),
        }) {
        None
      } else {
        GraphEditor::apply(
          editor,
          AddEdge(from, flow_out_port(), to, flow_in_port()),
        )
      }
    MoveNode(id, x, y) =>
      match editor.graph.find_node(id) {
        Some(_) => Some(accept(editor, editor.graph.move_node(id, x, y)))
        None => None
      }
    SetNodeTitle(id, title) =>
      match editor.graph.find_node(id) {
        Some(_) =>
          if title.is_empty() {
            None
          } else {
            let nodes = editor.graph.nodes.map(fn(node) {
              if node.id == id {
                { ..node, title, }
              } else {
                node
              }
            })
            Some(accept(editor, { ..editor.graph, nodes, }))
          }
        None => None
      }
    SetConfig(id, key, value) =>
      match editor.graph.find_node(id) {
        Some(node) =>
          match spec_of(editor, node) {
            Some(spec) =>
              if find_config_spec(spec, key) is None {
                None
              } else {
                let nodes = editor.graph.nodes.map(fn(n) {
                  if n.id != id {
                    n
                  } else {
                    let entries = n.config.filter(fn(entry) { entry.0 != key })
                    { ..n, config: [..entries, (key, value)], }
                  }
                })
                Some(accept(editor, { ..editor.graph, nodes, }))
              }
            None => None
          }
        None => None
      }
    ClearConfig(id, key) =>
      match editor.graph.find_node(id) {
        Some(node) =>
          if node.config.any(fn(entry) { entry.0 == key }) {
            let nodes = editor.graph.nodes.map(fn(n) {
              if n.id != id {
                n
              } else {
                { ..n, config: n.config.filter(fn(entry) { entry.0 != key }), }
              }
            })
            Some(accept(editor, { ..editor.graph, nodes, }))
          } else {
            None
          }
        None => None
      }
  }
}

///|
/// 撤销一步。历史为空时原样返回。
pub fn GraphEditor::undo(editor : GraphEditor) -> GraphEditor {
  if editor.past.is_empty() {
    editor
  } else {
    let last = editor.past.length() - 1
    let previous = editor.past[last]
    let past = Array(capacity=editor.past.length())
    for i = 0; i < editor.past.length() - 1; i = i + 1 {
      past.push(editor.past[i])
    }
    {
      graph: previous,
      past,
      future: [..editor.future, editor.graph],
      specs: editor.specs,
    }
  }
}

///|
/// 重做一步。重做栈为空时原样返回。
pub fn GraphEditor::redo(editor : GraphEditor) -> GraphEditor {
  if editor.future.is_empty() {
    editor
  } else {
    let last = editor.future.length() - 1
    let next = editor.future[last]
    let future = Array(capacity=editor.future.length())
    for i = 0; i < editor.future.length() - 1; i = i + 1 {
      future.push(editor.future[i])
    }
    {
      graph: next,
      past: [..editor.past, editor.graph],
      future,
      specs: editor.specs,
    }
  }
}
