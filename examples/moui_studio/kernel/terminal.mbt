///|
/// Studio 内核·PTY 服务键（M5 终端插件）：真实终端会话的平台能力接口。
///
/// 约束发现（记入计划）：MoonBit `moon.mod` 的 `import` 只支持版本化
/// registry 依赖——workspace 成员 `examples/terminal` 无法被 studio 模块
/// 导入，所以「复用其 PTY 宿主技术」的落点是**供应商绑定 vendor 进组合
/// 根**（pty.c stub + FFI 绑定放在 macos_skia，native provider 在那里
/// 构造本服务）；web/测试组合根给 `unavailable`（显式不可用，不假装能开）。
///
/// 句柄是组合根登记表的**不透明整数 id**（组合根持真实 fd/pid 映射），
/// 插件状态只存 id——内核与插件都不知道 fd 的存在。
pub(all) struct PtyService[Msg] {
  /// 本端是否具备 PTY 能力（native = 真；web/无头 = 假）
  available : Bool
  /// 派生终端会话：行列数 + 输出回调（VT 字节流解码后的增量文本）+
  /// 退出回调 + 消息泵（Effect::dispatch 的 emit——长有效性，provider
  /// 的异步读循环靠它把回调 lift 成的 Msg 送回运行时）；
  /// 返回登记表句柄 id（None = 不可达/失败）
  spawn : (Int, Int, (String) -> Msg, () -> Msg, (Msg) -> Unit) -> Int?
  /// 向会话写输入（用户键入行）
  write : (Int, String) -> Unit
  /// 尺寸变化（底栏拖拽/窗口 resize）
  resize : (Int, Int, Int) -> Unit
  /// 终止会话并回收子进程（页签关闭/Studio 退出）
  kill : (Int) -> Unit
}

///|
/// 不可达 PTY 服务：available=false，spawn 恒 None，其余 no-op。
/// web 入口与无头测试的显式降级口径（不假装能开）。
pub fn[Msg] PtyService::unavailable() -> PtyService[Msg] {
  {
    available: false,
    spawn: fn(_cols, _rows, _on_output, _on_exit, _emit) { None },
    write: fn(_handle, _input) { () },
    resize: fn(_handle, _cols, _rows) { () },
    kill: fn(_handle) { () },
  }
}
