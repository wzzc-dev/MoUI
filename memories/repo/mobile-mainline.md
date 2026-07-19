# Native Shell Mainline

- Android, iOS, and HarmonyOS use the MoUI-specific `wzzc-dev/moui_shell`
  SDK. It has a shared `embedding` package plus platform-first
  `android`, `ios`, and `harmonyos` packages; it is not a replacement for
  `wzzc-dev/window`.
- Platform backends import `moui_shell/embedding` plus their typed platform
  package. `moui_shell` never imports MoUI; the MoUI root facade remains
  shell-free. Runtime-owned application/session behavior stays in
  `moui/backend/internal/embedded_runtime_session`.
- `moui_shell/embedding` owns neutral session lifecycle, surface epochs,
  generation rejection, frame coalescing, host-update envelopes, asynchronous
  request correlation, capabilities, Embedding API v1 negotiation, the fixed
  provider, and native export dispatch.
- A shell app uses schema v1 `shell.json`, `shellApiVersion: 1`,
  `embeddingApiVersion: 1`, the sole `shell.profile: "handheld"`, and one
  platform `runnerMode: "managed" | "ejected"`.
- Managed shells are package-owned and staged at build time: Kotlin/AndroidX
  with registered JNI on Android, SwiftUI plus CAMetalLayer on iOS, and ArkTS
  Stage Ability/XComponent/NAPI on HarmonyOS. Ejected projects are created by
  `moui shell eject <platform>` and lock matching `moui`/`moui_shell` versions,
  API versions, and capability snapshot.
- Native embedders consume `moui_embedding_get_api_v1()` from the shell-owned
  provider. MoUI installs neutral runtime callbacks; embedders preserve `AppRuntime` across surface detach, reject stale
  generation responses, and use terminal application destroy only when the
  application is actually discarded.
- Android, iOS, and HarmonyOS app entrypoints call their typed backend's
  `install_embedding` with an app runtime factory and renderer configuration.
  The backend keeps the adapter private and registers shell callbacks; only
  `moui_shell/embedding` owns the fixed Embedding API v1 native export list.
  Entries must not declare ABI exports or construct embedding adapters directly.
- Product class remains `runtime_partial`. Managed/plugin/ejected fallback
  packaging and ABI structure are validated, but these do not upgrade platform
  readiness. Fresh matching-host runtime evidence is still required before any
  Android, iOS, or HarmonyOS status promotion.
