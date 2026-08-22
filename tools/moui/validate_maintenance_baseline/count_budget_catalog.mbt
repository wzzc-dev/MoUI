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
    // SurfaceMetrics is the single backend/render-neutral surface DTO.
    // Neutral accessibility DTO expansion (roles, relations, ranges, text,
    // live announcements, and typed actions) is intentionally public because
    // it is the cross-runtime wire contract. Keep the new ratchet explicit.
    { kind: "pub(all)", label: "moui/core", path: "moui/core", max_count: 188 },
    // 57 = 39 (ADR 0017 control theme tokens) + 17 control-theme/style
    // records + 1 externally constructed incremental-data change enum.
    { kind: "pub(all)", label: "moui/views", path: "moui/views", max_count: 57 },
    {
      kind: "pub(all)",
      label: "moui/runtime",
      path: "moui/runtime",
      // 35 = 34 (ADR 0018 host split) + 1 (window scene lifecycle growth).
      max_count: 35,
    },
    {
      kind: "pub(all)",
      label: "moui/backend",
      path: "moui/backend",
      // AccessKit's backend-owned adapter plus application-menu placement add
      // two package-level protocol records while common owners replace the
      // former coordinator.
      max_count: 96,
    },
    {
      kind: "pub(all)",
      label: "moui/render",
      path: "moui/render",
      // Root render carries renderer-neutral DTOs plus the two-layer
      // RendererProvider/RendererSession and opaque HostSurface contract.
      // Concrete routes and platform handle meaning stay renderer-local.
      max_count: 62,
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
