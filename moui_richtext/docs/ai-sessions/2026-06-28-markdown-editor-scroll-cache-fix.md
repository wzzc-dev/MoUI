# 2026-06-28: Markdown Editor 滚动 layer cache 失效修复

- **Agent**: Claude (GLM-5.2 via TRAE)
- **Goal**: 修复 `markdown_editor` 滚动后内容不更新、需要点击才会跳到真实滚动位置的 bug。
- **Outcome**: Success。根因定位到 layer cache key 漏掉 `frame.origin.y`，2 处补丁后全部 517 个相关测试通过。

## Summary

用户报告 markdown_editor 滚动后画面停留旧位置，点击才回到滚动后位置。诊断后发现是
`rich_text_block_cache_key` 与 `rich_text_block_content_revision` 只含 `frame.size` 而
漏掉 `frame.origin.y`，而 runtime 的 layer cache 命中判断只比对 `key + content_revision`，
导致滚动后 block 位置变化但 layer cache 仍命中旧位置的 layer。在两处缓存签名中加入
origin 坐标后，滚动时 layer 自动失效重绘，无需点击触发。

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_richtext/rich_text_editor.mbt` | `rich_text_block_cache_key` 字符串加入 `x=\{frame.origin.x};y=\{frame.origin.y}` | 滚动时 block 的 `frame.origin.y` 随 `top_padding - scroll_y` 变化，必须进入 cache_key 才能让 layer cache 失效 |
| `moui_richtext/rich_text_editor.mbt` | `rich_text_block_content_revision` 的 frame hash 由 `"\{w}x\{h}"` 改为 `"\{origin.x},\{origin.y},\{w}x\{h}"` | `Array::has_current_cached_layer` 同时比对 key 和 content_revision，两者必须同步包含 origin |
| `moui_richtext/facade.mbt` | `controlled_markdown_session_editor` 的 `revision` 末尾加入 `markdown_session_current_scroll_y(visible_scroll_y, visible_scroll_state)` | 让滚动状态变化触发 view tree 节点重建，使 paint 拿到最新 scroll_y 重新计算 block frame |

## Key Decisions

- **在 cache_key 和 content_revision 同时加入 origin**：runtime 的
  `Array::has_current_cached_layer` 用 `key == spec.key && content_revision == spec.content_revision`
  做命中判断，只改一处另一处不变仍会命中，必须两处同步。
- **保留 `facade.mbt` revision 加 scroll_y，撤销 `view_chrome.mbt` 的 `watch_scroll`**：
  `watch_scroll` 会触发完整 rebuild 导致 layout dirty，破坏
  `editor_app_cache_runtime_wbtest.mbt:72` 的 `dirty_layout_count == 0` 约束。
  revision 字符串只触发 paint 路径重建，足够驱动 block frame 重算且不污染 layout。
- **未改 runtime 的 `has_current_cached_layer`**：root cause 在 producer 一侧
  （moui_richtext 没把位置纳入签名），runtime 的命中语义本身正确，不应让 runtime
  去猜测 producer 的 frame 是否参与 cache 身份。

## Discoveries

- **layer cache 的命中模型**：`ViewPaintLayer` 通过 `cache_key + content_revision`
  标识身份，runtime `has_current_cached_layer` 只比对这两项，不比对 `frame.origin`。
  任何依赖位置变化触发重绘的 layer 必须自己把 origin 编码进 key/revision。
- **`MarkdownDocumentRichTextWindow::content_rect` 的偏移路径**：
  `content.offset(dx=0.0, dy=self.top_padding - self.scroll_y)`
  是滚动时 block frame.origin.y 变化的源头。windowed 渲染让 block 的 origin.y
  直接随 scroll_y 改变，不同于普通 scroll_view 只改 viewport 不改 child frame。
- **revision cache key vs watch_scroll 的代价差**：`View::node` 的 revision 字符串变化
  只让节点本身的 paint 重新执行，不会冒泡触发 layout dirty；`ComponentContext::watch_scroll`
  订阅 `State[Point]` cell 会触发 component rebuild，可能进入 layout 路径。滚动热路径
  上应优先使用 revision 字符串。
- **`markdown_session_current_scroll_y` 双源回退**：`visible_scroll_state: ScrollState?`
  优先于 `visible_scroll_y: Double`，保证 host 端 `ScrollState` 与 facade 入参一致时
  仍能取到最新 offset。

## Validation

```sh
moon test examples/markdown_editor/app --target native   # 377 passed
moon test moui_richtext --target native                  # 105 passed
moon test moui/runtime --target native                   # 35 passed
```

三个包共 517 个测试全部通过，无回归。未运行匹配 host 的 native Skia 滚动 smoke，
所以"真实滚动顺滑度"仍需后续手动 smoke 验证。

## Follow-Up

- [ ] 运行 `scripts/macos-skia-renderer-smoke.sh --run-markdown-smoke` 验证
      真实 native 滚动渲染顺滑度。
- [ ] 考虑给 `rich_text_block_cache_key` / `rich_text_block_content_revision` 加一个
      回归测试，断言同 block 在不同 `frame.origin.y` 下产生不同 key/revision，
      防止未来回归。
- [ ] 审视 moui_richtext 内其它 `ViewPaintLayer::new` 调用点是否同样依赖位置变化
      触发重绘（如代码块、表格的子 layer），若有需要同步加入 origin。
