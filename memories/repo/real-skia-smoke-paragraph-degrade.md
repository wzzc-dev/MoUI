# real-skia smoke: paragraph 库缺失降级与缓存陷阱

- `wzzc-dev/skia` 的 release **shared(动态)包不含 SkParagraph 库**(`libskparagraph.so`/`.dylib` 等),只有静态包含;`moui_skia/scripts/linux|macos-skia-smoke.sh` 与 `configure-*native-pkg.sh` 在动态模式下检测到 headers/libraries 缺失且未设 `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1` 时,降级禁用 SkParagraph(不定义 `MOUI_SKIA_HAS_SKPARAGRAPH`、不输出 `-lskparagraph`),否则 `-lskparagraph` 链接必失败。
- 陷阱:这类链接失败可能被 moon 构建缓存掩盖——只要源码与链接命令不变,CI 不重新链接就"通过";改动 `moui_skia` 下任意 .mbt/.cpp 才会暴露。改链接相关脚本后应强制清缓存验证。
- `--require-skparagraph`(静态模式,如 `moui-renderer-real-skia-ci.yml`)仍严格检查并失败。
- 改 `moui/core` 等 public API 后必须跑 `node scripts/generate-repo-docs.mjs --write`,否则 `checks/api-surface-report.json` 过期导致 pr-profile 失败;`checks/source-file-policy.json` 的 maxLines 是棘轮,超行必须同步上调。
