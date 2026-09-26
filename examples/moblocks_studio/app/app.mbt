///|

///|
pub(all) struct Model {
  editor : GraphEditor
  selection : Int?
  pending_proposal : PendingProposal?
  viewport_x : Double
  viewport_y : Double
  viewport_zoom : Double
  drag : DragState
  execution : ExecutionState
  notice : String
  project_name : String
  dirty : Bool
  fake_provider : Bool
  /// 当前入口是否具备真实 provider 通道（native async worker）。
  /// Web 入口为 false：无 async HTTP，切换真实模式会被拒绝并提示。
  real_provider_available : Bool
  provider_endpoint : String
  provider_key : String
  prompt_draft : String
}

///|
/// 自动推进：连续 StepOk 直到状态离开 Running（等待确认/完成/失败/取消）。
fn auto_advance(
  state : ExecutionState,
  specs : Array[BlockSpec],
) -> ExecutionState {
  let mut current = state
  let mut ticks = 0
  while current.status is Running && ticks < 200 {
    current = apply_exec_event(current, StepOk, specs)
    ticks = ticks + 1
  }
  current
}

///|
/// 当前执行/等待确认步骤对应的积木 id（绿旗时刻聚光灯）。
fn spotlight_node(execution : ExecutionState) -> Int? {
  if execution.cursor < execution.steps.length() {
    match execution.steps[execution.cursor].status {
      Running => Some(execution.steps[execution.cursor].node_id)
      WaitingConfirmation => Some(execution.steps[execution.cursor].node_id)
      _ => None
    }
  } else {
    None
  }
}

///|
pub(all) enum DragState {
  DragIdle
  DraggingNode(Int, Double, Double)
  Panning(Double, Double, Double, Double)
}

///|
pub(all) struct PendingProposal {
  graph : BlockGraph
  nodes : Int
  edges : Int
}

///|
pub(all) enum Msg {
  CanvasPress(Double, Double)
  CanvasDragTo(Double, Double)
  CanvasRelease(Double, Double)
  CanvasNop
  AddBlock(String)
  SelectNode(Int?)
  ApplyEdit(GraphEdit)
  UndoEdit
  RedoEdit
  DeleteSelected
  TitleInput(Int, String)
  ConfigInput(Int, String, String)
  ConnectTo(Int, String, Int, String)
  DropEdge(Int, String, Int, String)
  GenerateFromPrompt
  AcceptProposal
  CancelProposal
  RunExecution
  AutoRunExecution
  StepOk
  StepFail(String)
  ExecTick(Int)
  ConfirmExecution
  RejectExecution
  CancelExecution
  ResetExecution
  PromptInput(String)
  ZoomIn
  ZoomOut
  ZoomReset
  ProjectNameInput(String)
  NewProject
  LoadTemplate(String)
  ToggleProviderMode
  ProviderEndpointInput(String)
  ProviderKeyInput(String)
  RealGenerationFinished(Result[String, String])
  ExportRequested
  ExportDirPicked(@services.ServiceTaskResult[String])
  ExportFileWritten(@services.ServiceTaskResult[Unit])
  SaveRequested
  SavePathPicked(@services.ServiceTaskResult[String])
  SaveCompleted(@services.ServiceTaskResult[Unit])
  OpenRequested
  OpenPathPicked(@services.ServiceTaskResult[String])
  OpenReadCompleted(@services.ServiceTaskResult[String])
}

///|
fn no_effect(model : Model) -> (Model, @moui.Effect[Msg]) {
  (model, @moui.Effect::none())
}

///|
/// M0 初始图：覆盖全部 17 种积木的 20 节点链，用于画布帧基线探针。
/// 确认节点同时向全部外发积木的 approved 端口连线（精确闸门：样例图必须合法）。
fn sample_graph() -> BlockGraph {
  let kinds = [
    "AppStart", "UserPrompt", "UserConfirmation", "PromptTemplate", "ConversationMemory",
    "ModelCall", "StructuredModelCall", "ParseJson", "IfElse", "ShowMarkdown", "FileSelected",
    "ForEach", "Sequence", "Retry", "Timeout", "CatchError", "ShowTable", "ModelCall",
    "StructuredModelCall", "ShowMarkdown",
  ]
  let specs = block_catalog()
  let mut graph = BlockGraph::empty()
  let ids : Array[Int] = []
  let mut i = 0
  while i < kinds.length() {
    let kind = kinds[i]
    let title = match find_spec(specs, kind) {
      Some(spec) => spec.title
      None => kind
    }
    let x = 60.0 + (i % 4).to_double() * 190.0
    let y = 60.0 + (i / 4).to_double() * 110.0
    // 显式跟踪分配到的 id：不依赖 "id == 下标+1" 的隐式约定，
    // kinds 列表调整时连线与批准关系不会静默错位。
    let new_id = graph.next_id
    graph = graph.add_node(kind, title, x, y)
    ids.push(new_id)
    if i > 0 {
      graph = add_flow_edge(graph, ids[i - 1], ids[i])
    }
    i = i + 1
  }
  // 外发积木（ModelCall / StructuredModelCall）从人工确认节点取批准直连
  let confirm_id = ids[2]
  let mut j = 0
  while j < kinds.length() {
    if kinds[j] == "ModelCall" || kinds[j] == "StructuredModelCall" {
      graph = {
        ..graph,
        edges: [
          ..graph.edges,
          BlockEdge::{
            from: confirm_id,
            from_port: "approved",
            to: ids[j],
            to_port: "approved",
          },
        ],
      }
    }
    j = j + 1
  }
  graph
}

///|
pub fn Model::new() -> Model {
  {
    editor: GraphEditor::new(block_catalog(), sample_graph()),
    selection: None,
    pending_proposal: None,
    viewport_x: 0.0,
    viewport_y: 0.0,
    viewport_zoom: 1.0,
    drag: DragIdle,
    execution: ExecutionState::idle(),
    notice: "就绪：点选画布积木，或用 AI 生成对话机器人",
    project_name: "未命名项目",
    dirty: false,
    fake_provider: true,
    real_provider_available: false,
    provider_endpoint: "https://api.example.com/v1/chat/completions",
    provider_key: "",
    prompt_draft: default_prompt(),
  }
}

///|
/// 默认提示词：与确定性假模型的旗舰案例一致，评审不改动也能直接生成。
pub fn default_prompt() -> String {
  "做一个能记住我、有人设的聊天应用"
}

///|
fn clamp_non_negative(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn clamp_zoom(zoom : Double) -> Double {
  if zoom < 0.25 {
    0.25
  } else if zoom > 4.0 {
    4.0
  } else {
    zoom
  }
}

///|
/// 屏幕（画布本地）坐标 → 图坐标。
fn screen_to_graph(model : Model, x : Double, y : Double) -> (Double, Double) {
  (
    x / model.viewport_zoom + model.viewport_x,
    y / model.viewport_zoom + model.viewport_y,
  )
}

///|
fn mark_dirty(model : Model) -> Model {
  { ..model, dirty: true, }
}

///|
fn apply_edit(model : Model, edit : GraphEdit) -> Model {
  match GraphEditor::apply(model.editor, edit) {
    Some(editor) =>
      {
        ..mark_dirty(model),
        editor,
        selection: selection_after(model, edit, editor.graph),
      }
    None =>
      { ..model, notice: "编辑被拒绝：\{edit_reject_reason(edit)}", }
  }
}

///|
fn selection_after(
  model : Model,
  edit : GraphEdit,
  updated : BlockGraph,
) -> Int? {
  match edit {
    DeleteNode(id) =>
      if model.selection == Some(id) {
        None
      } else {
        model.selection
      }
    AddNode(_, _, _) => Some(updated.next_id - 1)
    _ => model.selection
  }
}

///|
fn edit_reject_reason(edit : GraphEdit) -> String {
  match edit {
    AddNode(kind, _, _) => "未知积木类型 \{kind}"
    AddEdge(_, from_port, _, _) =>
      "端口 \{from_port} 不存在、目标输入已占用或重复连线"
    AddFlowEdge(_, _) => "重复连线或端点无效"
    DeleteNode(_) => "节点不存在"
    DeleteEdge(_, _, _, _) => "连线不存在"
    MoveNode(id, _, _) => "节点 #\{id} 不存在"
    SetNodeTitle(_, _) => "节点不存在或标题为空"
    SetConfig(_, key, _) => "节点不存在或配置 \{key} 不在 schema 中"
    ClearConfig(_, _) => "节点或配置不存在"
  }
}

///|
fn apply_graph(model : Model, graph : BlockGraph) -> Model {
  {
    ..mark_dirty(model),
    editor: GraphEditor::new(block_catalog(), graph),
    selection: None,
    pending_proposal: None,
    execution: ExecutionState::idle(),
    notice: "已采纳新图（\{graph.nodes.length()} 个积木），校验通过",
  }
}

///|
/// 纯状态转移；保存/打开等副作用在 update_with_services 中附加。
pub fn update_pure(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  let specs = block_catalog()
  match msg {
    CanvasPress(x, y) => {
      let (gx, gy) = screen_to_graph(model, x, y)
      match hit_test(GraphEditor::graph(model.editor), gx, gy) {
        Some(node) =>
          no_effect({
            ..model,
            selection: Some(node.id),
            drag: DraggingNode(node.id, node.x - gx, node.y - gy),
          })
        None =>
          no_effect({
            ..model,
            selection: None,
            drag: Panning(model.viewport_x, model.viewport_y, x, y),
          })
      }
    }
    CanvasDragTo(x, y) =>
      match model.drag {
        DraggingNode(id, offset_x, offset_y) => {
          let (gx, gy) = screen_to_graph(model, x, y)
          no_effect(
            apply_edit(
              model,
              MoveNode(
                id,
                clamp_non_negative(gx + offset_x),
                clamp_non_negative(gy + offset_y),
              ),
            ),
          )
        }
        Panning(origin_x, origin_y, anchor_x, anchor_y) =>
          no_effect({
            ..model,
            viewport_x: origin_x - (x - anchor_x) / model.viewport_zoom,
            viewport_y: origin_y - (y - anchor_y) / model.viewport_zoom,
          })
        DragIdle => no_effect(model)
      }
    CanvasRelease(_, _) => no_effect({ ..model, drag: DragIdle, })
    CanvasNop => no_effect(model)
    AddBlock(kind) =>
      match find_spec(specs, kind) {
        Some(spec) => {
          let count = GraphEditor::graph(model.editor).nodes.length()
          let x = 60.0 + (count % 4).to_double() * 190.0
          let y = 60.0 + (count / 4).to_double() * 110.0
          no_effect(apply_edit(model, AddNode(spec.kind, x, y)))
        }
        None => no_effect(model)
      }
    SelectNode(id) => no_effect({ ..model, selection: id, })
    ApplyEdit(edit) => no_effect(apply_edit(model, edit))
    UndoEdit =>
      no_effect({
        ..mark_dirty(model),
        editor: GraphEditor::undo(model.editor),
      })
    RedoEdit =>
      no_effect({
        ..mark_dirty(model),
        editor: GraphEditor::redo(model.editor),
      })
    DeleteSelected =>
      match model.selection {
        Some(id) => no_effect(apply_edit(model, DeleteNode(id)))
        None => no_effect(model)
      }
    TitleInput(id, title) =>
      no_effect(apply_edit(model, SetNodeTitle(id, title)))
    ConfigInput(id, key, value) =>
      no_effect(apply_edit(model, SetConfig(id, key, value)))
    ConnectTo(from, from_port, to, to_port) =>
      no_effect(apply_edit(model, AddEdge(from, from_port, to, to_port)))
    DropEdge(from, from_port, to, to_port) =>
      no_effect(apply_edit(model, DeleteEdge(from, from_port, to, to_port)))
    GenerateFromPrompt =>
      match fake_generate_from_prompt(model.prompt_draft, specs) {
        Ok(graph) =>
          no_effect({
            ..model,
            pending_proposal: Some(PendingProposal::{
              graph,
              nodes: graph.nodes.length(),
              edges: graph.edges.length(),
            }),
            notice: "AI 提案就绪（\{graph.nodes.length()} 积木 / \{graph.edges.length()} 连线），等待接受",
          })
        Err(errors) =>
          no_effect({
            ..model,
            notice: "提案被拒绝：\{errors.length()} 个校验错误：\{validation_summary(errors)}",
          })
      }
    AcceptProposal =>
      match model.pending_proposal {
        Some(proposal) => no_effect(apply_graph(model, proposal.graph))
        None => no_effect(model)
      }
    CancelProposal =>
      no_effect({
        ..model,
        pending_proposal: None,
        notice: "已取消 AI 提案",
      })
    RunExecution | AutoRunExecution => {
      let errors = validate_graph(GraphEditor::graph(model.editor), specs)
      if errors.is_empty() {
        let started = apply_exec_event(
          start_execution(GraphEditor::graph(model.editor)),
          Start,
          specs,
        )
        // AutoRun：从起点连续推进到第一个阻塞点（等待确认/完成/失败）；
        // 普通 RunExecution 只启动，交给「前进一步」逐步调试。
        let running = if msg is AutoRunExecution {
          auto_advance(started, specs)
        } else {
          started
        }
        no_effect({
          ..model,
          execution: running,
          notice: if msg is AutoRunExecution {
            "已自动运行到阻塞点：\{run_status_label(running.status)}"
          } else {
            "运行开始"
          },
        })
      } else {
        no_effect({
          ..model,
          notice: "校验失败，已阻止运行：\{validation_summary(errors)}",
        })
      }
    }
    StepOk =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, StepOk, specs),
      })
    StepFail(reason) =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, StepFail(reason), specs),
      })
    ExecTick(delta_ms) =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, Tick(delta_ms), specs),
      })
    ConfirmExecution =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, Confirm, specs),
      })
    RejectExecution =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, Reject, specs),
      })
    CancelExecution =>
      no_effect({
        ..model,
        execution: apply_exec_event(model.execution, Cancel, specs),
      })
    ResetExecution => no_effect({ ..model, execution: ExecutionState::idle(), })
    ZoomIn =>
      no_effect({
        ..model,
        viewport_zoom: clamp_zoom(model.viewport_zoom * 1.25),
      })
    ZoomOut =>
      no_effect({
        ..model,
        viewport_zoom: clamp_zoom(model.viewport_zoom / 1.25),
      })
    ZoomReset =>
      no_effect({
        ..model,
        viewport_x: 0.0,
        viewport_y: 0.0,
        viewport_zoom: 1.0,
      })
    ProjectNameInput(name) =>
      no_effect({ ..model, project_name: name, dirty: true, })
    PromptInput(prompt) => no_effect({ ..model, prompt_draft: prompt, })
    NewProject => no_effect(new_project(model))
    LoadTemplate(name) => no_effect(load_template_project(model, name))
    ToggleProviderMode =>
      if !model.fake_provider {
        no_effect({
          ..model,
          fake_provider: true,
          notice: "已切换到假模型（离线）",
        })
      } else if !model.real_provider_available {
        // 无 async worker 的入口（Web）拒绝进入真实模式，避免提交后静默挂起
        no_effect({
          ..model,
          notice: "当前入口不支持真实 provider（无 async HTTP）；请使用 macOS 入口",
        })
      } else {
        no_effect({
          ..model,
          fake_provider: false,
          notice: "已切换到真实 provider：\{model.provider_endpoint}",
        })
      }
    ProviderEndpointInput(endpoint) =>
      no_effect({ ..model, provider_endpoint: endpoint, })
    ProviderKeyInput(key) => no_effect({ ..model, provider_key: key, })
    RealGenerationFinished(result) =>
      match result {
        Ok(text) =>
          match finish_real_generation(text, block_catalog()) {
            Ok(graph) =>
              no_effect({
                ..model,
                pending_proposal: Some(PendingProposal::{
                  graph,
                  nodes: graph.nodes.length(),
                  edges: graph.edges.length(),
                }),
                notice: "真实 provider 提案就绪（\{graph.nodes.length()} 积木 / \{graph.edges.length()} 连线），校验通过",
              })
            Err(errors) =>
              no_effect({
                ..model,
                notice: "provider 提案被拒绝：\{errors.length()} 个校验错误：\{validation_summary(errors)}",
              })
          }
        Err(reason) =>
          no_effect({ ..model, notice: "provider 调用失败：\{reason}", })
      }
    ExportRequested
    | ExportDirPicked(_)
    | ExportFileWritten(_)
    | SaveRequested
    | SavePathPicked(_)
    | SaveCompleted(_)
    | OpenRequested
    | OpenPathPicked(_)
    | OpenReadCompleted(_) => no_effect(model)
  }
}

///|
/// 目录 + 相对路径拼接（不用引入 path 包）。
pub fn join_path(dir : String, relative : String) -> String {
  if dir.has_suffix("/") {
    dir + relative
  } else {
    dir + "/" + relative
  }
}

///|
fn project_of(model : Model) -> Project {
  {
    metadata: { id: "project", name: model.project_name, revision: 1, },
    graph: GraphEditor::graph(model.editor),
    viewport: {
      x: model.viewport_x,
      y: model.viewport_y,
      zoom: model.viewport_zoom,
    },
    policy: default_policy(),
    template_origin: "",
  }
}

///|
/// 副作用版 update：保存/打开文件对话框与读写。
pub fn update_with_services(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    SaveRequested => {
      let options = @services.FileDialogOptions::new(
        title="保存 MoBlocks 项目",
        filters=["json"],
        default_name=Some("project.moblocks.json"),
      )
      (
        model,
        services.files().save_file(options~).effect(map=r => SavePathPicked(r)),
      )
    }
    SavePathPicked(result) =>
      match result {
        Success(path) =>
          (
            { ..model, notice: "正在写入 \{path}", },
            services
            .files()
            .write_text(path, encode_project(project_of(model)))
            .effect(map=r => SaveCompleted(r)),
          )
        Failure(error) =>
          (
            { ..model, notice: "保存失败：\{error.message}", },
            @moui.Effect::none(),
          )
        Cancelled =>
          ({ ..model, notice: "已取消保存", }, @moui.Effect::none())
      }
    SaveCompleted(result) =>
      match result {
        Success(_) =>
          (
            { ..model, dirty: false, notice: "已保存为 .moblocks.json", },
            @moui.Effect::none(),
          )
        Failure(error) =>
          (
            { ..model, notice: "保存失败：\{error.message}", },
            @moui.Effect::none(),
          )
        Cancelled =>
          ({ ..model, notice: "保存被取消", }, @moui.Effect::none())
      }
    OpenRequested => {
      let options = @services.FileDialogOptions::new(
        title="打开 MoBlocks 项目",
        filters=["json"],
      )
      (
        model,
        services.files().open_file(options~).effect(map=r => OpenPathPicked(r)),
      )
    }
    OpenPathPicked(result) =>
      match result {
        Success(path) =>
          (
            { ..model, notice: "正在读取 \{path}", },
            services
            .files()
            .read_text(path)
            .effect(map=r => OpenReadCompleted(r)),
          )
        Failure(error) =>
          (
            { ..model, notice: "打开失败：\{error.message}", },
            @moui.Effect::none(),
          )
        Cancelled =>
          ({ ..model, notice: "已取消打开", }, @moui.Effect::none())
      }
    ExportRequested => {
      let options = @services.FileDialogOptions::new(
        title="选择导出目录",
        filters=[],
      )
      (
        model,
        services
        .files()
        .pick_directory(options~)
        .effect(map=r => ExportDirPicked(r)),
      )
    }
    ExportDirPicked(result) =>
      match result {
        @services.ServiceTaskResult::Success(dir) => {
          let bundle = @export.export_bundle(
            encode_project(project_of(model)),
            model.project_name,
          )
          let effects : Array[@moui.Effect[Msg]] = []
          let mut index = 0
          while index < bundle.length() {
            let pair = bundle[index]
            let path = join_path(dir, pair.0)
            let content = pair.1
            effects.push(
              services
              .files()
              .write_text(path, content)
              .effect(map=r => ExportFileWritten(r)),
            )
            index = index + 1
          }
          (
            {
              ..model,
              notice: "正在导出 \{bundle.length()} 个文件到 \{dir}",
            },
            @moui.Effect::batch(effects),
          )
        }
        @services.ServiceTaskResult::Failure(error) =>
          (
            { ..model, notice: "导出失败：\{error.message}", },
            @moui.Effect::none(),
          )
        @services.ServiceTaskResult::Cancelled =>
          ({ ..model, notice: "已取消导出", }, @moui.Effect::none())
      }
    ExportFileWritten(result) =>
      match result {
        @services.ServiceTaskResult::Failure(error) =>
          (
            { ..model, notice: "导出写入失败：\{error.message}", },
            @moui.Effect::none(),
          )
        _ =>
          (
            {
              ..model,
              notice: "导出完成：按 README 运行 moon build <name>/web_wasm --target wasm-gc",
            },
            @moui.Effect::none(),
          )
      }
    OpenReadCompleted(result) =>
      match result {
        Success(text) =>
          match decode_project(text, block_catalog()) {
            Ok(project) =>
              (
                {
                  ..model,
                  project_name: project.metadata.name,
                  editor: GraphEditor::new(block_catalog(), project.graph),
                  selection: None,
                  execution: ExecutionState::idle(),
                  dirty: false,
                  notice: "已打开 \{project.metadata.name}（\{project.graph.nodes.length()} 个积木）",
                },
                @moui.Effect::none(),
              )
            Err(errors) =>
              (
                {
                  ..model,
                  notice: "项目被拒绝：\{errors.length()} 个校验错误：\{validation_summary(errors)}",
                },
                @moui.Effect::none(),
              )
          }
        Failure(error) =>
          (
            { ..model, notice: "读取失败：\{error.message}", },
            @moui.Effect::none(),
          )
        Cancelled =>
          ({ ..model, notice: "读取被取消", }, @moui.Effect::none())
      }
    _ => update_pure(model, msg)
  }
}

///|
fn validation_summary(errors : Array[ValidationError]) -> String {
  let mut text = ""
  let mut first = true
  for error in errors {
    if !first {
      text = text + "；"
    }
    first = false
    text = text + validation_error_label(error)
  }
  text
}

///|

///|
fn new_project(model : Model) -> Model {
  let mut graph = BlockGraph::empty()
  graph = graph.add_node("AppStart", "应用启动", 60.0, 60.0)
  {
    ..model,
    editor: GraphEditor::new(block_catalog(), graph),
    selection: None,
    pending_proposal: None,
    execution: ExecutionState::idle(),
    project_name: "未命名项目",
    notice: "已新建空项目：从工具箱添加积木，或用 AI 生成",
  }
}

///|
/// 加载内置模板（名称来自底部面板按钮）。
fn load_template_project(model : Model, name : String) -> Model {
  let source = match name {
    "chatbot" => template_chatbot_json()
    "doc" => template_doc_assistant_json()
    "csv" => template_csv_assistant_json()
    _ => ""
  }
  match decode_project(source, block_catalog()) {
    Ok(project) =>
      {
        ..mark_dirty(model),
        editor: GraphEditor::new(block_catalog(), project.graph),
        selection: None,
        pending_proposal: None,
        execution: ExecutionState::idle(),
        project_name: project.metadata.name,
        notice: "已加载模板：\{project.metadata.name}（\{project.graph.nodes.length()} 个积木）",
      }
    Err(errors) =>
      {
        ..model,
        notice: "模板加载失败：\{name}（\{errors.length()} 个校验错误）",
      }
  }
}

///|

///|
/// no-op provider 提交（Web 等无 async worker 的入口使用：真实模式降级为提示）。
fn noop_provider_submit(
  _endpoint : String,
  _key : String,
  _prompt : String,
  _on_result : (Result[String, String]) -> Unit,
) -> Unit {

}

///|
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  provider_submit? : (String, String, String, (Result[String, String]) -> Unit) -> Unit = noop_provider_submit,
  real_provider_available? : Bool = false,
) -> @moui.Program[Model, Msg] {
  // 服务句柄在 program 构造时捕获一次；update 里不再构造
  let services = environment.services()
  @moui.Program::new(
    init=() => {
      ({ ..Model::new(), real_provider_available, }, @moui.Effect::none())
    },
    update=(model, msg) => {
      match msg {
        GenerateFromPrompt =>
          if model.fake_provider {
            update_with_services(model, msg, services)
          } else {
            let endpoint = model.provider_endpoint
            let key = model.provider_key
            let prompt = model.prompt_draft
            (
              { ..model, notice: "正在请求真实 provider…", },
              @moui.Effect::dispatch(emit => {
                provider_submit(endpoint, key, prompt, result => {
                  emit(RealGenerationFinished(result))
                })
              }),
            )
          }
        _ => update_with_services(model, msg, services)
      }
    },
    view~,
    // 执行运行中的定时驱动：Tick 是执行状态机唯一的时间来源，
    // 让重试/超时预算在真实 UI 运行时生效（先例：three_d_physics_viewer）。
    // 状态离开 Running/WaitingConfirmation 后返回 none，定时器自动取消。
    subscriptions=model => {
      match environment.timer() {
        Some(timer) =>
          if model.execution.status
            is (RunStatus::Running | RunStatus::WaitingConfirmation) {
            timer.subscription(
              interval_ms=50.0,
              key="moblocks:exec-tick",
              label="MoBlocks execution tick",
              map=frame => ExecTick(frame.delta_ms.to_int()),
            )
          } else {
            @moui.Subscription::none()
          }
        None => @moui.Subscription::none()
      }
    },
  )
}
