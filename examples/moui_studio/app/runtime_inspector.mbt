///|
/// 运行时检查器（右栏 Runtime 页签）：把 `moui_devtools` 的运行时快照
/// （视图树 / 布局 / 绘制 / 语义五个分节）搬进 IDE 外壳。
///
/// 依赖边界：app 包不 import `wzzc-dev/moui/runtime`——快照类型与
/// `AppRuntime` 止步于平台组合根。入口注入的回调把快照**格式化成纯文本**
/// 再交进来，app 只负责展示与历史管理。Web 与 native 入口都可注入
/// （moui_devtools 是 wasm-gc 安全的）；测试与未注入时优雅降级。

///|
/// 一次运行时快照样本：summary 是单行计数（节点/命令/脏区…），
/// report 是分节文本报告。
pub(all) struct RuntimeInspectSample {
  summary : String
  report : String
}

///|
/// 平台入口注入的快照回调签名。
pub type RuntimeSnapshotFn = () -> RuntimeInspectSample?

///|
fn noop_runtime_snapshot() -> RuntimeInspectSample? {
  None
}

///|
/// 历史条上限：快照摘要按新到旧排列，超限丢弃最旧的。
/// moui_devtools 的 SnapshotHistory 无界，这里在 app 侧自己封顶。
const RUNTIME_HISTORY_LIMIT : Int = 24

///|
/// 采样到达：写入当前报告 + 追加历史（新到旧）。
pub fn runtime_sample_arrived(
  model : Model,
  sample : RuntimeInspectSample,
) -> Model {
  let history : Array[String] = [sample.summary]
  for item in model.runtime_history {
    if history.length() < RUNTIME_HISTORY_LIMIT && item != sample.summary {
      history.push(item)
    }
  }
  { ..model, runtime_report: Some(sample), runtime_missing: false, runtime_history: history, }
}

///|
/// 按需采样：打开 Runtime 页签或点击刷新时调用注入回调。
/// 其余消息原样通过——快照是 O(节点数) 的全树遍历，绝不能跟着
/// 每条消息跑。
pub fn runtime_refresh_attached(
  next : Model,
  msg : Msg,
  take : RuntimeSnapshotFn,
) -> (Model, @moui.Effect[Msg]) {
  let opened = match msg {
    SetContextTab(_) => next.ctx_tab is CtxRuntime
    RuntimeRefresh => true
    _ => false
  }
  if !opened {
    return (next, @moui.Effect::none())
  }
  match take() {
    Some(sample) => (runtime_sample_arrived(next, sample), @moui.Effect::none())
    None => ({ ..next, runtime_missing: true }, @moui.Effect::none())
  }
}
