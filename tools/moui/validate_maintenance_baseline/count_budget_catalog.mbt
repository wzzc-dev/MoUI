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
    // Actual ~140 after API narrowing; keep a small buffer for legitimate core enums.
    { kind: "pub(all)", label: "moui/core", path: "moui/core", max_count: 150 },
    // 39 = 19 (prior baseline) + 20 for ADR 0017 control theme token structs
    // migrated from core (ControlThemeSet, ButtonTheme, ControlStateTokens,
    // ControlStateStyle, ComponentThemes, …) — control vocabulary now lives
    // in views, so the pub(all) budget moved with it.
    { kind: "pub(all)", label: "moui/views", path: "moui/views", max_count: 39 },
    {
      kind: "pub(all)",
      label: "moui/runtime",
      path: "moui/runtime",
      // 34 = 16 (prior baseline) + 18 for ADR 0018 host split: the host
      // runtime driver, wall clock, redraw scheduler, window runtime slots,
      // window scene resolver, and runtime-side subscription source adapters
      // moved from backend/host to moui/runtime. These are the runtime
      // orchestration types that host contracts no longer own.
      max_count: 34,
    },
    {
      kind: "pub(all)",
      label: "moui/backend/host",
      path: "moui/backend/host",
      // Host Wire v1 adds the versioned update/response envelopes and the
      // revisioned PlatformView snapshot as required native-shell protocol.
      // Raised to 73 with multi-window / desktop host surface growth.
      max_count: 73,
    },
    {
      kind: "pub(all)",
      label: "moui/render",
      path: "moui/render",
      // 56 = 47 (prior baseline) + 9 for ADR 0019 RendererProvider plugin
      // system: RendererProvider, RendererInstance, RendererProviderRegistry,
      // SurfaceDescriptor, BoundSurface, SurfaceNegotiationResult,
      // RendererRecoveryKind, RendererProviderDescriptor, and the provider
      // factory aliases. The integration API is intentionally budgeted here
      // rather than leaking these types into the app facade.
      max_count: 56,
    },
    {
      kind: "pub(all)",
      label: "examples/showcase/app",
      path: "examples/showcase/app",
      // Root shell + catalog metadata + four workspace packages.
      max_count: 32,
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
      max_count: 12,
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
      // one-slot headroom for the next reserved workspace type.
      max_count: 18,
    },
    {
      kind: "pub(all)",
      label: "website/app",
      path: "website/app",
      // Generated catalog model types are internal to the Website package but
      // need package-wide visibility across its generated and adapter sources.
      max_count: 2,
    },
  ]
}

///|
fn root_facade_forward_budget() -> CountBudget {
  {
    kind: "root facade forwards",
    label: "moui/moui.mbt",
    path: "moui/moui.mbt",
    // Domain facades absorbed root `pub type` forwards; keep a tiny buffer only.
    max_count: 5,
  }
}
