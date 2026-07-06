///|
struct CountBudget {
  kind : String
  label : String
  path : String
  max_count : Int
}

///|
fn pub_all_budgets() -> Array[CountBudget] {
  [
    { kind: "pub(all)", label: "moui/core", path: "moui/core", max_count: 280 },
    { kind: "pub(all)", label: "moui/views", path: "moui/views", max_count: 82 },
    {
      kind: "pub(all)",
      label: "moui/runtime",
      path: "moui/runtime",
      max_count: 42,
    },
    {
      kind: "pub(all)",
      label: "moui/backend/host",
      path: "moui/backend/host",
      max_count: 170,
    },
    {
      kind: "pub(all)",
      label: "moui/render",
      path: "moui/render",
      max_count: 118,
    },
    {
      kind: "pub(all)",
      label: "examples/showcase/app",
      path: "examples/showcase/app",
      max_count: 8,
    },
    {
      kind: "pub(all)",
      label: "examples/markdown_editor/app",
      path: "examples/markdown_editor/app",
      max_count: 0,
    },
    {
      kind: "pub(all)",
      label: "examples/pdf_workbench/app",
      path: "examples/pdf_workbench/app",
      max_count: 20,
    },
    {
      kind: "pub(all)",
      label: "examples/mo_workbench/app",
      path: "examples/mo_workbench/app",
      // Multi-workspace shell (Code/Write/Settings implemented + 3 reserved)
      // exposes Workspace/AppearanceMode/ApprovalPolicy/SandboxMode/
      // ChatMessage/WorkbenchMsg/CodeMsg/SettingsMsg/WriteMsg +
      // AgentBackendRuntime/AgentBackendFixture/AgentCommand/AgentEvent/
      // ModelChoice/ThinkingChoice/TurnStatus/SessionSummary. Budget leaves
      // headroom for the reserved workspaces (ConnectPhone/ScheduledTasks/
      // Plugins) to gain their own pub(all) types when implemented.
      max_count: 20,
    },
    {
      kind: "pub(all)",
      label: "website/app",
      path: "website/app",
      max_count: 0,
    },
  ]
}

///|
fn root_facade_forward_budget() -> CountBudget {
  {
    kind: "root facade forwards",
    label: "moui/moui.mbt",
    path: "moui/moui.mbt",
    max_count: 50,
  }
}
