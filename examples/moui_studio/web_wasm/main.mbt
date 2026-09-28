///|
/// MoUI Studio Web 入口（wasm-gc）：薄组合根。
/// 浏览器只用确定性假模型（无网络/无凭据）；真实 provider 仅 native。
/// apply_locale 经 Ref 后置绑定（runtime 构造时还不存在）。

///|
fn main {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(environment=@web.app_environment(), apply_locale=tag => {
      match runtime_ref.val {
        Some(runtime) =>
          runtime.set_environment(runtime.environment().with_locale(tag))
        None => ()
      }
    }),
    width=1280.0,
    height=800.0,
  )
  runtime_ref.val = Some(runtime)
  @runtime.run_app("MoUI Studio", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
