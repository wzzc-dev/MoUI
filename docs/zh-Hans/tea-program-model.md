# TEA Program 模型

> 本文档描述 MoUI 应用的 TEA 模型（View、Program、Effect、Subscription）。
> 概述见[架构](../architecture.md)。

**应用作者配方**（timer、clipboard、file open、window resize、shortcut）位于[非渲染组件 cookbook](../non-render-component-cookbook.md) 和可运行的 Showcase Platform 包中。本页是生命周期和语义参考，不是可直接复制粘贴的 cookbook。

MoUI app 代码使用不透明的 `@moui.View[Msg]` 值构建 UI。标准形态是类型化 TEA 循环：`view : Model -> View[Msg]`，事件携带类型化消息，`update` 处理这些消息，显式的 `Effect[Msg]` 值描述后续工作。App 级 `Subscription[Msg]` 值声明持续事件源；它们应随着 model 变化被启动、按 key 复用或取消。需要 viewport 或平台输入的 view 通过 `Program::simple_with_environment` 或 `Program::new_with_environment` 使用 `view : (Model, ViewEnvironment) -> View[Msg]`。用户代码不调用 `lower`、`to_spec`、`ViewSpec` 或 `ViewLoweringSink`；这些名称是历史 guardrail 名称，不是受支持的 app 或控件 API。

`views/` 是具体 custom view 控件和高层组合之上的 facade：

```moonbit
enum CounterMsg { Inc; Dec }

fn view(count : Int) -> @moui.View[CounterMsg] {
  @views.column([
    @views.text("Count: \{count}"),
    @views.row([
      @views.button("-", on_click=Dec),
      @views.button("+", on_click=Inc),
    ], spacing=8.0),
  ], spacing=12.0)
}
```

函数组件只是返回 `View[Msg]` 的普通函数。子消息通过 `View::map` 提升，例如 `todo_row(todo).map(TodoRowMsg)`。会返回后续工作的子更新使用 `Effect::map` 提升 effect，这样父级 update 可以保留类型化子消息组合和结构化 effect descriptor，而不暴露 runtime dispatch。普通控件是 TEA 优先的受控 view：app 代码传入当前值和 `on_input`、`on_change` 或 `on_select`，然后根据发出的消息更新 model。需要复杂局部状态的控件，例如富文本编辑或虚拟化资源，会通过 binding、cell 或专用集成回调显式保存这些状态。

runtime 拥有、限定在 node 生命周期内的瞬态状态与 TEA 并不冲突。hover、focus、pressed、caret/selection 和 scroll position 可以存在于与某个 reconciled element 绑定的临时 slot 中；语义动作可以更新这些瞬态状态并排队 typed message，但只有应用 `update` 能改变业务 model。卸载节点会释放该 slot。

Custom-control 入口在 `moui/views` 中面向 app 暴露。App 代码、host 测试、smoke 检查和示例 app 应使用 `@views.text_field`、`@views.checkbox`、`@views.picker` 和 `@moui_richtext.markdown_editor` 等 helper（rich text 位于 `moui_richtext` addon，而不是 `moui/views`）。具体内置控件应在 `moui/views` 中实现与消息无关的 `@core.ViewNode` trait，并通过 `@core.View::from_node(...)` 连接类型化 children、event 和 text command。它们不应添加 `@core.View::primitive_*_view` constructor 或 runtime lowering table entry。

有状态控件在必须订阅 framework cell 或桥接复杂控件状态时，可以使用带 `ComponentContext` 的局部 `@views.component` adapter；但共享 app 包应默认使用 `Program::simple` factory，并让平台入口通过 `moui/runtime` 创建 `AppRuntime` 值。具备 effect 的 app 应在 `update` 返回后续工作时使用 `Program::new`。`Effect::run` 为普通一次性 runner 提供稳定 key、kind 和 label；`moui/services.ServiceTask::effect` 则用于文件、剪贴板、URL、设置、外观和菜单，把 `Success`、`Failure`、`Cancelled` 转换为 `Msg`，不暴露 host request id、bridge 或 completion queue。`AppEnvironment` 由 Program 闭包捕获，不能进入业务 `Model`。`Effect::task` 和 `Effect::service_task` 继续提供 runtime-owned 取消、完成与 stale-dispatch 诊断。

`@runtime.effect_plan_summary` 暴露 runtime-owned effect tree 诊断摘要，包括 batch、send、anonymous dispatch、structured run、task、none、scheduled leaf count、max depth、structured effect descriptor，以及重复 descriptor-key 的数量/名称，且不会运行 effect 回调。Program runtime snapshot 也报告 message queue 的 enqueue、drain、pending、max-pending 和 ignored program-dispatch 计数器，而不要求 `Msg` 值可序列化。每次 program-message drain 都被界定为一个 runtime turn：点击、`Effect::send` / `Effect::dispatch`、structured runner、effect task 或 subscription 同步排队的消息会保持 FIFO 顺序，但超过每 turn 上限的工作会留待下一个 host/runtime 入口处理，而不是让当前调用栈无限存活。由匿名 `Effect::dispatch` 或结构化 `Effect::run` 回调捕获的 dispatch closure 在 `AppRuntime::destroy()` 后会被忽略，因此迟到的 app-owned 回调不能重新进入已销毁的 program runtime。

`Program` constructor 也接受 `subscriptions=model => ...`；每个 source 使用稳定 key，接收 typed dispatcher，并可返回 cleanup callback。runtime 按 key/kind 复用、重启或取消 source，并拒绝已取消或已销毁生命周期的 stale callback。`backend` 只提供 integration-only `HostEventSource`/`HostWindowEventSource`；面向应用的 timer 和 route adapter 是仅依赖 core 的 `@services.TimerSource` 与 `@services.RouteSource`。

`Program::with_commands` 与 Program 一起声明 typed `ProgramCommand[Msg]`。runtime 随 model 同步当前 command map；键盘快捷键、原生应用菜单和 context-menu selection 都按 FIFO 排队相应 `Msg`，并进入同一个 `update`。应用不得安装在 TEA 之外直接修改 model 的 command closure。

Environment-aware TEA app 应使用 `*_with_environment` constructor，而不是在 view 层接收 `ComponentContext`。两种情况下，事件 dispatch 都通过类型化消息流动，而不是暴露 runtime tree。
