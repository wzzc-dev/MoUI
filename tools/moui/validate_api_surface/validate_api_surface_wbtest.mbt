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
fn classification_budget(
  path : String,
  category : String,
) -> ApiSurfaceCategoryBudget raise {
  for budget in api_surface_classification_budgets() {
    if budget.path == path && budget.category == category {
      return budget
    }
  }
  fail("missing classification budget: " + path + " " + category)
}

///|
test "api surface semantic categories cover public surface tiers" {
  let categories = api_surface_semantic_categories()
  inspect(categories.length(), content="10")
  assert_true(categories.contains("app_constructor"))
  assert_true(categories.contains("app_state_helper"))
  assert_true(categories.contains("app_style"))
  assert_true(categories.contains("advanced_core_protocol"))
  assert_true(categories.contains("runtime_diagnostic"))
  assert_true(categories.contains("host_contract"))
  assert_true(categories.contains("renderer_contract"))
  assert_true(categories.contains("required_protocol"))
  assert_true(categories.contains("test_exposure"))
  assert_true(categories.contains("migration_debt"))
  let paths = api_surface_classification_paths()
  inspect(paths.length(), content="5")
  assert_true(paths.contains("moui/core/pkg.generated.mbti"))
  assert_true(paths.contains("moui/views/pkg.generated.mbti"))
  assert_true(paths.contains("moui/runtime/pkg.generated.mbti"))
  assert_true(paths.contains("moui/backend/host/pkg.generated.mbti"))
  assert_true(paths.contains("moui/render/pkg.generated.mbti"))
  inspect(
    paths.contains("moui/backend/internal/mobile_runtime/pkg.generated.mbti"),
    content="false",
  )
}

///|
test "api surface classification budgets pin current high-risk packages" {
  inspect(
    classification_budget(
      "moui/core/pkg.generated.mbti", "advanced_core_protocol",
    ).max_count,
    content="523",
  )
  inspect(
    classification_budget("moui/core/pkg.generated.mbti", "required_protocol").max_count,
    content="139",
  )
  inspect(
    classification_budget("moui/views/pkg.generated.mbti", "app_constructor").max_count,
    content="134",
  )
  inspect(
    classification_budget("moui/views/pkg.generated.mbti", "app_state_helper").max_count,
    content="300",
  )
  inspect(
    classification_budget("moui/views/pkg.generated.mbti", "app_style").max_count,
    content="210",
  )
  inspect(
    classification_budget(
      "moui/views/pkg.generated.mbti", "advanced_core_protocol",
    ).max_count,
    content="40",
  )
  inspect(
    classification_budget("moui/views/pkg.generated.mbti", "migration_debt").max_count,
    content="0",
  )
  inspect(
    classification_budget(
      "moui/runtime/pkg.generated.mbti", "runtime_diagnostic",
    ).max_count,
    content="285",
  )
  inspect(
    classification_budget(
      "moui/backend/host/pkg.generated.mbti", "host_contract",
    ).max_count,
    content="470",
  )
  inspect(
    classification_budget("moui/render/pkg.generated.mbti", "renderer_contract").max_count,
    content="150",
  )
}

///|
test "api surface classification assigns representative lines" {
  fn category(path : String, line : String) -> String {
    match classify_api_surface_line(path, line) {
      Some(value) => value
      None => "none"
    }
  }
  inspect(
    category(
      "moui/views/pkg.generated.mbti", "pub fn[Msg] button(String) -> @core.View[Msg]",
    ),
    content="app_constructor",
  )
  inspect(
    category(
      "moui/views/pkg.generated.mbti", "pub fn picker_item(String, String) -> PickerItem",
    ),
    content="app_state_helper",
  )
  inspect(
    category("moui/views/pkg.generated.mbti", "pub struct ButtonStyle {"),
    content="app_style",
  )
  inspect(
    category(
      "moui/views/pkg.generated.mbti", "pub fn draw_path(PaintContext, @core.PathSpec) -> Unit",
    ),
    content="advanced_core_protocol",
  )
  inspect(
    category(
      "moui/core/pkg.generated.mbti", "pub fn View::node(identity~ : () -> ViewIdentity) -> View[Msg]",
    ),
    content="advanced_core_protocol",
  )
  inspect(
    category(
      "moui/runtime/pkg.generated.mbti", "pub fn AppRuntime::inspector_snapshot(Self) -> InspectorSnapshot",
    ),
    content="runtime_diagnostic",
  )
  inspect(
    category(
      "moui/backend/host/pkg.generated.mbti", "pub fn HostRouteSource::subscription(Self) -> @core.Subscription[Msg]",
    ),
    content="host_contract",
  )
  inspect(
    category(
      "moui/render/pkg.generated.mbti", "pub fn renderer_feature_capability_report() -> Array[RendererFeatureCapability]",
    ),
    content="renderer_contract",
  )
}

///|
test "api surface classification rejects unclassified public lines" {
  let failures : Array[String] = []
  let fixture =
    #|// Generated using `moon info`, DON'T EDIT IT
    #|package "wzzc-dev/moui/core"
    #|pub fn surprise_kernel_escape() -> Unit
    #|
  validate_api_surface_classification_text(
    "moui/core/pkg.generated.mbti", fixture, failures,
  )
  inspect(failures.length(), content="1")
  assert_true(failures[0].contains("unclassified public API line"))
  assert_true(failures[0].contains("add classification or move API"))
}

///|
test "root facade budget forwards app-loop sugar only" {
  let root = budget_by_label("root facade (app-loop sugar)")
  inspect(root.max_pub_all_lines, content="0")
  assert_true(root.required_tokens.contains("pub using @core {type View}"))
  assert_true(root.required_tokens.contains("pub using @core {type Program}"))
  assert_true(root.forbidden_tokens.contains("pub using @core {type Point}"))
  assert_true(root.forbidden_tokens.contains("pub using @core {type State}"))
}

///|
test "domain facade packages are required to re-export from core only" {
  let geom = budget_by_label("geometry sugar")
  assert_true(geom.required_tokens.contains("\"wzzc-dev/moui/core\""))
  assert_true(geom.required_tokens.contains("pub using @core {type Point}"))
  let gfx = budget_by_label("graphics sugar")
  assert_true(gfx.required_tokens.contains("\"wzzc-dev/moui/core\""))
  assert_true(gfx.required_tokens.contains("pub using @core {type Color}"))
  let core = budget_by_label("core")
  assert_false(core.required_tokens.contains("\"wzzc-dev/moui/geometry\""))
  assert_false(core.required_tokens.contains("\"wzzc-dev/moui/graphics\""))
  assert_false(core.required_tokens.contains("\"wzzc-dev/moui/animation\""))
  assert_false(core.required_tokens.contains("\"wzzc-dev/moui/text\""))
  assert_false(core.required_tokens.contains("\"wzzc-dev/moui/state\""))
}

///|
test "domain sugar packages forward the curated per-domain type set" {
  let geom = budget_by_label("geometry sugar")
  assert_true(geom.required_tokens.contains("pub using @core {type Point}"))
  assert_true(geom.required_tokens.contains("pub using @core {type Alignment}"))
  assert_true(
    geom.required_tokens.contains("pub using @core {type MainAxisAlignment}"),
  )
  assert_true(
    geom.required_tokens.contains("pub using @core {type CrossAxisAlignment}"),
  )
  assert_true(geom.forbidden_tokens.contains("pub using @core {type View}"))
  assert_true(geom.forbidden_tokens.contains("pub using @core {type Color}"))

  let gfx = budget_by_label("graphics sugar")
  assert_true(gfx.required_tokens.contains("pub using @core {type Color}"))
  assert_true(gfx.required_tokens.contains("pub using @core {type Brush}"))
  assert_true(
    gfx.required_tokens.contains("pub using @core {type ShadowStyle}"),
  )
  assert_true(
    gfx.required_tokens.contains("pub using @core {type RoundedRect}"),
  )
  assert_true(gfx.required_tokens.contains("pub using @core {type PathSpec}"))
  assert_true(gfx.required_tokens.contains("pub using @core {type ImageFit}"))
  assert_true(gfx.forbidden_tokens.contains("pub using @core {type View}"))
  assert_true(gfx.forbidden_tokens.contains("pub using @core {type Point}"))
  assert_false(gfx.forbidden_tokens.contains("pub using @core {type Color}"))
  assert_false(gfx.forbidden_tokens.contains("pub using @core {type Brush}"))

  let animation = budget_by_label("animation sugar")
  assert_true(
    animation.required_tokens.contains("pub using @core {type Easing}"),
  )
  assert_true(
    animation.required_tokens.contains("pub using @core {type TransitionSpec}"),
  )
  assert_true(
    animation.forbidden_tokens.contains("pub using @core {type View}"),
  )
  assert_true(
    animation.forbidden_tokens.contains("pub using @core {type RoundedRect}"),
  )

  let text = budget_by_label("text sugar")
  assert_true(text.required_tokens.contains("pub using @core {type FontSpec}"))
  assert_true(text.required_tokens.contains("pub using @core {type TextAlign}"))
  assert_true(text.forbidden_tokens.contains("pub using @core {type View}"))
  assert_true(text.forbidden_tokens.contains("pub using @core {type Color}"))

  let state = budget_by_label("state sugar")
  assert_true(
    state.required_tokens.contains("pub using @core {type ScrollState}"),
  )
  assert_true(
    state.required_tokens.contains("pub using @core {type NavigationState}"),
  )
  assert_true(
    state.required_tokens.contains("pub using @core {type LayoutDirection}"),
  )
  assert_true(
    state.required_tokens.contains("pub using @core {type FocusScope}"),
  )
  assert_true(state.forbidden_tokens.contains("pub using @core {type View}"))
  assert_true(state.forbidden_tokens.contains("pub using @core {type Point}"))
  assert_true(
    state.forbidden_tokens.contains("pub using @core {type CommandIntent}"),
  )
}

///|
test "runtime facade budget pins the opaque runtime boundary" {
  let runtime = budget_by_label("runtime facade")
  inspect(runtime.max_lines, content="430")
  inspect(runtime.max_pub_lines, content="285")
  inspect(runtime.max_pub_all_lines, content="9")
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
  assert_true(runtime.required_tokens.contains("pub struct InspectorSnapshot"))
  assert_true(
    runtime.required_tokens.contains("pub struct ProgramRuntimeSnapshot"),
  )
  assert_true(
    runtime.required_tokens.contains("pub struct RuntimeInspectorSnapshot"),
  )
  assert_true(runtime.required_tokens.contains("pub struct EffectPlanSummary"))
  assert_true(
    runtime.required_tokens.contains("pub struct SubscriptionPlanSummary"),
  )
  assert_true(
    runtime.required_tokens.contains("pub fn InspectorSnapshot::runtime(Self)"),
  )
  assert_true(
    runtime.required_tokens.contains(
      "pub fn ProgramRuntimeSnapshot::dispatched_count(Self)",
    ),
  )
  assert_true(
    runtime.required_tokens.contains("pub fn[Msg] effect_plan_summary("),
  )
  assert_true(
    runtime.required_tokens.contains("pub fn[Msg] subscription_plan_summary("),
  )
  assert_true(runtime.forbidden_tokens.contains("RuntimeState"))
  assert_true(runtime.forbidden_tokens.contains("ViewNode"))
  assert_true(runtime.forbidden_tokens.contains("VirtualNode"))
  assert_true(runtime.forbidden_tokens.contains("ErasedViewNode"))
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
  inspect(max_shared_app_core_imports(), content="20")
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
  inspect(views.max_lines, content="1250")
  inspect(views.max_pub_lines, content="560")
  inspect(views.max_pub_all_lines, content="19")
  inspect(views_facade_core_alias_tokens().length(), content="8")
  inspect(views_facade_host_alias_tokens().length(), content="0")
  let required = views.required_tokens
  assert_true(required.contains("pub using @core {type ActionCommand}"))
  assert_true(required.contains("pub using @core {type ActionCommandMap}"))
  assert_true(required.contains("pub using @core {type CommandBinding}"))
  assert_true(required.contains("pub using @core {type ColorPalette}"))
  assert_true(required.contains("pub using @core {type TypographyScale}"))
  assert_true(required.contains("pub using @core {type CommandIntent}"))
  assert_true(required.contains("pub using @core {type KeyModifiers}"))
  assert_true(required.contains("pub using @core {type KeyboardShortcut}"))
  assert_true(views.forbidden_tokens.contains("pub using @core {type Color}"))
  assert_true(views.forbidden_tokens.contains("pub using @core {type ColorScheme}"))
  assert_true(required.contains("pub struct ButtonStyle"))
  assert_true(required.contains("type FormFieldState"))
  assert_true(required.contains("pub(all) enum DatePickerMode"))
  assert_true(required.contains("pub fn default_theme()"))
  assert_true(required.contains("pub fn light_theme()"))
  assert_true(required.contains("pub fn dark_theme()"))
  assert_false(required.contains("pub using @core {type ButtonStyle}"))
  assert_false(required.contains("pub using @core {type TextFieldStyle}"))
  assert_false(required.contains("pub using @core {type PickerItem}"))
  assert_false(required.contains("pub using @core {type FormFieldState}"))
  assert_false(
    required.contains("pub using @core {type FormValidationSummary}"),
  )
  assert_false(required.contains("pub using @core {type RichTextDocument}"))
  assert_true(required.contains("pub fn[Msg] text("))
  assert_true(required.contains("pub fn[Msg] empty()"))
  assert_true(required.contains("pub fn[Msg] spacer("))
  assert_true(required.contains("pub fn[Msg] picker("))
  assert_true(required.contains("pub fn picker_item("))
  assert_true(required.contains("pub fn[Msg] datepicker("))
  assert_true(required.contains("pub fn[Msg] custom_layout("))
  assert_true(required.contains("pub fn[Msg] custom_children_layout("))
  assert_true(required.contains("pub fn[Msg] component("))
  assert_true(views.forbidden_tokens.contains("pub fn[Msg] raw_"))
  assert_true(views.forbidden_tokens.contains("RawDatePickerDisplayMode"))
  assert_true(views.forbidden_tokens.contains("RawPickerOption"))
  assert_true(required.contains("pub struct RouteLocation"))
  assert_true(required.contains("pub struct RouteHistoryState"))
  assert_true(required.contains("type RouteFocusStore"))
  assert_true(required.contains("type RouterState"))
  assert_false(required.contains("pub using @core {type RouteHistoryState}"))
  assert_false(required.contains("pub using @core {type RouteLocation}"))
  assert_false(required.contains("pub using @core {type WebViewEvent}"))
  assert_false(required.contains("pub using @host {type WebViewEvent}"))
  assert_false(
    required.contains("pub using @host {type WebViewNavigationPolicy}"),
  )
  assert_true(
    views.forbidden_tokens.contains("pub using @core {type RoundedRect}"),
  )
  assert_true(
    views.forbidden_tokens.contains("pub using @core {type TransitionSpec}"),
  )
  assert_false(required.contains("pub fn rich_text_document_height("))
  assert_true(views.forbidden_tokens.contains("RichText"))
  assert_true(views.forbidden_tokens.contains("rich_text_"))
  assert_true(views.forbidden_tokens.contains("markdown_editor"))
}

///|
test "host and renderer public all budgets ratchet down" {
  let host = budget_by_label("host contracts")
  inspect(host.max_pub_all_lines, content="71")
  let renderer = budget_by_label("renderer facade")
  inspect(renderer.max_pub_all_lines, content="40")
  let skia = budget_by_label("skia renderer")
  inspect(skia.max_pub_all_lines, content="3")
  let sun = budget_by_label("sun renderer")
  inspect(sun.max_pub_all_lines, content="1")
  let webgpu = budget_by_label("webgpu adapter")
  inspect(webgpu.max_pub_all_lines, content="2")
  let wgpu = budget_by_label("native wgpu renderer")
  inspect(wgpu.max_pub_all_lines, content="2")
  let text_protocol = budget_by_label("native text protocol")
  inspect(text_protocol.max_pub_all_lines, content="0")
  assert_true(sun.forbidden_tokens.contains("HostWindowRenderer"))
  assert_true(webgpu.forbidden_tokens.contains("SkiaRasterRenderer"))
  assert_true(wgpu.forbidden_tokens.contains("\"wzzc-dev/moui/backend/host\""))
  assert_true(text_protocol.forbidden_tokens.contains("RendererHandle"))
}

///|
test "core descriptor payloads stay opaque" {
  let core = budget_by_label("core")
  inspect(core.max_lines, content="1830")
  inspect(core.max_pub_lines, content="520")
  inspect(core.max_pub_all_lines, content="150")
  assert_true(core.required_tokens.contains("View::node"))
  assert_true(core.required_tokens.contains("View::identity"))
  assert_true(core.required_tokens.contains("View::children"))
  assert_true(core.required_tokens.contains("View::layout"))
  assert_true(core.required_tokens.contains("View::paint"))
  assert_true(core.required_tokens.contains("View::event"))
  assert_true(core.required_tokens.contains("View::text_command_result"))
  assert_true(core.required_tokens.contains("View::accepts_focus"))
  assert_true(core.required_tokens.contains("pub(all) struct ViewIdentity"))
  assert_true(
    core.required_tokens.contains("pub(all) struct ViewLayoutContext"),
  )
  assert_true(core.required_tokens.contains("pub(all) struct ViewPaintPlan"))
  assert_true(core.required_tokens.contains("pub(all) struct ViewEventResult"))
  assert_true(core.required_tokens.contains("pub(all) enum ViewDirtyHint"))
  assert_true(core.required_tokens.contains("ViewClean"))
  assert_true(core.required_tokens.contains("ViewPaintDirty"))
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct EffectDescriptor"),
  )
  assert_true(
    core.forbidden_tokens.contains("pub(all) struct SubscriptionDescriptor"),
  )
  assert_true(core.forbidden_tokens.contains("type RuntimeState"))
  assert_true(core.forbidden_tokens.contains("type RuntimeKernel"))
  assert_true(core.forbidden_tokens.contains("RuntimeKernel::"))
  assert_true(core.forbidden_tokens.contains("VirtualNode"))
  assert_true(core.forbidden_tokens.contains("View::virtual_node"))
  assert_true(core.forbidden_tokens.contains("View::ops"))
  assert_true(core.forbidden_tokens.contains("View::custom"))
  assert_true(core.forbidden_tokens.contains("pub struct ViewNode"))
  assert_true(core.forbidden_tokens.contains("ViewNode::new"))
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
  assert_true(core.forbidden_tokens.contains("DatePickerMode"))
  assert_true(core.forbidden_tokens.contains("SheetPresentationMode"))
  assert_true(core.forbidden_tokens.contains("EffectPlanSummary"))
  assert_true(core.forbidden_tokens.contains("SubscriptionPlanSummary"))
  assert_true(core.forbidden_tokens.contains("EffectRuntimeOp"))
  assert_true(core.forbidden_tokens.contains("Effect::plan_summary("))
  assert_true(core.forbidden_tokens.contains("Effect::runtime_ops("))
  assert_true(core.forbidden_tokens.contains("Subscription::plan_summary("))
  assert_true(core.forbidden_tokens.contains("Theme::default("))
  assert_true(core.forbidden_tokens.contains("Environment::default("))
  assert_true(core.forbidden_tokens.contains("BuildContext"))
  assert_true(core.forbidden_tokens.contains("ComponentContext::new("))
  assert_true(core.forbidden_tokens.contains("type FrameProfile"))
  assert_true(
    core.forbidden_tokens.contains("InspectorSnapshot::from_runtime("),
  )
  assert_true(
    core.forbidden_tokens.contains("RuntimeInspectorSnapshot::from_runtime("),
  )
  assert_true(core.forbidden_tokens.contains("RouteFocusStore::restore("))
  assert_true(core.forbidden_tokens.contains("RichText"))
}

///|
test "core legacy families are ratcheted toward existing layers" {
  let budgets = legacy_core_family_budgets()
  inspect(budgets.length(), content="9")
  for budget in budgets {
    inspect(budget.target_occurrences, content="0")
  }
  let labels = budgets.map(budget => budget.label)
  assert_true(labels.contains("control styles and picker model"))
  assert_true(labels.contains("form workflow helpers"))
  assert_true(labels.contains("rich text editor domain model"))
  assert_true(labels.contains("WebView platform service model"))
  assert_true(labels.contains("routing and history controller"))
  assert_true(labels.contains("datepicker control semantics"))
  assert_true(labels.contains("runtime diagnostics summary contract"))
  assert_true(labels.contains("design default theme helpers"))
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
  let datepicker = budgets[5]
  inspect(datepicker.max_occurrences, content="0")
  assert_true(datepicker.tokens.contains("DatePickerMode"))
  assert_true(datepicker.tokens.contains("DatePickerDisplayMode"))
  let runtime_summary = budgets[6]
  inspect(runtime_summary.max_occurrences, content="0")
  assert_true(runtime_summary.tokens.contains("EffectPlanSummary"))
  assert_true(runtime_summary.tokens.contains("runtime_ops"))
  let default_theme = budgets[7]
  inspect(default_theme.max_occurrences, content="0")
  assert_true(default_theme.tokens.contains("Theme::default"))
  assert_true(default_theme.tokens.contains("default_theme"))
  let diagnostics = budgets[8]
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
  inspect(max_shared_app_core_imports(), content="20")
  inspect(allowed.length(), content="5")
  assert_true(allowed.contains("examples/markdown_editor/app/moon.pkg"))
  assert_true(allowed.contains("examples/mo_workbench/app/moon.pkg"))
  assert_true(allowed.contains("examples/pdf_workbench/app/moon.pkg"))
  assert_true(allowed.contains("examples/showcase/app/moon.pkg"))
  assert_true(allowed.contains("website/app/moon.pkg"))
}

///|
test "internal mobile runtime imports are restricted to mobile backends" {
  let allowed = allowed_mobile_runtime_internal_imports()
  inspect(allowed.length(), content="4")
  assert_true(allowed.contains("moui/backend/android/moon.pkg"))
  assert_true(allowed.contains("moui/backend/ios/moon.pkg"))
  assert_true(allowed.contains("moui/backend/harmonyos/moon.pkg"))
  assert_true(allowed.contains("moui/backend/internal/mobile_runtime/moon.pkg"))
  let token = "  \"" + mobile_runtime_internal_package_token() + "\",\n"
  let failures : Array[String] = []
  validate_mobile_runtime_internal_import_text(
    "moui/backend/android/moon.pkg", token, failures,
  )
  inspect(failures.length(), content="0")
  validate_mobile_runtime_internal_import_text(
    "examples/counter/app/moon.pkg", token, failures,
  )
  inspect(failures.length(), content="1")
  assert_true(failures[0].contains("may only be imported"))
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
test "app api hygiene guard keeps examples on domain sugar for app-facing core types" {
  let roots = app_api_hygiene_roots()
  inspect(roots.length(), content="3")
  assert_true(roots.contains("examples"))
  assert_true(roots.contains("docs"))
  assert_true(roots.contains("website"))
  let tokens = app_api_hygiene_forbidden_tokens().map(rule => rule.token)
  inspect(tokens.length(), content="12")
  assert_true(tokens.contains("@core.Program["))
  assert_true(tokens.contains("@core.Program::"))
  assert_true(tokens.contains("@core.View["))
  assert_true(tokens.contains("@core.View::"))
  assert_true(tokens.contains("@core.State["))
  assert_true(tokens.contains("@core.State::"))
  assert_true(tokens.contains("@core.Binding["))
  assert_true(tokens.contains("@core.Binding::"))
  assert_true(tokens.contains("@core.Effect["))
  assert_true(tokens.contains("@core.Effect::"))
  assert_true(tokens.contains("@core.Subscription["))
  assert_true(tokens.contains("@core.Subscription::"))
  assert_true(
    app_api_hygiene_test_path("examples/counter/app/counter_app_test.mbt"),
  )
  assert_true(
    app_api_hygiene_test_path("examples/counter/app/counter_app_wbtest.mbt"),
  )
  assert_false(app_api_hygiene_test_path("examples/counter/app/app.mbt"))
  assert_true(
    app_api_hygiene_allowed_core_view_line("implemented via @core.View::node"),
  )
  assert_true(
    app_api_hygiene_allowed_core_view_line(
      "do not add @core.View::primitive_text_view",
    ),
  )
  assert_false(
    app_api_hygiene_allowed_core_view_line("fn view() -> @core.View[Msg]"),
  )
  assert_true(
    app_api_hygiene_line_allowed(
      "examples/counter/app/counter_app_test.mbt", "fn view() -> @core.View[Msg]",
    ),
  )
  assert_false(
    app_api_hygiene_line_allowed(
      "examples/counter/app/app.mbt", "fn view() -> @core.View[Msg]",
    ),
  )
}

///|
test "views return rules cover app-facing constructors" {
  let names = view_return_rules().map(rule => rule.name)
  assert_true(names.contains("button"))
  assert_true(names.contains("column"))
  assert_true(names.contains("text_field"))
  assert_false(names.contains("markdown_editor"))
  assert_true(names.contains("navigation_stack"))
  assert_true(names.contains("image"))
  assert_true(names.contains("canvas"))
  assert_true(names.contains("sheet"))
  assert_false(names.contains("web_view"))
  for rule in view_return_rules() {
    inspect(rule.return_token, content="-> @core.View[Msg]")
  }
}
