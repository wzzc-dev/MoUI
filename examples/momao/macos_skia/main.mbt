///|
/// MoMao Studio macOS Skia 入口（组合根 + 真实 provider worker）。
/// 与 Web 入口的差别只有两件事：
/// 1) 真实 provider worker（阶跃星辰 step-5-preview）在此起线程循环；
/// 2) 凭据从 gitignored 的 `examples/momao/.config.json` 读取预填面板，
///    缺文件时回退空配置（用户可在面板手填，key 只进会话内存）。
/// UI 逻辑全部在 app 包，本文件只做接线。

///|
async fn main {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let owner = @provider.ProviderOwner::new()
  let config = @provider.load_provider_config("examples/momao/.config.json").unwrap_or(@provider.ProviderConfig::{
      endpoint: "",
      model: "",
      api_key: "",
    },
  )
  let provider_config : @momao_app.ProviderConfig = {
    endpoint: config.endpoint,
    model: config.model,
    api_key: config.api_key,
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=@momao_app.program(
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
  let window_task : async () -> Unit = async fn() {
    @runtime.run_app("MoMao 墨卯", runtime)
    .render_all(@render_skia.from_env(platform=MacOS))
    .backend(@macos.entry())
    .run_async_pump()
  }
  let worker_task : async () -> Unit = async fn() {
    @provider.provider_worker_loop(owner)
  }
  ignore(@async.all([window_task, worker_task])) catch {
    err => println("MoMao Studio exited with error: \{err}")
  }
}
