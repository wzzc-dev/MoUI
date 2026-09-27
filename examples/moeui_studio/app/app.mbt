///|
/// Mo易 Studio 主应用：TEA 模型。
/// 三模式：设计（画布拖放 + 属性检查器）/ 代码（事件子程序编辑）/
/// 运行（真实控件 + 中文子程序解释执行）。
/// AI 提案走 MoBlocks 验证过的契约：模型只产 JSON，全量校验后待采纳。

///|
pub(all) enum Mode {
  Design
  Code
  Run
}

///|
pub(all) enum PropField {
  PropName
  PropText
  PropX
  PropY
  PropW
  PropH
}

///|
pub(all) enum DragState {
  DragIdle
  DraggingControl(Int, Double, Double) // 控件 id, 抓取点偏移（设计坐标）
}

///|
pub(all) struct Model {
  project : FormProject
  mode : Mode
  selection : Int?
  drag : DragState
  notice : String
  dirty : Bool
  editing_handler : (String, String)?
  run : RunSession?
  pending_proposal : FormProject?
  fake_provider : Bool
  /// 当前入口是否具备真实 provider 通道（native async worker）。
  real_provider_available : Bool
  provider_endpoint : String
  provider_key : String
  prompt_draft : String
}

///|
pub(all) enum Msg {
  SwitchMode(Mode)
  CanvasPress(Double, Double)
  CanvasDragTo(Double, Double)
  CanvasRelease(Double, Double)
  AddControl(ControlKind)
  DeleteSelected
  PropInput(Int, PropField, String)
  EditHandler(String, String)
  HandlerCodeInput(String, String, String)
  NewHandler(String, String)
  StartRun
  StopRun
  DismissMessage
  RunButtonClicked(String)
  RunHandler(String, String)
  RunTextChanged(String, String)
  GenerateFromPrompt
  AcceptProposal
  CancelProposal
  ToggleProviderMode
  ProviderEndpointInput(String)
  ProviderKeyInput(String)
  PromptInput(String)
  RealGenerationFinished(Result[String, String])
  NewProject
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
pub fn Model::new() -> Model {
  {
    project: sample_project(),
    mode: Design,
    selection: None,
    drag: DragIdle,
    notice: "就绪：拖动控件布置窗体，切换到代码写中文子程序",
    dirty: false,
    editing_handler: None,
    run: None,
    pending_proposal: None,
    fake_provider: true,
    real_provider_available: false,
    provider_endpoint: "https://api.example.com/v1/chat/completions",
    provider_key: "",
    prompt_draft: default_prompt(),
  }
}

///|
pub fn default_prompt() -> String {
  "做一个加法计算器"
}

///|
fn mark_dirty(model : Model) -> Model {
  { ..model, dirty: true, }
}

///|
/// ---------- 项目不可变更新辅助 ----------

///|
fn project_with_controls(
  project : FormProject,
  controls : Array[FormControl],
) -> FormProject {
  { ..project, controls, }
}

///|
fn project_replace_control(
  project : FormProject,
  control : FormControl,
) -> FormProject {
  let controls = project.controls.map(fn(item) {
    if item.id == control.id {
      control
    } else {
      item
    }
  })
  project_with_controls(project, controls)
}

///|
fn project_remove_control(project : FormProject, id : Int) -> FormProject {
  let controls = project.controls.filter(fn(item) { item.id != id })
  let removed_names : Array[String] = []
  for control in project.controls {
    if control.id == id {
      removed_names.push(control.name)
    }
  }
  let handlers = project.handlers.filter(fn(handler) {
    !removed_names.contains(handler.control)
  })
  { ..project, controls, handlers, }
}

///|
/// 设置（或创建）事件子程序。
fn project_set_handler(
  project : FormProject,
  control : String,
  event : String,
  source : String,
) -> FormProject {
  let exists = project.handlers.any(fn(handler) {
    handler.control == control && handler.event == event
  })
  let handlers = if exists {
    project.handlers.map(fn(handler) {
      if handler.control == control && handler.event == event {
        { ..handler, source, }
      } else {
        handler
      }
    })
  } else {
    [..project.handlers, { control, event, source, }]
  }
  { ..project, handlers, }
}

///|
fn unique_control_name(project : FormProject, base : String) -> String {
  let mut index = 1
  while true {
    let candidate = "\{base}\{index}"
    if project.find_control_by_name(candidate) is None {
      return candidate
    }
    index = index + 1
  }
  base
}

///|
fn default_size(kind : ControlKind) -> (Double, Double) {
  match kind {
    Button => (120.0, 40.0)
    Label => (160.0, 36.0)
    TextField => (180.0, 36.0)
  }
}

///|
/// ---------- 设计画布交互 ----------

///|
fn clamp_design_x(x : Double, width : Double) -> Double {
  if x < 0.0 {
    0.0
  } else if x > design_width - width {
    (design_width - width).max(0.0)
  } else {
    x
  }
}

///|
fn clamp_design_y(y : Double, height : Double) -> Double {
  if y < 0.0 {
    0.0
  } else if y > design_height - height {
    (design_height - height).max(0.0)
  } else {
    y
  }
}

///|
fn apply_prop_input(
  model : Model,
  id : Int,
  field : PropField,
  input : String,
) -> Model {
  match model.project.find_control(id) {
    None => model
    Some(control) => {
      let control = match field {
        PropName =>
          if control_name_valid(input) &&
            (
              model.project.find_control_by_name(input) is None ||
              input == control.name
            ) {
            { ..control, name: input, }
          } else {
            return {
              ..model,
              notice: "名称「\{input}」不可用（非空、无空白、不重名）",
            }
          }
        PropText => { ..control, text: input, }
        PropX =>
          match text_to_number(input) {
            Some(value) =>
              { ..control, x: clamp_design_x(value, control.width), }
            None => return model
          }
        PropY =>
          match text_to_number(input) {
            Some(value) =>
              { ..control, y: clamp_design_y(value, control.height), }
            None => return model
          }
        PropW =>
          match text_to_number(input) {
            Some(value) => { ..control, width: value.max(20.0), }
            None => return model
          }
        PropH =>
          match text_to_number(input) {
            Some(value) => { ..control, height: value.max(20.0), }
            None => return model
          }
      }
      {
        ..mark_dirty(model),
        project: project_replace_control(model.project, control),
      }
    }
  }
}

///|
/// ---------- 运行 ----------

///|
fn run_event(model : Model, control : String, event : String) -> Model {
  let session = match model.run {
    Some(session) => session
    None => RunSession::start(model.project)
  }
  match model.project.handler_of(control, event) {
    Some(source) =>
      match session.run_source(source) {
        Ok(next) =>
          { ..model, run: Some(next), notice: "\{control}.\{event} 已执行", }
        Err(error) =>
          {
            ..model,
            notice: "运行错误（\{control}.\{event} 行 \{error.line()}）：\{error.message()}",
          }
      }
    None => { ..model, notice: "控件 \{control} 没有 \{event} 子程序", }
  }
}

///|
/// ---------- 代码编辑 ----------

///|
fn starter_source(event : String) -> String {
  match event {
    "被单击" => "信息框(\"你好！\")"
    "内容改变" => ""
    _ => ""
  }
}

///|
/// ---------- AI 提案 ----------

///|
fn accept_proposal(model : Model) -> Model {
  match model.pending_proposal {
    Some(proposal) =>
      {
        ..mark_dirty(model),
        project: { ..proposal, next_id: proposal.next_id, },
        selection: None,
        pending_proposal: None,
        editing_handler: None,
        mode: Design,
        notice: "已采纳 AI 提案：\{proposal.name}（\{proposal.controls.length()} 个控件 / \{proposal.handlers.length()} 个子程序）",
      }
    None => model
  }
}

///|
fn validation_summary_text(errors : Array[FormError]) -> String {
  validation_summary(errors)
}

///|
/// ---------- update ----------

///|
/// 纯状态转移；文件对话框副作用在 update_with_services 中。
pub fn update_pure(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match msg {
    SwitchMode(mode) => {
      let model = match mode {
        Run => { ..model, mode, run: Some(RunSession::start(model.project)), }
        _ =>
          match model.mode {
            Run => { ..model, mode, run: None, }
            _ => { ..model, mode, }
          }
      }
      no_effect(model)
    }
    CanvasPress(x, y) =>
      match hit_test_control(model.project.controls, x, y) {
        Some(control) =>
          no_effect({
            ..model,
            selection: Some(control.id),
            drag: DraggingControl(control.id, control.x - x, control.y - y),
          })
        None => no_effect({ ..model, selection: None, drag: DragIdle, })
      }
    CanvasDragTo(x, y) =>
      match model.drag {
        DraggingControl(id, offset_x, offset_y) =>
          match model.project.find_control(id) {
            Some(control) => {
              let moved = {
                ..control,
                x: clamp_design_x(x + offset_x, control.width),
                y: clamp_design_y(y + offset_y, control.height),
              }
              no_effect(
                mark_dirty_with({
                  ..model,
                  project: project_replace_control(model.project, moved),
                }),
              )
            }
            None => no_effect(model)
          }
        DragIdle => no_effect(model)
      }
    CanvasRelease(_, _) => no_effect({ ..model, drag: DragIdle, })
    AddControl(kind) => {
      let count = model.project.controls.length()
      let (width, height) = default_size(kind)
      let control : FormControl = {
        id: model.project.next_id,
        name: unique_control_name(model.project, kind.label()),
        kind,
        x: clamp_design_x(60.0 + (count % 5).to_double() * 36.0, width),
        y: clamp_design_y(60.0 + (count % 5).to_double() * 36.0, height),
        width,
        height,
        text: "",
      }
      let project = project_with_controls(
        model.project,
        [..model.project.controls, control],
      )
      no_effect(
        mark_dirty_with({
          ..model,
          project: { ..project, next_id: model.project.next_id + 1, },
          selection: Some(control.id),
          notice: "已添加 \{kind.label()}：\{control.name}",
        }),
      )
    }
    DeleteSelected =>
      match model.selection {
        Some(id) =>
          no_effect(
            mark_dirty_with({
              ..model,
              project: project_remove_control(model.project, id),
              selection: None,
              notice: "已删除控件",
            }),
          )
        None => no_effect(model)
      }
    PropInput(id, field, input) =>
      no_effect(apply_prop_input(model, id, field, input))
    EditHandler(control, event) =>
      no_effect({
        ..model,
        mode: Code,
        editing_handler: Some((control, event)),
      })
    HandlerCodeInput(control, event, source) =>
      no_effect(
        mark_dirty_with({
          ..model,
          project: project_set_handler(model.project, control, event, source),
        }),
      )
    NewHandler(control, event) =>
      no_effect(
        mark_dirty_with({
          ..model,
          project: project_set_handler(
            model.project,
            control,
            event,
            starter_source(event),
          ),
          editing_handler: Some((control, event)),
          mode: Code,
          notice: "已创建子程序 \{control}.\{event}",
        }),
      )
    StartRun =>
      no_effect({
        ..model,
        mode: Run,
        run: Some(RunSession::start(model.project)),
        notice: "运行中：点击按钮或修改输入框触发子程序",
      })
    StopRun => no_effect({ ..model, mode: Design, run: None, })
    DismissMessage =>
      match model.run {
        Some(session) =>
          no_effect({ ..model, run: Some(session.clear_message()), })
        None => no_effect(model)
      }
    RunButtonClicked(name) => no_effect(run_event(model, name, "被单击"))
    RunHandler(control, event) => no_effect(run_event(model, control, event))
    RunTextChanged(name, text) => {
      // 先更新实时文本，再触发 内容改变 子程序（若存在）
      let session = match model.run {
        Some(session) => session.set_text(name, text)
        None => RunSession::start(model.project).set_text(name, text)
      }
      let model = { ..model, run: Some(session), }
      match model.project.handler_of(name, "内容改变") {
        Some(_) => no_effect(run_event(model, name, "内容改变"))
        None => no_effect(model)
      }
    }
    GenerateFromPrompt =>
      match fake_generate_from_prompt(model.prompt_draft) {
        Ok(proposal) =>
          no_effect({
            ..model,
            pending_proposal: Some(proposal),
            notice: "AI 提案就绪（\{proposal.controls.length()} 控件 / \{proposal.handlers.length()} 子程序），校验通过",
          })
        Err(errors) =>
          no_effect({
            ..model,
            notice: "提案被拒绝：\{validation_summary_text(errors)}",
          })
      }
    AcceptProposal => no_effect(accept_proposal(model))
    CancelProposal =>
      no_effect({
        ..model,
        pending_proposal: None,
        notice: "已取消 AI 提案",
      })
    ToggleProviderMode =>
      if !model.fake_provider {
        no_effect({
          ..model,
          fake_provider: true,
          notice: "已切换到假模型（离线）",
        })
      } else if !model.real_provider_available {
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
    PromptInput(prompt) => no_effect({ ..model, prompt_draft: prompt, })
    RealGenerationFinished(result) =>
      match result {
        Ok(text) =>
          match finish_real_generation(text) {
            Ok(proposal) =>
              no_effect({
                ..model,
                pending_proposal: Some(proposal),
                notice: "真实 provider 提案就绪，校验通过",
              })
            Err(errors) =>
              no_effect({
                ..model,
                notice: "provider 提案被拒绝：\{validation_summary_text(errors)}",
              })
          }
        Err(reason) =>
          no_effect({ ..model, notice: "provider 调用失败：\{reason}", })
      }
    NewProject =>
      no_effect(
        mark_dirty_with({
          ..model,
          project: FormProject::empty(),
          selection: None,
          editing_handler: None,
          pending_proposal: None,
          notice: "已新建空项目",
        }),
      )
    // 文件对话框流程在 update_with_services 处理
    SaveRequested
    | SavePathPicked(_)
    | SaveCompleted(_)
    | OpenRequested
    | OpenPathPicked(_)
    | OpenReadCompleted(_) => no_effect(model)
  }
}

///|
fn mark_dirty_with(model : Model) -> Model {
  mark_dirty(model)
}

///|
pub fn join_path(dir : String, relative : String) -> String {
  if dir.has_suffix("/") {
    dir + relative
  } else {
    dir + "/" + relative
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
        title="保存 Mo易 项目",
        filters=["json"],
        default_name=Some("project.moeui.json"),
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
            .write_text(path, encode_project(model.project))
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
            { ..model, dirty: false, notice: "已保存为 .moeui.json", },
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
        title="打开 Mo易 项目",
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
    OpenReadCompleted(result) =>
      match result {
        Success(text) =>
          match decode_project(text) {
            Ok(project) =>
              (
                {
                  ..model,
                  project,
                  selection: None,
                  editing_handler: None,
                  pending_proposal: None,
                  run: None,
                  mode: Design,
                  dirty: false,
                  notice: "已打开 \{project.name}（\{project.controls.length()} 个控件）",
                },
                @moui.Effect::none(),
              )
            Err(errors) =>
              (
                {
                  ..model,
                  notice: "项目被拒绝：\{validation_summary_text(errors)}",
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
/// no-op provider 提交（Web 等无 async worker 的入口使用）。
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
  )
}
