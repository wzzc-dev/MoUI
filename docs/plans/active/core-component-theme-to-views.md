# Plan: Component theme / control semantics ownership → views

- **Status**: active
- **Goal**: Keep neutral theme **schema** in `core`; move **control-specific**
  component tokens and semantics ownership toward `moui/views` (not domain).
- **Non-goals**: Domain facade ownership of theme types; letting `core` import
  `views`; big-bang `moui_theme` redesign in one PR.

## Constraint (why this is phased)

`@core.Theme` currently embeds:

```text
components : ComponentThemes
```

`ComponentThemes` / `ButtonTheme` / `ControlStateTokens` / … live in
`moui/core/theme_components.mbt`. Consumers:

- `moui/core/theme_resolver.mbt` (`minimal_components`)
- `moui/views/*` (paint via `theme.components.*`, `ButtonStyle`, …)
- `moui_theme/*` (projects branded tokens → `@core.ComponentThemes`)

Because **core must not depend on views** (B model), types that appear on
`Theme` **must remain core-visible** unless `Theme` itself is split (e.g.
core holds palette/scales only; component bag is views/environment-only).

So “move to views” means one of:

| Strategy | Idea | Cost |
|---|---|---|
| **S1 Schema stay** | Keep token structs on `Theme` in core; views own only app style structs (`ButtonStyle`, …) and constructors | Low; **status quo for tokens** |
| **S2 Split Theme** | `Theme` loses `components`; views/env attach component themes | High; breaks `moui_theme` + ambient theme |
| **S3 Views-owned components type, core holds opaque bag** | Hard with MoonBit package visibility | High |

**Default path: S1 until an explicit Theme-split RFC.** “瘦身” focus:

1. Stop **new** control semantics from landing in core.
2. Ensure **app-facing** control styles remain views-owned (`ButtonStyle`, …).
3. Document that `ComponentThemes` is **kernel theme schema**, not domain.
4. Optional later: S2 RFC.

## Already in good shape

- App control styles: `ButtonStyle`, `TextFieldStyle`, … in `moui/views/control_style*.mbt`
- Default aesthetic builders: `light_theme` / `dark_theme` in `moui/views/theme.mbt`
- Domain does **not** re-export component themes

## Residual core surface (keep as schema under S1)

- `theme_components.mbt`: `InteractionState`, `ControlStateTokens`,
  `ControlStateStyle`, `ButtonTheme`, `ComponentThemes`, per-control *Theme
  structs, variant tokens, state layers, …
- `theme_resolver.mbt`: `minimal_components`, resolve paths
- `Theme.components` field

## Acceptance (this plan)

- [x] Geometry facade exports `MainAxisAlignment` / `CrossAxisAlignment` (related layout sugar; separate small change)
- [ ] Written ownership rule: component tokens on `Theme` = core schema; control paint styles = views
- [ ] No new control-only enums/structs added to core without RFC
- [ ] `docs/button-styling-guide.md` + boundary doc state S1 explicitly
- [ ] (Optional) S2 RFC if product wants components off `Theme`

## Progress

| Date | Note |
|------|------|
| 2026-07-17 | Opened plan; Theme.components coupling blocks true source move without S2. |
| 2026-07-17 | Geometry: `MainAxisAlignment` / `CrossAxisAlignment` → `@geometry` facade. |
