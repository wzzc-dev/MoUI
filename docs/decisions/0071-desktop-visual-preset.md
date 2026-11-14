# 0071: Desktop visual preset and layout metrics

- **Date**: 2026-11-12
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted visual quality review)
- **Related**: plan `docs/plans/done/visual-quality.md`,
  `docs/design-metrics.md`, `docs/visual-theme-system.md`, ADR 0017 (control
  tokens live in views), ADR 0036 (ambient theme resolution)

## Context

A 2026-11-12 comparison against `egoist/mygo` showed that MoUI's perceived
visual quality trails its capability surface. The gap is not control count
(`moui/views` exposes more constructors than mygo documents) and not renderer
capability; it is the **default visual language**:

- a monochrome primary (`#252526`), 4/6/8 px radii, near-zero shadows and a
  16 px body made every default app read as a wireframe;
- button/input heights lived as hardcoded constructor defaults (100×40,
  240×40) with no theme owner, so no preset could move them together;
- `sidebar` rendered as a column of centered buttons with a solid primary
  fill for the selected row;
- surface padding/elevation came from fixed token values (`raised_padding =
  spacing.lg`, all shadows `None`), so cards and popovers had no depth.

The theme pipeline already splits cleanly: `core` owns neutral scales, `views`
owns control tokens (ADR 0017). What was missing was a neutral, size-only
metric group and a first-party preset that uses it.

## Decision

1. Add `ThemePreset::Desktop`, resolved by `core` through
   `resolve_desktop_theme(spec, system_scheme)`. `resolve_theme` dispatches on
   the preset; branded presets without their addon still fall back to Minimal.
2. Add `Theme.layout_scale` (`LayoutScale`): control height, control
   horizontal padding, row height, card/overlay/dialog padding. It carries
   **sizes only** — no colors, no variant vocabulary — so `core` does not gain
   control style tokens. Density scaling applies to it exactly as it does to
   `SpacingScale`.
3. `ControlThemeSet` derives surface elevation and padding from
   `theme.shadow_scale` / `theme.layout_scale`; control radii already derived
   from `radius_scale`. A preset therefore moves metrics without a second
   parallel token set.
4. Desktop defaults: body 14, title 18, control 13/550; radius md 8 / lg 12;
   control height 32, row 30, card 16, overlay 8, dialog 20; brand accent
   `#1D6FE0` (light) / `#60A5FA` (dark) with AA on-colors; layered single
   shadows per elevation tier.
5. Minimal keeps every 0.6.x metric. Desktop is opt-in via
   `@views.desktop_light_theme()` / `desktop_dark_theme()`.
6. State layers tint with `palette.foreground` instead of `palette.primary`,
   so hover/pressed stays neutral in every preset.

## Options Considered

### Option A: Retune Minimal in place

- Pros: one preset, no opt-in; screenshots improve immediately.
- Cons: silently changes every existing app's metrics and typography; breaks
  example/golden expectations with no rollback path; couples "make it prettier"
  to "upgrade the framework".

### Option B: New Desktop preset + layout metrics (chosen)

- Pros: reversible, testable, and the resolver already supports presets;
  metrics get a single owner; branded addons can override `layout_scale`.
- Cons: apps must opt in; two presets to document and screenshot.

### Option C: Put control sizes in `ControlThemeSet` only

- Pros: keeps `core` free of any sizing vocabulary.
- Cons: composites that resolve tokens at construction time (`card`, `sidebar`,
  `dialog`) cannot see the ambient `ControlThemeSet`; they would keep the old
  sizes unless every call site pins a theme. `layout_scale` on `Theme` is the
  only place both leaves and composites can read consistently.

## Rationale

The failure mode was not "wrong colors" but "no owner for size". `layout_scale`
gives sizes one owner and lets the existing `Theme` resolution path (including
density and reduced motion) apply. Keeping Minimal unchanged makes the change
shippable and testable; flipping the default is a separate, evidence-gated
decision for the next minor release.

## Consequences

- New public API: `Theme.layout_scale`, `LayoutScale` (+ `default`/`desktop`),
  `Theme::with_layout_scale`, `theme(layout_scale=)`; `TypographyScale::desktop`,
  `RadiusScale::desktop`, `ShadowScale::desktop`, `ColorPalette::desktop`;
  `ThemePreset::Desktop`; `ThemeSpec::desktop_light` / `desktop_dark`;
  `@views.desktop_light_theme` / `desktop_dark_theme`.
- `button` and `text_field` take optional `width` / `height`; omitted sizes
  resolve from the theme instead of hardcoded defaults. Call sites passing
  explicit sizes keep working.
- `card` padding defaults to `layout_scale.card_padding`; `sidebar` uses
  `row_height`, left-aligned labels and the tonal selected variant; `dialog`
  uses `dialog_padding`.
- Minimal's runtime rendering changes in two small ways: `raised_shadow` /
  `overlay_shadow` are now `Some` (Minimal's `sm`/`md`), and state layers use
  the foreground tone. Both are documented in `docs/design-metrics.md`.
- `FontSpec` gained optional `line_height`, `letter_spacing` and OpenType
  `features` (tag → value, canonicalized by tag for order-independent keys).
  The Desktop typography tier sets line heights; tracking stays unset until the
  Skia text path consumes it. The read-only `text` view re-flows line boxes
  onto the line height.
- Follow-ups: flip the default preset in a minor release after the screenshot
  gate; add letter-spacing/OpenType features, stacked shadows, OS accent
  plumbing, and state transitions on the remaining controls (V2/V3).

## Agent Notes

- **Session context**: completing the visual-quality plan (V0/V1).
- **Agent model**: DeepSeek-V4.1-Flash (ZCode).
- **Key prompt**: "完成计划 visual-quality.md 过程中要考虑可维护性、可扩展性、
  长期维护潜力、工程质量".
- **Validation**: `moon check --target native` (0 errors);
  `moon test moui/core --target native` (188 passed);
  `moon test moui/views --target native` (39 passed);
  `moon test moui/views/button --target native` (6 passed);
  preset/metric assertions in the three test files listed in
  `docs/design-metrics.md`.

## References

- `moui/core/theme.mbt` (`LayoutScale`, preset scales)
- `moui/core/theme_resolver.mbt` (`resolve_desktop_theme`)
- `moui/views/style/control_theme_set.mbt` (surface metrics/elevation)
- `moui/views/navigation/navigation_sidebar.mbt`
- `docs/design-metrics.md`
