# 任务生命周期

MoUI 有多个异步/任务形态的接口。它们共享一条所有权规则：任务由创建它的
scope 拥有，取消在完成边界、进入应用状态之前检查。

## 所有权与取消矩阵

| 接口 | Owner | 取消机制 | 完成规则 |
|---|---|---|---|
| `Effect[Msg]` | `AppRuntime` program runtime | 按 key 替换 / runtime destroy | 只有当前 effect 代际的完成才派发 |
| `Subscription[Msg]` | `AppRuntime` subscription runtime | key/kind 变化 / runtime destroy | 取消后 source 回调停止 |
| `ServiceTask[T]` | app/services bridge | 返回的 cancel 闭包 | 取消后结果被忽略 |
| `TimerSource` | app environment | subscription cancel | 取消后 frame 回调停止 |
| `RouteSource` | app environment | subscription cancel | 按 token 移除 route handler |
| 渲染器 image request | `backend/common/image` + renderer session | request token / session dispose | 迟到的完成是 stale，不应用 |
| GPU worker control queue | `render/common` | worker shutdown / context loss | control 消息永不丢弃 |
| Renderer session | `backend/common/frame` | dispose / surface replacement | dispose 幂等；frame token 拒绝 stale 结果 |

## Teardown 顺序

```text
window close
  -> subscription cancel
  -> effect/task cancel
  -> in-flight image cancel
  -> renderer session dispose
  -> runtime destroy
```

Embedded detach/recreate 遵循同一顺序；`window` 事件循环拥有外层转换，不得
实现第二套顺序。

## 代际规则

每个完成都携带启动它的 scope 的 generation/token。token 不再匹配的完成被丢弃
（不投递、不记为 app error）。`effect_task_supersession`、image completion 与
subscription cancel 测试共享这条规则。

## 后续

下一步是把 `TaskScope`/`CancelToken` 值类型引入 `ServiceTask`、image request
与 GPU worker，并为 native/embedded teardown 增加确定性虚拟 scheduler 测试。
