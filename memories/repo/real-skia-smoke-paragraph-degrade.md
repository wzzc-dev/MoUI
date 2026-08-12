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
