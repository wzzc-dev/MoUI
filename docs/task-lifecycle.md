# Task Lifecycle

MoUI has several async/task-shaped surfaces. They share one ownership rule:
a task is owned by the scope that created it, and cancellation is checked at
the completion boundary before the callback reaches app state.

## Ownership and cancellation matrix

| Surface | Owner | Cancel mechanism | Completion rule |
|---|---|---|---|
| `Effect[Msg]` | `AppRuntime` program runtime | replacement by key / runtime destroy | completion dispatches only while the effect generation is current |
| `Subscription[Msg]` | `AppRuntime` subscription runtime | key/kind change / runtime destroy | source callback stops after cancel |
| `ServiceTask[T]` | app/services bridge | returned cancel closure | result is ignored after cancel |
| `TimerSource` | app environment | subscription cancel | frame callback stops after cancel |
| `RouteSource` | app environment | subscription cancel | route handler removed by token |
| Renderer image request | `backend/common/image` + renderer session | request token / session dispose | late completion is stale, not applied |
| GPU worker control queue | `render/common` | worker shutdown / context loss | control messages are never dropped |
| Renderer session | `backend/common/frame` | dispose / surface replacement | dispose is idempotent; frame tokens reject stale results |

## Teardown order

```text
window close
  -> subscription cancel
  -> effect/task cancel
  -> in-flight image cancel
  -> renderer session dispose
  -> runtime destroy
```

Embedded detach/recreate follows the same order; the `window` event loop owns
the outer transition and must not implement a second order.

## Generation rule

Every completion carries the generation/token of the scope that started it.
A completion whose token no longer matches is discarded (not delivered, not
logged as an app error). The `effect_task_supersession`, image completion, and
subscription cancel tests share this rule.

## Open follow-up

`TaskScope`/`CancelToken` value types are the next step: adopt them in
`ServiceTask`, image requests, and the GPU worker, then add a deterministic
virtual scheduler test for native and embedded teardown.
