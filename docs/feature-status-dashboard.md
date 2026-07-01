# Feature Status Dashboard

This page tracks MoUI feature proof coverage. For implementation status
(supported/partial/gap), see
[renderer-capability-report.md](renderer-capability-report.md). For the
feature-to-CI-job mapping, see
[feature-proof-matrix.md](feature-proof-matrix.md).

The `feature-proof-summary.yml` CI workflow generates a proof report after
every `ci.yml` run. The latest report is available as the
`feature-proof-summary` artifact on the most recent `MoUI Feature Proof Summary`
workflow run.

## Proof Levels

| Level | CI workflow | Trigger | What it proves |
|-------|------------|---------|---------------|
| L1 | `ci.yml` | Every PR | API/algorithm/protocol correctness (no real renderer) |
| L2 | `moui-skia-real-skia-pr-smoke.yml` | Every PR and push-to-main | Real Skia runtime behavior on matching host |
| L3 | `feature-proof-summary.yml` | After `ci.yml` completes | All required L1 and L2 passed |

## Renderer Feature Proof Status

All 17 renderer features from `RendererFeature` enum share the same CI job
mapping. L1 proof is always provided by `conformance` (package tests). L2 proof
is provided by the three platform jobs on every PR.

| Feature | L1 (ci.yml) | L2 macOS | L2 Linux | L2 Windows | L3 |
|---------|-------------|----------|----------|------------|-----|
| Rect | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| RoundedRect | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Gradient | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Shadow | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Text | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Image | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Clip | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Transform | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Opacity | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| LayerCompositing | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| BlendMode | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| FilterEffect | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| PathVector | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| ShaderEffect | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| TextShaping | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| EmojiText | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| AsyncImage | `conformance` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |

## Global Follow-Up Tracking

Three features are declared `partial` in `renderer-capability-report.md`. Their
proof status:

### TextShaping

- **Implementation status**: partial (bidi/paragraph layout determinism)
- **L1 proof**: `conformance` job passes (grapheme break, caret stabilization,
  UAX#29 fixture)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (SkShaper/SkParagraph smoke markers, bidi Arabic and
  mixed-direction visual-order markers via `--run-text-emoji-smoke`)
- **Proof gap**: None. Runtime evidence is obtained automatically on every PR.
- **Functional gap**: Bidi/paragraph layout determinism remains follow-up work;
  this is an implementation gap, not a proof gap.

### EmojiText

- **Implementation status**: partial (cross-platform color emoji consistency)
- **L1 proof**: `conformance` job passes (emoji cluster detection, caret
  stabilization)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (emoji glyph/raster observation markers, keycap/
  regional-indicator/skin-tone-modifier fallback diagnostic markers via
  `--run-text-emoji-smoke`)
- **Proof gap**: None. Runtime evidence is obtained automatically.
- **Functional gap**: Deterministic color emoji and cross-platform font fallback
  conformance remain follow-up work; this is an implementation gap, not a proof
  gap.

### AsyncImage

- **Implementation status**: partial (off-main-thread file I/O proven by
  `background_io` flag in provider tests)
- **L1 proof**: `conformance` job passes (HostAsyncImageLoader dedup, late
  callback gating, completion routing, drain_fn spawn/drain cycle,
  `background_io` flag asserted in provider tests)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (second-frame repaint marker after local/data URI
  completions, deferred-completion marker after `HostNativeAsyncImageSource`
  completion via `--run-renderer-smoke`)
- **Proof gap**: None. The `moui-skia-real-skia-pr-smoke.yml` workflow
  automatically obtains second-frame and deferred-completion markers on all
  three platforms on every PR.
- **Functional gap**: Off-main-thread file I/O is implemented via platform C
  stubs (GCD on macOS, pthread on Linux, CreateThread on Windows). Each
  `ImageResourceLoadCompletion` now carries a `background_io` bool verified by
  provider tests on all three platforms. Data URI sources decode synchronously
  on the main thread; Skia decode remains on the main thread. Off-main-thread
  decode and real-device runtime smoke remain follow-up work.

## Evidence Traceability

| CI workflow | Artifact name | Content |
|------------|--------------|---------|
| `moui-skia-real-skia-pr-smoke.yml` → `macos-real-skia` | `macos-real-skia-pr-smoke` | `moui_skia/logs/macos-*.log` |
| `moui-skia-real-skia-pr-smoke.yml` → `linux-real-skia` | `linux-real-skia-pr-smoke` | `moui_skia/logs/linux-*.log` |
| `moui-skia-real-skia-pr-smoke.yml` → `windows-real-skia` | `windows-real-skia-pr-smoke` | `moui_skia/logs/windows-*.log` |
| `feature-proof-summary.yml` → `summarize` | `feature-proof-summary` | `artifacts/feature-proof/proof-report.json` + `.md` |

## Update Rule

This dashboard is a static reference. The actual proof status is generated
dynamically by `feature-proof-summary.yml` after each `ci.yml` run. To check
the latest proof status:

1. Go to the **Actions** tab in the GitHub repository.
2. Find the **MoUI Feature Proof Summary** workflow.
3. Open the latest run and check the `GITHUB_STEP_SUMMARY` or download the
   `feature-proof-summary` artifact.

When a new renderer feature is added to `RendererFeature` enum in
`render/capabilities.mbt`, update:
1. `docs/renderer-capability-report.md` (implementation status)
2. `docs/feature-proof-matrix.md` (proof mapping)
3. This dashboard (feature row)
4. `scripts/generate-feature-proof-report.mjs` (feature list if a new L2 job
   name was introduced)
