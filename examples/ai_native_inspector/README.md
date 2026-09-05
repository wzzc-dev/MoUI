# MoUI AI-Native UI / Agent Inspector

This reference app is a secure enterprise operations workbench for the MoUI
AI-Native UI project. It demonstrates a single program with two workspaces:
the business GUI on the left and an Agent Console on the right. Search, detail,
edit, assignment, state transition, export and sensitive-field controls declare
stable semantic IDs and typed actions so an external Agent can operate the
workflow without screen capture, OCR, coordinates or simulated keyboard input.

The composition root registers these declarative Skills:

- `workbench.search`
- `workbench.open`
- `workbench.update`
- `workbench.transition`
- `workbench.assign`
- `workbench.export`
- `workbench.read_sensitive`

Writes and export require confirmation. Sensitive contact values are redacted
by the secure Agent session unless the caller has the
`records.sensitive.read` Scope. Trace payloads remain redacted by default.

The UI is an operable demonstration console rather than a static screenshot.
It opens with `Northwind renewal` selected and exposes `Run demo`, `Next step`,
`Approve`, `Reject`, `Replay`, `Audit`, `Export report` and `Reset`. The default
driver runs locally without a model or API key; the composition root also
binds the same controls to `RuntimeAgentHost`, `PolicyAgentHost`, Skills and
the secure session.

The in-memory v1/v2 fixture switch changes the export semantic ID, allowing
Replay to stop at the first semantic regression without an external fixture
file.

Recommended recording script:

```text
Run demo
-> sensitive read denied and redacted
-> transition waits for confirmation
-> Approve
-> export waits for confirmation
-> Approve
-> switch to v2
-> Replay stops at workbench.export.v2
-> Audit -> Export report
```

The composition roots add `RuntimeAgentHost`, `PolicyAgentHost`, MCP and the
selected renderer in the host application. The shared `app` package remains
free of runtime, backend and renderer imports.

The scenario is intentionally runnable without a model or API key. It is a
realistic or simulated validation environment for AI application QA, not a
claim of customer deployment.

Build the headless MCP entrypoint with:

```sh
moon check examples/ai_native_inspector/main --target native
```

Send `initialize` and `tools/list` over NDJSON to inspect the default two-tool
surface plus the opt-in `skills/list`, `skills/get`, `skills/call`, trace,
replay and policy tools. The secure composition root routes Skills through a
short-lived scoped session. `skills/call` accepts a declarative Skill ID,
string inputs and explicit Scope names; successful read output is redacted by
that session, while malformed inputs and policy failures are returned as
structured MCP tool errors.
