///|
/// MoBlocks Studio 视图层：四区 IDE 布局（顶栏/运行条/积木箱|画布|检查器/时间线）。
/// 只读 Model、派发既有 Msg，不含业务规则；业务规则在 app.mbt 的 update 链。
using @views {button, column, row, text, text_field, scroll_view, frame, badge}

///|
fn node_config_value(
  node : BlockNode,
  key : String,
  fallback : String,
) -> String {
  match find_config_value(node, key) {
    Some(value) => value
    None => fallback
  }
}

///|
/// 顶栏：项目操作 + 视图控制 + provider 状态徽章。
fn top_bar(model : Model) -> @moui.View[Msg] {
  row(
    [
      text("项目：\{model.project_name}").title(),
      badge(
        if model.fake_provider {
          "假模型"
        } else {
          "真实 provider"
        },
        tone=if model.fake_provider {
          @views.BadgeTone::Success
        } else {
          @views.BadgeTone::Warning
        },
        width=96.0,
      ),
      button("新建", on_click=NewProject, width=64.0),
      button("打开", on_click=OpenRequested, width=64.0),
      button("保存", on_click=SaveRequested, width=64.0),
      button("导出", on_click=ExportRequested, width=64.0),
      button("撤销", on_click=UndoEdit, width=64.0),
      button("重做", on_click=RedoEdit, width=64.0),
      button("放大", on_click=ZoomIn, width=56.0),
      button("缩小", on_click=ZoomOut, width=56.0),
      button("复位视图", on_click=ZoomReset, width=88.0),
    ],
    spacing=6.0,
  )
}

///|
/// 运行控制条：一键演出 + 手动步进 + 闸门裁决。
fn run_bar(_model : Model) -> @moui.View[Msg] {
  row(
    [
      button("自动运行到阻塞点", on_click=AutoRunExecution, width=150.0),
      button("运行", on_click=RunExecution, width=72.0),
      button("前进一步", on_click=StepOk, width=96.0),
      button("确认外发", on_click=ConfirmExecution, width=96.0),
      button("拒绝", on_click=RejectExecution, width=64.0),
      button("取消", on_click=CancelExecution, width=64.0),
      button("重置", on_click=ResetExecution, width=64.0),
    ],
    spacing=6.0,
  )
}

///|
/// 模型 provider 面板：fake/真实切换 + endpoint/key。
/// key 仅存于会话内存，不写入项目文件（凭据脱敏红线）。
fn provider_panel(model : Model) -> Array[@moui.View[Msg]] {
  [
    text("模型 Provider").title(),
    text(
      if model.fake_provider {
        "当前：假模型（确定性，离线可演示）"
      } else {
        "当前：真实 provider（OpenAI 兼容）"
      },
      width=270.0,
    ),
    button(
      if model.fake_provider {
        "切换到真实 provider"
      } else {
        "切换到假模型"
      },
      on_click=ToggleProviderMode,
      width=270.0,
    ),
    text_field(
      model.provider_endpoint,
      on_input=fn(endpoint) { ProviderEndpointInput(endpoint) },
      placeholder="OpenAI 兼容 endpoint",
      width=270.0,
    ),
    text_field(
      model.provider_key,
      on_input=fn(key) { ProviderKeyInput(key) },
      placeholder="API Key（不写入项目文件）",
      width=270.0,
    ),
  ]
}

///|
fn proposal_panel(model : Model) -> Array[@moui.View[Msg]] {
  match model.pending_proposal {
    Some(proposal) =>
      [
        text("AI 提案预览").title(),
        text(
          "新图：\{proposal.nodes} 个积木 / \{proposal.edges} 条连线，校验通过",
          width=270.0,
        ),
        button("接受替换", on_click=AcceptProposal),
        button("取消提案", on_click=CancelProposal),
      ]
    None =>
      [
        text("AI 生成").title(),
        text_field(
          model.prompt_draft,
          on_input=fn(prompt) { PromptInput(prompt) },
          placeholder="用一句话描述应用，例如：做个能记住我、有人设的聊天助手",
          width=270.0,
        ),
        button("生成", on_click=GenerateFromPrompt, width=130.0),
        text("假模型按关键词路由到内置模板；", width=270.0),
        text("真实模式下同段描述发给远端模型。", width=270.0),
      ]
  }
}

///|
fn edges_of(graph : BlockGraph, id : Int) -> Array[BlockEdge] {
  graph.edges.filter(fn(edge) { edge.from == id || edge.to == id })
}

///|
fn input_port_occupied(graph : BlockGraph, id : Int, port : String) -> Bool {
  graph.edges.any(fn(edge) { edge.to == id && edge.to_port == port })
}

///|
/// L0 按钮式连接：当前选中积木的每个输出端口 → 类型匹配且未被占用的输入端口。
fn connect_candidates(
  graph : BlockGraph,
  node : BlockNode,
  specs : Array[BlockSpec],
) -> Array[(String, Int, String)] {
  let from_spec = find_spec(specs, node.kind)
  let candidates : Array[(String, Int, String)] = []
  match from_spec {
    Some(from_spec) =>
      for out_port in from_spec.output_ports {
        if candidates.length() >= 8 {
          return candidates
        }
        for target in graph.nodes {
          if candidates.length() >= 8 {
            return candidates
          }
          if target.id == node.id {
            continue
          }
          let target_spec = find_spec(specs, target.kind)
          match target_spec {
            Some(target_spec) =>
              for in_port in target_spec.input_ports {
                if candidates.length() >= 8 {
                  return candidates
                }
                if port_types_equal(out_port.port_type, in_port.port_type) &&
                  !input_port_occupied(graph, target.id, in_port.name) {
                  candidates.push((out_port.name, target.id, in_port.name))
                }
              }
            None => ()
          }
        }
      }
    None => ()
  }
  candidates
}

///|
/// 右侧检查器：AI 生成/提案 → 选中属性 → Provider 设置，纵向分区。
fn inspector_panel(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [text("检查器").title()]
  for proposal_view in proposal_panel(model) {
    items.push(proposal_view)
  }
  for selection_view in selection_panel(model) {
    items.push(selection_view)
  }
  for provider_view in provider_panel(model) {
    items.push(provider_view)
  }
  frame(scroll_view(column(items, spacing=8.0), width=300.0), height=480.0)
}

///|
/// 选中积木的属性面板：标题/config 编辑、实时校验错误、连线管理。
fn selection_panel(model : Model) -> Array[@moui.View[Msg]] {
  let graph = GraphEditor::graph(model.editor)
  let specs = block_catalog()
  let items : Array[@moui.View[Msg]] = []
  match model.selection {
    None => items.push(text("未选中积木"))
    Some(id) =>
      match graph.find_node(id) {
        None => items.push(text("选中：#\{id}（已删除）"))
        Some(node) => {
          items.push(text("\{node.title} · \{node.kind}"))
          items.push(
            text_field(
              node.title,
              on_input=fn(title) { TitleInput(node.id, title) },
              placeholder="积木标题",
              width=270.0,
            ),
          )
          let spec = find_spec(specs, node.kind)
          match spec {
            Some(spec) => {
              items.push(
                text(
                  "效果：\{effect_kind_label(spec.effect_kind)} · 风险：\{risk_class_label(spec.risk_class)}",
                  width=270.0,
                ),
              )
              for entry in spec.config_schema {
                let value = node_config_value(node, entry.key, entry.default)
                items.push(
                  text_field(
                    value,
                    on_input=fn(input) {
                      ConfigInput(node.id, entry.key, input)
                    },
                    placeholder=entry.label,
                    width=270.0,
                  ),
                )
              }
            }
            None => items.push(text("未知积木类型"))
          }
          let config_errors = match spec {
            Some(spec) => validate_node_config(node, spec)
            None => []
          }
          for error in config_errors {
            items.push(text("✗ \{validation_error_label(error)}"))
          }
          items.push(
            button("删除积木", on_click=DeleteSelected, width=150.0),
          )
          items.push(text("已连线").title())
          for edge in edges_of(graph, node.id) {
            items.push(
              button(
                "断开 #\{edge.from}.\{edge.from_port} → #\{edge.to}.\{edge.to_port}",
                on_click=DropEdge(
                  edge.from,
                  edge.from_port,
                  edge.to,
                  edge.to_port,
                ),
                width=270.0,
              ),
            )
          }
          items.push(text("连接到…").title())
          for candidate in connect_candidates(graph, node, specs) {
            let (from_port, target_id, to_port) = candidate
            let target_title = match graph.find_node(target_id) {
              Some(target) => target.title
              None => "#\{target_id}"
            }
            items.push(
              button(
                "\{from_port} → \{target_title}.\{to_port}",
                on_click=ConnectTo(node.id, from_port, target_id, to_port),
                width=270.0,
              ),
            )
          }
        }
      }
  }
  items
}

///|
fn effect_kind_label(kind : EffectKind) -> String {
  match kind {
    Pure => "纯计算"
    Model => "模型调用"
    UI => "界面"
    Control => "控制流"
  }
}

///|
fn risk_class_label(risk : RiskClass) -> String {
  match risk {
    Read => "只读"
    Write => "写入"
    Execute => "执行"
    ExternalSubmit => "数据外发"
  }
}

///|
fn category_label(category : BlockCategory) -> String {
  match category {
    Event => "事件"
    AI => "AI"
    Safety => "安全"
    Control => "控制"
    DataUI => "数据 / 界面"
  }
}

///|
/// 左侧积木箱：按分类分组的添加按钮 + 项目模板 + 选择积木。
fn block_palette(model : Model) -> @moui.View[Msg] {
  let specs = block_catalog()
  let items : Array[@moui.View[Msg]] = [text("积木工具箱").title()]
  for category in [Event, AI, Safety, Control, DataUI] {
    items.push(text(category_label(category)).title())
    for spec in specs {
      let same = match (spec.category, category) {
        (Event, Event)
        | (AI, AI)
        | (Safety, Safety)
        | (Control, Control)
        | (DataUI, DataUI) => true
        _ => false
      }
      if same {
        // “+”前缀标记“点击即添加”，同时避免与画布上的积木标题文本同名
        // （画布标题帧是画布局部坐标，同名会让按文本定位的 UI 测试拿错帧）。
        items.push(
          button("+ \{spec.title}", on_click=AddBlock(spec.kind), width=150.0),
        )
      }
    }
  }
  items.push(text("项目模板").title())
  items.push(button("新建空项目", on_click=NewProject, width=150.0))
  items.push(
    button("对话机器人", on_click=LoadTemplate("chatbot"), width=150.0),
  )
  items.push(
    button(
      "本地文档分析助手",
      on_click=LoadTemplate("doc"),
      width=150.0,
    ),
  )
  items.push(
    button("CSV 分析助手", on_click=LoadTemplate("csv"), width=150.0),
  )
  items.push(text("选择积木").title())
  for node in GraphEditor::graph(model.editor).nodes {
    let node_id = node.id
    items.push(
      button(
        "#\{node_id} \{node.title}",
        on_click=SelectNode(Some(node_id)),
        width=150.0,
      ),
    )
  }
  // 固有高度封顶：scroll_view 内容很高时会把 flexible 中行撑出视口，
  // 底部时间线会被挤出屏幕（列布局按内容测量分配）。
  frame(scroll_view(column(items, spacing=8.0), width=170.0), height=480.0)
}

///|
/// 底部时间线：运行步骤 + 审计留痕。
fn timeline_panel(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [
    text("运行时间线 · \{run_status_label(model.execution.status)}").title(),
  ]
  for step in model.execution.steps {
    items.push(
      text(
        "\{step.node_id}. \{step.title} · \{step_status_label(step.status)} \{step.summary}（\{step.duration_ms}ms）",
      ),
    )
  }
  for entry in model.execution.audit {
    items.push(text("· \{entry}"))
  }
  frame(scroll_view(column(items, spacing=8.0)), height=140.0)
}

///|
/// 四区 IDE 布局：通知条 + 顶栏/运行条 + （积木箱 | 画布 | 检查器）+ 时间线。
/// 旧版把全部控件塞进单个底部滚动面板，是当时怀疑 row 子级命中缺陷的绕行
/// （已复核为测试坐标误判，见 docs/plans/done/row-child-hit-testing.md）。
pub fn view(model : Model) -> @moui.View[Msg] {
  column([
    frame(text(model.notice), height=32.0),
    top_bar(model),
    run_bar(model),
    row([
      block_palette(model),
      block_canvas(
        GraphEditor::graph(model.editor),
        model.selection,
        spotlight_node(model.execution),
        model.viewport_x,
        model.viewport_y,
        model.viewport_zoom,
      ).flexible(weight=1.0),
      inspector_panel(model),
    ]).flexible(),
    timeline_panel(model),
  ])
}
