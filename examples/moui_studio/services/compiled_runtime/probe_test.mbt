///|
/// 生成代码形态探测：handler 里嵌套 lambda 作循环体、显式 Handler 包装、
/// 以及 raise 函数调用链 —— codegen 输出的正是这个形状。
fn probe_handler_body(
  rt : @compiled_runtime.Runtime,
) -> Unit raise @compiled_runtime.ExecError {
  let total = rt.get("总分", 2)
  let body : (@compiled_runtime.Runtime) -> Unit raise @compiled_runtime.ExecError = fn(
    inner : @compiled_runtime.Runtime,
  ) -> Unit raise @compiled_runtime.ExecError {
    let value = inner.get("总分", 3)
    ignore(value)
    inner.audit_assign("总分", @compiled_runtime.VNum(1.0), 3, "总分 = 1")
  }
  rt.count_loop(@compiled_runtime.VNum(3.0), "i", 3, body)
  ignore(total)
}

///|
test "probe generated handler shape" {
  let rt = @compiled_runtime.new_runtime(
    Map([], capacity=4),
    Map([], capacity=4),
    [("总分", "0")],
  )
  let status = @compiled_runtime.run_handler(
    rt,
    @compiled_runtime.Handler(probe_handler_body),
  )
  inspect(status is @compiled_runtime.Completed, content="true")
  inspect(rt.audit.length(), content="6")
  inspect(rt.audit[0].detail, content="iteration 1")
  inspect(rt.audit[1].detail, content="总分 = 1")
}
