# Button Styling 与 Theme Override 指南

本文档说明 MoUI 中 button 外观如何解析，以及如何在 app 层覆盖它（单个控件、单个 variant，或通过 theme 全局覆盖）。它的存在是为了让未来“把这个 button 换个颜色”这类任务不必重新从源码推导解析管线。

## 解析管线（先读这里）

Button 的 paint-time 外观经过四层。编辑之前，始终先沿这些层追踪一次颜色变化：

1. **Palette** - `@core.ColorPalette`（`moui/core/theme.mbt`）。
   - `ColorPalette::light()` / `ColorPalette::dark()` 通过 `ColorPalette::from_seed(primary=..., scheme)` 构建 Minimal palette。
   - Minimal light primary = `Color::rgba(r=0.145, g=0.145, b=0.149)`（接近黑色的 zinc）。Minimal dark primary = 接近白色。这就是默认 Primary button 在 light mode 下看起来是黑色的原因。
   - `from_seed` 推导完整的 on*/container 矩阵：`on_primary` 在深色 primary 上是白色，在浅色 primary 上是近黑色（luminance threshold 0.55）。

2. **Component tokens** - `@views.ControlThemeSet.button : ButtonTheme`
   （`moui/views/style/control_theme_tokens.mbt`、`moui/views/style/control_theme_set.mbt`）。
   按 ADR 0017，这些 token struct 在 `moui/views` 中以 `ControlThemeSet` 存在；`core` 不携带 control vocabulary。面向 app 的一次性 style 仍是 `@views.ButtonStyle` / variant helper。
   - `minimal_control_theme_set(theme)` 从 palette 构建默认 `ControlThemeSet`。每个 variant（`primary`/`tonal`/`outline`/`ghost`/`subtle`/`subtle_brand`）都是一个 `ControlStateTokens`（foreground/background/border/border_width/radius）。
   - `ButtonTheme` 还携带 `state_layer : StateLayerTokens`（color + hover/focus/pressed/dragged/selected/disabled alpha）。Minimal state layer = `palette.primary`，hover 0.08 / pressed 0.12 / disabled 0.38。
   - 品牌 addon（`moui_theme/*`）会通过 `DesignComponentTokens::core_themes(scheme)` 整体替换 `ControlThemeSet`；Fluent 2 还会区分 `subtle`/`subtle_brand` 并添加 brand-stroke border。

3. **State 解析** - `ButtonTheme::resolve(variant, state)`
   （`moui/views/style/control_theme_tokens.mbt`）。
   - Normal state = `variant_tokens.resolve()`（tokens → `ControlStateStyle`）。
   - Hovered/Pressed/Focused = normal 加上 state-layer wash；该 wash 通过 `state_layer_background(base, layer_color, alpha)` 混合到 background 上。当 base background 透明时，layer 会以请求的 alpha 发出；否则会在保留 base alpha 的情况下叠加到 base 上。
   - Disabled = normal 的 foreground/background/border alpha 乘以 `disabled_alpha`，并移除 shadow。
   - 因此 Primary button 的 hover/press shade **不是**手写的，而是近黑色 primary 加上一层半透明 primary wash；这就是默认 Primary button 的 hover/press 几乎不可见的原因。

4. **控件绘制** - `button_control`（`moui/views/button/button.mbt`），由 `button`（同文件；经 `moui/views/button.mbt` 重导出为 `@views.button`）调用。
   - `resolved_style = style? | variant.style(control_set)` - 显式 `style=` 参数是一次性覆盖；否则 variant 从 `control_set.button` 解析（第 2/3 层）。
   - `variant.style(control_set)`（`moui/views/style/style_api.mbt`）将 `ButtonVariant` → `ButtonVariantToken` → `ButtonTheme::resolve`；签名接受 `ControlThemeSet`，不是 `Theme`。
   - `ControlThemeSet` 在 paint time 通过 `@style.views_ambient_control_theme(theme)` 以 ambient 方式解析，因此 dark-mode/a11y/reduced-motion 变化无需 caller 重建 view tree 即可生效。

## Variant 速查表（Minimal preset）

| Variant | Normal background | Normal foreground | Hover/Press |
|--------------|------------------------------|---------------------|--------------------------------------|
| `Primary` | `palette.primary`（近黑） | `palette.on_primary`（白色） | primary + 0.08/0.12 primary wash |
| `Tonal` | `surface.lerp(primary, 0.12)` | `palette.primary` | tonal base + primary wash |
| `Outline` | transparent | `palette.foreground` | hover 时为 `surface_variant` wash |
| `Ghost` | transparent | `palette.foreground` | `foreground * 0.06` / `* 0.12` wash |
| `Subtle` | transparent（Ghost alias） | `palette.foreground` | 同 Ghost |
| `SubtleBrand` | transparent | `palette.primary` | 同 wash 模型 |

关键含义：Ghost hover wash（`foreground.multiply_alpha(0.06)`）就是用户在 hover 未选中的 sidebar/header item 时看到的“浅灰”。Primary fill（`palette.primary`）就是用户在选中项上看到的“黑色”。类似“把 primary button 改成比 hover gray 稍深一点的 gray”这样的请求，是在要求用介于 Ghost hover wash 和近黑 primary 之间的中灰替换 Primary normal background。

## 覆盖策略（app 层，无需改框架）

选择满足请求的最小作用域。

### 策略 A - 单个控件 `style=` 覆盖（最小作用域）

当只有一个或少数几个 button 需要自定义外观时使用。用 `@views.ButtonStyle::filled/tonal/outline/ghost(theme?)` 作为基础构建 `ButtonStyle`，并 patch `normal`/`hovered`/`pressed`/`disabled` 的 `ControlStateStyle` 字段，或直接构造一个：

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

`ControlStateStyle` 在 `@views` 中是 `pub(all)`（ADR 0017）。App 包通过 `@views.new_control_state_style(...)` 构造它。`ButtonStyle` 是 `pub struct`（字段私有）；通过 `ButtonStyle::new(...)` 或 factory method（`::filled`、`::tonal` 等）构造，并通过 `with_xxx(...)` method 修改（Flutter `copyWith` 模式）。

### 策略 B - Theme 层 component 覆盖（对一个 app 全局生效）

当 app 中每个 Primary button 都应改变时使用。在构建 control set 的位置一次性覆盖 `control_set.button.primary`，并把 patch 后的 `ControlThemeSet` 与 `Theme` 一起传入。这样保留 state-layer hover/press 模型不变：只改变 normal token，hover/press 仍会派生出来。

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

`ControlThemeSet`、`ButtonTheme`、`ControlStateTokens` 和 `StateLayerTokens` 都在 `@views`，因此 app 包可以读取 `control_set.button` 并用 struct-spread（`{ ..control_set, button }`）重建。

### 策略 C - Palette seed 覆盖（改变所有 primary）

当整个 primary 家族（button、focus ring、choice control、icon）都应改变时使用。通过 `ColorPalette::from_seed` 或 `Theme::with_palette` 替换 `palette.primary`。**警告：**这也会改变 `focus`、`info`、choice control selected color，以及任何读取 `palette.primary` 的控件。除非请求明确是“改变 brand/primary color”，否则优先使用策略 B。

```moonbit
let palette = @core.ColorPalette::from_seed(
  primary=@core.Color::rgba(r=0.45, g=0.45, b=0.48),  // mid-gray instead of near-black
  @core.ColorScheme::Light,
)
let theme = @views.theme(palette~, scheme=@core.ColorScheme::Light)
```

## Color Helper（`@core.Color`）

- `Color::rgba(r~, g~, b~, a?)` - 构建颜色（channel 0..1）。
- `Color::white()` / `Color::black()` / `Color::gray()` - 常量。
- `Color::lerp(other, t)` / `Color::mix(other, weight)` - 插值；`t=0` 保持 self，`t=1` 采用 other。用于从 `palette.foreground` + `palette.surface` 推导 scheme-aware gray。
- `Color::lighten(amount)` / `Color::darken(amount)` - 向白/黑插值。
- `Color::multiply_alpha(opacity)` / `Color::with_alpha(alpha)` - 只改变 alpha。
- `Brush::solid(color)` - 为 `ControlStateStyle.background` 包装颜色。

## 选择灰色

Minimal light palette：`foreground=0.145`、`surface=0.984`、`surface_variant=0.957`、`outline=0.898`。关于“gray”的参考点：

| Expression | Light value | Reads as |
|---------------------------------------------|-------------|---------------------|
| `foreground.multiply_alpha(0.06)` | ~0.145 @ 6% | Ghost hover wash |
| `foreground.multiply_alpha(0.12)` | ~0.145 @ 12% | Ghost press wash |
| `foreground.lerp(surface, 0.85)` | ~0.91 | 近 surface tint |
| `foreground.lerp(surface, 0.55)` | ~0.56 | 中灰 |
| `foreground.lerp(surface, 0.30)` | ~0.38 | 深灰 |
| `palette.primary`（默认） | ~0.145 | 近黑 |

对于“比 hover gray 稍深一点的 gray”：从 `foreground.lerp(surface, 0.55)`（中灰）附近开始，然后把 lerp weight 调高（更深）或调低（更浅）。始终同时检查 `Light` 和 `Dark` scheme；相同 lerp 表达式会跟随两者，因为 `foreground`/`surface` 会翻转。

## Showcase 中的 Button 在哪里

被问到“showcase button”时，最可能是以下之一：

- `examples/showcase/app/navigation.mbt` - `sidebar_item`（selected = `Primary`，unselected = `Ghost`）和 `header` action button（Overview/Examples 在 `Primary` 和 `Ghost` 之间切换）。
- `examples/showcase/app/controls_section.mbt` - controls gallery 的 Primary button。
- `examples/showcase/app/components.mbt` - capability/animation card。
- `examples/showcase/app/interaction_lab_section.mbt` - interaction lab variant demo。

Theme 在 `ShowcaseModel::view`（`examples/showcase/app/app.mbt`）中通过 `@views.light_theme()` / `@views.dark_theme()` 构建一次，并通过 `theme` 参数传入每个 section。在那里应用策略 B 会一致影响所有这些 button。

## 常见陷阱

- **为了改变一个 app 的 button 颜色而编辑 `moui/core/theme.mbt` 或 `moui/views/style/control_style.mbt` 几乎总是错的。** 这些是框架文件，会影响每个 app。改用 app 包中的策略 A 或 B。
- **`ButtonStyle::filled/tonal/outline/ghost` 是 legacy helper**，会绕过 `control_set.button`。它们仍可作为 `style=` 基础使用，但不会跟随品牌 component token。为保持与品牌设计系统一致，优先 patch `control_set.button`（策略 B）。
- **Hover/press 是派生的，不是存储的。** `ButtonTheme::resolve` 从 normal token + `state_layer` 计算它们。如果通过策略 B patch `primary`，hover/press 会自动更新。如果通过策略 A 构建 `ButtonStyle`，必须显式提供 `hovered`/`pressed`/`disabled`。
- **`on_primary` 是按对比度推导的。** 如果把 `primary` 换成浅灰，`on_primary`（palette 构建时计算）可能仍是白色，从而造成低对比度文本。在覆盖中显式设置 `foreground`（策略 A/B），或通过 `ColorPalette::from_seed` 重新推导（策略 C）。
- **检查两种 scheme。** 在 Light 中看起来合适的灰色，在 Dark 中可能消失。基于 `foreground`/`surface` 的 lerp 表达式会跟随两者；硬编码的 `Color::rgba` 值不会。
