///|
/// Studio 内核·插件契约（**读我**）。
///
/// 一个 Studio 插件 = 一个包，它向组合根提供四样东西：
///
/// 1. **状态切片 + TEA 五元组**：`@moui.Feature[ChildModel, ChildMsg]`
///    （init/update/subscriptions/commands）。组合根用
///    `Feature::scope(read, write, wrap)` 把它挂进根模型，根 update 对包装
///    变体穷举分派（漏臂 = 编译错误）。样板：`examples/settings/app`。
/// 2. **贡献项**（见 contributions.mbt）：面板视图 / 活动栏项 / 底栏页签 /
///    命令 / 模式预设。插件以自己的类型产出，组合根经它的 `wrap` 提升到根
///    类型后收进壳渲染的数组。
/// 3. **事件订阅**：纯函数 `(Event) -> Array[Msg]`，组合根注册进
///    `EventBus`（见 event_bus.mbt）。
/// 4. **服务依赖**：只经 `StudioServices` 取能力；插件之间互不 import，
///    协作只走服务、事件与根投影的共享读（设计契约 4）。
///
/// 与 Cordis 的对照与差距（诚实边界）：容器/服务/事件/贡献点是同构概念；
/// 插件的**注册、卸载与替换**在 Cordis 是运行时效果（disposer/patch 层），
/// 在这里是组合根的静态装配——MoonBit 无动态加载与反射，这是刻意的收窄，
/// 不是遗漏。
///
/// 因此内核不提供「插件数组」这类异构容器（MoonBit 无存在类型，硬造就要
/// 类型擦除）；**组合根是唯一知道全部插件的地方**，它用一份静态装配代码
/// 声明 profile——这正是 dsh 的 profiles/bundles 在静态语言里的对应物。

///|
/// 插件描述符：组合根装配日志与测试用（名字 + 一句话职责）。
pub(all) struct PluginDescriptor {
  name : String
  summary : String
}
