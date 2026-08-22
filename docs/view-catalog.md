# View Catalog

The `views` package exposes user-facing constructors for building MoUI apps.
Public constructors return opaque `@moui.View[Msg]`, so app code can stay
declarative while runtime owns tree reconciliation, dirty state, layout, paint,
input, and semantics dispatch. New built-in controls define concrete
`@core.ViewNode` implementations in `moui/views` and construct typed views with
`@core.View::from_node`; `ViewSpec` is historical, while `ViewNode` remains an
advanced core extension protocol and is not re-exported by app-facing facades.

Use this catalog as a support matrix for current view APIs. Source-level details
remain in `views/*.mbt` and the generated public API summary in
`views/pkg.generated.mbti`.

For task-oriented composition patterns, see the
[Non-render component cookbook](non-render-component-cookbook.md). It shows how
to assemble forms, data tables, navigation shells, menus, host-service flows,
and virtual lists without changing the renderer surface.

Showcase exposes the current user-facing catalog in this order:
`Overview -> Text & Media -> Controls -> Forms -> Data ->
Layout -> Navigation Shell -> Feedback -> Runtime/Renderer -> Diagnostics`.
Deeper routes for
advanced rendering, text diagnostics, interaction diagnostics, and reusable
examples are kept as focused diagnostic destinations rather than top-level
catalog rows.

## Authoring new controls (boilerplate reduction)

Two helpers in `moui/views` cut the ~60% boilerplate every new control used to
repeat:

- **`view_declaration_auto`** (`moui/views/common/declaration_helpers.mbt`) —
  builds a `ViewDeclaration` from per-channel field lists, applying the
  theme-override cache rule. Prefer it over hand-rolled `view_record_key` +
  `view_declaration` plumbing inside a control's `declaration()` method.
- **`themeable_control[Msg, Style]`** (`moui/views/controls/control_builder.mbt`)
  — a generic, theme-aware constructor that wires `identity`, theme resolution,
  `focusable`, and event forwarding. A new control supplies only `layout`,
  `paint`, and optional `event`/`semantics` logic; `Style` is resolved once per
  frame from `ControlThemeSet` (the single source of truth). This is the
  recommended path for standard themed controls.

Both read theming from `ControlThemeSet` (never the legacy `XStyle::default`
constructors), so a theme change lives in exactly one place.

## API Style

- Constructors use MoonBit labeled and optional parameters for common options.
- TEA-first controls receive plain values plus `on_input`, `on_change`, or
  `on_select` callbacks. Binding-backed companions keep the `*_binding` suffix
  for component-local or advanced state.
- Descriptor-heavy helpers expose free constructors such as `action_item`,
  `menu_item`, `sidebar_item`, `breadcrumb_item`, `section_nav_item`,
  `selectable_list_item`, `table_column`, and `description_item` so ordinary app
  DSL code does not have to mix view constructors with `Type::new` ceremony.
- Core exposes `FocusScope` helpers for app-owned focus order, first-invalid
  form targeting, and Enter/Escape default action intents. Runtime element
  focus traversal is separate; apps can call `AppRuntime::focus_key` with a
  keyed focusable view, and `RouteFocusStore` records route-to-focus-key
  restoration targets. `View::focus_trap` constrains Tab traversal and pointer
  focus to a view-level subtree for dialog/popover compositions.
- Visual customization usually flows through token groups on `@moui.Theme`,
  style types, or ordered modifiers such as `.padding`, `.background`,
  `.title`, `.clip`, and `.opacity`. Theme customization should replace
  canonical groups like `palette`, `typography`, `spacing_scale`, and
  `radius_scale` rather than adding theme-level alias fields.
- File drop targets use the `View::on_file_drop` modifier so apps can accept
  normalized platform file paths as typed messages without depending on
  backend-specific events.
- Views intended for Agent or automation control attach a validated
  `SemanticId` with `View::semantic_id`. Identity is independent from
  `View::key`; explicit `Transparent`, `Boundary`, `MergeDescendants`, and
  `Hidden` composition controls the logical semantics tree. Controls advertise
  only action kinds backed by typed handlers, so `SetText` and `Scroll` cannot
  omit their payload.
- Platform-specific behavior should not be added in `views`; views preserve UI
  intent as `@moui.View[Msg]` and eventual `@core.DrawCommand` data.
- View-level menus (`menu_bar`, `command_menu`, `context_menu_region`) are
  overlay and button compositions. Native context-menu preview flows through
  `@services.MenuServices::show_context` (adapted to `HostServiceBridge::ShowMenu` at the host edge).
  Application menu bars are an L2 host preview via
  `@services.MenuServices::install_application` (macOS installs native menus;
  Windows/Linux/Web return `Unavailable`). See
  [Non-render cookbook](non-render-component-cookbook.md) and
  Showcase's Platform workspace.

## Preview Control Baseline

This baseline groups the public controls and reusable app patterns by the
workflows app authors usually need first. It is intentionally a preview matrix:
`ready` means the public `views` API is available, documented below, covered by
focused tests, and visible in Showcase. `partial` means the user-facing surface
exists but an important behavior remains app-owned, host-owned, or narrower than
SwiftUI/Flutter-style expectations. `example-only pattern` means the workflow is
demonstrated in an example package but is not yet a reusable public constructor.
`missing` means the catalog should not imply the capability exists.
The catalog itself stays renderer-neutral: view helpers emit normal core
layout, event, semantics, and draw-command surfaces. In the current preview
push, Showcase and Markdown Editor native Skia entrypoints are the preferred
runtime consumers for proving that these surfaces remain usable on the
Skia-first native baseline.

| Workflow | Current status | Public surface | Showcase / example coverage | Preview gaps |
| --- | --- | --- | --- | --- |
| Forms | ready with app-owned validation | `form`, `form_section`, `form_field`, `form_field_state`, `FormFieldStatus::Validating`, `form_validation_summary`, `form_actions`, `form_workflow_bar`, `form_error`, `form_helper_text`, `input_group`, `clearable_text_field`, `password_field`, `number_field`, `stepper`, `text_area`, plus `text_field`, `checkbox`, `toggle`, `segmented_control`, `picker`, and `datepicker` | Showcase Forms and Controls; Settings example | Validation rules and async checks stay in the app model; reusable view/runtime helpers now cover validating/help/error states, keyed first-invalid focus targets, submit guards, and Enter/Escape action status. |
| Navigation | ready for controlled shells, app-owned route history, app-sampled route transitions, and route focus restoration | `navigation_stack`, `router_stack`, `route_header`, `section_nav`, `sidebar`, `breadcrumb`, `split_view`, `master_detail`, `resizable_split_view`, `wizard`, `tab_view`, `@views.RouteHistoryState`, `@views.RouteFocusStore`, `@services.RouteSource`, `View::transition`, `AppRuntime::focus_key` | Showcase Navigation Shell; views navigation/router tests; Showcase route/state tests; host route fanout tests | App-owned deep-link shadow history is preview-ready through a serializable route stack, back/forward cursor, and `RouterSnapshot` restoration. `RouteSource` covers typed route/deep-link event fanout through `Subscription::route_event`, but it does not mutate app history by itself. Showcase now demonstrates a controlled fade/slide route transition sampled by app state; automatic transition scheduling, browser history, native URL bars, and OS deep-link dispatch remain app/host follow-up work. Fixed and controlled drag-resizable split panes are preview-ready; apps still own persisted pane width. Route focus restoration is preview-ready as an app/host call into the runtime after a route switch. |
| Dialogs and menus | ready for view-level + host context menu; L2 app menu preview | `dialog`, `alert`, `dialog_host`, `sheet_host`, `sheet`, `popover`, `dropdown`, `combobox`, `autocomplete`, `menu_button`, `menu_bar`, `command_menu`, `context_menu_region`, `command_palette`, `@views.ActionCommand`, `@views.CommandIntent`, `View::focus_trap`, `@services.MenuServices::show_context`, `@services.MenuServices::install_application`, `@services.ApplicationMenuPlacement` | Showcase Patterns and Platform workspaces; Command Palette; DSH Desktop | TEA-controlled view-level surfaces and host context-menu service preview are available. macOS supports top-level menu-bar groups and commands placed in the standard application menu; Windows/Linux/Web remain unavailable. Host-modal deep binding and native accessibility adapters remain platform follow-up work. |
| Custom paint | ready for canvas / custom_layout | `canvas`, `animated_canvas`, `custom_layout`, `custom_children_layout`, `PaintContext` helpers | Showcase Diagnostics and Platform workspaces; PDF Workbench; tutorial `06-animation` | See [Canvas and custom paint](canvas-and-custom-paint.md). Looping canvas motion can use `animated_canvas` + paint clock (`now_ms`); model ticks still use `@services.TimerSource` / `View::transition`. |
| Data views | ready with app-owned data logic | `DataSortState`, `PaginationState`, `ColumnVisibilityState`, `ColumnWidthState`, `ColumnOrderState`, `SelectionState`, `DataGridSelectionState`, `DataGridEditState`, `IncrementalData`, `data_grid_viewport`, `data_filter_bar`, `data_filter`, `selection_toolbar`, `action_item`, `table`, `table_column`, `column_visibility_panel`, `selectable_list`, `selectable_list_item`, `pagination`, `detail_panel`, `description_item`, `tree_view`, `description_list`, `avatar`, `avatar_group`, `variable_virtual_list`, `variable_list_metrics`, `virtual_list`, `sectioned_list`, `scroll_to_index`, `lazy_list`, `lazy_grid` | Showcase Data and Layout; upgraded Data Table example | Filtering and sorting rules, request lifecycle, and pointer-specific table header interactions stay in app packages. Reusable helpers cover variable-height windowing and stable anchors, two-dimensional reuse with frozen panes, keyboard range selection, cell editing, incremental keyed data, and grid collection semantics. Existing fixed-height list APIs remain compatible. |
| Feedback and workflow states | ready for app-owned state | `ToastQueue`, `ToastQueueItem`, `toast`, `toast_stack`, `snackbar`, `banner`, `callout`, `progress_status`, `inline_error`, `empty_state`, `loading_state`, `error_state`, `status_badge`, `badge`, `stat_card`, `accordion`, `disclosure`, `collapsible_panel`, `drop_zone`, `file_import_panel` | Showcase Feedback and Interaction Lab; File Importer example | Toast queue storage has a reusable helper, while timers, host notifications, progress task lifecycle, and native file-picker UX remain app/host-owned. |
| Input, gestures, and accessibility | ready for preview semantics/focus, native adapters tracked | `AppRuntime::focus_key`, `shortcut_button`, `focus_ring`, `FocusScope` helpers, `View::focus_trap`, `@views.ActionCommand`, `@views.KeyboardShortcut`, keyboard shortcut dispatch, `View::on_long_press`, `View::on_double_tap`, `View::on_drag`, `View::on_drag_with_frame`, semantics roles and state modifiers including disabled, pressed, selected, checked, expanded, invalid, required, and action labels | Showcase Interaction Lab shows focus order, first-invalid targeting, Enter/Escape command targets, runtime focus trapping, shortcuts, visible app-owned focus rings, semantic states, gestures, and file drop; Navigation Shell shows command metadata; Web ARIA tests cover disabled/actions; host/native tests keep AccessKit tree/action roundtrips | Runtime focus traversal, key focus, and view-level trapping are preview-ready. macOS menu, IME, and drag/drop readiness are visible through host capability diagnostics; full native accessibility adapters and parity announcements remain follow-up work. |
| Native platform views | partial native host primitive | `web_view`, `@host.WebViewHost`, `@host.WebViewController`, `@host.WebViewEvent`, `@host.WebViewSecurityPolicy`, `@host.HostWebViewCapabilities` | `views/views_test.mbt`; WebView Demo example | `web_view` participates in MoUI layout and semantics, but real content is host-owned native WebView placement synced from `DrawFrame.platform_views`. It is not a `DrawCommand`, and Web wasm reports unavailable instead of using an iframe overlay. Navigation and bridge traffic are issued as controller tasks and validated by the host. On macOS, a sibling WKWebView stays visible while the active transparent presenter moves above the view-level MoUI overlay bounds; the WebView excludes those bounds from hit testing so dialogs, sheets, and popovers receive pointer input. Its first 32 points are a drag/no-drag strip where blank space moves the window and interactive DOM controls or `[data-moui-no-drag]` elements remain clickable. Web, Windows, and Linux do not yet offer those macOS paths. v1 otherwise supports rectangular placement and clipping only; transforms, opacity, filters, and rounded clipping do not apply to the native WebView. Low-level WebView specs and platform-view placements remain `core` contracts for host integration. |

```mbt nocheck
enum Msg { DraftChanged(String); SubmitDraft }

fn view(draft : String) -> @moui.View[Msg] {
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
| `text` | `views/views.mbt` | Font/foreground modifiers | Text role through core | `views/views_test.mbt` | Showcase, Markdown Editor | Basic label primitive. |
| `image` | `views/views.mbt` | Modifier-based | Image draw intent | `views/views_test.mbt` | Showcase | Renderer image support is tracked in the capability report; Showcase Interaction Lab covers ready/loading/failed lifecycle states. |
| `icon` | `views/views.mbt` | Modifier-based | Image role through core | `views/views_test.mbt` | Showcase | Icon glyph primitive sized by `IconName`, with optional color/weight overrides. |
| `web_view` | `views/web_view.mbt` | Host native WebView | WebView role through core | `views/views_test.mbt`, WebView Demo app tests | WebView Demo | Controlled native WebView primitive. The composition root creates a `WebViewHost` and `WebViewController`; navigation uses `controller.navigate(url)` and controller tasks cover reload, stop, back, forward, JSON bridge messages, request/response, and disposal. Validated `WebViewEvent` values return through the program effect/subscription path. |
| `canvas` | `views/canvas.mbt` | Modifier-based | Group | `views/views_test.mbt` | Showcase Platform and Diagnostics workspaces | Pure drawing view (`measure` + `draw` with `PaintContext`). No children. See [Canvas and custom paint](canvas-and-custom-paint.md). |
| `custom_layout` / `custom_children_layout` | `views/views.mbt` | N/A | Group / child semantics | `views/views_test.mbt` | PDF Workbench; Markdown Editor surface; Showcase | Custom measure/paint and multi-child layout delegates for advanced controls. |

## Controls

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `button` | `views/button.mbt` | ButtonStyle | Button | `views/views_test.mbt` | All examples | Main activation primitive. |
| `shortcut_button` | `views/button.mbt` | ButtonStyle/surface/text | Button with shortcut description | `views/views_test.mbt` | Showcase Interaction Lab | Composes a regular button, visible shortcut label, `View::keyboard_shortcut`, and shortcut semantics so app-owned keyboard shortcuts stay discoverable and dispatch through the typed message loop. |
| `menu_button` | `views/control_focus_overlay.mbt` | ButtonStyle | Menu | `views/views_test.mbt` | Showcase | Button wrapper with menu semantics. |
| `checkbox` | `views/views.mbt` | ChoiceControlStyle with direct font/color/size overrides | Checkbox | `views/views_test.mbt` | Showcase Todo pattern | TEA-first boolean control. Component-local state should be projected into explicit values and typed `on_change` messages before crossing the public `views` API boundary. |
| `toggle` | `views/control_choice.mbt` | ChoiceControlStyle with direct color overrides | Switch | `views/views_test.mbt` | Showcase | TEA-first switch control. |
| `radio` | `views/control_choice.mbt` | ChoiceControlStyle with direct color overrides | Radio | `views/views_test.mbt` | Showcase | TEA-first single-option primitive. |
| `text_field` | `views/views.mbt`, `views/text_input_controls.mbt` | TextFieldStyle | Text field | `views/views_test.mbt`, core input tests | Showcase, Markdown Editor | TEA-first text input. App, host, smoke, and cross-package tests should use this `views` entrypoint rather than direct core control constructors. |
| `searchbar` | `views/views.mbt`, `views/text_input_controls.mbt` | TextFieldStyle | Search field | `views/views_test.mbt` | Showcase | TEA-first text input specialized for filtering and clear actions. |
| `picker` | `views/views.mbt` | PickerStyle | Picker | `runtime/runtime_control_choices_wbtest.mbt`, `views/views_test.mbt` | Showcase | TEA-first option picker with renderer-neutral popup stacking above later siblings. |
| `datepicker` | `views/datepicker.mbt` | PickerStyle | Date picker | `runtime/runtime_control_choices_wbtest.mbt`, `views/views_test.mbt` | Showcase | TEA-first date picker with Sunday-first calendar popup rendering and min/max range enforcement. |
| `dropdown` / `combobox` / `autocomplete` | `views/popover_selectors.mbt` | ButtonStyle/TextFieldStyle/SurfaceStyle | Expanded menu anchors with selected/disabled option state | `views/views_test.mbt` | Showcase Interaction Lab | Controlled floating menus built from overlays, scroll views, buttons, and text fields. Expansion, selected option, disabled option, and toggle actions are exposed through semantics, while state and filtering remain app-owned. |
| `menu_bar` / `command_menu` / `context_menu_region` | `views/views.mbt` | ButtonStyle/text/surface | Menu/group with selected, disabled, and expanded fallback state | `views/descriptor_helpers_test.mbt`, `views/views_test.mbt` | Showcase Navigation Shell | TEA-first menu surfaces over `menu_item` descriptors and `@views.ActionCommand` metadata. Disabled commands render but do not dispatch, fallback view menus expose expanded/collapse semantics, and native context menus stay in host services. |
| `radio_group` / `checkbox_group` | `views/choice_groups.mbt` | ChoiceControlStyle | Group with radio/checkbox children | `views/views_test.mbt` | Showcase Controls | TEA-first grouped selection built from `ChoiceItem` descriptors. |
| `segmented_control` | `views/choice_segmented.mbt` | ButtonStyle/SurfaceStyle | Tab-like group | `views/views_test.mbt` | Showcase Controls | Controlled single-selection segmented buttons. |
| `chip` / `tag` / `filter_chip` / `choice_chip` | `views/choice_chips.mbt` | SurfaceStyle/ButtonStyle | Button or text roles | `views/views_test.mbt` | Showcase Controls | Compact selection and labeling controls. |
| `slider` | `views/control_slider.mbt` | SliderStyle with direct color overrides, optional `on_change` | Slider | `views/views_test.mbt` | Showcase | Custom painted scalar control with TEA-controlled drag updates through `on_change`; drag mapping uses the declared control width so model rebuilds during a drag do not compound translation. |
| `progress` | `views/control_progress.mbt` | ProgressStyle with direct color overrides | Progress | `views/views_test.mbt` | Showcase | Custom painted progress indicator. |
| `focus_ring` | `views/control_focus_overlay.mbt` | Border/theme | Focusable group with selected state | `views/views_test.mbt` | Showcase Interaction Lab | Visual wrapper for app-owned focus ids. It exposes a focus action plus selected/unselected semantics; use `View::focus_trap` when runtime Tab traversal must stay inside a dialog or popover subtree. |
| `tooltip` | `views/control_focus_overlay.mbt` | SurfaceStyle | Tooltip when visible | `views/views_test.mbt` | Showcase Interaction Lab | Wraps a child with an optional overlay. |
| `View::on_long_press` / `View::on_double_tap` / `View::on_drag` / `View::on_drag_with_frame` | `core/view.mbt` | N/A | Button-like activation metadata | `core/gesture_action_wbtest.mbt`, `core/state_holder_wbtest.mbt`, `views/views_test.mbt` | Showcase Interaction Lab | High-level gesture wrappers over pointer events; recognizer state stays in core/runtime and disabled ancestors suppress activation. `View::on_drag_with_frame` additionally passes the laid-out content frame for frame-relative controlled widgets. |
| `View::transition` / `View::presence` | `core/view.mbt` | N/A | Child semantics preserved while present | `core/animation_wbtest.mbt` | Showcase visual cards | Samples `TransitionSpec` into existing opacity, offset, scale, and foreground modifiers; `presence` keeps exiting content mounted until controlled progress completes and respects reduced motion. |

## Feedback And States

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `ToastQueue` / `ToastQueueItem` | `views/feedback_state.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase Feedback | Pure app-owned state helper for transient notifications. Apps push, expire, and convert queued items into `ToastStackItem` rows while timers and host notifications remain outside `views`. |
| `toast` / `toast_stack` / `snackbar` | `views/feedback_transient.mbt` | FeedbackStyle | Group with optional dismiss action | `views/views_test.mbt` | Showcase Feedback | App-owned transient/status surfaces. `toast_stack` renders an app-owned notification queue with optional per-item action and dismiss messages; `ToastQueue` can supply those rows, while timers stay in the app model. |
| `banner` / `callout` | `views/feedback_guidance.mbt` | FeedbackStyle | Group | `views/views_test.mbt` | Showcase Feedback | Inline status and guidance surfaces with optional action. |
| `progress_status` | `views/feedback_progress.mbt` | FeedbackStyle/ProgressStyle/ButtonStyle/BadgeStyle | Group with nested progress and status badge | `views/views_test.mbt` | Showcase Feedback | App-owned task progress card with title, `status_badge`, message, progress bar, and optional action. The task lifecycle and progress value stay in the app model. |
| `inline_error` | `views/feedback_status.mbt` | FeedbackStyle/BadgeStyle/ButtonStyle | Invalid group | `views/views_test.mbt` | Showcase Feedback | Compact inline error row for app-owned validation or workflow failures outside full state panels. |
| `empty_state` / `loading_state` / `error_state` | `views/feedback_status.mbt` | FeedbackStyle | Group | `views/views_test.mbt` | Showcase Feedback | Reusable workflow state panels using optional `StateViewAction`. |
| `status_badge` / `badge` / `stat_card` | `views/feedback_badge.mbt` | BadgeStyle/FeedbackStyle | Text/group with explicit status labels | `views/views_test.mbt` | Showcase Feedback | `status_badge` wraps compact status text with `Status: ...` accessibility labels and optional detail descriptions. `badge` remains the generic metadata chip, and `stat_card` covers compact metrics. |
| `presence_dot` | `views/views.mbt` | Theme colors | Image role through core | `views/views_test.mbt` | Showcase Data | Fluent 2 PresenceBadge status dot (Available/Away/Busy/Offline/Unknown) as a filled circle with a contrasting border, overlayable on avatars. |
| `drop_zone` / `file_import_panel` | `views/file_import.mbt` | Surface/button/text | Button-like drop target/group | `views/views_test.mbt` | Showcase Interaction Lab | Drag/drop maps through `View::on_file_drop`; browse buttons emit app messages so effect-capable apps can call `AppServices::files().open_file(...)` and map the typed `ServiceTaskResult` through `ServiceTask::effect` without making `views` depend on backend packages. Web hosts may surface browser file names or handles while native hosts can surface filesystem paths. |

## Data Display

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `description_list` | `views/data_display.mbt`, `views/data_display_state.mbt` | Text/theme spacing | Group | `views/views_test.mbt` | Showcase Data | Term/detail metadata rows from `DescriptionItem` descriptors. |
| `data_filter_bar` / `data_filter` | `views/data_filter_bar.mbt`, `views/data_filter_state.mbt` | Search field/chips/ButtonStyle | Group with selected/disabled filter chips | `views/views_test.mbt` | Showcase Data, Data Table | Controlled search/filter toolbar for table and list surfaces. Query, selected filters, result count, and clear policy remain app-owned. |
| `DataSortState` / `PaginationState` / `ColumnVisibilityState` / `ColumnWidthState` / `ColumnOrderState` / `SelectionState` | `views/data_sort_pagination.mbt`, `views/data_table_visibility_state.mbt`, `views/data_table_width_state.mbt`, `views/data_table_order_state.mbt`, `views/data_selection_state.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase Data, Data Table | Pure app-owned helpers for common data workflows: sort toggles, page clamping and slicing bounds, visible/locked columns, clamped column widths, column order, and selected ids. Their storage stays opaque; apps observe and update them through focused methods rather than field access. They intentionally do not own filtering predicates, requests, timers, pointer-specific header gestures, or bulk effects. |
| `DataGridSelectionState` / `DataGridEditState` / `DataGridViewport` / `DataGridFreezePanes` / `IncrementalData` | `views/data_grid_state.mbt`, `views/data_grid_edit_state.mbt`, `views/data_grid_viewport_state.mbt`, `views/data_incremental_state.mbt` | N/A | N/A | `views/complex_data_test.mbt` | N/A | App-owned primitives for spreadsheet-style keyboard range selection, controlled cell drafts and commits, frozen row/column window reuse, and revisioned keyed updates. They do not own application data requests, persistence, focus, or rendering policy. |
| `data_grid_semantics` / `data_grid_row_semantics` / `data_grid_cell_semantics` | `views/data_grid_semantics.mbt` | N/A | Grid, row, and cell collection metadata | `runtime/complex_data_semantics_test.mbt` | Data Table | Attach row/column counts and indexes to custom data views. Runtime tests verify committed semantics rather than modifier-local values. |
| `selection_toolbar` | `views/data_selection_toolbar.mbt` | ButtonStyle/text/surface | Group with selected state | `views/views_test.mbt` | Showcase Data, Data Table | Controlled selected-row summary with `ActionItem` bulk action buttons and optional clear action. Apps usually pass `SelectionState::count()` and keep selected row ids and action effects in the app model. |
| `table` / `table_column` | `views/data_table.mbt`, `views/data_table_rendering.mbt`, `views/data_table_state.mbt` | Surface/text/border/ButtonStyle | Grid with indexed row/cell collection metadata, selectable rows, and optional sortable header buttons | `views/views_test.mbt`, `runtime/complex_data_semantics_test.mbt` | Showcase Data, Data Table | Controlled text table with optional custom cell view, selected row, row-select messages, sortable header state, and empty state; `DataSortState`, `ColumnWidthState`, and `ColumnOrderState` can drive header state, width, and order while sorting rules, filtering, and persistence stay app-owned. |
| `column_visibility_panel` | `views/data_filter_column_visibility.mbt` | Checkbox/text/surface | Group with selected and disabled column items | `views/views_test.mbt` | Showcase Data, Data Table | Controlled column visibility chooser for table workflows. `ColumnVisibilityState` exposes visible and locked ids through accessors; pair it with `ColumnWidthState` and `ColumnOrderState` when a table workflow also needs app-owned resizing and reordering. |
| `selectable_list` | `views/data_selectable_list.mbt`, `views/data_selection_state.mbt` | Surface/text/ButtonStyle | List with selected/disabled list items | `views/descriptor_helpers_test.mbt`, `views/views_test.mbt` | Showcase Data | Controlled application data list built from `selectable_list_item` descriptors, title/subtitle/detail rows, selected id, disabled rows, typed item messages, and an empty state. Filtering, grouping, and selected-id storage stay app-owned. |
| `pagination` | `views/data_pagination.mbt` | ButtonStyle/text | Group with disabled edge buttons | `views/views_test.mbt` | Showcase Data, Data Table | Controlled pagination bar; `PaginationState` can clamp the page and expose slicing bounds, while page indexing and data slicing still stay app-owned. |
| `detail_panel` | `views/data_display.mbt` | Surface/text/ButtonStyle | Group | `views/views_test.mbt` | Showcase Data, Data Table | Compact selected-record details built from `DescriptionItem` rows, optional empty content, and optional action. |
| `tree_view` / `tree_item` | `views/data_tree.mbt`, `views/data_tree_state.mbt` | Button/text | List/list item | `views/views_test.mbt` | Showcase Data | Controlled tree rendering from expanded ids and selected id; toggle/select messages are supplied by the app. |
| `avatar` / `avatar_group` | `views/data_avatar.mbt` | Theme colors/image | Labeled image/text group | `views/views_test.mbt` | Showcase Data | Initials or image avatars plus compact overflow group. |

## Forms

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `form` / `form_section` | `views/form_layout.mbt` | Theme spacing/surface | Group | `views/views_test.mbt` | Showcase Forms | Layout shells for grouped TEA-controlled fields. |
| `form_field` | `views/form_field.mbt`, `views/form_field_support.mbt` | Theme typography/colors | Group with accessibility label | `views/views_test.mbt` | Showcase Forms | Composes label, required marker, helper text, validation message, validating, disabled, and read-only states without renderer changes. `FormFieldStatus::Validating` announces checking state while async validation remains app-owned. |
| `form_field_state` | `views/form/form_field_state.mbt` | Theme typography/colors | Group with accessibility label | `views/form/form_validation_test.mbt` | Showcase Forms | Bridges `@views.FormFieldState` validation into the view helper while preserving direct string-error constructors. |
| `form_validation_summary` | `views/form_validation.mbt` | FormValidationStyle/text/ButtonStyle | Invalid group | `views/views_test.mbt` | Showcase Forms | Renders an app/core-owned `FormValidationSummary` with first-invalid state, field errors, and optional focus/review action. Validation rules and focus orchestration stay outside the view helper. |
| `form_actions` | `views/form_workflow.mbt` | ButtonStyle/surface/text | Group with disabled action state | `views/views_test.mbt` | Showcase Forms | Reusable save/cancel action row with optional status text and app-controlled disabled submit state. Validation and submit policy remain in the app model. |
| `form_workflow_bar` | `views/form_workflow.mbt` | FormValidationStyle/surface/text/ButtonStyle | Group with invalid state | `views/views_test.mbt` | Showcase Forms | Composes validation summary, first-invalid focus action, `FocusScope` Enter/Escape target status, and a submit-guarded action row into one reusable form footer. Actual focus movement remains app/runtime-owned. |
| `form_error` / `form_helper_text` | `views/form_support_text.mbt` | FormValidationStyle/theme typography/colors | Text | `views/views_test.mbt` | Showcase Forms | Reusable support text helpers for app-local form layouts. `form_error` can consume a neutral validation style while `form_helper_text` stays muted-theme text. |
| `input_group` | `views/input_group_shell.mbt` | Theme surface/border | Child semantics | `views/views_test.mbt` | Showcase Forms | Prefix/suffix shell for app-owned inputs. |
| `clearable_text_field` / `password_field` | `views/views.mbt` | TextFieldStyle/ButtonStyle | Text field plus button semantics | `views/views_test.mbt` | Showcase Forms | Controlled wrappers; password reveal state remains app-owned. |
| `number_field` / `stepper` | `views/input_number.mbt` | TextFieldStyle/ButtonStyle | Text field and button semantics | `views/views_test.mbt` | Showcase Forms | Keeps parsing and numeric state in the app model. |
| `text_area` | `views/text_area.mbt` | TextFieldStyle | Text field semantics | `views/views_test.mbt` | Showcase Forms | Fixed-height text area for multi-line layouts without adding an editor engine. |

## Layout And Containers

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `container` / `card` | `views/views.mbt` | SurfaceStyle | Group through child | `views/views_test.mbt` | Counter, Showcase, Markdown Editor | Styled container primitives; `card` is the raised, padded entry point for simple apps. |
| `empty` | `views/views.mbt` | N/A | None | `views/views_test.mbt` | Showcase | Zero-size placeholder leaf for optional/slot composition. |
| `toolbar` / `command_bar` / `button_group` / `status_bar` | `views/toolbar.mbt` | ButtonStyle/text/surface | Group | `views/descriptor_helpers_test.mbt`, `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | App-owned command and status surfaces built from `action_item` descriptors, buttons, text, and surfaces. |
| `command_palette` | `views/views.mbt` | ButtonStyle/text/surface | Menu | `views/views_test.mbt`, `core/gesture_action_wbtest.mbt`, Showcase tests | Showcase Navigation Shell | Renders `@views.ActionCommand` metadata (`group`, `description`, shortcut label, enabled state) as a TEA-controlled palette without native menu or renderer changes. |
| `row` / `column` | `views/views.mbt` | Child/modifier based | Group/list via children | `views/views_test.mbt` | All examples | Flex layout primitives. |
| `center` | `views/views.mbt` | Optional background | Child semantics | `views/views_test.mbt` | Counter | Single-child layout helper that centers content inside its available space. |
| `spacer` | `views/views.mbt` | N/A | None | `views/views_test.mbt` | Showcase | Flexible space primitive. |
| `divider` | `views/views.mbt` | Theme colors/thickness | Separator through core | `views/views_test.mbt` | Showcase | Horizontal/vertical divider line with optional thickness, color, and inset. |
| `frame` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Constraint wrapper. |
| `padding` / `padding_insets` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | All examples | Ordered layout modifier wrappers. |
| `padding_edges` / `padding_xy` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Per-edge and symmetric horizontal/vertical padding convenience wrappers over the same ordered modifier. |
| `stack` / `overlay` | `views/views.mbt` | Child/modifier based | Children preserved | `views/views_test.mbt` | Showcase, Dialog host, Tooltip | Overlay layout primitives. |
| `popover` | `views/popover_overlay.mbt` | SurfaceStyle | Anchor plus optional overlay content | `views/views_test.mbt` | Showcase Interaction Lab | View-level floating overlay using existing stack, align, and container primitives. The optional `trap_focus=true` path applies `View::focus_trap`; by default popovers remain non-modal. Native context menus go through host services. |
| `scroll_view` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | Showcase, Markdown Editor | Emits clip/offset behavior through core and can report wheel deltas through `on_scroll`. |
| `grid` | `views/views.mbt` | N/A | Children preserved | `views/views_test.mbt` | Showcase | Fixed-column layout. |
| `list` | `views/views.mbt` | N/A | List/list item roles through core | `views/views_test.mbt`, `core/semantics_test.mbt` | Showcase Todo pattern | Eager list layout. |
| `lazy_list` | `views/views.mbt` | N/A | List output | `views/views_test.mbt`, `views/windowing_test.mbt`, `views/lazy_list_test.mbt` | Showcase | Windows visible rows from data. Fixed stride `item_height + spacing`; the app owns the scroll offset and feeds it back through `offset`/`on_scroll`. |
| `lazy_grid` | `views/views.mbt` | N/A | List/grid output | `views/views_test.mbt`, `views/windowing_test.mbt`, `views/lazy_grid_test.mbt` | Showcase | Windows visible grid rows from data via the shared `@common.visible_row_window` row model; `overscan` controls the extra rows kept around the viewport. |
| `virtual_list` / `sectioned_list` / `scroll_to_index` | `views/views.mbt`, `views/views.mbt` | N/A | List output | `views/views_test.mbt`, `views/lazy_list_test.mbt`, Showcase tests | Showcase Layout | Overscanned windowed lists, grouped section headers, empty states, and controlled offset intents built on existing scroll/list primitives. Like `lazy_grid`, the list keeps a fixed stride and the app feeds the offset back through `offset`/`on_scroll`. |
| `variable_virtual_list` / `variable_list_metrics` / `scroll_to_key` | `views/data_variable_virtual_list.mbt`, `views/data_variable_list_metrics.mbt`, `views/data_variable_list_anchor.mbt` | N/A | List output | `views/complex_data_test.mbt` | N/A | Variable-height overscanned windowing with keyed metrics, binary visible-range lookup, stable anchor capture/restoration, dynamic height replacement, and keyed scroll intents. The app owns measurements and controlled scroll offset; existing fixed-height `lazy_list` and `virtual_list` behavior is unchanged. |
| `accordion` / `disclosure` / `collapsible_panel` | `views/views.mbt` | ButtonStyle/surface/text | Group | `views/views_test.mbt`, Showcase tests | Showcase Feedback | Controlled disclosure containers; expanded state and toggle behavior stay in the app model. |
| `resizable_panel` | `views/views.mbt` | SurfaceStyle | Group | `views/views_test.mbt`, Showcase tests | Showcase Layout | Controlled-size panel with a visual handle and optional drag callback; the app still owns the size value. |

## Navigation And Presentation

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `navigation_destination` | `views/views.mbt` | N/A | N/A | `views/views_test.mbt` | N/A | Route/view pair for navigation stack. |
| `navigation_stack` / `navigation_stack_selected` | `views/views.mbt` | Child-based | Selected child semantics | `views/views_test.mbt` | N/A | Selects a view from `NavigationState` or a TEA-owned route string. |
| `router_stack` | `views/views.mbt` | Child-based | Selected child semantics | `views/views_test.mbt`, `views/navigation/navigation_routing_test.mbt` | N/A | Selects destinations from `@views.RouterState`, preserving query params and restoration snapshots while staying above the renderer. |
| `@views.RouteHistoryState` / `RouteHistoryEntry` | `views/navigation/navigation_routing.mbt` | N/A | N/A | `views/navigation/navigation_routing_test.mbt`, Showcase tests | Showcase Navigation Shell | App-owned, serializable route/deep-link history with back/forward cursor, forward truncation on new pushes, and `RouterSnapshot` restoration. It does not update browser history or native URL/deep-link handlers by itself. |
| `route_header` | `views/navigation_route_header.mbt` | Surface/text/ButtonStyle | Group | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled page header for app-owned route title, subtitle, and `ActionItem` buttons; routing, deep links, and history stay outside the view helper. |
| `section_nav` | `views/navigation_section_nav.mbt` | ButtonStyle/text/surface | List with selected/disabled list items | `views/descriptor_helpers_test.mbt`, `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled section switcher built from `section_nav_item` descriptors. Apps own the selected id, routing effects, history, and unavailable-section policy. |
| `sidebar` / `breadcrumb` | `views/navigation_sidebar.mbt`, `views/navigation_breadcrumb.mbt` | ButtonStyle/text/surface | List/group | `views/descriptor_helpers_test.mbt`, `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled navigation shell helpers built from `sidebar_item` and `breadcrumb_item` descriptors plus buttons, text, and surface primitives. |
| `split_view` / `master_detail` / `resizable_split_view` | `views/navigation_split.mbt` | Child-based | Group with optional drag handle | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Fixed-width and controlled drag-resizable shell composition for master/detail layouts. `resizable_split_view` emits the clamped primary width through `on_drag`; the app model still owns persistence, snapping, and route-specific pane sizing. |
| `wizard` / `wizard_step` | `views/navigation_presentation.mbt` | ButtonStyle/surface | Group with tab-like step buttons | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Controlled wizard workflow using `WizardStep` descriptors and app-owned current step. |
| `tab_item` | `views/views.mbt` | N/A | N/A | `views/views_test.mbt` | Showcase | Tab descriptor. |
| `tab_view` | `views/views.mbt` | ButtonStyle defaults | Tab buttons | `views/views_test.mbt` | Showcase | TEA-first tab selection. |
| `dialog` | `views/dialog_shell.mbt` | SurfaceStyle/ButtonStyle | Dialog | `views/views_test.mbt`, Showcase tests | Showcase Navigation Shell | Reusable custom-content dialog shell with title, subtitle, optional primary/secondary actions, and optional dismiss action. Pass it to `dialog_host` for view-level presentation; host-modal semantics remain follow-up work. |
| `alert` | `views/dialog_alert.mbt` | SurfaceStyle/ButtonStyle | Dialog | `views/views_test.mbt`, Showcase tests | Showcase | Reusable alert content with primary and optional secondary action; pass it to `dialog_host` for view-level presentation. |
| `dialog_host` | `views/navigation_presentation.mbt` | SurfaceStyle | Dialog when presented | `views/views_test.mbt`, Showcase tests; DSH Desktop | Stack wrapper for modal content with a dim scrim and centered dialog. Optional `on_backdrop` consumes backdrop taps with an app message; omitting it leaves the scrim inert. Presented dialogs apply view-level focus trap by default; pass `trap_focus=false` only for intentionally non-modal preview surfaces. |
| `sheet` / `sheet_host` | `views/views.mbt` | Brush, radius, shadow | Sheet presentation | `views/views_test.mbt` | Showcase | Modal or bottom-sheet presentation with content dismissal support. Presented sheets apply view-level focus trap by default while host-modal deep binding remains platform follow-up work. |

## Theme And Environment

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `theme` | `views/views.mbt` | Creates Theme | N/A | `views/views_test.mbt` | Showcase | Convenience constructor for custom `@moui.Theme` tokens, including palette, spacing, radius, typography, shadow, motion, and surface overrides over an optional base theme. |
| `environment` | `views/views.mbt` | Creates Environment | N/A | `views/views_test.mbt` | Showcase | Runtime environment helper. Showcase Runtime also displays the injected `@host.HostCapabilitySummary` so apps can compare service, input, window, text-input, IME, drag/drop, async-service, and accessibility readiness without depending on renderer packages. |
| `light_theme` / `dark_theme` | `views/views.mbt` | Creates Theme | N/A | `views/views_test.mbt` | Showcase | Convenience theme presets. |
| `default_theme` | `views/views.mbt` | Creates Theme | N/A | `views/views_test.mbt` | Showcase | Neutral fallback theme used when no ambient theme is supplied; `light_theme`/`dark_theme` resolve the Minimal preset over it. |
| `@material.light_theme` / `@carbon.light_theme` / `@primer.light_theme` / `@fluent.light_theme` / package `dark_theme` / `high_contrast_theme` / `system_theme` / package `tokens` / `tokens_for_variant` / `report` / `manifest` / `component_token_matrix` / shared `@common.custom` / `@common.custom_tokens` / `DesignPreset::*_report` shared resolver APIs | `moui_theme/common/*.mbt`, `moui_theme/material/theme.mbt`, `moui_theme/carbon/theme.mbt`, `moui_theme/primer/theme.mbt`, `moui_theme/fluent/theme.mbt` | Creates source-mapped official-system preview Theme values through package entrypoints and exposes shared semantic/component token and report models | N/A | `moui_theme/material/theme_test.mbt`, official-system entrypoint package tests, Design Systems tests | Design Systems example | Optional design-system addon for MoUI. Material, Carbon, Primer, and Fluent are requested through their package-local entrypoints; `moui_theme/common` owns shared token structs, source/golden/coverage/report models, resolver helpers, and generic customization helpers. Current external systems remain source-mapped previews until tests prove full official source import, stable source locks, official-token anchor coverage, token taxonomy parity, semantic palette parity, typography parity, density/variant parity, component-token matrix coverage, runtime token alignment, customization parity, adaptation closure, and golden/source-import integrity. Views still consume only `@moui.Theme` or neutral style contracts. |
| `@sickle.light_theme` / `@sickle.dark_theme` / `@sickle.skeuo_theme` / `@sickle.flat_theme` / `@sickle.hybrid_theme` / `@sickle.palette` | `moui_theme/sickle/theme.mbt` | Creates first-party Sickle Theme values | N/A | `moui_theme/sickle/theme_test.mbt` | Addon package tests | Smartisan-inspired hybrid visual theme with precise desktop skeuomorphism and flat semantic controls. `Hybrid` and `Skeuo` modes use layered surface gradients, stronger shadows, inset text-field focus edges, and metal/cream neutral ramps; `Flat` mode keeps the same Sickle red brand palette while removing depth and shadows. It is a MoUI theme addon, not a source-mapped official design-system preset. |

`DesignPreset::semantic_palette_role_report` lives in
`moui_theme/audit/design_system_semantic_palette.mbt` and breaks the semantic palette down
into foreground/background/surface/primary/status/focus/scrim role rows. The
rows tie each `DesignSemanticPalette` field to a neutral `@core.ColorPalette`
or `@core.SemanticColorScale` destination, direct official token/source-import
coverage when one exists, and explicit role-level parity gaps when a preset only
has a broader token-group adapter.

`DesignPreset::typography_role_report` lives in
`moui_theme/audit/design_system_typography.mbt` and breaks typography down into
body/title/caption/control role rows. The rows tie each
`DesignTypographyTokens` font slot to a neutral `@core.TypographyScale`
destination, direct official token/source-import alignment when one exists,
and explicit destination gaps for imported source properties such as
line-height that do not have a neutral `FontSpec` field yet.

`DesignPreset::component_token_matrix` rows expose per-component mapped and
required token counts plus related pinned source-import and runtime-aligned
coverage counts. Those coverage counts are intentionally separate from the
mapped/required matrix so source-import progress can be shown without claiming
the complete official component matrix is closed.

`DesignSystemTokens::core_component_styles`,
`DesignButtonTokens::core_styles`, `DesignTextFieldTokens::core_styles`,
`DesignSurfaceComponentTokens::core_styles`,
`DesignChoiceControlTokens::core_style`, `DesignProgressTokens::core_style`,
`DesignSliderTokens::core_style`, `DesignPickerTokens::core_style`,
`DesignFeedbackTokens::core_style`, `DesignBadgeTokens::core_style`, and
`DesignFormValidationTokens::core_style` expose component-token overrides as
neutral `@core` style contracts; text-field tokens include the resolved font so
custom design-system token bundles can carry typography into text-field style
conversion without adding design-system names to `core` or `views`. Common
`views` controls, feedback/status surfaces, badges, and validation helpers can
consume those neutral style contracts through optional `style`,
`badge_style`, or `progress_style` parameters while still defaulting to plain
`@moui.Theme`.

## Advanced Helpers

| Constructor | Source | Theme | Semantics | Tests | Example coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `expanded` / `flexible` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Flex child modifiers. |
| `layout_priority` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_test.mbt` | Showcase | Supplies priority metadata to custom layout delegates. |
| `wrap` / `flow` / `responsive_grid` / `baseline_form_rows` | `views/layout_flow.mbt`, `views/views.mbt`, `views/views.mbt` | N/A | Group | `views/views_test.mbt`, Showcase tests | Showcase Layout | Responsive wrapping, adaptive grid columns, and baseline-aligned form rows built with `custom_children_layout`; no renderer changes. |
| `align` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt`, `core/advanced_layout_wbtest.mbt` | Showcase, Dialog host, Tooltip | Places the child within its parent frame using the requested alignment. |
| `aspect_ratio` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Ratio constraint wrapper. |
| `intrinsic_width` / `intrinsic_height` | `views/views.mbt` | N/A | Child semantics | `views/views_test.mbt` | Showcase | Intrinsic measurement wrappers. |
| `custom_layout` | `views/views.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt` | Showcase Advanced Rendering | Builds a custom `View[Msg]`; Showcase uses it to emit layer/blend, filter, shader, path, transform, and opacity draw commands. |
| `custom_children_layout` | `views/views.mbt` | Caller-defined | Caller-defined | `views/views_test.mbt`, `core/advanced_layout_wbtest.mbt` | Showcase | Builds a custom child-layout `View[Msg]` with child size, baseline, priority, and placement callbacks. |
| `component` | `views/views.mbt` | ComponentContext-based | Built child semantics | `views/views_test.mbt` | Examples via app components | Wraps `@core.Component::new`. |

## Maintenance Checklist

When adding or changing a public view constructor:

1. Keep the constructor in `views/` and return `@moui.View[Msg]`.
2. Put reusable concrete custom view behavior in `moui/views`; reuse existing styles, bindings, and modifiers where
   possible.
3. Add or update focused tests in `views/views_test.mbt`.
4. Add Showcase coverage when the view is user-facing and visually meaningful.
5. Update this catalog if API, theme support, semantics, or example coverage
   changes.
6. Run `moon info` after public API changes and review `views/pkg.generated.mbti`.

Do not re-export `ViewNode` from `moui` or `moui/views`, add
`@core.View::primitive_*_view` constructors, `ViewLoweringSink`, or runtime
lowering arms for new widgets.
