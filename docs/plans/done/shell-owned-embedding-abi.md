# Plan: shell-owned embedding ABI

- **Status**: complete
- **Goal**: Move the fixed embedding ABI provider and compatibility dispatch
  into `moui_shell`, so Android, iOS, and HarmonyOS MoUI backends only install
  shell-declared MoonBit runtime callbacks.
- **Non-goals**: Make `moui_shell` depend on `wzzc-dev/moui`, change the
  handheld profile or platform-readiness status, retain the former provider
  ownership path, or add ABI backward-compatibility branches.

## Constraints

- `moui_shell` owns the C header/provider source, native exports, ABI metadata,
  and compatibility decisions.
- `moui_shell/embedding` exposes neutral MoonBit callback/installation APIs;
  it may use primitives and wire payloads but no MoUI runtime/host/render types.
- `moui/backend/<platform>` adapts `EmbeddedSessionCore` to those callbacks and
  does not declare `moui_embedding_*` symbols or `link.exports` entries.
- `moui_shell` remains independent of MoUI. Registration is inversion of
  control: MoUI installs callbacks, and shell dispatches to them.

## Acceptance

- [x] The fixed C embedding provider is compiled from `moui_shell`; all three
  native embedders and managed/ejected source collectors use that path.
- [x] `embedding` exports an installable neutral runtime callback surface and
  owns all fixed `moui_embedding_*` MoonBit exports.
- [x] Each platform backend installs a callback adapter while retaining typed
  handle, `AppRuntime`, host, and renderer ownership locally.
- [x] MoUI no longer contains an ABI provider C++ source or native export list.
- [x] Tests cover installed/uninstalled dispatch, replacement, and the three
  platform adapters; ABI header/ownership/ASan and shell packaging matrices
  pass.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | Keep `EmbeddedSessionCore` in MoUI because it assembles `AppRuntime`, renderer, and host contracts. Move only the neutral ABI facade and its dispatch ownership to `moui_shell/embedding`. |

## Validation

- Passed: MoonBit tests for `moui_shell/embedding`, Android/iOS/HarmonyOS
  backends, CLI, shell-app-config, harness invariants, and API-surface tools.
- Passed: ABI header, ownership, symbol, and AddressSanitizer audit; Android,
  iOS, and HarmonyOS managed/plugin/ejected fallback preparation matrices.
- Passed: maintenance, API-surface, guidance, website-documentation, shell
  configuration, and diff checks. `moon info` confirms that platform backends
  now expose `install_embedding` but no fixed ABI forwarding functions.
