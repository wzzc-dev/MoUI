# MoUI AI-Native UI Inspector

This reference app is a platform-neutral enterprise data workbench for the
MoUI AI-Native UI project. Its search, filter, edit, submit and export controls
declare stable semantic IDs and typed actions so an external Agent can operate
the workflow without coordinates.

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

Send `initialize`, `tools/list`, `agent_read_trace` and
`agent_replay_trace` JSON-RPC requests over NDJSON to exercise the opt-in
Inspector surface.
