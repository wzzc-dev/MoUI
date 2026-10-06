///|
/// 预览 web 控制的进程级槽位(M2-2)。
///
/// webview 控制器与控制束(navigate/reload/set_directory/端口)由平台
/// 组合根在启动时注入;app 内部的视图与处理器经此读取。用槽位而不是
/// 逐层参数穿透:view_with_viewport → shell_view → workspace_content →
/// preview_workspace 四层签名只为一个进程单例服务,不值得。
/// web 入口不注入(槽位为 None)→ Web 模式显式不可用。

///|
let controller_slot : Ref[@webview_host.WebViewController?] = Ref(None)

///|
let controls_slot : Ref[PreviewWebControls?] = Ref(None)

///|
/// 组合根注入(main.mbt 启动时调用一次)。
pub fn install_preview_web(
  controller : @webview_host.WebViewController?,
  controls : PreviewWebControls?,
) -> Unit {
  controller_slot.val = controller
  controls_slot.val = controls
}

///|
pub fn preview_web_controller() -> @webview_host.WebViewController? {
  controller_slot.val
}

///|
/// 控制束(None 时回落 noop,让调用方无须分支)。
pub fn preview_web_controls() -> PreviewWebControls {
  match controls_slot.val {
    Some(controls) => controls
    None => @kernel.noop_preview_web_controls()
  }
}
