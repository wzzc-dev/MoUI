# Release Readiness

This page turns the 2026 roadmap into an auditable preview-release checklist.
It does not replace `docs/roadmap-2026.md`; it records the current evidence,
known gaps, and next implementation slices needed before MoUI can be presented
as a preview baseline for real MoonBit app development.

## Preview Baseline Definition

MoUI is preview-ready when the repository can demonstrate all of these claims
with current files and validation output:

- The platform-neutral runtime pipeline remains explicit:
  `View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer`.
- Public view constructors return opaque `@core.View[Msg]`; app code uses the
  TEA-shaped `Program` surface with typed messages, explicit `Effect[Msg]`
  follow-up work when needed, app-level `Subscription[Msg]` event sources for
  ongoing callbacks and pending host-service completions, and shared logic
  through Web wasm-gc, macOS native, and Windows native entrypoints where those
  platforms are supported.
- Renderer capability status is synchronized between
  `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
  `docs/renderer-capability-report.md`.
- High-risk behavior uses the same four-layer conformance model: `core`
  contract tests, host routing tests, implementation/provider tests, and
  matrix/diagnostic conformance entrypoints.
- Showcase and Markdown Editor serve as runnable documentation rather than
  hidden smoke tests.
- Showcase remains the preferred visible validation surface for framework
  features: new user-facing views, renderer capabilities, host-service flows, or
  example-worthy platform behaviors should add Showcase coverage unless they are
  impossible or misleading to demonstrate there.
- Platform backends stay adapters around `backend/host`; unsupported platform
  paths are marked as scaffolds instead of implied as complete.
- Development validation is bounded, repeatable, and documented.
- `AGENTS.md` and repo-local skills remain aligned with package boundaries,
  validation commands, examples, renderer capability rules, and text-system
  architecture.

## Current Evidence

| Area | Evidence | Status |
| --- | --- | --- |
| Daily validation | `sh scripts/dev-check.sh` passes after the Windows Showcase unused import cleanup. | ready |
| Package boundaries | `docs/architecture.md`, `AGENTS.md`, and repo-local skills describe the same `core` / `views` / `backend` / `render` / `examples` split. | ready |
| Public view model | `views/` constructors are documented as returning opaque `@core.View[Msg]`; `Program::simple`, `Program::new`, `Effect[Msg]`, and app-level `Subscription[Msg]` are the app-facing TEA surface; public API edits require `moon info`. `Effect::host_service` standardizes host-service effect descriptor kind while leaving concrete host calls outside `core`, `Effect::service_task` standardizes service-like one-shot task descriptors, and `Effect::task` covers custom one-shot cancellable app tasks with active/completed/cancelled lifecycle diagnostics, including `EffectTaskKindChanged` when a same-key replacement changes descriptor kind; `Subscription::timer`, `Subscription::animation_tick`, `Subscription::window_event`, `Subscription::host_event`, `Subscription::route_event`, and `Subscription::service_completion` standardize common ongoing-source descriptor kinds while leaving concrete adapters outside `core`; subscription reuse now requires both key and kind to match, and same-key kind changes restart the source with `SubscriptionKindChanged` lifecycle diagnostics; `backend/host` exposes `HostAppServices::completion_subscription` for app-owned pending host-service completions, `HostEventSource::subscription` for typed host-event fanout subscriptions, `HostWindowEventSource::subscription` for window-scoped platform event subscriptions, `HostTimerSource::subscription` for scheduler-backed timer subscriptions, and `HostRouteSource::subscription` for typed route/deep-link fanout. Canceled completion subscriptions release queue handlers so late responses are retained as completed records, canceled host-event, host-window-event, and host-route subscriptions remove their publisher handlers, and canceled host-timer subscriptions run the scheduler cleanup so late callbacks are counted by stale-dispatch diagnostics. Browser history, native URL bars, OS deep-link dispatch, and automatic app history mutation remain platform/app follow-up work outside `core`. | ready with platform history follow-ups |
| Example shape | Showcase and Markdown Editor keep shared app logic under `examples/*/app/` with platform entrypoints as wiring; File Importer demonstrates effect-capable host-service flow through `Program::new`, typed completions, pending host-service completion subscriptions that re-enter the TEA message loop, and parent/child composition through `View::map`, `Effect::map`, and `Subscription::map`, with parent-runtime assertions for mapped effect descriptors, active completion subscription descriptors, and cancellation lifecycle diagnostics. Showcase Navigation Shell now exercises `RouteHistoryState` as app-owned route/deep-link shadow history, a sampled fade/slide route transition preview, and `resizable_split_view` as a controlled pane-size workflow, while the Data Table example exercises `ColumnWidthState`/`ColumnOrderState` for controlled column resizing/reordering without moving table state into `views`. Browser history/native deep-link dispatch and automatic transition scheduling remain pending host/app work, not MoUI runtime evidence. | ready |
| Renderer capability tracking | Capability status is recorded in code, tests, and `docs/renderer-capability-report.md`. | ready with tracked gaps |
| Platform contracts | `backend/host` owns shared events, services, windows, redraw, and request/completion contracts. | ready with tracked Linux service gaps |
| Text system | `docs/text-system.md` documents `TextSystem`, provider composition, embedded fonts, Skia `skia_text_system()` diagnostic coverage, and shaping gaps; stable and diagnostic text conformance checks pass without claiming full bidi/paragraph shaping parity. | ready with tracked gaps |
| Devtool counters | Core inspector snapshots expose runtime, cached layout, cached semantics, cached render command, structured dirty-state summaries with dirty element ids for pending rebuild/layout/paint/redraw work, rebuild/layout/paint/draw-command pass counters, TEA dispatch/update/message-queue/effect-plan/effect-kind counters that distinguish send, anonymous dispatch, structured run, and one-shot task effects, latest effect summaries with structured effect descriptors, aggregate duplicate effect descriptor-key counters/names, active/completed/cancelled effect-task counters and lifecycle entries, subscription-plan counters/summaries with planned source descriptors, aggregate duplicate subscription-key counters/names, active subscription descriptors, active subscription kind-count summaries, app subscription lifecycle entries, ignored stale effect-task/subscription dispatch counters, and ignored program-dispatch counters for late anonymous or structured effect callbacks after runtime destruction; inspector capture does not drain pending dirty work, render snapshots also report open clip/layer/filter scopes and unbalanced pops, and Showcase Diagnostics surfaces render command/scope counters plus dirty summary, TEA message, structured effect, effect-task, subscription plan, active subscription, subscription kind summary, and descriptor labels with app-test coverage. | ready for command-level diagnostics |
| Guidance surface | `docs/ai-collaboration.md`, `AGENTS.md`, and `skills/` define focused agent workflows. | ready |

## Required Gates

Before calling a preview-release handoff complete, collect fresh evidence for:

| Gate | Required Evidence | Command Or Artifact |
| --- | --- | --- |
| Daily baseline | Bounded package checks and Web wasm-gc example builds pass. | `sh scripts/dev-check.sh` |
| Public API audit | Generated interfaces reviewed after public API changes. | `moon info` plus `pkg.generated.mbti` diff review |
| Renderer sync | Capability code, tests, docs, and visible Showcase coverage agree. | `moon test moui/render --target native`, `moon test moui/render/wgpu --target native`, `moon test moui/render/webgpu_adapter --target wasm-gc`, Showcase Web build |
| Focused conformance | Input/focus, layout, render, platform service, and text slices pass at their owning layer. | `sh scripts/conformance-check.sh --input`, `--layout`, `--render`, `--platform-services`, `--text`, `--text-diagnostic` |
| Text conformance | Stable text contracts and diagnostic gaps are current. | `sh scripts/conformance-check.sh --text`, `sh scripts/conformance-check.sh --text-diagnostic` |
| Web runtime presentation | Web Showcase and Markdown Editor run in a browser session with WebGPU, wasm startup, sized canvas, resize/input event-bridge delivery, Markdown Editor text input, clean target close, clean console, and nonblank screenshots recorded before Web runtime claims are marked passed. The Web fold must retain provenance: `github-actions` with CI workflow/job/run URL/runner when produced by the successful non-skipped `web-runtime-presentation` Actions job, or `matching-host-artifact` with the local browser-session artifact bundle when produced on a matching host. | `sh scripts/ci-web-runtime-presentation.sh` in CI or on a configured matching host; manual equivalent: `node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed`, then `node scripts/validate-web-runtime-presentation-manifest.mjs artifacts/conformance/web-runtime-presentation.json --require-passed` |
| Platform contracts | Shared host and active backend behavior stay covered, and matching-host runtime evidence has a validated manifest when claimed. | `moon test moui/backend/host --target native`, `moon test moui/backend/web --target wasm-gc`, `sh scripts/dev-check.sh --platform-examples-test` when platform behavior changes, `node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...`, `node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json`, `node scripts/validate-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json` |
| Examples | Showcase and Markdown Editor remain runnable docs; new user-facing features have visible Showcase coverage or a recorded reason to skip it. | App package tests plus Web wasm-gc builds |
| Guidance freshness | Docs, `AGENTS.md`, and repo-local skills agree after guidance-affecting changes. | `node scripts/validate-guidance-consistency.mjs` plus manual audit notes in the handoff |

## Current Evidence Snapshot

This snapshot records the current preview-readiness evidence gathered on
2026-05-26, focused renderer/example follow-up evidence gathered on
2026-05-31, Skia/capture-manifest evidence refreshed on 2026-06-02, macOS
real-Skia Showcase/Markdown first-frame evidence refreshed on 2026-06-03, and
Skia image lifecycle callback and host bridge evidence refreshed on 2026-06-04.
Refresh the full gate set before a release candidate handoff.

| Gate | Current evidence | Status |
| --- | --- | --- |
| Daily baseline | `sh scripts/dev-check.sh --platform-examples-test` passed on Darwin on 2026-06-02 after the Skia descriptor integration, capture-manifest validator self-test, Web runtime handoff validator, local-dependency window evidence-surface guard, and macOS backend/provider checks. The local dependency guard now also verifies the `moui_skia` platform status and native capability contracts with `skia-platform-status.json`, `native/capabilities.json`, `verify-platform-status.sh`, and `verify-native-capability-contract.sh`. On 2026-06-03, `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke` passed on Darwin with the pinned JetBrains Skia provider, covering MoUI renderer pixels plus first-frame Showcase and Markdown Editor macOS Skia presentation. | current for Darwin host |
| Public API audit | The TEA diagnostics slices added message-queue counters, ignored program-dispatch counters for late callbacks after `AppRuntime::destroy()`, `RuntimeDirtyStateSummary`, dirty element ids on `RuntimeDirtyStateSummary` / `RuntimeInspectorSnapshot` / `AppRuntime::dirty_element_ids`, rebuild/layout/paint/draw-command pass counters, `EffectDescriptor`, `Effect::run`, `Effect::host_service`, `Effect::task`, `Effect::service_task`, `EffectTaskLifecycleStatus`, `EffectTaskCancelReason` including `EffectTaskKindChanged`, `EffectTaskLifecycleSnapshot`, `EffectPlanKind`, `EffectPlanSummary`, `Effect::plan_summary`, structured effect descriptors, `EffectPlanRun` / `run_count` / `task_count` diagnostics, duplicate descriptor-key counts/names in effect summaries, aggregate structured run/task plus duplicate effect descriptor-key counters/names on `ProgramRuntimeSnapshot` / `RuntimeInspectorSnapshot`, `SubscriptionPlanKind`, `SubscriptionPlanSummary`, planned descriptors and duplicate key names on `SubscriptionPlanSummary`, `Subscription::plan_summary`, standard subscription source helpers (`timer`, `animation_tick`, `window_event`, `host_event`, `route_event`, `service_completion`), `SubscriptionKindCount` with active subscription kind summaries on `ProgramRuntimeSnapshot` / `RuntimeInspectorSnapshot`, aggregate duplicate subscription-key counters/names, ignored effect-task/subscription dispatch counters, active effect-task/subscription descriptors and lifecycle entries on `RuntimeInspectorSnapshot`, `SubscriptionKindChanged` lifecycle cancellation diagnostics for same-key source kind changes, and effect/subscription-plan fields on `ProgramRuntimeSnapshot` / `RuntimeInspectorSnapshot`; the async image diagnostics slice added `ImageResourceLifecycle::snapshot`, `ImageResourceLifecycle::snapshot_with_revision`, `ImageResourceSnapshot`, and renderer/backend `image_resource_snapshot()` accessors alongside existing `image_resources()` record APIs; the native async image apply-port slice adds `ImageResourceLoadCompletion`, `ImageResourceLifecycle::apply_load_completion`, `HostWindowRenderer::apply_image_resource_load_completion`, and `HostImageResourceCompletionSource::complete`; the Skia image notification slice added the `create_with_present_target(... on_image_resource_change?)` hook and `SkiaRasterRenderer::set_image_resource_change_callback()` for renderer-local revisioned callback snapshots; native renderer diagnostics added `HostWindowRenderer::image_resources`, `HostWindowRenderer::image_resource_snapshot`, `HostWindowRenderer::set_image_resource_change_callback`, and the renderer-neutral `HostImageResourceRepaintTracker` / `HostImageResourceRepaintResult` / `HostImageResourceRepaintSnapshot` APIs for per-window revision routing and tracked-window diagnostics, including `HostImageResourceRepaintTracker::request_redraw_for_snapshot_if_changed`, `HostImageResourceStatusCounts` summaries for loading/ready/failed/disposed records on tracked-window snapshots and previous/current repaint results; the native async image completion slice adds `HostImageResourceCompletionSource`, `HostImageResourceCompletionSource::publish`, and completion routing diagnostics; the Skia renderer diagnostics slice added `SkiaUnsupportedCommandDiagnostic` and `SkiaRasterRenderer::unsupported_command_diagnostics()` while keeping `unsupported_command_count()` as the count summary; the app-owned async service completion slices add `HostAppServices::on_completed` and `HostAppServices::completion_subscription`; the host-event adapter slice adds `HostEventSource::new`, `HostEventSource::subscription`, `HostEventSource::publish`, and `HostEventSource::active_handler_count`; the host-window adapter slice adds `HostWindowEvent`, `HostWindowEventSource::new`, `HostWindowEventSource::publish`, `HostWindowEventSource::active_handler_count`, and `HostWindowEventSource::subscription`; the host-route adapter slice adds `HostRouteEvent`, `HostRouteEvent::from_route`, `HostRouteSource::new`, `HostRouteSource::publish`, `HostRouteSource::active_handler_count`, and `HostRouteSource::subscription`; the host-timer adapter slice adds `HostTimerSource::new` and `HostTimerSource::subscription`; `HostCapabilitySummary::preflight_fields()` is the renderer-neutral ready/gap formatter used by native provider audits; macOS, Windows, and Linux Skia provider packages expose `*_skia_provider_preflight_summary()` as intentional package/preflight audit APIs, not runtime evidence. | current |
| Renderer sync | `render/capabilities.mbt`, `render/capabilities_test.mbt`, and `docs/renderer-capability-report.md` remain the source of truth. `sh scripts/conformance-check.sh --render` passed after follow-up evidence was tightened for transform, text shaping, emoji text, and async image. A focused async-image refresh on 2026-05-31 passed `moon test moui/render --target native`, `moon test moui/render/webgpu_adapter --target wasm-gc`, `moon test moui/backend/web --target wasm-gc`, `moon test examples/showcase/app --target native`, and `moon build examples/showcase/web_wasm --target wasm-gc`. Native WGPU and Skia providers now forward renderer image-resource records plus revisioned snapshots through `HostWindowRenderer`, with host facade coverage in `moui/backend/host`; `ImageResourceLoadCompletion`, `ImageResourceLifecycle::apply_load_completion`, and `HostWindowRenderer::apply_image_resource_load_completion` provide the renderer-neutral apply port for native loader ready/failed results; macOS, Windows, and Linux hosts now baseline presented revisions, route repaint requests to the matching open window when a newer revision is observed, expose previous/current repaint status counts plus tracked-window revision/status-count snapshots, and discard closed-window image changes. Skia raster also emits renderer-local image-resource change callback snapshots on lifecycle revision advances; native Skia providers forward callback setters through `HostWindowRenderer`, and native hosts install baseline-guarded callbacks that schedule redraw for post-present image revisions. Host-layer native async image completion routing is covered by `backend/host` tests; provider/platform async loader scheduling and matching-host runtime artifacts remain required before marking async image ready. The local `moui_skia` update added surface target, frame finalization, renderer resource-plan, font fallback, text shaping descriptors, and binding-level platform status/native capability contracts. MoUI now consumes the descriptors through Skia raster surface creation, `Surface::flush_and_submit`, `raster_surface_preflight`, and `skia_text_descriptor_preflight`, while `scripts/check-local-deps.sh` runs `verify-platform-status.sh` and `verify-native-capability-contract.sh` to guard `skia-platform-status.json`, `native/capabilities.json`, the JetBrains provider lock, fallback parity, FFI ownership/borrow metadata, native smoke capability markers, and CI gate evidence wiring. On 2026-06-02, `moon test moui/render/skia --target native` and `moon check moui/render/skia --target native` passed after this Skia descriptor integration; on 2026-06-04, focused host/macOS Skia/Linux Skia checks passed after adding renderer-local image lifecycle callback coverage and the host/provider callback bridge. | current with tracked renderer gaps |
| Focused conformance | `sh scripts/conformance-check.sh --input`, `--layout`, `--platform-services`, `--text`, and `--text-diagnostic` passed. On 2026-06-02, `--platform-services` found the local window checkout's generated Wayland protocol sources, ran `moui/backend/linux --target native` alongside host/Web/macOS service checks, and validated the platform runtime evidence manifest scaffold at `artifacts/conformance/platform-runtime-evidence.json`. The manifest now includes a native-only `skiaEvidence` block so Skia provider/preflight, fallback-unavailable behavior, real renderer smoke, and Showcase/Markdown first-frame status are audited separately from full platform-service observations. | current with host/setup-scoped Linux service evidence, passed macOS Skia route evidence, and pending full runtime manifest contract |
| Text conformance | Stable text conformance covers core, native renderer/provider validation, Web adapter, and Web backend. Core fallback carets now keep per-character arrays while stabilizing representative variation-selector, combining-mark, emoji modifier, keycap, ZWJ, regional-indicator, tag-sequence, prepend-mark, script-mark, and Hangul Jamo cluster interiors for deterministic selection and IME-anchor geometry; basic left/right caret movement and shift-selection skip the same representative cluster interiors. Diagnostic matrix tests cover core fallback, Cosmic, platform-default composed fallback/scaffolds, malformed-provider fallback, and Web text systems where available. Web host capability reporting now advertises browser IME plumbing because `window/web` accepts `TextInputSession` IME requests and emits browser composition lifecycle events; shaping/color-emoji parity remains tracked separately. | current with shaping/color-emoji gaps documented |
| Platform contracts | `backend/host` now covers post-close queued window command rejection, completion recording, app-owned async service completion callbacks, shared host-event subscription fanout through `HostEventSource`, window-scoped subscription fanout through `HostWindowEventSource`, route/deep-link subscription fanout through `HostRouteSource`, shared scheduler-backed timer subscriptions through `HostTimerSource`, shared text-input session requests, and the renderer-neutral image-resource change callback bridge on `HostWindowRenderer`. Web host capabilities now report IME readiness for the browser composition/request bridge while keeping deterministic browser shaping out of scope. Linux adapter tests cover the window fork's Wayland key/modifier mapping and current button-event coordinates through shared host conversion. Skia platform entrypoints preflight renderer availability before host app assembly, and macOS/Windows/Linux Skia providers now expose public preflight summaries that record renderer availability, `moui_skia/native` availability, selected font resolution, presenter path, the renderer-neutral `HostWindowRenderer` bridge for forwarding Skia text-system, image-resource snapshots, image-resource change callbacks, present-count, and disposal diagnostics, inherited host service/input/window readiness, clipboard/menu/file-dialog/open URL/system-theme/async-service readiness, text-input/IME/drag-drop readiness, native context-menu readiness, host-modal file-dialog readiness, native accessibility status, first-frame smoke option state, and runtime evidence boundary. macOS marks first-frame smoke as required for Skia route proof; its `skiaEvidence` entry is passed after the 2026-06-03 real-Skia renderer smoke plus Showcase/Markdown first-frame artifact refresh, while the broader macOS platform entry remains pending until full platform-service observations are recorded. Windows/Linux now have renderer-neutral `exit_after_first_present` host options and Skia entrypoint env flags for matching-host first-frame runs, but remain `matching-host pending` until those runs record passed artifacts. Native Skia route recording now rejects provider-preflight logs that do not name the matching Skia provider/preflight surface as well as a passing marker. `sh scripts/dev-check.sh --platform-examples-test` passed on Darwin on 2026-06-02, including `moui/backend/macos`, `moui/backend/macos/wgpu`, and `moui/backend/macos/skia`; `moon test moui/backend/linux/skia --target native` also exercises the Linux Skia preflight summary on hosts where the package compiles. `moon test moui/backend/windows/skia --target native` remains a Windows/MSVC package check because the Win32 C stubs require `windows.h` and intentionally fail on Darwin. The local `window` fork's MoUI smoke/evidence files are now checked by `scripts/check-local-deps.sh`; `scripts/conformance-check.sh --platform-services` writes a validated pending platform runtime evidence manifest so Windows/Linux runtime claims must be filled in from matching hosts. | current for Darwin Skia route and package/preflight evidence; full macOS and Windows/Linux runtime evidence remains host-limited |
| Examples | `moon test examples/showcase/app --target native`, `moon test examples/markdown_editor/app --target native`, and both Web wasm-gc builds passed under `sh scripts/dev-check.sh --platform-examples-test` on Darwin on 2026-06-02. Showcase capability cards now surface follow-up rows first, and the host capability card has app-test coverage for injected host summaries; native Showcase Skia entrypoints are statically validated to inject the matching platform capability summary. Markdown Editor app tests cover Unicode paste through runtime undo/redo, and File Importer app tests cover pending file-dialog completion through typed TEA messages plus mapped parent/child effect/subscription diagnostics. On 2026-06-03, the macOS Skia helper built and launched both `examples/showcase/macos_skia` and `examples/markdown_editor/macos_skia` with first-frame exit markers after the renderer pixel smoke. Showcase and Markdown Editor now both expose Windows/Linux Skia first-frame env flags for matching-host smoke runs; package checks prove their provider wiring, but Windows/Linux runtime evidence remains matching-host pending until those commands record passed artifacts. `sh scripts/conformance-check.sh --bench` also rebuilt Showcase and Markdown Editor Web wasm-gc targets, validated their static Web runtime handoff, and validated benchmark manifest targets for both examples. `scripts/record-web-runtime-presentation.mjs` and `scripts/validate-web-runtime-presentation-manifest.mjs` now define the browser-session evidence path for `artifacts/conformance/web-runtime-presentation.json`, and `scripts/record-platform-evidence-manifest.mjs ... web --web-presentation-manifest ...` folds that browser artifact into the Web platform runtime entry. Chrome headless WebGPU presentation passed for Showcase and Markdown Editor after the browser runtime started reporting WebGPU uncaptured errors and the advanced shader switched blur/backdrop reads to explicit-LOD sampling; the recorder now also requires resize/input/text-input/target-close event-bridge evidence before the Web platform entry can be marked passed. GitHub Actions now has a non-skipped `web-runtime-presentation` job wired to run the same record/fold/validate path and upload `moui-web-runtime-presentation`; cite it as CI evidence only after a successful run uploads the artifact bundle. | current with Darwin Skia first-frame, Markdown Skia package evidence, and browser presentation evidence paths; Web CI evidence path configured pending first successful Actions artifact; Windows/Linux runtime evidence remains matching-host pending |
| Guidance freshness | `AGENTS.md`, framework skill, app skill, docs, README entrypoint wording, provider package paths, and example entrypoints are covered by `scripts/validate-guidance-consistency.mjs` after guidance-affecting updates. On 2026-06-02, the guidance guard passed after adding the capture manifest validator self-test and benchmark target checks. | current |

## Platform Validation Matrix

Preview handoffs must say which host produced platform evidence. Platform
claims should be scoped to the host that ran them; do not use a macOS check as
runtime evidence for Windows or Linux native behavior.
When GitHub CI is used as the authority, only non-skipped successful jobs with
uploaded logs, manifests, screenshots, or first-frame artifacts may support a
`status=passed` runtime claim. Workflow-dispatch paths that were not run,
build-only jobs, package-only jobs, and provider/preflight audits must stay
pending or be described as narrower setup evidence.

| Host | Routine command | What it proves | What remains out of scope |
| --- | --- | --- | --- |
| macOS / Darwin | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/macos` native backend tests on the current macOS host. The Skia provider test audits `macos_skia_provider_preflight_summary()` as provider/package evidence; `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke` is the local real-Skia renderer plus first-frame runtime evidence path. | Windows native backend/runtime behavior, Windows packaging helper runtime behavior, Linux runtime backend behavior, and slow native example builds unless `--platform-examples-build` is also run. The provider preflight summary is not runtime evidence. |
| Windows / MSVC | `powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 -Package examples/showcase/windows -BuildOnly` | Windows native build evidence with Visual Studio C++ tools, vcpkg zlib, and dynamic WGPU; pair with `moon test moui/backend/windows --target native`, `moon test moui/backend/windows/wgpu --target native`, and `moon test moui/backend/windows/skia --target native` from `msvc_env.ps1` for backend/provider tests. The Skia provider test audits `windows_skia_provider_preflight_summary()` as provider/package evidence. | macOS AppKit behavior, Linux backend behavior, and packaged app runtime launch unless `package_windows_app_msvc.ps1`, `run.cmd`, and the Windows Showcase/Markdown Skia entrypoints are also exercised. The provider preflight summary is not runtime evidence. |
| Linux | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/linux` and `backend/linux/skia` native backend/provider tests on a Linux host with Wayland headers. The Skia provider test audits `linux_skia_provider_preflight_summary()` as provider/package evidence. | Real Wayland compositor/runtime behavior unless the Showcase and Markdown Editor `moon run` commands are also run under Wayland with a usable Vulkan stack; clipboard, menu, dialog, drag/drop, IME, AT-SPI, and native font provider work remain tracked gaps. The provider preflight summary is not runtime evidence. |
| Local `window` fork evidence | `sh scripts/check-local-deps.sh`; matching-host `.local_repos/window/scripts/check_moui_*_smoke.sh` and `.local_repos/window/scripts/record_moui_evidence.sh` when collecting dependency runtime evidence. | The local dependency checkout exposes the MoUI-oriented smoke/evidence files, including Web/macOS smoke templates and Linux/Windows matching-host pending templates from `.local_repos/window/docs/moui-integration-smoke.md`. | These scripts prove the window fork evidence surface exists; passed native runtime evidence still must be recorded on matching hosts and does not replace MoUI Showcase/Markdown Editor platform entrypoint evidence. |
| Local `moui_skia` status evidence | `sh scripts/check-local-deps.sh`; `moui_skia/scripts/verify-platform-status.sh`; `moui_skia/scripts/verify-native-capability-contract.sh`. | The repo-local editable Skia binding workspace exposes `skia-platform-status.json`, `skia-provider-lock.json`, `SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`, verifier scripts, CI gate evidence wiring, fallback parity, FFI ownership/borrow metadata, native smoke capability markers, and a pinned JetBrains provider artifact lock. | This is binding-level dependency acceptance evidence. It does not prove MoUI renderer pixels or platform entrypoint runtime behavior; those still require `sh scripts/dev-check.sh --skia-real-smoke`, `scripts/macos-skia-renderer-smoke.sh`, or matching-host Showcase/Markdown Editor runs. |
| Web runtime presentation manifest | `sh scripts/ci-web-runtime-presentation.sh` or `node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed`; then `node scripts/validate-web-runtime-presentation-manifest.mjs artifacts/conformance/web-runtime-presentation.json --require-passed` | The recorder opens Showcase and Markdown Editor in a Chrome DevTools Protocol browser session and records page status, WebGPU availability, adapter/device request signals, wasm startup, canvas sizing, resize delivery, representative pointer/keyboard input, Markdown Editor text input, clean target close, console errors, and screenshot nonblank thresholds. Folding that manifest into the platform evidence derives `github-actions` provenance when the fold runs in the `web-runtime-presentation` Actions job, or `matching-host-artifact` provenance for local matching-host folds. | This is browser-session evidence for the named Chrome run only. It does not prove cross-browser behavior, deterministic golden pixels, or Windows/Linux native runtime behavior. CI provenance proves where the browser-session artifact was produced and uploaded; it does not replace a passed presentation manifest. Failed manifests may be folded into the Web platform evidence entry as failed evidence, but must stay out of passed Web runtime claims. |
| MoUI runtime evidence manifest | `sh scripts/conformance-check.sh --platform-services`; then `node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...`, `node scripts/record-native-skia-evidence.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...` for matching-host native Skia logs, `node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json`, and `node scripts/validate-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json` | The schema v2 manifest records the required Web/macOS/Windows/Linux runtime evidence shape, expected Showcase/Markdown Editor targets including native Skia variants, window-fork recorder command, consumer command, observations, artifact paths, and passed-entry provenance. It mirrors the window fork's monitor/cursor evidence as `monitorCursor`; native passed entries must record it as `yes`. Native entries also include `skiaEvidence` for Skia provider/preflight, fallback-unavailable, real renderer smoke, and Showcase/Markdown first-frame status; native platform `passed` requires that Skia block to be `passed` too. The platform recorder updates one platform entry and revalidates it so matching-host results do not require hand-editing JSON; the native Skia helper validates Skia log markers and updates only `skiaEvidence`; for Web the recorder derives passed or failed platform observations from the browser presentation manifest. | A pending manifest is only a contract. It becomes runtime evidence only after the platform entry records enough passed observations, artifacts, and `evidenceProvenance` for the platform being claimed. Passed provenance must trace to a non-skipped successful GitHub Actions job/run or to a matching-host artifact bundle. A passed `skiaEvidence` block is Skia-route proof, not full platform-service proof by itself, and the native Skia helper deliberately leaves the broader platform status unchanged. A Web presentation manifest is marked passed only when the browser session includes resize/input/text-input/shutdown platform observations and browser-session artifact provenance; Web may leave `monitorCursor` pending because browser CDP evidence does not prove native monitor/current-monitor or cursor probes. |

For release candidates on a configured host, add:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Record any skipped native example builds as host/setup limits rather than
silently broadening the evidence claim.

## Showcase Capability Alignment

Showcase is the visual catalog and the preferred place to verify new
user-facing framework features. When adding a public view, visible renderer
capability, host-service workflow, or platform behavior that users can
reasonably inspect, add a Showcase demo plus app-level assertions in
`examples/showcase/app` and keep the Web wasm-gc build passing. If a feature is
not useful or possible to demonstrate there, record the reason in the relevant
docs or handoff.

Showcase is still not automatically proof that every renderer feature has an
end-to-end visual demo. Treat the Showcase renderer section as two surfaces:

- The capability card lists `render.renderer_feature_capability_report()` so
  users can inspect the current status data. It shows follow-up rows before
  ready rows so visible docs keep partial and gap items in view.
- The visual cards and app tests provide stronger evidence only for the draw
  commands they actually emit.

Current alignment:

| Renderer feature | Showcase visibility | Current app-level evidence | Release-readiness note |
| --- | --- | --- | --- |
| Rect / rounded rect | Visual panels and layout tiles. | Showcase app tests inspect rounded-rect marker output. | Covered as ordinary surface/control drawing. |
| Gradient | Visual styling and sparkline/card brushes. | Showcase app tests assert `FillRoundedRectBrush` with `LinearGradient` and `RadialGradient`; renderer tests cover Skia radial brush pixels and WGPU/Web deterministic radial fallback. | Covered by visible demo plus command-level app test. |
| Shadow | Theme/renderer cards and panels. | Showcase app tests assert `DrawShadow`. | Covered by visible demo plus command-level app test. |
| Text | Most catalog sections plus the Text Diagnostics `Text Frame Clip` card. | Showcase app tests assert many section labels, renderer report text, and a deliberately narrow `TextRun.frame` sample. | Covered broadly as view output, while shaping conformance remains tracked in text tests. |
| Image | Text/media and visual correctness cards. | Showcase app tests assert `DrawImage` plus scale-down/fit-width/fit-height image fits; renderer/Web adapter tests cover image lifecycle snapshots. Skia renderer tests cover ready PNG/JPEG/BMP data URI and local-file decode, contain/cover/stretch/scale-down/fit-width/fit-height placement geometry, immutable failed-cache reuse, local-file retry once a missing file appears, and failed placeholders. | Covered for visible image commands; async diagnostics are partial but Web snapshots now refresh ready/failed records from the browser image cache after host submission. |
| Clip | Scroll/capability card and clipped image demos. | Showcase app tests assert `PushClip` and clipped long renderer content; Web adapter tests preserve rounded clip host calls. | Covered for visible clipping; Web rounded clip submit uses the browser layer-mask path. |
| Transform | Capability card lists follow-up status first while WGPU/Web remain partial; visual correctness image uses scale/offset. | Native renderer tests cover scoped layer/filter transform/clip inheritance, transformed filter child vertices/scissors, shader-effect advanced-vertex transform state, and masked layer composite vertices; Skia real smoke covers translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform pixels; Web adapter tests preserve transform scope around layer, filter, and shader-effect commands, the browser runtime applies transform to shader-effect advanced vertices, and Chrome headless presentation evidence now reaches Running with clean WebGPU console for Showcase and Markdown Editor. Showcase app tests assert the follow-up row is visible. | Skia is ready; keep overall follow-up visible until WGPU/Web broader render-pass transform pixel evidence exists. |
| Opacity | Visual correctness image and state-driven visuals. | Showcase app tests assert `PushOpacity`. | Covered for view-level opacity emission; renderer-specific blending remains renderer evidence. |
| Layer compositing | Advanced Rendering includes a layer/blend card. | Showcase app tests assert `PushLayer`/`PopLayer`, rounded layer masks, and non-default blend payloads; Skia renderer-local pixel tests cover rectangular masked opacity output; Chrome headless Web presentation runs the Showcase and Markdown Editor WebGPU pages with clean WebGPU console after advanced shader validation fixes. | Covered by visible Showcase demo plus command-level/browser-presentation evidence; renderer tests remain primary evidence for pixel semantics. |
| Blend mode | Advanced Rendering includes multiply, screen, and overlay layer scopes. | Showcase app tests assert `Multiply`, `Screen`, and `Overlay` layer blend payloads; Skia renderer-local pixel tests cover multiply output; Web overlay backdrop sampling now uses explicit-LOD texture sampling so Chrome WGSL validation accepts the advanced pipeline. | Covered by visible Showcase demo plus command-level/browser-presentation evidence; renderer tests remain primary evidence for exact blend math. |
| Filter effect | Advanced Rendering includes a blur filter card. | Showcase app tests assert `PushFilter(FilterEffect::Blur(_))` plus `PopFilter`; Web blur sampling now uses explicit-LOD texture sampling so Chrome WGSL validation accepts filter branches selected from fragment input; Skia renderer-local tests cover saturation output and identity-normalized short/long color-matrix payloads before native filter creation. | Covered by visible Showcase demo plus command-level/browser-presentation evidence; renderer tests remain primary evidence for filter pixels. |
| Path/vector | Theme/renderer section includes a vector path card that emits filled and stroked `DrawPath` commands. | Renderer tests cover `PathSpec` tessellation, native draw-plan path items, Web host-call forwarding, fallback planning that keeps visible `DrawPath` out of fallback diagnostics, and Skia renderer-local solid/linear-gradient path pixels; Showcase app tests assert `DrawPath` emission. | Covered by visible Showcase demo plus renderer/Web adapter command-level evidence; Skia renderer-local pixels are renderer evidence, not platform runtime evidence. |
| Shader effect | Advanced Rendering includes checker and vignette shader cards. | Showcase app tests assert `DrawShaderEffect` payloads for `checker` and `vignette`; Skia renderer-local pixel tests now cover `checker`, `linear-gradient-debug`, and `vignette`. | Covered by visible Showcase demo plus command-level app test; renderer tests remain primary evidence for shader pixels. |
| Text shaping | Capability card lists follow-up status first; text/media section exercises text views. | Text conformance tests are primary evidence; Skia text now resolves `FontSpec` family, weight, style, and representative coverage characters through Skia `FontMgr` `FontFallbackRequest`/`Font`, splits mixed-script text into grapheme-safe fallback segments for per-run FontMgr resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interiors in both caret paths, retries emoji font candidates on the system FontMgr path, clips aligned glyph drawing to `TextRun.frame`, and renders through optional SkShaper shaped glyph runs when linked or positioned glyph runs otherwise. The native diagnostic matrix now also injects `skia_text_system()` into a public `AppRuntime` text field and asserts that composition caret geometry and selection highlight drawing consume the Skia measurement path; this is app-runtime geometry evidence, not native-platform IME runtime evidence. The local `moui_skia` text descriptor update is consumed by `skia_text_descriptor_preflight`, which audits fallback, measurement, shaping, shaped-run, and shaped-glyph resource plans in fallback-safe tests; this is cache/resource-key evidence, not typography parity evidence. `backend_info()` now also includes a fallback-safe `text maturity audit partial` summary that counts the audited Skia baseline and mixed-run fallback separately from tracked bidi, paragraph line-breaking, color emoji, and full-grapheme gaps. macOS Skia provider defaults now match Windows/Linux by selecting `SystemFontMgr` for normal Showcase, Markdown Editor, and Mo Workbench entrypoints, while macOS first-frame smoke entrypoints explicitly switch to `EmptyTypeface` only when their exit-after-first-present flag is set. Default renderer smoke continues to cover Skia FontMgr/SkShaper evidence plus bounded `TextRun.frame` clipping; provider validation rejects non-empty run-layout carets that do not cover the input, and Cosmic run-layout tests assert glyph output plus monotonic caret coverage through the provider-safe mapped layout path for representative emoji clusters. Showcase app tests assert the follow-up row is visible. | Do not use Showcase labels, Skia descriptor resource plans, the text maturity audit, or basic Skia font matching/metrics/caret measurement as proof of bidi/line-breaking/color-emoji/typography parity. |
| Emoji text | Capability card lists follow-up status first. | Diagnostic text conformance covers single-codepoint, variation-selector, and ZWJ emoji measurement/caret invariants; renderer tests now cover native RGBA color glyph payload parsing/upload, text vertex shader marking, Cosmic platform emoji fallback loading/resolution, provider-safe Cosmic run-layout caret coverage, Cosmic color swash preservation, CoreText AppleColorEmoji format selection, Skia system-FontMgr `FontFallbackRequest` matching that prefers emoji coverage characters, and fallback caret stabilization for representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interiors. Showcase app tests assert the partial follow-up row is visible. | Keep native/Web/Skia `partial`: the evidence does not prove full native emoji font fallback across all providers, ZWJ/color emoji conformance, browser rasterization determinism, or full grapheme shaping parity. |
| Async image | Capability card lists follow-up status first; image demos render ordinary images. | Native/Web renderer tests expose image resource records plus revisioned snapshots; native WGPU and Skia provider packages now forward snapshots through `HostWindowRenderer`; `moui/render` tests cover `ImageResourceLoadCompletion` ready/failed application on the shared lifecycle, and `moui/backend/host` tests cover per-window revision routing, redraw de-duplication, previous/current repaint result counts plus tracked-window revision/status-count snapshots for loading/ready/failed/disposed records, revision high-water handling that ignores stale lower snapshots, closed-window discard/removal with dropped current counts, the `HostWindowRenderer` image-resource callback setter, `HostWindowRenderer::apply_image_resource_load_completion` forwarding/default behavior, and `HostImageResourceCompletionSource` publish/complete/redraw/stale-revision/closed-window completion routing diagnostics. macOS, Windows, and Linux hosts now use the tracker around their redraw loops and install baseline-guarded renderer callbacks; Skia providers forward callback setters to `SkiaRasterRenderer`, Skia caches immutable failed image sources with diagnostics before placeholder drawing, retries local-file failures when the file later appears, records disposed cached image resources during renderer disposal, and notifies optional renderer-local callbacks with revisioned snapshots for ready/disposed transitions plus unchanged failed-cache de-duplication; backend Web tests cover app/host-visible `WebRenderer::image_resources` and `WebRenderer::image_resource_snapshot`; Web records submitted sources as loading, refreshes ready/failed records from the browser image cache, and the canonical Web boot path schedules a redraw after browser image load/error notifications. | Still partial until provider/platform async loader scheduling and matching-host runtime artifacts prove real native loader completions; Web no longer depends on a manual app action to observe browser image completion. |

If renderer support changes, update this alignment only when Showcase coverage
or its evidence level changes. Otherwise keep the authoritative support status
in `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
`docs/renderer-capability-report.md`.

## Work Queue

These slices are intentionally scoped so each can land with focused tests and
documentation evidence.

### Renderer

1. Layer-level transform state
   - Current status: affine transforms are folded into visual, image, text,
     shader-effect advanced vertices, and masked native layer composite
     vertices. Native scoped layer/filter child plans inherit transform and
     clip while outer opacity is applied at composite time, including
     transformed filter child vertices/scissors; Web scoped layer/filter
     commands clone current transform/clip state through the browser runtime,
     and Web adapter tests preserve transform scope around shader-effect
     commands. Skia real smoke now covers translated, scaled-and-clipped,
     layer-masked opacity, and filter-scoped transform output.
   - Done when: WGPU/Web broader render-pass transform visible/pixel evidence
     is in place, or their remaining limits are explicitly documented for the
     preview handoff.
   - Evidence: renderer tests, `render/capabilities.mbt`,
     `render/capabilities_test.mbt`, `docs/renderer-capability-report.md`, and
     Showcase if visible.

2. Async image diagnostics
   - Current status: renderer-neutral lifecycle records model loading, ready,
     failed, disposed, eviction, and monotonic revisions. Native/Web/Skia
     renderer facades expose image resource records plus revisioned snapshots;
     `ImageResourceLoadCompletion` and
     `ImageResourceLifecycle::apply_load_completion` model renderer-neutral
     ready/failed completion application, and
     `HostWindowRenderer::apply_image_resource_load_completion` exposes the host facade
     apply port;
     native WGPU and Skia provider packages forward renderer snapshots through
     `HostWindowRenderer`, Skia providers forward image-resource callback setters,
     and native hosts install baseline-guarded callbacks; the host image repaint
     tracker baselines presented
     revisions, preserves each window's revision high-water mark when stale
     lower snapshots arrive, routes redraw requests to the matching open window,
     exposes tracked-window revision/status-count snapshots, drops closed-window image changes, and
     `HostImageResourceCompletionSource` publishes native provider/platform
     completion snapshots through that same routing contract;
     Skia caches failed sources with diagnostics
     before placeholder drawing, clears cached images and records disposed
     resources during renderer disposal, notifies optional renderer-local
     callbacks with revisioned snapshots, and the backend WebRenderer facade
     forwards Web snapshots to app/host integration code.
     Web refreshes submitted sources from the browser image cache that is
     updated by `Image.onload` / `Image.onerror`. The canonical Web boot path
     now schedules a redraw when those browser image events report a resource
     change. Focused renderer, Web adapter, Web backend, Showcase app, and
     Showcase Web build evidence was refreshed on 2026-05-31 and recorded in
     this readiness snapshot.
   - Done when: both host source tests and native provider/platform evidence are
     present: concrete providers must wire real native async loader scheduling
     into the renderer completion/apply port, matching hosts must record redraw
     artifacts for late completions, or the missing pieces must be explicitly
     scoped out of the preview handoff.
     Renderer-local diagnostics, provider callback forwarding, host
     baseline-guarded redraw scheduling, renderer-neutral completion apply
     helpers, and host completion-source routing are current, but they do not
     yet prove that every native renderer has a real out-of-render async loader.
   - Evidence: focused renderer/Web adapter tests, backend/host completion-source
     tests, docs, capability report, and matching-host runtime artifacts.

3. Emoji and text shaping evidence
   - Current status: Web can rely on browser font rasterization. Native WGPU can
     carry RGBA color glyph payloads through the provider protocol, atlas
     upload path, and text vertex shader marker. Cosmic now loads platform
     emoji fallback font candidates when available, while full native emoji
     font fallback across all providers, ZWJ/color emoji conformance, and full bidi/line
     breaking/typography conformance remain
     follow-up work. Diagnostic checks cover representative emoji measurement
     and caret invariants, including single-codepoint, variation-selector, and
     ZWJ samples; Cosmic tests also assert platform emoji fallback
     loading/resolution plus run-layout glyph output and caret coverage through
     the provider-safe mapped layout path. Core fallback tests now also fold
     representative variation-selector, combining-mark, emoji modifier, keycap,
     ZWJ, regional-indicator, tag-sequence, prepend-mark, script-mark, and
     Hangul Jamo cluster interiors to the cluster start while preserving the
     per-character caret array, and basic text caret movement skips those same
     representative interiors. Skia tests now cover the same
     representative emoji caret coverage, verify shaped-run and fallback caret stabilization
     for representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interiors, check that emoji font retry stays
     on the system FontMgr path before default-font fallback, inject the Skia
     text system into a public text field runtime for composition caret geometry
     and selection highlight evidence, and consume `moui_skia` fallback/shaping descriptor resource plans through an internal
     preflight, but they document invariants and known gaps rather than claiming
     full Unicode shaping parity.
   - Done when: deterministic coverage keeps improving without claiming full
     Unicode shaping parity before it exists.
   - Evidence: text conformance commands, renderer tests, and text-system docs.

### Text Providers

1. Windows DirectWrite provider
   - Current status: scaffold composed with Cosmic fallback.
   - Done when: the provider returns validated platform layout/raster data or
     the scaffold documentation continues to describe fallback behavior
     honestly.
   - Evidence: provider tests, platform notes, text-system docs, and renderer
     capability notes.

2. Linux fontconfig/HarfBuzz/FreeType provider
   - Current status: scaffold for a future Linux host path.
   - Done when: real provider data exists behind the documented protocol, or
     the scaffold remains explicitly unavailable.
   - Evidence: scaffold/provider tests and text-system docs.

### Platform

1. Linux backend
   - Current status: minimal Wayland host core plus WGPU provider path with
     tracked service, accessibility, IME, and native font-provider gaps;
     adapter tests cover dependency-provided key/modifier mapping and current
     pointer coordinates.
   - Done when: Showcase `linux` and `linux_cosmic` run under a real Wayland
     compositor with a usable Vulkan stack, and readiness wording continues to
     describe the remaining unsupported platform services honestly.
   - Evidence: backend tests, platform notes, readiness report wording, and the
     two Linux Showcase `moon run` commands.

2. Platform validation handoff
   - Current status: daily checks skip slow native platform examples.
   - Done when: preview handoff records the host, current-platform checks that
     ran, and native example builds intentionally left out due to setup or host
     limits.
   - Evidence: `sh scripts/dev-check.sh --platform-examples-test`, the platform
     validation matrix above, and, when configured,
     `--platform-examples-build`.

### Examples And Docs

1. Showcase capability alignment
   - Current status: Showcase lists the renderer capability report and has
     visible/app-test evidence for a focused subset of draw commands.
   - Done when: each visible renderer capability status has either Showcase
     coverage or a documented reason it is not visible there, and new visible
     framework features default to adding Showcase coverage.
   - Evidence: Showcase capability alignment matrix, Showcase app tests, Web
     wasm-gc build, capability report.

2. Release handoff checklist
   - Current status: this document defines gates; each release candidate still
     needs fresh evidence.
   - Done when: this readiness document maps every requirement to a current
     artifact and command result, without relying on IDE-local task ledgers.
   - Evidence: readiness snapshot plus final verification summary.

### Dev Tools

1. Render inspector diagnostics
   - Current status: `RenderInspectorSnapshot` can be built from an
     `AppRuntime` or an explicit draw-command stream and reports draw command
     counts, max clip/layer/filter depths, open scope depths, unbalanced pop
     count, path count, and shader count. Showcase Diagnostics now surfaces
     render command count plus max/open clip/layer/filter scope counters,
     unbalanced pop count, TEA message/effect/subscription counters, and
     effect/subscription descriptor labels in the visible inspector snapshot
     card. The
     conformance `--golden` and `--bench` scaffolds now write and validate
     ignored capture manifests under `artifacts/conformance/` that name the
     screenshot targets, benchmark metrics, and render-inspector counters to
     save with the manual capture artifacts. Benchmark manifests also name the
     Showcase and Markdown Editor Web wasm-gc targets and their metrics artifact
     paths so both runnable documentation examples stay in the benchmark
     handoff. `scripts/validate-web-runtime-handoff.mjs` checks that both Web
     wasm-gc examples have HTML boot pages, browser runtime assets, wasm
     artifacts, and expected compiled WebAssembly event/completion exports after
     build; with `--manifest`, it writes
     `artifacts/conformance/web-runtime-handoff.json` so release handoffs can
     cite the checked targets, exports, assets, and evidence boundary. The
     companion `scripts/validate-web-runtime-handoff-manifest.mjs` guard checks
     that artifact schema before the scaffold reports success. The focused
     `scripts/test-browser-runtime-events.mjs` guard covers browser pointer,
     mouse, and click fallback routing: pointer-capable browsers ignore
     compatibility mouse/click activation entirely, while non-pointer fallback
     mode still de-duplicates delayed fallback events whose rounded coordinates
     drift from the original pointer event. This keeps delayed app rebuilds from
     replaying a single browser click as multiple MoUI pointer activations. This
     remains static/HTTP handoff evidence rather than browser WebGPU
     presentation proof.
     The shared
     `scripts/validate-conformance-capture-manifest.mjs` guard checks the
     schema, canonical viewports, artifact paths, inspector counter list,
     benchmark target list, and benchmark metric list before either scaffold
     reports success.
   - Done when: captured screenshot and benchmark result artifacts are recorded
     against those manifests, or browser automation/pixel diffing replaces the
     manual capture step.
   - Evidence: `moon test moui/core --target native`, `moon test
     examples/showcase/app --target native`, `sh scripts/conformance-check.sh
     --golden`, `sh scripts/conformance-check.sh --bench`,
     `node scripts/validate-conformance-capture-manifest.mjs`,
     `node scripts/test-validate-conformance-capture-manifest.mjs`,
     `node scripts/validate-web-runtime-handoff.mjs`,
     `node scripts/test-browser-runtime-events.mjs`, generated public API review
     after inspector changes, and testing docs.

## Known Non-Goals

- Do not make compatibility shims for removed APIs unless explicitly requested.
- Do not move platform or renderer implementation details into `core/`.
- Do not describe Linux platform support as complete while service, IME,
  AT-SPI, and native font-provider gaps remain; do not describe DirectWrite or
  fontconfig providers as complete while their packages are scaffolds.
- Do not make broad all-target tests the default inner loop.
- Do not treat a green narrow test as evidence for a broader release claim.

## Handoff Template

Use this shape for preview-readiness handoffs:

```text
Changed files:
- ...

Validation:
- command: result
- command: result

Readiness impact:
- Which checklist items moved forward.
- Which known gaps remain.

Guidance freshness:
- AGENTS.md: checked / updated
- skills/: checked / updated

Risks:
- ...
```
