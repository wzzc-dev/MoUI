# Diagnostics

`moui/core/diagnostics` is the shared envelope for cross-layer diagnostic
facts. It is intentionally a leaf package: it imports no runtime, backend,
render, or theme package, so every layer can produce events without a
dependency inversion.

## Envelope

```text
DiagnosticEvent {
  code: String,            // stable catalog key, e.g. "renderer.feature.gap"
  severity: Info | Warning | Error,
  domain: Runtime | Render | Backend | Text | Accessibility | Services,
  message: String,
  source: String,          // provider/window/control identity
  generation: UInt64?,     // semantics/session generation when relevant
  frame: UInt64?,          // frame sequence when relevant
  detail: String?,         // short payload; long evidence stays in its report
}
```

Capability notes stay in `docs/renderer-capability-report.md`; a diagnostic
event carries a short message and a stable code, not the full evidence text.

## Sink

`DiagnosticSink` is caller-owned, bounded, and drained at a sampling boundary.
It is **not** a runtime hot-path log (ADR 0056). A host/tool creates one and
passes it only to the producers it wants to observe.

The runtime now owns one bounded sink (`AppRuntime::diagnostics_sink()`).
`WindowFrameState` forwards `RenderFrameResult.diagnostics` through its frame
hook into that sink, and DevTools reads `snapshot()` when it builds a document.
The sink copy and the runtime share the same array, so a frame hook never holds
the runtime.

## Producers and consumers

| Layer | Producer | Consumer |
|---|---|---|
| Host orchestration | renderer selection/rejection, window rejection | DevTools, host log |
| Runtime | full-damage reason, semantics/action failures | DevTools, Showcase |
| Render | per-frame `RenderFrameResult.diagnostics` | backend frame hook → runtime sink, DevTools |
| Text | paragraph/font fallback | text diagnostics |
| Services | extension unavailable/failure | Agent/MCP, host log |

`RenderFrameResult` carries a per-frame `diagnostics` array. Renderers report
degradation there; the backend frame owner can forward it to DevTools, the
embedded wire envelope, or the Agent diagnostics surface.

## Update rule

Add a new stable code before adding a producer. Tests assert codes and
severities, not only message text.
