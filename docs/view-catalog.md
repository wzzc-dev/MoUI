# View Catalog

The `views` package exposes user-facing constructors for building MoUI apps.
Public constructors return opaque `@core.View[Msg]`, so app code can stay
declarative while the core runtime owns identity, layout, paint, input, and
semantics. `ViewSpec` is an internal core representation, not an app-facing API.

Use this catalog as a support matrix for current view APIs. Source-level details
remain in `views/*.mbt` and the generated public API summary in
`views/pkg.generated.mbti`.

## API Style

- Constructors use MoonBit labeled and optional parameters for common options.
- TEA-first controls receive plain values plus `on_input`, `on_change`, or
  `on_select` callbacks. Binding-backed companions keep the `*_binding` suffix
  for component-local or advanced state.
- Core exposes `FocusScope` helpers for app-owned focus order, first-invalid
  form targeting, and Enter/Escape default action intents; actual element focus
  traversal still lives in the runtime.
- Visual customization usually flows through `@core.Theme`, style types, or
  ordered modifiers such as `.padding`, `.background`, `.title`, `.clip`, and `.opacity`.
- File drop targets use the `View::on_file_drop` modifier so apps can accept
  normalized platform file paths as typed messages without depending on
  backend-specific events.
- Platform-specific behavior should not be added in `views`; views preserve UI
  intent as `@core.View[Msg]` and eventual `@core.DrawCommand` data.

```mbt nocheck
enum Msg { DraftChanged(String); SubmitDraft }

fn view(draft : String) -> @core.View[Msg] {
  @views.column([
    @views.text("Todo"),
    @views.text_field(draft, on_input=DraftChanged, placeholder="New item"),
    @views.button("Add", on_click=SubmitDraft),
  ], spacing=8.0)
}
```

## Text And Media

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `text` | `views/label.mbt` | Font/foreground modifiers | Text role through core | `views/views_test.mbt` | Showcase, Markdown Editor | Basic label primitive. |
| `image` | `views/image.mbt` | Modifier-based | Image draw intent | `views/views_test.mbt` | Showcase | Renderer image support is tracked in the capability report; Showcase Interaction Lab covers ready/loading/failed lifecycle states. |
| `rich_text_editor` | `views/markdown_editor.mbt` | TextFieldStyle | Text field semantics through core | `views/views_test.mbt`, `core/rich_text_editor_test.mbt` | Markdown Editor | Generic rich text editor wrapper; see `docs/markdown-editor.md`. |
| `markdown_editor` | `views/markdown_editor.mbt` | TextFieldStyle | Text field semantics through core | `views/views_test.mbt` | Markdown Editor | App supplies Markdown parsing and styled runs; see `docs/markdown-editor.md`. |

## Controls

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `button` | `views/button.mbt` | ButtonStyle | Button | `views/views_test.mbt` | All examples | Main activation primitive. |
| `menu_button` | `views/controls.mbt` | ButtonStyle | Menu | `views/views_test.mbt` | Showcase | Button wrapper with menu semantics. |
| `checkbox` | `views/checkbox.mbt` | Color/font params | Checkbox | `views/views_test.mbt` | Showcase Todo pattern | TEA-first boolean control; use `checkbox_binding` for component-local state. |
| `toggle` | `views/controls.mbt` | Color params | Switch | `views/views_test.mbt` | Showcase | TEA-first switch control; binding alias available. |
| `toggle_switch` | `views/controls.mbt` | Color params | Switch | `views/views_test.mbt` | Showcase | Alias-style switch entry point. |
| `radio` | `views/controls.mbt` | Color params | Radio | `views/views_test.mbt` | Showcase | TEA-first single-option primitive; use `radio_binding` for component-local state. |
| `text_field` | `views/text_field.mbt` | TextFieldStyle | Text field | `views/views_test.mbt`, core input tests | Showcase, Markdown Editor | TEA-first text input; use `text_field_binding` for component-local state. |
| `searchbar` | `views/searchbar.mbt` | Color/font params | Search field | `views/views_test.mbt` | Showcase | TEA-first text input specialized for filtering and clear actions; `searchbar_binding` remains for advanced state. |
| `picker` | `views/picker.mbt` | Color/font params | Picker | `views/views_test.mbt` | Showcase | TEA-first option picker; `picker_binding` remains for advanced state. |
| `datepicker` | `views/datepicker.mbt` | Color/font params | Date picker | `views/views_test.mbt` | Showcase | TEA-first date picker with min/max range enforcement; `datepicker_binding` remains for advanced state. |
| `dropdown` / `combobox` / `autocomplete` | `views/popover.mbt` | ButtonStyle/TextFieldStyle/SurfaceStyle | Button/text field rows | `views/views_test.mbt` | Showcase Interaction Lab | Controlled floating menus built from overlays, scroll views, buttons, and text fields; expansion stays in the app model. |
| `radio_group` / `checkbox_group` | `views/choice_controls.mbt` | Color/font params | Group with radio/checkbox children | `views/views_test.mbt` | Showcase Controls | TEA-first grouped selection built from `ChoiceItem` descriptors. |
| `segmented_control` | `views/choice_controls.mbt` | ButtonStyle/SurfaceStyle | Tab-like group | `views/views_test.mbt` | Showcase Controls | Controlled single-selection segmented buttons. |
| `chip` / `tag` / `filter_chip` / `choice_chip` | `views/choice_controls.mbt` | SurfaceStyle/ButtonStyle | Button or text roles | `views/views_test.mbt` | Showcase Controls | Compact selection and labeling controls. |
| `slider` | `views/controls.mbt` | Color params | Slider | `views/views_test.mbt` | Showcase | Custom painted scalar control. |
| `progress` | `views/controls.mbt` | Color params | Progress | `views/views_test.mbt` | Showcase | Custom painted progress indicator. |
| `tooltip` | `views/controls.mbt` | SurfaceStyle | Tooltip when visible | `views/views_test.mbt` | Showcase Interaction Lab | Wraps a child with an optional overlay. |

## Feedback And States

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `toast` / `snackbar` | `views/feedback.mbt` | Tone colors/surface | Group | `views/views_test.mbt` | Showcase Feedback | App-owned transient/status surfaces; no queue manager in v1. |
| `banner` / `callout` | `views/feedback.mbt` | Tone colors/surface | Group | `views/views_test.mbt` | Showcase Feedback | Inline status and guidance surfaces with optional action. |
| `empty_state` / `loading_state` / `error_state` | `views/feedback.mbt` | Tone colors/surface | Group | `views/views_test.mbt` | Showcase Feedback | Reusable workflow state panels using optional `StateViewAction`. |
| `badge` / `stat_card` | `views/feedback.mbt` | Tone colors/surface | Text/group | `views/views_test.mbt` | Showcase Feedback | Compact metadata and metric cards. |

## Data Display

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `description_list` | `views/data_display.mbt` | Text/theme spacing | Group | `views/views_test.mbt` | Showcase Data | Term/detail metadata rows from `DescriptionItem` descriptors. |
| `table` / `table_column` | `views/data_display.mbt` | Surface/text/border | Grid with row items | `views/views_test.mbt` | Showcase Data | Controlled text table with optional custom cell view, selected row, header, and empty state; sorting/resizing stay app-owned. |
| `tree_view` / `tree_item` | `views/data_display.mbt` | Button/text | List/list item | `views/views_test.mbt` | Showcase Data | Controlled tree rendering from expanded ids and selected id; toggle/select messages are supplied by the app. |
| `avatar` / `avatar_group` | `views/data_display.mbt` | Theme colors/image | Labeled image/text group | `views/views_test.mbt` | Showcase Data | Initials or image avatars plus compact overflow group. |

## Forms

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `form` / `form_section` | `views/form.mbt` | Theme spacing/surface | Group | `views/views_test.mbt` | Showcase Forms | Layout shells for grouped TEA-controlled fields. |
| `form_field` | `views/form.mbt` | Theme typography/colors | Group with accessibility label | `views/views_test.mbt` | Showcase Forms | Composes label, required marker, helper text, validation message, disabled, and read-only states without renderer changes. |
| `form_field_state` | `views/form.mbt` | Theme typography/colors | Group with accessibility label | `views/views_test.mbt`, `core/app_framework_wbtest.mbt` | Showcase Forms | Bridges `@core.FormFieldState` validation into the view helper while preserving direct string-error constructors. |
| `form_error` / `form_helper_text` | `views/form.mbt` | Theme typography/colors | Text | `views/views_test.mbt` | Showcase Forms | Reusable support text helpers for app-local form layouts. |
| `input_group` | `views/input_group.mbt` | Theme surface/border | Child semantics | `views/views_test.mbt` | Showcase Forms | Prefix/suffix shell for app-owned inputs. |
| `clearable_text_field` / `password_field` | `views/input_group.mbt` | TextFieldStyle/ButtonStyle | Text field plus button semantics | `views/views_test.mbt` | Showcase Forms | Controlled wrappers; password reveal state remains app-owned. |
| `number_field` / `stepper` | `views/input_group.mbt` | TextFieldStyle/ButtonStyle | Text field and button semantics | `views/views_test.mbt` | Showcase Forms | Keeps parsing and numeric state in the app model. |
| `multiline_text_area_shell` | `views/input_group.mbt` | TextFieldStyle | Text field semantics | `views/views_test.mbt` | Showcase Forms | Fixed-height text field shell for multi-line layouts without adding an editor engine. |

## Layout And Containers

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `surface` / `card` | `views/container.mbt` | SurfaceStyle | Group through child | `views/views_test.mbt` | Counter, Showcase, Markdown Editor | Styled container primitives; `card` is the raised, padded entry point for simple apps. |
| `toolbar` / `command_bar` / `button_group` / `status_bar` | `views/toolbar_disclosure.mbt` | ButtonStyle/text/surface | Group | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | App-owned command and status surfaces built from buttons, text, and surfaces. |
| `command_palette` | `views/toolbar_disclosure.mbt` | ButtonStyle/text/surface | Menu | `views/views_test.mbt`, `core/gesture_action_wbtest.mbt`, Showcase tests | Showcase Navigation Shell | Renders `@core.ActionCommand` metadata (`group`, `description`, shortcut label, enabled state) as a TEA-controlled palette without native menu or renderer changes. |
| `row` / `column` | `views/flex.mbt` | Child/modifier based | Group/list via children | `views/views_test.mbt` | All examples | Flex layout primitives. |
| `center` | `views/container.mbt` | Optional background | Child semantics | `views/views_test.mbt` | Counter | Single-child layout helper that centers content inside its available space. |
| `spacer` | `views/flex.mbt` | N/A | None | `views/views_test.mbt` | Showcase | Flexible space primitive. |
| `frame` | `views/frame.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Constraint wrapper. |
| `padding` / `padding_insets` | `views/padding.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | All examples | Ordered layout modifier wrappers. |
| `stack` / `overlay` | `views/stack.mbt` | Child/modifier based | Children preserved | `views/views_test.mbt` | Showcase, Dialog host, Tooltip | Overlay layout primitives. |
| `popover` | `views/popover.mbt` | SurfaceStyle | Anchor plus optional overlay content | `views/views_test.mbt` | Showcase Interaction Lab | View-level floating surface using existing stack, align, and surface primitives; no native menu service. |
| `scroll_view` | `views/stack.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | Showcase, Markdown Editor | Emits clip/offset behavior through core and can report wheel deltas through `on_scroll`. |
| `grid` | `views/grid_list.mbt` | N/A | Children preserved | `views/views_test.mbt` | Showcase | Fixed-column layout. |
| `list` | `views/grid_list.mbt` | N/A | List/list item roles through core | `views/views_test.mbt`, `core/semantics_test.mbt` | Showcase Todo pattern | Eager list layout. |
| `lazy_list` | `views/grid_list.mbt` | N/A | List output | `views/views_test.mbt` | Showcase | Windows visible rows from data. |
| `lazy_grid` | `views/grid_list.mbt` | N/A | List/grid output | `views/views_test.mbt` | Showcase | Windows visible grid rows from data. |
| `virtual_list` / `sectioned_list` / `scroll_to_index` | `views/grid_list.mbt` | N/A | List output | `views/views_test.mbt`, Showcase tests | Showcase Layout | Overscanned windowed lists, grouped section headers, empty states, and controlled offset intents built on existing scroll/list primitives. |
| `accordion` / `disclosure` / `collapsible_panel` | `views/toolbar_disclosure.mbt` | ButtonStyle/surface/text | Group | `views/views_test.mbt`, Showcase tests | Showcase Feedback | Controlled disclosure containers; expanded state and toggle behavior stay in the app model. |
| `resizable_panel` | `views/toolbar_disclosure.mbt` | SurfaceStyle | Group | `views/views_test.mbt`, Showcase tests | Showcase Layout | Controlled-size panel with a visual handle; drag resizing is left for gesture support. |

## Navigation And Presentation

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `navigation_destination` | `views/navigation.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase | Route/view pair for navigation stack. |
| `navigation_stack` / `navigation_stack_selected` | `views/navigation.mbt` | Child-based | Selected child semantics | `views/views_test.mbt`, Showcase tests | Showcase | Selects a view from `NavigationState` or a TEA-owned route string. |
| `router_stack` | `views/navigation.mbt` | Child-based | Selected child semantics | `views/views_test.mbt`, `core/app_framework_wbtest.mbt`, Showcase tests | Showcase | Selects destinations from `@core.RouterState`, preserving query params and restoration snapshots while staying above the renderer. |
| `sidebar` / `breadcrumb` | `views/navigation.mbt` | ButtonStyle/text/surface | List/group | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled navigation shell helpers built from buttons, text, and surface primitives. |
| `split_view` / `master_detail` | `views/navigation.mbt` | Child-based | Group | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Fixed-width shell composition for master/detail layouts; v1 does not drag-resize panes. |
| `wizard` / `wizard_step` | `views/navigation.mbt` | ButtonStyle/surface | Group with tab-like step buttons | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled wizard workflow using `WizardStep` descriptors and app-owned current step. |
| `tab_item` | `views/navigation.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase | Tab descriptor. |
| `tab_view` | `views/navigation.mbt` | ButtonStyle defaults | Tab buttons | `views/views_test.mbt` | Showcase | TEA-first tab selection; use `tab_view_binding` for component-local state. |
| `dialog_host` | `views/navigation.mbt` | SurfaceStyle | Dialog when presented | `views/views_test.mbt`, Showcase tests | Showcase | Stack wrapper for modal content. |
| `sheet` / `sheet_host` | `views/sheet.mbt` | Brush, radius, shadow | Sheet presentation | `views/views_test.mbt` | Showcase | Modal or bottom-sheet presentation with content dismissal support. |

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
| `wrap` / `flow` / `responsive_grid` / `baseline_form_rows` | `views/layout_helpers.mbt` | N/A | Group | `views/views_test.mbt`, Showcase tests | Showcase Layout | Responsive wrapping, adaptive grid columns, and baseline-aligned form rows built with `custom_children_layout`; no renderer changes. |
| `align` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_wbtest.mbt` | Showcase, Dialog host, Tooltip | Places the child within its parent frame using the requested alignment. |
| `aspect_ratio` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Ratio constraint wrapper. |
| `intrinsic_width` / `intrinsic_height` | `views/layout_helpers.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Intrinsic measurement wrappers. |
| `custom_layout` | `views/layout_helpers.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt` | Showcase Advanced Rendering | Builds a custom `View[Msg]`; Showcase uses it to emit layer/blend, filter, shader, path, transform, and opacity draw commands. |
| `custom_children_layout` | `views/layout_helpers.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt`, `core/advanced_layout_wbtest.mbt` | Showcase | Builds a custom child-layout `View[Msg]` with child size, baseline, priority, and placement callbacks. |
| `component` | `views/layout_helpers.mbt` | BuildContext-based | Built child semantics | `views/views_test.mbt` | Examples via app components | Wraps `@core.Component::new`. |

## Maintenance Checklist

When adding or changing a public view constructor:

1. Keep the constructor in `views/` and return `@core.View[Msg]`.
2. Reuse existing core primitive builders, styles, bindings, and modifiers where possible.
3. Add or update focused tests in `views/views_test.mbt`.
4. Add Showcase coverage when the view is user-facing and visually meaningful.
5. Update this catalog if API, theme support, semantics, or example coverage
   changes.
6. Run `moon info` after public API changes and review `views/pkg.generated.mbti`.
