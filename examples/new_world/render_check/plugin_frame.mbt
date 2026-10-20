///|
/// 插件入口的**帧适配层**（计划 P5.3）。
///
/// P5.3 的链条是：
/// `plugin_init(w,h)` → `view(model, layout)` → `draw_commands()` → 编码返回。
///
/// 只有第一步 `plugin_init` 需要真实例（它由宿主在实例创建后调用）。**中间的
/// 「给定尺寸渲染出一帧命令」是纯函数**：`Layout::for_width`（P5.1）与
/// `Program::draw_commands` 都已存在，这里只是把它们按插件宿主需要的形状接起来。
///
/// 放在 `render_check` 而不是 `app`：`app` 包只依赖 `@moui` 门面（见
/// `docs/moui-app-package-boundary.md`），而 `draw_commands` 属于 `runtime` 层，
/// 引入它会把 app 拉出允许的依赖集。

///|
/// 按宿主给的矩形渲染一帧，返回 DrawCommand 序列。
///
/// `layout` 显式传入而不是内部按宽度反推：宿主可能已经知道自己的列宽策略
/// （面板模式与整窗模式不同），在适配层再猜一次会与宿主不一致。
pub fn plugin_frame(
  model : @app.WorldModel,
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  // `new_view` 而不是 `new_program_with_dimensions`：插件宿主每帧拿到的是
  // **一个模型 + 一个矩形**，没有 TEA 循环（循环在插件内部）。用一个纯视图
  // 入口更贴近宿主实际要做的事，也让这条路径可以在没有 effect/subscription
  // 的情况下断言。
  let runtime = @runtime.new_view(
    root=@app.view_for(model, @app.Screen::for_viewport(width, height)),
    size=@core.Size::new(width~, height~),
  )
  runtime.draw_commands()
}

///|
/// 按宿主矩形渲染一帧并编码成插件帧文本（P2 的 `Array[DrawCommand]` 边界）。
///
/// 这就是 `plugin_render()` 在宿主侧要做的事：拿到命令、编码成宿主能读的文本。
/// 编码走 `moui/core` 的既有实现，与宿主侧的 `draw_commands_from_json` 成对。
pub fn plugin_frame_json(
  model : @app.WorldModel,
  width : Double,
  height : Double,
) -> String {
  @core.draw_commands_to_json(plugin_frame(model, width, height))
}
