# Plan: Backend ownership and renderer lifecycle convergence

- **Status**: active
- **RFC**: [0005](../../rfcs/0005-backend-renderer-lifecycle-convergence.md)
- **ADR**: [0027](../../decisions/0027-backend-renderer-lifecycle-convergence.md)
- **Goal**: Split backend-common state by ownership, collapse renderer binding
  to provider/session, and replace root platform surface enums with opaque
  capabilities.
- **Non-goals**: publishing 0.2, compatibility wrappers, platform readiness
  promotion, renderer reclassification, or platform-backend extraction from
  the base module.

## Delivery sequence

1. Add governance records and ownership/renderer invariants.
2. Introduce `HostSurfaceCapability`, `RendererProvider`, and
   `RendererSession`; migrate renderer-common selection and all four renderer
   modules, then remove the old contracts.
3. Migrate runtime, platform backends, composition roots, CLI templates, and
   internal tests to ordered providers and renderer sessions.
4. Split backend-common state into lifecycle, frame, image, input, services,
   and embedded-session packages; remove the three coordinator types.
5. Add ownership metadata and MoonBit-backed validation, regenerate public
   interfaces, and synchronize docs and skills.
6. Run focused, cross-target, profile, package-consumer, and path-triggered
   renderer/host validation without publishing.
7. Before the first 0.2 publication, atomically rename the concrete renderer
   modules to `moui_{skia,sun,web,wgpu}_renderer`, migrate every workspace and
   external-consumer reference, and retain no old-name compatibility module.

## Acceptance

- [x] `RendererProvider` and `RendererSession` are the only root renderer
  binding/lifecycle types.
- [x] Root render has no platform surface descriptor or graphics-API route
  enum; rejected providers allocate no persistent resources.
- [x] Renderer session disposal is idempotent and owns selected renderer/native
  surface cleanup exactly once.
- [x] Backend-common lifecycle, frame, image, input, services, and embedded
  session state have separate package owners and an acyclic dependency graph.
- [x] `WindowCoordinator`, `EmbeddedWindowCoordinator`, and
  `FrameCoordinator` no longer exist.
- [x] Cross-renderer contract tests live in `moui_tests/renderer_contract` and
  tester remains in `moui_tests/tester`.
- [x] Focused checks, static gates, `pr`, `daily`, and `platform` profiles pass;
  host-sim, macOS Skia, and Web presentation smoke pass on the current host.
- [ ] The combined `full` profile passes. Its daily/platform/theme work and all
  remaining full-only steps pass independently, but this host lacks `pwsh` and
  the pre-existing full maintenance hotspot ratchets still report five
  unchanged files.
- [x] Base, Skia, and Web package-mode external consumers resolve outside the
  monorepo with the intended dependency closures; every public release module
  produces a local package archive.
- [x] The pre-rename concrete-renderer module names and repository directories
  have no remaining references; closure, API, focused renderer, archive, and
  external-consumer checks pass under the new names. Renderer naming guidance
  is synchronized; the global guidance gate remains blocked only by the
  unrelated `crater-browser-integration.md` active-plan status/index mismatch.
- [x] No publish or registry-baseline mutation is performed.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-07 | Use an atomic 0.2 migration with no old-contract aliases or wrappers. |
| 2026-08-07 | Use local object-safe surface capabilities with opaque handles; concrete renderer modules own platform interpretation. |
| 2026-08-07 | Platform backends hold narrow owners directly; shared cross-owner operations are stateless workflows rather than another aggregate coordinator. |
| 2026-08-07 | Name concrete renderer release modules `moui_<implementation>_renderer` so each binding/engine and its renderer remain adjacent; no old module wrapper is retained because 0.2 is unpublished. |

## Progress

| Date | Note |
|------|------|
| 2026-08-07 | Plan, RFC, ADR, and target invariants established before code migration. |
| 2026-08-07 | Migrated root render to opaque `HostSurface` plus `RendererProvider`/`RendererSession`; moved platform interpretation into renderer-owned policies and removed the old lifecycle contracts. |
| 2026-08-07 | Split backend-common state into lifecycle, frame, image, input, services, and embedded owners; migrated all platform backends and removed aggregate coordinators. |
| 2026-08-07 | Migrated runtime, CLI templates, examples, addons, internal tests, docs, generated interfaces, and structural validators to the new ownership and provider/session contracts. |
| 2026-08-07 | `pr`, `daily`, and current-host `platform` pass; Android/iOS/HarmonyOS host-sim, macOS Skia renderer smoke, and real Chrome Web presentation pass. |
| 2026-08-07 | Package-mode base/Skia/Web consumers report `monorepoSource=false`; all public release modules produce local archives without publishing. |
| 2026-08-07 | Web presentation exposed an existing HTML image upload failure in headless Chrome; the Web renderer now stages decoded images through a canvas before WebGPU upload, with a JS regression test. |
| 2026-08-07 | `full` remains incomplete locally: `pwsh` is unavailable and full maintenance reports five unchanged pre-existing hotspot budget overflows; all other full-only steps pass independently. |
| 2026-08-07 | Renamed the unpublished renderer modules and directories to `moui_{skia,sun,web,wgpu}_renderer`; focused tests, package archives, release closure, API, Web resource-path checks, and package-mode base/Skia/Web consumers pass without publishing. The PR profile reaches only the unrelated crater-plan guidance failure. |
