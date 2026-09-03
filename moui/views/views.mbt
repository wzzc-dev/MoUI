///|
/// Facade for the `@views` namespace. Implementations live in sub-packages
/// (button/, container/, controls/, data/, form/, layout/, navigation/,
/// popover/, style/, text/, ...); this file re-exports their public API so
/// downstream callers see a single `@views` namespace.

// === primitives ===

///|
pub using @button {button, shortcut_button}

///|
pub using @canvas {canvas, animated_canvas}

///|
pub using @container {container, card, center, empty, spacer}

///|
pub using @checkbox {checkbox, checkbox_control}

///|
pub using @divider {divider}

///|
pub using @image {image}

///|
pub using @icon {icon}

///|
pub using @text {text, text_field, text_area}

///|
pub using @controls {clearable_text_field, password_field}

///|
pub using @presence_dot {type PresenceStatus, presence_dot}

///|
/// Re-export DateValue from common.
pub using @common {type DateValue}

///|
/// Drawing helpers operating on the `@common.PaintContext` type.
pub using @common {
  clear,
  fill_rect,
  stroke_rect,
  fill_rounded_rect,
  stroke_rounded_rect,
  draw_shadow,
  draw_text,
  draw_image,
  draw_path,
  draw_shader_effect,
  push_clip,
  pop_clip,
  push_rounded_clip,
  pop_rounded_clip,
  push_transform,
  pop_transform,
  push_opacity,
  pop_opacity,
  push_layer,
  pop_layer,
  push_filter,
  pop_filter,
}

// === layout ===

///|
pub using @layout {row, column}

///|
pub using @layout {stack}

///|
pub using @navigation {overlay_marker}

///|
pub using @core {type DragGestureEvent, type DragGesturePhase}

///|
pub using @layout {frame}

///|
pub using @layout {grid, list}

///|
pub using @presentation {
  overlay_host,
  popup_host,
  type PresentationSpec,
  type PresentationAnchor,
  type PresentationDismissPolicy,
  type PresentationHostPolicy,
  type PresentationKind,
  type PresentationModality,
  type PresentationPlacement,
  type PresentationPlacementCandidate,
  type PresentationTransition,
}

///|
pub using @layout {padding, padding_xy, padding_edges, padding_insets}

///|
pub using @layout {type SectionListSection, type ScrollToIndexIntent}

///|
/// Layout/scroll helper entrypoints implemented in `controls/` (they compose
/// `@controls` primitives such as `scroll_container`).
pub using @controls {
  expanded,
  flexible,
  layout_priority,
  align,
  rounded_clip,
  aspect_ratio,
  intrinsic_width,
  intrinsic_height,
  custom_children_layout,
  scroll_view,
  responsive_grid,
  lazy_grid,
  lazy_list,
  virtual_list,
  scroll_to_index,
  sectioned_list,
}

// === interactive controls ===

///|
pub using @controls {toolbar, button_group, command_bar, status_bar}

///|
pub using @controls {chip, tag, filter_chip, choice_chip}

///|
pub using @controls {choice_item, radio_group, checkbox_group}

///|
pub using @controls {segmented_control}

///|
pub using @controls {type ChoiceItem}

///|
pub using @controls {focus_ring, menu_button, tooltip}

///|
pub using @controls {custom_layout}

///|
pub using @controls {alert}

///|
pub using @controls {dialog}

///|
pub using @controls {disclosure, accordion, collapsible_panel, resizable_panel}

///|
pub using @controls {input_group}

///|
pub using @controls {number_field, stepper}

///|
pub using @controls {picker, picker_item}

///|
pub using @controls {searchbar}

///|
/// Aggregate facade for the choice/ progress/ slider sub-packages (merged
/// from control_choice.mbt / control_progress.mbt / control_slider.mbt).
pub using @checkbox {toggle, radio}

///|
pub using @progress {progress}

///|
pub using @slider {slider}

// === composite / domain views ===

///|
/// Aggregate facade for the data/ sub-package (merged from the per-file
/// data_*.mbt facades).
pub using @data {
  avatar,
  avatar_group,
  column_visibility_panel,
  data_filter,
  data_filter_bar,
  data_grid_cell,
  data_grid_cell_key,
  data_grid_cell_semantics,
  data_grid_freeze_panes,
  data_grid_row_semantics,
  data_grid_semantics,
  data_grid_viewport,
  description_item,
  description_list,
  detail_panel,
  pagination,
  selectable_list,
  selectable_list_item,
  selection_toolbar,
  table,
  table_column,
  tree_item,
  tree_view,
  variable_list_metrics,
  variable_virtual_list,
  scroll_to_key,
  type ColumnOrderState,
  type ColumnVisibilityState,
  type ColumnWidthState,
  type DataFilter,
  type DataGridCell,
  type DataGridEditCommit,
  type DataGridEditState,
  type DataGridFreezePanes,
  type DataGridSelectionRange,
  type DataGridSelectionState,
  type DataGridViewport,
  type DataSortState,
  type DescriptionItem,
  type PaginationState,
  type SelectableListItem,
  type SelectionState,
  type TableColumn,
  type TreeItem,
  type IncrementalData,
  type IncrementalDataChange,
  type VariableListAnchor,
  type VariableListMetrics,
  type VariableListRange,
}

///|
pub using @feedback {
  empty_state,
  loading_state,
  error_state,
  inline_error,
  toast,
  toast_stack,
  snackbar,
  progress_status,
  banner,
  callout,
  badge,
  status_badge,
  stat_card,
  type ToastStackItem,
  type ToastQueueItem,
  type ToastQueue,
}

///|
pub using @controls {type StateViewAction}

///|
/// Aggregate facade for the form/ sub-package (merged from the per-file
/// form_*.mbt / datepicker.mbt facades).
pub using @form {
  datepicker,
  drop_zone,
  file_import_panel,
  form,
  form_actions,
  form_error,
  form_field,
  form_field_state,
  form_helper_text,
  form_section,
  form_validation_summary,
  form_workflow_bar,
  required_field,
  validate_form,
  baseline_form_rows,
  type BaselineFormRow,
  type FileImportAvailability,
  type FileSelection,
  type FormController,
  type FormFieldError,
  type FormFieldLayout,
  type FormFieldState,
  type FormFieldStatus,
  type FormValidationDisplay,
  type FormValidationResult,
  type FormValidationRule,
  type FormValidationSummary,
}

///|
/// Aggregate facade for the navigation/ sub-package (merged from the per-file
/// navigation_*.mbt facades).
pub using @navigation {
  action_item,
  breadcrumb,
  breadcrumb_item,
  command_menu_section,
  master_detail,
  menu_item,
  navigation_destination,
  navigation_stack_selected,
  resizable_split_view,
  resolve_route,
  route_header,
  router_stack,
  section_nav,
  section_nav_item,
  sidebar,
  sidebar_item,
  split_view,
  tab_item,
  tab_view,
  wizard,
  wizard_step,
  command_palette,
  menu_bar,
  command_menu,
  context_menu_region,
  type ActionItem,
  type BreadcrumbItem,
  type CommandMenuSection,
  type MenuItem,
  type NavigationDestination,
  type RouteDescriptor,
  type RouteFocusStore,
  type RouteHistoryEntry,
  type RouteHistoryState,
  type RouteLocation,
  type RouteParam,
  type RouteQueryParam,
  type RouterSnapshot,
  type RouterState,
  type SectionNavItem,
  type SidebarItem,
  type TabItem,
  type WizardStep,
}

///|
/// Aggregate facade for the popover/ sub-package (merged from the per-file
/// popover_*.mbt facades).
pub using @popover {
  autocomplete,
  combobox,
  dropdown,
  sheet,
  type DropdownState,
  type PopoverPlacement,
}

///|
/// Command types re-exported from core for the menu/command entrypoints.
pub using @core {
  type ActionCommand,
  type ActionCommandMap,
  type CommandBinding,
  type CommandIntent,
  type KeyModifiers,
  type KeyboardShortcut,
}

// === style / theme ===

///|
/// Style types and helpers live in the `style/` sub-package; this facade
/// re-exports them so downstream callers see a single `@views` namespace.
pub using @style {
  type ButtonVariant,
  type ButtonStyle,
  type ControlStateStyle,
  type ProgressStyle,
  type SliderStyle,
  type TextFieldVariant,
  type ContainerVariant,
  type TextRole,
  type MainAlign,
  type CrossAlign,
  type ChipVariant,
  type SegmentedControlSize,
  type FeedbackTone,
  type BadgeTone,
  type SheetPresentationMode,
  type DatePickerMode,
  type TextStyle,
  type SurfaceStyle,
  type TextFieldStyle,
  type ChoiceControlStyle,
  type PickerStyle,
  type ToneStyle,
  type FeedbackStyle,
  type BadgeStyle,
  type FormValidationStyle,
  type PickerItem,
  type ButtonVariantToken,
  type ControlThemeSet,
  type ControlStateTokens,
  type ButtonTheme,
  type StateLayerTokens,
  type TextFieldAppearance,
  type TextFieldTheme,
  type SurfaceTheme,
  type ChoiceControlShape,
  type CheckMarkStyle,
  type ThumbShape,
  type ChoiceControlTheme,
  type ProgressTheme,
  type SliderTheme,
  type PickerTheme,
  type ToneTokens,
  type FeedbackTheme,
  type BadgeTheme,
  type FormValidationTheme,
  type IconName,
}

///|
pub using @style {minimal_control_theme_set, new_control_state_style}

///|
pub using @style {type ColorPalette, type TypographyScale}

///|
pub using @style {light_theme, dark_theme, default_theme, theme, environment}

///|
pub using @common {type PaintContext}
