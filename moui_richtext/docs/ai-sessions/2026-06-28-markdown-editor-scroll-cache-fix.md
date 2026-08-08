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
- [x] 考虑给 `rich_text_block_cache_key` / `rich_text_block_content_revision` 加一个
      回归测试，断言同 block 在不同 `frame.origin.y` 下产生不同 key/revision，
      防止未来回归。**结论：不需要这个测试。见下方 Follow-Up Update，origin 不应进签名。**
- [ ] 审视 moui_richtext 内其它 `ViewPaintLayer::new` 调用点是否同样依赖位置变化
      触发重绘（如代码块、表格的子 layer），若有需要同步加入 origin。

## Follow-Up Update (2026-06-28，同日回退)

**背景**：上方的修复上线后用户反馈"大文件滚动之后比滚动之前卡"。重新审计发现
本次修复的 `cache_key` / `content_revision` 加入 origin 部分是错误且有害的，需要回退。

**渲染器侧证据**：`SunRasterRenderer::update_cached_layer` 与
`SkiaRasterRenderer` 栅格化 cached layer 时都会执行
`canvas.translate(0 - spec.frame.origin.x, 0 - spec.frame.origin.y)` 抵消 origin
（见 `moui_sun_renderer/renderer_cached_layer.mbt` 与
`moui_skia_renderer/renderer_cached_layer.mbt`），所以 pixmap 内容只依赖 block 自身
和 `frame.size`，与 `frame.origin` 无关。`frame.origin` 只在 `draw_cached_layer_pixmap`
贴图阶段（`draw_transformed_quality_pixmap_rect` 用 `frame.origin.x/y` 定位）才被使用。

**真正根因重新定位**：原始 bug "滚动后内容停留旧位置、点击才回到滚动位置" 的正确根因
是 `facade.mbt::controlled_markdown_session_editor` 的 `revision` 字符串漏掉 `scroll_y`，
导致滚动时 view tree 节点不重建，paint 拿旧 `scroll_y` 算出旧 block frame，layer 以
旧 frame 贴图，所以内容显示在旧位置。`revision` 加 `scroll_y` 是修复的唯一必要改动。

**上次决策的错误**：误以为 `runtime::has_current_cached_layer` 只比 key+revision 不比
origin 是"runtime 缺失"，于是把 origin 编码进签名强行让 cache 失效。实际 runtime 的语义
正确——layer cache 的 pixmap 与 origin 解耦，producer 不应把位置进签名。

**回退动作**：
| 改动 | 处理 |
|---|---|
| `rich_text_block_cache_key` 去掉 `x=...;y=...`，只保留 `w`/`h` | 已回退 |
| `rich_text_block_content_revision` 的 frame hash 由 `"\{origin.x},\{origin.y},\{w}x\{h}"` 回到 `"\{w}x\{h}"` | 已回退 |
| `facade.mbt` revision 末尾的 `markdown_session_current_scroll_y(...)` | **保留**，这是上次修复唯一正确的部分 |

**回退后的滚动时序**：
1. `scroll_y` 变化 → `facade.mbt` revision 字符串变化 → view tree 节点重建
2. paint 拿到最新 `scroll_y` → block frame 以新 `origin.y` 重算
3. `ViewPaintLayer::new(frame=新 origin, cache_key=不含 origin, content_revision=不含 origin)`
4. runtime `has_current_cached_layer` 比对 key+revision → **命中**（都不含 origin）
5. `DrawCachedLayer(spec)`，spec.frame 含新 origin
6. renderer `draw_cached_layer_pixmap(pixmap, spec.frame)` → 用新 origin 把缓存的
   pixmap 贴到新位置

cache 不失效、不重栅格化、不触发驱逐抖动，滚动顺滑。

**Discoveries 补充**：
- **producer 的位置语义 vs runtime 的 cache 身份是两层**：layer 的 `frame` 是"贴图位置"，
  `cache_key`+`content_revision` 是"pixmap 身份"。runtime 用 frame 定位、用 key+revision
  判缓存身份，二者解耦。producer 把位置混进 cache 身份是反模式。
- **layer cache 失效代价远高于节点重建**：节点重建只触发 paint 路径重新产出 commands
  （CPU 上 cheap），cache miss 触发整张 pixmap 重新栅格化（CPU 昂贵，且可能引发
  `sun_cached_layer_max_entries=32` 上限下的驱逐抖动）。位置变化应优先让节点重建拿新 frame，
  不应让 cache 失效。
- **`repaint_boundary_cache_key` 的对照**：runtime 自己的 `repaint_boundary_cache_key`
  （`moui/runtime/render_tree.mbt`）确实包含 origin，但那是为 element 节点重绘 boundary
  服务的、由 runtime 自己维护的 key，与 `ViewPaintLayer` 的 producer-supplied cache_key
  不是一回事，不能拿这个对照去推断 producer 也该把 origin 放进 cache_key。

**Validation**：

```sh
moon test examples/markdown_editor/app --target native   # 378 passed
moon test moui_richtext --target native                  # 105 passed
moon test moui/runtime --target native                   # 35 passed
```

518 个测试全过。仍然建议运行 `scripts/macos-skia-renderer-smoke.sh --run-markdown-smoke`
做真实滚动顺滑度手动 smoke。

## Follow-Up Update 2 (2026-06-28，runtime paint_revision 修复)

**背景**：Follow-Up Update 的回退（去掉 cache_key/content_revision 的 origin，保留
facade.mbt revision 加 scroll_y）上线后用户反馈"反而更卡了"。

**根因重新定位**：深入调查 `ErasedViewNode::reconcile_dirty_kind`
（`moui/runtime/erased_view_node_ops.mbt`）发现，revision 字符串变化**必然触发
`ReconcileLayout`**（`mark_layout()` + `clear_cached_layout_and_paint()`），不是只触发
paint。runtime 的 `ReconcileDirtyKind` 枚举有 `ReconcileClean`/`ReconcilePaint`/
`ReconcileLayout` 三档，但 `reconcile_dirty_kind` 从不返回 `ReconcilePaint`——
`ReconcilePaint` 分支在 `apply_reconcile_dirty` 中已实现（`mark_paint()` +
`render_cache.clear()`，不清 layout cache），但无路径产生。

这意味着 facade.mbt revision 加 scroll_y 后，每一帧滚动都触发：
1. `mark_layout()` → `needs_layout=true` → layout 函数重新执行
2. `clear_cached_layout_and_paint()` → layout cache + render cache 全清
3. paint 函数重新执行（必要，但要拿新 scroll_y）
4. 即使 layer cache 命中（cache_key 不含 origin），paint_commands 仍被重新生成

layout 重新执行 + 缓存全清 + paint 重算 = 每帧滚动都付全量代价，所以比修复 1 更卡。

**修复方案**：给 `View::node` 增加可选 `paint_revision` 参数（默认 `() => ""`），
与 `revision` 分开。`paint_revision` 变化只触发 `ReconcilePaint`，不触发
`ReconcileLayout`。markdown_editor 把 scroll_y 从 `revision` 移到 `paint_revision`。

**修改清单**：

| 文件 | 改动 |
|---|---|
| `moui/core/view_protocol.mbt` | `ViewNode` 结构增加 `paint_revision_fn`；`ViewNode::new` 增加 `paint_revision?` 参数；`ViewNode::paint_revision` getter；`View::node` 增加 `paint_revision?` 参数；`View::paint_revision` getter；`ViewNode::map` 传入 `paint_revision` |
| `moui/runtime/view_tree.mbt` | `ErasedViewNode` 结构增加 `paint_revision : String` 字段 |
| `moui/runtime/erased_view_node_ops.mbt` | `reconcile_dirty_kind` 增加 paint_revision 比较：revision 变了→`ReconcileLayout`；revision 没变但 paint_revision 变了→`ReconcilePaint`；都没变→`ReconcileClean`。paint_revision 为空串（默认）时不参与判断，保持现有 revision-only 语义。`empty_erased_view_node` 加 `paint_revision: ""` |
| `moui/runtime/view_runtime_erased_view_node.mbt` | `erase_view_for_runtime` 加 `paint_revision: view.paint_revision()` |
| `moui_richtext/facade.mbt` | `controlled_markdown_session_editor` 的 scroll_y 从 `revision` 移到 `paint_revision`；`revision` 去掉末尾的 `markdown_session_current_scroll_y(...)` |
| `moui/core/pkg.generated.mbti` | `moon info` 重新生成，`View::node` 签名增加 `paint_revision?`，新增 `View::paint_revision` |

**修复后的滚动时序**：

1. `scroll_y` 变化 → `paint_revision` 字符串变化 → `reconcile_dirty_kind` 返回
   `ReconcilePaint`（revision 没变）
2. `apply_reconcile_dirty(ReconcilePaint)` → `mark_paint()` + `render_cache.clear()`
   （**不清 layout cache，不 mark_layout**）
3. layout cache 命中 → layout 函数**不重新执行**（revision 没变，needs_layout=false）
4. render cache 已清 → paint 函数重新执行 → 拿到新 scroll_y → block frame 以新 origin 重算
5. `ViewPaintLayer::new(frame=新 origin, cache_key=不含 origin, content_revision=不含 origin)`
6. runtime `has_current_cached_layer` 比对 key+revision → **命中**（都不含 origin，content 没变）
7. `DrawCachedLayer(spec)` → renderer `draw_cached_layer_pixmap(pixmap, spec.frame)`
   → 用新 origin 把缓存的 pixmap 贴到新位置

与 Follow-Up Update 回退方案的差异：**layout 不重算、layout cache 不清**。
仅 paint 重算 + render cache 清 + layer cache 命中贴图。

**reconcile_dirty_kind 新逻辑**：

```moonbit
let layout_clean = self.revision != "" && self.revision == next.revision
if !layout_clean {
  return ReconcileLayout
}
if self.paint_revision != "" && self.paint_revision != next.paint_revision {
  return ReconcilePaint
}
ReconcileClean
```

- 不使用 paint_revision 的 producer（默认空串）：行为与改动前完全一致
- 使用 paint_revision 的 producer：paint_revision 变化只触发 paint dirty

**向后兼容性**：`paint_revision` 是可选参数（默认 `() => ""`），所有现有
`View::node` 调用者无需修改。API surface guard、maintenance baseline、smoke check
全部通过。

**Validation**：

```sh
moon test examples/markdown_editor/app --target native   # 378 passed
moon test moui_richtext --target native                  # 105 passed
moon test moui/runtime --target native                    # 35 passed
node scripts/validate-api-surface.mjs                    # ok
node scripts/validate-maintenance-baseline.mjs            # ok
node scripts/smoke-check.mjs --check                     # ok (4 suites)
```

**Discoveries 补充**：

- **`ReconcileDirtyKind` 三档但只用两档**：runtime 已有 `ReconcilePaint` 枚举和
  `apply_reconcile_dirty` 实现，但 `reconcile_dirty_kind` 从不返回它。本次修复
  启用了这个已有但闲置的代码路径。
- **revision 变化的代价远高于预期**：不是只触发 paint 重算，而是触发 layout
  重算 + layout/render cache 全清。对于"只影响 paint 不影响 layout"的状态变化，
  应使用 `paint_revision` 而非 `revision`。
- **markdown_editor 的 layout 函数不依赖 scroll_y**：layout 只返回
  `ctx.constraints.constrain(size)`，与 scroll_y 无关。所以 scroll_y 变化
  不需要触发 layout dirty，用 `paint_revision` 是正确的。
