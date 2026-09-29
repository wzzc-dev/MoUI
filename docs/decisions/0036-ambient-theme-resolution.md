# 0036: Ambient theme resolution at paint time

- **Date**: 2026-09-29
- **Status**: Accepted
- **Deciders**: Agent-assisted
- **Related**: [ADR 0017](0017-theme-and-host-contract.md), [ADR 0034](0034-viewnode-declaration-coverage-gate.md), [plan moui-studio](../plans/active/moui-studio.md)

## Context

MoUI components resolved their theme from two different places, and the split
was invisible until an app pinned a dark theme:

1. **Paint-time ambient resolution** — `text`, `text_field`, and `button`
   store only declaration inputs (role, variant) and resolve
   `self.theme.unwrap_or(ctx.environment.theme)` inside
   `measure`/`paint`. They track `View::theme(...)` subtrees and host
   `ThemeChanged` events without the caller rebuilding the tree.
2. **Declaration-time fallback** — `container`/`card`, `divider`,
   `toolbar`, `command_bar`, and the choice groups called
   `views_ambient_theme(theme?)` while building the view tree, where no
   environment exists yet. The helper falls back to
   `Theme::neutral()` (= minimal **light**), and the resolved colors were
   baked into the node.

Consequence: inside a `.theme(dark)` subtree, text painted near-white
(palette foreground) while its surrounding card stayed neutral-light
(white brush). On a light-mode host window the result is white-on-white at
~1.16:1 measured contrast — exactly what shipped in MoUI Studio's
technical-dark shell on 2026-09-29 (commit `102ebe578`), where headings,
inspector labels, and the window title were invisible on macOS while every
framework test stayed green. The same bug class had already been recorded in
reverse on 2026-09-27 ("dark system + light layout without painted
backgrounds = white-on-white").

## Decision

1. **Surfaces follow the ambient theme at paint time.** `ContainerBox`
   (moui/views/layout) gains an `ambient : ContainerVariant?` field. When the
   caller pins neither an explicit `background=` nor a `theme=`, `container()`
   records the variant instead of baking colors, and `paint` resolves the full
   surface chrome (brush, border, radius, shadow) via
   `variant.style(ctx.environment.theme)`. Pinned values always win; the
   default environment (neutral light) renders exactly as before.
2. **Dividers resolve at paint too.** `divider()` with neither `color=` nor
   `theme=` stores `None` and paints the environment theme's
   `palette.outline_variant`.
3. **Composite helpers forward, never pre-resolve.** `card`/`center`,
   `toolbar`/`command_bar`, and `radio_group`/`checkbox_group` forward the
   `theme?` Option instead of resolving it to `Theme::neutral()` and threading
   the result down (spacing defaults come from `@style.default_theme()`,
   which is scheme-independent).
4. **Apps that want a fixed look pin it explicitly.** Components that derive
   concrete colors at declaration time (`badge`, `callout`, `inline_error`,
   feedback/state views) keep their `theme?` contract; an app wanting a
   deterministic brand appearance passes `theme=<brand_theme>()` at those
   call sites. MoUI Studio does this for its pinned-dark shell.

## Options Considered

### Option A: Paint-time ambient resolution for surface components (chosen)

- Pros: matches the button/text contract and ADR 0017's "controls track the
  environment" intent; fixes every app with a themed subtree; unthemed hosts
  are byte-identical to before (fallback resolves against the same neutral
  light theme).
- Cons: `container_box` signature gains one optional parameter; ambient
  containers resolve style twice across layout/paint (style is cheap and
  pure); shadow tokens from a custom views-side `ControlThemeSet` are not
  visible to the ambient path — ambient surfaces are flat by design.

### Option B: Thread the theme into view construction

- Pros: one resolution point.
- Cons: impossible without global state — view construction is a pure
  function of the model and runs before the environment exists. Rejected on
  architecture grounds.

### Option C: App-side only (paint root background, pin every call site)

- Pros: zero framework change.
- Cons: leaves the trap armed for every future dark-themed app; ~20 call
  sites per app must remember to pin; the framework keeps two contradictory
  resolution contracts.

## Consequences

- Every `container`/`card`/`divider` without an explicit `background=` or
  `theme=` now renders with the ambient environment theme's surface tokens —
  including radius scales, so themes with custom radius scales (MoUI Studio's
  tight 2/4/6 tiers) finally apply to cards.
- Declaration-coverage declarations (`ADR 0034`) carry an explicit `ambient`
  key (`base`/`raised`/`overlay`/`none`) so the deferred resolution is
  visible in view-tree snapshots.
- `container_box`'s public signature gained the optional `ambient?` parameter
  (`moui/views/{layout,container}/pkg.generated.mbti` regenerated).
- Verification for the motivating defect: web build at 1280×832 re-measured
  after the fix — every previously-invisible text sample (window title,
  panel headings, inspector labels, inactive tabs, undo badges) moved from
  1.16–2.79:1 to 14–18:1; framework tests cover the dark/light/neutral/
  pinned matrix for both `container` and `divider`.
