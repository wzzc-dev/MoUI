# Testing

MoUI uses layered validation instead of broad all-repository checks for every
change. Prefer the smallest command that covers the package, platform, or public
API surface you touched.

## Daily Check

Run the bounded development check for routine work:

```sh
sh scripts/dev-check.sh
```

This keeps feedback fast by running stable package-level tests, native renderer
contract tests, and Web wasm-gc example builds without invoking every native or
wasm-gc target.

## Focused Package Tests

Use package-level commands while editing implementation code:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/tests/tooling --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
```

Run `moon fmt` before handoff so MoonBit source stays normalized.

Use `moon check --warn-list +unnecessary_annotation` as a cleanup audit before
or during public API reviews. Treat new unnecessary annotations as cleanup work,
but do not require this stricter audit to be warning-free for every inner-loop
change until existing warnings are resolved.

When validating cookbook-style app patterns, start with the package that owns
the contract and then run the shared example that demonstrates it. The common
mapping is:

| Pattern | Focused checks |
| --- | --- |
| Forms | `moon test moui/core --target native`, `moon test moui/views --target native`, `moon test examples/settings/app --target native` |
| Data table | `moon test moui/views --target native`, `moon test examples/data_table/app --target native` |
| Navigation shell | `moon test moui/views --target native`, `moon test examples/showcase/app --target native` |
| Menus and commands | `moon test moui/core --target native`, `moon test moui/views --target native`, `moon test examples/command_palette/app --target native` |
| Host services and file import | `moon test moui/backend/host --target native`, `moon test moui/backend/web --target wasm-gc`, `moon test examples/file_importer/app --target native` |
| Virtual lists | `moon test moui/views --target native`, `sh scripts/conformance-check.sh --layout` |

## Platform Validation

When platform behavior matters, include backend tests without forcing native
example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Before release-style validation on a configured host, build current-platform
examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Native builds link platform stubs and `wgpu-native`, so they are intentionally
not part of every inner-loop check.

Renderer provider packages are platform-specific. Use the current-host helper
above for normal backend/provider validation instead of trying to run every
`moui/backend/<platform>/{wgpu,skia}` test package on every machine.
The macOS, Windows, and Linux Skia provider packages expose
`macos_skia_provider_preflight_summary()`,
`windows_skia_provider_preflight_summary()`, and
`linux_skia_provider_preflight_summary()` for package-level audits of renderer
availability, `skia_mbt/native` availability, selected font resolution, the
presenter path, the renderer-neutral `HostWindowRenderer` bridge used to
forward the Skia text system, image-resource diagnostics, present count, and
disposal hooks, host service/input readiness, clipboard/menu/file-dialog/open
URL/system-theme/async-service readiness, window/multi-window readiness,
text-input/IME/drag-drop readiness, native context-menu readiness, host-modal
file-dialog readiness, native accessibility status, and whether the
matching-host first-frame smoke option is enabled. Their tests prove
provider/preflight wiring only. macOS runtime
presentation still requires the real-Skia renderer smoke or first-frame
Showcase/Markdown Editor runs; Windows Skia tests require a Windows/MSVC host
because the Win32 stubs include `windows.h`; Linux Skia tests can compile where
the local Linux window package and toolchain are available, but real
presentation still requires a matching Wayland runtime. Windows and Linux Skia
entrypoints expose the same auto-exit path through
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`, and
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`; passed logs from
those runs are matching-host runtime evidence, not provider evidence.
`node scripts/validate-skia-entrypoints.mjs` statically audits the native Skia
example entrypoint shape for Showcase, Markdown Editor, and Mo Workbench: each
entrypoint must import `render/skia`, the matching `backend/<platform>/skia`
provider, its shared app package, the smoke-only first-frame environment flag,
and the `EmptyTypeface`/`SystemFontMgr` selection. That guard is package/wiring
evidence only; runtime presentation still needs the smoke or matching-host
commands above.
After a matching host has produced provider, fallback-unavailable, renderer
smoke, Showcase first-frame, and Markdown Editor first-frame logs under
`artifacts/platform-evidence/<platform>/`, use
`node scripts/record-native-skia-evidence.mjs` to validate those log markers and
update only that platform's `skiaEvidence` block. The helper intentionally
leaves the broader platform runtime `status` unchanged; use the full platform
recorder below only after service/input/window observations have also been
collected.
The Skia renderer package also exposes `skia_text_system()` for diagnostic text
contract checks; `moon test moui/tests/text_conformance/native --target native`
includes that path as measurement evidence, not as platform-window runtime
evidence.

On Linux, the platform example build step covers Showcase native entrypoints
plus the Markdown Editor Skia entrypoint:

```sh
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/linux_skia --target native
```

Runtime validation requires a Wayland compositor and Vulkan stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

## Public API Review

After changing exported types, constructors, functions, package imports, or
public behavior, run:

```sh
moon info
```

Review generated `pkg.generated.mbti` diffs. If no public API changed, generated
interfaces should stay unchanged.

Treat generated interfaces as the public API contract baseline. Behavioral
contracts should be covered by focused `*_contract_test.mbt` files or the
conformance matrix; avoid adding long-lived `*_spec.mbt` files for ordinary
implementation structure. Use `*_tree.mbt`, `*_descriptor.mbt`, `*_input.mbt`,
`*_protocol.mbt`, and `*_capabilities.mbt` for package-local source
organization when those names match the responsibility.

## Documentation And Guidance Checks

For docs-only changes, keep validation lightweight and focused on the edited
surface:

```sh
sh scripts/dev-check.sh --help
sh scripts/conformance-check.sh --help
sh -n scripts/dev-check.sh
sh -n scripts/conformance-check.sh
sh -n scripts/setup-local-deps.sh
sh -n scripts/check-local-deps.sh
bash .local_repos/skia_mbt/scripts/verify-platform-status.sh
bash .local_repos/skia_mbt/scripts/verify-native-capability-contract.sh
sh -n scripts/preview-loop.sh
sh -n scripts/package-macos-app.sh
node --check scripts/validate-guidance-consistency.mjs
node scripts/validate-guidance-consistency.mjs
node --check scripts/validate-package-manifest.mjs
node --check scripts/validate-conformance-capture-manifest.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/validate-platform-evidence-manifest.mjs
node scripts/test-validate-platform-evidence-manifest.mjs
node --check scripts/record-platform-evidence-manifest.mjs
node scripts/test-record-platform-evidence-manifest.mjs
node --check scripts/record-native-skia-evidence.mjs
node scripts/test-record-native-skia-evidence.mjs
node --check scripts/validate-web-runtime-handoff.mjs
node scripts/test-validate-web-runtime-handoff.mjs
node --check scripts/validate-web-runtime-handoff-manifest.mjs
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node --check scripts/record-web-runtime-presentation.mjs
node scripts/test-record-web-runtime-presentation.mjs
node --check scripts/validate-web-runtime-presentation-manifest.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
node --check scripts/validate-renderer-provider-manifests.mjs
```

When packaging helpers change, also run at least one `--no-build` smoke against
an already-built executable. The helpers validate their generated manifests
before reporting success; you can also run the validator directly when checking
an existing package output:

```sh
node scripts/validate-package-manifest.mjs \
  "dist/macos/MoUI Showcase.app/Contents/Resources/moui-package.json" \
  --platform macos
```

Use `rg` to audit stale terms, missing links, old example paths, and outdated
validation commands. If the change updates docs placement, package layout,
platform behavior, examples, renderer capabilities, or the text system, also
check `AGENTS.md` and `skills/`.

Do not run `moon info` for a docs-only change unless MoonBit public APIs or
package imports changed.

## Renderer Capability Rule

When draw command support changes, keep the capability loop synchronized:

1. Update `render/capabilities.mbt`.
2. Update `render/capabilities_test.mbt`.
3. Update `docs/renderer-capability-report.md`.
4. If the behavior is visible, update Showcase coverage.

Suggested validation:

```sh
moon test moui/render --target native
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
```

This renderer slice includes the native Skia raster package at
`moui/render/skia`; real presenter pixels still require the opt-in Skia smoke.
On macOS, use `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
--run-markdown-smoke` when you need renderer pixels plus first-frame Showcase
and Markdown Editor runtime evidence with temporary real-Skia link flags. Add
`--link-mode dynamic|static` or set `SKIA_MBT_MACOS_LINK_MODE` when the
default auto mode is not what you want; auto prefers static `libskia.a` for
temporary smoke/build rewrites and dynamic `libskia.dylib` for
`--write-local-config` direct-run setup when those files exist. Add
explicit log paths and `--record-platform-evidence` when you want the helper to
update the macOS `skiaEvidence` block in the platform evidence manifest after a
successful run:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --run-showcase-smoke \
  --run-markdown-smoke \
  --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log \
  --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log \
  --markdown-log artifacts/platform-evidence/macos/markdown-macos-skia-first-frame.log \
  --record-platform-evidence artifacts/conformance/platform-runtime-evidence.json
```

That manifest update records Skia route evidence only; keep the broader macOS
platform entry pending until full platform-service observations are collected.

## Conformance Ownership Layers

High-risk framework behavior should be validated through four ownership layers
instead of one large end-to-end assertion:

1. Contract layer: `core/` defines platform-neutral semantics and invariants.
   Text, input/focus, layout, selection, undo/redo, draw intent, and runtime
   state transitions belong here.
2. Host layer: `backend/host` and active platform backends prove that native or
   browser events, services, window lifecycle requests, paste/composition, and
   focused commands drive the runtime through shared contracts.
3. Implementation layer: renderer and provider packages prove concrete
   implementations honor the contract. This includes WGPU renderer capability
   evidence, native text-provider metrics/raster validation, and Web adapter
   host payload checks.
4. Matrix layer: `moui/tests/*_conformance` and `scripts/conformance-check.sh`
   compare supported engines or platforms. Strict failures are reserved for
   contract invariants; engine-specific metric differences should be reported
   with documented tolerances or diagnostic wording.

Examples are evidence consumers, not the only proof. Showcase and Markdown
Editor should demonstrate visible workflows and carry app-level assertions, but
shared contract claims still need package or conformance tests at the owning
layer.

## Conformance-Oriented Coverage

The SwiftUI/Flutter/Compose parity work should grow focused conformance tests
before it grows broad platform claims:

- Runtime: dirty component rebuilds, keyed effect reuse/cancellation, unmount
  cleanup, and saveable state restore.
- Layout/render: custom child layout delegates, baseline/alignment follow-ups,
  lazy viewport behavior, clip/transform/opacity/image/text command stability,
  and renderer capability report synchronization.
- Input/accessibility: gesture arbitration, action-command matching and
  dispatch, explicit focus traversal helpers, shortcut dispatch, IME/text
  selection, clipboard service routing, file drop dispatch, and semantics action
  roundtrips.
- Platform/tooling: host-service capability checks, Linux readiness, Web
  wasm-gc backend tests, async host-service completion, window lifecycle
  registry behavior, app-owned route history/deep-link state, devtool
  snapshots, render inspector scope diagnostics, frame-profile counters,
  guidance freshness, and example builds. Showcase app tests also assert that
  the Navigation Shell surfaces route history state and app-sampled route
  transition state, and that the Diagnostics route surfaces render command and
  render-scope inspector counters from the shared inspector snapshot.
- Text system: stable fallback/provider/editor invariants for CJK, emoji,
  mixed bidi, caret positions, selection, and IME anchors, plus opt-in
  diagnostic packages under `moui/tests/text_conformance/`.

Use the conformance entrypoint for this suite:

```sh
sh scripts/conformance-check.sh
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
sh scripts/conformance-check.sh --golden
sh scripts/conformance-check.sh --bench
sh scripts/conformance-check.sh --platform
```

The base command runs runtime, host, renderer, Web backend, and Showcase app
contracts. `--input` runs core input/focus semantics and shared host input
routing. `--layout` runs core layout, baseline, and TextSystem-dependent
geometry contracts. `--render` runs renderer facade, native WGPU, and Web
adapter capability evidence. `--text` runs the stable text conformance surface
across core, native renderer, the standalone Cosmic provider, Web adapter, and
Web backend packages. `--text-diagnostic` runs the opt-in cross-engine text
matrix packages.
`--platform-services` runs host and Web service contracts, runs current-host
macOS service tests on Darwin, runs Linux service tests only when the local
window checkout has generated Wayland protocol sources available, and writes a
validated platform runtime evidence manifest at
`artifacts/conformance/platform-runtime-evidence.json`. That manifest is a
matching-host evidence contract for Showcase and Markdown Editor targets,
including the native Skia entrypoints: pending entries are not runtime proof,
and a passed Windows or Linux entry must name the matching host, commands, MoUI
consumer run, observations, and artifacts. Native entries also include a
`skiaEvidence` block for the Skia-first route: provider/preflight commands,
fallback-unavailable checks, real renderer smoke, Showcase first-frame, and
Markdown Editor first-frame. `skiaEvidence.status=passed` is native Skia route
evidence, not full platform-service proof by itself; however a native platform
entry cannot be marked `passed` unless its Skia evidence is also `passed`.
`--golden` builds the Showcase Web
wasm-gc target as the canonical screenshot source. `--bench` builds the heavier
example targets, validates the Web runtime handoff for Showcase and Markdown
Editor, and records the expected measurement set: startup, frame time,
dirty-count, draw-command count, and memory. `--platform` layers in
current-platform backend checks through `scripts/dev-check.sh
--platform-examples-test`.

`sh scripts/check-local-deps.sh`, which is part of `dev-check`, also verifies
that `.local_repos/window` contains the generated Wayland protocol C sources
needed by Linux backend package tests and its MoUI-oriented smoke/evidence
surface: `docs/moui-integration-smoke.md`, `docs/platform-gaps.md`,
`scripts/check_moui_readiness.sh`, `scripts/check_moui_evidence.sh`,
`scripts/record_moui_evidence.sh`, and the macOS/Web/Linux/Windows
`check_moui_*_smoke.sh` helpers. It also checks the current smoke contract:
the macOS helper still executes the AppKit smoke through `moon run`, the Web
helpers build wasm-gc artifacts under the module-qualified
`wzzc-dev/window/examples/...` paths, and the MoUI Web smoke page still emits
the public consumer sentinel lines. This is a dependency-readiness guard only;
run the window smoke helpers on matching hosts before claiming runtime platform
evidence.
The same local-dependency check requires `.local_repos/skia_mbt` to expose its
binding-level platform acceptance surface: `skia-platform-status.json`,
`skia-provider-lock.json`, `SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`,
`native/ownership.json`, and the native verifier scripts. It runs
`.local_repos/skia_mbt/scripts/verify-platform-status.sh` and
`.local_repos/skia_mbt/scripts/verify-native-capability-contract.sh`, which
check the provider lock, CI gate wiring, native smoke capability markers,
artifact evidence references, fallback parity, FFI ownership/borrow metadata,
and native capability manifest coverage. That is Skia binding dependency
evidence; it does not replace MoUI's opt-in real-Skia renderer smoke or
matching-host Showcase/Markdown Editor runtime evidence.

The platform runtime evidence manifest uses schema version 2. Its observation
set mirrors the local window fork's recorder fields, including native
monitor/cursor evidence as `monitorCursor`. For native passed entries,
`monitorCursor` must be `yes`; the Web browser-session path may keep it
`pending` because CDP evidence does not prove native monitor/current-monitor or
cursor probes. Native platform entries also carry `skiaEvidence`; use
`--skia-status`, repeated `--skia-set`, `--skia-artifact`, and `--skia-note`
when recording first-frame Skia smoke results. Keep the overall platform
`status` pending when only the Skia first-frame route passed and broader
platform-service observations are still pending.

For Windows/Linux matching-host Skia route evidence, the convenience wrapper
checks the expected log markers before delegating to the manifest recorder:

```sh
node scripts/record-native-skia-evidence.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  windows \
  --host "Windows MSVC CI" \
  --provider-preflight-log artifacts/platform-evidence/windows/skia-provider.log \
  --fallback-unavailable-log artifacts/platform-evidence/windows/skia-fallback-unavailable.log \
  --renderer-smoke-log artifacts/platform-evidence/windows/skia-renderer-smoke.log \
  --showcase-log artifacts/platform-evidence/windows/showcase-skia-first-frame.log \
  --markdown-log artifacts/platform-evidence/windows/markdown-skia-first-frame.log
```

Use `linux` plus the Linux artifact directory on a Wayland host. Supplying only
some logs records a partial `skiaEvidence` block and leaves omitted Skia
observations pending.

When collecting release evidence on a configured host, update or regenerate the
platform runtime evidence manifest with that host's results and validate it:

```sh
node scripts/record-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  windows \
  --status passed \
  --host "Windows MSVC CI" \
  --window-evidence-command \
    ".local_repos/window/scripts/record_moui_evidence.sh windows --status passed --host 'Windows MSVC CI'" \
  --consumer-command \
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows --target native }\"" \
  --set windowOpened=yes \
  --set resizeRedraw=yes \
  --set representativeInput=yes \
  --set cleanExit=yes \
  --set surface=yes \
  --set redraw=yes \
  --set resizeScale=yes \
  --set consumerInput=yes \
  --set textInput=yes \
  --set rendererHandle=yes \
  --set monitorCursor=yes \
  --set cleanShutdown=yes \
  --artifact artifacts/platform-evidence/windows/window-smoke.md \
  --artifact artifacts/platform-evidence/windows/showcase-run.log \
  --note "matching-host Windows evidence observed" \
  --skia-status passed \
  --skia-set providerPreflight=yes \
  --skia-set fallbackUnavailable=yes \
  --skia-set realRendererSmoke=yes \
  --skia-set showcaseFirstFrame=yes \
  --skia-set markdownFirstFrame=yes \
  --skia-artifact artifacts/platform-evidence/windows/skia-provider.log \
  --skia-artifact artifacts/platform-evidence/windows/showcase-skia-first-frame.log \
  --skia-artifact artifacts/platform-evidence/windows/markdown-skia-first-frame.log \
  --skia-note "matching-host Windows Skia first-frame evidence observed"
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  --platform windows
```

The manifest complements the Markdown snippets generated by the local window
fork's `.local_repos/window/scripts/record_moui_evidence.sh`. Keep both scoped:
window-fork smoke proves dependency behavior, while MoUI platform evidence must
also name the Showcase or Markdown Editor consumer run that exercised the
framework entrypoint.
Use `--status failed` with at least one `--set <observation>=no` to record a
matching-host failure without weakening the release claim; the validator keeps
failed and pending entries distinct from passed runtime evidence.

CI runs several bounded jobs from `.github/workflows/ci.yml`:

- `Core conformance` runs the daily check, text conformance plus the diagnostic
  text matrix, and the Showcase golden build scaffold.
- `Public API surface` runs `moon info` and fails if generated
  `pkg.generated.mbti` files drift.
- `Linux platform contracts` installs Wayland development packages and runs the
  current-platform backend checks on Ubuntu.
- `macOS packaging smoke` packages Showcase as a local `.app`, validates the
  package manifest, and uploads the bundle artifact.
- `Benchmark scaffold` runs `sh scripts/conformance-check.sh --bench` to keep
  benchmark build targets healthy.
- `Windows MSVC native smoke` installs vcpkg `zlib:x64-windows`, imports the
  Visual Studio C++ toolchain, runs Windows backend and WGPU provider tests,
  builds Showcase with `MBT_WGPU_LINK_MODE=dynamic`, packages it under
  `dist/windows-msvc`, validates the package manifest, and uploads the portable
  folder artifact.

Manual `workflow_dispatch` inputs add heavier coverage when needed:

- `run_slow_native_examples` builds current-platform native examples in the
  macOS packaging and Linux platform jobs.
- `run_real_skia_smoke` runs the opt-in macOS real Skia renderer smoke; use
  the local helper's `--run-showcase-smoke --run-markdown-smoke` flags when a
  handoff also needs current-host first-frame Showcase and Markdown Editor
  runtime evidence.

CI still does not run browser screenshot automation or pixel diffing; the
golden job remains a build-and-capture handoff until a browser runner is added.
The handoff now writes and validates an ignored capture manifest under
`artifacts/conformance/` so screenshot and benchmark captures have an explicit,
script-checked place to record the render inspector counters that travel with
the artifacts.

## Golden Screenshots And Benchmarks

Showcase is the golden source of truth for visible component coverage. Golden
tests should capture the catalog at stable desktop, tablet, and mobile
viewports, then compare screenshots against approved artifacts. Until a browser
screenshot runner is checked in, `sh scripts/conformance-check.sh --golden`
verifies that the Showcase Web wasm-gc target builds, writes and validates
`artifacts/conformance/showcase-golden-capture.json`, and prints the manual
capture handoff point. The manifest schema is guarded by
`node scripts/validate-conformance-capture-manifest.mjs`, which checks the
canonical viewports, screenshot artifact paths, render inspector counters, and
benchmark target/metric names before the scaffold reports success.

The scaffold's canonical handoff is:

```sh
sh scripts/conformance-check.sh --golden
python3 -m http.server 18080
```

Then open `http://127.0.0.1:18080/examples/showcase/web_wasm/`, capture
`1440x900`, `1024x768`, and `390x844`, and save artifacts under
`artifacts/golden/showcase-web-wasm/<viewport>.png`. Store the render inspector
counters named in `artifacts/conformance/showcase-golden-capture.json` with the
same capture set. This is deliberately a non-rendering scaffold: it does not
introduce browser automation, pixel diffing, or renderer golden assertions.

Benchmarks should use the same examples and record comparable counters:
frame-time, dirty-count, draw-command count, render inspector scope diagnostics,
startup, and memory. Until native profiling hooks are wired into CI,
`sh scripts/conformance-check.sh --bench` keeps the benchmark build targets
healthy and writes plus validates
`artifacts/conformance/showcase-benchmark-capture.json` with the Showcase and
Markdown Editor Web wasm-gc benchmark targets, metrics artifact paths, and
render-inspector metrics to collect. The canonical metrics paths are
`artifacts/benchmarks/showcase-web-wasm.json` and
`artifacts/benchmarks/markdown-editor-web-wasm.json`.

The Web runtime handoff validator checks that both Web wasm-gc examples have
HTML boot pages, browser runtime assets, wasm artifacts, and expected compiled
WebAssembly event/completion exports after build:

```sh
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/validate-web-runtime-handoff.mjs \
  --manifest artifacts/conformance/web-runtime-handoff.json
node scripts/validate-web-runtime-handoff-manifest.mjs \
  artifacts/conformance/web-runtime-handoff.json
python3 -m http.server 18080
node scripts/validate-web-runtime-handoff.mjs --base-url http://127.0.0.1:18080
```

This is still a static delivery and HTTP availability check. It does not claim
that Browser WebGPU device creation, wasm instantiation, canvas presentation, or
pixel output succeeded; collect those with browser automation or manual browser
evidence before changing Web runtime entries from pending to passed.
The optional manifest records the checked runtime assets, target HTML/wasm
paths, compiled WebAssembly exports, file/HTTP checks, and the same evidence
boundary so release handoffs can cite a structured artifact rather than console
output alone.

When a local browser with Chrome DevTools Protocol access is available, collect
browser-session Web runtime presentation evidence separately from the static
handoff check:

```sh
python3 -m http.server 18080 --bind 127.0.0.1
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless=new \
  --remote-debugging-port=9223 \
  --user-data-dir=/tmp/moui-web-runtime-presentation \
  about:blank
node scripts/record-web-runtime-presentation.mjs \
  --base-url http://127.0.0.1:18080 \
  --cdp-url http://127.0.0.1:9223 \
  --manifest artifacts/conformance/web-runtime-presentation.json \
  --require-passed
node scripts/validate-web-runtime-presentation-manifest.mjs \
  artifacts/conformance/web-runtime-presentation.json \
  --require-passed
node scripts/record-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  web \
  --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  --platform web
```

The presentation recorder opens Showcase and Markdown Editor through the named
browser session, injects a read-only browser-runtime event observer, waits for
the page status, records WebGPU/wasm/canvas signals, performs a viewport resize,
representative pointer and keyboard input, Markdown Editor text input, closes
the CDP targets, writes screenshots under
`artifacts/conformance/web-runtime-presentation/`, and validates
`artifacts/conformance/web-runtime-presentation.json`. A passed manifest is
stronger than the handoff artifact because it proves browser-local WebGPU
startup, wasm app startup, canvas sizing, resize/input event-bridge delivery,
clean target close, clean console, and nonblank screenshot thresholds for that
Chrome session. It is still not cross-browser coverage, deterministic
pixel-golden proof, or native platform runtime evidence. If the local browser
cannot create a WebGPU adapter or device, keep the manifest failed or omit it
from release claims; do not use the static handoff artifact as a substitute for
passed browser presentation evidence. The platform recorder can also consume a
failed presentation manifest; it then marks the Web platform entry failed and
records the negative observations so release notes can cite a structured reason.
If the CDP browser is unavailable during recorder startup, the recorder still
writes a failed `web-runtime-presentation.json` with negative observations for
both targets before exiting nonzero; validate that artifact without
`--require-passed` when documenting the environment limit.
When the presentation manifest passes with all browser-observable platform
observations set to `yes`, `record-platform-evidence-manifest.mjs ... web
--web-presentation-manifest ...` records the Web platform entry as passed for
that browser session. The Web entry may keep `monitorCursor` pending because
browser CDP evidence does not prove native monitor/current-monitor or cursor
probes.

## Release-Oriented Checklist

Before a broad handoff or release candidate:

```sh
sh scripts/dev-check.sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
moon info
```

Also confirm README and docs mention current commands, platform constraints,
example paths, and renderer capability status. If the release includes warning
cleanup, include `moon check --warn-list +unnecessary_annotation` and review the
remaining diagnostics explicitly.
