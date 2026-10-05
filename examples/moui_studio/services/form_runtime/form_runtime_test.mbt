///|
/// 表单运行时门面测试:set/get 变量 + set_text + message_box(不崩)。

///|
test "FormRuntime 变量 set/get" {
  let inner = @compiled_runtime.new_runtime(Map([]), Map([]), [])
  let rt = FormRuntime::from(inner)
  rt.set("计数", @compiled_runtime.VInt(42))
  let value = rt.get("计数")
  assert_true(value is @compiled_runtime.VInt(_))
}

///|
test "FormRuntime get 未声明变量返回 VUnit(宽容口径)" {
  let inner = @compiled_runtime.new_runtime(Map([]), Map([]), [])
  let rt = FormRuntime::from(inner)
  let value = rt.get("不存在")
  assert_true(value is @compiled_runtime.VUnit)
}

///|
test "FormRuntime audit_assign 不崩" {
  let inner = @compiled_runtime.new_runtime(Map([]), Map([]), [])
  let rt = FormRuntime::from(inner)
  rt.audit_assign("x", @compiled_runtime.VInt(1), 1, "x = 1")
}
