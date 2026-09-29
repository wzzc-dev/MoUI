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
  let app_options = @macos.MacosHostAppOptions::new(
    transparent_titlebar=immersive,
    min_window_size=Some(@dpi.LogicalSize::LogicalSize(900.0, 600.0)),
    window_drag=Some(window_drag),
  )
  let owner = @provider.ProviderOwner::new()
  // 真编译执行器：与 provider 同一模式——UI 线程只入队，进程 IO 在 worker。
  let compile_owner = @compile.CompileOwner::new()
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
      provider_config~,
      // native 入口：编译轨可达（Web 入口保持默认 false =
      // 只有解释轨 + 源码预览，边界在 docs 定位页写明）。
      compile_track_available=true,
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
      compile_submit=(project_json, app_name, on_result) => {
        @compile.compile_submit(compile_owner, @compile.CompileJob::{
          project_json,
          app_name,
          work_root: @compile.default_work_root(),
          on_result,
        })
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
  }
  let worker_task : async () -> Unit = async fn() {
    @provider.provider_worker_loop(owner)
  }
  let compile_task : async () -> Unit = async fn() {
    @compile.compile_worker_loop(compile_owner)
  }
  let agent_task : async () -> Unit = async fn() {
    // serve_with_diagnostics：语义工具之外再暴露运行时计数/绘制摘要/
    // 事件与命令注入（诊断面），供 Agent 做无头 E2E 与健康观测。
    @mcp_stdio.serve_with_diagnostics(host)
  }
  ignore(@async.all([window_task, worker_task, compile_task, agent_task])) catch {
    err => println("MoUI Studio exited with error: \{err}")
  }
}
