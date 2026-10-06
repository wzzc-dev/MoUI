///|
/// MoUI Studio macOS Skia 入口（组合根 + 真实 provider worker）。
/// 与 Web 入口的差别只有三件事：
/// 1) 真实 provider worker（阶跃星辰 step-5-preview）在此起线程循环；
/// 2) 凭据从 gitignored 的 `examples/moui_studio/.config.json` 读取预填面板，
///    缺文件时回退空配置（用户可在面板手填，key 只进会话内存）；
/// 3) 附加 stdio MCP agent 传输：Agent 在正常开窗运行时上读写已提交语义树，
///    无 Agent 附着（stdin 已关闭）时立即返回，不影响正常使用。
/// UI 逻辑全部在 app 包，本文件只做接线。

///|
async fn main {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  // 沉浸式无边框：隐藏系统标题栏、内容延伸到窗口顶端，顶栏**本身就是窗口
  // 标题栏**（56pt，IDEA 口径）。这是 mainline 桌面形态——Studio 是产品级
  // IDE，不该顶着一个系统标题栏。
  //
  // 注意：`transparent_titlebar` 只把标题栏变透明，**系统红黄绿三个信号灯
  // 仍然存在**（浮在左上角，圆心距窗口顶约 16pt、最右一颗右缘约 68pt）。
  // 所以 app 层**不**自绘信号点——自绘会出现六个，而且自绘的「缩放」没有
  // 对应的窗口请求可发，是死 UI。标题栏左侧按 `TRAFFIC_LIGHT_INSET` 让位给
  // 原生按钮，hover/点击/键盘可达性都由 AppKit 提供。Web 端没有这个选项，
  // `immersive` 在 Web 入口保持 false。
  let immersive = true
  // 拖拽通道：app 声明「标题栏左侧那段可拖」，宿主在这块区域里按下时调用
  // 原生 `performWindowDragWithEvent:`。**同一个实例必须同时交给 app 与宿主**
  // ——app 侧写、宿主侧读；给两边各建一个的话永远拖不动。
  //
  // 声明必须**避开右侧动作簇**：命中拖拽区时事件不再进入运行时，盖住
  // 运行/单步/编译会让它们变成拖窗口（点了没反应）。宽度由 app 的
  // `topbar_drag_width` 算，与渲染共用同一个计算源。
  //
  // 无边框窗口没有标题栏，不接这条通道就完全没法移动窗口。
  let window_drag = @services.WindowDragRegionSource::new()
  // 预览 webview(M2-2):宿主状态机 + macOS 平台插件(WKWebView 承载)。
  // 控制器经 PreviewWebControls 注入 app;命令走 effect 泵到插件。
  let webview_host = @webview_host.WebViewHost::new()
  // 控制器创建失败不 fail-fast:Web 预览显式不可用,Frame 预览照常
  let webview_controller : @webview_host.WebViewController? = match
    webview_host.create_controller(id="studio-preview") {
    Ok(controller) => Some(controller)
    Err(error) => {
      println("webview controller unavailable: \{error.message}")
      None
    }
  }
  let webview_plugin = @macos_webview.create_macos_webview_plugin(webview_host)
  let app_options = @macos.MacosHostAppOptions::new(
    transparent_titlebar=immersive,
    min_window_size=Some(@dpi.LogicalSize::LogicalSize(900.0, 600.0)),
    window_drag=Some(window_drag),
    platform_view_plugins=[webview_plugin],
  )
  let owner = @provider.ProviderOwner::new()
  // 真编译执行器：与 provider 同一模式——UI 线程只入队，进程 IO 在 worker。
  let compile_owner = @compile.CompileOwner::new()
  // 产物启动执行器：同一模式。`spawn` 在 worker 上做，UI 不阻塞。
  let launch_owner = @launch.LaunchOwner::new()
  // 通用构建执行器(M0-7):FramePreview/WebPreview/RunNative 的 moon 命令。
  let build_owner = @build_native.BuildOwner::new()
  // 终端 PTY provider(M5):vendor pty_host 宿主技术,queue+worker 形态,
  // 服务闭包同步入队(UI 零阻塞),worker 异步真派生 + 读循环。
  let pty_provider = PtyProvider::{
    queue: @async.Queue::new(kind=Unbounded),
    pty_ref: Ref(None),
  }
  let pty_service = pty_native_service(pty_provider)
  // 终端聚焦回调（M8）：runtime.focus_key 把键盘焦点交给终端节点
  // （节点 identity key = "terminal-input"；runtime_ref 在程序创建后填充）
  let focus_terminal = fn() {
    match runtime_ref.val {
      Some(runtime) => ignore(runtime.focus_key("terminal-input"))
      None => ()
    }
  }
  // 本地静态服务(M2):绑定回环端口 0(OS 分配);服务目录在构建回执后
  // 经 PreviewWebControls.set_directory 动态指向 workspace 根。
  // 绑定失败不 fail-fast:Web 预览显式不可用(port=0),Frame 预览照常。
  let preview_server : @webpreview.StaticServer? = match
    @webpreview.bind_static_server() {
    Ok(server) => Some(server)
    Err(message) => {
      println("webpreview static server unavailable: \{message}")
      None
    }
  }
  let preview_web : @studio_app.PreviewWebControls = match
    (preview_server, webview_controller) {
    (Some(server), Some(controller)) =>
      {
        port: server.port(),
        set_directory: dir => server.set_directory(dir),
        navigate: url => {
          controller.navigate(url).effect(map=_ => @studio_app.Msg::Noop)
        },
        reload: () => controller.reload().effect(map=_ => @studio_app.Msg::Noop),
      }
    _ => @kernel.PreviewWebControls::noop()
  }
  let config = @provider.load_provider_config(
    "examples/moui_studio/.config.json",
  ).unwrap_or(@provider.ProviderConfig::{
    endpoint: "",
    model: "",
    api_key: "",
  })
  let provider_config : @studio_app.ProviderConfig = {
    endpoint: config.endpoint,
    model: config.model,
    api_key: config.api_key,
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(
      environment=@macos.app_environment(window_drag=Some(window_drag)),
      pty=pty_service,
      focus_terminal~,
      provider_config~,
      // native 入口：编译轨可达（Web 入口保持默认 false =
      // 只有解释轨 + 源码预览，边界在 docs 定位页写明）。
      compile_track_available=true,
      // native 入口有系统目录选择（NSOpenPanel canChooseDirectories）
      // 与逐文件写盘，导出独立应用可达；Web 端点「导出」会显式声明
      // 不可用（app.export.unavailable_web），不弹一个必然失败的目录框。
      export_available=true,
      immersive~,
      apply_locale=tag => {
        match runtime_ref.val {
          Some(runtime) =>
            runtime.set_environment(runtime.environment().with_locale(tag))
          None => ()
        }
      },
      provider_submit=(spec, on_result) => {
        @provider.provider_submit_prompt(
          owner,
          spec.endpoint,
          spec.key,
          spec.model,
          spec.system,
          spec.prompt,
          on_result,
        )
      },
      webview_controller~,
      preview_web~,
      build_submit=(kind, root, entry_rel, on_result) => {
        @build_native.build_submit(build_owner, @build.BuildRequest::{
          kind,
          root,
          entry_rel,
          on_result,
        })
      },
      compile_submit=(project_json, app_name, on_progress, on_result) => {
        @compile.compile_submit(compile_owner, @compile.CompileJob::{
          project_json,
          app_name,
          work_root: @compile.default_work_root(),
          on_progress,
          on_result,
        })
      },
      // 「停止编译」杀掉正在跑的 moon 子进程（runner 登记句柄，这里取消）。
      compile_cancel=fn() { @compile.compile_cancel(compile_owner) },
      // 「运行产物」：脱离式启动（进程 reparent，Studio 退出不带走它）。
      launch_submit=(path, on_result) => {
        @launch.launch_submit(launch_owner, @launch.LaunchJob::{
          path,
          on_result,
        })
      },
      // 运行时检查器：把 moui_devtools 快照格式化成纯文本注入 app
      // （app 不 import runtime，快照类型止步于本组合根）。
      runtime_snapshot=() => {
        match runtime_ref.val {
          Some(runtime) => {
            let snapshot = runtime.inspector_snapshot()
            Some({
              summary: @devtools.snapshot_summary(snapshot).text(),
              report: @devtools.inspector_report_text(snapshot),
            })
          }
          None => None
        }
      },
    ),
    width=1280.0,
    height=800.0,
  )
  runtime_ref.val = Some(runtime)
  let host = @agent.RuntimeAgentHost::new(runtime)
  let window_task : async () -> Unit = async fn() {
    @runtime.run_app("MoUI Studio", runtime)
    .render_all(@render_skia.from_env(platform=MacOS))
    .backend(@macos.entry(options=app_options))
    .run_async_pump()
    // 窗口关闭后通知 PTY worker 优雅退出（kill 残留 shell 子进程）
    pty_provider_shutdown(pty_provider)
  }
  let worker_task : async () -> Unit = async fn() {
    @provider.provider_worker_loop(owner)
  }
  let compile_task : async () -> Unit = async fn() {
    @compile.compile_worker_loop(compile_owner)
  }
  let launch_task : async () -> Unit = async fn() {
    @launch.launch_worker_loop(launch_owner)
  }
  let build_task : async () -> Unit = async fn() {
    @build_native.build_worker_loop(build_owner)
  }
  let pty_task : async () -> Unit = async fn() {
    pty_worker_loop(pty_provider)
  }
  // 静态服务循环:仅在绑定成功时注册(随从);close 可优雅停止
  let webpreview_task : async () -> Unit = async fn() {
    match preview_server {
      Some(server) => @webpreview.serve_forever(server)
      None => return
    }
  }
  let agent_task : async () -> Unit = async fn() {
    // serve_with_diagnostics：语义工具之外再暴露运行时计数/绘制摘要/
    // 事件与命令注入（诊断面），供 Agent 做无头 E2E 与健康观测。
    @mcp_stdio.serve_with_diagnostics(host)
  }
  // **窗口是主任务，其余四个是随从**：交给 `@macos.run_window_with_workers`。
  //
  // 不能用 `@async.all([...])`（旧写法，本仓 4 个入口都踩过）：`all` 要等
  // **每一个**兄弟任务结束才返回，而这四个 worker 都是
  // `while true { queue.get() }` 的常驻循环——窗口关掉后 window_task 返回，
  // 另外四个永远不返回，于是 `all` 永不返回、进程永不退出。用户看到的就是
  // 「点系统信号灯关不掉窗口 / 卡住」：窗口没了、Dock 图标还在、只能强杀。
  //
  // 框架里那个 helper 用 `return_immediately`（交出主结果 + 取消所有子任务），
  // 窗口一返回就取消 worker，进程随即收敛。
  @macos.run_window_with_workers(window=window_task, workers=[
    worker_task, compile_task, launch_task, agent_task, build_task, webpreview_task,
    pty_task,
  ])
}
