///|
struct ForbiddenSourceToken {
  label : String
  token : String
}

///|
fn forbidden_core_control_tokens() -> Array[ForbiddenSourceToken] {
  [
    { label: "empty view", token: "@core.View::empty(" },
    {
      label: "primitive empty view",
      token: "@core.View::primitive_empty_view(",
    },
    { label: "text view", token: "@core.View::text(" },
    { label: "primitive text view", token: "@core.View::primitive_text_view(" },
    { label: "button", token: "@core.View::button(" },
    { label: "primitive button", token: "@core.View::primitive_button_view(" },
    { label: "image", token: "@core.View::image(" },
    { label: "primitive image", token: "@core.View::primitive_image_view(" },
    { label: "web view", token: "@core.View::web_view(" },
    { label: "primitive web view", token: "@core.View::primitive_web_view(" },
    { label: "flex layout", token: "@core.View::flex(" },
    {
      label: "primitive flex layout",
      token: "@core.View::primitive_flex_view(",
    },
    { label: "spacer", token: "@core.View::spacer(" },
    { label: "primitive spacer", token: "@core.View::primitive_spacer_view(" },
    { label: "frame node", token: "@core.View::frame_node(" },
    { label: "primitive frame", token: "@core.View::primitive_frame_view(" },
    { label: "stack layout", token: "@core.View::stack(" },
    {
      label: "primitive stack layout",
      token: "@core.View::primitive_stack_view(",
    },
    { label: "scroll view", token: "@core.View::scroll(" },
    {
      label: "primitive scroll view",
      token: "@core.View::primitive_scroll_view(",
    },
    { label: "grid layout", token: "@core.View::grid(" },
    {
      label: "primitive grid layout",
      token: "@core.View::primitive_grid_view(",
    },
    { label: "list layout", token: "@core.View::list(" },
    {
      label: "primitive list layout",
      token: "@core.View::primitive_list_view(",
    },
    { label: "custom view", token: "@core.View::custom_view(" },
    {
      label: "primitive custom view",
      token: "@core.View::primitive_custom_view(",
    },
    {
      label: "custom children layout",
      token: "@core.View::custom_children_layout(",
    },
    {
      label: "primitive custom children layout",
      token: "@core.View::primitive_custom_children_layout_view(",
    },
    { label: "component", token: "@core.View::component(" },
    {
      label: "primitive component",
      token: "@core.View::primitive_component_view(",
    },
    { label: "checkbox", token: "@core.View::checkbox(" },
    {
      label: "primitive checkbox",
      token: "@core.View::primitive_checkbox_view(",
    },
    { label: "controlled checkbox", token: "@core.View::controlled_checkbox(" },
    {
      label: "primitive controlled checkbox",
      token: "@core.View::primitive_controlled_checkbox_view(",
    },
    { label: "text field", token: "@core.View::text_field(" },
    {
      label: "primitive text field",
      token: "@core.View::primitive_text_field_view(",
    },
    {
      label: "controlled text field",
      token: "@core.View::controlled_text_field(",
    },
    {
      label: "primitive controlled text field",
      token: "@core.View::primitive_controlled_text_field_view(",
    },
    { label: "rich text editor", token: "@core.View::rich_text_editor(" },
    {
      label: "primitive rich text editor",
      token: "@core.View::primitive_rich_text_editor_view(",
    },
    {
      label: "controlled rich text editor",
      token: "@core.View::controlled_rich_text_editor(",
    },
    {
      label: "primitive controlled rich text editor",
      token: "@core.View::primitive_controlled_rich_text_editor_view(",
    },
    { label: "picker", token: "@core.View::picker(" },
    { label: "primitive picker", token: "@core.View::primitive_picker_view(" },
    { label: "controlled picker", token: "@core.View::controlled_picker(" },
    {
      label: "primitive controlled picker",
      token: "@core.View::primitive_controlled_picker_view(",
    },
    { label: "datepicker", token: "@core.View::datepicker(" },
    {
      label: "primitive datepicker",
      token: "@core.View::primitive_datepicker_view(",
    },
    {
      label: "controlled datepicker",
      token: "@core.View::controlled_datepicker(",
    },
    {
      label: "primitive controlled datepicker",
      token: "@core.View::primitive_controlled_datepicker_view(",
    },
    { label: "search bar", token: "@core.View::search_bar(" },
    {
      label: "primitive search bar",
      token: "@core.View::primitive_search_bar_view(",
    },
    {
      label: "controlled search bar",
      token: "@core.View::controlled_search_bar(",
    },
    {
      label: "primitive controlled search bar",
      token: "@core.View::primitive_controlled_search_bar_view(",
    },
  ]
}

///|
fn forbidden_core_program_runtime_source_tokens() -> Array[ForbiddenSourceToken] {
  [
    { label: "program runtime diagnostics", token: "ProgramRuntimeDiagnostics" },
    {
      label: "program message drain loop",
      token: "program_message_drain_limit",
    },
    { label: "program message queue", token: "pending_messages" },
    { label: "effect task lifecycle", token: "start_effect_task(" },
    { label: "subscription lifecycle", token: "sync_subscriptions(" },
    { label: "legacy core runtime kernel", token: "RuntimeKernel" },
  ]
}

///|
fn forbidden_core_program_runtime_source_paths() -> Array[String] {
  [
    "moui/core/program_runtime_diagnostics.mbt", "moui/core/program_runtime_effect_tasks.mbt",
    "moui/core/program_runtime_subscriptions.mbt", "moui/core/runtime_wbtest.mbt",
  ]
}

///|
fn forbidden_core_webview_source_tokens() -> Array[ForbiddenSourceToken] {
  [
    { label: "host-owned WebView spec", token: "type WebViewSpec" },
    { label: "host-owned WebView spec struct", token: "struct WebViewSpec" },
    { label: "host-owned WebView command", token: "enum WebViewCommand" },
    { label: "host-owned WebView event", token: "enum WebViewEvent" },
    {
      label: "host-owned WebView navigation policy",
      token: "enum WebViewNavigationPolicy",
    },
    {
      label: "WebView-specific platform placement helper",
      token: "PlatformViewPlacement::web_view",
    },
    { label: "WebView-specific app event", token: "WebView(String" },
  ]
}

///|
fn forbidden_core_routing_source_tokens() -> Array[ForbiddenSourceToken] {
  [
    { label: "views-owned route location", token: "type RouteLocation" },
    {
      label: "views-owned route location struct",
      token: "struct RouteLocation",
    },
    { label: "views-owned route descriptor", token: "type RouteDescriptor" },
    {
      label: "views-owned route descriptor struct",
      token: "struct RouteDescriptor",
    },
    { label: "views-owned router snapshot", token: "type RouterSnapshot" },
    {
      label: "views-owned router snapshot struct",
      token: "struct RouterSnapshot",
    },
    { label: "views-owned route history", token: "type RouteHistoryState" },
    {
      label: "views-owned route history struct",
      token: "struct RouteHistoryState",
    },
    { label: "views-owned route focus store", token: "type RouteFocusStore" },
    {
      label: "views-owned route focus store struct",
      token: "struct RouteFocusStore",
    },
    { label: "views-owned router state", token: "type RouterState" },
    { label: "views-owned router state struct", token: "struct RouterState" },
    { label: "views-owned route resolver", token: "resolve_route(" },
  ]
}

///|
fn forbidden_core_runtime_boundary_source_tokens() -> Array[
  ForbiddenSourceToken,
] {
  [
    { label: "app runtime owner", token: "type AppRuntime" },
    { label: "app runtime constructor", token: "AppRuntime::new_" },
    { label: "legacy runtime kernel", token: "RuntimeKernel" },
    { label: "runtime state owner", token: "RuntimeState" },
    { label: "runtime element node", token: "ElementNode" },
    { label: "runtime element tree", token: "ElementTree" },
    { label: "runtime render node", token: "RenderNode" },
    { label: "runtime dirty flags", token: "DirtyFlags" },
    { label: "legacy lowering sink", token: "ViewLoweringSink" },
    {
      label: "legacy runtime lowering entry",
      token: "View::lower_for_runtime(",
    },
    {
      label: "legacy primitive constructor",
      token: "View::primitive_button_view(",
    },
    { label: "legacy view spec enum", token: "enum ViewSpec" },
    { label: "legacy view spec type", token: "type ViewSpec" },
    { label: "legacy text view spec constructor", token: "ViewSpec::TextSpec" },
    {
      label: "legacy button view spec constructor",
      token: "ViewSpec::ButtonSpec",
    },
    { label: "legacy flex view spec constructor", token: "ViewSpec::FlexSpec" },
    { label: "legacy realized view return", token: "-> ViewSpec" },
    { label: "legacy realized view parameter", token: ": ViewSpec" },
    { label: "legacy realized view children", token: "Array[ViewSpec]" },
    { label: "legacy view realization", token: "realize_view(" },
    { label: "legacy view node realization", token: "realize_view_node(" },
  ]
}

///|
fn forbidden_core_runtime_boundary_source_paths() -> Array[String] {
  [
    "moui/core/element.mbt", "moui/core/element_reconcile.mbt", "moui/core/element_reconcile_dirty.mbt",
    "moui/core/element_tree.mbt", "moui/core/input_drag_drop.mbt", "moui/core/input_focus.mbt",
    "moui/core/input_keyboard.mbt", "moui/core/input_pointer.mbt", "moui/core/input_text_dispatch.mbt",
    "moui/core/input_web_view.mbt", "moui/core/layout_engine.mbt", "moui/core/paint_controls.mbt",
    "moui/core/paint_engine.mbt", "moui/core/paint_popup_controls.mbt", "moui/core/paint_text_controls.mbt",
    "moui/core/render_tree.mbt", "moui/core/runtime_events.mbt", "moui/core/runtime_render_pipeline.mbt",
    "moui/core/runtime_state.mbt", "moui/core/taffy_layout.mbt", "moui/core/text_editing_fields.mbt",
    "moui/core/view_realize.mbt", "moui/core/view_spec_ops.mbt",
  ]
}
