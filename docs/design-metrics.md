# Design Metrics

> Single source for the default control and surface metrics. The numbers here
> are the contract: `moui/core/theme_desktop_test.mbt`,
> `moui/views/style/control_theme_set_test.mbt`, and
> `moui/views/button/button_test.mbt` assert them, and the gallery screenshots
> are judged against them. Change a number here only together with the tests
> and an ADR note.

Related: [visual-theme-system.md](visual-theme-system.md),
[button-styling-guide.md](button-styling-guide.md),
[plans/done/visual-quality.md](plans/done/visual-quality.md),
ADR 0071 (Desktop preset).

## Where metrics live

| Layer | Owner | Contents |
|---|---|---|
| `Theme.palette` / `typography` / `radius_scale` / `shadow_scale` / `motion` / **`layout_scale`** | `moui/core` | Neutral, size-only tokens. `layout_scale` carries control height, row height and container padding — no colors, no variant vocabulary. |
| `ControlThemeSet` | `moui/views` | Per-control style tokens (colors, borders, radii) resolved from the theme. Elevation and surface padding read the theme scales, so a preset moves them without a second token set. |
| Constructor defaults | `moui/views` | Only sizes a caller can reasonably override (`width`, explicit `height`, card `padding`). A zero/omitted size means "use `layout_scale`". |

Density (`ThemeSpec.density`) multiplies spacing and layout metrics:
`Compact` ×0.82, `Standard` ×1.0, `Comfortable` ×1.18.

## Type scale

`Minimal` (existing default, unchanged from 0.6.x) and `Desktop` (new
opt-in preset). Each tier is a `FontSpec` (size / weight / line height);
`FontSpec` also carries optional `letter_spacing` and OpenType `features`
(tag → value). The desktop tier sets line heights today; tracking stays unset
until the Skia text path honors it (see [Known gaps](#known-gaps)).

| Role | Minimal | Desktop | Use |
|---|---|---|---|
| display | 38 / 600 | 32 / 650 | page hero numbers, empty-state art |
| headline | 27 / 600 | 24 / 650 | page/section headline |
| title | 21 / 600 | 18 / 600 | card/panel title |
| subtitle | 18 / 600 | 15 / 600 | secondary title |
| body | 16 / 400 | 14 / 400 | default copy |
| label | 16 / 600 | 13 / 550 | buttons, tabs, form labels |
| control | = label | = label | control text |
| caption | 13 / 400 | 12 / 400 | metadata, status bar |
| overline | 11 / 600 | 11 / 600 | eyebrows, table headers |

Desktop line heights: display 35.8, headline 28.8, title 23.4, subtitle/body
20.3 (1.45× for body), label 16.9, caption 16.2, overline 14.3. `FontSpec`
carries an optional `line_height`; the read-only `text` view re-flows line
boxes onto it (provider leading stays the fallback when unset), so prose gets
1.45× without touching text providers.

## Radii

| Token | Minimal | Desktop |
|---|---|---|
| sm | 4 | 4 |
| md | 6 | 8 |
| lg | 8 | 12 |
| pill | 999 | 999 |

`md` carries controls and inputs; `lg` carries cards, popovers and dialogs.

## Layout metrics (`Theme.layout_scale`)

| Field | Minimal | Desktop | Consumers |
|---|---|---|---|
| `control_height` | 40 | 32 | `button`, `text_field` (when no explicit height) |
| `control_padding_x` | 16 | 12 | `button` horizontal padding and icon gap |
| `row_height` | 34 | 30 | `sidebar` rows |
| `card_padding` | 24 | 16 | `card` / raised `container` |
| `overlay_padding` | 12 | 8 | popover/menu panel padding, sidebar inset |
| `dialog_padding` | 16 | 20 | `dialog` panel padding |

Buttons hug their content horizontally; the old fixed 100×40 default is gone.
An explicit `width`/`height` still wins.

## Elevation (`Theme.shadow_scale`)

| Tier | Minimal | Desktop (light) |
|---|---|---|
| sm | 0 0 0 @3% | 0 1 2 @5% |
| md | 0 2 8 @6% | 0 8 24 −6 @10% |
| lg | 0 2 16 @8.4% | 0 12 32 −8 @18% |

Desktop dark uses 28/38/52% alphas. Cards take `sm`, popovers `md`, dialogs
`lg`. The paint model carries one shadow per layer, so a tier is one tuned
shadow rather than a stacked pair; stacked elevation is a follow-up.

## State layers

`ControlThemeSet.button.state_layer` tints with `palette.foreground`, not the
brand color, so hover/pressed on ghost buttons and list rows stays neutral.
Selected rows still read through a heavier alpha and the control's own token.

| State | Light alpha | Dark alpha |
|---|---|---|
| hover | 0.06 | 0.06 of near-white foreground |
| focus | 0.10 | 0.10 |
| pressed | 0.10 | 0.10 |
| dragged | 0.14 | 0.14 |
| selected | 0.10 | 0.10 |
| disabled | 0.38 | 0.38 |

Focus is a visible state layer today; a dedicated 2 px accent ring that does
not change border width is a V2 item (it needs a paint-side inset stroke).

## Accent

Desktop's palette uses a brand accent in place of Minimal's monochrome
primary. The fallback is chosen for AA contrast at 13 px control text:

| Scheme | Accent | On-accent | Contrast |
|---|---|---|---|
| Light | `#1D6FE0` | white | 4.77:1 |
| Dark | `#60A5FA` | near-black | 6.38:1 |

On macOS the host reports the system accent (`NSColor.controlAccentColor`) as
`AccentColorChanged(0xAARRGGBB)`: once at startup and again whenever
`NSSystemColorsDidChangeNotification` fires. `HostRuntimeDriver` stores it in
`Environment.system_accent`. The resolver picks the palette in this order:

1. `ThemeSpec.seed` — an app-pinned accent always wins.
2. `Environment.system_accent` on the `Desktop` preset — the OS accent drives
   the palette (accent, tonal rows, focus ring).
3. The Desktop fallback table above.
4. Minimal ignores both; it stays monochrome.

Hosts without an accent service (Windows, Linux, Web) leave `system_accent`
empty and land on the fallback, so behavior there is unchanged. The value is
kept as an environment input instead of being written into `ThemeSpec`, which
keeps theme specs reproducible and lets a spec pinned by an app ignore the OS.

## Frame background

The runtime clears each frame to the root view's scoped theme background
(`theme.palette.background`), falling back to the runtime environment's theme
when the root does not scope one. A root view that paints no background still
lands on the theme backdrop: `.theme(dark_theme())` on the root keeps dark
themes from showing a white page, and the offscreen gallery screenshots render
the runtime's commands unchanged. Frames stay transparent when a platform view
owns the surface.

## Motion

`Theme.motion` carries `fast 120 / normal 180 / slow 280 ms` with
`EaseInOut`. Reduced motion zeroes all three in the resolver.

Every interactive control in the state matrix animates hover/press through the
shared `pressable_transition` slot: button background, text-field border,
checkbox/radio/toggle row overlay, slider halo. The duration is `fast_ms`
capped at **150 ms**, and reduced motion snaps to the terminal color. Controls
read `environment.reduced_motion` even when their theme is pinned, because
`Environment::with_theme_spec` now keeps `reduced_motion`/`accessibility_contrast`
in sync with the spec.

## Validation

```sh
moon test moui/core --target native
moon test moui/views --target native
node scripts/visual-control-matrix.mjs
node scripts/generate-control-previews.mjs --check
node scripts/generate-gallery-screenshots.mjs --check
node scripts/generate-icon-set.mjs --check
```

- `moui/core/theme_desktop_test.mbt` — preset numbers, density, seed,
  contrast, reduced motion, accent on-color, host-accent precedence over the
  Desktop fallback (and Minimal ignoring it).
- `moui/apphost/host_runtime_driver_test.mbt` — an
  `Event::AccentColorChanged` dispatch rebuilds `Environment.system_accent`.
- `moui/views/style/control_theme_set_test.mbt` — control tokens derive from
  the theme; Minimal metrics unchanged.
- `moui/views/button/button_test.mbt` — control height follows
  `layout_scale`; explicit height wins; default hugs.
- `moui_tests/visual_matrix` + `scripts/visual-control-matrix.mjs` — every
  interactive control at default/hover/pressed/focused/disabled × light/dark;
  an expected state that paints like the resting state fails as
  `missing_states`.
- `scripts/generate-control-previews.mjs --check` — the committed
  Skia-rendered `docs/assets/controls/*.png` sheets still match the matrix
  pixels (hosts without Skia skip this comparison).
- `scripts/generate-gallery-screenshots.mjs --check` — the committed
  README/homepage `gallery-{light,dark}.png` still match an offscreen render
  of `examples/gallery` at 1080×820 (hosts without Skia skip).

## Material defaults

`material(width, height)` defaults: `blur_radius` 16, `corner_radius` 12,
`tint` = theme `surface` at 65% alpha. Skia blurs the painted backdrop inside
the rounded clip; Sun blurs through a rectangular clip; renderers without a
backdrop read paint the tint. `scroll_edge` defaults to a 24 DIP fade from the
theme background to transparent. Native macOS `NSVisualEffectView` is declared
in the platform readiness declaration but not implemented yet.

## Known gaps

1. **Letter-spacing / OpenType features** — the tokens and declaration-key
   plumbing exist (`FontSpec.letter_spacing`, `FontSpec.features`). The Sun CPU
   text path honors letter spacing and line height; the mainline Skia text path
   and the Web renderer ignore both fields today, so the Desktop preset does
   not set tracking yet. Feature tags are recorded but no provider consumes
   them yet.
2. **Stacked shadows** — `ShadowStyle` is one layer; dialog/card double
   shadows wait for the paint model or a second `ShadowStyle`.
3. **System accent on other hosts** — macOS reads `controlAccentColor`; Windows
   (DWM accent) and Linux (portal `accent-color`) equivalents are not wired and
   fall back to the preset accent.
4. **Other control state transitions** — only `button` animates hover/press.
5. **Icons** — the built-in 24×24 set, `icon_svg` for arbitrary SVG path
   data, and `lucide_icon` over a vendored 103-icon Lucide subset
   (`resource/icons/lucide.json`, ISC). `sf_symbol_icon` bridges SF Symbols
   names to that set; native Apple artwork (per-weight SF Symbols via AppKit)
   needs a macOS host service and remains open.
