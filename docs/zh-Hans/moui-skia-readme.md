# wzzc-dev/moui_skia

Skia Graphics Library 的 MoonBit 绑定，结构参照
`rust-skia/rust-skia`。

公共 API 的组织理念与 `skia-safe` 一致：从安全的值层绘制类型开始，
通过 `native` 子包选择进入原生句柄，并把资源规划/帧提交契约视为后端
集成 API。

- 安全绘制值：几何、颜色、图像元数据、变换、画笔、采样和可移植路径可直接从
  `@moui_skia` 使用。
- 原生绘制句柄：`@native.Surface`、`@native.Canvas`、`@native.Image`、
  `@native.Path`、`@native.Font`、shader、filter 和 codec 是选择启用项，
  在回退构建中返回 `None`，而不是暴露不可用的句柄。
- 后端规划契约：`SurfaceTargetDescriptor`、`RenderCommandList`、
  `RenderFrameDescriptor`、`RendererResourcePlan` 及相关描述符面向需要
  replay、缓存预检、present，或未来 GPU 准入检查的 GUI/runtime 集成。

当前包暴露以下值层 API 面：

- 几何：`Point`、`IPoint`、`Size`、`ISize`、`Rect`、`IRect`、`RRect`，
  包括点向量 helper、矩形构造器、排序性、中心、偏移和整数舍入 helper
- 颜色：`Color`、`Color4f`
- 图像元数据和像素布局：`ColorInfo`、`ImageInfo`
- 复制的像素快照：`Pixmap`
- 变换：`Matrix`，包括成员访问、有限值和仿射查询、前置/后置 concat helper，
  以及点/向量/半径/矩形映射
- 画笔状态：`Paint`、`PaintStyle`、`StrokeCap`、`StrokeJoin`、`BlendMode`
- 画布点绘制模式：`PointMode`
- 图像采样：`SamplingOptions`、`FilterMode`、`MipmapMode`、
  `CubicResampler`
- 表面契约：`SurfaceDescriptor`、`SurfaceTargetDescriptor`、
  `SurfacePresentDescriptor`、`SurfaceFinalizationDescriptor`、
  `WindowSurfaceDescriptor`、`SurfaceBackend`、`SurfaceOrigin`、`SurfaceBudget`、
  `SurfacePresentMode`、
  `GpuContextBackend` 和 `GpuContextDescriptor` 面向栅格、窗口和
  未来 GPU 渲染目标，提供稳定的窗口目标身份，以及面向后端表面、present
  调度、finalization 和 GPU context 缓存的类型化资源描述符
- 渲染器资源缓存：`ResourceCache` 和 `ResourceCacheStats` 为图像、shader、
  typeface 以及其他后端拥有的资源提供确定性的字节预算 LRU 边界，包括针对驻留
  和缺失的可缓存资源计划进行缓存预检拆分
- 渲染器资源身份：`RendererResourceKind`、`RendererResourceKey`、
  `RendererResourceDescriptor` 和 `RendererResourcePlan` 为这些缓存提供
  类型化 key，并为图像、shader、filter、文本段、路径、表面和未来 GPU 资源提供
  可审计资源需求，包括面向后端准入检查的 GPU-backed 资源子计划，以及用于把可复用
  句柄与一次性帧工作分开的可缓存/不可缓存子计划
- shader 和 filter 资源配方：`ShaderDescriptor`、
  `ColorFilterDescriptor`、`ImageFilterDescriptor` 和 `MaskFilterDescriptor`
  在后端分配原生 shader/filter 句柄前提供稳定的缓存 key
- 渲染通道契约：`RenderPassDescriptor`、`RenderPassLoadOp` 和
  `RenderPassStoreOp` 在具体后端记录绘制命令前定义目标边界以及
  load/clear/store/present 语义，包括从 `SurfaceTargetDescriptor` 派生的默认值
  和面向目标表面的资源描述符
- 渲染命令契约：`RenderCommandList`、`RenderCommand` 和
  `RenderCommandStats` 提供后端中立的命令流边界，GUI 渲染器可在将其 replay 到
  原生 Canvas 之前进行验证，包括 current-clip 颜色/画笔和 shader 填充、
  圆角矩形和路径裁剪、可缓存文本段和成形 glyph-run 绘制命令、显式
  shader/filter/image 资源声明，以及面向目标边界的后端缓存资源计划
- 渲染帧契约：`RenderFrameDescriptor`、
  `RenderFrameSubmissionDescriptor`、`RenderFrameFinalizationDescriptor` 和
  `RenderFrameValidationStatus` 将目标、finalized 命令流、资源计划、就绪诊断、
  缓存填充边界、可选 present 调度描述符，以及可审计的逐帧 submission/finalization
  资源计划组合起来；这些计划带有 GPU-backed 加可缓存/不可缓存子集，用于后端准入、
  缓存暂存和驻留/缺失预检
- 文本布局和 fallback 契约：`TextRunDescriptor`、
  `TextMeasurementDescriptor`、`MeasuredTextRunDescriptor`、
  `TextShapingDescriptor`、
  `ShapedTextRunDescriptor`、`ShapedGlyphRunDescriptor`、`FontDescriptor`、
  `FontFallbackRequest`、`FontFallbackMatchDescriptor`、
  `FontFallbackResolutionDescriptor`、`FontFallbackChain` 和 `FontStyleRequest`
  为原生成形和字体 fallback 定义值层输入和已解析匹配元数据，包括确定性的字节范围
  文本段、文本测量、测量结果、文本成形、成形结果、详细成形 glyph、字体、fallback
  请求、fallback 匹配和 fallback 解析资源 key；无效的测量/成形/fallback 请求/结果
  元数据保持不可缓存且不带下游缓存依赖，并且包含面向后端测量、成形、字体句柄和
  typeface 解析缓存的计划
- 可移植路径：`Path`、`PathLine`、`PathRect`、`PathVerb`、`PathFillType`、
  `PathDirection`、`PathSegmentMask`，
  包括 verb/point 计数、轮廓闭合查询、矩形、椭圆、圆、圆角矩形和折线/多边形轮廓、
  控制点和紧边界、append/extend path 模式、路径追加、资源描述符、`reset`
  和 `rewind`

原生 Skia 对象句柄会有意放在单独的 FFI 计划之后分阶段引入，以便 ownership、
ref-counting 和 linker 配置能够逐包验证。

`native` 子包包含第一批选择启用的原生边界：

- `@native.skia_available()` 报告 stub 是否使用真实 Skia 头文件和库编译；
- `@native.skia_shaper_available()` 报告 SkShaper
  边界是否已编译并链接；
- `@native.skia_paragraph_available()` 报告
  SkParagraph 边界是否已编译并链接；对于应在 SkParagraph、SkShaper、SkUnicode、
  HarfBuzz 或 ICU 支持缺失时失败的 smoke/proof 运行，使用
  `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1`；
- `@native.Surface::raster_n32_premul(size)` 是第一个栅格表面入口；
- `@native.Surface::gpu_context_support_status(context)` 报告值层 context
  描述符的原生 GPU-context 就绪门控。macOS Metal 探测通过
  `MOUI_SKIA_ENABLE_GPU_METAL=1` 选择启用；它检查 Skia
  Ganesh Metal 头文件以及真实的 `GrDirectContext` 创建；
- `@native.GpuContext::metal(context)` 在选择启用的就绪门控可用时创建显式原生
  Metal/Ganesh context；
- `@native.Surface::gpu_n32_premul(context, descriptor)` 和
  `@native.Surface::for_target_with_gpu_context(target, context)` 为匹配的 GPU
  目标/context 对分配离屏 GPU-backed Skia 表面；
- `@native.Surface::target_support_status(target)` 报告目标是否可分配为原生表面，
  包括空目标、Skia 不可用、窗口不支持和 GPU 不支持等判定；
- `@native.Surface::for_target(target)` 从值层 `SurfaceTargetDescriptor` 值分配
  受支持的栅格目标。此默认路径仍仅支持栅格；GPU 目标必须使用显式 target+context API；
- `@native.Surface::descriptor()` 报告原生栅格表面满足的值层表面契约；
- `@native.Surface::image_snapshot()` 在表面可用时返回不可变 `@native.Image`
  句柄；
- `@native.Surface::image_snapshot_with_bounds(bounds)` 对有边界的表面矩形取快照，
  并拒绝超出表面边界的矩形；
- `@native.Surface::flush_and_submit()` 为原生表面建立显式 finalization 边界；
  栅格表面将其视为 no-op，而 GPU-backed 表面会通过其拥有的 direct context flush；
- `@native.Surface::render_frame(frame)` 和 `render_frame_with_resources(...)`
  返回 `SurfaceFrameReplayStats`，其 `status()` 会分类验证、表面不匹配、replay 跳过、
  finalization 失败和完成结果；这些 stats 还暴露用于原生 flush/submit 边界的
  值层帧 finalization 描述符和资源计划；
- `@native.NativeReplayResources::stats()` 报告 Canvas 和 Surface 帧 replay 使用的
  原生 replay 缓存中的聚合缓存槽位、驻留资源、字节预算、命中、未命中和驱逐；
- `@native.Surface::read_pixels(bounds)` 将 N32 premultiplied 表面像素读取到自有的
  `@moui_skia.Pixmap`，并拒绝超出表面边界的矩形；
- `@native.Image::encode_to_data(format, quality)` 为 PNG/JPEG 输出返回不可变
  `@native.Data` 字节；WEBP 仅在链接的原生 Skia 构建暴露编码器能力时启用，
  会拒绝不受支持的原生编码格式，并把 quality clamp 到 Skia 的 `0..100` 范围；
- `@native.Image::from_bitmap(bitmap)` 将原生 bitmap 快照为不可变图像；
- `@native.Data::from_bytes(bytes)` 和 `@native.Image::from_encoded_bytes(bytes)`
  提供第一条内存内图像解码路径；
- `@native.Codec::from_data(data)` 和 `@native.Codec::from_bytes(bytes)` 暴露
  已编码图像元数据，并解码为 N32 premultiplied `Bitmap`；
- `@native.Bitmap::alloc_n32_premul(size)` 拥有栅格像素存储，并可导出复制后的
  `@moui_skia.Pixmap`；
- `@native.FontMgr::default()` 枚举原生字体族，并将一个字体族加 Skia 风格的
  weight/width/slant 值匹配到 typeface；
  `@native.Typeface::default()` / `from_name(family, weight, width, slant)` 和
  `@native.Font::default(size)` / `from_typeface(typeface, size)` 创建第一批用于绘制
  和测量的原生文本句柄；原生 typeface 可报告其 Skia family name；原生字体大小、
  成形宽度和 glyph 位置原点在跨入 Skia 前会进行有限值检查；
  `FontStyleRequest` 和 `FontFallbackRequest`
  可通过原生 FontMgr/Typeface adapter 传递，包括当请求包含 BCP47 语言标签和 code
  point 时的 Skia 字符 fallback，随后以 `FontFallbackMatchDescriptor` 元数据记录，
  用于缓存规划；
- `@native.Shader::color(color)`、`linear_gradient(start, end, colors...)`
  和 `radial_gradient(center, radius, colors...)` 创建第一批用于 shader-backed
  paint 调用的原生 shader 句柄，退化的 linear-gradient 输入以及非有限
  linear/radial-gradient 几何会在原生 replay/资源规划前被拒绝；
- `@native.ColorFilter`、`ImageFilter` 和 `MaskFilter` 在创建原生句柄和值层资源规划前
  拒绝非有限参数，原生 FFI stub 也会将非有限 matrix/sigma 输入置空；
- 直接的无效 shader/filter 描述符变体会产生不可缓存资源描述符，即使绕过构造器也保持
  缓存安全；
- 原生 replay 会跳过无效的 shader/filter 描述符命令，且不会触碰或填充 shader、
  color-filter、image-filter 或 mask-filter 缓存；
- 原生 replay 会跳过不可解码或为空的 encoded image 绘制命令，且不会触碰或填充图像缓存；
- 原生 replay 让空路径绘制、裁剪和 path-shader 命令避开路径缓存查找，保持零
  path-cache 资源/未命中/命中，同时仍 replay 无害的空原生路径；
- 非有限值层路径会产生不可缓存资源描述符，会从命令列表资源计划中过滤掉，并在不触碰路径缓存的情况下跳过原生 replay；
- 原生路径追加会跳过非有限可移植路径或矩阵，且不会改变既有 `@native.Path` 几何；
- 直接的原生路径 verb、形状、变换和偏移 mutation 会跳过非有限输入，且不会改变既有
  `@native.Path` 几何；
- `@native.Path` 支持第一批路径构造调用：`new`、`reset`、
  `rewind`、
  `set_fill_type`、`fill_type`、`move_to`、`line_to`、`quad_to`、`cubic_to`、
  `conic_to`、`close`、`count_points`、`count_verbs`、
  `segment_masks`、`is_finite`、`is_inverse_fill_type`、
  `is_last_contour_closed`、`last_point`、`is_line`、`is_rect`、`is_oval`、
  `contains`、`bounds`、`compute_tight_bounds`、`add_path_value`、`add_poly`、
  `add_rect`、`add_oval`、`add_circle`、`add_round_rect`、`add_rrect`、
  `transform`、`offset` 和 `is_empty`；
- `@native.Path::from_value(path)` 在 Skia 已链接时将有限的可移植 `@moui_skia.Path`
  replay 到原生路径，并拒绝非有限路径；
- `@native.Canvas` 支持 `clear`、`draw_color`、`draw_paint`、
  `draw_point`、`draw_line`、`draw_points`、`draw_rect`、`draw_oval`、`draw_circle`、
  `draw_arc`、`draw_round_rect`、`draw_rrect`、`draw_drrect`、`draw_path`、
  `draw_image` 和 `draw_image_rect`，并带显式 `SamplingOptions`；还支持通过
  `draw_path_value` 绘制可移植路径、通过 `replay` 执行渲染命令 replay，并提供
  `CanvasReplayStats::status()` 诊断来区分完整 Canvas 工作、deferred surface present
  命令和已跳过的 replay 命令；同时提供 declarations、images、shaders、filters、
  paths 和 text resources 的命令/资源类别计数器，通过 `draw_text_utf8` 支持
  UTF-8 文本，文本段 replay 会遵守描述符字节范围并跳过空范围且不填充文本缓存，
  通过 `draw_glyphs` 支持定位 glyph run；无效 shaped glyph replay 会跳过且不规划
  可缓存依赖；当 SkShaper 已链接时，通过 `Font::shape_text_utf8` 支持可选的
  shaped glyph run，通过 `TextShapingDescriptor` 和
  `ShapedTextRunDescriptor` 提供 shaped-run 元数据，通过
  `ShapedGlyphRunDescriptor` 提供详细 shaped glyph-run 元数据；
  当 SkParagraph 已链接时，通过 `Paragraph::layout_utf8` 支持可选 paragraph layout，
  带 line metrics、UTF-8 range text boxes 和 UTF-8 hit-test offsets；
  通过 `Font::measure_text_utf8` 支持字体测量，通过
  `Font::count_text_utf8` / `Font::text_to_glyphs_utf8` 支持 glyph ID，通过
  `Font::glyph_width` / `Font::glyph_widths` 支持 glyph advance，通过
  `Font::glyph_positions` / `Font::glyph_x_positions` 和
  `Font::text_glyph_positions_utf8` / `Font::text_glyph_x_positions_utf8` 支持 glyph 位置，通过
  `Font::glyph_bounds` / `Font::glyph_bounds_many` 支持 glyph bounds，通过
  `Font::measure_text_bounds_utf8` 支持文本边界，通过 `Font::metrics` 支持字体 metrics，
  并通过 `draw_paint_shader` / `draw_rect_shader` 支持 color-shader paint；
- 直接的 Canvas 几何、裁剪、图像放置和文本/glyph 定位调用会跳过非有限坐标，且不会改变像素；
- 原生 Canvas paint 转发会 sanitize 非有限 stroke 标量，并且
  `save_layer` 将非有限边界视为无边界 layer；
- 原生 Canvas 图像采样会在 cubic 系数非有限时禁用 cubic resampling，从而使用普通
  filter/mipmap 采样保留图像绘制；
- `@native.Canvas` 还暴露第一批状态和变换调用：
  `save`、`save_layer`、`restore`、`restore_to_count`、`save_count`、
  `translate`、`scale`、`rotate`、`skew`、`concat`、`reset_matrix` 和
  `discard`；
- `@native.Canvas` 暴露使用 `ClipOp` 的 `clip_rect`、`clip_rrect` 和
  `clip_path` 裁剪、local/device clip bound 查询，以及
  rect/path quick rejection；
- 没有 Skia link flags 时，它会编译为安全回退并返回 `None`。

## 原生冒烟测试

常规测试套件通过跳过仅真实后端可用的断言，使无 Skia 的回退构建保持绿色。
真实原生 Skia 构建还应通过专用冒烟测试：

回退门控还会验证每个 target-specific 原生 MoonBit 文件都在 `native/moon.pkg`
中有一个不可用回退 twin，因此新的原生绑定不会意外地只在已链接 Skia 路径上编译。
CI 也运行 `moon check --target all`，以保持 wasm/js 回退和 native/LLVM target
map 可以一起编译。

```text
cd scripts/native_smoke
moon run --target native .
```

冒烟模块有意与默认测试套件分离。没有真实 Skia link flags 时，它会快速失败，
而不是静默地执行回退。

对于仅回退验证门控，运行：

```powershell
.\scripts\check-fallback.ps1
```

该脚本会格式化/检查根模块，运行 `moon info`，运行默认测试，并在没有真实 Skia
link flags 的情况下构建原生冒烟模块，使 smoke 入口保持可编译，同时在运行时仍需选择启用。

GitHub Actions 回退 workflow 在 Windows 和 Linux 上镜像此门控。
真实 Skia 冒烟测试有意保持独立，直到仓库拥有可重复的 Skia binary/build source
用于 CI。

可选 shaped-text 边界默认关闭，以便小型 Skia 构建仍可使用。在 macOS 上，当 Skia
library directory 还包含 `libskshaper`、`libskunicode_core`、
`libskunicode_icu`、`libharfbuzz` 和 `libicu` 时，将 `--enable-skshaper`
传给 `scripts/macos-skia-smoke.sh`。该 wrapper 会添加
`-DMOUI_SKIA_HAS_SKSHAPER`，链接这些 module libraries，并验证原生 smoke log
包含 shaped-run marker。

默认真实 Skia binary provider 现在是 `wzzc-dev/skia` GitHub release，
由 `skia-provider-lock.json` 锁定到 tag `dev-6d73578a36` 和 commit
`6d73578a36506d10bc044e920cc71037982e481d`。fetch helpers 会把 package 缓存
到 `.skia-cache/release` 下，并打印现有原生 package configurators 使用的
include/lib/flag 值。默认 link mode 是 static；dynamic libraries 需通过
`MOUI_SKIA_LINK_MODE=dynamic` 或 `--link-mode dynamic` 显式选择：

```bash
bash scripts/fetch-release-skia.sh --platform auto --arch auto --print-env
```

HarmonyOS 使用 platform-specific 的 `harmonyos_release` provider entry，因为第一批
被接受的 HarmonyOS assets 位于 release `dev-fcb9c18e54`，而不是默认 desktop/mobile
provider release。用以下命令显式选择它：

```bash
bash scripts/fetch-release-skia.sh --platform harmonyos --arch arm64 --link-mode dynamic --print-env
```

```powershell
.\scripts\fetch-release-skia.ps1 -Platform auto -Arch auto -PrintEnv
```

将[真实 Skia 冒烟验收清单](../../moui_skia/REAL_SKIA_SMOKE.md)用作真实后端 artifact
的验收 checklist。通过的回退构建、dry-run 或 syntax check 不足以声称真实 Skia
验收通过。

冒烟测试要求 `@native.skia_available()` 为 true。它会创建一个 32x32 栅格
N32 premul 表面，将其清为白色，绘制红、绿、蓝矩形，在 point、line 和 polygon
模式中执行 `draw_points`，绘制一个定位 glyph run，
检查 canvas save/restore 状态、clip bounds、quick rejection 和被裁剪的绘制，
读回像素，检查代表性的 BGRA N32 像素，
对表面取快照，将快照编码为 PNG，验证 encoded PNG signature，
将这些字节解码回图像，并解码一个 N32 bitmap，其像素仍匹配已绘制场景和
N32 channel layout。

在 Windows 上配合 MinGW-compatible Skia 构建，使用验收 wrapper 临时注入原生
link flags、运行冒烟测试、保存日志，并验证临时 package rewrite 之后已恢复：

```powershell
.\scripts\windows-accept-real-skia-smoke.ps1 -LogDir logs `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\Static
```

如果你的 Skia 构建需要额外 defines 或依赖库，传入 `-ExtraCcFlags` 或
`-ExtraLinkFlags`。该 helper 会在重写 package configuration 前检查 Skia 头文件以及
MinGW-compatible 的 `libskia.a` 或 `skia.lib` 是否存在。`Windows Real Skia Smoke`
workflow 将同一 helper 暴露为 manual job，供已经有此类 Skia 构建的 runner 使用。

在 Linux 上，使用验收 wrapper。当已有 Skia 构建对 system compiler 可见时，
传入其 include 和 library paths：

```bash
bash scripts/linux-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

对于需要额外 defines、rpaths 或依赖库的 Skia 构建，传入 `--extra-cc-flags`
或 `--extra-link-flags`。添加 `--dry-run-config` 可打印所选模式和有效的
build/smoke arguments，而不 fetch 或 build Skia，也不重写 `native/moon.pkg`；
在 source-build mode 中，它会打印已解析的 checkout/build paths 和 GN args；
配合 existing Skia paths 时，它还会检查 Skia header 和 library files，并打印将被注入的精确
native flags。使用 `libskia.so` 时，Linux smoke helper 会在运行 smoke executable
前把提供的 library directory 加入 `LD_LIBRARY_PATH`。传入
`--smoke-log logs/linux-native-smoke-output.log` 可将原生 smoke executable 的
stdout/stderr 与 wrapper log 分开保存。

在 macOS 上配合已有 Skia 构建，使用验收 wrapper：

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

macOS helper 默认添加常见 CoreFoundation/CoreGraphics/CoreText/ImageIO
frameworks；对于额外 Skia build dependencies，传入 `--extra-link-flags`。
当需要强制使用 `libskia.dylib` 或 `libskia.a` 时，使用 `--link-mode dynamic|static`
或 `MOUI_SKIA_LINK_MODE=dynamic|static`；`auto` 会根据可用 library files 选择模式。

package prebuild hook 现在默认为 native builds 启用原生真实 Skia configuration。
当你需要 fallback-unavailable 编译路径时，设置 `MOUI_SKIA_ENABLE_PREBUILD_SKIA=0`
或 `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1`。`MOUI_SKIA_SKIA_INCLUDE`、
`MOUI_SKIA_SKIA_LIB_DIR`、`MOUI_SKIA_SKIA_LIB`、
`MOUI_SKIA_EXTRA_CC_FLAGS`、`MOUI_SKIA_EXTRA_LINK_FLAGS` 和
`MOUI_SKIA_LINK_MODE` 的环境值优先于 release provider 默认值。
对于 cross-builds，设置 `MOUI_SKIA_PLATFORM`（`macos`、`linux`、`windows`、
`android`、`ios`、`iosSim`、`tvos`、`tvosSim` 或 `wasm`）、
`MOUI_SKIA_ARCH`（`arm64`、`x64` 或 `riscv64`），并可选设置
`MOUI_SKIA_CONFIG=Release|Debug`。Android builds 应显式设置
`MOUI_SKIA_PLATFORM=android`，使 prebuild 使用锁定的 Android artifact，而不是当前
desktop host platform。

要为 macOS 冒烟测试从源码构建一个小型 CPU-only Skia，运行：

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

`macOS Real Skia Smoke` workflow 将同一路径暴露为 manual GitHub
Actions job。

要从源码构建一个小型 CPU-only Skia，并在本地一次性运行带验收检查的 Linux 冒烟测试，
运行：

```bash
bash scripts/install-linux-smoke-deps.sh
bash scripts/linux-accept-real-skia-smoke.sh --work-dir .skia-cache/linux
```

在已经准备好的 Ubuntu runner 上，
`bash scripts/install-linux-smoke-deps.sh --check` 会验证 workflow 在投入原生冒烟工作前安装的同一组
apt packages。这包括 `libwayland-dev`、`libwayland-bin` 和 `wayland-protocols`，
它们是 `wzzc-dev/window` 在准备原生 smoke dependency graph 并生成 xdg-shell client
header 时需要的。Linux source-build 默认安装 `clang` 以及 fontconfig/FreeType/HarfBuzz
development headers，并将 `cc="clang"` / `cxx="clang++"` 传给 Skia GN，
使 smoke build 不依赖 runner 的默认 C++ compiler。

省略 `--skia-rev` 时，Linux source-build helpers 会读取
`skia-revision.txt`。首次成功的真实 runner 之后，请将该文件保持在一个 known-good
Skia commit；测试新 Skia revision 时可用 `--skia-rev` 覆盖。acceptance summary log
会记录已解析的 `skia_commit`；在 source-built run 通过后，使用下方 guarded pin
helpers 写入该值。不要把 release-provider commits 写入
`skia-revision.txt`；它们由 `skia-provider-lock.json` 跟踪。

对于首次 source-built Linux 验收，guarded pinning wrapper 会运行冒烟测试，
用必需的完整 commit hash 验证 artifact bundle，固定 `skia-revision.txt`，
并验证该 pin：

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux
```

它会拒绝 dry runs 和 existing-build Skia paths，因此只有真实 source-built
Linux 验收才能建立初始仓库 pin。它会在开始昂贵构建前检查 Ubuntu smoke dependencies；
传入 `--install-deps` 可先安装它们，或为 elsewhere-managed runner 传入
`--skip-deps-check`。

如果没有 `--skia-include` / `--skia-lib-dir`，验收 wrapper 会通过
`scripts/linux-real-skia-smoke.sh` checkout 并构建 Skia，捕获 wrapper 和原生
executable logs，验证 `native/moon.pkg` 已恢复，并检查 executable 打印
`moui_skia native smoke test passed`，证明真实 smoke 到达最终断言。
`Linux Real Skia Smoke` workflow 对真实运行使用同一验收 wrapper；其可选输入既可以从
`skia_rev` 构建 Skia，也可以复用 existing `skia_include` / `skia_lib_dir` pair
以及额外 compile/link flags。它还会每周作为昂贵的真实后端 canary 运行。
workflow 在安装 build dependencies 或编译 Skia 前运行 dry-run preflight，
随后在成功或失败时上传 preflight log、source-built run 的
`logs/linux-skia-build.log`、wrapper log、专用原生 executable log，以及
acceptance summary log，作为 `linux-real-skia-smoke-log` artifact。真实运行中，
它还会 grep `logs/linux-native-smoke-output.log` 查找
`moui_skia native smoke test passed`，并在 workflow summary 中记录 marker check。
同一 artifact check 可用
`scripts/verify-native-smoke-log.sh logs/linux-native-smoke-output.log` 手动重新运行。
summary 会记录所选模式、dry-run 设置、artifact 名称、关键 Skia 输入、
预期 log paths、marker check，以及
临时 package rewrites 在运行后是否已恢复。
设置 workflow 的 `dry_run_config` 输入，可在不安装 MoonBit/build dependencies、
不构建 Skia、不恢复 Skia cache、也不重写 package files 的情况下打印
已解析的 build/smoke arguments；配合 existing Skia paths 时，它还会检查 Skia
header 和 library files。workflow 仅在从源码构建 Skia 时恢复 Skia source-build
cache；`extra_gn_args` 会被 existing builds 忽略。

```mbt check
///|
test {
  let point = @moui_skia.Point::new(3, 4)
  let rect = @moui_skia.Rect::from_point_and_size(
    @moui_skia.Point::new(2, 3),
    @moui_skia.Size::new(4, 5),
  )
  let sorted = @moui_skia.Rect::new(5, 4, 1, 2).sorted()
  let fractional = @moui_skia.Rect::new(1.2, -2.8, 5.7, 3.1)
  let wide = @moui_skia.IRect::new(-2000000000, 0, 2000000000, 1)

  assert_true(point.is_finite())
  assert_eq(point.length_squared(), 25.0)
  assert_eq(point.dot(@moui_skia.Point::new(-2, 5)), 14.0)
  assert_eq(point.cross(@moui_skia.Point::new(-2, 5)), 23.0)
  assert_true(point.with_length(10) == Some(@moui_skia.Point::new(6, 8)))
  assert_true(point.rotate_cw() == @moui_skia.Point::new(4, -3))
  assert_true(rect == @moui_skia.Rect::from_ltrb(2, 3, 6, 8))
  assert_eq(rect.left(), 2.0)
  assert_eq(rect.bottom(), 8.0)
  assert_true(rect.tl() == @moui_skia.Point::new(2, 3))
  assert_true(rect.intersects(@moui_skia.Rect::from_xywh(5, 7, 3, 3)))
  assert_true(
    @moui_skia.Rect::from_points([point, @moui_skia.Point::new(8, -1)]) ==
    Some(@moui_skia.Rect::new(3, -1, 8, 4)),
  )
  assert_true(
    rect.to_quad() ==
    [
      @moui_skia.Point::new(2, 3),
      @moui_skia.Point::new(6, 3),
      @moui_skia.Point::new(6, 8),
      @moui_skia.Point::new(2, 8),
    ],
  )
  assert_true(
    rect.with_offset_to(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(10, -1, 4, 5),
  )
  assert_true(sorted.is_sorted())
  assert_true(sorted.center() == @moui_skia.Point::new(3, 3))
  assert_eq(wide.width_64(), 4000000000L)
  assert_true(!wide.is_empty_64())
  assert_true(fractional.round_in() == @moui_skia.IRect::new(2, -2, 5, 3))
  assert_true(fractional.round_out() == @moui_skia.IRect::new(1, -3, 6, 4))
}
```

```mbt check
///|
test {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(1, 1))
  let pixmap = @moui_skia.Pixmap::new(info, 4, b"\xff\x00\x00\xff")

  assert_true(pixmap is Some(_))
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.compute_min_byte_size64(), 4L)
}
```

```mbt check
///|
test {
  let paint = @moui_skia.Paint::new(
      color=@moui_skia.Color::from_rgb(0xff, 0, 0),
      anti_alias=true,
    )
    .set_stroke(true)
    .set_stroke_width(4)
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 8, 8),
  )

  assert_true(paint.style == Stroke)
  assert_true(paint.color == @moui_skia.Color::red())
  assert_true(
    path.stroke_bounds(paint) == Some(@moui_skia.Rect::new(-2, -2, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let sampling = @moui_skia.SamplingOptions::new(filter=Linear, mipmap=Linear)

  assert_eq(sampling.filter_ordinal(), 1)
  assert_eq(sampling.mipmap_ordinal(), 2)
  assert_true(!sampling.uses_cubic())
}
```

```mbt check
///|
test {
  let matrix = @moui_skia.Matrix::translate(10, 20).concat(
    @moui_skia.Matrix::scale(2, 3),
  )
  let rect = matrix.map_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 5))
  let points = @moui_skia.Matrix::translate(1, 2).map_points([
    @moui_skia.Point::new(0, 0),
    @moui_skia.Point::new(3, 4),
  ])

  assert_true(matrix.is_invertible())
  assert_true(rect == @moui_skia.Rect::from_xywh(10, 20, 8, 15))
  assert_true(
    points == [@moui_skia.Point::new(1, 2), @moui_skia.Point::new(4, 6)],
  )
}
```

```mbt check
///|
test {
  let path = @moui_skia.Path::new(fill_type=EvenOdd).add_circle(
    @moui_skia.Point::new(5, 5),
    5,
    direction=CCW,
  )

  let shifted = path.offset(10, 20)

  assert_eq(path.verb_count(), 6)
  assert_true(path.fill_type == EvenOdd)
  assert_true(
    shifted.bounds() == Some(@moui_skia.Rect::from_xywh(10, 20, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )

  assert_true(triangle.is_last_contour_closed())
  assert_eq(triangle.count_points(), 3)
  assert_true(
    triangle.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let base = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 2, 2),
  )
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )

  let combined = base.add_path(
    triangle,
    matrix=@moui_skia.Matrix::translate(10, 0),
  )
  let shifted = base.add_path_offset(triangle, @moui_skia.Point::new(10, 0))

  assert_eq(combined.count_verbs(), 9)
  assert_true(combined.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(shifted == combined)
}
```

```mbt check
///|
test {
  let rrect = @moui_skia.RRect::new(
    @moui_skia.Rect::from_xywh(0, 0, 10, 8),
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(3, 1),
    @moui_skia.Size::new(1, 2),
    @moui_skia.Size::empty(),
  )
  let path = @moui_skia.Path::new().add_rrect(rrect)

  assert_true(!rrect.is_rect())
  assert_true(
    rrect.with_offset_to(@moui_skia.Point::new(10, 20)).bounds() ==
    @moui_skia.Rect::from_xywh(10, 20, 10, 8),
  )
  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(3, 3, 4, 2)))
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rrect.bounds()))
}
```
