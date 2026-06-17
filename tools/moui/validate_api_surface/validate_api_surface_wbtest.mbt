///|
test "line count ignores trailing generated blank lines" {
  inspect(line_count(""), content="0")
  inspect(line_count("one"), content="1")
  inspect(line_count("one\n"), content="1")
  inspect(line_count("one\n\n"), content="1")
  inspect(line_count("one\ntwo"), content="2")
  inspect(line_count("one\ntwo\n\n"), content="2")
}

///|
fn budget_by_label(label : String) -> PackageBudget raise {
  for budget in package_budgets() {
    if budget.label == label {
      return budget
    }
  }
  fail("missing package budget: " + label)
}

///|
test "root facade budget keeps runtime diagnostics and theme builders out" {
  let root = budget_by_label("root facade")
  inspect(root.max_lines, content="125")
  inspect(root.max_pub_lines, content="40")
  inspect(root.max_pub_all_lines, content="0")
  inspect(root_facade_app_safe_aliases().length(), content="37")
  assert_true(root.required_tokens.contains("pub using @core {type View}"))
  assert_true(root.required_tokens.contains("pub using @core {type Program}"))
  assert_true(root.required_tokens.contains("pub using @core {type Binding}"))
  assert_true(root.required_tokens.contains("pub using @core {type Color}"))
  assert_true(root.required_tokens.contains("pub using @core {type DateValue}"))
  assert_true(
    root.forbidden_tokens.contains("pub using @core {type AppRuntime}"),
  )
  assert_true(
    root.forbidden_tokens.contains("pub using @core {type WidgetOps}"),
  )
  assert_true(
    root.forbidden_tokens.contains("pub using @core {type WebViewEvent}"),
  )
  assert_true(
    root.forbidden_tokens.contains("pub using @core {type RichTextDocument}"),
  )
  assert_true(root.forbidden_tokens.contains("DrawCommand"))
  assert_true(root.forbidden_tokens.contains("ProgramRuntimeSnapshot"))
  assert_true(root.forbidden_tokens.contains("pub fn light_theme("))
  assert_true(root.forbidden_tokens.contains("pub fn theme("))
}

///|
test "runtime facade budget pins the opaque runtime boundary" {
  let runtime = budget_by_label("runtime facade")
  inspect(runtime.max_lines, content="307")
  inspect(runtime.max_pub_lines, content="42")
  inspect(runtime.max_pub_all_lines, content="17")
  assert_true(runtime.required_tokens.contains("pub struct AppRuntime"))
  assert_true(runtime.required_tokens.contains("pub fn[Msg] new_view("))
  assert_true(
    runtime.required_tokens.contains(
      "pub fn[Model, Msg] new_program_with_dimensions(",
    ),
  )
  assert_true(
    runtime.required_tokens.contains(
      "pub fn[Model, Msg] AppRuntime::new_program(",
    ),
  )
  assert_true(
    runtime.required_tokens.contains(
      "pub fn AppRuntime::inspector_snapshot(Self) -> InspectorSnapshot",
    ),
  )
  assert_true(
    runtime.required_tokens.contains(
      "pub fn AppRuntime::program_runtime_snapshot(Self) -> ProgramRuntimeSnapshot",
    ),
  )
  assert_true(
    runtime.required_tokens.contains("pub(all) struct InspectorSnapshot"),
  )
  assert_true(
    runtime.required_tokens.contains("pub(all) struct ProgramRuntimeSnapshot"),
  )
  assert_true(
    runtime.required_tokens.contains("pub(all) struct RuntimeInspectorSnapshot"),
  )
  assert_true(runtime.forbidden_tokens.contains("RuntimeState"))
  assert_true(runtime.forbidden_tokens.contains("inner : @core.AppRuntime"))
  assert_true(runtime.forbidden_tokens.contains("core_inspector_snapshot"))
  assert_true(runtime.forbidden_tokens.contains("@core.InspectorSnapshot"))
  assert_true(runtime.forbidden_tokens.contains("@core.ProgramRuntimeSnapshot"))
}

///|
test "backend runtime interface guard covers native providers" {
  let paths = backend_runtime_interface_paths()
  inspect(paths.length(), content="11")
  assert_true(paths.contains("moui/backend/host/pkg.generated.mbti"))
  assert_true(paths.contains("moui/backend/web/pkg.generated.mbti"))
  assert_true(paths.contains("moui/backend/macos/skia/pkg.generated.mbti"))
  assert_true(paths.contains("moui/backend/windows/wgpu/pkg.generated.mbti"))
  assert_true(paths.contains("moui/backend/linux/pkg.generated.mbti"))
}

///|
test "shared app runtime import guard ignores test-only imports" {
  inspect(max_shared_app_runtime_imports(), content="1")
  assert_true(
    allowed_shared_app_runtime_imports().contains(
      "examples/showcase/app/moon.pkg",
    ),
  )
  let default_import =
    #|import {
    #|  "wzzc-dev/moui",
    #|  "wzzc-dev/moui/runtime",
    #|}
    #|
  assert_true(
    moon_pkg_has_default_import(default_import, "\"wzzc-dev/moui/runtime\""),
  )
  let test_only_import =
    #|import {
    #|  "wzzc-dev/moui",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|} for "test"
    #|
  assert_false(
    moon_pkg_has_default_import(test_only_import, "\"wzzc-dev/moui/runtime\""),
  )
}

///|
test "shared app core import guard tracks default imports" {
  inspect(max_shared_app_core_imports(), content="5")
  let default_import =
    #|import {
    #|  "wzzc-dev/moui",
    #|  "wzzc-dev/moui/core",
    #|}
    #|
  assert_true(
    moon_pkg_has_default_import(default_import, "\"wzzc-dev/moui/core\""),
  )
  let test_only_import =
    #|import {
    #|  "wzzc-dev/moui",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/core",
    #|} for "test"
    #|
  assert_false(
    moon_pkg_has_default_import(test_only_import, "\"wzzc-dev/moui/core\""),
  )
}

///|
test "views facade exposes control-specific contracts" {
  let views = budget_by_label("views facade")
  inspect(views.max_lines, content="980")
  inspect(views.max_pub_lines, content="370")
  inspect(views_facade_core_alias_tokens().length(), content="8")
  inspect(views_facade_widget_alias_tokens().length(), content="8")
  inspect(views_facade_host_alias_tokens().length(), content="2")
  let required = views.required_tokens
  assert_true(required.contains("\"wzzc-dev/moui/backend/host\""))
  assert_true(required.contains("\"wzzc-dev/moui/widget\""))
  assert_true(required.contains("pub using @core {type ActionCommand}"))
  assert_true(required.contains("pub using @core {type ActionCommandMap}"))
  assert_true(required.contains("pub using @core {type CommandBinding}"))
  assert_true(required.contains("pub using @core {type Color}"))
  assert_true(required.contains("pub using @core {type ColorScheme}"))
  assert_true(required.contains("pub using @core {type CommandIntent}"))
  assert_true(required.contains("pub using @core {type KeyModifiers}"))
  assert_true(required.contains("pub using @core {type KeyboardShortcut}"))
  assert_true(required.contains("pub(all) struct ButtonStyle"))
  assert_true(required.contains("pub(all) struct FormFieldState"))
  assert_false(required.contains("pub using @core {type ButtonStyle}"))
  assert_false(required.contains("pub using @core {type TextFieldStyle}"))
  assert_false(required.contains("pub using @core {type PickerItem}"))
  assert_false(required.contains("pub using @core {type FormFieldState}"))
  assert_false(
    required.contains("pub using @core {type FormValidationSummary}"),
  )
  assert_true(required.contains("pub using @widget {type RichTextDocument}"))
  assert_true(
    required.contains("pub using @widget {type RichTextInputTransform}"),
  )
  assert_true(
    required.contains(
      "pub type RichTextFormatter = (String) -> @widget.RichTextDocument",
    ),
  )
  assert_false(required.contains("pub using @core {type RichTextDocument}"))
  assert_true(required.contains("pub(all) struct RouteLocation"))
  assert_true(required.contains("pub(all) struct RouteHistoryState"))
  assert_true(required.contains("type RouteFocusStore"))
  assert_true(required.contains("type RouterState"))
  assert_false(required.contains("pub using @core {type RouteHistoryState}"))
  assert_false(required.contains("pub using @core {type RouteLocation}"))
  assert_false(required.contains("pub using @core {type WebViewEvent}"))
  assert_true(required.contains("pub using @host {type WebViewEvent}"))
  assert_true(
    required.contains("pub using @host {type WebViewNavigationPolicy}"),
  )
  assert_true(required.contains("pub fn rich_text_document_height("))
}

///|
test "core descriptor payloads stay opaque" {
  let core = budget_by_label("core")
  inspect(core.max_lines, content="1904")
  inspect(core.max_pub_lines, content="552")
  inspect(core.max_pub_all_lines, content="151")
  assert_true(core.required_tokens.contains("pub struct WidgetOps[Msg]"))
  assert_true(core.required_tokens.contains("View::widget"))
  assert_true(core.required_tokens.contains("WidgetOps::new"))
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct EffectDescriptor"),
  )
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct SubscriptionDescriptor"),
  )
  assert_true(core.forbidden_tokens.contains("type RuntimeState"))
  assert_true(core.forbidden_tokens.contains("type RuntimeKernel"))
  assert_true(core.forbidden_tokens.contains("RuntimeKernel::"))
  assert_true(core.forbidden_tokens.contains("type ViewNode["))
  assert_true(core.forbidden_tokens.contains("ViewLoweringSink"))
  assert_true(core.forbidden_tokens.contains("View::lower_for_runtime("))
  assert_true(core.forbidden_tokens.contains("View::primitive_button_view("))
  assert_true(
    core.forbidden_tokens.contains(
      "View::primitive_controlled_text_field_view(",
    ),
  )
  assert_true(core.forbidden_tokens.contains("type ViewSpec"))
  assert_true(core.forbidden_tokens.contains("type ElementNode"))
  assert_true(core.forbidden_tokens.contains("type ElementTree"))
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct InspectorSnapshot"),
  )
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct ProgramRuntimeSnapshot"),
  )
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct RuntimeInspectorSnapshot"),
  )
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct RenderInspectorSnapshot"),
  )
  assert_true(core.forbidden_tokens.contains("type FrameProfile"))
  assert_true(
    core.forbidden_tokens.contains("InspectorSnapshot::from_runtime("),
  )
  assert_true(
    core.forbidden_tokens.contains("RuntimeInspectorSnapshot::from_runtime("),
  )
  assert_true(core.forbidden_tokens.contains("RouteFocusStore::restore("))
}

///|
test "core legacy families are ratcheted toward existing layers" {
  let budgets = legacy_core_family_budgets()
  inspect(budgets.length(), content="6")
  for budget in budgets {
    inspect(budget.target_occurrences, content="0")
  }
  let labels = budgets.map(budget => budget.label)
  assert_true(labels.contains("control styles and picker model"))
  assert_true(labels.contains("form workflow helpers"))
  assert_true(labels.contains("rich text editor domain model"))
  assert_true(labels.contains("WebView platform service model"))
  assert_true(labels.contains("routing and history controller"))
  assert_true(labels.contains("runtime diagnostics snapshots"))
  let control = budgets[0]
  inspect(control.max_occurrences, content="0")
  assert_true(control.tokens.contains("ButtonStyle"))
  assert_true(control.tokens.contains("PickerItem"))
  let form = budgets[1]
  inspect(form.max_occurrences, content="0")
  let rich_text = budgets[2]
  inspect(rich_text.max_occurrences, content="0")
  let webview = budgets[3]
  inspect(webview.max_occurrences, content="0")
  assert_true(webview.tokens.contains("WebViewEvent"))
  assert_true(webview.tokens.contains("PlatformViewPlacement::web_view"))
  let routing = budgets[4]
  inspect(routing.max_occurrences, content="0")
  assert_true(routing.tokens.contains("RouteHistoryState"))
  assert_true(routing.tokens.contains("resolve_route"))
  let diagnostics = budgets[5]
  inspect(diagnostics.max_occurrences, content="0")
  assert_true(diagnostics.tokens.contains("ProgramRuntimeSnapshot"))
}

///|
test "core program runtime ownership guard covers moved implementation" {
  let tokens = forbidden_core_program_runtime_source_tokens().map(rule => {
    rule.token
  })
  assert_true(tokens.contains("ProgramRuntimeDiagnostics"))
  assert_true(tokens.contains("program_message_drain_limit"))
  assert_true(tokens.contains("pending_messages"))
  assert_true(tokens.contains("start_effect_task("))
  assert_true(tokens.contains("sync_subscriptions("))
  assert_true(tokens.contains("RuntimeKernel"))
  let paths = forbidden_core_program_runtime_source_paths()
  assert_true(paths.contains("moui/core/program_runtime_diagnostics.mbt"))
  assert_true(paths.contains("moui/core/program_runtime_effect_tasks.mbt"))
  assert_true(paths.contains("moui/core/program_runtime_subscriptions.mbt"))
  assert_true(paths.contains("moui/core/runtime_wbtest.mbt"))
}

///|
test "core WebView ownership guard points at host-owned API" {
  let tokens = forbidden_core_webview_source_tokens().map(rule => rule.token)
  assert_true(tokens.contains("type WebViewSpec"))
  assert_true(tokens.contains("enum WebViewCommand"))
  assert_true(tokens.contains("enum WebViewEvent"))
  assert_true(tokens.contains("enum WebViewNavigationPolicy"))
  assert_true(tokens.contains("PlatformViewPlacement::web_view"))
  assert_true(tokens.contains("WebView(String"))
}

///|
test "core routing ownership guard points at views-owned API" {
  let tokens = forbidden_core_routing_source_tokens().map(rule => rule.token)
  assert_true(tokens.contains("type RouteLocation"))
  assert_true(tokens.contains("struct RouteHistoryState"))
  assert_true(tokens.contains("type RouteFocusStore"))
  assert_true(tokens.contains("struct RouterState"))
  assert_true(tokens.contains("resolve_route("))
}

///|
test "core runtime boundary guard covers moved implementation" {
  let tokens = forbidden_core_runtime_boundary_source_tokens().map(rule => {
    rule.token
  })
  assert_true(tokens.contains("type AppRuntime"))
  assert_true(tokens.contains("AppRuntime::new_"))
  assert_true(tokens.contains("RuntimeKernel"))
  assert_true(tokens.contains("RuntimeState"))
  assert_true(tokens.contains("ElementNode"))
  assert_true(tokens.contains("ElementTree"))
  assert_true(tokens.contains("RenderNode"))
  assert_true(tokens.contains("DirtyFlags"))
  assert_true(tokens.contains("enum ViewSpec"))
  assert_true(tokens.contains("ViewSpec::FlexSpec"))
  assert_true(tokens.contains("ViewLoweringSink"))
  assert_true(tokens.contains("View::lower_for_runtime("))
  assert_true(tokens.contains("View::primitive_button_view("))
  assert_true(tokens.contains("realize_view("))
  let paths = forbidden_core_runtime_boundary_source_paths()
  assert_true(paths.contains("moui/core/element.mbt"))
  assert_true(paths.contains("moui/core/runtime_state.mbt"))
  assert_true(paths.contains("moui/core/runtime_render_pipeline.mbt"))
  assert_true(paths.contains("moui/core/view_realize.mbt"))
  assert_true(paths.contains("moui/core/view_spec_ops.mbt"))
}

///|
test "shared app core import budget is an explicit advanced-app allowlist" {
  let allowed = allowed_shared_app_core_imports()
  inspect(max_shared_app_core_imports(), content="5")
  inspect(allowed.length(), content="5")
  assert_true(allowed.contains("examples/markdown_editor/app/moon.pkg"))
  assert_true(allowed.contains("examples/mo_workbench/app/moon.pkg"))
  assert_true(allowed.contains("examples/pdf_workbench/app/moon.pkg"))
  assert_true(allowed.contains("examples/showcase/app/moon.pkg"))
  assert_true(allowed.contains("website/app/moon.pkg"))
}

///|
test "core view construction is reserved for views facade consumers" {
  inspect(core_control_consumer_roots().contains("moui/views"), content="false")
  inspect(runtime_consumer_roots().contains("moui/views"), content="true")
  let tokens = forbidden_core_control_tokens().map(rule => rule.token)
  inspect(tokens.length(), content="54")
  assert_true(tokens.contains("@core.View::empty("))
  assert_true(tokens.contains("@core.View::button("))
  assert_true(tokens.contains("@core.View::component("))
  assert_true(tokens.contains("@core.View::controlled_text_field("))
  assert_true(tokens.contains("@core.View::controlled_search_bar("))
  assert_true(tokens.contains("@core.View::primitive_button_view("))
  assert_true(tokens.contains("@core.View::primitive_web_view("))
  assert_true(
    tokens.contains("@core.View::primitive_controlled_text_field_view("),
  )
}

///|
test "views return rules cover app-facing constructors" {
  let names = view_return_rules().map(rule => rule.name)
  assert_true(names.contains("button"))
  assert_true(names.contains("column"))
  assert_true(names.contains("text_field"))
  assert_true(names.contains("markdown_editor"))
  assert_true(names.contains("navigation_stack"))
  assert_true(names.contains("web_view"))
  for rule in view_return_rules() {
    inspect(rule.return_token, content="-> @core.View[Msg]")
  }
}
