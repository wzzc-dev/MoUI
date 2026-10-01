///|
/// 编译轨状态机测试（与服务执行器分离：这里只验证纯转移与路由）。
/// 命名保持 `compile_` 前缀，便于按名字筛选真编译相关契约。

///|
fn compile_apply(model : @app.Model, msg : @app.Msg) -> @app.Model {
  let (next, _effect) = @app.update_pure(model, msg)
  next
}

///|
test "compile run is explicit: switching track does not start a build" {
  let model = @app.initial_model(compile_track_available=true)
  let switched = compile_apply(model, SetRunTrack(Compile))
  assert_false(switched.compile_busy)
  assert_true(switched.compile_report is None)
}

///|
test "compile run on web says native-only and stays idle" {
  let model = @app.initial_model()
  let next = compile_apply(model, CompileRun)
  assert_false(next.compile_busy)
  assert_true(next.compile_report is None)
  assert_true(next.notice.contains("native"))
}

///|
test "compile run marks busy once and is idempotent while running" {
  let model = @app.initial_model(compile_track_available=true)
  let busy = compile_apply(model, CompileRun)
  assert_true(busy.compile_busy)
  assert_true(busy.run_track is @app.Compile)
  assert_true(busy.mode is @app.ModeRun)
  // 忙态下重复点击不改变状态（不重复排队）
  let again = compile_apply(busy, CompileRun)
  assert_true(again.compile_busy)
  assert_eq(again.notice, busy.notice)
}

///|
test "compile submit is dispatched only on the false to true edge" {
  let model = @app.initial_model(compile_track_available=true)
  let busy = compile_apply(model, CompileRun)
  assert_true(@app.compile_submit_needed(model, busy))
  assert_false(@app.compile_submit_needed(busy, busy))
  // 未使能编译轨（Web）不派发
  let web = @app.initial_model()
  assert_false(@app.compile_submit_needed(web, compile_apply(web, CompileRun)))
  // 源码草稿有错时不派发（先修再编译）：CompileRun 会先 commit，
  // 提交失败只写 code_error，不进入忙态，也就不派发。
  let broken = compile_apply(model, EditCode("x ="))
  let refused = compile_apply(broken, CompileRun)
  assert_true(refused.code_error != "")
  assert_false(refused.compile_busy)
  assert_false(@app.compile_submit_needed(broken, refused))
}

///|
test "compile failure surfaces diagnostics and does not fall back" {
  let model = compile_apply(
    @app.initial_model(compile_track_available=true),
    CompileRun,
  )
  let report : @export.CompileReport = {
    ok: false,
    exit_code: 1,
    target: "native",
    source_path: "/tmp/x/app/generated_handlers.mbt",
    output: "Error: [4014]\nbroken",
    diagnostics: [
      @export.CompileDiagnostic::{
        severity: "error",
        code: "4014",
        file: "/tmp/x/app/generated_handlers.mbt",
        line: 12,
        column: 3,
        text: "Type mismatch",
      },
    ],
    artifacts: [],
    work_root: "/tmp/x",
  }
  let failed = compile_apply(model, CompileRunFinished(report))
  assert_false(failed.compile_busy)
  match failed.compile_report {
    None => fail("失败报告必须留在模型里，不许静默丢弃")
    Some(stored) => {
      assert_false(stored.ok)
      assert_eq(stored.errors().length(), 1)
    }
  }
  // 报告失败不改变轨道：仍在编译轨视图看诊断
  assert_true(failed.run_track is @app.Compile)
}

///|
test "compile executor startup failure is reported as a failed report" {
  let model = compile_apply(
    @app.initial_model(compile_track_available=true),
    CompileRun,
  )
  let failed = compile_apply(model, CompileRunFailed("boom"))
  assert_false(failed.compile_busy)
  match failed.compile_report {
    None => fail("执行器失败也要有报告")
    Some(report) => {
      assert_false(report.ok)
      assert_eq(report.exit_code, -1)
      assert_eq(report.output, "boom")
    }
  }
}

///|
test "compile stop clears report without switching tracks" {
  let model = compile_apply(
    @app.initial_model(compile_track_available=true),
    CompileRun,
  )
  let stopped = compile_apply(model, CompileStopped)
  assert_false(stopped.compile_busy)
  assert_true(stopped.compile_report is None)
  assert_true(stopped.run_track is @app.Compile)
}

///|
test "compile output toggle flips the fold state" {
  let model = @app.initial_model(compile_track_available=true)
  assert_false(model.compile_output_open)
  let opened = compile_apply(model, ToggleCompileOutput)
  assert_true(opened.compile_output_open)
  let closed = compile_apply(opened, ToggleCompileOutput)
  assert_false(closed.compile_output_open)
}

///|
test "compile jump maps generated source line back to its block" {
  let model = @app.initial_model(compile_track_available=true)
  // 取生成源码里第一条语句的真实行号——同一函数、同一份字节。
  let generated = @export.moonbit_preview_with_lines(model.program)
  let handler = generated.handlers[0]
  let entry = handler.stmt_lines[0]
  let jumped = compile_apply(model, CompileJump(entry.line))
  assert_true(jumped.mode is @app.ModeBlocks)
  let blocks = @app.block_chain_of(jumped)
  assert_true(jumped.selected_block >= 0)
  assert_eq(blocks[jumped.selected_block].path, entry.path)
}

///|
test "compile jump with unknown line keeps the model unchanged" {
  let model = @app.initial_model(compile_track_available=true)
  let jumped = compile_apply(model, CompileJump(999999))
  assert_true(jumped.mode is @app.ModeDesign)
  assert_eq(jumped.selected_block, model.selected_block)
}
