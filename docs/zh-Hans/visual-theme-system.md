# 视觉主题系统

> 本文档描述 ThemeSpec → Theme 管道、ColorPalette、组件主题和环境主题解析。
> 概述见 [架构](architecture.md)。控件样式细节见 [按钮样式指南](button-styling-guide.md)。

视觉系统是一条 `ThemeSpec -> resolve_theme -> Theme` 管道。`core`
拥有中立的模式和解析器；带品牌的设计系统是插件式适配器，生成同一个
`@core.Theme`：

- `core` 拥有 `ThemeSpec`（preset/color-mode/density/contrast/seed/reduced-motion
  意图）、`resolve_theme(spec, system_scheme)` / `resolve_minimal_theme`、
  `Theme` 模式，以及 `Theme::neutral()` 兜底。`ColorPalette` 携带完整的
  on*/container 角色矩阵（primary/on_primary/primary_container、
  secondary、tertiary、error、surface/on_surface/on_surface_variant，带有
  on-colors 的语义 success/warning/danger/info、outline/outline_variant、focus、
  scrim），因此带品牌的系统不需要临时推导角色。
- `Theme` 是一个令牌记录，包含 scheme、palette、spacing、radius、typography、
  shadow、motion 和 surfaces——**没有控制词汇表**（ADR 0017）。
  控制令牌位于 `@views.ControlThemeSet`（`button`、`text_field`、
  `surface`、`choice_control`、`progress`、`slider`、`picker`、`feedback`、
  `badge`、`form_validation`），每个都保存 `ControlStateTokens`，并在绘制时通过
  `ButtonTheme::resolve(variant, state)` 等解析为 `ControlStateStyle`。
  应用和控件代码读取规范分组，例如
  `theme.palette.foreground`、`theme.palette.on_primary`、
  `control_set.button.primary`、`theme.typography.body`、
  `theme.spacing_scale.sm` 和 `theme.radius_scale.md`。
- `@views.light_theme()` / `@views.dark_theme()` 通过
  `resolve_minimal_theme` 解析 Minimal 预设。`@views.theme(...)` 会把整组令牌
  叠加到可选基底上。环境携带的 `ControlThemeSet` 由
  `minimal_control_theme_set(theme)` 构建，并与 `Theme` 一起穿过视图环境。
- `Environment` 携带 `theme_spec`（用户意图）、`system_scheme`
  （宿主报告）和解析后的 `theme`。`with_system_scheme` 会从 `theme_spec`
  重建完整主题，因此宿主 `ThemeChanged(Dark)` 事件会切换调色板、表面和阴影，
  而不只是切换一个 scheme 标志。旧的 `with_color_scheme`
  （会留下过期调色板）已移除。
- 控件在绘制时以**环境方式**解析样式：每个控件的 `theme?` 参数都是可选的
  （不捕获 `default_theme()`），绘制闭包读取
  `theme.unwrap_or(ctx.environment.theme)`，因此按钮/复选框/
  文本框/进度条/滑块/选择器等可以通过 `set_environment` 跟随暗色模式 /
  高对比度 / 减少动态效果 / 调色板变化，而无需调用方重建视图树。
  叶子控件会发出 `"context"` 修订令牌，使协调过程延后到由环境驱动的重绘。
  组合视图通过共享的 `views_ambient_theme(theme)` 辅助函数解析构造期布局读取
  （spacing/shadow，兜底到 `Theme::neutral`），并把解析后的主题传给叶子子控件。
- `ButtonVariant::style(control_set)` 通过 `ButtonVariantToken` 从
  `control_set.button` 解析变体；控件默认走这条路径，`style?` 是一次性覆盖。
  `ButtonVariant` 覆盖 Primary/Tonal/Outline/Ghost/Subtle/SubtleBrand。
  `ControlStateStyle` 携带可选的 `bottom_border_only` 和 `inner_focus_border`
  字段，使 Fluent 2 下划线输入框和焦点显露内描边无需变体专用绘制路径也能渲染。
  `ControlStateStyle` 位于 `core`，由令牌解析器和视图层样式结构共享。
- `View::theme(...)` 和 `View::environment(...)` 会在布局/绘制时通过
  `child_environment` 钩子把主题/环境级联到子树；它们的 modifier 修订包含内容指纹，
  因此协调过程可以检测真实主题变化。
- `ChoiceControlTheme` 携带 `box_shape`（`Square`/`Circle`）和
  `check_style`（`Checkmark`/`Dot`），因此复选框渲染为带有 "✓" 字形的圆角方框，
  而单选框渲染为带实心内点的圆环（Fluent 2 风格）。
  `checkbox` 接受可选的 `box_shape?`/`check_style?` 覆盖；`radio`
  传入 `Circle`/`Dot`。`SliderTheme` 携带
  `thumb_shape`（`Rounded`/`Circle`）；Fluent 2 滑块使用圆形滑块柄。
- `DesignSemanticPalette` 携带中性色阶
  （`background_2`/`background_3`/`background_4`、`foreground_2`、
  `stroke_1`/`stroke_2`/`stroke_accessible`）以及独立的 `brand_stroke`，
  因此 Fluent 2 的 `colorNeutralBackground1/2/3/4`、
  `colorNeutralForeground1/2`、`colorNeutralStroke1/2/Accessible` 和
  `colorBrandStroke1` 可以被分别表达。`core_palette()` 会把该色阶映射到
  `ColorPalette` 表面层级（surface=background_2、surface_variant=background_3、
  outline=stroke_1、outline_variant=stroke_2）。`divider` 使用
  `outline_variant`（柔和的 stroke_2）；菜单/弹出层读取
  `control_set.surface.overlay_shadow`（Fluent 浮出阴影），并兜底到
  `shadow_scale.lg`/`md`。
- `presence_dot(status, ...)` 将 Fluent 2 PresenceBadge 状态点
  （Available/Away/Busy/Offline/Unknown）渲染为带对比边框的实心圆，可叠放在头像上。
- `SurfaceStyle` 支持表面画刷、圆角、内边距、边框元数据和阴影元数据。
- `moui_theme/*` 会从 `DesignSystemTokens::to_theme()` 生成完整的
  `@core.Theme`（调色板 + 比例尺 + 组件）；`core_component_styles()`
  保留用于生成诊断报告。想让 Fluent 2（或其他带品牌系统）驱动控件外观的应用，
  调用一次 `@fluent.theme(...)` 并把它作为根主题传入；控件会自动继承
  `components`，而不是逐控件传入 `style=` 参数。
- `ShadowStyle` 和 `BorderStyle` 是视图级样式输入；绘制会在最终 frame
  已知后把它们转换为具体的 `DrawCommand` 载荷。
- `animated_value`、`animated_point`、`animated_color`、`TransitionSpec` 和
  `TransitionStyle` 为状态驱动的视觉效果提供小型属性动画采样器。
  `View::transition` 和 `View::presence` 会通过既有的不透明度、偏移、
  缩放和前景色 modifier 应用这些采样，并包含减少动态效果的捷径。
- `ImageFit::Contain/Cover/Stretch/ScaleDown/FitWidth/FitHeight` 记录图像意图，
  并在视图规格中保留 source、opacity 和圆角裁剪。
- 原生 Skia 和 WebGPU 渲染器在主线上保持可见绘制命令支持。Skia 负责原生栅格像素
  和文本诊断，而 WebGPU 负责浏览器 wasm-gc 呈现。实验性原生 WGPU 仍在明确请求时
  验证 GPU 路径。

视图构造器会把 `Brush`、边框和阴影数据传入 `DrawCommand`，不会调用
`Brush::fallback_color`；兜底集中在渲染器能力层。

原生 Skia 渲染器是渲染器 smoke 和平台入口验证的推荐原生基线。它通过平台
Skia provider 呈现 CPU 像素帧，并使用本地 `moui_skia` 绑定进行栅格、路径、图像
和文本诊断。WebGPU host-import 渲染器会把完整命令集转发给浏览器运行时。
实验性原生 WGPU 在明确请求时继续覆盖 GPU surface 路径和 provider 文本集成。
见 [渲染器能力报告](renderer-capability-report.md)。

文本测量流经运行时 `TextSystem` 契约。`core/` 拥有中立契约和确定性兜底；
原生 Skia 主线暴露 `skia_text_system()` 用于渲染器/文本诊断，WGPU 诊断 provider
位于 `moui_wgpu_renderer/*` 下，Web 安装一个由浏览器 Canvas 支撑的系统，以匹配其
WebGPU 字形路径。见 [文本系统](text-system.md)。
