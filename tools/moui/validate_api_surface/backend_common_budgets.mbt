///|
fn backend_common_package_budgets() -> Array[PackageBudget] {
  [
    {
      label: "backend common",
      path: "moui/backend/common/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/common\"",
      // I1: DesktopSurfaceBinding[W] + DesktopNativeHostBackendCore[W, Extra]
      // moved the desktop backends' shared struct/construction surface here.
      // ADR 0059 adds the apphost import line (79) and forbids direct runtime.
      // Cursor projection adds the `wzzc-dev/window/core` import line, the
      // `cursor_icon_to_window` mapping table (+2 lines with its doc block) and
      // the two cursor sync workflows (+3): 79 -> 84 / 18 -> 21.
      // Window chrome controls (issue #24): apply_window_control_requests +
      // sync_window_controls (+2 declarations, +3 lines): 84 -> 87 / 21 -> 23.
      max_lines: 87,
      max_pub_lines: 23,
      max_pub_all_lines: 2,
      required_tokens: [
        "\"wzzc-dev/moui/apphost\"", "pub fn attach_window_surface", "pub fn dispatch_host_event",
        "pub fn run_window_redraw", "pub fn dispose_window",
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
      // Issue #24 chrome controls: WindowSurfaceActions gains
      // set_maximized/set_fullscreen/set_decorations, the request queue and
      // command facade gain maximize/restore/fullscreen/decorations helpers,
      // the registry records observed maximized/fullscreen, and the lifecycle
      // exposes its request port: +11 lines / +11 pub.
      // +1 pub: effective_window_requests resolves the launch port against a
      // backend-owned fallback queue, the counterpart of the
      // WindowRequests::is_unavailable marker.
      max_lines: 331,
      max_pub_lines: 182,
      max_pub_all_lines: 10,
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
      max_pub_lines: 25,
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
      // Cursor projection: CursorSession (+8 lines) and the three
      // WindowInputState cursor helpers (+5): 175 -> 186 / 61 -> 69.
      max_lines: 186,
      max_pub_lines: 69,
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
