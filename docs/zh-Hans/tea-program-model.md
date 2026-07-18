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

Custom-control 入口在 `moui/views` 中面向 app 暴露。App 代码、host 测试、smoke 检查和示例 app 应使用 `@views.text_field`、`@views.checkbox`、`@views.picker` 和 `@moui_richtext.markdown_editor` 等 helper（rich text 位于 `moui_richtext` addon，而不是 `moui/views`）。具体控件实现应位于 `moui/views`，并生成 `@core.View::node(...)`。它们不应添加 `@core.View::primitive_*_view` constructor 或 runtime lowering table entry。

有状态控件在必须订阅 framework cell 或桥接复杂控件状态时，可以使用带 `ComponentContext` 的局部 `@views.component` adapter；但共享 app 包应默认使用 `Program::simple` factory，并让平台入口通过 `moui/runtime` 创建 `AppRuntime` 值。具备 effect 的 app 应在 `update` 返回后续工作时使用 `Program::new`：`Effect::send` 直接重新进入类型化消息循环，而 `Effect::dispatch` 会把类型化消息 dispatcher 交给 effect runner，用于 app 自有 host-service bridge 或其它回调，而不让 `core` 带有平台特性。`Effect::run` 是普通一次性 runner 的结构化形式，适合出现在 diagnostics 中；它添加稳定 key、kind 和 label，同时把具体异步执行留在 `core` 之外。`Effect::host_service` 是 host-service bridge 的标准结构化运行 helper；它把 descriptor kind 固定为 `host-service`，而实际 service 调用仍由 app/backend 拥有。`Effect::task` 从 effect update 启动一次性可取消任务，`Effect::service_task` 是服务型一次性任务的标准 helper：它需要相同的 runtime-owned 取消生命周期，并带有稳定的 `service` descriptor kind。Runtime 会记录 active task descriptor，在第一次类型化 dispatch 时完成任务，当新任务以相同 key 启动时取消旧 active task，在 runtime 销毁时取消 active task，并忽略完成或取消后的陈旧 task dispatch。相同 key 的任务替换如果改变 descriptor kind，会记录为 `EffectTaskKindChanged`，这样 tooling 可以区分“服务型任务被替换成另一个任务类别”和普通的同类重启。

`@runtime.effect_plan_summary` 暴露 runtime-owned effect tree 诊断摘要，包括 batch、send、anonymous dispatch、structured run、task、none、scheduled leaf count、max depth、structured effect descriptor，以及重复 descriptor-key 的数量/名称，且不会运行 effect 回调。Program runtime snapshot 也报告 message queue 的 enqueue、drain、pending、max-pending 和 ignored program-dispatch 计数器，而不要求 `Msg` 值可序列化。每次 program-message drain 都被界定为一个 runtime turn：点击、`Effect::send` / `Effect::dispatch`、structured runner、effect task 或 subscription 同步排队的消息会保持 FIFO 顺序，但超过每 turn 上限的工作会留待下一个 host/runtime 入口处理，而不是让当前调用栈无限存活。由匿名 `Effect::dispatch` 或结构化 `Effect::run` 回调捕获的 dispatch closure 在 `AppRuntime::destroy()` 后会被忽略，因此迟到的 app-owned 回调不能重新进入已销毁的 program runtime。

`Program` constructor 也接受 `subscriptions=model => ...`；每个 `Subscription::listen` / `Subscription::run` 使用稳定 key，接收类型化 dispatcher，并可返回 cleanup 回调。`Subscription::timer`、`Subscription::animation_tick`、`Subscription::window_event`、`Subscription::host_event`、`Subscription::route_event` 和 `Subscription::service_completion` 为常见持续 source 类别标准化 descriptor kind，而不会在 `core` 中启动任何具体平台工作。`@runtime.subscription_plan_summary` 暴露声明的 none、batch、source、duplicate-key 数量/名称、max-depth 和声明的 source descriptor 结构，而不会启动 source。只有当 descriptor kind 仍然匹配时，现有 key 才会跨 model 变化复用；缺失的 key 会被取消；保留相同 key 但改变 kind 的 source 会以 `SubscriptionKindChanged` lifecycle reason 重启，防止 app 在复用 key 时静默保留旧 timer、host-event 或 service adapter。一个 subscription batch 中的重复 key 会在第一个之后被忽略并报告到 runtime diagnostics；`Subscription::map` 在把消息提升为父类型时，会保留子功能消息和 descriptor 身份。由已取消或已销毁 subscription 捕获的 dispatcher 会被忽略，因此陈旧回调不能在 subscription 生命周期结束后重新进入 model loop；program runtime 和 inspector snapshot 会把这些被忽略的 subscription dispatch 与正常类型化 dispatch/update 计数分开统计，并为 tooling 暴露 planned subscription descriptor、active subscription descriptor、active subscription kind-count summary 和 lifecycle entry。具体 timer、window、host-event、route 或 host-service adapter 留在 `core` 之外；core subscription runtime 只拥有平台中立生命周期、subscription plan diagnostics 和类型化 dispatch contract。`backend/host` 为 `Subscription::host_event` 提供具体 `HostEventSource` fanout adapter，为 `Subscription::window_event` 提供 `HostWindowEventSource`，为 `Subscription::timer` tick 提供 `HostTimerSource`，并为 `Subscription::route_event` fanout 提供 `HostRouteSource`。浏览器 history、原生 URL bar 和 OS deep-link dispatch 仍是 platform/app 层的后续工作。

Environment-aware TEA app 应使用 `*_with_environment` constructor，而不是在 view 层接收 `ComponentContext`。两种情况下，事件 dispatch 都通过类型化消息流动，而不是暴露 runtime tree。
