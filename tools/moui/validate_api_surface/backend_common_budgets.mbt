///|
fn backend_common_package_budgets() -> Array[PackageBudget] {
  [
    {
      label: "backend common",
      path: "moui/backend/common/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common\"",
      max_lines: 58,
      max_pub_lines: 18,
      max_pub_all_lines: 0,
      required_tokens: [
        "pub fn attach_window_surface", "pub fn dispatch_host_event", "pub fn run_window_redraw",
        "pub fn dispose_window",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui_skia_renderer\"", "\"wzzc-dev/moui_wgpu_renderer\"", "SkiaRasterRenderer",
        "WindowCoordinator", "FrameCoordinator", "EmbeddedWindowCoordinator",
      ],
    },
    {
      label: "backend common lifecycle owner",
      path: "moui/backend/common/lifecycle/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common/lifecycle\"",
      max_lines: 255,
      max_pub_lines: 155,
      max_pub_all_lines: 3,
      required_tokens: [
        "pub struct WindowLifecycle", "pub struct EmbeddedLifecycle", "pub struct WindowRegistry",
        "pub struct WindowRequestQueue",
      ],
      forbidden_tokens: [
        "RendererSession", "WindowFrameState", "WindowImageState",
      ],
    },
    {
      label: "backend common frame owner",
      path: "moui/backend/common/frame/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common/frame\"",
      max_lines: 64,
      max_pub_lines: 26,
      max_pub_all_lines: 0,
      required_tokens: [
        "pub struct WindowFrameState", "pub struct WindowFrameStates",
      ],
      forbidden_tokens: [
        "WindowLifecycle", "WindowImageState", "WindowServiceState",
      ],
    },
    {
      label: "backend common image owner",
      path: "moui/backend/common/image/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common/image\"",
      max_lines: 50,
      max_pub_lines: 20,
      max_pub_all_lines: 0,
      required_tokens: [
        "pub struct WindowImageTasks", "pub struct WindowImageTaskStates",
      ],
      forbidden_tokens: [
        "WindowLifecycle", "WindowFrameState", "WindowServiceState",
      ],
    },
    {
      label: "backend common input owner",
      path: "moui/backend/common/input/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common/input\"",
      max_lines: 150,
      max_pub_lines: 57,
      max_pub_all_lines: 7,
      required_tokens: [
        "pub struct WindowInputState", "pub(all) struct TextInputSession", "pub fn transform_cross_platform_event",
      ],
      forbidden_tokens: [
        "RendererSession", "WindowLifecycle", "WindowServiceState",
      ],
    },
    {
      label: "backend common services owner",
      path: "moui/backend/common/services/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common/services\"",
      max_lines: 49,
      max_pub_lines: 22,
      max_pub_all_lines: 0,
      required_tokens: [
        "pub fn app_services", "pub fn app_environment", "pub struct ServiceAsyncQueue",
        "pub struct WindowServiceState",
      ],
      forbidden_tokens: [
        "RendererSession", "WindowLifecycle", "WindowFrameState",
      ],
    },
  ]
}
