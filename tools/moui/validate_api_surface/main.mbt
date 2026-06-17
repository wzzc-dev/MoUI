///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct PackageBudget {
  label : String
  path : String
  package_token : String
  max_lines : Int
  max_pub_lines : Int
  max_pub_all_lines : Int
  required_tokens : Array[String]
  forbidden_tokens : Array[String]
}

///|
struct ViewReturnRule {
  name : String
  signature_prefix : String
  return_token : String
}

///|
struct ForbiddenSourceToken {
  label : String
  token : String
}

///|
struct LegacyCoreFamilyBudget {
  label : String
  tokens : Array[String]
  max_occurrences : Int
  target_occurrences : Int
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_api_surface [--repo-root PATH]
    #|
    #|Audits generated pkg.generated.mbti files for MoUI API-surface guardrails:
    #|package size budgets, root facade boundaries, and app-facing view return
    #|types. Run moon info before this check when public API may have changed.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn root_facade_app_safe_aliases() -> Array[String] {
  [
    "View", "Program", "Effect", "Subscription", "Theme", "Point", "Size", "Rect",
    "Insets", "Constraints", "Axis", "Color", "Brush", "BorderStyle", "ShadowStyle",
    "FontSpec", "FontFamily", "FontFamilyStack", "TextRange", "TextAlign", "State",
    "Binding", "DerivedState", "Environment", "ViewEnvironment", "ColorScheme", "LayoutDirection",
    "AccessibilityContrast", "ContentSizeCategory", "ScrollState", "FocusState",
    "NavigationState", "CommandIntent", "KeyboardShortcut", "KeyModifiers", "DateValue",
    "DatePickerMode",
  ]
}

///|
fn root_facade_required_tokens() -> Array[String] {
  let tokens = ["\"wzzc-dev/moui/core\""]
  for type_name in root_facade_app_safe_aliases() {
    tokens.push("pub using @core {type \{type_name}}")
  }
  tokens
}

///|
fn views_facade_core_alias_tokens() -> Array[String] {
  [
    "ActionCommand", "ActionCommandMap", "BadgeStyle", "ButtonStyle", "ChoiceControlStyle",
    "Color", "ColorScheme", "CommandBinding", "CommandIntent", "ControlStateStyle",
    "FeedbackStyle", "FormController", "FormFieldError", "FormFieldState", "FormValidationResult",
    "FormValidationRule", "FormValidationStyle", "FormValidationSummary", "KeyModifiers",
    "KeyboardShortcut", "PickerItem", "PickerStyle", "ProgressStyle", "RichTextBlock",
    "RichTextDecoration", "RichTextDocument", "RichTextInputTransform", "RichTextRun",
    "RichTextSourceRange", "RichTextTable", "RichTextTableCell", "RouteDescriptor",
    "RouteFocusStore", "RouteHistoryEntry", "RouteHistoryState", "RouteLocation",
    "RouteParam", "RouteQueryParam", "RouterSnapshot", "RouterState", "SliderStyle",
    "SurfaceStyle", "TextFieldStyle", "TextStyle", "ToneStyle", "WebViewEvent", "WebViewNavigationPolicy",
  ]
}

///|
fn views_facade_required_tokens() -> Array[String] {
  let tokens = [
    "\"wzzc-dev/moui/core\"", "pub fn[Msg] button(", "pub fn[Msg] column(", "pub fn[Msg] markdown_editor(",
    "pub type RichTextFormatter = (String) -> @core.RichTextDocument",
  ]
  for type_name in views_facade_core_alias_tokens() {
    tokens.push("pub using @core {type \{type_name}}")
  }
  tokens
}

///|
fn package_budgets() -> Array[PackageBudget] {
  [
    {
      label: "root facade",
      path: "moui/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui\"",
      max_lines: 125,
      max_pub_lines: 40,
      max_pub_all_lines: 0,
      required_tokens: root_facade_required_tokens(),
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend", "\"wzzc-dev/moui/render", "moui_theme", "HostWindowRenderer",
        "RendererBackendKind", "SkiaRasterRenderer", "RuntimeState", "ViewNode",
        "ViewSpec", "DrawCommand", "EffectDescriptor", "SubscriptionDescriptor",
        "SubscriptionLifecycleSnapshot", "ProgramRuntimeSnapshot", "pub using @core {type AppRuntime}",
        "pub using @core {type WidgetOps}", "pub using @core {type WidgetLayoutContext}",
        "pub using @core {type WidgetPaintContext}", "pub using @core {type WidgetEventContext}",
        "pub using @core {type RuntimeInspectorSnapshot}", "pub using @core {type RenderInspectorSnapshot}",
        "pub using @core {type WebViewEvent}", "pub using @core {type WebViewSpec}",
        "pub using @core {type WebViewCommand}", "pub using @core {type WebViewNavigationPolicy}",
        "pub using @core {type RichTextDocument}", "pub using @core {type RichTextInputTransform}",
        "pub using @core {type FormFieldState}", "pub using @core {type FormValidationSummary}",
        "pub using @core {type RouteHistoryState}", "pub using @core {type RouterState}",
        "pub fn default_theme(", "pub fn light_theme(", "pub fn dark_theme(", "pub fn theme(",
      ],
    },
    {
      label: "runtime facade",
      path: "moui/runtime/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/runtime\"",
      max_lines: 307,
      max_pub_lines: 42,
      max_pub_all_lines: 17,
      required_tokens: [
        "\"wzzc-dev/moui/core\"", "pub struct AppRuntime", "pub fn[Model, Msg] new_program(",
        "pub fn[Model, Msg] new_program_with_dimensions(", "pub fn[Msg] new_view(",
        "pub fn[Model, Msg] AppRuntime::new_program(", "pub fn[Msg] AppRuntime::new_view(",
        "pub fn AppRuntime::draw_frame(", "pub fn AppRuntime::inspector_snapshot(Self) -> InspectorSnapshot",
        "pub fn AppRuntime::program_runtime_snapshot(Self) -> ProgramRuntimeSnapshot",
        "pub(all) struct InspectorSnapshot", "pub(all) struct ProgramRuntimeSnapshot",
        "pub(all) struct RuntimeInspectorSnapshot", "pub(all) struct RenderInspectorSnapshot",
        "pub(all) struct ViewTreeInspectorSnapshot", "pub(all) enum EffectTaskCancelReason",
        "pub(all) enum SubscriptionCancelReason",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend", "\"wzzc-dev/moui/render", "moui_theme", "RuntimeState",
        "ViewNode", "ViewSpec", "pub using @core {type AppRuntime}", "inner : @core.AppRuntime",
        "core_inspector_snapshot", "core_program_runtime_snapshot", "@core.InspectorSnapshot",
        "@core.ProgramRuntimeSnapshot",
      ],
    },
    {
      label: "core",
      path: "moui/core/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/core\"",
      max_lines: 1904,
      max_pub_lines: 552,
      max_pub_all_lines: 151,
      required_tokens: [
        "pub struct View[Msg]", "View::map", "pub(all) struct Theme", "type Program[Model, Msg]",
        "pub(all) struct Effect", "pub(all) struct Subscription", "pub(all) struct DrawFrame",
        "pub struct WidgetOps[Msg]", "View::widget", "WidgetOps::new",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui_theme", "\"wzzc-dev/moui/render/skia\"", "SkiaRasterRenderer",
        "View::empty(", "View::text(", "View::button(", "View::image(", "View::web_view(",
        "View::flex(", "View::spacer(", "View::frame_node(", "View::stack(", "View::scroll(",
        "View::grid(", "View::list(", "View::custom_view(", "View::custom_children_layout(",
        "View::component(", "View::checkbox(", "View::controlled_checkbox(", "View::text_field(",
        "View::controlled_text_field(", "View::rich_text_editor(", "View::controlled_rich_text_editor(",
        "View::picker(", "View::controlled_picker(", "View::datepicker(", "View::controlled_datepicker(",
        "View::search_bar(", "View::controlled_search_bar(", "pub(all) struct EffectDescriptor",
        "pub(all) struct SubscriptionDescriptor", "type AppRuntime", "AppRuntime::",
        "ViewLoweringSink", "View::lower_for_runtime(", "View::primitive_empty_view(",
        "View::primitive_text_view(", "View::primitive_button_view(", "View::primitive_image_view(",
        "View::primitive_web_view(", "View::primitive_flex_view(", "View::primitive_spacer_view(",
        "View::primitive_frame_view(", "View::primitive_stack_view(", "View::primitive_scroll_view(",
        "View::primitive_grid_view(", "View::primitive_list_view(", "View::primitive_custom_view(",
        "View::primitive_custom_children_layout_view(", "View::primitive_component_view(",
        "View::primitive_checkbox_view(", "View::primitive_controlled_checkbox_view(",
        "View::primitive_text_field_view(", "View::primitive_controlled_text_field_view(",
        "View::primitive_rich_text_editor_view(", "View::primitive_controlled_rich_text_editor_view(",
        "View::primitive_picker_view(", "View::primitive_controlled_picker_view(",
        "View::primitive_datepicker_view(", "View::primitive_controlled_datepicker_view(",
        "View::primitive_search_bar_view(", "View::primitive_controlled_search_bar_view(",
        "type RuntimeKernel", "RuntimeKernel::", "type RuntimeState", "RuntimeState::",
        "type ViewNode[", "type ElementNode", "ElementNode::", "type ElementTree",
        "ElementTree::", "type ViewSpec", "pub(all) enum ViewSpec", "pub enum ViewSpec",
        "pub(all) struct InspectorSnapshot", "pub(all) struct ProgramRuntimeSnapshot",
        "pub(all) struct RuntimeInspectorSnapshot", "pub(all) struct RenderInspectorSnapshot",
        "pub(all) struct ViewTreeInspectorSnapshot", "pub(all) struct LayoutInspectorSnapshot",
        "pub(all) struct SemanticsInspectorSnapshot", "pub(all) struct WidgetInspectorSummary",
        "type FrameProfile", "FrameProfile::capture(", "InspectorSnapshot::from_runtime(",
        "RuntimeInspectorSnapshot::from_runtime(", "ViewTreeInspectorSnapshot::from_runtime(",
        "LayoutInspectorSnapshot::from_runtime(", "RenderInspectorSnapshot::from_runtime(",
        "SemanticsInspectorSnapshot::from_runtime(", "RouteFocusStore::restore(",
        "RouteFocusStore::restore_location(",
      ],
    },
    {
      label: "views facade",
      path: "moui/views/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/views\"",
      max_lines: 760,
      max_pub_lines: 288,
      max_pub_all_lines: 60,
      required_tokens: views_facade_required_tokens(),
      forbidden_tokens: [
        "ViewSpec", "ViewNode", "RuntimeState", "HostWindowRenderer", "SkiaRasterRenderer",
      ],
    },
    {
      label: "host contracts",
      path: "moui/backend/host/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/host\"",
      max_lines: 1100,
      max_pub_lines: 390,
      max_pub_all_lines: 100,
      required_tokens: [
        "HostWindowRenderer", "HostAsyncImageLoader", "HostRouteSource",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/render/skia\"", "\"wzzc-dev/moui/render/wgpu\"", "SkiaRasterRenderer",
      ],
    },
    {
      label: "renderer facade",
      path: "moui/render/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render\"",
      max_lines: 380,
      max_pub_lines: 80,
      max_pub_all_lines: 45,
      required_tokens: [
        "RendererBackendKind", "RendererDescriptor", "RenderFrameResult",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend/host\"", "HostWindowRenderer", "SkiaRasterRenderer",
      ],
    },
    {
      label: "skia renderer",
      path: "moui/render/skia/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render/skia\"",
      max_lines: 220,
      max_pub_lines: 50,
      max_pub_all_lines: 8,
      required_tokens: [
        "SkiaRasterRenderer", "skia_available", "skia_image_load_completion",
      ],
      forbidden_tokens: ["\"wzzc-dev/moui/backend/host\"", "HostWindowRenderer"],
    },
  ]
}

///|
fn view_return_rules() -> Array[ViewReturnRule] {
  [
    {
      name: "button",
      signature_prefix: "pub fn[Msg] button(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "column",
      signature_prefix: "pub fn[Msg] column(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "row",
      signature_prefix: "pub fn[Msg] row(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "text",
      signature_prefix: "pub fn[Msg] text(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "text_field",
      signature_prefix: "pub fn[Msg] text_field(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "markdown_editor",
      signature_prefix: "pub fn[Msg] markdown_editor(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "navigation_stack",
      signature_prefix: "pub fn[Msg] navigation_stack(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "web_view",
      signature_prefix: "pub fn[Msg] web_view(",
      return_token: "-> @core.View[Msg]",
    },
  ]
}

///|
fn legacy_core_family_budgets() -> Array[LegacyCoreFamilyBudget] {
  [
    {
      label: "control styles and picker model",
      tokens: [
        "ButtonStyle", "TextFieldStyle", "ChoiceControlStyle", "ProgressStyle", "SliderStyle",
        "PickerStyle", "FeedbackStyle", "BadgeStyle", "FormValidationStyle", "PickerItem",
      ],
      max_occurrences: 28,
      target_occurrences: 0,
    },
    {
      label: "form workflow helpers",
      tokens: [
        "FormFieldError", "FormValidationResult", "FormValidationSummary", "FormValidationStyle",
        "FormFieldState", "FormValidationRule", "FormController", "required_field",
        "validate_form",
      ],
      max_occurrences: 34,
      target_occurrences: 0,
    },
    {
      label: "rich text editor domain model",
      tokens: [
        "RichTextDocument", "RichTextBlock", "RichTextRun", "RichTextInputTransform",
        "RichTextFormatter", "RichTextTable", "RichTextTableCell", "RichTextSourceRange",
        "RichTextDecoration", "rich_text_document_", "rich_text_editor_",
      ],
      max_occurrences: 38,
      target_occurrences: 0,
    },
    {
      label: "WebView platform service model",
      tokens: [
        "WebViewSpec", "WebViewCommand", "WebViewEvent", "WebViewNavigationPolicy",
        "PlatformViewPlacement::web_view", "WebView(String",
      ],
      max_occurrences: 17,
      target_occurrences: 0,
    },
    {
      label: "routing and history controller",
      tokens: [
        "RouteHistoryState", "RouteDescriptor", "RouterState", "RouteFocusStore",
        "RouteLocation", "RouterSnapshot", "resolve_route",
      ],
      max_occurrences: 66,
      target_occurrences: 0,
    },
    {
      label: "runtime diagnostics snapshots",
      tokens: [
        "RuntimeInspectorSnapshot", "ProgramRuntimeSnapshot", "ViewTreeInspectorSnapshot",
        "RenderInspectorSnapshot", "InspectorSnapshot", "LayoutInspectorSnapshot",
        "SemanticsInspectorSnapshot", "WidgetInspectorSummary",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
  ]
}

///|
fn line_count(text : String) -> Int {
  let end = for index = text.length(); index > 0; {
    if text[index - 1] == '\n' {
      continue index - 1
    } else {
      break index
    }
  } nobreak {
    0
  }
  if end == 0 {
    return 0
  }
  let mut count = 1
  for index in 0..<end {
    if text[index] == '\n' {
      count += 1
    }
  }
  count
}

///|
fn count_lines_with_prefix(text : String, prefix : String) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix(prefix) {
      count += 1
    }
  }
  count
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn skipped_directory_name(name : String) -> Bool {
  name == ".git" ||
  name == ".mooncakes" ||
  name == "_build" ||
  name == "artifacts"
}

///|
fn read_dir_names(
  path : String,
  label : String,
) -> Result[Array[String], String] {
  if !@tools.directory_exists(path) {
    return Err(label + " is missing: " + path)
  }
  let entries : Array[String] = @fs.read_dir(path) catch {
    _ => return Err(label + " could not be read: " + path)
  }
  entries.sort()
  Ok(entries)
}

///|
fn collect_mbt_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  let entries = match read_dir_names(absolute_dir, relative_dir) {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(absolute) {
      if !skipped_directory_name(entry) {
        collect_mbt_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) &&
      relative.has_suffix(".mbt") &&
      !relative.has_suffix("pkg.generated.mbti") {
      files.push(relative)
    }
  }
}

///|
fn push_max_check(
  failures : Array[String],
  label : String,
  actual : Int,
  max : Int,
) -> Unit {
  if actual > max {
    failures.push(label + " is \{actual}, above budget \{max}")
  }
}

///|
fn push_required_token_checks(
  failures : Array[String],
  path : String,
  text : String,
  tokens : Array[String],
) -> Unit {
  for token in tokens {
    if !text.contains(token) {
      failures.push(path + ": expected token '" + token + "'")
    }
  }
}

///|
fn push_forbidden_token_checks(
  failures : Array[String],
  path : String,
  text : String,
  tokens : Array[String],
) -> Unit {
  for token in tokens {
    if text.contains(token) {
      failures.push(path + ": forbidden token '" + token + "'")
    }
  }
}

///|
fn validate_package_budget(
  repo_root : String,
  budget : PackageBudget,
  failures : Array[String],
) -> Unit {
  let text = match read_repo_text(repo_root, budget.path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let lines = line_count(text)
  let pub_lines = count_lines_with_prefix(text, "pub ")
  let pub_all_lines = count_lines_with_prefix(text, "pub(all)")
  println(
    "api surface: " +
    budget.label +
    " lines=\{lines} pub=\{pub_lines} pub(all)=\{pub_all_lines}",
  )
  if !text.has_prefix("// Generated using `moon info`, DON'T EDIT IT") {
    failures.push(budget.path + ": expected moon info generated header")
  }
  if !text.contains(budget.package_token) {
    failures.push(
      budget.path + ": expected package token " + budget.package_token,
    )
  }
  push_max_check(failures, budget.path + " line count", lines, budget.max_lines)
  push_max_check(
    failures,
    budget.path + " public declaration count",
    pub_lines,
    budget.max_pub_lines,
  )
  push_max_check(
    failures,
    budget.path + " pub(all) declaration count",
    pub_all_lines,
    budget.max_pub_all_lines,
  )
  push_required_token_checks(
    failures,
    budget.path,
    text,
    budget.required_tokens,
  )
  push_forbidden_token_checks(
    failures,
    budget.path,
    text,
    budget.forbidden_tokens,
  )
}

///|
fn matching_signature_line(text : String, prefix : String) -> String? {
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix(prefix) {
      return Some(line)
    }
  }
  None
}

///|
fn validate_views_return_types(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/views/pkg.generated.mbti"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for rule in view_return_rules() {
    match matching_signature_line(text, rule.signature_prefix) {
      Some(line) =>
        if !line.contains(rule.return_token) {
          failures.push(
            path + ": " + rule.name + " must return " + rule.return_token,
          )
        }
      None =>
        failures.push(
          path + ": missing app-facing constructor " + rule.signature_prefix,
        )
    }
  }
}

///|
fn validate_root_facade_shape(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/pkg.generated.mbti"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  if count_lines_with_prefix(text, "import {") != 1 {
    failures.push(path + ": root facade should keep a single import block")
  }
  let allowed = root_facade_app_safe_aliases()
  let mut aliases = 0
  let alias_prefix = "pub using @core {type "
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix(alias_prefix) {
      aliases += 1
      let type_name = line[alias_prefix.length():line.length() - 1].to_owned()
      if !allowed.contains(type_name) {
        failures.push(
          path +
          ": root facade alias " +
          type_name +
          " is not app-safe allowlisted",
        )
      }
    }
  }
  if aliases != allowed.length() {
    failures.push(
      path +
      ": root facade should expose exactly the curated app-safe alias set; got \{aliases}, expected \{allowed.length()}",
    )
  }
}

///|
fn count_token_occurrences(text : String, token : String) -> Int {
  let mut count = 0
  let mut start = 0
  while start < text.length() {
    match text[start:].find(token) {
      Some(index) => {
        count += 1
        start += index + token.length()
      }
      None => break
    }
  }
  count
}

///|
fn validate_core_legacy_family_budgets(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/core/pkg.generated.mbti"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for budget in legacy_core_family_budgets() {
    let mut count = 0
    for token in budget.tokens {
      count += count_token_occurrences(text, token)
    }
    println(
      "api surface: core legacy family " +
      budget.label +
      " occurrences=\{count} max=\{budget.max_occurrences} target=\{budget.target_occurrences}",
    )
    if count > budget.max_occurrences {
      failures.push(
        path +
        ": core legacy family " +
        budget.label +
        " occurrences=\{count}, above ratchet max \{budget.max_occurrences}; move new API to views/widget/runtime/backend/host",
      )
    }
  }
}

///|
fn runtime_consumer_roots() -> Array[String] {
  [
    "benchmarks", "examples", "moui/backend", "moui/tests", "moui/views", "moui_devtools",
    "moui_tester", "website",
  ]
}

///|
fn backend_runtime_interface_paths() -> Array[String] {
  [
    "moui/backend/host/pkg.generated.mbti", "moui/backend/web/pkg.generated.mbti",
    "moui/backend/macos/pkg.generated.mbti", "moui/backend/windows/pkg.generated.mbti",
    "moui/backend/linux/pkg.generated.mbti", "moui/backend/macos/skia/pkg.generated.mbti",
    "moui/backend/windows/skia/pkg.generated.mbti", "moui/backend/linux/skia/pkg.generated.mbti",
    "moui/backend/macos/wgpu/pkg.generated.mbti", "moui/backend/windows/wgpu/pkg.generated.mbti",
    "moui/backend/linux/wgpu/pkg.generated.mbti",
  ]
}

///|
fn max_shared_app_runtime_imports() -> Int {
  1
}

///|
fn max_shared_app_core_imports() -> Int {
  5
}

///|
fn allowed_shared_app_core_imports() -> Array[String] {
  [
    "examples/markdown_editor/app/moon.pkg", "examples/mo_workbench/app/moon.pkg",
    "examples/pdf_workbench/app/moon.pkg", "examples/showcase/app/moon.pkg", "website/app/moon.pkg",
  ]
}

///|
fn allowed_shared_app_runtime_imports() -> Array[String] {
  ["examples/showcase/app/moon.pkg"]
}

///|
fn collect_shared_app_moon_pkgs(
  repo_root : String,
  paths : Array[String],
  failures : Array[String],
) -> Unit {
  let examples_root = @tools.resolve_path(repo_root, "examples")
  let entries = match read_dir_names(examples_root, "examples") {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      []
    }
  }
  for entry in entries {
    let path = "examples/" + entry + "/app/moon.pkg"
    if @tools.file_exists(@tools.resolve_path(repo_root, path)) {
      paths.push(path)
    }
  }
  let website_app = "website/app/moon.pkg"
  if @tools.file_exists(@tools.resolve_path(repo_root, website_app)) {
    paths.push(website_app)
  }
}

///|
fn moon_pkg_has_default_import(text : String, package_token : String) -> Bool {
  let mut in_import_block = false
  let mut block_contains_package = false
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if !in_import_block {
      if line == "import {" {
        in_import_block = true
        block_contains_package = false
      }
    } else {
      if line.contains(package_token) {
        block_contains_package = true
      }
      if line.has_prefix("}") {
        if block_contains_package &&
          !line.contains("for \"test\"") &&
          !line.contains("for \"wbtest\"") {
          return true
        }
        in_import_block = false
        block_contains_package = false
      }
    }
  }
  false
}

///|
fn core_control_consumer_roots() -> Array[String] {
  [
    "benchmarks", "examples", "moui/backend", "moui/tests", "moui_devtools", "moui_tester",
    "website",
  ]
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

///|
fn validate_runtime_entrypoint_usage(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  for root in runtime_consumer_roots() {
    collect_mbt_files(repo_root, root, files, failures)
  }
  let mut direct_core_runtime_uses = 0
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if text.contains("@core.AppRuntime") {
      direct_core_runtime_uses += 1
      failures.push(
        path +
        ": app/host runtime entrypoints must use @runtime.AppRuntime instead of @core.AppRuntime",
      )
    }
  }
  println(
    "api surface: direct @core.AppRuntime consumer files=\{direct_core_runtime_uses}",
  )
}

///|
fn validate_backend_runtime_interfaces(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let mut direct_core_runtime_interfaces = 0
  for path in backend_runtime_interface_paths() {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if text.contains("@core.AppRuntime") ||
      text.contains("@wzzc-dev/moui/core.AppRuntime") ||
      text.contains("wzzc-dev/moui/core.AppRuntime") {
      direct_core_runtime_interfaces += 1
      failures.push(
        path +
        ": backend public interfaces must expose @runtime.AppRuntime, not @core.AppRuntime",
      )
    }
  }
  println(
    "api surface: backend @core.AppRuntime interface files=\{direct_core_runtime_interfaces}",
  )
}

///|
fn validate_shared_app_runtime_imports(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let paths : Array[String] = []
  collect_shared_app_moon_pkgs(repo_root, paths, failures)
  let mut runtime_imports = 0
  let mut unauthorized_runtime_imports = 0
  let allowed = allowed_shared_app_runtime_imports()
  for path in paths {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if moon_pkg_has_default_import(text, "\"wzzc-dev/moui/runtime\"") {
      runtime_imports += 1
      if !allowed.contains(path) {
        unauthorized_runtime_imports += 1
        failures.push(
          path +
          ": shared app packages should not default-import runtime; add only explicit diagnostics/platform exceptions",
        )
      }
    }
  }
  let max_runtime_imports = max_shared_app_runtime_imports()
  if runtime_imports > max_runtime_imports {
    failures.push(
      "shared app default runtime imports are \{runtime_imports}, above budget \{max_runtime_imports}",
    )
  }
  println(
    "api surface: shared app default runtime imports=\{runtime_imports}/\{max_runtime_imports}; unauthorized=\{unauthorized_runtime_imports}",
  )
}

///|
fn validate_shared_app_core_imports(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let paths : Array[String] = []
  collect_shared_app_moon_pkgs(repo_root, paths, failures)
  let mut core_imports = 0
  let mut unauthorized_core_imports = 0
  let allowed = allowed_shared_app_core_imports()
  for path in paths {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if moon_pkg_has_default_import(text, "\"wzzc-dev/moui/core\"") {
      core_imports += 1
      if !allowed.contains(path) {
        unauthorized_core_imports += 1
        failures.push(
          path +
          ": shared app packages should default to moui + views; add core only to the explicit advanced-app allowlist",
        )
      }
    }
  }
  let max_core_imports = max_shared_app_core_imports()
  if core_imports > max_core_imports {
    failures.push(
      "shared app default core imports are \{core_imports}, above budget \{max_core_imports}",
    )
  }
  println(
    "api surface: shared app default core imports=\{core_imports}/\{max_core_imports}; unauthorized=\{unauthorized_core_imports}",
  )
}

///|
fn validate_core_control_entrypoint_usage(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  for root in core_control_consumer_roots() {
    collect_mbt_files(repo_root, root, files, failures)
  }
  let mut direct_core_control_uses = 0
  let tokens = forbidden_core_control_tokens()
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for rule in tokens {
      if text.contains(rule.token) {
        direct_core_control_uses += 1
        failures.push(
          path +
          ": app/host/test code must use moui/views for view construction (" +
          rule.label +
          ") instead of " +
          rule.token,
        )
      }
    }
  }
  println(
    "api surface: direct core view constructor uses=\{direct_core_control_uses}",
  )
}

///|
fn validate_runtime_source_boundaries(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_mbt_files(repo_root, "moui/runtime", files, failures)
  let mut core_app_runtime_uses = 0
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if text.contains("@core.AppRuntime") ||
      text.contains("inner : @core.AppRuntime") ||
      text.contains("@core.RuntimeKernel") {
      core_app_runtime_uses += 1
      failures.push(
        path +
        ": runtime must own state directly; do not wrap @core.AppRuntime or @core.RuntimeKernel",
      )
    }
  }
  println(
    "api surface: runtime @core.AppRuntime source uses=\{core_app_runtime_uses}",
  )
}

///|
fn validate_core_program_runtime_ownership(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_mbt_files(repo_root, "moui/core", files, failures)
  let mut source_hits = 0
  let tokens = forbidden_core_program_runtime_source_tokens()
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for rule in tokens {
      if text.contains(rule.token) {
        source_hits += 1
        failures.push(
          path +
          ": program runtime implementation belongs in moui/runtime (" +
          rule.label +
          ") instead of core",
        )
      }
    }
  }
  let mut stale_files = 0
  for path in forbidden_core_program_runtime_source_paths() {
    if @tools.file_exists(@tools.resolve_path(repo_root, path)) {
      stale_files += 1
      failures.push(
        path + ": program runtime implementation file belongs in moui/runtime",
      )
    }
  }
  println(
    "api surface: core program-runtime source tokens=\{source_hits}; stale files=\{stale_files}",
  )
}

///|
fn validate_core_runtime_boundary(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_mbt_files(repo_root, "moui/core", files, failures)
  let mut source_hits = 0
  let tokens = forbidden_core_runtime_boundary_source_tokens()
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for rule in tokens {
      if text.contains(rule.token) {
        source_hits += 1
        failures.push(
          path +
          ": runtime implementation belongs in moui/runtime (" +
          rule.label +
          ") instead of core",
        )
      }
    }
  }
  let mut stale_files = 0
  for path in forbidden_core_runtime_boundary_source_paths() {
    if @tools.file_exists(@tools.resolve_path(repo_root, path)) {
      stale_files += 1
      failures.push(
        path + ": runtime implementation file belongs in moui/runtime",
      )
    }
  }
  println(
    "api surface: core runtime-boundary source tokens=\{source_hits}; stale files=\{stale_files}",
  )
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for budget in package_budgets() {
    validate_package_budget(repo_root, budget, failures)
  }
  validate_root_facade_shape(repo_root, failures)
  validate_core_legacy_family_budgets(repo_root, failures)
  validate_views_return_types(repo_root, failures)
  validate_runtime_source_boundaries(repo_root, failures)
  validate_core_program_runtime_ownership(repo_root, failures)
  validate_core_runtime_boundary(repo_root, failures)
  validate_backend_runtime_interfaces(repo_root, failures)
  validate_runtime_entrypoint_usage(repo_root, failures)
  validate_shared_app_runtime_imports(repo_root, failures)
  validate_shared_app_core_imports(repo_root, failures)
  validate_core_control_entrypoint_usage(repo_root, failures)
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("api surface guardrails: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
        1
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
