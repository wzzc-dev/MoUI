///|
/// Studio 内核·服务容器：平台能力以**类型化服务键**集中声明（Cordis
/// context services 的静态形态——MoonBit 没有运行时异构映射，所以容器就是
/// 一个结构体：每服务一个字段，增删服务在构造点即时显编译错误）。
///
/// 依赖方向纪律：kernel 只认识**服务接口层**（moui/services 与 studio 的
/// services/* 数据类型），不认识任何插件与 app——组合根是唯一构造本结构体
/// 的地方，provider 在那里选择（native 真实现 / noop / web 显式降级）。

///|
/// 真实 provider 请求规格：由 UI 层组装（面板里的模型名 + 按请求类型选择的
/// system 提示），平台入口只负责投递，不再自行拼提示。
pub(all) struct ProviderRequestSpec {
  endpoint : String
  key : String
  model : String
  system : String
  prompt : String
}

///|
/// 真实 provider 提交签名：入口注入，UI 线程从不等待网络。
pub type ProviderSubmit = (
  ProviderRequestSpec,
  (Result[String, String]) -> Unit,
) -> Unit

///|
/// 真编译提交签名：由平台入口注入（macOS 起 native worker；Web/测试用
/// noop）。UI 线程同步返回、从不等待 moon 工具链；工具链进程全部在
/// async worker 上跑，进度与结果都经回调回到 UI 线程（与 provider 同一模式）。
///
/// `on_progress` 让界面在编译过程中就能显示「正在做第 N 步」——没有它，
/// 用户点完编译只能看着一个静态徽标等十几秒，读起来像「卡住了」。
pub type CompileSubmit = (
  String,
  String,
  (@export.CompileProgress) -> Unit,
  (Result[@export.CompileReport, String]) -> Unit,
) -> Unit

///|
/// 产物启动提交签名：由平台入口注入（macOS 起 native worker；Web/测试用
/// noop）。与编译同一模式——UI 线程同步返回，`spawn` 在 worker 上做。
///
/// 启动是**脱离式**的：进程 reparent 到系统 init，Studio 退出不带走它。
/// 所以回调只报「起没起来」，不含退出码（见 services/launch_native）。
pub type LaunchSubmit = (String, (Result[Unit, String]) -> Unit) -> Unit

///|
/// 构建提交签名：平台入口注入（native 起 BuildOwner worker；web/测试 noop）。
pub type BuildSubmit = (
  @build.BuildKind,
  String,
  String,
  (Result[@build.BuildReport, String]) -> Unit,
) -> Unit

///|
/// 预览 web 控制束（M2-2 引入，M1 内核化时泛型化）：静态服务端口/目录设置
/// + webview 命令。平台入口在组合根装配（native 真实现；web/测试用
/// `noop`——不可达能力的统一口径是 noop 返回 `Effect::none`，调用方不必分叉）。
pub(all) struct PreviewWebControls[Msg] {
  /// 静态服务实际端口（0 = 未启动/web 不可用）
  port : Int
  /// 设置静态服务的服务目录（构建回执后调用）
  set_directory : (String) -> Unit
  /// webview 导航（返回 Effect 走运行时 effect 泵）
  navigate : (String) -> @moui.Effect[Msg]
  /// webview 刷新（重建后）
  reload : () -> @moui.Effect[Msg]
}

///|
pub fn[Msg] PreviewWebControls::noop() -> PreviewWebControls[Msg] {
  {
    port: 0,
    set_directory: _directory => (),
    navigate: _url => @moui.Effect::none(),
    reload: () => @moui.Effect::none(),
  }
}

///|
/// 服务容器：Studio 全部平台能力的**唯一**类型化键面。插件经它取能力，
/// 组合根经它装 provider；两个平台入口的「哪些能力可达」差异全部体现在
/// 这里构造出的值里，不散落在 update 链中。
pub(all) struct StudioServices[Msg] {
  provider_submit : ProviderSubmit
  compile_submit : CompileSubmit
  compile_cancel : () -> Unit
  build_submit : BuildSubmit
  build_cancel : () -> Unit
  launch_submit : LaunchSubmit
  files : @services.FileServices
  preview_web : PreviewWebControls[Msg]
  /// 词法着色服务（M6）：provider 按语言 id 注册（moonbit 随内核发布；
  /// DSL 在 app 侧注册）。着色是渲染层事实，与平台无关——所有组合根同构。
  highlight : HighlightService
}

///|
/// 不可达 provider（noop 口径：显式失败，不装作能通）。
pub fn noop_provider_submit(
  _spec : ProviderRequestSpec,
  callback : (Result[String, String]) -> Unit,
) -> Unit {
  callback(Err("真实 provider 未接入"))
}

///|
/// 不可达编译执行器（noop 口径）。
pub fn noop_compile_submit(
  _project_json : String,
  _app_name : String,
  _on_progress : (@export.CompileProgress) -> Unit,
  callback : (Result[@export.CompileReport, String]) -> Unit,
) -> Unit {
  callback(
    Err("本端没有真编译执行器：编译轨仅在 native 入口可达"),
  )
}

///|
pub fn noop_compile_cancel() -> Unit {
  ()
}

///|
/// 不可达构建执行器（noop 口径）。
pub fn noop_build_submit(
  _kind : @build.BuildKind,
  _root : String,
  _entry_rel : String,
  callback : (Result[@build.BuildReport, String]) -> Unit,
) -> Unit {
  callback(Err("本端没有构建执行器:构建仅在 native 入口可达"))
}

///|
pub fn noop_build_cancel() -> Unit {
  ()
}

///|
/// 不可达产物启动执行器（noop 口径）。
pub fn noop_launch_submit(
  _path : String,
  callback : (Result[Unit, String]) -> Unit,
) -> Unit {
  callback(Err("本端没有产物启动执行器：仅 native 入口可达"))
}

///|
/// 不可达预览 web 控制（noop 口径）。
pub fn[Msg] noop_preview_web_controls() -> PreviewWebControls[Msg] {
  PreviewWebControls::noop()
}

///|
/// 不可达服务集：全部执行器返回「本端没有该执行器」的显式失败，文件服务
/// 不可用，web 控制为 noop。供无平台环境的组合根（测试/无头入口）使用；
/// 各 noop 文案是平台入口的统一口径。
pub fn[Msg] StudioServices::denied(
  files? : @services.FileServices = @services.FileServices::unavailable(),
) -> StudioServices[Msg] {
  {
    provider_submit: noop_provider_submit,
    compile_submit: noop_compile_submit,
    compile_cancel: noop_compile_cancel,
    build_submit: noop_build_submit,
    build_cancel: noop_build_cancel,
    launch_submit: noop_launch_submit,
    files,
    preview_web: noop_preview_web_controls(),
    highlight: HighlightService::new(),
  }
}
