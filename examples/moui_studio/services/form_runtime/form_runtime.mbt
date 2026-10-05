///|
/// 表单运行时公共化(M5-5b):从导出 kernel 提取的独立 @form 运行时门面。
///
/// 用户工程的 handlers.mbt 调用本包的 set / get / set_text 等——与导出
/// bundle 里的 compiled_runtime 同一 API 面,但作为**可依赖的库包**而非
/// vendored 副本。
///
/// 提取策略:`@compiled_runtime.Runtime` 是完整实现(状态/审计/闸门/
/// 步数预算),本包是**薄门面**——公开用户工程需要的子集,内部委托
/// `@compiled_runtime.Runtime`。后续 IR 生长(match/enum/struct)时
/// 只需扩展此门面,不必触碰 kernel 内核。
///
/// 注意:set_text / message_box 等需要控件元数据的内建(操作 form IR
/// 的控件表)不在本门面——它们由 moonbit_codegen 生成的 handlers.mbt
/// 直接调用 compiled_runtime 的完整 API;本门面暴露的是**变量与审计**
/// 子集,供 form.mbt 工程的 handlers 直接调用的最小面。

///|
/// 表单运行时:包装 compiled_runtime 的完整实现。
pub(all) struct FormRuntime {
  inner : @compiled_runtime.Runtime
}

///|
/// 从 inner runtime 构造(组合根或预览 harness 调用)。
pub fn FormRuntime::from(inner : @compiled_runtime.Runtime) -> FormRuntime {
  { inner, }
}

///|
/// 取内部 runtime(需要完整 API 面时用;如预览 harness 的 draw_commands)。
pub fn FormRuntime::inner(self : FormRuntime) -> @compiled_runtime.Runtime {
  self.inner
}

///|
/// 变量赋值(积木:变量 名 = 值)。
pub fn FormRuntime::set(
  self : FormRuntime,
  name : String,
  value : @compiled_runtime.Value,
) -> Unit {
  self.inner.set(name, value)
}

///|
/// 读取变量值(未声明变量返回 VUnit 而非报错——门面的宽容口径)。
pub fn FormRuntime::get(
  self : FormRuntime,
  name : String,
) -> @compiled_runtime.Value {
  self.inner.get(name, 0) catch {
    _ => @compiled_runtime.VUnit
  }
}

///|
/// 审计赋值(编译轨自动生成;积木面板不用直接调)。
pub fn FormRuntime::audit_assign(
  self : FormRuntime,
  name : String,
  value : @compiled_runtime.Value,
  line : Int,
  detail : String,
) -> Unit {
  self.inner.audit_assign(name, value, line, detail) catch {
    _ => ()
  }
}

///|
/// 设置控件文本(需要 form IR 控件元数据;由代码生成器调用)。
pub fn FormRuntime::set_text(
  self : FormRuntime,
  control : String,
  text : String,
) -> Unit {
  self.inner.set_text(control, @compiled_runtime.VStr(text), "set_text", 0, "") catch {
    _ => ()
  }
}

///|
/// 弹出信息框。
pub fn FormRuntime::message_box(self : FormRuntime, text : String) -> Unit {
  self.inner.message_box(@compiled_runtime.VStr(text), "message_box", 0, "") catch {
    _ => ()
  }
}
