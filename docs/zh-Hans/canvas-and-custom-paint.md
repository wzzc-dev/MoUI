# Canvas 与自定义绘制

MoUI 面向应用的自定义绘制使用 `@views.canvas`、`@views.custom_layout`
以及 `PaintContext` 辅助函数（`fill_rounded_rect`、`push_clip`、
`push_opacity`、路径/着色器辅助函数等）。这些 API 发出普通的
`DrawCommand` 流；它们不依赖具体渲染器包。

## 何时使用哪一个

| API | 使用场景 |
| --- | --- |
| `canvas(measure, draw)` | 纯绘制，无子视图（Flutter `CustomPainter` / SwiftUI `Canvas`） |
| `custom_layout(measure, paint, …)` | 带可选子视图放置的自定义测量/绘制 |
| `custom_children_layout(...)` | 多子视图自定义布局 + 绘制 |
| 普通控件 + modifier | 主题令牌、内边距、不透明度、过渡采样 |

优先使用普通控件和主题令牌。需要程序化形状、图表、HUD 叠层或由指针驱动的草图时，
再使用 canvas。

## 最小 canvas

```moonbit nocheck
using @views {canvas, fill_rounded_rect}

fn swatch() -> @moui.View[Msg] {
  canvas(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=200.0, height=120.0))
    },
    draw=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=12.0),
        @graphics.Brush::solid(@graphics.Color::rgba(r=0.2, g=0.45, b=0.9)),
      )
    },
    semantics_label="Blue swatch",
  )
}
```

`PaintContext` 对 `views` 包局部可见；应用代码只会在 `draw` / `paint`
回调的第一个参数中看到它。用 `@moui/graphics`（或其中重新导出的 `@core`
等价项）构造颜色、画刷和路径。

## 指针驱动绘制

将 canvas 与手势 modifier 组合。对于简单画板，`View::on_drag` 已足够；
把笔画点保存在应用模型中。

```moonbit nocheck
canvas(measure~, draw~)
  .on_drag(event => CanvasDrag(event.position))
```

可运行的拖拽绘制卡片见 `examples/showcase/app/platform`。

## 动画

MoUI 面向应用的动画大多是**应用采样**：

- `View::transition` / `View::presence` 将 `TransitionSpec` 采样为不透明度 /
  偏移 / 缩放 / 前景色 modifier。
- `@moui/animation` 重新导出缓动和过渡类型。
- `@views.animated_canvas` 用于循环 canvas 运动：draw 回调从运行时绘制时钟接收
  `now_ms`，绘制计划会被标记为 animating，因此宿主会在没有 `@services.TimerSource`
  的情况下持续请求帧。
- `Subscription::animation_tick` 只是描述符种类；目前还没有通用宿主适配器。
  在模型层需要 tick 时，用 `@services.TimerSource`（如 Showcase Platform）
  或你拥有的宿主动画回调来驱动。

采样过渡时应尊重减少动态效果（见 core 过渡辅助函数和 Showcase 运动卡片）。

## 更深入的示例

| 示例 | 关注点 |
| --- | --- |
| Showcase Platform workspace | 最小 canvas + 由定时器驱动的不透明度 |
| 教程 `06-animation` | 由 `now_ms` 驱动的 `animated_canvas` orb |
| `examples/showcase` Advanced Rendering | 图层、混合、滤镜、着色器、路径、变换 |
| `examples/pdf_workbench` | `custom_layout` 页面位图 |
| `examples/markdown_editor` | 编辑器表面绘制 |

渲染器能力状态（渐变、滤镜、文本 shaping 等）位于
`docs/renderer-capability-report.md`，不在视图目录中。

## 相关文档

- [视图目录](view-catalog.md) — 控件矩阵
- [非渲染 cookbook](non-render-component-cookbook.md) — 宿主配方
- [TEA 程序模型](tea-program-model.md) — effects 和 subscriptions
