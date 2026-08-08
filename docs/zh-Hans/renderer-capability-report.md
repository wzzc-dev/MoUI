# 渲染器能力报告

本页按渲染器后端跟踪绘制命令覆盖情况。同一份状态数据已固化在
`render/capabilities.mbt` 中，并由 `render/capabilities_test.mbt` 检查。
Showcase 使用同一份后端列表，因此新的渲染器列来自结构化数据，而不是硬编码的
native/web 字段。渲染器支持声明仍来自本报告以及 renderer/provider 测试。报告顺序
遵循当前主线：native Skia raster、WebGPU wasm-gc、native WGPU 诊断，然后是
Sun CPU raster。平台就绪度与渲染器能力分开跟踪。macOS Skia smoke 日志可以支撑
仅限 macOS 的运行时说明，但如果没有匹配宿主的 smoke 日志，它不会提升
Windows/Linux 平台状态，也不会提升全局 Skia 字体排印或 native paragraph/bidi
就绪度。

状态含义：

- `supported`：由渲染器直接实现。
- `partial`：已有可见支持，但仍有后续工作。
- `gap`：尚无可见实现。
- `host-forwarded`：MoonBit 将命令转发给浏览器 WebGPU 宿主，没有本地运行时覆盖。
- `unavailable`：后端有契约或计划映射，但在当前 fallback-safe 构建中不能声明为受支持。

| 功能 | Skia 光栅原生 | Web wasm-gc | Native wgpu 诊断 | Sun CPU 光栅 | 后续工作 |
| --- | --- | --- | --- | --- | --- |
| 矩形 | supported | supported | supported | supported | Skia rect fill/stroke 有真实 native renderer 像素 smoke 覆盖。 |
| 圆角矩形 | supported | supported | supported | supported | Skia rounded fill/stroke 和 solid rounded brushes 有真实 native renderer 像素 smoke 覆盖。 |
| 渐变 | supported | partial | partial | supported | Skia 现在会为圆角矩形和路径渲染 linear 与 radial gradient brushes；browser WebGPU 和 native WGPU 诊断都会保留 radial rounded/path brush payloads，并在 visual shader 中对 radial interpolation 着色。Web 在 Web renderer smoke 记录真实 radial center/mid/edge 像素之前保持 partial；native WGPU 只对其 diagnostic smoke 保留同一要求。 |
| 阴影 | supported | supported | supported | supported | Skia soft rounded shadows 使用 `MaskFilter` blur，并有真实 native renderer 像素 smoke 覆盖。 |
| 文本 | supported | supported | supported | supported | Skia `Font` measurement、font-metric baseline/height、在链接 SkShaper 时使用 shaped-run cluster carets，否则使用 measured prefix carets，并为两条 caret 路径稳定 representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interior，提供 grapheme-safe mixed-run fallback segments，并将 best-available glyph-run rendering 裁剪到 `TextRun.frame`，同时通过 Skia `FontMgr` `FontFallbackRequest`/`Font` 解析 `FontSpec` family、weight、style、representative coverage characters 和 inferred fallback language tags；真实 native renderer smoke 覆盖 glyph-run 像素和有界 `TextRun.frame` 裁剪；更广泛的 shaping 另行跟踪。 |
| 图像 | supported | supported | supported | supported | Skia 验证 PNG/JPEG/BMP data URI decode、local PNG/JPEG/BMP decode、contain/cover/stretch/scale-down/fit-width/fit-height placement geometry、`draw_image_rect` 输出、ready/failed lifecycle records、failed-image placeholders、immutable-source failed-cache reuse，以及文件出现后的 local-file failure retry；Sun renderer-local tests 现在通过 `mizchi/image` adapter 覆盖 JPEG data URI 和 local-file decode，并覆盖相同的 contain/cover/stretch/scale-down/fit-width/fit-height placement 与 source-crop geometry；真实 native renderer smoke 覆盖 ready data URI/local PNG drawing 和 failed-image placeholders。 |
| 裁剪 | supported | supported | supported | supported | Skia rectangular、rounded 和 path clip scopes 有代表性的真实 native smoke 覆盖。Sun CPU raster 通过 `moui_sun` clip state 应用变换后的 rectangular clip bounds，并以 inverse-transform rounded masking 验证 2x rectangular/rounded clip 像素。 |
| 变换 | supported | partial | partial | supported | WGPU/Web 将 affine transforms 折叠进 planned vertices 和 scope state。Skia 将 MoUI affine fields 映射到 Skia matrix members，并有 translated、scaled-and-clipped、layer-masked opacity 和 filter-scoped 像素 smoke 覆盖。Sun CPU raster 现在会在 layer、rounded-clip 和 filter offscreen scopes 之间保留 transform/clip state。 |
| 透明度 | supported | supported | supported | supported | Skia save-layer opacity 有 blended pixel smoke 覆盖。 |
| 图层合成 | supported | supported | supported | supported | 每帧通过 `BeginRetainedLayer(spec)`/完整 payload/`EndRetainedLayer(key)` 声明 retained layer。Skia、Sun、WGPU 和 Web 的 renderer session 自己决定 hit、update、residency 与 eviction；runtime 和 backend 不保存 cache epoch/residency，也不提供 host command-cache fallback。 |
| 混合模式 | supported | supported | supported | supported | Skia 将所有 MoUI blend modes 映射到 Skia paint blend modes，并通过 renderer-local 像素验证 multiply；multiply/screen/overlay/darken/lighten 输出像素也由真实 native renderer smoke 覆盖。 |
| 滤镜效果 | supported | supported | supported | supported | Skia 通过 renderer-local tests 验证 saturation 和 identity-normalized color matrix filters；blur、saturation、brightness、contrast 和 color matrix filters 也由真实 native renderer smoke 覆盖。Sun CPU raster 在 offscreen canvases 继承父级 transform/clip state 后验证 transformed filter scopes。 |
| 路径/向量 | supported | supported | supported | supported | Skia 将 `PathSpec` 重放为 native paths，并有 renderer-local solid/gradient pixel tests，以及对 solid/gradient fill 和 stroke output 的真实 native smoke 覆盖，另含 quadratic 与 cubic curve verbs。WGPU/Web 共享 MoonBit tessellator，保留 path brush payloads，并通过 visual shader 提交 radial path vertices，而不是把 radial brushes 压平成单个 sampled color。 |
| 着色器效果 | supported | supported | supported | supported | Skia procedural solid、checker、linear-gradient-debug 和 vignette effects 有 renderer-local pixel tests 以及真实 native renderer 像素 smoke 覆盖；unknown names 仍使用 fallback paths。Sun CPU raster 现在会在 unknown shader name 回退到 spec fallback brush 时记录相同的 unsupported-command diagnostic shape。 |
| 文本 shaping | supported | supported | supported | supported | Skia 映射 `FontSpec` family、weight 和 style，在常规 family matching 之前用 representative emoji/non-ASCII coverage characters 加 inferred BCP47 script language tags 构造 `FontFallbackRequest` values，将 mixed-script text 拆成 grapheme-safe fallback segments 以便 per-run `FontMgr` resolution，返回 Skia font-metric baseline/height，并在链接 SkShaper 时返回 shaped-run cluster carets，否则返回 measured prefix carets，通过共享 UAX-style `TextGraphemeBoundaries` scanner 稳定 cluster interiors，暴露 `TextSystem::layout_paragraph()` line metrics、paragraph caret rectangles、selection rectangles 和 hit-test geometry，在可用时通过 native SkParagraph 路由 paragraph layout，在 system `FontMgr` 路径上为 emoji-hint text 重试 emoji-family fonts，并可在链接后绘制可选 SkShaper shaped glyph runs。Sun raster 在 `moui_sun/text` 之上暴露 renderer-backed `TextSystem`，其 requested-family-first fallback chain resolution 覆盖已注册 faces；renderer-local tests 覆盖 mixed Latin-plus-emoji measurement、有覆盖绘制时没有 missing fallback diagnostic、TextRun frame clipping 和 paragraph metadata。共享 scanner 使用生成的 Unicode 17.0 property predicates，`moui/core` 运行 curated 和 full vendored Unicode 17.0 default grapheme fixtures，`moui_skia_renderer` 通过 `skia_grapheme_cluster_texts` 运行同一 fixture。真实 Skia smoke 通过 `--run-text-emoji-smoke` 在 macOS/Linux/Windows 上获得 bidi Arabic 和 mixed-direction visual-order markers，以及 paragraph wrapping、selection rectangles、hit testing、grapheme editing 和 IME candidate/composition markers。 |
| Emoji 文本 | supported | supported | supported | supported | Skia 检测 representative single-codepoint、variation-selector、keycap、emoji-modifier、ZWJ、regional-indicator、emoji tag-sequence、Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark samples 和 Hangul Jamo grapheme cluster samples，在 system `FontMgr` `FontFallbackRequest` matching 中优先使用 emoji coverage characters 和 inferred language tags，稳定 representative cluster interior carets，在 default-font fallback 之前重试 platform emoji font candidates，并通过 `Typeface::has_color_glyphs` 和 glyph format metadata 报告 deterministic color emoji readiness。Sun raster 在 requested-family-first fallback chain 之上使用 `moui_sun/text FontFallbackPlan`，因此可在 Latin primary face 之后选择已注册 emoji coverage；renderer-local tests 覆盖 mixed Latin-plus-emoji measurement 和 covered draw diagnostics。text/emoji smoke 记录 high-saturation glyph/raster observation 以及 font/glyph metadata，其 non-empty source/script/fallback-request-character-aware glyph key 与已记录的 source、text-system、shaper、script、fallback language tag payload、language-count、fallback request character 和 format metadata 匹配，并通过 `--run-text-emoji-smoke` 在 macOS/Linux/Windows 上获得 keycap、regional-indicator 和 skin-tone-modifier fallback diagnostic markers。 |
| 异步图像 | supported | supported | supported | supported | renderer session 发出带 opaque token 的 `RendererImageLoadRequest`；backend image owner 只调度/取消字节 I/O，并以相同 token 回传 completion。session 返回 Applied/Stale/Disposed，只有 Applied 请求窗口重绘；Skia、Sun、WGPU 和 Web 各自拥有 decode、resource/cache 状态。 |

## 渲染器描述符

渲染器身份通过 `RendererDescriptor` 声明，而不是给 app code 或 view/runtime trees
添加固定字段。当前描述符为：

- `NativeWgpu`：family `Wgpu`，presentation `HostGpuSurface`，target `Native`。
- `WebGpuWasm`：family `WebGpu`，presentation `WebCanvas`，targets `WasmGc`
  和 `Web`。
- `SkiaRasterNative`：family `Skia`，presentation `CpuPixelFrame`，target
  `Native`。
- `SkiaGpuNative`：family `Skia`，presentation `HostGpuSurface`，target
  `Native`。
- `SunRasterNative`：family `Sun`，presentation `CpuPixelFrame`，target
  `Native`。

关于功能证明覆盖（哪个 CI job 证明哪个功能），见
[功能证明矩阵](../feature-proof-matrix.md) 和
[功能状态仪表板](../feature-status-dashboard.md)。

`RendererDescriptor` 描述静态渲染器能力身份。Native host runtime assembly
由应用拥有的 renderer providers 处理：`@render_skia.from_env(platform=...)` 在 `auto` 下
注册 GPU 后再注册 raster，`@render_wgpu.native(...)` 选择 diagnostic route，
`@render_sun.raster()` 选择 CPU raster route。`RendererSelection` helper 对按 families
或 backend ids 匹配的 reports 和 tests 仍然有用，但它不是 native host-core
option 或 provider contract。Web 继续使用 WebGPU wasm backend。

Skia binding 有明确的 Metal、D3D12、Vulkan 和 EGL/GLES window-surface
source paths，而 `moui_skia_renderer` 会报告 route preflight diagnostics。macOS real
Skia helper 可以添加 `--run-gpu-smoke`，这要求 renderer smoke log 包含
`MoUI Skia GPU Metal renderer smoke passed route=metal-gpu
surface_gpu=true present_count=1 pixel-markers`；该 marker 证明显式 GPU route
creation、GPU-backed offscreen surface rendering、readback，以及现有的
pixel-present callback。在同一个 helper 中，`--run-gpu-smoke` 还会为 Showcase
和 Markdown Editor first-frame runs 设置 `MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu`，
其日志必须在正常 first-frame marker 之前包含 `surface_route=metal-gpu;
surface_gpu=true` provider diagnostics。renderer-only GPU smoke 仍只是
offscreen/readback 证据。macOS first-frame smoke 还证明 `SkPicture` handoff
给拥有 Ganesh/Metal context 的 native worker，该 worker 获取 `CAMetalDrawable`、
重放、flush、present，并发出 `Presented`，且不调用 `read_pixels`。
同一 worker 在其他 native providers 中拥有 D3D12 swapchains/fences、Vulkan
acquire/render-finished synchronization，以及 EGL contexts/surfaces。Android
和 HarmonyOS cross-build 这些路径；iOS simulator 选择 Metal GPU route。
当宿主 GPU surface 可用时，product `auto` 在每个 native Skia platform 上默认使用
`SkiaGpuNative`。Windows/Linux 和 physical mobile seven-gate quality manifests
仍可能不完整。

## 当前 Native WGPU 诊断说明

Native wgpu 仍可作为诊断渲染器使用。它现在直接渲染 rects、rounded geometry、
linear gradients、soft shadows、glyph-atlas text 和 images。Image commands
使用完整 pipeline：通过 `mizchi/image` 进行 PNG/JPEG/BMP decoding、local file
和 base64 data URI sources、texture caching、GPU sampling、
contain/cover/stretch/scale-down/fit-width/fit-height fit modes，以及 fallback
handling。
Clip support 使用 transformed rectangular scissor rectangles 和带 shader SDF masks
的 rounded clips。Transform support 会应用到 planned visual、image、text、
shader-effect advanced vertices 和 masked layer composite vertices。Scoped layer/filter
child plans 继承 transform 和 clip state，同时 outer opacity 在 composite time
只应用一次；filter scopes 在 compositing 前保留 transformed child vertices 和
transformed clip scissors。Opacity 被折叠进 visual 和 text vertex alpha。
Layer compositing 和 filter scopes 会先渲染到 offscreen textures，再由 parent pass
通过 advanced composite shader 采样。该 pass 应用 opacity、rectangular 或 rounded
masks、built-in filter payloads 和 shader-effect payloads。Source-over、multiply、
screen、darken 和 lighten 使用 GPU blend-state mappings；overlay 使用单独的
backdrop-sampling pass，让 shader 可以按当前目标评估 per-channel overlay formula。
Vector paths 使用共享的 `moon_zeno` tessellation contract：fills 和 strokes
降为 triangle vertices，包括 flattened quadratic 和 cubic segments。native draw plan
现在通过 visual GPU pipeline 将这些 vertices 作为 path-colored triangles 提交，因此
`DrawPath` 不再是 fallback-only command。renderer-neutral SVG import path 使用
`mizchi/svg` 作为 parser frontend，并将支持的 scene graph shapes 降到相同的
draw-command model，同时报告不支持的 SMIL animation 和 `foreignObject` usage。
`render/capabilities.mbt` 还暴露 command fallback planner，会报告 unbalanced pops
以及打开的 clip、rounded-clip、transform、opacity、layer 和 filter scopes，同时让可见
`DrawPath` commands 不进入 fallback list。Native color glyph payloads 现在可以通过
provider protocol、glyph atlas 和 text vertex shader marker 作为 RGBA data 流动；
Cosmic 会在可用时加载 platform emoji fallback font candidates，保留 color swash pixels，
并在 native layout 前 safe-map provider-fragile emoji samples，使 caret diagnostics
保持稳定；CoreText 在 macOS 上将 AppleColorEmoji raster payloads 标记为 RGBA。Text shaping
通过 renderer text-system contract 支持：`core/` 保留 deterministic fallback `TextSystem`，
其中包含 representative variation-selector、combining-mark、emoji modifier、keycap、
ZWJ、regional-indicator、tag-sequence、prepend-mark、script-mark 和 Hangul Jamo
cluster interior caret stabilization，以及对同一组 representative boundaries 的基本
left/right caret movement；`moui_wgpu_renderer` 拥有 provider validation 和 atlas upload，
包括拒绝不能覆盖输入文本的 non-empty run-layout caret arrays；`moui_wgpu_renderer/cosmic_text`
拥有 native Cosmic provider，macOS 组合 CoreText-backed platform text engine 与 Cosmic
fallback 以进行 measurement 和 glyph rasterization，native platform providers 共享
`moui_wgpu_renderer/text_protocol`，用于 UTF-32 input encoding、携带 size、weight、style
和 structured family stack 的 versioned `FontSpec` payloads、private versioned
measurement payload parsing、用于 shaped glyph placements 且带 platform-private raster
payloads 的 generic run-layout envelope、shared alpha-mask/RGBA raster glyph parser，
以及 embedded font bytes 的 versioned registration payload encoder/decoder。随后
CoreText 会从 structured family stack 中尝试已安装的 named families，将 `ui-monospace`、
`serif`、`emoji` 等 generic families 映射到合适的 macOS fonts，对不可用 families
回退到 system fonts，尝试在 requested family alias 下进行 app-provided font bytes 的
process-local registration，在 atlas upload 前使用 CoreText glyph runs 获取 glyph ids
和 positions，并让其 glyph payloads 携带 PostScript font identity，使 fallback-font
glyph runs 可以用 shaping 时相同的 font 进行 rasterization。Windows 组合 DirectWrite
scaffold provider 与 Cosmic fallback，Linux 组合其 fontconfig/FreeType provider 与
Cosmic fallback。当 Noto Color Emoji 可用时，Linux provider 可以为显式 emoji-family
runs 发出 native FreeType RGBA glyphs，但 general measurement、shaping 和 non-emoji
raster data 仍会回退到 Cosmic，直到完整 fontconfig/HarfBuzz 路径实现。Web 注入
Canvas-backed text system，使用与 text drawing 相同的 CSS `system-ui` family stack。
Fallback composition 在 backend/provider boundary 上是显式的；`moui_wgpu_renderer` package
验证 provider responses，但不依赖 Cosmic provider package。Diagnostic text conformance
覆盖 single-codepoint、variation-selector 和 ZWJ samples 的 deterministic emoji
measurement 与 caret invariants，也覆盖 representative combining-mark、emoji modifier、
keycap、regional-indicator、tag-sequence、prepend-mark、script-mark 和 Hangul Jamo samples
的 core fallback cluster-safe caret geometry 与 movement；Cosmic run-layout tests 还会
断言通过 provider-safe mapped layout path 获得 glyph output 加 monotonic caret coverage，
focused Cosmic tests 覆盖 platform emoji fallback font loading，以及在此类字体可用时的
emoji codepoint resolution。Bidi reordering、paragraph line breaking、deterministic
color emoji、native emoji fallback 和 provider shaping evidence 由 text/emoji proof
matrix 表示，而不是 renderer capability blockers。
跨 package 文本边界记录在 [文本系统](../text-system.md) 中。Native image support
在 session 边界上异步完成：renderer session 发出带 opaque token 的 image request，
backend `WindowImageTasks` 只读取 `HostImageSource` 原始字节并回传同一 token。
`RendererSession::apply_image_load_completion` 只接受当前 token，返回 Applied、Stale
或 Disposed；只有 Applied 才请求重绘。WGPU、Skia、Sun 和 Web 的 decode、resource
status、cache update 与 failure retry 都属于各自 renderer session；backend 不保存
revision snapshot、repaint tracker 或 command cache。窗口 dispose 时取消 pending I/O，
迟到 completion 无副作用。

Sun renderer-local tests 也覆盖 JPEG data URI/local-file decode、
`ImageFit::Contain` letterboxing、`ImageFit::Cover` source crops、
`ImageFit::Stretch` full-frame sampling、`ImageFit::ScaleDown`
natural-size-or-contain placement、`ImageFit::FitWidth/FitHeight` axis-locked
placement/cropping，以及文件出现后的 async local-file failure retry，使 retry behavior
与 Skia 的 local-file path 保持一致。Skia renderer-local tests 也会在
`draw_image_rect` 提交 source/destination rects 之前固定 `ImageFit::Contain`
letterboxing、`ImageFit::Cover` UV crop geometry、`ImageFit::Stretch` full-frame
sampling、`ImageFit::ScaleDown` natural-size-or-contain placement，以及
`ImageFit::FitWidth/FitHeight` axis-locked placement/cropping。

## 当前 Skia 光栅说明

`moui_skia_renderer` 是一个只面向 native 的渲染器 package，位于可编辑的
`wzzc-dev/moui_skia` checkout 之上。它暴露 `SkiaRasterRenderer`、`SkiaPixelFrame`、
`SkiaPresentTarget`、`SkiaFontResolution`、`SkiaUnsupportedCommandDiagnostic`、
`renderer_descriptor()`、backend info、fallback-safe availability checks、basic
Skia-backed text system、renderer-local image resources、tokenized completion diagnostics，
以及带 command/reason payloads 的 structured unsupported-command diagnostics。
`unsupported_command_count()` accessor 仍是 count summary，而
`unsupported_command_diagnostics()` 返回 per-frame command/reason list。Unmatched、
mismatched 和 frame-end unclosed canvas scopes 会被当作 unsupported diagnostics，在
frame boundary 被忽略或恢复，而不是恢复越过 frame-root canvas scope。在 fallback builds
中，`skia_available()` 返回 `false`，renderer creation 抛出 `SkiaUnavailable`，platform
Skia entrypoints 会在把控制权交给 host app assembly 前 preflight availability，因此显式
Skia selection 会带 diagnostic 退出，而不是打开 blank window。Windows 和 Linux host
smoke options 暴露与 tester/backend smoke runners 使用的同一个 renderer-neutral
first-frame auto-exit hook；这些日志只为生成它们的 host 记录 presentation。Linux Skia
是 renderer 和 text observation 的 native Linux Preview Ready route；Linux native
WGPU/fontconfig provider 仍是 diagnostic，不能被引用为 Skia-route readiness。

当链接 real Skia 时，渲染器会通过 `moui_skia` 的 `SurfaceTargetDescriptor` 和
`Surface::for_target` value-layer surface contract，使用 physical pixels 创建 CPU
`raster_n32_premul` surface，按 host scale factor 缩放 canvas，使 MoUI commands 保持在
logical coordinates 中，绘制 command stream，通过 `Surface::flush_and_submit` finalize
surface，将 pixels 读回 `SkiaPixelFrame`，并调用 platform presenter。fallback-safe
`raster_surface_preflight` diagnostic 汇总相同的 `moui_skia` surface/frame/finalization
resource plans，让 MoUI 即使在未链接 real native Skia 时也能审计 Skia raster target
contract。fallback-safe `skia_text_descriptor_preflight` 同样消费 `FontFallbackRequest`、
`TextMeasurementDescriptor`、`TextShapingDescriptor`、`ShapedTextRunDescriptor` 和
`ShapedGlyphRunDescriptor` resource plans，作为当前 Skia text path 的 cache-key
observation。Skia missing-glyph recovery 现在会立即接受 complete fallback runs，并且只在
partial default-font fallback 减少 missing glyph ids 或从 blank primary run 恢复 visible
text 时接受它。配套的 `text maturity audit ready` 或 `text maturity audit pending`
backend-info summary 会让已审计的 Skia text baseline checks 在 fallback-safe 和 real Skia
environments 中保持显式；当链接的 Skia route 暴露所需证据时，bidi reordering、paragraph
line breaking 和 deterministic color emoji 现在属于 ready audit。两个 diagnostic 都不会
替代现有 MoUI draw-command replay，也不能证明 full shaping parity。macOS 通过 `CALayer`
上的 `CGImage` 呈现 frame，Windows 通过 top-down BGRA DIB 和 `StretchDIBits` 呈现，Linux
通过本地 `window/linux` `Window::present_rgba_pixels` `wl_shm` presenter 呈现。

当前 real Skia smoke 使用 JetBrains Skia link flags 通过 `SkiaRasterRenderer` 渲染并回读
representative frame。它验证 clear、rect fill/stroke、rounded fill/stroke、linear-gradient
fills 和 strokes、soft rounded shadows、rectangular 和 rounded clips、affine translation
和 scaled scoped clip、transformed layer opacity masks、transformed filter scopes、opacity、
带 rectangular 和 rounded masks 的 layer opacity、nested layer/filter composition、
multiply/screen/overlay/darken/lighten blending、blur/saturation/brightness/contrast/color-matrix
filters、color-matrix short/long payload normalization、solid 和 gradient paths（包括
quadratic 与 cubic curve verbs）、solid、checker、linear-gradient-debug 和 vignette shader
effects、PNG/JPEG/BMP data URI decode、local PNG/JPEG/BMP decode、
contain/cover/stretch/scale-down/fit-width/fit-height image placement geometry、local PNG image
drawing、immutable failed-image placeholders 加 local-file retry recovery、basic text glyph-run
pixels、有界 `TextRun.frame` clipping，以及使用 `--enable-skshaper` 运行 smoke 时的可选
SkShaper availability，同时要求 `unsupported_command_count == 0`。聚焦的 Skia renderer
white-box tests 还覆盖 radial-gradient rounded brush 和 path brush pixels，以及 unmatched
pops、mismatched pops、unclosed scopes、unknown shader fallback 和 per-frame diagnostic reset
的 structured unsupported-command diagnostics。Native Skia provider packages 通过
`RendererSession` 暴露 renderer-local image diagnostics；host 不检查或镜像 resource status。
Applied token completion 路由匹配窗口重绘，stale/disposed token 无副作用；renderer tests 覆盖 JPEG/BMP data URI 和 local-file
decode、contain/cover/stretch/scale-down/fit-width/fit-height source/destination placement、
immutable failed-cache reuse，以及 missing file 出现后的 local-file retry。
Skia renderer text support 现在已针对当前 renderer contract 达到 release-ready。Basic text
measurement/drawing 使用 Skia `FontMgr`/`Font`，带 `FontSpec` family、weight、style
selection，在常规 family matching 之前通过 representative coverage characters 和 inferred
BCP47 script language tags 进行 `FontFallbackRequest` matching，提供 per-run `FontMgr`
resolution 的 grapheme-safe mixed-run fallback segments，使用 Skia font metrics 提供
baseline/height，链接 SkShaper 时使用 shaped-run cluster carets，否则使用 Skia-measured
prefix carets，用共享 UAX-style `TextGraphemeBoundaries` cluster splitting 和 caret
stabilization 覆盖两条 caret paths，对 emoji-hint text 进行 SystemFontMgr-only emoji font
retry，链接后可选用 SkShaper shaped glyph runs 进行 rendering，并为 Skia fallback、
measurement、shaping、shaped-run 和 shaped-glyph resource plans 提供 fallback-safe descriptor
preflight coverage。渲染器还在 backend info 中暴露 fallback-safe text maturity audit，
计入 audited baseline、missing-glyph recovery rule、mixed-run fallback、Unicode 17
grapheme boundary contract、bidi/paragraph readiness 和 deterministic color emoji readiness。
`TextSystem::layout_paragraph()` 现在提供 Skia diagnostics wrapped line metrics、caret
rectangles、selection rectangles 和 hit-test geometry。当 binding 构建启用 SkParagraph 时，
`skia_paragraph_available()` 让 Skia text system 可以使用 native `Paragraph` wrapper 来获取
SkParagraph line metrics、selection boxes、hit testing 和 mixed-direction visual-order
metadata。fallback path 保持 native paragraph 和 bidi readiness flags 为 false；SkParagraph
path 只有在存在有效 line metrics、caret geometry、selection rectangles、hit-test results
和 visual-order metadata 之后才可以设置这些 flags。渲染器会将 aligned text glyphs 裁剪到每个
`TextRun.frame`；fallback-safe white-box tests 覆盖 placement contract，opt-in real Skia
smoke 在链接 native Skia 时验证 long glyph runs 不会泄漏到 narrow text frames 之外。
Native SkParagraph 和 bidi readiness 由 matching-host real Skia smoke logs 支撑，其中包含
paragraph wrapping、bidi layout、selection rectangles 和 hit testing 的 `engine=skparagraph`
markers。更广泛的 typography benchmarks、未来 Unicode data refreshes 和 cross-platform emoji
fallback comparisons 是 conformance maintenance items，而不是 renderer capability blockers。
macOS Skia provider 现在与 Windows 和 Linux 一样，默认使用
`SkiaFontResolution::SystemFontMgr`，因此正常 Showcase、Markdown Editor 和 Mo Workbench
Skia entrypoints 会使用 system FontMgr path，包含 platform font lookup、emoji retry 和链接时
可选 SkShaper。macOS tester-owned first-frame smoke entrypoints 会显式切换到
`SkiaFontResolution::EmptyTypeface`；这让 CLI smoke runs 保持在更安全的 default-font retry
path，同时保留正常 app default。renderer smoke 也使用 system FontMgr path，因此 real Skia font
和 optional SkShaper coverage 仍会被跟踪。

## 当前 Web 说明

wasm-gc renderer bridge 保留完整 draw command stream，并将 payloads 转发给 `webgpu`
host import module。browser runtime 现在通过 WebGPU pipelines 渲染 rects、rounded geometry、
gradients、soft shadows、opacity、text 和 loaded images。Text 在 glyphs 由 WebGPU 合成前使用
DPR-aware canvas-rasterized glyph atlas。Images 作为 WebGPU textures 缓存，支持
contain/cover/stretch/scale-down/fit-width/fit-height fit，通过 visual shader 渲染 radial rounded
fill/stroke 和 path brushes，并在 browser 仍在加载 source 或加载失败时使用 deterministic fallback
color。Web radial support 会保持 partial，直到 browser renderer smoke 在 Chrome/WebGPU session
中为 rounded 和 path payloads 都记录 radial center/mid/edge pixels。
`WebGpuWasmRenderer::image_resources()` 暴露 renderer-local image resource records，
`WebGpuWasmRenderer::image_resource_snapshot()` 添加同样的 monotonic revision snapshot shape，
该 shape 由 `backend/web.WebRenderer::image_resource_snapshot()` 转发给 app/host integration
code。Submitted sources 从 loading 开始，host submission 后 adapter 会从 browser cache 刷新
records；该 cache 由 `Image.onload` / `Image.onerror` 更新，因此后续 renders 可以报告 ready
dimensions 或 failed diagnostics。browser runtime 还为 WebGPU imports 暴露
`onImageResourceChange` callback，`bootMouiWasmGcApp` 将该 callback 连接到
`window_web.schedule_animation_frame`，因此即使 user notification code 抛错，image load/error
completion 也能进入正常 Web redraw path。

Clip support 将 transformed rectangular clip stacks 映射到 per-item scissor rectangles。
Rounded clip scopes 作为带 rounded mask 的 offscreen layer scopes 提交，复用 browser runtime
的 layer-mask composite path。Transform support 被折叠进 generated visual、image、text 和
shader-effect advanced vertices，clip scissors 则从 transformed bounding boxes 推导。Scoped
layer/filter commands 在渲染到其 offscreen scope 前克隆当前 transform 和 clip state，Web adapter
tests 会在 layer、filter 和 shader-effect host calls 周围保留 transform scope。
Web runtime 通过 wasm-gc host ABI 转发 layer、filter 和 shader-effect commands。browser runtime
使用 draw scopes、offscreen WebGPU textures 和 advanced composite shader 来处理 layer opacity、
masks、filters 和 built-in shader effects。Blend-mode coverage 与 native 匹配：source-over、
multiply、screen、darken 和 lighten 使用 WebGPU blend states，而 overlay 使用
backdrop-sampling WebGPU pass 以获得精确语义。advanced shader 对 blur 和 backdrop reads 使用
explicit-LOD texture sampling，因此 Chrome 的 WGSL validator 会接受 command kind 随 fragment
input 变化的 filter 和 overlay paths；browser runtime 会将 WebGPU uncaptured/device-lost errors
转发到 page log，使 browser presentation observation 在 shader 或 pipeline validation errors
时失败，而不是静默依赖 nonblank screenshot。Arbitrary paths 与 native 共享同一个 MoonBit
tessellation contract。wasm-gc adapter 将 tessellated `DrawPath` mesh 序列化成 compact host
payload，browser runtime 通过 WebGPU visual pipeline 按 active transform、opacity 和 clip state
提交这些 vertices。当 scopes unbalanced、left open，或已建模命令尚未可见执行时，skipped advanced
commands 会保留在 renderer 的 last fallback plan 中用于 diagnostics。Emoji 和 complex text shaping
依赖 browser font behavior；diagnostic conformance 覆盖 representative emoji samples 的
measurement 和 caret invariants，但不会让 browser rasterization 或 provider shaping 变成 deterministic。

## 更新规则

当改进 image、clip、opacity、transform 或任何其他 draw command support 时，更新：

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. 本报告页面

对于 text-related renderer changes，还要更新 `docs/text-system.md`。
