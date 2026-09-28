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
  let owner = @provider.ProviderOwner::new()
  let config = @provider.load_provider_config("examples/moui_studio/.config.json").unwrap_or(@provider.ProviderConfig::{
      endpoint: "",
      model: "",
      api_key: "",
    },
  )
  let provider_config : @studio_app.ProviderConfig = {
    endpoint: config.endpoint,
    model: config.model,
    api_key: config.api_key,
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(
      environment=@macos.app_environment(),
      provider_config~,
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
    ),
    width=1280.0,
    height=800.0,
  )
  runtime_ref.val = Some(runtime)
  let host = @agent.RuntimeAgentHost::new(runtime)
  let window_task : async () -> Unit = async fn() {
    @runtime.run_app("MoUI Studio", runtime)
    .render_all(@render_skia.from_env(platform=MacOS))
    .backend(@macos.entry())
    .run_async_pump()
  }
  let worker_task : async () -> Unit = async fn() {
    @provider.provider_worker_loop(owner)
  }
  let agent_task : async () -> Unit = async fn() {
    // serve_with_diagnostics：语义工具之外再暴露运行时计数/绘制摘要/
    // 事件与命令注入（诊断面），供 Agent 做无头 E2E 与健康观测。
    @mcp_stdio.serve_with_diagnostics(host)
  }
  ignore(@async.all([window_task, worker_task, agent_task])) catch {
    err => println("MoUI Studio exited with error: \{err}")
  }
}
