# Plan: MoUI AI-Native UI

- **Status**: active
- **Goal**: deliver the Agent Runtime, declarative Skills, Agent Inspector and secure enterprise-operations-workbench evidence for OA2026 and OS2026.
- **Non-goals**: model inference, network transport, coordinate automation, and first-release mobile competition commitments.

## Scope

MoUI AI-Native UI is a framework SDK plus Agent Runtime, declarative Skills,
Agent Inspector and an AI application QA workflow. The reference application
is a secure enterprise operations workbench with search, detail, record
editing, assignment, state transition, submit confirmation, export and
sensitive contact access.

The framework provides semantic IDs, committed semantic generations and typed
actions already owned by `moui/core` and `moui/runtime`. New policy, trace,
replay and scenario behavior lives in `moui_agent`; it does not add model
inference, networking or coordinate input to the core runtime.

## Implemented contracts

- `PolicyAgentHost` wraps any existing `AgentHost` and applies `Allow`,
  `Deny(reason)` or `RequireConfirmation(request_id)` before dispatch.
- Confirmation requests can be approved once, rejected once or cleared as
  expired. Policy and execution outcomes are retained in `AgentTraceEntry`.
- `AgentTraceHost` exposes cursor-based trace reads, opt-in replay and policy
  state. SetText values are retained for in-memory replay but redacted in JSON.
- `AgentScenario` provides read, typed action, target, action capability and
  Generation assertions for local and CI tests.
- `AgentSkillManifest`, `AgentSkillStep`, `AgentSkillRegistry`,
  `AgentSkillExecutor` and `AgentSkillResult` provide a fixed declarative
  Skill vocabulary. Skills can
  only read committed semantics, assert targets/actions, execute typed actions,
  check Generation and require Scopes; arbitrary callbacks and coordinates are
  not part of the protocol.
- `AgentVisibilityPolicy` and `AgentSecureSession` redact protected semantic
  values and reject direct actions without the declared Scope.
- `route()` remains the two-tool MCP surface. `route_with_agent_tools()` is
  the explicit opt-in surface for `agent_read_trace`, `agent_replay_trace` and
  `agent_read_policy_state`.
- `route_with_skills()` adds the explicit `skills/list`, `skills/get` and
  `skills/call` tools while retaining the semantic and Inspector tools. Secure
  composition roots use `route_with_secure_skills()`, which applies the
  invocation Scope to a short-lived secure session for Skill execution.
- Successful Skill results include structured read output. The output is
  produced after secure-session redaction, so protected values are only
  present when the invocation has the required Scope; failures never include
  the unread protected snapshot.
- `moui_devtools` exposes `AgentInspectorReport`, text/JSON export and the
  `agent_inspector_overlay`. Its workspaces cover Semantics, Skills, Actions,
  Policy, MCP, Trace, Replay and AI-Ready Audit. Audit issues stay outside
  `moui/core`.
- `examples/ai_native_inspector/main` provides a headless NDJSON stdio MCP
  entrypoint for local QA and CI without a model or API key.

## Reference workflow

1. A developer declares stable semantic IDs and typed actions in the app.
2. QA reads the committed semantics tree and runs an Agent scenario.
3. Policy checks protect submit, text, assignment, state transition and export
   operations.
4. Trace records decisions, confirmations, Generation transitions and errors.
5. Replay is run against a new build and stops at stale or unavailable
   semantics instead of guessing with coordinates.
6. The Inspector report is exported as a release acceptance artifact.

The workbench is a simulated validation environment that maps to CRM, ticket,
asset, finance and public-sector operations products. GUI development is the
developer-tool scenario; the OA industry scenario is secure enterprise GUI
application delivery and permission governance. No customer deployment is
claimed without external evidence.

## Platform evidence

- macOS Skia and Web wasm-gc: complete reference-app interaction paths are the
  target evidence.
- Windows Skia and Linux Skia: compile, protocol and report tests are the
  initial evidence. Full interaction claims require matching-host smoke.
- Android, iOS and HarmonyOS are outside the first competition commitment.

## Validation

```sh
moon test moui_agent --target native
moon test moui_agent_mcp --target native
moon test moui_devtools --target native
moon test moui_devtools/overlay --target native
moon test examples/ai_native_inspector/app --target native
moon build examples/ai_native_inspector/web_wasm --target wasm-gc
moon check examples/ai_native_inspector/macos_skia --target native
moon check examples/ai_native_inspector/windows_skia --target native
moon check examples/ai_native_inspector/linux_skia --target native
```

The reference app runs without a model or API key. External model adapters can
use the same semantic and MCP contracts without changing the framework core.
