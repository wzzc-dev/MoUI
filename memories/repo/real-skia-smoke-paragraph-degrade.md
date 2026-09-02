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
- `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build examples/markdown_editor/macos_skia` 会把真实 Skia 二进制**替换成秒退 fallback stub**。任何宿主目检/截图验证前,必须先 `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke` 重建真实二进制,否则会拿旧/降级二进制误判渲染 bug。
- markdown_editor 的 macos_skia 入口支持 `macos_skia.exe <document.md>` 启动即打开文档:入口解析 `@env.args()`,`program` 经 `initial_document_path?` 在 init 里 batch `Effect::send(OpenRecentDocument(path))`(与最近文件菜单同一消息)。

## 绘制字形 id 必须属于绘制字体:SkShaper fallback 的 FFI 扁平化陷阱

- `moonbit_skia_font_shape_text_utf8` 用带 font-mgr fallback 的 `SkShapers` 排版,但 FFI run handler 把结果扁平化成 `glyphs/positions/clusters`,**丢弃 per-glyph typeface**。主字体(如编辑器字体链的 Open Sans)不覆盖 CJK 时,shaper 会用 PingFang 的字形 id 冒充"完整覆盖"(`missing=0`、advance 正确),而绘制仍以主字体 typeface 映射这些 id → GPU(Metal)上整段空白;同一 payload 在 CPU raster 上却画出乱码墨迹——"raster 有暗像素"不能证明字形正确。
- 因此 `moui_skia_renderer` 的字体解析链(embedded → font-files → `match_fallback_request`)必须用候选字体自身 cmap 全量覆盖文本才接受(`skia_typeface_covers_text`),payload 层再校验绘制字体覆盖文本(`skia_font_covers_text`);回归测试 `skia cjk text payload draws with a typeface covering that text`(host-capability aware)。
- 宿主 GPU 验证:临时在 `render_frame` flush 后对文本区域 `read_pixels` 统计暗像素(帧中途 read 会被后续命令覆盖出假 0);纯 CJK 行 dark=0 即 ink 丢失。临时插桩验收前必须移除。
