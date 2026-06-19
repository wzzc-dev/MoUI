<!--
Thanks for the PR! Read CONTRIBUTING.md first if you haven't.
Keep the PR focused: one logical change per PR. Broad churn is harder to review.
-->

## Summary

<!-- One or two sentences: what does this PR change and why? -->

## Motivation

<!-- The problem this solves. Link any related issue with "Fixes #123" / "Refs #123". -->

Fixes #

## Change type

<!-- Check the type that applies. This should match the commit message prefix. -->

- [ ] `feat` — new feature or capability
- [ ] `fix` — bug fix
- [ ] `refactor` — internal change, no behavior shift
- [ ] `docs` — documentation only
- [ ] `build` / `test` — build system, CI, or tests
- [ ] `diagnostic` — diagnostic-only route (WGPU, design-systems)

## Affected package boundary

<!-- See docs/moui-app-package-boundary.md. Confirm the change lands in the right owning package. -->

- [ ] `moui/core` — platform-neutral contracts / kernel
- [ ] `moui/views` — controls & app-facing constructors
- [ ] `moui/runtime` — lifecycle, trees, dispatch
- [ ] `moui/backend/host` — host service contracts
- [ ] `moui/render/*` — renderers
- [ ] `moui_theme/*` — design-system addons
- [ ] `examples/*/app` — shared app logic
- [ ] Platform entrypoint (`web_wasm` / `*_skia`) — thin wiring only
- [ ] Docs / scripts / tooling only

## Verification

- [ ] `sh scripts/dev-check.sh` passes locally.
- [ ] If `moui_theme` or `examples/design_systems` changed, `sh scripts/dev-check.sh --theme-diagnostics` passes.
- [ ] If public API changed: `pkg.generated.mbti` regenerated and `node scripts/validate-api-surface.mjs` passes.
- [ ] If the maintenance baseline numbers moved: the ratchet budget is updated or the change stays within `max`.
- [ ] If workflow / package layout / examples / text-rendering boundaries changed: `docs/`, `AGENTS.md`, and the relevant `skills/` file are updated.
- [ ] No files under `artifacts/` are committed.
- [ ] Real platform / browser / renderer claims are backed by a cited smoke log (see docs/testing.md).

## Architectural invariants

- [ ] No new `core` enum variant, primitive constructor, or runtime lowering arm added to support a control. New controls are expressed in `moui/views` via `@core.View::node`.
- [ ] The runtime pipeline (`View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer`) is preserved.
- [ ] Ordinary app packages (`examples/*/app`) do not gain dependencies on `moui/runtime`, `moui/render/*`, or platform backends.
- [ ] Renderer status (mainline / diagnostic) stays synchronized across code, tests, docs, and Showcase.

## DCO

By submitting this PR, I certify that my contributions are my own original work
(or that I have the right to submit them under Apache-2.0) and that I have added
a `Signed-off-by` line to each commit (`git commit -s`).

See [CONTRIBUTING.md](https://github.com/wzzc-dev/MoUI/blob/main/CONTRIBUTING.md#developer-certificate-of-origin) for details.
