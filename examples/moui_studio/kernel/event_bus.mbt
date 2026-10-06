///|
/// Studio 内核·事件总线：跨插件通知的**静态**扩展点（Cordis capability
/// events 的 MoonBit 形态）。纪律：
///
/// 1. **静态注册**：监听器只在组合根装配期经 `on` 注册，运行期不变；
///    派发顺序 = 注册顺序（无优先级，v1 刻意不做）。
/// 2. **监听器是纯函数**：`(Event) -> Array[Msg]`，把事件翻译成「后续要
///    处理的消息」；副作用一律走那些消息的 update 臂——这保证可测性与
///    P13（应用状态只在 update 里变化）。
/// 3. **发事件不等于执行**：update 侧把事件推进 outbox（模型字段），包装层
///    每趟排空一次并经 `fire_events` 批量转为 Effect——事件是「事实已发生」
///    的记录，不是直接调用。
///
/// MoonBit 无运行时反射/动态加载，所以没有 Cordis 的 disposer/patch 层/
/// HMR 对应物：卸载 = 组合根不注册。这一差距记录在计划的 ADR 待办里。

///|
pub struct EventBus[Event, Msg] {
  priv listeners : Array[(String, (Event) -> Array[Msg])]
}

///|
pub fn[Event, Msg] EventBus::new() -> EventBus[Event, Msg] {
  { listeners: [], }
}

///|
/// 组装期注册一个监听器（组合根专用；运行期调用是契约违规）。
pub fn[Event, Msg] EventBus::on(
  self : EventBus[Event, Msg],
  name : String,
  handler : (Event) -> Array[Msg],
) -> Unit {
  self.listeners.push((name, handler))
}

///|
/// 已注册监听器名（按注册序；测试与诊断用）。
pub fn[Event, Msg] EventBus::listener_names(
  self : EventBus[Event, Msg],
) -> Array[String] {
  let names : Array[String] = []
  for entry in self.listeners {
    names.push(entry.0)
  }
  names
}

///|
/// 一个事件经全部监听器翻译出的消息（按注册序拼接；纯函数，可直接断言）。
pub fn[Event, Msg] EventBus::messages_for(
  self : EventBus[Event, Msg],
  event : Event,
) -> Array[Msg] {
  let messages : Array[Msg] = []
  for entry in self.listeners {
    for message in (entry.1)(event) {
      messages.push(message)
    }
  }
  messages
}

///|
/// 派发一个事件：无监听产出 = 零开销 NoEffect；单条 = Send；多条 =
/// Batch(Send…)。事件序与监听序都保持。
pub fn[Event, Msg] EventBus::emit(
  self : EventBus[Event, Msg],
  event : Event,
) -> @moui.Effect[Msg] {
  fire_events([event], self)
}

///|
/// 排空一批事件（模型 outbox 的出口）：按事件序依次经总线翻译，全部消息
/// 打包为一个 Effect。空 outbox 显式返回 NoEffect——调用方不必判空。
pub fn[Event, Msg] fire_events(
  events : Array[Event],
  bus : EventBus[Event, Msg],
) -> @moui.Effect[Msg] {
  let messages : Array[Msg] = []
  for event in events {
    for message in bus.messages_for(event) {
      messages.push(message)
    }
  }
  match messages {
    [] => @moui.Effect::none()
    [single] => @moui.Effect::send(single)
    _ =>
      @moui.Effect::batch(messages.map(message => @moui.Effect::send(message)))
  }
}
