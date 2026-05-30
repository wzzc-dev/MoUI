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

On Linux, the platform example build step covers both Showcase native
entrypoints:

```sh
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
moon build examples/showcase/linux_skia --target native
```

Runtime validation requires a Wayland compositor and Vulkan stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
moon run examples/showcase/linux_skia --target native
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
sh -n scripts/preview-loop.sh
sh -n scripts/package-macos-app.sh
node --check scripts/validate-guidance-consistency.mjs
node scripts/validate-guidance-consistency.mjs
node --check scripts/validate-package-manifest.mjs
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
  registry behavior, devtool snapshots, render inspector scope diagnostics,
  frame-profile counters, guidance freshness, and example builds. Showcase app
  tests also assert that the Diagnostics route surfaces render command and
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
macOS service tests on Darwin, and runs Linux service tests only when the local
window checkout has generated Wayland protocol sources available. `--golden`
builds the Showcase Web wasm-gc target as the canonical screenshot source.
`--bench` builds the heavier example targets and records the expected
measurement set: startup, frame time, dirty-count, draw-command count, and
memory. `--platform` layers in current-platform backend checks through
`scripts/dev-check.sh --platform-examples-test`.

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
- `run_real_skia_smoke` runs the opt-in macOS real Skia renderer smoke.

CI still does not run browser screenshot automation or pixel diffing; the
golden job remains a build-and-capture handoff until a browser runner is added.

## Golden Screenshots And Benchmarks

Showcase is the golden source of truth for visible component coverage. Golden
tests should capture the catalog at stable desktop, tablet, and mobile
viewports, then compare screenshots against approved artifacts. Until a browser
screenshot runner is checked in, `sh scripts/conformance-check.sh --golden`
verifies that the Showcase Web wasm-gc target builds and prints the manual
capture handoff point.

The scaffold's canonical handoff is:

```sh
sh scripts/conformance-check.sh --golden
python3 -m http.server 18080
```

Then open `http://127.0.0.1:18080/examples/showcase/web_wasm/`, capture
`1440x900`, `1024x768`, and `390x844`, and save artifacts under
`artifacts/golden/showcase-web-wasm/<viewport>.png`. This is deliberately a
non-rendering scaffold: it does not introduce browser automation, pixel diffing,
or renderer golden assertions.

Benchmarks should use the same examples and record comparable counters:
frame-time, dirty-count, draw-command count, render inspector scope diagnostics,
startup, and memory. Until native profiling hooks are wired into CI,
`sh scripts/conformance-check.sh --bench` keeps the benchmark build targets
healthy and documents the metrics to collect.

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
