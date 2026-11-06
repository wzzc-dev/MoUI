# 诊断

`moui/core/diagnostics` 是跨层诊断事实的共享信封。它是叶子包：不 import
runtime、backend、render 或 theme，因此任何层都能产生事件而不会形成依赖倒置。

## 信封

```text
DiagnosticEvent {
  code: String,            // 稳定目录键，例如 "renderer.feature.gap"
  severity: Info | Warning | Error,
  domain: Runtime | Render | Backend | Text | Accessibility | Services,
  message: String,
  source: String,          // provider/window/control 身份
  generation: UInt64?,     // 相关时的 semantics/session 代际
  frame: UInt64?,          // 相关时的帧序号
  detail: String?,         // 短载荷；长证据留在对应报告里
}
```

能力说明仍留在 `docs/renderer-capability-report.md`；诊断事件只携带短消息和
稳定 code，不携带完整证据文本。

## Sink

`DiagnosticSink` 由调用方拥有、有界、在采样边界 drain。它不是 runtime 热路径
日志（ADR 0056）。宿主/工具创建一个 sink，只传给它关心的生产者。

## 生产者与消费者

| 层 | 生产者 | 消费者 |
|---|---|---|
| Host 编排 | 渲染器选择/拒绝、窗口拒绝 | DevTools、宿主日志 |
| Runtime | full-damage 原因、semantics/action 失败 | DevTools、Showcase |
| Render | 每帧 `RenderFrameResult.diagnostics` | backend frame owner、DevTools |
| Text | 段落/字体回退 | 文本诊断 |
| Services | extension 不可用/失败 | Agent/MCP、宿主日志 |

`RenderFrameResult` 携带每帧 `diagnostics` 数组。渲染器在这里报告降级；
backend frame owner 可转发给 DevTools、embedded wire envelope 或 Agent 诊断面。

## 更新规则

先增加稳定 code，再增加生产者。测试断言 code 与 severity，而不只是消息文本。
