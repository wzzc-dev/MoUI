# Studio 插件内核（kernel + 三模式 + AI 满配）

## 架构事实

- **kernel 包**：`StudioServices[Msg]`（结构体即类型化服务注册表）、
  `EventBus[Event,Msg]`（纯监听器 `(Event)->Array[Msg]`，副作用走 update 臂）、
  贡献点类型、MoonBit 词法器（`moonbit_highlight`）。
- **插件即包**：plugins/ai（AiSessions 多会话切片 + `current()`/`amend()` 纪律）、
  plugins/terminal（TerminalState 行缓冲屏 + 列光标模型）。插件互不 import。
- **事件出箱**：Model.outbox + `fire_events`；跨域 flag 全灭
  （pending_code_project/pending_build/build_seq → EvCodeProjectWrite/
  EvBuildSubmit/EvPreviewWebNavigate|Reload）。
- **AI 宿主推导**：right_view(RvAi) > PsAi 中心 > 底栏 BtAi 页签——无联动状态。

## 硬门与踩坑

- `(x.field)(...)`：结构体闭包字段调用必须加括号（三犯）。
- `try_put`/`Array.remove` 会抛错/需 ignore；match 分支 action 裸 let 加大括号。
- `trim()` 返回 StringView（`.to_owned()`）；`moon.mod` import 仅版本化
  registry 依赖（workspace 成员不可导入 → PTY 技术 vendor 进组合根）。
- 棘轮真身在 `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt`
  （policy JSON 的 ratchets 只管生成文件）。
- goal-column：`TextControlStateContext.goal_column : Double?`（垂直播种/保持，
  水平/点击/插入重置）；空行走 blank-collapse 边界路径（整行端点即 goal 落点）。
- FFI 指针参数 `#borrow` 注解是 error 级；`moon.pkg` 只能有一个 `options` 块。
