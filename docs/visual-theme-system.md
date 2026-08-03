# Visual Theme System

> This document describes the `ThemeSpec` → `Theme` pipeline, `ColorPalette`,
> component themes, and environment-theme resolution. For an overview, see
> [Architecture](architecture.md). For control-style details, see the
> [Button Styling Guide](button-styling-guide.md).

The visual system is a `ThemeSpec -> resolve_theme -> Theme` pipeline. `core`
owns the neutral schema and resolver; branded design systems are addon
adapters that produce the same `@core.Theme`:

- `core` owns `ThemeSpec` (preset/color-mode/density/contrast/seed/reduced-motion
  intent), `resolve_theme(spec, system_scheme)` / `resolve_minimal_theme`, the
  `Theme` schema, and `Theme::neutral()` fallback. `ColorPalette` carries the
  full on*/container role matrix (primary/on_primary/primary_container,
  secondary, tertiary, error, surface/on_surface/on_surface_variant, semantic
  success/warning/danger/info with on-colors, outline/outline_variant, focus,
  scrim) so a branded system does not need to derive roles ad hoc.
- `Theme` is a token record for scheme, palette, spacing, radius, typography,
  shadow, motion, and surfaces — **no control vocabulary** (ADR 0017).
  Control tokens live in `@views.ControlThemeSet` (`button`, `text_field`,
  `surface`, `choice_control`, `progress`, `slider`, `picker`, `feedback`,
  `badge`, `form_validation`), each storing `ControlStateTokens` resolved to
  `ControlStateStyle` at paint time via `ButtonTheme::resolve(variant, state)`
  etc. App and control code reads canonical groups such as
  `theme.palette.foreground`, `theme.palette.on_primary`,
  `control_set.button.primary`, `theme.typography.body`,
  `theme.spacing_scale.sm`, and `theme.radius_scale.md`.
- `@views.light_theme()` / `@views.dark_theme()` resolve the Minimal preset
  via `resolve_minimal_theme`. `@views.theme(...)` composes whole token groups
  over an optional base. The ambient `ControlThemeSet` is built by
  `minimal_control_theme_set(theme)` and carried through the view
  environment alongside the `Theme`.
- `Environment` carries `theme_spec` (user intent), `system_scheme`
  (host-reported), and the resolved `theme`. `with_system_scheme` rebuilds the
  full theme from `theme_spec` so a host `ThemeChanged(Dark)` event switches
  palette/surfaces/shadows, not just a scheme flag. The legacy
  `with_color_scheme` (which left the palette stale) is removed.
- Controls resolve their styles **ambient-ly** at paint time: each control's
  `theme?` parameter is optional (no `default_theme()` capture), and paint
  closures read `theme.unwrap_or(ctx.environment.theme)` so a button/checkbox/
  text field/progress/slider/picker/etc. tracks dark-mode / high-contrast /
  reduced-motion / palette changes via `set_environment` without the caller
  rebuilding the view tree. Leaf controls emit a `"context"` revision token so
  reconcile defers to environment-driven repaints. Composite views resolve
  construction-time layout reads (spacing/shadow) through a shared
  `views_ambient_theme(theme)` helper (falling back to `Theme::neutral`) and
  pass the resolved theme to their leaf children.
- `ButtonVariant::style(control_set)` resolves a variant from
  `control_set.button` via `ButtonVariantToken`; controls default to this
  path and `style?` is a one-shot override. `ButtonVariant` covers
  Primary/Tonal/Outline/Ghost/Subtle/SubtleBrand. `ControlStateStyle` carries
  optional `bottom_border_only` and `inner_focus_border` fields so Fluent 2
  underline inputs and focus-reveal inner strokes render without
  variant-specific draw paths. `ControlStateStyle` lives in `views` (ADR 0017)
  and is shared by the token resolver and the view-layer style structs.
- `View::theme(...)` and `View::environment(...)` cascade the theme/environment
  into child subtrees via the `child_environment` hook at layout/paint time;
  their modifier revisions include a content fingerprint so reconcile detects
  real theme changes.
- `ChoiceControlTheme` carries `box_shape` (`Square`/`Circle`) and `check_style`
  (`Checkmark`/`Dot`) so checkboxes render as rounded squares with a "✓" glyph
  while radios render as circle rings with a filled inner dot (Fluent 2 style).
  `checkbox` accepts optional `box_shape?`/`check_style?` overrides; `radio`
  passes `Circle`/`Dot`. `SliderTheme` carries
  `thumb_shape` (`Rounded`/`Circle`); Fluent 2 sliders use a circular thumb.
- `DesignSemanticPalette` carries a neutral ramp
  (`background_2`/`background_3`/`background_4`, `foreground_2`,
  `stroke_1`/`stroke_2`/`stroke_accessible`) and a separate `brand_stroke` so
  Fluent 2's `colorNeutralBackground1/2/3/4`, `colorNeutralForeground1/2`,
  `colorNeutralStroke1/2/Accessible`, and `colorBrandStroke1` are expressed
  distinctly. `core_palette()` maps the ramp onto `ColorPalette` surface tiers
  (surface=background_2, surface_variant=background_3, outline=stroke_1,
  outline_variant=stroke_2). `divider` uses `outline_variant` (subtle
  stroke_2); menus/popovers read `control_set.surface.overlay_shadow`
  (Fluent flyout shadow) falling back to `shadow_scale.lg`/`md`.
- `presence_dot(status, ...)` renders a Fluent 2 PresenceBadge status dot
  (Available/Away/Busy/Offline/Unknown) as a filled circle with a contrasting
  border, overlayable on avatars.
- `SurfaceStyle` supports surface brushes, radius, padding, border metadata,
  and shadow metadata.
- `moui_theme/*` produces a complete `@core.Theme` plus a `@views.ControlThemeSet`
  from `DesignSystemTokens::to_theme()`; brand-specific control styles live in
  `ControlThemeSet`. An app that wants Fluent 2 (or another branded system) to
  drive control appearance calls `@fluent.theme(...)` once and passes both the
  `Theme` and the `ControlThemeSet` through the view environment; controls
  inherit the control set automatically instead of per-control `style=`
  arguments.
- `ShadowStyle` and `BorderStyle` are view-level style inputs; paint converts
  them into concrete `DrawCommand` payloads once the final frame is known.
- `animated_value`, `animated_point`, `animated_color`, `TransitionSpec`, and
  `TransitionStyle` provide small property-animation samplers for state-driven
  visuals. `View::transition` and `View::presence` apply those samples through
  existing opacity, offset, scale, and foreground modifiers, including a
  reduced-motion shortcut.
- `ImageFit::Contain/Cover/Stretch/ScaleDown/FitWidth/FitHeight` records image intent, with
  source, opacity, and rounded clipping preserved in the view spec.
- Native Skia and WebGPU renderers keep visible draw-command support on the
  mainline. Skia owns native raster pixels and text diagnostics, while WebGPU
  owns browser wasm-gc presentation. Experimental native WGPU still validates
  the GPU path when explicitly requested.

View constructors pass `Brush`, border, and shadow data into `DrawCommand`
without calling `Brush::fallback_color`; fallback is centralized in renderer
capability layers.

The native Skia renderer is the recommended native baseline for renderer smoke
and platform entrypoint validation. It presents CPU pixel frames through platform
presenters supplied through `HostSurfaceKit` and uses the local `moui_skia` binding for raster, path, image,
and text diagnostics. The WebGPU host-import renderer forwards the full command
set to the browser runtime. Experimental native WGPU continues to exercise the
GPU surface path and provider text integrations when explicitly requested. See
[Renderer capability report](renderer-capability-report.md).

Text measurement flows through the runtime `TextSystem` contract. `core/` owns
the neutral contract and deterministic fallback; the native Skia mainline
exposes `skia_text_system()` for renderer/text diagnostics, WGPU diagnostic
providers live under `render/wgpu/*`, and Web installs a browser Canvas-backed
system that matches its WebGPU glyph path. See [Text system](text-system.md).
