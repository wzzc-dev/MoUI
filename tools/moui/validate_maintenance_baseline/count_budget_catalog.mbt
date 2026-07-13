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
    { kind: "pub(all)", label: "moui/views", path: "moui/views", max_count: 19 },
    {
      kind: "pub(all)",
      label: "moui/runtime",
      path: "moui/runtime",
      // 9 = 6 (prior baseline) + 3 for Phase 2.2 context-loss recovery
      // scaffolding (RendererRecoveryState enum, RendererRecoveryBudget
      // struct, RendererRecoverySnapshot struct), all introduced by ADR
      // 0006 § Context-loss recovery.
      max_count: 9,
    },
    {
      kind: "pub(all)",
      label: "moui/backend/host",
      path: "moui/backend/host",
      max_count: 70,
    },
    {
      kind: "pub(all)",
      label: "moui/render",
      path: "moui/render",
      // 46 = 38 (prior baseline) + 8 for the unified native renderer
      // selection, completion, worker, and recovery diagnostics contracts.
      // The integration API is intentionally budgeted here rather than
      // leaking these types into the app facade.
      // 38 = 35 (prior baseline) + 1 for SkiaPresentKind (the discriminator
      // for the CpuPixelFrame vs HostGpuSurface present path) + 1 for
      // HostGpuPresentOutcome (the present-gpu outcome struct), both
      // introduced by Phase 1.1 of the readback-elimination plan (ADR 0006),
      // + 1 for RendererControlMessage (Phase 2.1 renderer-thread mailbox
      // control message enum, ADR 0006 § Renderer-thread ownership).
      max_count: 46,
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
