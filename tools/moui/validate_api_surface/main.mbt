///|
struct CliOptions {
  repo_root : String
  report_path : String
  help : Bool
}

///|
struct ApiPackageReport {
  label : String
  path : String
  lines : Int
  public_declarations : Int
  pub_all_declarations : Int
} derive(ToJson)

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
    #|Usage: tools/moui/validate_api_surface [--repo-root PATH] [--report PATH]
    #|
    #|Audits generated pkg.generated.mbti files for MoUI API-surface guardrails:
    #|package size budgets, root facade boundaries, and app-facing view return
    #|types. Run moon info before this check when public API may have changed.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  --report PATH      Write a schema v1 JSON package-count report.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let report_path = Ref("")
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
      "--report" => {
        if index + 1 >= args.length() {
          return Err("missing value for --report")
        }
        report_path.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, report_path: report_path.val, help: help.val })
}

///|
/// App-loop types forwarded by root `wzzc-dev/moui` (not a subpackage).
fn root_app_shape_tokens() -> Array[String] {
  [
    "View", "Program", "ProgramCommand", "Effect", "Subscription", "Theme", "Environment",
    "ViewEnvironment", "SemanticId", "ControlledValue", "ScrollRequest", "FocusRequest",
  ]
}

///|
fn root_facade_required_tokens() -> Array[String] {
  sugar_required_tokens(root_app_shape_tokens())
}

///|
/// Types forwarded by the `moui/geometry` domain sugar package.
fn sugar_geometry_tokens() -> Array[String] {
  [
    "Point", "Size", "Rect", "Insets", "Constraints", "Axis", "Alignment", "MainAxisAlignment",
    "CrossAxisAlignment",
  ]
}

///|
/// Types forwarded by the `moui/graphics` domain sugar package.
fn sugar_graphics_tokens() -> Array[String] {
  [
    "Color", "Brush", "BorderStyle", "ShadowStyle", "RoundedRect", "PathSpec", "PathVerb",
    "ImageRun", "ImageFit", "BlendMode", "LayerSpec", "LayerMask", "FilterEffect",
    "ShadowSpec", "Transform2D", "ShaderEffectSpec",
  ]
}

///|
/// Types forwarded by the `moui/animation` domain facade package.
fn sugar_animation_tokens() -> Array[String] {
  ["Easing", "TransitionSpec", "TransitionStyle"]
}

///|
/// Types forwarded by the `moui/text` domain sugar package.
fn sugar_text_tokens() -> Array[String] {
  [
    "FontSpec", "FontFamily", "TextRange", "TextAlign", "FontFamilyStack", "TextRun",
  ]
}

///|
/// Types forwarded by the `moui/state` domain sugar package.
fn sugar_state_tokens() -> Array[String] {
  ["ColorScheme", "LayoutDirection", "FocusScope", "FocusScopeItem"]
}

///|
fn sugar_required_tokens(type_names : Array[String]) -> Array[String] {
  let tokens = ["\"wzzc-dev/moui/core\""]
  for type_name in type_names {
    tokens.push("pub using @core {type \{type_name}}")
  }
  tokens
}

///|
/// Returns `pub using @core {type X}` forbidden tokens for a sugar package:
/// every type forwarded by the *other* four sugar packages plus the
/// intentionally-unsugared low-frequency tokens (`CommandIntent`,
/// `FontFamilyStack`, `AccessibilityContrast`, ...). This prevents a sugar
/// package from leaking a type that belongs to a different domain or that the
/// policy leaves on `@core` direct.
fn sugar_cross_domain_forbidden_tokens(
  own_tokens : Array[String],
) -> Array[String] {
  let all = [
    "View", "Program", "Effect", "Subscription", "Theme", "Environment", "ViewEnvironment",
    "Point", "Size", "Rect", "Insets", "Constraints", "Axis", "Alignment", "MainAxisAlignment",
    "CrossAxisAlignment", "Color", "Brush", "BorderStyle", "ShadowStyle", "RoundedRect",
    "PathSpec", "PathVerb", "ImageRun", "ImageFit", "BlendMode", "LayerSpec", "LayerMask",
    "FilterEffect", "ShadowSpec", "Transform2D", "ShaderEffectSpec", "Easing", "TransitionSpec",
    "TransitionStyle", "FontSpec", "FontFamily", "TextRange", "TextAlign", "State",
    "Binding", "DerivedState", "ScrollState", "FocusState", "NavigationState", "ColorScheme",
    "LayoutDirection", "FocusScope", "FocusScopeItem", "CommandIntent", "KeyboardShortcut",
    "KeyModifiers", "DateValue", "FontFamilyStack", "AccessibilityContrast", "ContentSizeCategory",
    "ActionCommand", "ActionCommandMap", "CommandBinding", "ComponentContext", "ElementId",
    "SemanticsRole", "SemanticId",
  ]
  let forbidden : Array[String] = []
  for type_name in all {
    if !own_tokens.contains(type_name) {
      forbidden.push("pub using @core {type \{type_name}}")
    }
  }
  forbidden
}

///|
fn views_facade_core_alias_tokens() -> Array[String] {
  [
    // Control/command/theme workflow surface only — not domain value types.
    "ActionCommand", "ActionCommandMap", "CommandBinding", "CommandIntent", "KeyModifiers",
    "KeyboardShortcut", "ColorPalette", "TypographyScale",
  ]
}

///|
fn views_facade_host_alias_tokens() -> Array[String] {
  []
}

///|
fn views_facade_required_tokens() -> Array[String] {
  let tokens = [
    "\"wzzc-dev/moui/core\"", "pub fn[Msg] button(", "pub fn[Msg] column(", "pub using @style {type ButtonStyle}",
    "pub fn[Msg] checkbox_control(", "pub fn[Msg] navigation_stack_selected(", "pub using @style {type DatePickerMode}",
    "pub fn default_theme()", "pub fn light_theme()", "pub fn dark_theme()", "pub fn[Msg] text(",
    "pub fn[Msg] empty()", "pub fn[Msg] spacer(", "pub fn[Msg] picker(", "pub fn picker_item(",
    "pub fn[Msg] datepicker(", "pub fn[Msg] custom_layout(", "pub fn[Msg] custom_children_layout(",
    "pub fn[Msg] row(",
  ]
  for type_name in views_facade_core_alias_tokens() {
    tokens.push("pub using @core {type \{type_name}}")
  }
  for type_name in views_facade_host_alias_tokens() {
    tokens.push("pub using @host {type \{type_name}}")
  }
  tokens
}

///|
fn package_budgets() -> Array[PackageBudget] {
  let budgets = [
    {
      label: "root facade (app-loop sugar)",
      path: "moui/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui\"",
      max_lines: 40,
      max_pub_lines: 12,
      max_pub_all_lines: 0,
      required_tokens: root_facade_required_tokens(),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(
        root_app_shape_tokens(),
      ),
    },
    {
      label: "geometry sugar",
      path: "moui/geometry/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/geometry\"",
      max_lines: 40,
      max_pub_lines: 12,
      max_pub_all_lines: 0,
      required_tokens: sugar_required_tokens(sugar_geometry_tokens()),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(
        sugar_geometry_tokens(),
      ),
    },
    {
      label: "graphics sugar",
      path: "moui/graphics/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/graphics\"",
      max_lines: 80,
      max_pub_lines: 20,
      max_pub_all_lines: 0,
      required_tokens: sugar_required_tokens(sugar_graphics_tokens()),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(
        sugar_graphics_tokens(),
      ),
    },
    {
      label: "animation sugar",
      path: "moui/animation/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/animation\"",
      max_lines: 24,
      max_pub_lines: 4,
      max_pub_all_lines: 0,
      required_tokens: sugar_required_tokens(sugar_animation_tokens()),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(
        sugar_animation_tokens(),
      ),
    },
    {
      label: "text sugar",
      path: "moui/text/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/text\"",
      max_lines: 30,
      max_pub_lines: 8,
      max_pub_all_lines: 0,
      required_tokens: sugar_required_tokens(sugar_text_tokens()),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(sugar_text_tokens()),
    },
    {
      label: "state sugar",
      path: "moui/state/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/state\"",
      max_lines: 28,
      max_pub_lines: 5,
      max_pub_all_lines: 0,
      required_tokens: sugar_required_tokens(sugar_state_tokens()),
      forbidden_tokens: sugar_cross_domain_forbidden_tokens(
        sugar_state_tokens(),
      ),
    },
    {
      label: "runtime facade",
      path: "moui/runtime/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/runtime\"",
      // AppBuilder, PlatformEntry, and AppLaunchRequest are the public
      // application/platform composition contract.
      max_lines: 864,
      max_pub_lines: 468,
      max_pub_all_lines: 35,
      required_tokens: [
        "\"wzzc-dev/moui/core\"", "\"wzzc-dev/moui/backend\"", "\"wzzc-dev/moui/render\"",
        "pub struct AppRuntime", "pub fn[Model, Msg] new_program(", "pub fn[Model, Msg] new_program_with_dimensions(",
        "pub fn[Msg] new_view(", "pub fn[Model, Msg] AppRuntime::new_program(", "pub fn[Msg] AppRuntime::new_view(",
        "pub fn AppRuntime::draw_frame(", "pub fn AppRuntime::inspector_snapshot(Self) -> InspectorSnapshot",
        "pub fn AppRuntime::program_runtime_snapshot(Self) -> ProgramRuntimeSnapshot",
        "pub fn AppRuntime::read_semantics(", "pub fn AppRuntime::perform_semantics_action(",
        "pub struct SemanticsSnapshot", "pub struct SemanticsDelta", "pub(all) enum SemanticsActionDispatchError",
        "pub struct InspectorSnapshot", "pub struct ProgramRuntimeSnapshot", "pub struct RuntimeInspectorSnapshot",
        "pub struct RenderInspectorSnapshot", "pub struct ViewTreeInspectorSnapshot",
        "pub(all) enum EffectTaskCancelReason", "pub(all) enum SubscriptionCancelReason",
        "pub struct EffectPlanSummary", "pub struct SubscriptionPlanSummary", "pub fn InspectorSnapshot::runtime(Self)",
        "pub fn ProgramRuntimeSnapshot::dispatched_count(Self)", "pub fn[Msg] effect_plan_summary(",
        "pub fn[Msg] subscription_plan_summary(",
      ],
      forbidden_tokens: [
        "moui_theme", "RuntimeState", "ViewNode", "VirtualNode", "ErasedViewNode",
        "ViewSpec", "pub using @core {type AppRuntime}", "inner : @core.AppRuntime",
        "core_inspector_snapshot", "core_program_runtime_snapshot", "@core.InspectorSnapshot",
        "@core.ProgramRuntimeSnapshot",
      ],
    },
    {
      label: "core",
      path: "moui/core/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/core\"",
      // SurfaceMetrics is the single backend/render-neutral surface DTO.
      // Semantics DTO expansion adds roles, relations, ranges, text metadata,
      // live announcements, and typed actions in one intentional migration.
      max_lines: 2120,
      max_pub_lines: 560,
      max_pub_all_lines: 187,
      required_tokens: [
        "pub struct View[Msg]", "View::map", "pub(all) struct Theme", "type Program[Model, Msg]",
        "pub(all) struct SurfaceMetrics", "SurfaceMetrics::from_logical", "SurfaceMetrics::new",
        "pub(all) enum Effect", "type Subscription", "pub(all) struct DrawFrame",
        "pub(open) trait ViewNode", "View::from_node", "View::identity", "View::children",
        "View::layout", "View::paint", "View::event", "View::text_command_result",
        "View::accepts_focus", "pub(all) struct ViewIdentity", "pub(all) struct ViewLayoutContext",
        "pub(all) struct ViewLayoutResult", "pub(all) struct ViewPaintContext", "pub(all) struct ViewPaintPlan",
        "pub(all) struct ViewPaintLayer", "pub(all) struct ViewEventContext", "pub(all) struct ViewEventResult",
        "pub(all) enum ViewDirtyHint", "ViewClean", "ViewPaintDirty", "pub(all) struct ViewTextCommandResult",
        "pub(all) struct ViewSemanticsInfo", "pub(all) struct ViewStateContext",
        "pub struct DeclarationKey", "pub struct ViewDeclaration", "pub struct SemanticId",
        "pub struct SemanticsNodeId", "pub struct SemanticsGeneration", "pub(all) enum SemanticsActionKind",
        "pub(all) enum SemanticsAction", "pub(open) trait ViewStateValue", "pub struct ViewStateSlot",
        "pub struct ViewStateSlots", "ViewStateContext::read_slot", "ViewStateContext::with_slot",
        "ViewStateContext::without_slot",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui_theme", "\"wzzc-dev/moui_skia_renderer\"", "SkiaRasterRenderer",
        "VirtualNode", "View::virtual_node", "View::view_node", "View::virtual_node_ops",
        "View::view_node_ops", "View::ops", "View::custom", "View::node(", "pub struct ViewNode",
        "pub(all) struct ViewNode", "ViewNode::new", "type ViewNode[", "View::empty(",
        "View::text(", "View::button(", "View::image(", "View::web_view(", "View::flex(",
        "View::spacer(", "View::frame_node(", "View::stack(", "View::scroll(", "View::grid(",
        "View::list(", "View::custom_view(", "View::custom_children_layout(", "View::component(",
        "View::checkbox(", "View::controlled_checkbox(", "View::text_field(", "View::controlled_text_field(",
        "View::rich_text_editor(", "View::controlled_rich_text_editor(", "View::picker(",
        "View::controlled_picker(", "View::datepicker(", "View::controlled_datepicker(",
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
        "type ElementNode", "ElementNode::", "type ElementTree", "ElementTree::",
        "type ViewSpec", "pub(all) enum ViewSpec", "pub enum ViewSpec", "pub(all) struct InspectorSnapshot",
        "pub(all) struct ProgramRuntimeSnapshot", "pub(all) struct RuntimeInspectorSnapshot",
        "pub(all) struct RenderInspectorSnapshot", "pub(all) struct ViewTreeInspectorSnapshot",
        "pub(all) struct LayoutInspectorSnapshot", "pub(all) struct SemanticsInspectorSnapshot",
        "pub(all) struct ViewInspectorSummary", "DatePickerMode", "EffectPlanSummary",
        "SubscriptionPlanSummary", "EffectRuntimeOp", "Effect::plan_summary(", "Effect::runtime_ops(",
        "Subscription::plan_summary(", "Theme::default(", "Environment::default(",
        "BuildContext", "ComponentContext::new(", "type FrameProfile", "FrameProfile::capture(",
        "InspectorSnapshot::from_runtime(", "RuntimeInspectorSnapshot::from_runtime(",
        "ViewTreeInspectorSnapshot::from_runtime(", "LayoutInspectorSnapshot::from_runtime(",
        "RenderInspectorSnapshot::from_runtime(", "SemanticsInspectorSnapshot::from_runtime(",
        "RouteFocusStore::restore(", "RouteFocusStore::restore_location(", "ComponentContext::new_for_runtime",
        "RichText", "SheetPresentationMode", "type ElementId", "ElementId::",
      ],
    },
    {
      label: "views facade",
      path: "moui/views/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/views\"",
      max_lines: 630,
      max_pub_lines: 310,
      max_pub_all_lines: 0,
      required_tokens: views_facade_required_tokens(),
      forbidden_tokens: [
        "pub using @core {type Color}", "pub using @core {type ColorScheme}", "pub using @core {type Point}",
        "pub using @core {type Brush}", "pub using @core {type FontSpec}", "pub using @core {type State}",
        "pub using @core {type Rect}", "ViewSpec", "ViewNode", "VirtualNode", "RuntimeState",
        "HostWindowRenderer", "SkiaRasterRenderer", "RichText", "rich_text_", "markdown_editor",
        "pub fn[Msg] raw_", "RawPickerOption", "RawDatePickerDisplayMode", "pub using @core {type ComponentContext}",
        "pub using @core {type FocusScope}", "pub using @core {type FocusScopeItem}",
        "pub using @core {type FontFamilyStack}", "pub using @core {type ImageFit}",
        "pub using @core {type ImageRun}", "pub using @core {type TextRun}", "pub using @core {type BlendMode}",
        "pub using @core {type Easing}", "pub using @core {type FilterEffect}", "pub using @core {type LayerMask}",
        "pub using @core {type LayerSpec}", "pub using @core {type PathSpec}", "pub using @core {type PathVerb}",
        "pub using @core {type RoundedRect}", "pub using @core {type ShaderEffectSpec}",
        "pub using @core {type ShadowSpec}", "pub using @core {type Transform2D}",
        "pub using @core {type TransitionSpec}", "pub using @core {type TransitionStyle}",
        "pub using @core {type ElementId}", "pub using @core {type SemanticsRole}",
      ],
    },
    {
      label: "backend protocols",
      path: "moui/backend/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend\"",
      max_lines: 420,
      max_pub_lines: 80,
      max_pub_all_lines: 40,
      required_tokens: [
        "pub(all) enum Event", "pub(all) struct WindowId", "pub struct WindowRequests",
        "pub struct HostServiceBridge", "pub struct PlatformViewPlugin",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui_skia_renderer\"", "\"wzzc-dev/moui_wgpu_renderer\"", "SkiaRasterRenderer",
        "WindowRegistry", "WindowRequestQueue", "ServiceAsyncQueue", "Coordinator",
      ],
    },
    {
      label: "render protocols",
      path: "moui/render/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render\"",
      // HostSurface erases native handle meaning; RendererProvider binds one
      // per-window RendererSession at the composition boundary.
      max_lines: 500,
      max_pub_lines: 150,
      max_pub_all_lines: 31,
      required_tokens: [
        "RendererBackendKind", "RendererDescriptor", "RendererProvider", "RendererBindResult",
        "RendererSession", "HostSurface", "NativeSurface", "FrameToken", "RenderFrameSubmission",
        "RendererEvent", "RenderFrameResult",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend\"", "SkiaRasterRenderer", "RendererProviderRegistry",
        "ImageResourceLifecycle", "AsyncImageLoader", "ImageResourceRepaintTracker",
        "RendererFactory", "RendererProviderBinding", "WindowRenderer", "SurfaceDescriptor",
        "SurfaceRoute", "Metal", "HWND", "Wayland", "Vulkan", "EGL", "D3D",
      ],
    },
    {
      label: "render common",
      path: "moui/render/common/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render/common\"",
      max_lines: 350,
      max_pub_lines: 110,
      max_pub_all_lines: 12,
      required_tokens: [
        "pub struct ImageResourceLifecycle", "pub fn resolve_renderer", "pub fn renderer_feature_capability",
        "pub struct GpuRenderWorker",
      ],
      forbidden_tokens: ["\"wzzc-dev/moui/backend\"", "SkiaRasterRenderer"],
    },
    {
      label: "skia renderer",
      path: "moui_skia_renderer/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui_skia_renderer\"",
      max_lines: 235,
      max_pub_lines: 121,
      max_pub_all_lines: 7,
      required_tokens: [
        "SkiaRasterRenderer", "skia_available", "skia_image_load_completion",
      ],
      forbidden_tokens: ["\"wzzc-dev/moui/backend\""],
    },
    {
      label: "sun renderer",
      path: "moui_sun_renderer/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui_sun_renderer\"",
      max_lines: 242,
      max_pub_lines: 144,
      max_pub_all_lines: 1,
      required_tokens: [
        "SunRasterRenderer", "SunRendererError", "SunPixelFrame",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend\"", "SkiaRasterRenderer", "WgpuRenderer",
      ],
    },
    {
      label: "webgpu adapter",
      path: "moui_web_renderer/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui_web_renderer\"",
      max_lines: 160,
      max_pub_lines: 69,
      max_pub_all_lines: 2,
      required_tokens: [
        "WebGpuHostCall", "WebGpuHostError", "WebGpuWasmRenderer",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend\"", "SkiaRasterRenderer", "WgpuRenderer",
      ],
    },
    {
      label: "native wgpu renderer",
      path: "moui_wgpu_renderer/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui_wgpu_renderer\"",
      max_lines: 150,
      max_pub_lines: 66,
      max_pub_all_lines: 3,
      required_tokens: [
        "NativeTextEngine", "HostWgpuSurface", "NativeTextLayout",
      ],
      forbidden_tokens: ["\"wzzc-dev/moui/backend\"", "SkiaRasterRenderer"],
    },
    {
      label: "native text protocol",
      path: "moui_wgpu_renderer/text_protocol/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui_wgpu_renderer/text_protocol\"",
      max_lines: 60,
      max_pub_lines: 23,
      max_pub_all_lines: 0,
      required_tokens: [
        "NativeFontRegistrationPayload", "native_measure_layout_from_bytes",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend\"", "HostWindowRenderer", "WgpuRenderer", "HostWgpuSurface",
        "RendererHandle",
      ],
    },
  ]
  budgets.append(backend_common_package_budgets())
  budgets
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
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "form workflow helpers",
      tokens: [
        "FormFieldError", "FormValidationResult", "FormValidationSummary", "FormValidationStyle",
        "FormFieldState", "FormValidationRule", "FormController", "required_field",
        "validate_form",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "rich text editor domain model",
      tokens: [
        "RichTextDocument", "RichTextBlock", "RichTextRun", "RichTextInputTransform",
        "RichTextFormatter", "RichTextTable", "RichTextTableCell", "RichTextSourceRange",
        "RichTextDecoration", "rich_text_document_", "rich_text_editor_",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "WebView platform service model",
      tokens: [
        "WebViewSpec", "WebViewCommand", "WebViewEvent", "WebViewNavigationPolicy",
        "PlatformViewPlacement::web_view", "WebView(String",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "routing and history controller",
      tokens: [
        "RouteHistoryState", "RouteDescriptor", "RouterState", "RouteFocusStore",
        "RouteLocation", "RouterSnapshot", "resolve_route",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "datepicker control semantics",
      tokens: ["DatePickerMode", "DatePickerDisplayMode"],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "runtime diagnostics summary contract",
      tokens: [
        "EffectPlanSummary", "SubscriptionPlanSummary", "EffectRuntimeOp", "plan_summary",
        "runtime_ops",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "design default theme helpers",
      tokens: [
        "Theme::default", "Environment::default", "Theme::light", "Theme::dark",
        "default_theme", "light_theme", "dark_theme",
      ],
      max_occurrences: 0,
      target_occurrences: 0,
    },
    {
      label: "runtime diagnostics snapshots",
      tokens: [
        "RuntimeInspectorSnapshot", "ProgramRuntimeSnapshot", "ViewTreeInspectorSnapshot",
        "RenderInspectorSnapshot", "InspectorSnapshot", "LayoutInspectorSnapshot",
        "SemanticsInspectorSnapshot", "ViewInspectorSummary",
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
fn collect_moon_pkg_files(
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
        collect_moon_pkg_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) && entry == "moon.pkg" {
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
  reports : Array[ApiPackageReport],
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
  reports.push({
    label: budget.label,
    path: budget.path,
    lines,
    public_declarations: pub_lines,
    pub_all_declarations: pub_all_lines,
  })
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
/// Root `wzzc-dev/moui` forwards only the curated app-loop alias set.
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
  let allowed = root_app_shape_tokens()
  let alias_prefix = "pub using @core {type "
  let mut aliases = 0
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
          " is not in app-loop allowlist",
        )
      }
    }
  }
  if aliases != allowed.length() {
    failures.push(
      path +
      ": root facade should expose exactly the app-loop alias set; got \{aliases}, expected \{allowed.length()}",
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
        " occurrences=\{count}, above ratchet max \{budget.max_occurrences}; move new API to views/runtime/backend",
      )
    }
  }
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
    "benchmarks", "examples", "moui/backend", "moui_tests", "moui_devtools", "website",
  ]
}

///|
fn app_api_hygiene_roots() -> Array[String] {
  ["examples", "docs", "website"]
}

///|
fn app_api_hygiene_forbidden_tokens() -> Array[ForbiddenSourceToken] {
  [
    { label: "Program type", token: "@core.Program[" },
    { label: "Program constructor", token: "@core.Program::" },
    { label: "View type", token: "@core.View[" },
    { label: "View constructor", token: "@core.View::" },
    { label: "State type", token: "@core.State[" },
    { label: "State constructor", token: "@core.State::" },
    { label: "Binding type", token: "@core.Binding[" },
    { label: "Binding constructor", token: "@core.Binding::" },
    { label: "Effect type", token: "@core.Effect[" },
    { label: "Effect constructor", token: "@core.Effect::" },
    { label: "Subscription type", token: "@core.Subscription[" },
    { label: "Subscription constructor", token: "@core.Subscription::" },
  ]
}

///|
fn app_api_hygiene_test_path(path : String) -> Bool {
  path.has_suffix("_test.mbt") || path.has_suffix("_wbtest.mbt")
}

///|
fn app_api_hygiene_allowed_core_view_line(line : String) -> Bool {
  line.contains("@core.View::from_node") ||
  line.contains("@core.View::primitive_")
}

///|
fn app_api_hygiene_line_allowed(path : String, line : String) -> Bool {
  app_api_hygiene_test_path(path) ||
  app_api_hygiene_allowed_core_view_line(line)
}

///|
fn collect_app_api_hygiene_files(
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
        collect_app_api_hygiene_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) &&
      (relative.has_suffix(".mbt") || relative.has_suffix(".md")) &&
      !relative.has_suffix("pkg.generated.mbti") {
      files.push(relative)
    }
  }
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
          ": shared app packages should prefer @moui/domain facades; default-import core only for advanced kernel/diagnostics use",
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
fn validate_app_api_hygiene(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = ["README.mbt.md"]
  for root in app_api_hygiene_roots() {
    collect_app_api_hygiene_files(repo_root, root, files, failures)
  }
  let mut direct_core_app_api_uses = 0
  let tokens = app_api_hygiene_forbidden_tokens()
  for path in files {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let mut line_number = 1
    for line_view in text.split("\n") {
      let line = line_view.to_owned()
      if !app_api_hygiene_line_allowed(path, line) {
        for rule in tokens {
          if line.contains(rule.token) {
            direct_core_app_api_uses += 1
            failures.push(
              path +
              ":\{line_number}: ordinary app/docs examples should use domain sugar (@app/@state/@geometry/@graphics/@text) for " +
              rule.label +
              " instead of " +
              rule.token,
            )
          }
        }
      }
      line_number += 1
    }
  }
  println(
    "api surface: direct @core app-facing source/docs uses=\{direct_core_app_api_uses}",
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
fn validate_core_webview_ownership(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_mbt_files(repo_root, "moui/core", files, failures)
  let mut source_hits = 0
  let tokens = forbidden_core_webview_source_tokens()
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
          ": WebView command/event/policy/spec ownership belongs in moui/backend (" +
          rule.label +
          ") instead of core",
        )
      }
    }
  }
  println("api surface: core WebView ownership source tokens=\{source_hits}")
}

///|
fn validate_core_routing_ownership(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  collect_mbt_files(repo_root, "moui/core", files, failures)
  let mut source_hits = 0
  let tokens = forbidden_core_routing_source_tokens()
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
          ": routing/history ownership belongs in moui/views (" +
          rule.label +
          ") instead of core",
        )
      }
    }
  }
  let stale_path = "moui/core/routing.mbt"
  if @tools.file_exists(@tools.resolve_path(repo_root, stale_path)) {
    source_hits += 1
    failures.push(
      stale_path + ": routing/history implementation belongs in moui/views",
    )
  }
  println("api surface: core routing ownership source tokens=\{source_hits}")
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
/// Model B (ADR 0014): `core` owns domain value types; domain packages are
/// facades over `core`. `core` must never import domain packages, and each
/// domain package must import only `core` (no domain cross-imports).
fn validate_domain_facade_dependency_direction(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let domain_packages = ["geometry", "graphics", "animation", "text", "state"]
  let core_pkg = "moui/core/moon.pkg"
  let core_text = match read_repo_text(repo_root, core_pkg) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for domain in domain_packages {
    let token = "\"wzzc-dev/moui/" + domain + "\""
    if core_text.contains(token) {
      failures.push(
        core_pkg +
        ": core must not import domain package " +
        token +
        " (ADR 0014 model B)",
      )
    }
  }
  for domain in domain_packages {
    let path = "moui/" + domain + "/moon.pkg"
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if !text.contains("\"wzzc-dev/moui/core\"") {
      failures.push(
        path + ": domain facade must import \"wzzc-dev/moui/core\" (ADR 0014)",
      )
    }
    for other in domain_packages {
      if other == domain {
        continue
      }
      let token = "\"wzzc-dev/moui/" + other + "\""
      if text.contains(token) {
        failures.push(
          path +
          ": domain facade must not cross-import " +
          token +
          " (ADR 0014 model B)",
        )
      }
    }
  }
  println("api surface: domain facade dependency direction checked")
}

///|
fn run_checks(
  repo_root : String,
  reports : Array[ApiPackageReport],
) -> Array[String] {
  let failures : Array[String] = []
  for budget in package_budgets() {
    validate_package_budget(repo_root, budget, failures, reports)
  }
  validate_api_surface_classifications(repo_root, failures)
  validate_root_facade_shape(repo_root, failures)
  validate_domain_facade_dependency_direction(repo_root, failures)
  validate_core_legacy_family_budgets(repo_root, failures)
  validate_views_return_types(repo_root, failures)
  validate_runtime_source_boundaries(repo_root, failures)
  validate_core_program_runtime_ownership(repo_root, failures)
  validate_core_webview_ownership(repo_root, failures)
  validate_core_routing_ownership(repo_root, failures)
  validate_core_runtime_boundary(repo_root, failures)
  validate_backend_runtime_interfaces(repo_root, failures)
  validate_embedded_runtime_internal_imports(repo_root, failures)
  validate_host_service_internal_imports(repo_root, failures)
  validate_runtime_entrypoint_usage(repo_root, failures)
  validate_shared_app_runtime_imports(repo_root, failures)
  validate_shared_app_core_imports(repo_root, failures)
  validate_core_control_entrypoint_usage(repo_root, failures)
  validate_app_api_hygiene(repo_root, failures)
  failures
}

///|
fn write_api_package_report(
  repo_root : String,
  report_path : String,
  reports : Array[ApiPackageReport],
) -> Result[Unit, String] {
  if report_path == "" {
    return Ok(())
  }
  let path = @tools.resolve_path(repo_root, report_path)
  let text = ({ "schemaVersion": 1, "packages": reports.to_json() } : Json).stringify() +
    "\n"
  @tools.write_text_file(path, text, "API surface report")
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let reports : Array[ApiPackageReport] = []
      let failures = run_checks(options.repo_root, reports)
      match
        write_api_package_report(
          options.repo_root,
          options.report_path,
          reports,
        ) {
        Err(message) => failures.push(message)
        Ok(_) => ()
      }
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
