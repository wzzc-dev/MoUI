# real-skia smoke: paragraph 库缺失降级与缓存陷阱

- `wzzc-dev/skia` 的 release **shared(动态)包不含 SkParagraph 库**(`libskparagraph.so`/`.dylib` 等),只有静态包含;`moui_skia/scripts/linux|macos-skia-smoke.sh` 与 `configure-*native-pkg.sh` 在动态模式下检测到 headers/libraries 缺失且未设 `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1` 时,降级禁用 SkParagraph(不定义 `MOUI_SKIA_HAS_SKPARAGRAPH`、不输出 `-lskparagraph`),否则 `-lskparagraph` 链接必失败。
- 陷阱:这类链接失败可能被 moon 构建缓存掩盖——只要源码与链接命令不变,CI 不重新链接就"通过";改动 `moui_skia` 下任意 .mbt/.cpp 才会暴露。改链接相关脚本后应强制清缓存验证。
- `--require-skparagraph`(静态模式,如 `moui-renderer-real-skia-ci.yml`)仍严格检查并失败。
- 改 `moui/core` 等 public API 后必须跑 `node scripts/generate-repo-docs.mjs --write`,否则 `checks/api-surface-report.json` 过期导致 pr-profile 失败;`checks/source-file-policy.json` 的 maxLines 是棘轮,超行必须同步上调。

## moon prebuild:link_configs 是链接 flags 的唯一可靠载体

- moon **不会**在 `moon.pkg` 的 `link."native"."cc-link-flags"` 位置展开 `${build.MOUI_SKIA_CC_LINK_FLAGS}`(最终链接阶段拿不到 prebuild vars);`stub-cc-flags` 的 `${build.MOUI_SKIA_STUB_CC_FLAGS}` 会展开(编译 stub 时)。
- 因此 `moui_skia/build.js` prebuild 必须用 `link_configs: [{package: "wzzc-dev/moui_skia/native", link_flags}]` 把 flags 挂到 native 包,否则直接依赖 native 包的 is-main 链接(scripts/native_smoke、moon test)缺 Skia/libstdc++ flags,报 `undefined reference to SkJpegEncoder::Encode/std::__throw_length_error`。
- example 链路(经 moui_skia_renderer)会合并 native+renderer 两份 flags,产生 duplicate libraries 警告——历史如此,无害,勿再清空 link_configs。
- 真实 Skia smoke 脚本不依赖 prebuild:它们直接写临时 `moon.pkg`(硬编码 cc-link-flags)再 restore。

## native 包 public API 变更必须同步 fallback 实现

- `moui_skia/native/text_font_*_unavailable.mbt` 等 fallback 实现必须与 `*_native.mbt` 的 `pub fn` 名称一一对应,`tools/moui_skia/verify_native_capability_contract`(源码级解析 `pub fn X::y` 名称,双向比对)会检查;缺 API 报 "native capability fallback is missing public APIs"。
- 新增 native 包 public API 后:① 补 fallback 同名实现(None/降级语义)② `moon info -p moui_skia/native` 重新生成 `pkg.generated.mbti` 并提交,否则 PR profile 的 generated interface drift 失败。

## SkParagraph 行度量是 UTF-16 码元 + 宿主检查前的 stub 二进制陷阱

- `LineMetrics.fStartIndex/fEndIndex` 是 **UTF-16 码元** 索引(与 Flutter 同),而 rect/hit-test API 收 UTF-8 字节偏移。`skia_paragraph_line_metrics` 必须走 `skia_utf16_char_offsets(text)` 生成的专用表;ASCII 下两者一致,只有中英混排才暴露(README.zh-CN 换行乱位 bug 根因,回归测试在 `skia_renderer_test.mbt`)。
- `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build examples/showcase/macos_skia` 会把真实 Skia 二进制**替换成秒退 fallback stub**。任何宿主目检/截图验证前,必须先 `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke` 重建真实二进制,否则会拿旧/降级二进制误判渲染 bug。
- markdown_editor 的 macos_skia 入口支持 `macos_skia.exe <document.md>` 启动即打开文档:入口解析 `@env.args()`,`program` 经 `initial_document_path?` 在 init 里 batch `Effect::send(OpenRecentDocument(path))`(与最近文件菜单同一消息)。

## 绘制字形 id 必须属于绘制字体:SkShaper fallback 的 FFI 扁平化陷阱

- `moonbit_skia_font_shape_text_utf8` 用带 font-mgr fallback 的 `SkShapers` 排版,但 FFI run handler 把结果扁平化成 `glyphs/positions/clusters`,**丢弃 per-glyph typeface**。主字体(如编辑器字体链的 Open Sans)不覆盖 CJK 时,shaper 会用 PingFang 的字形 id 冒充"完整覆盖"(`missing=0`、advance 正确),而绘制仍以主字体 typeface 映射这些 id → GPU(Metal)上整段空白;同一 payload 在 CPU raster 上却画出乱码墨迹——"raster 有暗像素"不能证明字形正确。
- 因此 `moui_skia_renderer` 的字体解析链(embedded → font-files → `match_fallback_request`)必须用候选字体自身 cmap 全量覆盖文本才接受(`skia_typeface_covers_text`),payload 层再校验绘制字体覆盖文本(`skia_font_covers_text`);回归测试 `skia cjk text payload draws with a typeface covering that text`(host-capability aware)。
- 宿主 GPU 验证:临时在 `render_frame` flush 后对文本区域 `read_pixels` 统计暗像素(帧中途 read 会被后续命令覆盖出假 0);纯 CJK 行 dark=0 即 ink 丢失。临时插桩验收前必须移除。

## Apple 链接期体积门(-Wl,-dead_strip -Wl,-x)与"real-skia smoke 不走 prebuild"陷阱

- `moui_skia/build.js` 的 `platformFlags` 对 `macos|ios|iosSim` 追加 `-Wl,-dead_strip -Wl,-x`(2026-10-27)。`moon build --release --target native ./moui_studio/macos_skia`:30.51 MB / 56,553 符号 → 24.56 MB / 1,595 符号(-19.5%)。功能全绿:`moui_skia` 75、`moui_skia/native` 35(含 PNG `encode_to_data` 与 AVIF/JPEGXL 返回 None)、`moui_skia_renderer` 141、`moui_richtext` 325、`moui_tests/text_conformance/native` 10、`skia_text_emoji_smoke` 退出 0 且 8×`engine=skparagraph`。MoonBit panic backtrace 用自己的源码位置元数据,不依赖 Mach-O 局部符号,`-x` 只让 `atos` 丢局部帧。
- 剩余体积没有免费午餐:24.56 MB = `__text` 12.0 MB + `__const` 11.55 MB(其中 `_icudt_skiko74_dat` ICU 数据表 ≈10.3 MB),`__LINKEDIT` 已只剩 0.39 MB。下一刀必须动 ICU(`skunicode_core` 的 `SkUnicode::Make()`),有真实功能代价(bidi/复杂文字分行)。
- `moui package macos` 打包的是 **debug** 产物(`desktop_build_once` 默认 `release=false`,`run_package_build` 没传 `release~`):同 commit 同 flags,debug 33.35 MB vs release 24.56 MB。再降约 26% 要把 package 流程改 release,那会关掉 MoonBit debug 检查,属产品决策不是构建开关。
- `moui_skia/scripts/macos-real-skia-smoke.sh`(+ `macos-skia-smoke.sh`)**不经过 prebuild**:备份后临时写 `native/moon.pkg` 与 `scripts/native_smoke/moon.pkg`(硬编码 cc-link-flags,不含 prebuild 追加的 flags),EXIT trap 还原。因此它验证不了 prebuild 的链接 flags 改动;要验证 prebuild 效果,用 workspace 内 `moon build/test --release --target native <pkg>` 并核对产物符号数(未剥离是数万,剥离后约 1.1k~3.5k)。
- 同一 smoke 的 release provider 会 `curl` GitHub 下载 zip(本机 github.com:443 超时,只能命中 `.skia-cache/release/<tag>/` 已有缓存)。`moui_skia/scripts/native_smoke` 是独立 module,其 `.mooncakes/wzzc-dev/moui_skia/build.js` 是**已发布 0.2.5 副本**,不含工作区 `build.js` 改动,别拿它给 prebuild 改动做 A/B。
- `scripts/test-moui-prebuild.mjs:153`("Skia binding prebuild must leave link ownership to moon.pkg")与 `moui_skia/build.js` 无条件输出 `link_configs` 互相矛盾,在 HEAD 上即红(daily 第 196 步;`pr` profile 绿)。不要为了让它变绿而清空 `link_configs`——moon 不在 `cc-link-flags` 展开 `${build.MOUI_SKIA_CC_LINK_FLAGS}`,清空会让 is-main 链接报 undefined reference。
- 2026-10-28 已按上一条的告诫修掉:改的是**断言**而不是 flags——现在要求恰好一条 `package: wzzc-dev/moui_skia/native` 的 `link_configs`,且八个 archive 在其中各出现一次(`af9bafa6c` 恢复 native link_configs 是有意的,`3df372319` 的零条断言是过期前提)。

## daily 的三条既有红(2026-10-28 全部实证,非猜测)

- `check.sh` 给**每一步**注入 `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1`(`scripts/lib/check-runner.mjs:106` `defaultCheckEnv`,自 2026-07-08),于是 daily 在"无真实 Skia 的 fallback stub"配置下跑。`moui_skia_renderer/renderer_embedded_fonts_wbtest.mbt:26` 断言 SFNS.ttf 变量字体 `wght=900` 比 `100` 更宽,而 stub 里 `register_font_data` 不影响度量 → daily 恒红。A/B 已做:同一条命令加该 env 即失败、不加即 141/141 通过;换 HEAD 的 `moui_skia/build.js`(无 dead_strip)结果一样,所以 **dead_strip 被排除**,同时也说明本文早先记的"dead_strip 后 141 全绿"是**配置相关**的(只在带真实 Skia 的 standalone 下成立)。修法二选一属 owner 决策:测试在没链真 Skia 时自跳过(仓库里没有 MoonBit 可见的"Skia 已链接"谓词,`MOUI_SKIA_HAS_SKIA` 只活在 C 预处理层,加一个要动 `moui_skia` public API + mbti + api-surface 预算),或该步显式走 real-Skia(既有约定是 `scripts/macos-skia-renderer-smoke.sh` 这类 path-triggered smoke)。
- `tools/moui/generate_grapheme_break_fixtures/generate.mbt` 发的是 `Array[Int]`,生成的 `_wbtest.mbt` 被 `moon fmt` 规范成 `Array[Int32]`(**实测:`moon fmt` 会把 `Array[Int]` 改写成 `Array[Int32]`**),于是 `--check` 恒判过期。已把生成器模板改成 `Array[Int32]`(14 处),重新生成后与已提交文件**逐字节相同**——这类"生成物 vs 生成器"漂移,判据就是:哪个方向重生成后内容零 diff,哪个才是要修的一侧。
- `website/app/i18n_catalog_generated.mbt` 与生成器不一致(diff 1595 行,生成器发 `GeneratedI18nMessage::Text`、文件里是短名 `Text`)。方向判定:先试改生成器→studio **submodule** 里那份文件仍是短名?不是,它仍是限定名 1716 处,改生成器会把它撞红;再试 `moon fmt` 会不会自己缩短限定名(**实测不会**,406→406)。⇒ 生成器才是契约,`5fb1dd912`(2026-09-23,"clear toolchain-upgrade warnings workspace-wide")直接编辑了这份标着 DO NOT EDIT 的生成物,submodule 那份没跟着改。已用原生成器重新生成 website 那份(914 插/410 删,`--check` 与 `moon fmt --check` 与 `moon check website/app` 全绿),生成器未改。**教训:改生成器前必须先枚举所有被它生成的文件(含 submodule),否则会把一条红换成另一条更贵的红。**

## sun 路线体积基线与 base 包链接开关(moui/build.js)

- `examples/showcase` 同 app `--release --target native`:`macos_skia` 20.35 MB(`__text` 9.09 / `__const` 11.39 MB)、`macos_sun` 4.06 MB(`__text` 3.70 / `__const` 0.34 MB,`strings` 里 skia/icudt/harfbuzz 命中 0)≈ 5.0x。sun 不加链接开关是 4.98 MB/11,875 符号。
- `moui_skia/build.js` 的 flags 只随 Skia 依赖进链接;要覆盖 sun/wgpu 等非 Skia Apple 产物,必须加在 `moui/build.js` 的 `macosBackendHostFlags`(它经 `pushLinkConfig` 挂到 `wzzc-dev/moui/backend/macos`,是所有 Apple 链接的公共上游)。`MOUI_MACOS_BACKEND_HOST_LINK_FLAGS` 这个 vars 出口在本仓无消费者,改它无副作用。
- sun 侧验证:`moui_sun/{graphics 615,text 149,renderer 149,softbuffer 61}` + `moui_sun_renderer` 105 + `moui/backend/macos` 49 全绿,`sh scripts/check.sh --profile pr` 198 步 / 1,992 测试全绿;真机 `MOUI_MACOS_SUN_EXIT_AFTER_FIRST_PRESENT=1 examples/.../macos_sun.exe` 退出 0 且 `presented first frame`。仍未覆盖:菜单/拖放/UTType 这类只靠 ObjC 运行时按名查找的路径(dead_strip 对它们是理论裁剪风险),上真机点一遍才算清。
- 治理边界:Sun 是 experimental renderer(ADR 0023),不进 `auto`、不注册默认 composition root、不做可用性/性能承诺;`TextShaping`/`EmojiText` = Partial,图片只 PNG/JPEG/BMP;sun 入口目前只有 `examples/showcase/{macos,windows,linux}_sun`。

## 三条渲染路线的实测体积带 + "新增后端"的真实成本面（Metal 直连评估基线）

- 同 app `examples/showcase`、`--release --target native`、都带 `-Wl,-dead_strip -Wl,-x`：`macos_skia` 20.35 MB(`__text` 9.09/`__const` 11.39)、`macos_wgpu` 11.05 MB(`__text` 8.50；wgpu-native+hal+core **静态**链入，`nm` 命中 343 个 `wgpu_core/wgpu_hal` 符号，`otool -L` 显式链 `Metal.framework`)、`macos_sun` 4.06 MB(`__text` 3.70/`__const` 0.34)。⇒ ~~"不经 Skia 的 GPU 路线"不是缺口~~（2026-10-27 作废：owner 定的边界是"可用系统框架、排除外部图形库"，wgpu 入口链 `wgpu-native`，落在被排除集合内，所以 {有 GPU} ∩ {不链外部图形库} 确实为空——见 ADR 0044 与 `memories/repo/renderer-route-economics.md`）。wgpu 入口在 `examples/{showcase,momark}/{macos,windows,linux}_wgpu` 已存在，这一点不变。
- 新 renderer 的 MoonBit 接缝极小：`RendererProvider` 4 字段(`moui/render/provider_contract.mbt:23`)；`RendererSession::new` 14 个 labelled 参数里只有 `resize`/`render_frame`/`text_system` 必填(`moui/render/renderer_session.mbt:81`)。`DrawCommand` 26 变体(`moui/core/paint.mbt:418`)，`RendererFeature` 17 项(`moui/render/capabilities_feature_model.mbt:2`)。
- 主机侧已经交出处置好的 Metal surface：`moui/backend/macos/macos_present.mm:308-366` 建 `CAMetalLayer`、设 `drawableSize/contentsScale/opaque` 并返回裸句柄给 provider(`NativeSurface.surface_handle`)；iOS 同名能力在 `moui/backend/ios/ios_present.mm:167-189`。
- 手写 GPU 绑定的真实成本用 `extern "C" fn` 条数量：`moui_sun_renderer` 0 条、`moui_wgpu_renderer` 全仓 14 条(因为把 API 面外包给 `Milky2018/wgpu_mbt`)、`moui_skia/native` 292 条(canvas49+path55+surface_image_data62+text_font48+paragraph27+gpu_worker29+shader_filter13+picture9)。自写 Metal 会落在这条带的右端。
- 两个"看起来能复用、其实不能"的门（第二条已修正）：`moui_tests/text_conformance/native` 的 **paragraph/选区/hit-test 层**绑死 Skia（`text_conformance_test.mbt:254,282` 分支于 `@skia_native.skia_paragraph_available()`，成熟度字符串读 `@skia_renderer.backend_info()`），但它的**字形矩阵已经是 provider 中立的**：`assert_diagnostic_native_text_matrix(system : @core.TextSystem)`（:104-123）跑 16 个样本，且 :362-407 已由非 Skia provider 驱动。所以"仓库里没有 renderer 中立的文本一致性门"是错的（2026-10-27 证伪）；缺的是段落层。`moui_tests/renderer_contract` 只 import `core/render/render/common`，不含任何 concrete provider，这条仍成立。
- 治理：ADR 0005(`docs/decisions/0005-mobile-host-and-gpu.md`)只允许 Metal **via Skia**；ADR 0023 给 sun experimental + capability-freeze。新增第四条路线需要 ADR，且会引入第三份能力副本(参照既有 encoder 三副本弱保真教训)。
