///|
/// Mo易 Studio macOS Skia 入口（组合根 + 真实 provider worker）。
/// 模式同 moblocks_studio：async main 里把窗口泵与 provider worker 成对运行。
async fn main {
  let owner = @provider.ProviderOwner::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=@moeui_app.program(
      environment=@macos.app_environment(),
      provider_submit=(endpoint, key, prompt, on_result) => {
        @provider.provider_submit_prompt(
          owner,
          endpoint,
          key,
          @moeui_app.proposal_system_prompt(),
          prompt,
          on_result,
        )
      },
      real_provider_available=true,
    ),
    width=1280.0,
    height=800.0,
  )
  let window_task : async () -> Unit = async fn() {
    @runtime.run_app("Mo易 Studio", runtime)
    .render_all(@render_skia.from_env(platform=MacOS))
    .backend(@macos.entry())
    .run_async_pump()
  }
  let worker_task : async () -> Unit = async fn() {
    @provider.provider_worker_loop(owner)
  }
  ignore(@async.all([window_task, worker_task])) catch {
    err => println("Mo易 Studio exited with error: \{err}")
  }
}
