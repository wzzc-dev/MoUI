///|
/// 导出的可执行 runner 源码（由 tools/sync_kernel 生成，勿手改）。
/// 模板位于 tools/export_runner_template/runner.mbt；
/// 模板改动不同步时 `--check` 会报 DRIFT。

///|
pub fn runner_source() -> String {
  let source =
    #|///|
    #|/// MoBlocks 导出的可执行应用。
    #|///
    #|/// 领域内核（block_graph/block_catalog/graph_validation/execution_reducer/
    #|/// project_codec）与 Studio 逐字节同源，因此执行语义一致：拓扑序推进、
    #|/// 重试/超时从上游积木推导、数据外发在人工确认处暂停。不确定的模型输出由
    #|/// 执行器的确定性摘要承担（离线可跑）；外发闸门是真实的按钮交互。
    #|
    #|///|
    #|using @views { button, column, scroll_view, text }
    #|
    #|///|
    #|pub(all) struct Model {
    #|  project_name : String
    #|  graph : BlockGraph
    #|  specs : Array[BlockSpec]
    #|  execution : ExecutionState
    #|  notice : String
    #|}
    #|
    #|///|
    #|pub fn Model::new() -> Model {
    #|  match decode_project(project_json(), block_catalog()) {
    #|    Ok(project) => {
    #|      let graph = project.graph
    #|      {
    #|        project_name: project.metadata.name,
    #|        graph,
    #|        specs: block_catalog(),
    #|        execution: ExecutionState::idle(),
    #|        notice: "项目已加载：" +
    #|          project.metadata.name +
    #|          "（" +
    #|          graph.nodes.length().to_string() +
    #|          " 积木 / " +
    #|          graph.edges.length().to_string() +
    #|          " 连线）",
    #|      }
    #|    }
    #|    Err(errors) => {
    #|      {
    #|        project_name: "（项目数据无法解析）",
    #|        graph: BlockGraph::empty(),
    #|        specs: block_catalog(),
    #|        execution: ExecutionState::idle(),
    #|        notice: "内嵌项目数据无效：" + errors.length().to_string() + " 个错误",
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub(all) enum Msg {
    #|  AutoRun
    #|  ConfirmExternal
    #|  RejectExternal
    #|  CancelRun
    #|  Reset
    #|}
    #|
    #|///|
    #|/// 自动推进：连续 StepOk 直到离开 Running（等待确认 / 完成 / 失败）。
    #|fn advance(
    #|  state : ExecutionState,
    #|  specs : Array[BlockSpec],
    #|) -> ExecutionState {
    #|  let mut current = state
    #|  let mut ticks = 0
    #|  while current.status is Running && ticks < 200 {
    #|    current = apply_exec_event(current, StepOk, specs)
    #|    ticks = ticks + 1
    #|  }
    #|  current
    #|}
    #|
    #|///|
    #|pub fn update(model : Model, msg : Msg) -> Model {
    #|  match msg {
    #|    AutoRun =>
    #|      if validate_graph(model.graph, model.specs).length() > 0 {
    #|        { ..model, notice: "校验失败，已阻止运行", }
    #|      } else {
    #|        let started = apply_exec_event(
    #|          start_execution(model.graph),
    #|          Start,
    #|          model.specs,
    #|        )
    #|        let running = advance(started, model.specs)
    #|        {
    #|          ..model,
    #|          execution: running,
    #|          notice: "已运行到阻塞点：" + run_status_label(running.status),
    #|        }
    #|      }
    #|    ConfirmExternal => {
    #|      let running = advance(
    #|        apply_exec_event(model.execution, Confirm, model.specs),
    #|        model.specs,
    #|      )
    #|      {
    #|        ..model,
    #|        execution: running,
    #|        notice: "已确认外发：" + run_status_label(running.status),
    #|      }
    #|    }
    #|    RejectExternal => {
    #|      let running = apply_exec_event(model.execution, Reject, model.specs)
    #|      {
    #|        ..model,
    #|        execution: running,
    #|        notice: "已拒绝外发：" + run_status_label(running.status),
    #|      }
    #|    }
    #|    CancelRun => {
    #|      let running = apply_exec_event(model.execution, Cancel, model.specs)
    #|      { ..model, execution: running, notice: "已取消运行", }
    #|    }
    #|    Reset =>
    #|      { ..model, execution: ExecutionState::idle(), notice: "已重置执行状态", }
    #|  }
    #|}
    #|
    #|///|
    #|/// 时间线行：状态标记 + 标题 + 耗时 + 截断摘要。
    #|fn timeline_rows(model : Model) -> Array[@moui.View[Msg]] {
    #|  let rows : Array[@moui.View[Msg]] = []
    #|  for step in model.execution.steps {
    #|    let mark = match step.status {
    #|      Completed => "✓"
    #|      Failed(_) => "✗"
    #|      Running => "▶"
    #|      _ => "·"
    #|    }
    #|    rows.push(
    #|      text(
    #|        mark + " " + step.title + " · " + step_status_label(step.status) + " · " + step.duration_ms.to_string() + "ms · " + step.summary,
    #|      ),
    #|    )
    #|  }
    #|  rows
    #|}
    #|
    #|///|
    #|/// 运行控制：闸门按钮只在等待确认时出现；取消/重置始终可用。
    #|fn run_controls(model : Model) -> Array[@moui.View[Msg]] {
    #|  let items : Array[@moui.View[Msg]] = []
    #|  if model.execution.status is WaitingConfirmation {
    #|    items.push(button("确认外发", on_click=ConfirmExternal))
    #|    items.push(button("拒绝外发", on_click=RejectExternal))
    #|  } else {
    #|    items.push(button("运行", on_click=AutoRun))
    #|  }
    #|  items.push(button("取消运行", on_click=CancelRun))
    #|  items.push(button("重置", on_click=Reset))
    #|  items
    #|}
    #|
    #|///|
    #|/// 审计留痕：执行器产出的 audit 行（外发确认/拒绝/重试/超时等安全事件）。
    #|fn audit_rows(model : Model) -> Array[@moui.View[Msg]] {
    #|  let rows : Array[@moui.View[Msg]] = []
    #|  for line in model.execution.audit {
    #|    rows.push(text("• " + line))
    #|  }
    #|  rows
    #|}
    #|
    #|///|
    #|pub fn view(model : Model) -> @moui.View[Msg] {
    #|  let items : Array[@moui.View[Msg]] = []
    #|  items.push(text(model.project_name).title())
    #|  items.push(text(model.notice))
    #|  for control in run_controls(model) {
    #|    items.push(control)
    #|  }
    #|  items.push(
    #|    text("运行时间线 · " + run_status_label(model.execution.status)).title(),
    #|  )
    #|  for row in timeline_rows(model) {
    #|    items.push(row)
    #|  }
    #|  if model.execution.audit.length() > 0 {
    #|    items.push(text("安全审计").title())
    #|    for row in audit_rows(model) {
    #|      items.push(row)
    #|    }
    #|  }
    #|  column([scroll_view(column(items), width=960.0, height=600.0)])
    #|}
    #|
    #|///|
    #|/// TEA 组合根：无 IO、无服务依赖——导出的应用是纯本地的确定性执行器。
    #|pub fn program() -> @moui.Program[Model, Msg] {
    #|  @moui.Program::new(
    #|    init=() => (Model::new(), @moui.Effect::none()),
    #|    update=(model, msg) => (update(model, msg), @moui.Effect::none()),
    #|    view~,
    #|  )
    #|}
    #|
  source
}
