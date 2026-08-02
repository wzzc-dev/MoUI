# Button Styling & Theme Override Guide

This document explains how button appearance is resolved in MoUI and how to
override it at the app level (per-control, per-variant, or globally via the
theme). It exists so future "make this button a different color" tasks do not
need to re-derive the resolution pipeline from source.

## Resolution Pipeline (read this first)

A button's paint-time appearance flows through four layers. Always trace a
color change through these layers before editing:

1. **Palette** — `@core.ColorPalette` (`moui/core/theme.mbt`).
   - `ColorPalette::light()` / `ColorPalette::dark()` build the Minimal palette
     via `ColorPalette::from_seed(primary=..., scheme)`.
   - Minimal light primary = `Color::rgba(r=0.145, g=0.145, b=0.149)` (near-black
     zinc). Minimal dark primary = near-white. This is why the default Primary
     button reads as black in light mode.
   - `from_seed` derives the full on*/container matrix: `on_primary` is white on
     dark primaries, near-black on light primaries (luminance threshold 0.55).

2. **Component tokens** — `@views.ControlThemeSet.button : ButtonTheme`
   (`moui/views/style/control_theme_tokens.mbt`, `moui/views/style/control_theme_set.mbt`).
   Per ADR 0017, these token structs live in `moui/views` as `ControlThemeSet`;
   `core` carries no control vocabulary. App-facing one-shot styles remain
   `@views.ButtonStyle` / variant helpers.

### Single source of truth

`ControlThemeSet`, built once by `minimal_control_theme_set(theme)`, is the
**only** compute source for *all* control theming — choice controls, sliders,
progress, pickers, feedback, badges, form validation, and buttons. The legacy
`XStyle::default(theme=)` constructors in `moui/views/style/control_style.mbt`
(`ChoiceControlStyle::default`, `SliderStyle::default`, `BadgeStyle::default`,
etc.) are now thin projections over `ControlThemeSet` kept only for backward
compatibility.

**Rule:** when changing a control's themed appearance, edit
`minimal_control_theme_set` (or an override of `ControlThemeSet`) and read
tokens at paint time via `@style.views_ambient_control_theme(theme)`. Do **not**
fork a second computation inside an `XStyle::default` — that reintroduces the
dual-source drift this unification removed. New controls should read
`ControlThemeSet` directly (or be built with `themeable_control`).
   - `minimal_control_theme_set(theme)` builds the default `ControlThemeSet` from
     the palette. Each variant (`primary`/`tonal`/`outline`/`ghost`/`subtle`/`subtle_brand`)
     is a `ControlStateTokens` (foreground/background/border/border_width/radius).
   - `ButtonTheme` also carries `state_layer : StateLayerTokens` (color +
     hover/focus/pressed/dragged/selected/disabled alphas). Minimal state layer
     = `palette.primary` at hover 0.08 / pressed 0.12 / disabled 0.38.
   - Branded addons (`moui_theme/*`) replace `components` wholesale via
     `DesignComponentTokens::core_themes(scheme)`; Fluent 2 additionally
     differentiates `subtle`/`subtle_brand` and adds brand-stroke borders.

3. **State resolution** — `ButtonTheme::resolve(variant, state)`
   (`moui/views/style/control_theme_tokens.mbt`).
   - Normal state = `variant_tokens.resolve()` (tokens → `ControlStateStyle`).
   - Hovered/Pressed/Focused = normal with a state-layer wash blended onto the
     background via `state_layer_background(base, layer_color, alpha)`. When the
     base background is transparent, the layer is emitted at the requested
     alpha; otherwise it is composited over the base keeping the base alpha.
   - Disabled = normal with foreground/background/border alphas multiplied by
     `disabled_alpha`, shadow dropped.
   - So a Primary button's hover/press shades are **not** hand-written — they
     are the near-black primary with a translucent primary wash, which is why
     hover/press on the default Primary button is nearly invisible.

4. **Control paint** — `button_control` (`moui/views/button/button.mbt`)
   called by `button` (same file; re-exported as `@views.button` via
   `moui/views/button.mbt`).
   - `resolved_style = style? | variant.style(control_set)` — an explicit
     `style=` argument is a one-shot override; otherwise the variant resolves
     from `control_set.button` (layer 2/3).
   - `variant.style(control_set)` (`moui/views/style/style_api.mbt`) maps
     `ButtonVariant` → `ButtonVariantToken` → `ButtonTheme::resolve`; the
     signature takes a `ControlThemeSet`, not a `Theme`.
   - The `ControlThemeSet` is resolved ambient-ly at paint time via
     `@style.views_ambient_control_theme(theme)`, so
     dark-mode/a11y/reduced-motion changes apply without the caller rebuilding
     the view tree.

## Variant Cheat Sheet (Minimal preset)

| Variant      | Normal background            | Normal foreground   | Hover/Press                          |
|--------------|------------------------------|---------------------|--------------------------------------|
| `Primary`    | `palette.primary` (near-black) | `palette.on_primary` (white) | primary + 0.08/0.12 primary wash |
| `Tonal`      | `surface.lerp(primary, 0.12)` | `palette.primary`   | tonal base + primary wash            |
| `Outline`    | transparent                  | `palette.foreground`| `surface_variant` wash on hover      |
| `Ghost`      | transparent                  | `palette.foreground`| `foreground * 0.06` / `* 0.12` wash  |
| `Subtle`     | transparent (alias of Ghost) | `palette.foreground`| same as Ghost                        |
| `SubtleBrand`| transparent                  | `palette.primary`   | same wash model                      |

Key implication: the Ghost hover wash (`foreground.multiply_alpha(0.06)`) is the
"light gray" users see when hovering an unselected sidebar/header item. The
Primary fill (`palette.primary`) is the "black" users see on the selected item.
A request like "make the primary button a gray a bit darker than the hover gray"
is asking to replace the Primary normal background with a mid-gray that sits
between the Ghost hover wash and the near-black primary.

## Override Strategies (app-level, no framework edits)

Pick the smallest scope that satisfies the request.

### Strategy A — Per-control `style=` override (smallest scope)

Use when only one or a few buttons need a custom look. Build a `ButtonStyle`
with `@views.ButtonStyle::filled/tonal/outline/ghost(theme?)` as a base and
patch the `normal`/`hovered`/`pressed`/`disabled` `ControlStateStyle` fields,
or construct one directly:

```moonbit
let gray = theme.palette.foreground.lerp(theme.palette.surface, 0.55)
let on_gray = @core.Color::white()
let style : @views.ButtonStyle = {
  normal: {
    foreground: on_gray,
    background: @core.Brush::solid(gray),
    border: None,
    radius: theme.radius_scale.md,
    shadow: None,
    bottom_border_only: false,
    inner_focus_border: None,
  },
  hovered: { /* ..normal with a darker gray */ .. },
  pressed: { /* ..normal with an even darker gray */ .. },
  disabled: { /* ..normal with multiply_alpha(0.38) */ .. },
}
button("Label", on_click=Msg, variant=@views.ButtonVariant::Primary, theme~, style~, width=104.0)
```

`ControlStateStyle` is `pub(all)` in `@views` (ADR 0017).
App packages construct it via `@views.new_control_state_style(...)`.
`ButtonStyle` is `pub struct` (field-private); construct via
`ButtonStyle::new(...)` or factory methods (`::filled`, `::tonal`, etc.),
and modify via `with_xxx(...)` methods (Flutter `copyWith` pattern).

### Strategy B — Theme-level component override (global to one app)

Use when every Primary button in an app should change. Override
`control_set.button.primary` once where the control set is built and pass the
patched `ControlThemeSet` alongside the `Theme`. This keeps the state-layer
hover/press model intact — only the normal token changes, hover/press are
still derived.

```moonbit
fn showcase_control_set(theme : @core.Theme) -> @views.ControlThemeSet {
  let palette = theme.palette
  let gray_fill = palette.foreground.lerp(palette.surface, 0.55)
  let base = @views.minimal_control_theme_set(theme)
  let button = {
    ..base.button,
    primary: @views.ControlStateTokens::new(
      foreground=@core.Color::white(),
      background=gray_fill,
      border=gray_fill,
      border_width=0.0,
      radius=theme.radius_scale.md,
    ),
  }
  { ..base, button }
}

// In the app's view:
let theme = @views.light_theme()
let control_set = showcase_control_set(theme)
```

`ControlThemeSet`, `ButtonTheme`, `ControlStateTokens`, and `StateLayerTokens`
are all in `@views`, so app packages can read `control_set.button` and
rebuild it with struct-spread (`{ ..control_set, button }`).

### Strategy C — Palette seed override (changes primary everywhere)

Use when the whole primary family (buttons, focus rings, choice controls,
icons) should shift. Replace `palette.primary` via `ColorPalette::from_seed` or
`Theme::with_palette`. **Warning:** this also changes `focus`, `info`, choice
control selected colors, and any control that reads `palette.primary`. Prefer
Strategy B unless the request is explicitly "change the brand/primary color".

```moonbit
let palette = @core.ColorPalette::from_seed(
  primary=@core.Color::rgba(r=0.45, g=0.45, b=0.48),  // mid-gray instead of near-black
  @core.ColorScheme::Light,
)
let theme = @views.theme(palette~, scheme=@core.ColorScheme::Light)
```

## Color Helpers (`@core.Color`)

- `Color::rgba(r~, g~, b~, a?)` — build a color (channels 0..1).
- `Color::white()` / `Color::black()` / `Color::gray()` — constants.
- `Color::lerp(other, t)` / `Color::mix(other, weight)` — interpolate; `t=0`
  keeps self, `t=1` adopts other. Use to derive scheme-aware grays from
  `palette.foreground` + `palette.surface`.
- `Color::lighten(amount)` / `Color::darken(amount)` — lerp toward white/black.
- `Color::multiply_alpha(opacity)` / `Color::with_alpha(alpha)` — alpha only.
- `Brush::solid(color)` — wrap a color for `ControlStateStyle.background`.

## Picking a Gray

The Minimal light palette: `foreground=0.145`, `surface=0.984`,
`surface_variant=0.957`, `outline=0.898`. Reference points for "gray":

| Expression                                  | Light value | Reads as            |
|---------------------------------------------|-------------|---------------------|
| `foreground.multiply_alpha(0.06)`           | ~0.145 @ 6% | Ghost hover wash    |
| `foreground.multiply_alpha(0.12)`           | ~0.145 @ 12%| Ghost press wash    |
| `foreground.lerp(surface, 0.85)`            | ~0.91       | Near-surface tint   |
| `foreground.lerp(surface, 0.55)`            | ~0.56       | Mid gray            |
| `foreground.lerp(surface, 0.30)`            | ~0.38       | Dark gray           |
| `palette.primary` (default)                 | ~0.145      | Near-black          |

For "a gray a bit darker than the hover gray": start near
`foreground.lerp(surface, 0.55)` (mid gray) and adjust the lerp weight up
(darker) or down (lighter). Always check both `Light` and `Dark` schemes — the
same lerp expression tracks both because `foreground`/`surface` flip.

## Where Buttons Live in the Showcase

When asked about "the showcase button", it is most likely one of:

- `examples/showcase/app/navigation.mbt` — `sidebar_item` (selected =
  `Primary`, unselected = `Ghost`) and `header` action buttons (Overview/
  Examples toggle between `Primary` and `Ghost`).
- `examples/showcase/app/controls_section.mbt` — the controls gallery Primary
  button.
- `examples/showcase/app/components.mbt` — capability/animation cards.
- `examples/showcase/app/interaction_lab_section.mbt` — interaction lab
  variant demos.

The theme is built once in `ShowcaseModel::view` (`examples/showcase/app/app.mbt`)
via `@views.light_theme()` / `@views.dark_theme()` and threaded through every
section via the `theme` argument. Strategy B applied there affects all of them
uniformly.

## Common Pitfalls

- **Editing `moui/core/theme.mbt` or `moui/views/style/control_style.mbt` to change
  one app's button color is almost always wrong.** Those are framework files
  affecting every app. Use Strategy A or B in the app package instead.
- **`ButtonStyle::filled/tonal/outline/ghost` are legacy helpers** that bypass
  `control_set.button`. They still work as `style=` bases but do not track
  branded component tokens. Prefer patching `control_set.button` (Strategy
  B) for consistency with branded design systems.
- **Hover/press are derived, not stored.** `ButtonTheme::resolve` computes them
  from the normal token + `state_layer`. If you patch `primary` via Strategy B,
  hover/press update automatically. If you build a `ButtonStyle` via Strategy
  A, you must supply `hovered`/`pressed`/`disabled` explicitly.
- **`on_primary` is contrast-derived.** If you swap `primary` to a light gray,
  `on_primary` (computed at palette-build time) may still be white and produce
  low-contrast text. Set `foreground` explicitly in the override (Strategy A/B)
  or re-derive via `ColorPalette::from_seed` (Strategy C).
- **Check both schemes.** A gray that looks right in Light may vanish in Dark.
  Lerp expressions based on `foreground`/`surface` track both; hardcoded
  `Color::rgba` values do not.
