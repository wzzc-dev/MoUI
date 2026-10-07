///|
/// MoUI Studio Web 入口（wasm-gc）：薄组合根。
/// 浏览器只用确定性假模型（无网络/无凭据）；真实 provider 仅 native。
/// apply_locale 经 Ref 后置绑定（runtime 构造时还不存在）。

///|
/// 平台墙钟 → app 的 StudioClock 纯数据映射（mo_desktop 的 DesktopClock
/// 同款先例；web 的 FFI 在 moui/backend/web/web_host.mbt）。
fn web_studio_clock() -> @studio_app.StudioClock {
  let clock = @web.web_wall_clock()
  {
    year: clock.year,
    month: clock.month,
    day: clock.day,
    weekday: clock.weekday,
    hour: clock.hour,
    minute: clock.minute,
    second: clock.second,
  }
}

///|
fn main {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(
      environment=@web.app_environment(),
      wall_clock=Some(web_studio_clock),
      apply_locale=tag => {
        match runtime_ref.val {
          Some(runtime) =>
            runtime.set_environment(runtime.environment().with_locale(tag))
          None => ()
        }
      },
      // 运行时检查器：Web 与 native 同权（moui_devtools wasm-gc 安全）。
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
  @runtime.run_app("MoUI Studio", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
