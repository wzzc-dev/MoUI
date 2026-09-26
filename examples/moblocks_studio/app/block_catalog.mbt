///|
/// 积木分类：事件 / AI / 安全 / 控制 / 数据与 UI。
pub(all) enum BlockCategory {
  Event
  AI
  Safety
  Control
  DataUI
}

///|
/// 积木的副作用类别。mcp 值保留至赛后。
pub(all) enum EffectKind {
  Pure
  Model
  UI
  Control
}

///|
/// 风险等级：external_submit 级必须经显式 UserConfirmation 路径。
pub(all) enum RiskClass {
  Read
  Write
  Execute
  ExternalSubmit
}

///|
/// 比赛版 17 种积木的完整规格：端口 + 配置 schema。
pub(all) struct BlockSpec {
  kind : String
  category : BlockCategory
  title : String
  effect_kind : EffectKind
  risk_class : RiskClass
  summary : String
  input_ports : Array[PortSpec]
  output_ports : Array[PortSpec]
  config_schema : Array[ConfigSpec]
}

///|
/// 比赛版 17 种积木目录（无 MCP）。
/// 端口约定：非入口积木都有 trigger(Unit) 输入与 flow(Unit) 输出表达执行顺序；
/// 其余为数据端口，类型必须严格匹配才可连线。
pub fn block_catalog() -> Array[BlockSpec] {
  let trigger_in = [PortSpec::{ name: flow_in_port(), port_type: Unit, }]
  let flow_out = [PortSpec::{ name: flow_out_port(), port_type: Unit, }]
  [
    {
      kind: "AppStart",
      category: Event,
      title: "应用启动",
      effect_kind: UI,
      risk_class: Read,
      summary: "应用启动时触发一次",
      input_ports: [],
      output_ports: flow_out,
      config_schema: [],
    },
    {
      kind: "UserPrompt",
      category: Event,
      title: "用户提问",
      effect_kind: UI,
      risk_class: Read,
      summary: "等待用户输入一段提示",
      input_ports: trigger_in,
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "prompt", port_type: Text, },
        PortSpec::{ name: "message", port_type: ChatMessage, },
      ],
      config_schema: [],
    },
    {
      kind: "FileSelected",
      category: Event,
      title: "选择文件",
      effect_kind: UI,
      risk_class: Read,
      summary: "用户选择一个本地文件",
      input_ports: trigger_in,
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "file", port_type: FileRef, },
      ],
      config_schema: [],
    },
    {
      kind: "ModelCall",
      category: AI,
      title: "模型调用",
      effect_kind: Model,
      risk_class: ExternalSubmit,
      summary: "调用大模型生成文本（数据外发）",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "prompt", port_type: Text, },
        PortSpec::{ name: "context", port_type: ChatMessage, },
        PortSpec::{ name: "approved", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "reply", port_type: ChatMessage, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "model",
          label: "模型",
          value_type: CfgString,
          default: "fake-gpt-mini",
        },
        ConfigSpec::{
          key: "temperature",
          label: "温度",
          value_type: CfgNumber,
          default: "0.7",
        },
      ],
    },
    {
      kind: "StructuredModelCall",
      category: AI,
      title: "结构化调用",
      effect_kind: Model,
      risk_class: ExternalSubmit,
      summary: "调用大模型并按 schema 解析 JSON（数据外发）",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "prompt", port_type: Text, },
        PortSpec::{ name: "context", port_type: ChatMessage, },
        PortSpec::{ name: "approved", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "model",
          label: "模型",
          value_type: CfgString,
          default: "fake-gpt-mini",
        },
        ConfigSpec::{
          key: "schema",
          label: "输出结构",
          value_type: CfgString,
          default: "summary",
        },
      ],
    },
    {
      kind: "PromptTemplate",
      category: AI,
      title: "提示词模板",
      effect_kind: Pure,
      risk_class: Read,
      summary: "用变量渲染提示词模板",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "topic", port_type: Text, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "rendered", port_type: Text, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "persona",
          label: "人设",
          value_type: CfgString,
          default: "友好助手",
        },
      ],
    },
    {
      kind: "ConversationMemory",
      category: AI,
      title: "会话记忆",
      effect_kind: Pure,
      risk_class: Read,
      summary: "读写多轮对话上下文",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "append", port_type: ChatMessage, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "history", port_type: ChatMessage, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "entries",
          label: "记忆轮数",
          value_type: CfgNumber,
          default: "8",
        },
      ],
    },
    {
      kind: "UserConfirmation",
      category: Safety,
      title: "人工确认",
      effect_kind: Control,
      risk_class: Read,
      summary: "高风险动作前暂停并等待用户确认",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "approved", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "scope",
          label: "作用范围",
          value_type: CfgString,
          default: "数据外发",
        },
      ],
    },
    {
      kind: "Sequence",
      category: Control,
      title: "顺序执行",
      effect_kind: Control,
      risk_class: Read,
      summary: "按顺序依次执行分支",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [],
    },
    {
      kind: "IfElse",
      category: Control,
      title: "条件分支",
      effect_kind: Control,
      risk_class: Read,
      summary: "按条件选择分支",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "condition",
          label: "条件",
          value_type: CfgString,
          default: "score >= 0.5",
        },
      ],
    },
    {
      kind: "ForEach",
      category: Control,
      title: "有限遍历",
      effect_kind: Control,
      risk_class: Read,
      summary: "对有界集合逐项执行",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "limit",
          label: "遍历上限",
          value_type: CfgNumber,
          default: "10",
        },
      ],
    },
    {
      kind: "Retry",
      category: Control,
      title: "有限重试",
      effect_kind: Control,
      risk_class: Read,
      summary: "失败时重试，上限 3 次",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "attempts",
          label: "重试次数",
          value_type: CfgNumber,
          default: "3",
        },
        ConfigSpec::{
          key: "backoff_ms",
          label: "退避间隔(ms)",
          value_type: CfgNumber,
          default: "200",
        },
      ],
    },
    {
      kind: "Timeout",
      category: Control,
      title: "超时控制",
      effect_kind: Control,
      risk_class: Read,
      summary: "超过预算时间转为失败",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [
        ConfigSpec::{
          key: "budget_ms",
          label: "预算(ms)",
          value_type: CfgNumber,
          default: "3000",
        },
      ],
    },
    {
      kind: "CatchError",
      category: Control,
      title: "捕获错误",
      effect_kind: Control,
      risk_class: Read,
      summary: "捕获上游失败并转入处理分支",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "action", port_type: Json, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "result", port_type: Json, },
      ],
      config_schema: [],
    },
    {
      kind: "ParseJson",
      category: DataUI,
      title: "JSON 解析",
      effect_kind: Pure,
      risk_class: Read,
      summary: "把文本解析为 JSON 值",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "text", port_type: Text, },
      ],
      output_ports: [
        PortSpec::{ name: flow_out_port(), port_type: Unit, },
        PortSpec::{ name: "value", port_type: Json, },
      ],
      config_schema: [],
    },
    {
      kind: "ShowMarkdown",
      category: DataUI,
      title: "Markdown 显示",
      effect_kind: UI,
      risk_class: Read,
      summary: "把 Markdown 文本渲染到界面",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "content", port_type: ChatMessage, },
      ],
      output_ports: flow_out,
      config_schema: [],
    },
    {
      kind: "ShowTable",
      category: DataUI,
      title: "表格显示",
      effect_kind: UI,
      risk_class: Read,
      summary: "把结构化数据渲染为表格",
      input_ports: [
        PortSpec::{ name: flow_in_port(), port_type: Unit, },
        PortSpec::{ name: "data", port_type: Json, },
      ],
      output_ports: flow_out,
      config_schema: [],
    },
  ]
}

///|
pub fn find_spec(specs : Array[BlockSpec], kind : String) -> BlockSpec? {
  for spec in specs {
    if spec.kind == kind {
      return Some(spec)
    }
  }
  None
}

///|
pub fn find_input_port(spec : BlockSpec, name : String) -> PortSpec? {
  for port in spec.input_ports {
    if port.name == name {
      return Some(port)
    }
  }
  None
}

///|
pub fn find_output_port(spec : BlockSpec, name : String) -> PortSpec? {
  for port in spec.output_ports {
    if port.name == name {
      return Some(port)
    }
  }
  None
}

///|
pub fn find_config_spec(spec : BlockSpec, key : String) -> ConfigSpec? {
  for entry in spec.config_schema {
    if entry.key == key {
      return Some(entry)
    }
  }
  None
}

///|
/// 分类配色：画布节点填充色。
pub fn category_color(category : BlockCategory) -> @graphics.Color {
  match category {
    Event => @graphics.Color::rgba(r=0.91, g=0.64, b=0.24)
    AI => @graphics.Color::rgba(r=0.49, g=0.36, b=0.99)
    Safety => @graphics.Color::rgba(r=0.89, g=0.24, b=0.34)
    Control => @graphics.Color::rgba(r=0.30, g=0.60, b=1.0)
    DataUI => @graphics.Color::rgba(r=0.18, g=0.71, b=0.49)
  }
}
