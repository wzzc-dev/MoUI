# Renderer Route Economics (Apple) and the no-third-party GPU route

Durable facts for deciding between rendering routes. Full record: ADR 0043
(superseded conclusion, measurements still valid), ADR 0044, and
`docs/plans/active/no-third-party-gpu-route.md`.

- **ADR 0044's kill gate fired on the performance branch at L0, and the owner
  proceeded anyway: L0.5 and L1 both landed on 2026-10-27.** `moui_metal_renderer`
  now draws the L1 acceptance frame (clear colour, filled rect, solid path, one real
  CoreText glyph run) with 0 Skia and 0 wgpu matches in `otool -L` / `nm -a` /
  `strings -a`, 6 hand-written externs at that frame (8 now, after the image and
  atlas-texture entries), and a 34-line /
  9-declaration public interface. So the route exists because the two surviving
  motives are being priced by real code, not because a gate asked for it. Dead motives: performance (the shipped Skia-Metal route
  already holds the renderer-attributable slice at 0.10–0.76 ms p50 while the frame
  costs are framework-side) and license (struck by L0.3). Live motives: **size
  relative to Skia** — measured 2026-10-28, `macos_metal` is a fifth of Skia's
  artifact — and
  **autonomy**, which is the owner's call. What was taken off the table — "size
  *below* the `sun` floor, because a hand-written backend only adds a rasterizer
  to MoUI's own framework body" — turned out to be a derivation, not a measurement
  (next two bullets). Do not re-litigate performance or license
  from old `presentMs` numbers; the raster baseline they came from is itself ~3.5×
  off the shipped path.

- Measured band for the *same* app (`examples/showcase`, `--release --target
  native`, all three linked with `-Wl,-dead_strip -Wl,-x`; re-measured
  2026-10-26 with `size -m`): `macos_skia` 20.35 MB (`__text` 9,092,412 /
  `__const` 11,390,176 — ICU table dominates); `macos_wgpu` 11.05 MB
  (`__text` 8,498,112 / `__const` 1,328,452); `macos_sun` 4.06 MB (`__text`
  3,699,004 / `__const` 338,848).
- **The derived band is void — it was measured, and the measurement went the other
  way.** The reasoning was "a GPU engine costs ≈4.80 MB of `__text` (`wgpu` −
  `sun`), so any new GPU route lands between 4.06 and 11.05 MB, so 'smaller
  binary' is never a reason to add one against `sun`." 4.80 MB is wgpu's engine,
  not the price of a GPU. Built and measured 2026-10-28, same app, same flags,
  same day as a re-measured `macos_sun` (byte-identical to the number above):
  `macos_metal` **4,101,856 B** (`__text` 3,527,568 / `__const` 339,584) vs
  `macos_sun` 4,260,688 B — the GPU route is 158,832 B *below* the CPU-raster
  floor, with 171,436 B less `__text` and 736 B more `__const`. Mechanism the
  derivation lacked: a GPU route does not *add* a rasterizer to the always-linked
  MoUI framework body, it *substitutes* command encoding for scan-raster code, and
  that swap measured net negative. So `sun` is not a floor a GPU route must sit
  above; the floor was CPU-raster-shaped. Sub-MB is still out (the 266,600 B
  language floor plus ~4.0 MB of MoUI body dominates either rasterizer), and one
  app / one arch / one build is not a property of the route — the route still owes
  blur-quality, stencil-clip and `Overlay` blend code. No gate enforces any of
  these numbers —
  `checks/performance-budgets.json` `packageBytes` limits (70/80/100 MB) are
  placeholders, and `moui package macos` builds debug artifacts, so a
  `packageBytes` figure and a `size -m` release figure are different artifacts.
  The `-Wl,-dead_strip -Wl,-x` flags used for the pair are **not committed** on the
  two entrypoints — added, measured, reverted to `""`.
- "GPU without Skia" exists (`moui_wgpu_renderer` links wgpu-native; `otool -L`
  shows `Metal.framework`), **but it does not satisfy "no external graphics
  library"** — that route is inside the excluded set. Under the boundary the owner
  fixed on 2026-10-27 (OS frameworks allowed, Skia/wgpu-native excluded), the set
  {has GPU} ∩ {links no external graphics library} is empty, which is why ADR 0044
  reopened the route that ADR 0043 had killed. R1 is unchanged by that reopening:
  Skia mainline, WGPU diagnostic.
- The gpui architecture (GPU + OS text shaping + glyph atlas) is wired on macOS
  already: `examples/showcase/macos_wgpu/main.mbt:11-12` injects
  `@text_coretext.coretext_text_provider()`, glyph coverage uploads through
  `moui_wgpu_renderer/native_text_glyph_atlas.mbt`, CoreText boundary is 4
  externs (`moui_text_providers/coretext/coretext_text.mbt:439-465`).
- Two reusable halves verified 2026-10-27, both cheaper than expected: the host
  already creates the `CAMetalLayer` and exports a renderer-neutral handle
  (`moui/backend/macos/macos_present.mm:308` `moui_macos_surface_layer_from_view`,
  layer built at :334-342), and `moui_text_providers/coretext/moon.pkg` links only
  system frameworks (AppKit/QuartzCore/CoreText/CoreGraphics/Foundation/
  CoreFoundation/-lobjc/-lz). The blocker was types, not frameworks: all 17
  `@wgpu_renderer` references in `coretext_text.mbt` are data structs declared in
  `moui_wgpu_renderer/native_text_model.mbt:100`, inside the package that imports
  `Milky2018/wgpu_mbt`, and `text_protocol/moon.pkg` imports it too — so the text
  model had to be extracted before any compliant route could reuse it. **That
  extraction landed the same day (L0.2)**: the model, validation and caches are now
  `moui/render/native_text` (`NativeTextEngine` at
  `moui/render/native_text/text_model.mbt:5`), its `moon.pkg` imports only
  `wzzc-dev/moui/core`, and all five native text packages plus
  `moui_tests/text_conformance/native` import that instead of the renderer root —
  `coretext_text.mbt`'s 17 references are now `@native_text`, same count. The
  renderer keeps only the glyph atlas upload and the text vertex builder, and
  re-exports the moved names with `pub using`, so L0.2 alone needed no consumer
  edits. **The residual it left is closed by L0.5 (2026-10-27)**: the five packages
  now live in their own published module `wzzc-dev/moui_text_providers` (directory
  `moui_text_providers`, registered `publication: public` / `role: binding` /
  `releaseStage: base-bindings` / `0.2.2` — the `moui_skia`/`moui_sun` topology),
  together with `build.js` and the `--moonbit-unstable-prebuild` hook that used to
  sit in `moui_wgpu_renderer`. That was not cosmetic: P14 (`docs/invariants.md:30`)
  forbids a `role: "renderer"` module importing another renderer module, so while
  the providers sat inside `moui_wgpu_renderer` no `moui_metal_renderer` could
  import `coretext` however clean its own imports were. Giving the new module
  `role: "renderer"` instead would have made `moui_wgpu_renderer` the violator.
  Consumers `examples/showcase/*_wgpu` and `moui_tests/{wgpu_renderer_smoke,text_conformance}`
  did have to be rewired by the move (import paths plus the `@wgpu_*` → `@text_*`
  aliases), and `examples/momark` / `moui_studio` deliberately got **no**
  compatibility shims — they are submodules resolving the already-published
  `wzzc-dev/moui_wgpu_renderer@0.2.2` from the registry, so they still build.
  `NativeTextEngineSetting` (`MoonCosmic` /
  `PlatformDefault`) is referenced by **zero** local source files — only by vendored
  `.mooncakes` copies of older published layouts — and was left in the wgpu root
  untouched rather than deleted, since removing public API is a separate owner call.
- Estimated FFI bill for a Metal-direct renderer under that boundary: **≈10–40
  externs**, not 292 — presentation needs `MTLCreateSystemDefaultDevice` plus
  `nextDrawable`/texture via `objc_msgSend` (the shipped Skia GPU path does exactly
  this at `moui_skia/native/skia_stub_surface_image_data.cpp:65,99,1824-1836`), and
  geometry is already repo-owned in `moui/render/common`.
- Licensing is a **struck** motive (L0.3, 2026-10-27, now in `THIRD_PARTY.md`).
  Everything locally confirmable is permissive: the MoonBit dependency graph is
  Apache-2.0/MIT, and the Skia package delivers license texts at eight locations
  (`third_party/externals/`: angle2, freetype/docs — FTL.TXT with its GPLv2
  alternative, harfbuzz "Old MIT", libpng, libwebp BSD-with-advertising-clause,
  swiftshader Apache-2.0, zlib; plus `include/third_party/vulkan`), all
  BSD/MIT/Zlib/libpng/FTL family. What
  the macOS route *actually* links is decided by `moui_skia/build.js`, not by what
  the package contains: with paragraph + Metal static, the darwin link line names
  **eight archives** (`libskia_ganesh_ext`, `libskia`, `libskparagraph`,
  `libskshaper`, `libskunicode_icu`, `libskunicode_core`, `libharfbuzz`, `libicu`)
  plus `-lc++` and Apple frameworks; the package ships 29. Only HarfBuzz of those
  eight has its text in the artifact — no Skia root `LICENSE`, no ICU terms.
  `-lfreetype` is appended only on Linux (`moui_skia/build.js:777`), so FTL-vs-GPLv2
  is a Linux-route question. Residual exposure is **notice completeness, not IP
  blocking**, and is self-fixable because the locked provider is this project's own
  `wzzc-dev/skia` artifact (`moui_skia/skia-provider-lock.json`,
  `default_provider: "release"`, tag `dev-6d73578a36`) — while
  `scripts/macos-skia-renderer-smoke.sh:120,362-367` defaults to the `jetbrains`
  provider at `m148-8967a2e80c`, so real-Skia *evidence* can come from a different
  build than the product links (both verified inventory-identical on macOS arm64).
- Hand-written FFI band, verified by `grep -c '^extern "C" fn '`: `moui_sun` 0,
  `moui_wgpu_renderer` 14 (API surface outsourced to `Milky2018/wgpu_mbt`),
  `moui_skia/native` 292. The shim, not the drawing logic, is the cost driver.
- **`presentMs` history: fixed 2026-10-27, still headless.** Before L0.4 every
  frame number in the repo came from a no-op presenter on the forced CPU raster
  route (`SkiaPresentTarget(present=_frame => { true })`). The harness now selects
  four present paths by `MOUI_PERFORMANCE_SURFACE_ROUTE` — `raster`, `metal-gpu`,
  `metal-gpu-host`, `metal-gpu-host-rotating` — each with its own runner label, and
  `perf_fail`s rather than mislabels if `surface_is_gpu()` / `target_kind()`
  disagree with the requested mode. Measured p50 (3 interleaved rounds × 40 frames)
  on the rotating-host route closest to what Apple ships: `presentMs`
  **0.100–0.762 ms**, and the frame-dominating scenarios are 92–95% framework
  (excel 12.51 ms, deep-tree 4.79 ms) — so the renderer-attributable slice is
  already tiny. What the headless harness still does **not** pay: `CAMetalLayer`,
  `nextDrawable`, vsync-blocked `present:` (the rotating mode buys per-frame surface
  acquisition, the largest synthesizable component). Those are backend-independent,
  and reproducing them needs the live-window smoke script, not this runner.
- **Two benchmark traps to not repeat.** (1) The gated raster runner overstated
  scroll `presentMs` by ~3.5× (2.697 vs 0.762 on the host route), so "present is
  the dominant stage" was an artifact of benchmarking the fallback. (2) `metal-gpu`
  means GPU→CPU `read_pixels`: 1.7–5.9× the raster present, and that ratio prices
  the *copy*, not the engine — never claim "GPU slower than raster" through a
  CPU-frame presenter. Related: all-zero `buildMs` / `layoutMs` are **honest** (each
  stage is timed only when its dirty flag is set); the instruments that were
  genuinely missing were `drawMs` and `totalMs`, now emitted and gated as 7
  required timing metrics.
- **The committed timing budgets cannot arbitrate a route choice.** Across 4 routes
  × 5 scenarios × 7 metrics (140 sample/budget ratios) none exceeded 1.0 and the
  tightest was 0.80 (`drawMs`); host-route `presentMs` sits at 0.007–0.051 of
  budget. `checks/performance-budgets.json` ceilings are crash detectors — answer
  attribution questions by stage share, not by pass/fail. Their p50 entries (24–72
  ms) are ~30× looser than measurement (2026-09-06 artifact frame medians:
  virtual-list-100k 0.722, multi-window-4 0.826, markdown-input 0.336, scroll 3.107,
  deep-tree 7.661, excel 19.597 ms), so never read a budget p50 as an expected
  frame time. Same for size: no gate
  enforces the MB band above (the `packageBytes` limits are 70/80/100 MB
  placeholders).
- **The macOS CI budget step is report-only as of 2026-10-28.** Two macos-14 runs
  of identical code drifted 1.3–1.5× on p50 (deep-tree `drawMs` 0.051→0.072 ms,
  `totalMs` 8.8→13.3 ms), and deep-tree `drawMs` p95 0.248 ms broke the 0.1875 ms
  limit. The `drawMs`/`totalMs` baselines were grounded in a local 2026-10-27
  artifact where `drawMs` ran ~3× faster than on CI (0.019 vs 0.051–0.072 ms).
  `benchmark-scaffold` still builds, measures and uploads the artifact; the budget
  step uses `continue-on-error`, so review a red line by hand — it is not a merge
  gate. Re-tighten only on a quiet dedicated runner.
- **MoonBit's own native size floor is not the problem.** A one-line `println`
  release binary (`moon run --release --target native`) links 266,600 B
  (`__text` 151,508) against `libSystem` only — probe kept at
  `artifacts/tmp/mnsize`. So `macos_sun`'s 4,260,688 B means ≈4.0 MB is MoUI's
  always-linked framework body, with zero graphics libraries involved; sub-1 MB
  is a framework-volume program, not a backend choice.
- **The perf harness is provider-parametric since L0.1 (2026-10-27), so a non-Skia
  route can produce frame numbers.** `MOUI_PERFORMANCE_PROVIDER=skia|skia-neutral|sun`
  (`benchmarks/performance_budget/native/main.mbt:187`); `skia` keeps the concrete
  `SkiaRasterRenderer` path and stays the *only* budget-gated runner (its four labels
  are byte-identical to before, CI's flag-less call is unchanged), while
  `skia-neutral` binds through the neutral 4-field `RendererProvider`
  (`moui/render/provider_contract.mbt:23`) and `sun` through `@render_sun.raster()`.
  Control runs write `artifacts/performance/result-<provider>-<route>.json` and skip
  budget validation — never quote a control number as a budget result. The
  skia↔skia-neutral A/B is ±4% with `cacheHitRate` identical to four decimals, but a
  plain repeat of the *gated* path alone moved +1.8–11.0%, so that A/B certifies "no
  visible overhead", not a measured equivalence. Runs here are sequential, not
  interleaved: read anything under ~10% as drift, and route decisions only off ratios
  far outside it (sun's 15–233× is 4–50× the noise band).
- **`moon fmt <package>` regenerates `_build/<target>/release/format/…` without writing
  the source back**, so it silently leaves the tree unformatted; apply with a
  project-wide `moon fmt`, verify with `moon fmt --check` (the `pr` profile runs that
  as a step). Formatting a file shifts every line citation pointing into it — re-check
  them in docs, ADRs and `memories/repo/` rather than trusting the old numbers.
- **First non-Skia frame numbers: `native-sun-raster` is 15–233× the shipped
  renderer's `frameMs` p50 and breaks 4 of 5 committed ceilings by 3.5–61×**
  (multi-window-4 passes only because its 72 ms ceiling is ~30× looser than reality).
  `presentMs` is 96–99.7% of sun's `frameMs`; `peakRss` 270–315 MB vs 82–105 MB with
  *fewer* live blocks (957 vs ~10.4k). Three limits on how that may be used: (1) it
  prices `sun`, not "a non-Skia renderer"; (2) `RendererSession` has
  `present_count` / `image_diagnostics` / GPU-recovery counters but **no
  unsupported-command accessor** (`moui/render/renderer_session.mbt:212-251`), so a
  silently skipped `DrawCommand` *understates* cost and 15–233× is a floor; (3) every
  artifact reports the identical `packageBytes` 23,262,232 because the benchmark
  binary links both renderers — a provider-swap run can never measure provider-only
  size. `wgpu` stays unreachable headlessly (its bind closure rejects a surface with
  no `native_surface()`, `moui_wgpu_renderer/binding_factory.mbt:25-27`) and
  `benchmarks/app_cached_layer/native/main.mbt:143` was left concrete on purpose.
  Also note `startupMs` is **not** an independent signal: the timer spans app
  construction, pump construction and the 12 warmup frames
  (`benchmarks/performance_budget/native/main.mbt:725-737`).
- **A GPU-backing blit that fails is invisible unless you assert it.** The host
  surface route keeps a stable backing surface and `copy_from`s into it; on a size
  or context mismatch `Surface::copy_from`
  (`moui_skia/native/surface_image_data_native.mbt:1399`) returns false, and
  `render_to_gpu_backing` treats that as "optimization failure only" and silently
  falls back to a direct full redraw (`moui_skia_renderer/renderer.mbt:385,412`
  → :500-513). So a rotating-drawable benchmark can measure the fallback while
  believing it measured the blit path. `skia_renderer_gpu_backing_wbtest.mbt` now
  asserts `renderer.gpu_backing` is still `Some` after rotation; any future route
  that swaps the replacement drawable must reuse the outgoing `descriptor()` or the
  number it prints is not the path it claims.
- The text conformance suite is *partly* provider-parametric already, contrary
  to a common assumption: `assert_diagnostic_native_text_matrix(system :
  @core.TextSystem)` (`moui_tests/text_conformance/native/text_conformance_test.mbt:104-123`)
  runs 16 samples (ZWJ, VS16, Hebrew bidi, Thai/Lao/Sinhala/Khmer/Tibetan) and
  is already driven by non-Skia providers at :362-407. Only the paragraph /
  selection-rect / hit-test layer (:247-286) and the maturity strings read from
  `@skia_renderer.backend_info()` (:55-76) are Skia-bound.
- Naming trap: `docs/platform-notes-macos.md:97` calls the shipped Skia-on-Metal
  surface "the direct Metal GPU provider". "Direct Metal" is not a distinguishing
  phrase; "no Skia, no wgpu" is.
- Platform coverage is **not** what an Apple-only Metal route buys. Metal is
  Apple-only; D3D12 is OS-shipped on Windows; Linux and the RISC-V embedded
  targets have no OS-owned GPU API, so a compliant Vulkan backend means owning
  swapchain + sync + explicit memory binding by hand (the wgpu-hal job). Record
  that as its own ADR if it is ever taken up.
- Renderer-surface growth is capped by ADR 0027 gates
  (`scripts/validate-renderer-provider-manifests.mjs`,
  `scripts/validate-renderer-provider-open-extension.mjs`); a new renderer also
  needs `moon.work`, `checks/release-modules.json`, `checks/profiles.json`, a
  capability-report column plus its zh-Hans mirror, and a showcase entrypoint.


## L1 落地后的持久事实（2026-10-27，ADR 0045）

- **库包的 `cc-link-flags` 到不了 is-main 链接。** 实证方式：往
  `moui_text_providers/coretext/moon.pkg` 塞一个非法 flag，`macos_wgpu` 照样
  build 成功。载体是 prebuild 的 `link_configs`（`moui_skia/build.js:1059` 的注释
  早就这么写）。它不是死配置：`moon test <pkg>` 时该包就是 is-main，自己的 flag
  会生效。CoreText 此前只是碰巧能链接——平台后端额外链了 `ApplicationServices`
  umbrella 并转发导出 CoreText；不带后端链接 CoreText 的消费者会失败，现已由
  `moui_text_providers/build.js` 在 darwin 上发出 `link_configs` 修掉，并由
  `scripts/test-moui-prebuild.mjs` 钉住。
- **`moui/render` 的公开面禁止命名平台 surface。** `Metal`/`HWND`/`Vulkan`/`EGL`/
  `D3D`/`Wayland` 在 `checks/backend-common-ownership.json`
  `rootRenderForbiddenTokens` 与 `validate-api-surface.mjs` 的 forbidden token 里
  都有门。给新渲染器起协议身份时不要叫 `Metal`：现在是
  `RendererBackendKind::NativeDirectGpu` + `RendererFamily::DirectGpu`，模块名保留
  Metal，散文一律用"无 Skia、无 wgpu"（因为
  `docs/platform-notes-macos.md` 已把随主线的 Skia-on-Metal 称作"直连 Metal GPU
  provider"）。门是对的，改名字而不是改门。
- **全覆盖的合成字形测试会掩盖真实着色 bug。** 预乘颜色 × 直通 alpha texel 会让
  rgb 保持满亮度，coverage 只落到 alpha —— 真 CoreText 文字画成实心白条，而
  全 255 覆盖的合成测试照样绿。判据必须是**半覆盖** mask（外加 uv 字节偏移：
  布局 x,y,r,g,b,a,u,v 时 uv 在 24 不是 16，偏移错也表现为"整块白"）。
- **Metal SDK 事实**（本仓 SDK 版本）：配 `MTLVertexDescriptor` 时顶点函数入参必须
  是带 `[[attribute(n)]]` 字段的 `[[stage_in]]` struct（离散带属性参数被拒）；
  blending 属性直接挂在 `MTLRenderPipelineColorAttachmentDescriptor` 上（没有
  `.blending` 对象）；`MTLRenderPipelineDescriptor` 没有 `rasterizer`；
  `MTLTextureUsage` **没有** `HostReadable`（纹理默认可 host 读）；
  `MTLResourceOptionCPUCacheModeDefault` 已废弃，用 `MTLResourceStorageModeShared`。
- **Metal 路线的证据门是 darwin-only 的 `platform` profile 步骤**
  （`moon test moui_metal_renderer --target native` 与
  `moon run moui_tests/metal_renderer_smoke/macos --target native`）：需要真 GPU
  与 Apple stub，所以不能进 `pr`/`daily`——与 text provider、wgpu smoke 同一理由。
  离屏像素证明走 `metal_proof_pixels`（`moui_metal_renderer/metal_proof.mbt`），
  真实 provider 证明走 smoke，断言"墨迹比例是字形形状"且 noop 引擎墨迹恒为 0。
- **仍未定价的是体积。** 8.9 MB 是 debug 产物，20.35 MB 是 release 产物，两者不可
  比；`packageBytes` 基线还是占位值。任何"Metal 更小"的说法在跑过 release 打包测量
  之前都不成立。

- **L2 shape pipeline facts (2026-10-27).** 一个 76 字节顶点（clip 位置、shape 局部点、
  atlas uv、渐变两端、两个 brush 颜色、kind）+ 每项 8 float 盒参数经 `setFragmentBytes`
  传入；颜色必须逐顶点带，因为共享的 `tessellate_path` 网格把 fill 与 stroke 两个子网格
  混在同一顶点数组里且各自有 brush。SDF/stroke/shadow/渐变的数学与
  `moui_wgpu_renderer/native_visual_shader.mbt` 保持一致（那两个诊断渲染器对同一 mode 的
  解释必须相同）。阴影衰减带只在 grow box 边缘约 ±blur 内，取样落在平台期会得到
  "inside == ring" 的假失败。
- **L2 的"不静默"通道不是事件。** `RendererEvent` 只有 `PresentCompleted` /
  `ImageLoadRequested`，两个宿主后端都忽略其它值，所以新增 unsupported 变体是无人读的
  通道；公开的是 CPU 侧 `metal_frame_report`（任何宿主都能问，smoke 会打印）。

- **Metal 图像解码走 ImageIO（L2b, 2026-10-28）。** `CGImageSourceCreateWithData` +
  `CGBitmapContextCreate(..., kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)`
  —— 不加 `ByteOrder32Big` 时小端内存是 BGRA，与 `MTLPixelFormatRGBA8Unorm` 不匹配。
  纹理按 MoonBit 分配的 Int32 id 缓存在 context 的 `NSMutableDictionary` 里；
  `fit`/`src_rect` 必须走共享 `image_placement`/`image_src_window`。图像片元只乘
  opacity（texel 已预乘），再乘 rgb 会二次压暗。测试夹具用左红右蓝的 4×4 PNG：
  纯色图对任何 uv 错误都不敏感。
- **completion 携带的是解码后的 RGBA，不是编码字节。** 把 `ImageLoadCompletion` 再喂进
  decode stub 会让 `moui_metal_image_decode` 返回 0、图像被标失败，而症状指向纹理，
  完全看不出是契约错配。stub 边界因此拆成 `image_write_rgba`（只上传，走 completion）
  与 `image_decode` + `image_write_rgba`（离屏证明路径，起点才是编码文件）。
  另一侧：`ImageResourceLoadCompletion::has_decoded_rgba_payload()` 是**真谓词**——
  要求 `decoded_row_bytes >= width*4` 且 `pixels.length() >= row_bytes*height`；
  把行距写成 `width*height*4` 会失败。
- **异步图像契约有四个槽，用共享 lifecycle 而不是自研。** `image_source` /
  `image_decoder` / `image_records` / `apply_image_load_completion` 全部架在
  `@render_common.ImageResourceLifecycle` 上，请求去重、失败重试、快照语义就与
  Skia/Sun 路线一致；缺文件时只在字节重新可读后重新请求（一次缺失=一次请求）。
  像素证明必须是**两帧**：第 1 帧 `items=0` 且 `image_ops_pending=1`，应用 completion
  后 `uploads=1` + `ImageReady`，第 2 帧才断言红/蓝两半——否则测试不管生命周期怎么走都会绿。

- **L2c 落地后的 Metal 路线现状（2026-10-28）。** 26 个 `PlanOp` 变体全部有绘制分支：
  8 个 extern、53 行 mbti / 13 个公开声明、43 个模块测试。`dropped_ops` 从公开
  `MetalFrameReport` 里**删除**了——没有 catch-all 之后它不可能非零，而"漏画一个 op"
  从此是编译错误而不是一个数字（先例：`moui_wgpu_renderer/native_visual_plan.mbt`
  既无兜底分支也无丢弃计数）。`moon check` 报 `unreachable_code`（Warning 0012）
  就是"26 个都匹配到了"的证明。

- **图层是真实的 pass，不是近似 clip。** 每项 9 个 int32（第 9 个是 `owner`：`-1`
  主 pass / `-2` 丢弃 / `>=0` 图层槽），每 shape 36 float，每条图层记录 11 字
  （7 int32 + 4 float），顶点仍 76 B。槽位按后序立即认领，宿主倒序渲染
  `slot = count-1 … 0` 再画主 pass，因此同时只有一个 active encoder；pass target
  按槽复用（尺寸一致才复用）。per-pass 变换用 `setVertexBytes` 绑成
  `constant float4& pass [[buffer(1)]]`，不撑大顶点；pipeline 键是
  `role-format[-blend]`——这是 BlendMode 能走固定函数而不进 shader 分支的原因。
  合成是一个满屏 quad（role 3）。

- **Metal 固定函数 blending 的边界**：SourceOver、Multiply
  (`DestinationColor, Zero`)、Screen (`OneMinusDestinationColor, One`)、
  Darken/Lighten 用 `MTLBlendOperationMin`/`Max`（**没有** `Minimum`/`Maximum`）。
  `Overlay` 需要 backdrop 快照，完全表达不了 → `blend_modes_unsupported`；任何非
  SourceOver 只在非透明底上精确 → `blend_modes_approximated`。模糊是 3×3 加权 tap
  → `filter_approximations`。为真卷积加"每个被滤组一张 backdrop blit"的方案被否：
  代价确定、收益无证据。计数分两类的原则是"精确性只被计数，不被暗示"。

- **box 与 path 不共享坐标空间（本路线第一个真实画错）。** MSL 的盒 SDF 用
  `in.local - half_size` 度量，即 `local` 是 rect 原点相对；而 `tessellate_path`
  的网格带的是绝对表面位置。渐变端点原本按表面坐标上传，于是非原点 rect 上的渐变
  轴整体平移（声明 `2→10`，实测 `4→12`）。修法是盒 brush 减去 rect 原点，但径向
  渐变的 `end.x` 是**半径（长度）不能减**。之前每个渐变证明都把矩形锚在 `(0,0)`，
  两种空间在那里重合，所以整套测试全绿。教训：**只在原点成立的像素证伪的是算术，
  不是坐标空间。** 定位方式是先写新证明、再用一次性 probe 测试读实测像素，而不是
  改期望值。

- **rebuild 而非 cache 的诚实记录**：本路线没有按 `RetainedLayerSpec.key` 的跨帧
  缓存，重绘边界每帧重建进新 pass（像素相同、省下的工作为零），由
  `retained_layers_rebuilt` 计数；`DrawShaderEffect` 用自己 spec 声明的 `fallback`
  brush 画、`uniforms` 不用，由 `shader_effects_fallback_painted` 计数。两者在能力
  表里是 `Partial`，note 直接引用证明它的测试名。包内 tripwire 会拒绝"note 比 status
  更乐观"，Gap 行的 note 必须含 `not implemented` 字面量。

- **L3a：atlas 能清空了（2026-10-28）。** 512×512 覆盖图集原本没有任何释放途径：
  装满后 `Full` 与 `Missing` 走同一分支，字形被丢弃并计数，之后每一帧都撞同一面墙
  ——长文档的文字是"消失且不再回来"，不是一个计数器能描述的降级。修法抄兄弟路线：
  `moui_wgpu_renderer/native_visual_plan.mbt:342` 满了就 `atlas.clear()` 重建 plan，
  `native_text_rendering.mbt:147` 把信号返回给上层。Metal 侧 `Full` 置
  `atlas_overflowed`，`build_metal_geometry` 清空后重建一次，**只重试一次**（一帧自身
  的字形集装不满空图集时，重来一遍同样失败，此时 `text_dropped_glyphs` 就是诚实信号）。
  非空洞性用 A/B 证：关掉重试，新测试在 `assert_eq(second.item_count, 1)` 报 `0 != 1`。
  测试用四个 200×200 栅格（正好两排两列填满），再要一个新字形，断言它画出来了、
  `resets == 1`、且图集里**只剩 1 个** placement。`atlas.resets` 保持包内私有：成功的
  重试像素正确，宿主没有可被告知的东西；抖动（工作集大于图集→每帧重传 1 MB）是*成本*
  信号，而本路线还没有能吃下它的性能门，留给 L4，且届时要先有具名失败模式。
- **共享图集的量化前提（别再说"三份副本"）**：glyph atlas 只有**两份**
  （wgpu `native_text_glyph_atlas.mbt` 135 行、metal `metal_text.mbt` 160 行），
  sun 是 CPU 光栅没有图集。两份在货架装箱上同构，但行为差四处：padding 是双侧
  （wgpu，`width + 2*padding`）还是仅尾部（metal）；零尺寸栅格在 wgpu 完全不占货架
  （提前返回 `(0,0)`）而 metal 推进游标；全透明 texel wgpu 跳过写、metal 写；
  full/missing 在 wgpu 是返回值、metal 是计数。抽公共层要带四个开关，而 L3 剩下的活
  正是会继续改动这些行为的地方——顺序应是先收敛行为，真出现第三条 GPU 路线再谈去重。
- **新代码长成超长文件时，答案是拆而不是登记棘轮。** `validate_source_file_policy`
  的 1200 行新文件硬限这轮抓到两个：`metal_geometry.mbt`(1674) 与
  `metal_renderer.mm`(1291)，都是前一天新建的文件——给刚长过头的新代码登记棘轮，等于
  用永久余量买回门明确要防的失败模式。拆法按已有的缝：op walk(789) / 帧的字节布局与
  MSL code 值(622) / scope 栈与 pass slot(275)；桥那边按另一种缝，把 182 行运行时编译
  的 MSL 字符串搬进 `metal_shaders.h`（shader 文本是宿主读取的数据，不是宿主逻辑，
  也是改 fragment 时唯一要动的东西），.mm 落到 1096 行进 1000+ 复排队列。公开 API、
  extern 数、断言都没变。**旁证**：`pr` 的 `generate-repo-docs --check` 会发现
  `checks/api-surface-report.json` 与 `docs/repository-facts.md` 陈旧（只被 pr 检查的
  生成物能整条 feature leg 保持沉默），陈旧的 leg 就该负责重新生成。
- **不要边改代码边跑 `pr`。** 第一次尝试在 `moon fmt --check` 里以
  `git diff --no-index` 报错失败，原因是我同时在编辑同一文件——那是自己的工作流竞态，
  不是仓库红，但花了一轮才分清。

- **彩色字体的判据是 trait，不是 PostScript 名（macOS 26.3 实测）。** 系统级联把
  `🙂` 解析到 **`.AppleColorEmojiUI`**（traits `0xc0002000`，`kCTFontColorGlyphsTrait`
  置位，32pt 在 `kCGImageAlphaPremultipliedLast | 32Big` 上下文里画出 472/539 个有彩色
  像素），而 provider 原先按 `postscript_name == "AppleColorEmoji"` 判色，于是每个 emoji
  都退回 **37×42 的 DeviceGray 覆盖掩码**——能画、形状对、就是没颜色，且没有任何计数器
  会说谎。改法：`CTFontGetSymbolicTraits(font) & kCTFontColorGlyphsTrait`
  （`moui_text_providers/coretext/macos_coretext_text.m`）。不能再改回按名查：
  `CTFontCreateWithName(".AppleColorEmojiUI")` 被拒绝（返回 TimesNewRomanPSMT 并打
  CoreText console note），而 `moui_create_named_font_from_bytes` 对 `.` 开头的名字显式
  返回 NULL——trait 只能从**级联解析出来的那个字体**上读。
- **这条判据的代价在路线之外，而且是升级方向。** `moui_wgpu_renderer` 共用同一个
  provider，其 `EmojiText` 行声称 `supported`；按旧的名字判据，这个 claim 在 macOS 26.3
  上不可能真交付过彩色。这轮没有为 wgpu 那行重新取证（它的 61 个测试与
  `moui_tests/text_conformance/native` 的 10 个测试原样通过），所以那是一条**已知可疑的
  `supported`**，L4 要带着数字处理它。
- **"颜色真的活到了像素里"的非空洞证法（可复用）**：跑两个 run colour——纯红 run 断言
  green 通道非零、纯绿 run 断言 red 通道非零，两条 claim 各自归零对方依赖的通道，一个实心
  白条骗不过两条；再加一对**同一字形盒、只差栅格格式**的配对断言（ColorRgba fixture 在
  (1,1)/(5,3) 绿、AlphaMask fixture 在同位红），以及 noop engine 对照必须 0 像素。Metal 侧
  实测 `🙂` 698 inked / 686 green / 698，ZWJ 序列 `👩‍💻` 1011 / 993 / 1011。
- **能力表的两条永久事实**：(1) `capabilities.mbt` 的 status/note 两个走现在都**点名全部
  17 个 `RendererFeature`、没有 `_ =>`**，新增一个 feature 在本模块是编译错误而不是一个
  默认 `gap` 行；代价是包内 tripwire 的 Gap 那一半今天没有行可触发，替换它的保证是编译
  错误 + 85 格校验器（后者每台宿主都跑，而本模块只在 darwin 编译）。(2)
  `docs/zh-Hans/renderer-capability-report.md` 的镜像**不被机器校验**，它会漂——这轮就在
  同一行发现 Sun 的 `EmojiText` 格子写 `supported` 而代码是 `Partial`。改 en 表必须手改 zh
  表。
- **能力行不等于探针（2026-10-28，L4 paint-state probes）**：17 行里最先要查的不是"哪行标得太乐观"，
  而是"哪行的 op 从没被任何测试画过"——`PushTransform`/`PushOpacity` 四个 op 在模块 48 个测试里出现 0 次，
  对应的 `Transform`/`Opacity` 两行的 `Partial` 其实是读代码读出来的断言。11 个上设备的探针
  （`metal_state_wbtest.mbt`，48→59）第一次就把 transform 和 scope 组合起来，就翻出两个真实误画：
  ①`append_metal_box` 用**未变换**的 rect 做 clip 剔除，于是被 transform 移进 layer mask 框内的矩形画不出来；
  ②`metal_state_with_clip` 不把 clip rect 随 CTM 变换，而 wgpu 路线
  （`native_visual_state.mbt:48`）变换——两条 native GPU 路线读同一条命令流读出两种结果，参照路线就是证据，不用另写 spec。
  共同的例外：`LayerSpec` mask 在两条路线上都**不**变换（`:185`），因为 mask 命名的是屏幕上的框，clip 命名的是调用方坐标系里的形状。
  可复用的判别式：**一个 op 若在测试里 grep 不出一次调用，它那一行的状态标签就是没验证过的声明；
  `Partial` 看着保守，不等于有证据。** 定位成本很低——拿每行 note 里点名的 op 去 grep 测试目录，从空的那几行开始。

- **A/B 前先确认 patch 真的落地（2026-10-28，第二次踩同一个坑）**：`moon fmt` 会把
  `clip: state.clip\n      .intersection(...)` 这类链式表达式重排缩进，于是按原缩进写的 patch 匹配 0 处、
  静默 no-op，"回退后仍然 59/59 全绿"看着像测试没牙，其实是回退根本没生效。
  规则：脚本改代码做 A/B 时先 `assert old in s` 再写，改完立刻 grep 结果行；
  真正的空转门要的是"拔掉后必红"，不是"装上后是绿"。这轮的 A/B 按此执行并留了字节级凭证：
  改前先 grep 确认 patch 命中格式化后的文本，恢复用 `shasum -c` 比对改动前的校验和，然后 63/63。
  牙是真的：`Rect → Gap` 同时红掉 ink 走查（"reports gap while its probe stream paints 64 pixels"）
  和 note 门（"a Gap row must say the feature is absent"），`BlendMode → Supported` 红在 refuse 门
  （"reports supported, but its probe refuses 1 ops"）。

- **retained layer 的 emitter 是真的，但"证据 app 每帧都在付"这句被证伪（2026-10-28）**：链路很短——
  `View::repaint_boundary()`（`moui/core/view_modifiers.mbt:511`）→ `plan.repaint_boundary`
  （`moui/core/modifier_paint.mbt:270`）→ `paint_engine.mbt:134` 调 `with_repaint_boundary_cache()`
  （`render_tree.mbt:197`），其 key 是永不空的 `"element=…;x=…;w=…"`（`:230-232`），于是 `:98` 一定
  push `BeginRetainedLayer(spec)`。app 侧 emitter 在 `examples/showcase/app/diagnostics/components.mbt:24,32,80`
  （每个 diagnostics section 的滚动主体**和**标题面板）。四个检查否掉了更强那句：`examples/showcase/macos_metal/main.mbt`
  既不传 `route` 也不传 `initial_section_code`；`ShowcaseRoute::default()` 是 `Components/welcome`
  （`examples/showcase/app/workspace.mbt:84-86`）；showcase 里 `repaint_boundary()` 只出现在 diagnostics 面板；
  `grep -rn macos_metal scripts/ checks/` **零命中**——没有任何已提交门启动这个 app。诚实的说法是
  "第一次导航进 diagnostics section 起就在付，落地帧不在"。同一条更正落到 `ShaderEffect` 那条记录上（它原先
  把 effects section 写成了"evidence app 的每帧"）。两个比更正更值钱的发现：`benchmarks/app_cached_layer`
  已经在驱动那个 section（`benchmarks/app_cached_layer/native/main.mbt:376`），所以 retained-layer 缓存腿
  **有现成的已提交仪器**；而 `RetainedLayerSpec` 本来就带 `key` 与 `content_revision`，加缓存不需要改 wire。
  判别式（可复用）：**"这个缺口的成本是潜在还是已付"必须查三件——谁 emitter、哪个 route/入口真的跑到它、
  有没有已提交门启动那个入口**。只查第一件会得出过强的句子。

- **能力表的真空门不是"标得乐观"，是"标签从没和像素对过"（2026-10-28，L4 row walk）**：
  `validate-renderer-capability-consistency` 比的是报告表格与 `metal_feature_status`，于是文档和代码
  可以就一条**根本画不出东西**的功能完全一致地通过；另外 15 行有像素测试，但没有任何测试把"某一行的标签"
  连到设备产出的一个数字。`metal_feature_probe_wbtest.mbt`（59→63）改成一行一条最小命令流上设备，四条断言：
  ①状态与 ink 一致（`Supported`/`Partial`/`HostForwarded` 必须有 ink，`Gap`/`Unavailable` 必须没有）；
  ②`probed == 16`——不写这条，静默少跑几行的循环体照样全绿；③单帧答不了的行**点名豁免**并且每次都复证豁免前提
  （`AsyncImage` 的两帧生命周期），否则豁免清单会变成藏东西的地方；④声称 `Supported` 的行，自己的 probe 不许
  `refused_count()` 非零。可复用的做法：**把一张表变成"观察可查的门"很便宜（每行一条流），而它和"doc 对 code"
  是两种证据**；只有后者的表，每一次 status 编辑都在免费通过。
- 这轮两个真实取舍：`BlendMode` 的 probe 先用 `Multiply`，在不透明黑 clear 上**正确地**画不出东西——此时只有两条路，
  改命令流或放宽断言，选了前者（`Screen`，白过黑就是 composite 自己的输出）并把理由写进注释，防止后人"修"回去；
  `Text`/`TextShaping`/`EmojiText` 必须用不同 raster（覆盖掩码 vs 绿色彩色位图），否则三次探针是同一帧在区分不存在的东西。
  walk 没覆盖的方向也写进了文件头：它只验证"挂在该行名下的流画出了该行声明的 ink"，**不**验证"流里含该行的 op"——
  后者需要 core 命令枚举给不出的 op→行登记表，所以新增能力行仍是评审义务，不是门。

- **L3b/L3c 之后的 Metal 路线现状（2026-10-28，阴影与 blur 两腿后更新）**：88 个模块测试 + 23 个 coretext
  provider 测试 + 11 个共享 text-conformance 测试；glyph atlas 是**按需增长的 1024×1024 页集合**
  （上限 4 页），不再是单张固定图集；`EmojiText`
  从 `Gap` 变 `Partial`（缺的那一半：真实 provider 证据仍是一次一个 run、主 pass、32pt、
  scale factor 1.0，圆角掩码 group 与两层嵌套彩色 group 还没过，且"某码位到底是不是彩色"由共享
  provider 的 trait 决定）。图层/filter group 内的彩色字形已经过了（3 个设备像素探针）。
  图集的 clear-and-retry 让彩色字形与覆盖掩码共用同一条重置路径，今天只在**整个页集合**装满后才触发。


- **A/B 要挑"第一个断言还绿"的那一层（`ShaderEffect` builtin，2026-10-28）**：四个新像素探针
  各自第一行都是 `assert_eq(report.shader_effects_fallback_painted, 0)`。把 CPU 侧 kind 强制成
  `metal_effect_none` 后确实红了 4/74，但四条全部死在这同一个计数器断言上——像素那半根本没跑，
  这一轮只证明了计数器，没证明画面。把 mutation 下移到 CPU→MSL 的交接（往 `edge.z` 写 0.0，
  kind map 和计数器都不动），同样 4 条改死在像素断言上且计数器仍全绿，这才证明 MSL 分支真的在产像素、
  shape 记录真的是载体。规则：mutation 后**看每条红在哪一行**；如果 N 条红都停在同一行的同一个断言，
  就等于只验证了"这条测试会读那一行"，要换一层让前面的断言保持绿。
  同一轮两个可复用点：①共享契约是函数不是口头传统——`builtin_shader_names()`
  （`moui/render/common/advanced_execution.mbt:87`）已经把"哪四个名字算 builtin"写死了，判据照它实现即可；
  ②"新参数是一个槽，不是一次格式变更"——144B per-item 常量里 `edge.z/edge.w` 一直是写死的 `0.0` 且无人读，
  所以 effect kind/amount 进去后 wire 大小、`metal_renderer.mm`、顶点格式全没动（`Clip` 腿复用现成 pass 是同一招的第二次）。
  逐效应选 formulation 而不是整条抄某一路由：checker/vignette 跟 Skia+Sun（方格 `min(w,h)/amount`、
  半径 `max(w,h)/2*max(amount,0.8)`），不跟 wgpu（它按轴归一化→非正方 frame 出长方形格，且 `max(amount,8.0)` 吞掉粗格请求）；
  `solid` 反过来跟 wgpu 的"单色"而 Skia 用整支 fallback brush——两处分歧都写进 note，不假装与主线一致。
- **改"画什么"之前先找"这个能力在别的 scope 上是不是已经实现了"（`Clip` 圆角裁剪，
  2026-10-28）**：`PushRoundedClip` 之前退化成包围盒 scissor。真正的修法看着像要动
  wire 格式 + MSL（每 item 传裁剪圆角盒）：其实 `LayerMask::RoundedMask` 的 composite
  早就用 `moui_rounded_box_sdf` 给自己的 group 圆了角，`PushLayer/PushFilter` 早就会给
  一个 scope 开离屏 pass。于是圆角裁剪 = "把 scope 变成带 RoundedMask 的 pass"，
  `metal_shaders.h` 与 76B 顶点/36float shape 记录一行没改。可复用的动作：在加新线上字段前，
  先 grep 同一形状在别处是否已被正确画过，以及现成的 scope 机制能不能直接承载它。
- **前提检查就是保真的一部分**：`metal_exact_rounded_clip` 只在①开启的变换是轴对齐均匀缩放
  （旋转/非均匀缩放会把圆角变成椭圆）②父裁剪与 surface 边界都不缩小该 rect（composite 圆的是
  "递给它的盒子"，缩小后的框会圆错角）时才走精确路径；否则退回包围盒 scissor 并继续
  `approximated_clips += 1`。测试里必须有一条专门钉"退化的那两种情况仍然被计数"
  （"a rounded clip that cannot stay a rounded box is still counted"），否则前一条成功测试
  会被读成"圆角裁剪已解决"。
- **代价先量再写：这条 pass 成本目前是"潜在"而非"已在付"**。全仓 `push_rounded_clip`
  与 `RoundedClip` 只有定义处（唯一 emitter 是 `moui/views/controls/layout_helpers.mbt:77`
  的 `RoundedClip` view），没有任何 example/view 调用——所以这轮改动对真实 app 的帧开销是 0，
  只有哪天宿主用了圆角裁剪容器才开始按卡片付 target。（这是 grep 使用数，不是跑出来的 perf 数。）
- **精确不是免费的，代价要在写下的那一轮写清**：一个精确圆角裁剪现在 = 一个 pass =
  一个裁剪框大小的离屏 target + 一次 composite（`report.layers` 计数）。每卡片都圆角的页面
  按卡片数付 target。stencil 附件才能对所有形状（含旋转）既精确又不额外开 pass，但那是
  wgpu 路线共享的工程——而 wgpu 的 `Clip` 行此刻声明 `supported`，自己的 `clip_radius` 却无人读。
- **"不加自造必要性"也适用于补平权**：Metal `dispose` 没像 Skia 那样把缓存源逐个标成
  `ImageDisposed`，看起来是缺口，实际没有任何读方——`RendererSession::image_diagnostics`
  只有测试调用，两条宿主 dispose 路径都是终态（`window_frame_state.mbt:166-172` 之后不再画帧，
  `window_host_workflows.mbt:16` 直接丢弃刚 dispose 的 session）。所以不加；真缺口是**会话中回收**
  （`evict_disposed` 两条路线零调用方），那需要一个高于本模块的策略决定。
- **不透明黑 clear 上的遮罩强度只能读 rgb 通道**：composite 输出是预乘的，source-over 会把
  alpha 补回 255，所以"角上被遮掉"在 `.3` 上完全看不出来（实测 rgb 13 / alpha 255）。
  第一版断言写了 `corner.3 < 120`，是自洽失败而不是代码失败。

- **两条路线的图集容量已对齐在 1024×1024，这个数字是量出来的（L3c）**。512 时实测：
  用真 CoreText provider 塞不同的汉字，一帧只放得下 **~200 个 14pt/设备缩放 2.0 的字形**
  （14pt/1.0 约 651，24pt/1.0 约 333，24pt/2.0 约 92）。Retina 上整屏中文正文想要上千个
  不同字形，所以最密的页**每帧都丢掉自己的溢出**——L3a 修的是跨帧那面墙，这是帧内天花板。
  改到 1024 后：14pt/2.0 约 818、24pt/2.0 约 347、24pt/1.0 约 1389、1600 个 14pt 汉字无丢弃
  （**这句当时漏写了缩放**，读者会当成 Retina 也放得下——实际 14pt/2.0 的 1600 字要两页，
  现在两条 smoke 行都每次复测：`scale=1 items=1 dropped=0` / `scale=2 items=2 dropped=0`）。
  代价（写进 ADR 0045 第 3 条）：4 MB CPU 缓冲 + 4 MB RGBA8 纹理常驻（原为各 1 MB），
  任何出现新字形的帧整张纹理重传，每次 overflow 重试 4 MB 归零（`clear` 改为就地 `fill`，
  不再重新分配，字段因此被编译器判掉 `mut`）。
- **LRU 淘汰被明确否掉**：工作集大于容量时，淘汰与整图清空造成同样的每帧抖动，一个丢弃也
  防不住——"更聪明的策略"若不消除失败模式就只是成本。dirty-rect 上传同理是*成本*信号，
  留给有性能门的 L4。
- **盘点两份代码的差异，要按"能不能画错"排序，并且先比预算常量。** 上一轮写的"四处行为差异
  里 padding 与零尺寸字形是正确性差异"被证伪：文字采样器是
  `MTLSamplerMinMagFilterNearest`（`metal_renderer.mm:317`），邻接 texel 根本不会被读，
  padding 是 1px 还是 2px 无法渗色；两条路线的 `clear()` 都重建/归零零值数组，所以
  "WGPU 跳过全透明 texel、Metal 照写"也不可能留残影；零尺寸栅格在 Metal 只按**不同空缓存
  key**每个消耗 1 像素货架。真正会画丢字的差异——图集边长 512 对 1024——当时压根不在清单里。
- **图集尺寸写在两种语言里，漂移现在是响的**：`moui_metal_texture_write` 把长度检查从
  下限改成 `side*side*4` 的相等，比纹理大的调用方被拒绝上传，而不是"传前缀 + 采样垃圾"。
  A/B 证：只把 MoonBit 侧改回 512，三个 GPU 像素测试 + 新增容量下限测试一起失败，后者消息是
  "a 512x512 atlas only fit 289 distinct 28x28 glyph boxes"。容量测试断言 28×28（=14pt×缩放
  2.0）至少放下 700 个，介于实测 818 与旧的 289 之间，所以缩小预算会在模块里红，而不是变成
  用户眼前的缺字。
- **体积动机现在量出来了，而且推翻了"GPU 路线必然比 sun 大"的推导（L4，2026-10-28）**：
  同 app、同 flags（`-Wl,-dead_strip -Wl,-x`，测完就把两个 `moon.pkg` 恢复成 `""`，所以
  这两个开关没有提交）、同一天成对复测——`macos_metal` 4,101,856 B（`__text` 3,527,568 /
  `__const` 339,584），`macos_sun` 4,260,688 B（`__text` 3,699,004）。GPU 路线比所谓"地板"
  还**小 158,832 B**，`__text` 比 Sun 整个软件光栅器少 171,436 B。缺的那一步：GPU 路线不是往
  常驻的 MoUI 框架体上*再加*一个光栅器，而是用命令编码*替换*像素扫描，这次替换净负。所以
  4.80 MB（wgpu − sun）是 wgpu 引擎的体积，不是"碰 GPU"的价格；"任何新 GPU 路线落在
  4.06–11.05 MB"作废。sub-MB 仍然不可能（266,600 B 语言地板 + ≈4.0 MB MoUI 本体）。边界证明
  取自产物本身：`otool -L` 只有 Apple 框架 + libSystem/libz/libobjc，`nm -a`/`strings -a` 对
  skia/wgpu/`hal::`/vulkan 零命中。别把它读成门：`moui package macos` 打的是 debug 产物，
  `packageBytes` 预算（70/80/100 MB）是占位值，两边量的不是同一个东西。也别把它读成性质的：
  一个 app、arm64、一次构建，路线还欠 blur 质量、圆角裁剪模板、`Overlay` 混合这些代码。
- **L4 的 gpu_recovery 空门：两处真空，都不是 Metal 路线自己的（2026-10-28）**。(1)
  `RendererSession::new` 的 `recover~` 默认返回 `RecoverySucceeded`——今天没有渲染器踩到
  （Skia/WGPU/Sun 显式给 `FallbackToCpu`，TUI/Web 给成功，Metal 给具名拒绝），但它是下一个
  渲染器的陷阱，所以默认改成拒绝，新增测试
  `a session with no recovery path refuses rather than claiming success` 做了 A/B（旧默认下失败）。
  (2) 更大的一半在宿主：macOS GPU promotion harness 的 context-loss 阶段收尾时写
  `context_loss_done = context_loss_injected`、`recovered_within_vsyncs = wait_presents`，**不管有没有真的恢复**；
  而 `gpu_recovery_count()` 在所有路线上恒为 0（Skia 只接了 `gpu_fallback_active`，inject 是空函数），
  于是每个 promotion 产物的 `diagnostics.recoveryCount` 记的是"注入了几次丢失"而不是"恢复了几次"。
  现在只有计数器真的前进才算 done，summary 行多了 `context_loss_injected=` 和
  `recovery_count_after=`，`gpu-performance-metrics.mjs` 暴露 `contextLossInjected`。Skia 已记录的
  claim 不受影响，因为它靠 `automatic_fallback`（唯一接到线的信号）。
  判别式（可复用）：**一个门如果把自己"发起的次数"记成"观察到的次数"，它就是空转门**——读宿主代码时
  先看这类赋值，比读断言更快。
- **没写的东西也要记**：Metal 的设备丢失重建（`MTLDevice isRemoved` 轮询 + `recover` 重建）没做，
  因为 `RendererSession::recover` 在生产路径**零调用方**（全仓 4 个调用点都在测试里），
  防不出真实失败模式；重开条件写在 ADR 0045 §"Amended 2026-10-28 (L4)"——宿主哪天因为真实信号
  （`isRemoved`、surface 重建、唤醒）调 `recover`，那才是把 `RecoveryFailed("metal direct has no
  gpu recovery path before plan stage L4")` 换掉的时候。

- **"这条路线画文本"是一个声明两半，第二半根本不在渲染器里（2026-10-28，L4 text fidelity）**：
  `moui_metal_renderer/binding_factory.mbt:62` 装的是 `native_text_system_with_cache`，而
  `moui/render/native_text/text_cache.mbt:227-231` 只给 `measure`、**不给** `paragraph_layout` 钩子，
  于是 `moui/core/text_layout.mbt:155` 用 core 的逐行 fallback 算术 + provider 度量回答所有段落——
  换行、caret rect、选区、hit-test 在 Metal 路线上都是共享模块的路径。查这种声明的判据（可复用）：
  **看这条路线*安装*的那个 TextSystem 有没有钩子，而不是看仓库里有没有段落测试**。此前唯一的段落测试
  跑的是 `skia_text_system()`（它有原生钩子），所以这条组合零覆盖；非空洞证明：把
  `fallback_paragraph_should_wrap`（`text_layout.mbt:544`）改成永不换行，只红新加的 cosmic 与 coretext
  两例，Skia 那例照绿。
- **范围取舍：把契约放进已经拥有它的套件，而不是在渲染器里造第三份段落引擎。** 该行的 `Partial` 早已写明
  "composition root 包了平台 provider、背后没有第二套引擎"（`capabilities.mbt` 的 `Text` note），
  表格 `Native direct GPU` 列的 `Text` 也就是 `partial`；再加一份引擎是第三份副本、纯永久成本，换不到新证据。
  落地的是共享断言 `assert_diagnostic_native_paragraph_contract`（从 Skia 那例*提取*而非复制）+
  cosmic 一例（跨平台，所以 Linux/Windows CI 也托住这条路径）+ coretext 一例（`examples/showcase/macos_metal`
  真正注入的引擎），两例都另断言 `native_paragraph_ready == false`——诚实的那一半。
- **测试标题不是覆盖（同一轮）**：`metal session reports the fallback text system until the text leg lands`
  断言的是 `present_count` 与 `recover` 的理由，和文本系统无关——标题比内容多活了三条腿。核对办法很便宜：
  读测试时把标题和 `assert` 对一遍。新的接线探针（`metal session gives the runtime the injected engine's
  text system`）把 `text_system=` 指回 `@core.TextSystem::fallback()` 会**单独**失败，这才叫接上了。
- **第一个 fixture 撞出的不是断言松了，是真实的度量分裂**：provider 说 6.0、系统量出 8.8，因为
  `NativeTextLayout::is_valid_for_measure`（`moui/render/native_text/layout_validation.mbt:18`）要求
  每簇一个 caret，无 caret 表的测试 layout 被判无效，共享模型于是用 core 的 ~0.55em 估算喂 widget，
  而 painter 仍用 provider 的 placements。真实 provider 都带 caret 表（coretext 套件钉住了这些计数），
  所以这是 fixture 属性而不是路线 bug——但新测试存在的意义正是抓这种 widget 与像素各说各话，
  于是 fixture 故意留了"任何估算都算不出"的数字。**新测试第一次失败时先问"行为分裂还是断言太松"**，
  改断言是最贵的那种"修好"。
- **`checks/profiles.json` 曾没有任何步骤跑 `moui_text_providers`**：Metal 路线的文本依赖 provider，
  但那 22 个 coretext 测试只在有人手敲命令时执行过。现在 `platform` profile 里有 darwin 限定的
  `CoreText provider tests`。**盘点一条路线的覆盖时，把它的依赖模块拿去 grep profile 名单**——
  "存在于源码"与"被执行过"是两件事，和上一轮"能力表标签从没和像素对过"是同一类空洞。

- **能力行自己的 note 就是最便宜的工作队列（2026-10-28，L3 colour glyph in a group）**：
  `EmojiText` 的 note 早写着"图层/filter group 内的彩色字形还没过"，照着写三条就完事——
  三条都只用模块已有的 fixture（`metal_test_engine_for` 上彩色 raster、`metal_layer`、
  `metal_filter`），**没有新机制**，67/67 一次通过。可复用的坦白：这组测试与主 pass 那条
  彩色测试**共享同一个变异**（把 `blit_metal_glyph` 的 `coverage_only` 恒真，三条一起红），
  因为图集是一张纹理、group 合成根本看不到 run colour 可漏——所以它们扩的是"声明成立的上下文"，
  不是"新路径的证明"。不写明这点，后来人会把它们读成 group 专用彩色通道的证据。
  顺带新增值的一类：文字*第一次*进带 mask 的 group（`a masked layer clips its colour glyph
  as well as its pixels`），旧的 mask 测试全用填充；把 `metal_layer_clip` 里的 mask 去掉
  会让它连同 4 条填充测试一起红。
- **"字段被算出来"不等于"字段生效"（同轮，跨路线发现）**：wgpu 路线的
  `native_visual_state.mbt:56-81` 认真维护一个 `clip_radius`（嵌套取 min），但**没有任何代码读它**——
  剪刀来自 `state.clip`（纯 `Rect`，`:162`），唯一的每顶点半径通道是 `mask_radius`，
  只由 `layer.mask` 喂（`native_visual_advanced.mbt:10`）。所以那条路线圆的是*图层 mask*、
  不是*裁剪*，而能力表给它 `Clip` 打的是 `supported`，note 里对裁剪一字未提——正是本路线
  诚实写成 `Partial` 并计数的那个近似。查法很便宜：**给一个状态字段 grep 读者**，比读断言快。
  没有替它改表：改别的模块已发布的自述是主张变更，且真正的修法（裁剪形状写 stencil、后续绘制
  stencil-equal；一个顶点只有一个裁剪槽，所以"片元里算 SDF"做不了嵌套裁剪）是一套机制同时动两行。

- **"复用已有的一个字"第三次胜过"加一条新线"（图集分页，2026-10-28）**：`Text` 的 note 自 L3c 起就
  写着"单帧自己的字形集装满空 1024×1024 图集后仍然丢弃并计数"，而 clear-and-retry 治不了它——重装进
  另一张**同样大小**的空页撞的是同一面墙，于是那种帧每帧丢字，症状只是一个看起来正常的计数器。
  修法：货架装箱是单调的（字形只会放到当前排或下一排，绝不回头），所以一个 run 内页索引不降，run 拆成
  **连续顶点段**、每页一个 text item，页号写进 `item[7]`（图像角色读它当图像记录、合成角色读它当 pass
  槽，本来就没人同时读两个），76B 顶点 / 9×int32 item / 36float shape 记录 / MSL 一行没改，u/v 仍按页
  归一（页都是同尺寸）。按 alpha 深度切覆盖（每 MB 约 4 倍容量）被否：那要**逐字形**选页，必须加顶点
  属性，也就是改 wire。可复用的动作与前两条同形：加新字段前先问"哪个已经存在的字，在这一角色下是空的"。
- **分层的成本要说"稳态多少、上限多少"，不能说"常驻多少"**：page 0 构造时分配，所以文本轻的路线付的
  还是 1 个 4 MB CPU 缓冲 + 1 个 4 MB 纹理；后续页只由真需要的帧分配；`METAL_ATLAS_MAX_PAGES = 4` 把
  最坏情况钉在 16 MB + 16 MB；`dirty` 改为**逐页**，只碰 page 0 的帧仍只传一页（原来任何新字形都整张
  重传）。宿主在 `clear` 时**故意不释放**后续页纹理（留到 context 释放）：在那里释放就会让一个反复越界
  的文档每帧重建 4 MB 纹理。页上限也是两种语言各写一份（`kMouiMetalMaxAtlasPages`），宿主对越界页号
  拒绝而不是照着 grow——越界是 CPU 侧没打算发的值，不是要服务的请求。
- **测出来的数字要两个方向都测（同轮）**：真 CoreText provider、1600 个不同汉字、14pt——
  scale 2.0 `items=2 dropped=0`，把上限钉成 1 页时 `items=1 dropped=782`；`1600 − 782 = 818` 正好是
  L3c 用另一种 fixture 得到的每页天花板，等于用第二个实验复证了第一个。smoke 现在还测 scale 1.0 并断言
  `items == 1`：一页本来就够的帧**不许**顺手把图集撑大——稳态成本需要一条测试托着，否则它只是注释。
  mutation 三轮都挑"会死在像素断言"的那层（本功能每个测试第一行都是计数器）：宿主恒绑 page 0 只红
  `metal_text_wbtest.mbt:529`（第二页前那段空白），上限改 1 红 3 条含 `:530`，让 run 拆分条件永假红
  `:527`（第一页自己的墨）。恢复后 76/76。

- **retained-layer 缓存第四次证明"复用现成的东西"胜过"加新机制"（2026-10-28）**：不需要新的
  picture/pixel 缓存，也不需要改 wire——宿主 `moui_metal_pass_target` 本来就按 slot 跨帧保留离屏
  target、只在尺寸变了时重建。所以"同一 boundary 在紧接的下一帧仍占同一 slot、设备矩形一致"就可以直接
  合成那张纹理：命中时推一条 `child_count = 0` 的 pass 记录、跳过子流不画，宿主 pass 循环只加一个分支
  （childless 记录不开 encoder，因为开就清了缓存像素）。这个分支对所有既有流是 no-op：空 group 从来不推
  记录（CPU 侧把 slot 退回去）。三重守卫各关一种画旧图的路：revision 相等、slot+xywh 全等、entry 必须来自
  **紧接的上一帧**（pass target 不专属某个 boundary，间隙里谁占过那个 slot 就覆盖了它）。
- **命中必须重新盖章，否则缓存只能两帧省一帧（这轮真实 bug，只有四帧设备跑才看得见）**：命中不画图，于是
  entry 的 `painted_at` 停在旧代；第二帧命中后，第三帧按"上一帧"规则判它过期→又重建。修法是命中时把 entry
  重新 `store` 一遍，理由要说清（命中帧自己也占着那个 slot，所以期间不可能别人画过）。可复用的判据：
  **跨帧缓存的语义必须用"至少三帧"的序列测试**，两帧刚好测不出老化；这轮五个计数器测试全 device-free，
  但这一条只能上设备。
- **缓存类功能的像素证明是"故意陈旧"那一条**：第三帧保持 key/revision 不变但把子内容换成绿色，断言像素**仍是
  红色**——因为"命中后画成当前流要求的样子"与"根本没命中、重新画"在像素上无法区分，陈旧读取才是跳过子流的
  唯一证据。配套要有一条镜像断言（revision 一 bump 绿色就到），否则这条只能证明代码没跑。A/B 三次：删掉宿主
  那个 childless 分支只红 1 条且死在像素断言（`:351`，计数器全绿）；命中忽略守卫红 4；永不命中红 5。
- **`.mbti` 行预算的登记处是 `tools/moui/validate_api_surface/main.mbt` 的 PackageBudget 条目**（不是
  checks/*.json）：每条带注释写明历次上调的理由，公开面变宽时就在那条注释后追加一句（本轮 53→56，三个字段
  全在已有的 `MetalFrameReport` 里，没有新增声明/类型/函数）。`node scripts/generate-repo-docs.mjs --write`
  会重新生成 `docs/repository-facts.md` 并同步 website docs，而且它内部会跑 api-surface 校验——预算没登记时它是
  **抛异常**而不是报红，容易被误读成脚本坏了。
- **新增探针若与已有探针共享同一个变异，就必须写明"这是扩范围不是新路径"，并再配一个只打中新探针的变异（2026-10-28，彩色 group 收尾腿）**：五个 group 情形（普通/brightness 滤镜/矩形遮罩/圆角遮罩/两层嵌套）共用同一条彩色分支——分支在顶点处就选定，合成阶段读不到也无权重染。强制走 coverage 那条分支会一次红 6 条（含两条新测试），这恰好就是要披露的那条局限的形状；于是第二刀只把 `RoundedMask` 的 mask kind 改成 `metal_mask_none`，红 3 条且新测试死在自己的消息上（"the corner the radius should clear is inked"）。判别式：**"新测试是不是旧测试换了件衣服"由变异集合回答，不由标题回答。** 另外圆角遮罩这一发还是本路线第一次让 `LayerMask::RoundedMask` 从 `PushLayer` 到达设备（此前只有 `PushRoundedClip` 内部会构造它，`metal_geometry.mbt:331`），一条测试因此兼两个用途：像素对的时候要把这层身份也写进 note，别让后来人以为只是彩色测试。
  - 成对断言的必要性：遮罩类测试只断言"彩色保住了"会免费通过——去掉遮罩照样绿；所以必须再断言一个**同一 fixture 在该位置本来有墨**的角上为空（`(0,0)` 黑 + `(3,3)`/`(2,2)` 绿）。嵌套那组同理配 `report.layers == 2`，防止"只合成了一次"蒙过去。
- **Metal 的 blur 曾经是"回声"，现在是一条钟形；修它的同时挖出一个先于本腿存在的色彩矩阵缺陷（2026-10-28）**：旧核的抽点在 0 与 ±radius 上，两像素标记在半径 8 下回读为 128/128、六个空像素、+8 处又是 64/64——那是把该组复制了一份，不是柔化，而且没有计数器会说谎。改成可分离：水平级写进自己那张 pass target（**必须在 group 之前认领 slot**，这样宿主降序遍历才会把它排在 group 之后），合成时做垂直读取，sigma 就等于请求半径（与 `moui_skia_renderer` 的 `ImageFilter::blur(radius, radius)` 同一种读法），抽点落在每一个设备像素上直到 `min(2*sigma, 12)`，权重除以自身之和。一个被模糊的组现在报 `layers = 2`（中间那张 target 就是一条 pass），但 `filter_approximations` 仍只计一次。设备测试断言的是**剖面**而不是数值：两个轴都要越过标记、每个方向单调不增、+8 处不得比近处更亮——最后一条正是旧核过不去的那条，这才是把测试写成形状而不是写成一个数的理由。
  - 第二级刚接上时中间 target 回读成饱和平台，顺着它挖出的 bug 比 blur 本身更早存在：合成片元里 `else if (kind > 4.5)` **上界是开着的**，于是新加的 6/7 两级掉进了色彩矩阵分支；而 `metal_identity_color_matrix` 拿的是 `moui_wgpu_renderer` 那组数字——那是给按列索引的 `mat4x5f` 用的单位矩阵，对本 shader 的行读法而言它把每个通道都映射到了 red，连 `o.w` 也变成 red。今天不经 blur 也能碰到：`ColorMatrix` 传不足 20 个值时，复制只覆盖前若干个，剩下的仍是那份"身份"。两处都改了（分支上界收到 5.5，身份矩阵改成行主序、每行平移量在末尾），并且各有一条自己的测试。三刀 A/B 各钉一件事：换回错身份只红色彩矩阵那一条且死在 green 通道像素断言上（钟形照绿）；把垂直级改成再做一次水平，红在"标记下方没有光"；整个 blur 分支短路，则钟形与旧的柔化测试一起红。
  - 可复用的判据：**给 shader 增加枚举值时，要顺着所有 `kind >` 判断走一遍**——开区间的 `> 4.5` 这种写法在新 kind 加入时不是"风格问题"，而是会把新载荷塞进别人的分支；以及**跨渲染器复制常量数组前先确认两侧的读取方式相同**（列主序与行主序的单位矩阵，数字看起来一样、含义完全不同）。
- **shadow 曾经是"一块板"，现在是一条钟形；而旧测试对着一块板一直是绿的（2026-10-28）**：盒被撑大 `2*blur+spread`、坡道只占最后一个 sigma，实测 12 像素标记配 blur 8 → 形状左缘外八像素到右缘外七像素全是 255，然后盒缘一个像素掉 76 级。也就是说每张带阴影的卡片后面都贴着一块硬边圆角矩形。改成高斯在硬边上留下的那条剖面：coverage = `0.5*erfc(d/(sigma*sqrt2))`，d 从**被 spread 撑大的形状**（不是盒子）量起，sigma = `blur_radius`（与主线一致，因为 Skia 把 `radius` 当 sigma 交给 `ImageFilter::blur`）。本 MSL 没有 `erfc`，用 A&S 7.1.26（~1.5e-7，远低于 8bit）。盒撑到 `3*sigma`，因为 2 sigma 处仍有 2.3%，按 2 sigma 裁会切出可见边。零新增 pass、零纹理、零 wire，只是每片元一次 `exp`。
  - 可复用的两条判据：①**断言剖面，不要断言"存在渐变"**——旧测试只问"有没有软边"，所以一块板照样通过；新测试钉边沿≈一半、+1σ≈16%、+2σ<10%、到 +3σ 单调、且没有单像素大跳变。②mutation 要能只红新测试：保留高斯、但把 d 从盒子上量，**只有新测试红**——这既证明新断言看得见旧断言看不见的东西，也说明"换个锚点"这类结构决定必须有专属变异。
  - 遗留的一半写在行里，不做美化：距离场是单边的（比 blur 窄的形状中心约 81%，精确值约 50%）、拐角走 SDF、路径/纹理源投出的仍是外接框；真要模糊"画出来的内容"就得让 shadow 走 filter pass 机器（每个阴影一张 target）。
  - 跨路线后果只记录、不越界修改：Metal 与 `moui_wgpu_renderer` 在阴影观感上不再一致，而 wgpu 的 note 还写着双方共用同一套公式——现在它是过期的一侧；这与它那条没人读的 `clip_radius` 是同一类发现。

- **退出码来自管道最后一个命令，不是来自门**（2026-10-28 真实翻车两次）：`sh check.sh --profile pr | tail` 后台任务的 exit 0 属于 `tail`；那一轮 pr 其实连红两次——①改了 `MetalFrameReport` 字段却没跑 `generate-repo-docs --write`，`--check` 抛异常；②给预算加的解释注释把 `tools/moui/validate_api_surface/main.mbt` 顶过它自己登记的行数上限。规则：跑门就 `> /tmp/x.log 2>&1; echo $?`，然后**读日志里的 pass 字样**，别信管道尾部状态；改公开面就顺手重生成派生文档。

- **解码图像常驻量现在由本路线自己管（2026-10-28）**：每帧在建帧前执行 resident-bytes 预算（默认 `METAL_IMAGE_MAX_RESIDENT_BYTES = 64MB`；预算是 `MetalFrameContext` 字段，因此测试驱动的是**自动路径**而不是手调 helper），LRU 释放经 `moui_metal_image_release`（extern 数 8→9），并丢掉 keys/source_of 条目；`image_textures_released` 记每帧释放数。设备测试 `an evicted image is requested again while the resident one keeps painting` 钉住"释放≠消失"：下一帧要么就地重建、要么重新请求，完成之后 fixture 照样画出来。A/B：把建帧前的 enforce 去掉，该测试即红（`cache.released > 0` 那条）。
  - 仍然缺的是**按通知回收**：`ImageResourceLifecycle::evict_disposed` 全仓零调用方，所以只在字节压力下丢，不会在源被丢弃时立刻丢；何时该调它是本模块之上的策略，别在渲染器里编。
  - 过程教训（本轮又一次发生）：备份文件要拿**当前**状态做，别用早期快照回滚——我用一份改字段之前的 `/tmp/geo.bak` 覆盖掉刚加好的 struct 字段，白白多绕两轮；改完能编译再备份。

- **窗口门禁现在会回读它呈现的那张 surface（2026-10-28）**：之前的 gate 只证明"选的是直连路线"+"宿主 present 了一帧"，而**空白窗口也能过**。现在宿主在 present 前把 drawable 拷进 staging texture，统计与 clear 色不同的像素，打印 `MOUI-METAL-PRESENT width=2200 height=1360 ink=1817023`（真机 Retina 窗口，60.6% 有墨）。gate 解析这行并卡在 0.5%–99.5% 之外一律失败（空白帧、以及"每像素都不同于 clear"的坏 clear 都会被拒）。`framebufferOnly=NO` 只在 smoke 变量存在时才设，因为那拷贝每帧都要付带宽；不带变量时 layer 与从前完全一样。
  - 证伪方式值得记：把上报的计数写死成 0，身份行与 first-frame marker 照样打印（旧 gate 会绿），新 gate 以 "presented surface has ink=0 of 2992000" 退出 1；恢复用 `diff` 证明逐字节一致。**任何"看起来在检查"的门，都要构造一次它该红而旧版本会绿的情形。**
  - 别夸大：这是覆盖率（有没有画到真 surface 上），不是窗口内像素保真；逐像素断言仍属于离屏证明的活。
  - 这团代码把 `metal_renderer.mm` 顶到 1200 行新文件硬限（`pr` 抓到的）。按仓内既有规则**拆，不登记棘轮**：新增 `metal_present_smoke.mm`（95 行）+ 同名头文件，并在 `moon.pkg` 的 `native-stub` 里登记；宿主文件回到 1148 行，gate 数值不变。顺带一个可复用形状：宿主文件里"与编码帧无关的旁路关切"（smoke/诊断）天然就是独立 TU。

- **damage 与"我自己写错的悲观声明"（2026-10-28）**：①本路线 `render_frame` 完全不读 `frame.damage`，每帧整面重绘；原因不是偷懒而是结构性的——present pass 对 drawable 设 `MTLLoadActionClear`，只画损坏矩形会把矩形外**全部擦掉**。真正的局部重绘要保留后备缓冲或 `framebufferOnly=NO`+上一帧拷贝，与 `Overlay` 需要的 backdrop 是同一族代价。决定已写进 `renderer.mbt` 调用处注释与计划的 Permanent cost surfaces，顺手挡住"把 damage 接进 scissor"这种看似优化、实则会画出空白帧的"修"。②同一轮里我发现自己上午写进 `Shadow` 行的"路径/纹理源仍投外接框"是**假的**：`ShadowSpec::new(rect~ : RoundedRect, …)` 在命令模型里根本表达不出路径形阴影，没有 app 能触发那个误画。已在模块自述与两份表格里改为真实残余（拐角衰减走距离场而非精确二维卷积）。
  - 通则：**过度悲观的行和过度乐观的行一样贵**——一个藏缺口、一个造缺口，读者按表分配工作两种都会错；两者都靠同一个习惯兜底：每条断言回到类型或设备再看一眼，别相信自己的措辞。

- **能力行走查的第二半：每一行现在要交出自己的"后果"，而不只是墨点（2026-10-28）**：`metal_probe_row_observed(feature, report, pixels)` 对**全部 17 行做无兜底 match**（新增 feature 在这里同样是编译错误），每臂是一条**打印测量出来的**可观测量：clip 把 64 像素砍到 ~16、transform 让 `(0,0)` 保持黑而 `(6,6)` 有墨、blur 必须把光放到它包住的外形**之外**（ink 80 > 64）并报 `layers=2 / filter_approximations=1`、圆角盒留白 `(0,0)` 且 ink 60、渐变沿轴换通道、opacity 落在 128、阴影在自己的框外仍然有墨并逐像素变淡、图像是红左蓝右、文本与 shaping 都 <48（不是实心条）、emoji 在纯红 run 下点亮 green、shader-effect 与 blend-mode 交出自己的计数器。
  - 为什么先打印再断言：我第一版 `Image` 断言写错了通道（把打印元组的顺序读成 red/blue/alpha，其实是 red/green/blue），walk 立刻红——**是测量值纠正了我，而不是我读夹具读对了**。凡是要写阈值/像素关系的测试，先跑一遍打印全部实测值，再落断言。
  - A/B：把 Clip 行的流换成裸 fill（去掉 op，ink 仍 64）→ 恰好红在后果断言上；恢复 `shasum -c` 通过，90/90。头注释里那条"这里不检查流里是否含该行的 op"已按事实改写：流的**选择**仍是评审事项，但选了不exercise该行的流会撞上为它写的谓词。

- **2026-10-28：这条路线此前从没被任何"已提交的步骤"在真窗口里跑过**——离屏像素证明、真 provider 文本 smoke、90 个模块测试、六个校验器全有，唯独没有一步去开 `CAMetalLayer` 并 present。手工一跑就过：`MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/macos_metal` 打印 `macOS renderer presented first frame; exiting by request` 并 exit 0。于是它成了 gate：`scripts/macos-metal-presentation-smoke.sh`，注册进 `platform`（darwin）。
  - 关键细节：**gate 必须看两行**。宿主的 marker 只报平台（Skia/wgpu 走同一后端、印同一句），所以入口额外打一行由模块自己的 descriptor+capability 拼出的身份（`renderer=direct-gpu family=direct-gpu provider=metal-direct`）。A/B 打在 gate 上：把身份正则改成 `renderer=skia-raster` → exit 1；改回 → 通过。只查宿主那行的 gate 会给任何渲染器开绿灯。
  - 别把这一步读大了：它是"首帧 present"，不是窗口内像素断言（没有 drawable 回读），就绪度仍是 `experimental`。它回答的是一直没被回答的那个更基本的问题：**它到底能不能在真窗口里跑起来**。
  - 同一轮里两处当天写下的"没有已提交脚本启动 macos_metal"随之作废，已就地标注为历史并被脚本名替换——发现自己今天的句子过期，要当场改，不要留给下一位。

- **`metal_proof` 原来硬编码 scale 1.0，所以本模块所有真实 provider 像素断言其实都是 1× 断言（2026-10-28）**：`metal_proof_pixels` 现在有 `scale_factor~ = 1.0`（逻辑 width/height、设备 width*scale 个 texel）；几何本就把两个空间分开（NDC 用逻辑尺寸，剪刀与 pass 变换用设备尺寸），所以只有 proof pass 变了。真实 CoreText 下 Retina 彩色证据到位：🙂 6084 墨化/6018 green、ZWJ 8146/8049、noop 控制恒 0。
  - 让参数无法"装了不用"的写法是一对此消彼长的断言：scale 2.0 下 4 逻辑像素的盒子在设备 `(6,6)` 有墨、`(9,9)` 无墨，而**同一条流**在 scale 1.0 下 `(6,6)` 必须是黑的。把设备尺寸改回逻辑尺寸只会红这一条测试（89/90）——这就是本模块认账前的那一刀 A/B。
  - 两条文本行由此丢掉一句不真的免责声明（"Retina 回读未证"），换上真的那句：矩阵是抽样不是覆盖（Retina 只有主 pass 每样本一次；字号梯度与 group 合成都在缩放 1.0），以及"码位是否彩色"归 provider 的 trait。两行都没离开 `Partial`。**免责声明也要当断言来核对**：它可能是"能力缺失"，也可能只是"测量没接线"。

- **两条文本行的 `Remaining:` 里写着"只量了一种"，于是 smoke 长成了网格，并且证明这网格会红（2026-10-28）**：emoji 证据现在按 24/32/48pt 每档跑，并且除了主 pass 之外也穿过一层 layer 合成（ZWJ 序列墨化 576/1011/2290，其中 571/993/2240 点亮 green；group 内 2098/2048、`layers` 1；noop 引擎每一档都必须是 0，否则这一切只是背景色）。图集容量改成格元：(14pt,1.0,1600)→1 个 text item、(14pt,2.0,1600)→2、(24pt,2.0,900)→3，全部 dropped=0；第三格才是重点——它用第二个字号复证了每页天花板，而不是把 14pt 的数再念一遍。非空洞证明：把 `METAL_ATLAS_MAX_PAGES` 钉成 1，smoke 立刻报 `items=1 least=2 dropped=782` 并 abort，782 正是分页那条腿当初手工量到的数——现在它是回归绊线，不是一段话。
  - 之后两行让出去的话也更准：回读**彩色**只到 device scale 1.0（`metal_proof` 一个逻辑像素一个 texel，Retina 靠计数器与模块自己的假 raster 探针），容量网格是两字号两缩放而不是全字体全文案。两行都没离开 `Partial`——网格消掉的是免责声明，不是缺口。这正是 `Remaining:` 约定要守住的分别。
  - MoonBit 语法三坑（都在同一轮踩过）：带默认值的 labelled 形参在函数体里**不带** `~`（写 `width=side`，不是 `width=side~`）；调用点写 `size~=size` 会被 `moon fmt` 改成 `size~`，所以手工补丁要先重读文件再匹配；以及补丁脚本一律先算好新文本再 `open(...,'w')`。

- **blur 半径曾经"不增宽"：抽点间距必须随 sigma 走（2026-10-28，先测后改）**：可分离核每轴十三抽点、间隔 1 设备像素、support=`min(ceil(2σ),12)`，于是无论 σ 多大触及范围都只有 ±12 像素，半径变大只是把权重压平。设备实测 σ=16 的直边：边内 16 像素处 255（理想 214）、边上 122、+1σ 处**正好 0**（理想 40）——"radius 16"其实只糊到 6。修法是一个除数：`stride = max(σ/6,1)`，抽点取 `index*stride`，权重按 `(index*stride)^2`，support 改 `min(ceil(2σ/stride),12)`；抽点数与成本不变，覆盖范围回到 ~2σ。改后实测 212/119/32/10/0（对照理想 214/128/40/17/6）；残余是十三个抽点的离散代价（远尾偏低约两成），note 的 `Remaining:` 也从"支撑被截断"换成这句真话。
  - 纪律：测试先写、先在坏核上红（`a large blur radius widens the falloff instead of flattening it`），再改 shader；同一个 stride 改动不能弄坏 σ=8 那条旧剖面测试（已验）。
  - 同一腿里两次自我更正，都留在记录里：`Shadow` note 里"精确双边积分约 50%"其实是 0.547（Φ(6/8)−Φ(−6/8)），81% 是量到的、50% 是我脑算的；计划里"本仓没有比自身 blur 更窄的投影元素"这句**并未核查**，已被改写成"这个说法没验证过，所以它不是理由，公开的数字才是"。写理由前先分清"量到的"和"我推的"。

- **写"全仓没有 X"这类否定断言前，先 grep 对的符号名**（2026-10-28，我连错两次）：AsyncImage 那半我先写成"宿主 starter 没有生产调用方"，用的是 `window_image_task_starter_set`——真实函数叫 `..._install`，而 `examples/momark/macos_skia/main.mbt:24` 确实在装 `@image_remote.remote_image_starter` 并把 worker 当作 pump 的兄弟任务跑。第二次修正里又差点漏掉"那个 starter 只推迟 `https:` 源"这条：showcase 喂的是 `data:` URI（`examples/showcase/app/diagnostics/formatting.mbt:129`），本地/内联源在两类 starter 下都是同步完成，所以"给 macos_metal 装个 starter 就能取证"这个任务前提本身不成立。最后站得住的版本是：全仓只有 momark/macos_skia 装了 starter（`macos_wgpu`/`linux_wgpu` 都没装），Metal 缺的那次观测被两件事卡住——本模块虽已登记 `publication: public`（`checks/release-modules.json:68`）但要等一条发布线才真的发出去（momark 是固定在已发布版本上的 submodule，且 `examples/momark` 里根本没有 macos_metal 变体），以及需要一个真会联网抓图的 Metal 变体；两者都在发布线/产品层，不是渲染器代码。登记 ≠ 已发布，这两件事也别混为一谈（这是同一轮里的第三次修正）。顺序语义本身已由 `moui/backend/common/image/window_image_tasks_test.mbt:134,:176` 用注入 spawn/post 钉住。做法：先 `grep` 符号定义拿到真名再 grep 调用方；把"某个证据拿不到"写成任务前，先确认那条路径在所选数据源下真的会异步。

- **`Partial` 行的缺口现在必须写成 `Remaining:` 句子，而且这条是可机器检查的（2026-10-28）**：本模块 `metal_renderer_wbtest.mbt` 里那条"Partial 必须说明缺的一半"的门，实现是 `note.length() >= 60`——长度检查分不出"解释"和"描述"，于是 `Transform`(814) 与 `Opacity`(715) 靠着只写"做了什么"、一个字都没提缺什么而一直绿。改法：约定每条 Partial note 以 `Remaining:` 结尾列出缺口，门收集**全部**违规行并用 label 一次报出（不是每轮只报一条）。补写的两个真缺口来自读代码而不是猜：Transform 因为仿射只落到顶点，"形状自身空间里按长度量的东西"（圆角半径、描边宽度、阴影 blur 带）在均匀缩放+旋转下精确、在非均匀缩放或斜切下两轴不可能同时对（这正是 `PushRoundedClip` 放弃精确路径的同一件事），且旋转过的 clip 只能给剪刀提供轴对齐包围盒；Opacity 因为乘进每个顶点色而非整次 draw 取一次，网格自重叠处会二次混色（Skia save-layer 是先组后压一次），且 group 的 opacity 落在合成上，继承 BlendMode 那条"只在非透明目标上精确"的半个缺口。
  - 顺手立一条纪律：**写"缺的一半"之前也要先证伪**。"彩色 glyph 不吃 opacity"听着合理，去读 `metal_geometry.mbt:704` 发现彩色分支就是 `白色.multiply_alpha(state.opacity)`——把它写进 note 就是反向的乐观声明。
- **用 python 就地打补丁时，先算好新文本再 `open(...,'w')`**（本轮真实自毁）：`open(p,"w").write(s.replace(a,b,"1"))` 会**先截断文件再求值参数**，`str.replace` 不接受第三个位置参数于是抛异常，留下一份 0 字节的 `capabilities.mbt`——而本模块未进 git，没有任何副本。救回来的是 `moon fmt` 一分钟前沿写到 `_build/wasm-gc/release/format/<pkg>/capabilities.mbt` 的那份拷贝（校验和逐字节一致）。两条可复用规则：①patch 脚本一律 `new = ...; assert new != src; open(p,'w').write(new)`；②**改动验证通过前不要清理 `_build`**——未跟踪文件的唯一历史版本常常就在那里（同一条也适用于被切片切坏的 `metal_shaders.h`）。

- **内嵌 MSL 的 `.h` 被误删后可以从编译产物里逐字恢复**：`_build/native/debug/build/<pkg>/metal_renderer.o` 里仍存有整段字符串，用 python 从 `#include <metal_stdlib>` 切到下一个 `\0` 即得原文。不要用 `strings` 转储重建——它丢弃长度小于 4 的 run，会把所有只含 `  }` 的行静默吃掉。另：这种 C 字面量形式里每一行 MSL 都必须自带 `\n`，注释行漏了 `\n` 就会与下一段字面量拼接——拼到注释无害，拼进语句就是静默吞代码。本轮的教训是：`kind > 0.5 && kind < 1.5` 这类判断在 shader 里**不止一处**（shader effect 派发也有），用 substring 定位切片必须锚定到唯一文本或行号并先打印命中范围，否则一次替换能删掉三分之一个文件。
- **行为变了，测试标题也要跟着变**：`a retained layer rebuilds into its own pass every frame` 现在只在
  "前面没有帧"时成立，改名 `a retained boundary with no frame before it rebuilds into its own pass`。同轮还要把
  断言"相反事实"的文档句子一起改：本计划 L2c bullet、ADR 0045 的 retained 段、两份能力表那一行都原样写着
  "每帧重建、没有缓存"，留着就是过期的自述。
