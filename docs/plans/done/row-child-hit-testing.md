# Row-child hit testing and drag modifiers — resolved as a coordinate-space misdiagnosis

- **Status:** done (2026-09-26 复核关闭：原症状是**坐标系误用导致的测试误判**，框架无缺陷；行为已由回归测试固定)
- **Found**: 2026-09-25, while building `examples/moblocks_studio` (M2)
- **Owner**: framework (moui/runtime + moui/views)

## Symptom

在 moon 0.1.20260920 + MoUI 本地工作区下：

1. **`row` 直接子级控件（按钮）不接收指针点击**：`column([row([button(...), ...])])` 中，
   row 的按钮子级完全不命中（native runtime 与 Chrome wasm-gc 表现一致）。
   而 `row → column → button` 的嵌套按钮正常命中。
2. **`scroll_view` 作为 `row` 子级时，其内部控件同样不命中**（top-level column 下的
   scroll_view 内部按钮正常）。
3. **`on_drag` / `on_drag_with_frame` 修饰符不触发**：无论挂在 `canvas` 还是普通 `text`
   上，无论位于 view 根部还是嵌套布局中，native runtime 下 Down/Move 事件均不产生
   拖拽手势（`on_tap` 系按钮点击正常）。
4. 画布（`@views.canvas` + `on_drag_with_frame`）因此无法完成节点拖拽。

## Repro

`examples/moblocks_studio` 的测试文件保留了可用证据（`moblocks_ui_test.mbt`）：

- `M2：扁平列按钮可经指针事件驱动（运行）`：底部滚动面板中的扁平「运行」按钮经
  `AppRuntime.dispatch_event(Pointer(...))` 点击后 notice 变为「运行开始」——通过。
- `M2：检查器 AI 生成按钮可经指针事件驱动`：检查器列内扁平按钮点击生成提案——通过。
- 已删除的回归测试（row 内「放大」按钮 + 画布拖拽选中节点）在修复前会失败：
  - 放大测试：`click_text(runtime, "放大")` 后节点文本宽度不变（缩放未生效）。
  - 拖拽测试：在节点文本帧中心派发 Down/Move/Up 后，检查器不显示选中标题。

补一个最小复现（框架侧，无需 app 上下文）：

```moonbit nocheck
test "row child button misses pointer" {
  let received : Array[String] = []
  let root : @moui.View[String] = @views.column([
    @views.row([
      @views.button("InRow", on_click="row", width=80.0, height=28.0),
    ]),
    @views.column([
      @views.button("InColumn", on_click="col", width=80.0, height=28.0),
    ]),
  ])
  // runtime 布局后按「InRow」文本帧中心派发 Down/Up：received 不含 "row"；
  // 对「InColumn」同样操作：received 含 "col"。
}
```

## 真实根因（2026-09-26 定位）

三项症状都不是框架缺陷，而是**坐标空间混用**：

1. **画布 draw 命令里的文本帧是画布局部坐标**。`@views.canvas` 的 draw 回调在
   transform 下绘制，但 `AppRuntime.draw_commands()` 记录的 `DrawText.frame`
   是变换前的局部帧；而指针事件是屏幕坐标。旧回归测试「按节点文本帧中心派发
   Down/Move/Up」把局部帧当作屏幕点用，点击落在积木上方 42px（画布屏幕原点
   (0,42) = notice 32px + 根 column 间距 10px）的空白处 → hit_test 未命中 →
   被误判为「on_drag 手势不触发」。
2. **拖拽手势的 `Started` 发生在第一次越过 3px 阈值的 Move 上**（不是 Down）。
   不了解这一点会让测试少发一次步进，从而只观察到「按下」没有「拖动」。
3. row 直接子级按钮与 scroll_view 子级命中在 8 种形状探针下全部正常。

Studio 画布拖拽链路（CanvasPress → hit_test → DraggingNode → CanvasDragTo →
MoveNode）经 AppRuntime 端到端验证可用，回归测试见
`examples/moblocks_studio/app/moblocks_ui_test.mbt`（46/46）。

## Acceptance（2026-09-26 复核结论）

全部条目**已验证通过**：

- [x] row 直接子级按钮命中：8 种形状探针（单按钮/双按钮/文本+按钮/spacer+按钮/
      scroll_view/padding/嵌套 row/顶层 scroll_view）全部收到指针事件。
- [x] `scroll_view` 作为 row 子级时内部控件命中。
- [x] `on_drag` / `on_drag_with_frame` 在普通 view、按钮与 `canvas` 上均经
      Down/Move/Up 触发（探针分别收到 3 次手势消息）。
- [x] 行为固化为回归测试 `moui/runtime/row_child_pointer_input_test.mbt`（5 项，
      native + wasm-gc 双端 140/140 通过）。
- [x] 「恢复 Studio 删除项」：画布拖拽选中/移动节点的端到端回归已恢复并通过
      （`M2：画布积木可经拖拽移动`）；工具栏 row 的原位按钮无需恢复——
      row 子级命中本就正常，M2 的扁平面板保留为可访问的等价入口。

## Workaround (M2, 已落地)

- 所有可交互控件集中到 view 根部的滚动面板（扁平列）与检查器（扁平列）；
  工具栏 row 与画布拖拽暂不使用，节点选择改为面板内「选择积木」按钮列表，
  节点移动（L1 交互）暂缓——与计划中的画布递进降级策略一致。
