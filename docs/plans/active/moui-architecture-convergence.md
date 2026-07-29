# Plan: MoUI core/views/host/renderer/platform architecture convergence

- **Status**: active
- **Goal**: Converge MoUI package ownership and dependency direction to match
  ADR 0014/0015/0017-0020 and invariants P3-P6/R1-R2/M6. Make `core` neutral,
  `views` own control vocabulary, `backend/host` platform-neutral contracts
  only, `render/*` a provider-plugin system, platform adapters thin wiring
  over a shared transformer. Preserve Native Skia mainline, Native WGPU
  diagnostic, embedded-runtime entrypoints, and existing platform behavior.
- **Decisions**: ADR 0017 (Theme layering), 0018 (host split),
  0019 (renderer provider), 0020 (platform adapter convergence).
- **Non-goals**: redesigning `moui_richtext`; rewriting `moui_skia` FFI;
  changing MoonBit toolchain; mobile product-class graduation; reclassifying
  Native WGPU off diagnostic; absorbing platform logic into host.

## Sequencing (phased, no big-bang)

Each phase is independently green (`moon test` + relevant profile) before the
next starts. Phases are ordered by dependency direction: the lower layers
(core theme tokens, render surface contract) must land before the consumers
(host split, provider migration, platform convergence).

```text
Phase A  foundation contracts (no behavior change)
  A1  moui/render: add neutral RenderSurface/Completion/Recovery/Capability
      value types (ADR 0018 render-surface bridge, ADR 0019 provider contract
      half) — core-visible value types only, no concrete renderer edits.
  A2  moui/views: add ControlThemeSet shell + views-owned resolve entry points
      that today delegate to core (ADR 0017 scaffold). No core removal yet.
  A3  scripts/validate-host-import-baseline.mjs +
      scripts/validate-core-theme-no-control-surface.mjs +
      scripts/validate-renderer-provider-open-extension.mjs +
      scripts/validate-platform-adapter-duplication.mjs +
      checks/platform-adapter-duplication-baseline.json
      added in **report-only** mode (no enforcement) so current violations are
      captured as the shrinking baseline.

Phase B  Task 2 — Theme layering (ADR 0017)
  B1  Move control token structs + per-control theme structs + shape/appearance
      enums (ButtonTheme, ButtonVariantToken, ChoiceControlTheme,
      ChoiceControlShape, CheckMarkStyle, TextFieldTheme, TextFieldAppearance,
      SliderTheme, PickerTheme, ProgressTheme, FeedbackTheme, BadgeTheme,
      SurfaceTheme, FormValidationTheme, ThumbShape, ComponentThemes,
      ControlStateTokens, ControlStateStyle, StateLayerTokens, ToneTokens,
      ButtonState) from moui/core/theme_components.mbt to
      moui/views/control_theme_tokens.mbt + moui/views/control_theme_set.mbt.
      Keep InteractionState in core (neutral gesture/semantics state).
  B2  moui/core/theme.mbt: remove Theme.components field + with_components;
      core.Theme = scheme/palette/spacing/radius/typography/shadow/motion/
      surfaces only.
  B3  moui/views: ControlThemeSet now owns the migrated structs; resolve
      helpers (minimal_components, branded control defaults) move from
      moui/core/theme_resolver.mbt to moui/views/control_theme_resolver.mbt.
  B4  moui_theme/*: project branded control tokens into views ControlThemeSet,
      not core ComponentThemes. Ambient resolver produces (Theme,
      ControlThemeSet).
  B5  root facade, examples, docs: consume ControlThemeSet via view env, not
      Theme.components.
  B6  Switch validate-core-theme-no-control-surface.mjs to **enforce**; freeze
      API surface baseline down.
  Gate: moon test moui/core moui/views moui_theme --target native;
        sh scripts/check.sh --profile theme; daily green.

Phase C  Task 1 — core control-only surface removal (ADR 0017 + 0014)
  C1  After B, core has no control types. Audit core pkg.generated.mbti for
      residual control-only enums/structs/fns (ButtonState already moved in B1;
      sweep for Picker/Slider/Checkbox helpers that leaked into core).
  C2  Generalize tap/press gesture internal state into core-private neutral
      models (core/gesture.mbt); remove public control-only bridge APIs that
      have zero callers (find-references audit).
  C3  scripts/validate-core-theme-no-control-surface.mjs extended to also
      reject any control-only type on core's public surface (not just theme).
  Gate: moon info moui/core shows no control-only types; no repo control
        implementation depends on @core control state; daily green.

Phase D  Task 3 — host contract split (ADR 0018)
  D1  moui/runtime: receive HostRuntimeDriver + wall_clock + redraw_scheduler
      + runtime-side subscription source adapters from backend/host.
  D2  moui/render: receive render completion / GPU recovery / image snapshot /
      layer cache glue (host_surface render half, image_repaint, renderer
      completion) — uses A1 surface contract.
  D3  moui/backend/host: shrink to HostEvent/HostCmd/services facade/
      EmbedderHostChannel/HostPlatformChannel/capability summary/text-input
      session contract/window lifecycle+request contracts. moon.pkg drops
      moui/runtime + moui/render imports; keeps core + window/core + dpi +
      accesskit + utf8.
  D4  Platform adapters + composition root: import HostRuntimeDriver from
      runtime, renderer completion from render, host contracts from host.
  D5  Switch validate-host-import-baseline.mjs to **enforce**.
  Gate: moon info moui/backend/host shows no runtime/render symbols;
        moon test moui/backend/host moui/runtime moui/render --target native;
        daily green; embedded-runtime entrypoints unchanged behavior.

Phase E  Task 4 — renderer provider plugin (ADR 0019)
  E1  moui/render: define RendererProvider + RendererInstance + neutral
      Capability/Surface/Completion/Recovery value types (A1 half already in).
  E2  render/skia: implement RendererProvider (capabilities/negotiate/create/
      render/recover/dispose); delete its central matrix contributions.
  E3  render/wgpu + render/webgpu_adapter: implement RendererProvider.
  E4  render/canvas2d + render/sun: implement RendererProvider.
  E5  moui/render: delete native_gpu_selection.mbt +
      capabilities_backend_matrix.mbt; renderer.mbt facade becomes a thin
      provider registry helper or moves to runtime composition root.
  E6  moui/runtime composition root: register providers for the build;
      selection = capability negotiation, not central switch. Recovery
      fallback = SkiaRasterNative provider-declared capability (R2 preserved).
  E7  Contract test suite: render/skia and render/wgpu pass the same
      RendererProvider suite. Add a throwaway test renderer/provider that only
      adds a package + a registration line to prove open extension.
  E8  Switch validate-renderer-provider-open-extension.mjs to **enforce**.
  Gate: contract tests green; throwaway renderer attached without core/host/
        runtime/existing-renderer edits; daily green; Skia mainline + WGPU
        diagnostic behavior unchanged.

Phase F  Task 5 — platform adapter convergence (ADR 0020)
  F1  moui/backend/shared_adapter: new package owning cross-platform
      transformers (window event→HostEvent mapping, pointer/keyboard decode
      normalization, resize/scale normalization, lifecycle state machine,
      clipboard command mapping, text-input session state machine, surface
      attach/detach lifecycle, error mapping). Imports core + backend/host
      contracts only. Table-driven where platform input is a native type tag.
  F2  backend/{macos,windows,linux,web,android,ios,harmonyos,wechat}: shrink to
      native decode + PlatformCapability declaration + strategy impl + thin
      wiring calling shared_adapter. Add shared_adapter import.
  F3  backend/shared_adapter/*_table_test.mbt: table-driven tests feed
      (native_type_tag, payload) → expected HostEvent/HostCmd for every
      platform in one place.
  F4  Freeze checks/platform-adapter-duplication-baseline.json to the
      post-convergence measurement; switch
      validate-platform-adapter-duplication.mjs to **enforce** with allowlist
      for genuine platform differences (XComponent surface, Choreographer
      pacing, UIKit event loop, Win32 message queue, DOM/CDP).
  Gate: validate-platform-adapter-duplication green vs baseline;
        moon test moui/backend/shared_adapter --target native;
        sh scripts/check.sh --profile platform; per-platform smoke
        (path-triggered) unchanged; no reverse dependency
        (shared_adapter imports host, host does not import shared_adapter).

Phase G  docs + repo-local skill + final verification
  G1  docs/architecture-map.md: update ownership cheat sheet + dependency
      direction diagram (host imports, render provider model, shared_adapter).
  G2  docs/invariants.md: update P3 (core neutral, no control vocab),
      P5 (host contracts only), P6 (provider plugin), M6 (shared_adapter),
      add renderer provider + adapter budget rows.
  G3  docs/testing.md: register the four new validators + platform profile
      expectation + adapter duplication budget policy.
  G4  docs/visual-theme-system.md, docs/platform-host-contract.md,
      docs/renderer-capability-report.md, docs/button-styling-guide.md,
      docs/architecture.md: align with ADR 0017-0020.
  G5  skills/moui-framework-development-skill/SKILL.md: update framework
      development workflow pointers (host split, renderer provider, shared
      adapter, theme layering).
  G6  docs/decisions/README.md: index ADR 0017-0020.
  G7  Final: moon info moui/core moui/views moui/backend/host — capture API
      drift for human review; static trio (baseline/api-surface/guidance);
      sh scripts/check.sh --profile pr; --profile daily; --profile theme;
      --profile platform; path-triggered renderer/platform smoke per
      docs/testing.md.
  Gate: all validators green; all profiles green; API surface only shrinks
        or has RFC explanation; repo-local skill + docs match implementation.

## Compatibility strategy

- Phased landing: each phase green before the next; no big-bang.
- During Phase B, ControlThemeSet is born delegating to core, so consumers
  can migrate incrementally; the field is removed only after all consumers
  moved.
- Phase D moves files between packages; the composition root (entrypoints)
  is the only wiring edit. Mobile EmbedderHostChannel contract is preserved
  byte-for-byte (ADR 0005).
- Phase E keeps `--renderer auto|skia-gpu|skia-raster` and
  `MOUI_SKIA_RENDERER` (invariant R3) — the composition root honors them via
  provider capability, not a central enum.
- Phase F does not change any platform's observable behavior; the table-driven
  transformers reproduce the exact HostEvent/HostCmd mappings each platform
  had, verified by the table tests.
- Public API removals (Theme.components, control types on core, central
  renderer matrix, host runtime/render imports) are announced via `moon info`
  drift review in G7 and documented in ADR 0017-0020.

## Non-targets (explicit)

- No `moui_richtext` redesign.
- No `moui_skia` FFI rewrite (P7 ownership unchanged).
- No MoonBit toolchain change.
- No mobile product-class graduation (M6/M7/M8 unchanged; window-hosted
  entrypoints stay canonical).
- No Native WGPU reclassification off diagnostic (R1 preserved).
- No platform logic absorption into host (ADR 0018 forbids reverse deps).
- No runtime dynamic plugin discovery (compile-time composition per ADR 0019).

## Validator allowlist / RFC gate

- Any growth in API surface, renderer central coupling, or adapter
  duplication budget requires an RFC entry in the relevant allowlist
  (`checks/platform-adapter-duplication-baseline.json` allowlist, or a new
  ADR superseding 0017-0020).
- Budgets only shrink or stay; growth needs explicit reason.

## Progress

| Date | Note |
|------|------|
| 2026-07-28 | Opened plan; ADR 0017-0020 written; Phase 0 audit complete. |
