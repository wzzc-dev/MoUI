# View Catalog

The `views` package exposes user-facing constructors for building MoUI apps.
Public constructors return `@core.ViewSpec`, so app code can stay declarative
while the core runtime owns identity, layout, paint, input, and semantics.

Use this catalog as a support matrix for current view APIs. Source-level details
remain in `views/*.mbt` and the generated public API summary in
`views/pkg.generated.mbti`.

## API Style

- Constructors use MoonBit labeled and optional parameters for common options.
- Stateful controls receive `@core.Binding[T]` values from `State::binding()` or
  `BuildContext::binding`.
- Visual customization usually flows through `@core.Theme`, style types, or
  ordered modifiers such as `.padding`, `.background`, `.clip`, and `.opacity`.
- File drop targets use the `ViewSpec::on_file_drop` modifier so apps can accept
  normalized platform file paths without depending on backend-specific events.
- Platform-specific behavior should not be added in `views`; views preserve UI
  intent as `@core.ViewSpec` and `@core.DrawCommand` data.

```mbt nocheck
let draft = @core.State::new("")
let screen = @views.column([
  @views.text("Todo"),
  @views.text_field(draft.binding(), placeholder="New item"),
  @views.button("Add", on_click=() => println(draft.get())),
], spacing=8.0)
```

## Text And Media

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `text` | `views/label.mbt` | Font/foreground modifiers | Text role through core | `views/views_test.mbt` | Showcase, Markdown Editor | Basic label primitive. |
| `image` | `views/image.mbt` | Modifier-based | Image draw intent | `views/views_test.mbt` | Showcase | Renderer image support is tracked in the capability report. |
| `rich_text_editor` | `views/markdown_editor.mbt` | TextFieldStyle | Text field semantics through core | `views/views_test.mbt`, `core/rich_text_editor_test.mbt` | Markdown Editor | Generic rich text editor wrapper; see `docs/markdown-editor.md`. |
| `markdown_editor` | `views/markdown_editor.mbt` | TextFieldStyle | Text field semantics through core | `views/views_test.mbt` | Markdown Editor | App supplies Markdown parsing and styled runs; see `docs/markdown-editor.md`. |

## Controls

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `button` | `views/button.mbt` | ButtonStyle | Button | `views/views_test.mbt` | All examples | Main activation primitive. |
| `menu_button` | `views/controls.mbt` | ButtonStyle | Menu | `views/views_test.mbt` | Showcase | Button wrapper with menu semantics. |
| `checkbox` | `views/checkbox.mbt` | Color/font params | Checkbox | `views/views_test.mbt` | Showcase Todo pattern | Binding-backed boolean control. |
| `toggle` | `views/controls.mbt` | Color params | Switch | `views/views_test.mbt` | Showcase | Checkbox wrapper with switch semantics. |
| `toggle_switch` | `views/controls.mbt` | Color params | Switch | `views/views_test.mbt` | Showcase | Alias-style switch entry point. |
| `radio` | `views/controls.mbt` | Color params | Radio | `views/views_test.mbt` | Showcase | Binding-backed single-option primitive. |
| `text_field` | `views/text_field.mbt` | TextFieldStyle | Text field | `views/views_test.mbt`, core input tests | Showcase, Markdown Editor | Binding-backed text input. |
| `searchbar` | `views/searchbar.mbt` | Color/font params | Search field | `views/views_test.mbt` | Showcase | Text input specialized for filtering and clear actions. |
| `picker` | `views/picker.mbt` | Color/font params | Picker | `views/views_test.mbt` | Showcase | Binding-backed option picker. |
| `datepicker` | `views/datepicker.mbt` | Color/font params | Date picker | `views/views_test.mbt` | Showcase | Binding-backed date/time picker. |
| `slider` | `views/controls.mbt` | Color params | Slider | `views/views_test.mbt` | Showcase | Custom painted scalar control. |
| `progress` | `views/controls.mbt` | Color params | Progress | `views/views_test.mbt` | Showcase | Custom painted progress indicator. |
| `tooltip` | `views/controls.mbt` | SurfaceStyle | Tooltip when visible | `views/views_test.mbt` | Showcase | Wraps a child with an optional overlay. |

## Layout And Containers

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `surface` | `views/container.mbt` | SurfaceStyle | Group through child | `views/views_test.mbt` | Showcase, Markdown Editor | Styled container and surface primitive. |
| `row` / `column` | `views/flex.mbt` | Child/modifier based | Group/list via children | `views/views_test.mbt` | All examples | Flex layout primitives. |
| `spacer` | `views/flex.mbt` | N/A | None | `views/views_test.mbt` | Showcase | Flexible space primitive. |
| `frame` | `views/frame.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Constraint wrapper. |
| `padding` / `padding_insets` | `views/padding.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | All examples | Ordered layout modifier wrappers. |
| `stack` / `overlay` | `views/stack.mbt` | Child/modifier based | Children preserved | `views/views_test.mbt` | Showcase, Dialog host, Tooltip | Overlay layout primitives. |
| `scroll_view` | `views/grid_list.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Emits clip/offset behavior through core. |
| `grid` | `views/grid_list.mbt` | N/A | Children preserved | `views/views_test.mbt` | Showcase | Fixed-column layout. |
| `list` | `views/grid_list.mbt` | N/A | List/list item roles through core | `views/views_test.mbt`, `core/semantics_test.mbt` | Showcase Todo pattern | Eager list layout. |
| `lazy_list` | `views/grid_list.mbt` | N/A | List output | `views/views_test.mbt` | Showcase | Windows visible rows from data. |
| `lazy_grid` | `views/grid_list.mbt` | N/A | List/grid output | `views/views_test.mbt` | Showcase | Windows visible grid rows from data. |

## Navigation And Presentation

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `navigation_destination` | `views/navigation.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase | Route/view pair for navigation stack. |
| `navigation_stack` | `views/navigation.mbt` | Child-based | Selected child semantics | `views/views_test.mbt`, Showcase tests | Showcase | Selects view from `NavigationState`. |
| `tab_item` | `views/navigation.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase | Tab descriptor. |
| `tab_view` | `views/navigation.mbt` | ButtonStyle defaults | Tab buttons | `views/views_test.mbt` | Showcase | Binding-backed tab selection. |
| `dialog_host` | `views/navigation.mbt` | SurfaceStyle | Dialog when presented | `views/views_test.mbt`, Showcase tests | Showcase | Stack wrapper for modal content. |
| `sheet` / `sheet_host` | `views/sheet.mbt` | Brush, radius, shadow | Sheet presentation | `views/views_test.mbt` | Showcase | Modal or bottom-sheet presentation wrapper. |

## Theme And Environment

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `theme` | `views/theme.mbt` | Creates Theme | N/A | `views/views_test.mbt` | Showcase | Convenience constructor for theme tokens. |
| `environment` | `views/theme.mbt` | Creates Environment | N/A | `views/views_test.mbt` | Showcase | Runtime environment helper. |
| `light_theme` / `dark_theme` | `views/theme.mbt` | Creates Theme | N/A | `views/views_test.mbt` | Showcase | Convenience theme presets. |

## Advanced Helpers

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `expanded` / `flexible` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Flex child modifiers. |
| `layout_priority` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | Showcase | Supplies priority metadata to custom layout delegates. |
| `align` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase, Dialog host, Tooltip | Alignment wrapper. |
| `aspect_ratio` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Ratio constraint wrapper. |
| `intrinsic_width` / `intrinsic_height` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Intrinsic measurement wrappers. |
| `custom_layout` | `views/layout_helpers.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt` | Showcase | Builds `ViewSpec::custom`. |
| `custom_children_layout` | `views/layout_helpers.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | Showcase | Builds `ViewSpec::custom_layout` with child size, baseline, priority, and placement callbacks. |
| `component` | `views/layout_helpers.mbt` | BuildContext-based | Built child semantics | `views/views_test.mbt` | Examples via app components | Wraps `@core.Component::new`. |

## Maintenance Checklist

When adding or changing a public view constructor:

1. Keep the constructor in `views/` and return `@core.ViewSpec`.
2. Reuse existing core specs, styles, bindings, and modifiers where possible.
3. Add or update focused tests in `views/views_test.mbt`.
4. Add Showcase coverage when the view is user-facing and visually meaningful.
5. Update this catalog if API, theme support, semantics, or example coverage
   changes.
6. Run `moon info` after public API changes and review `views/pkg.generated.mbti`.
