# Mo Workbench 消息列表窗口化与重建优化

Status: active
Created: 2026-06 (session)
Related: `examples/mo_workbench/app`

## 问题

mo_workbench 对话一多就卡。根因(见会话分析):

1. **主因**:`code_message_list`(`view_code.mbt`)每帧遍历 `model.messages` 全量构建每条消息的 view;每条消息经 `chat_message_body` → `chat_message_display_lines`(`view_message_body.mbt`)逐字符换行,并构造大量 `@views.text` 节点。MoUI 是立即式 view(TEA 每帧重建树),view 构建成本随"消息总数 × 字符数"线性增长,与渲染端 dirty 缓存无关。
2. **侧栏放大器**:流式 chunk 和消息滚动原本也会在 shell 层全量重建 `task_tree`,让每次中心交互都重新构造所有会话行。
3. 配套:流式 chunk 每次 `Array::copy(messages)`(O(n) memcpy)与 `existing + chunk`(O(n²) 字符串,但 n=单条消息字符数)——量级核算见下,非卡顿来源。

## 方案

### 阶段 1:换行结果 memo(纯 app 层)

`chat_message_display_lines` 增加模块级缓存(结果数组按 `(text length, width, font_size)` 哈希桶命中,桶内完整比较文本,容量上限 384, FIFO 淘汰)。**换行算法输出不变**(`workbench_wbtest.mbt:195-205` 断言具体换行结果)。memo 收益:非流式消息的换行不再每帧重算(流式最后一条内容变化必然 miss,接受)。

### 阶段 2:消息列表窗口化(纯 app 层)

`code_message_list` 只构建可视窗口 ± overscan 内的消息行,窗口外用等高空 `@views.spacer` 占位:

- 新增 `message_row_height(msg, theme, width)`:按消息类型由"换行行数 × 行高 + padding 常量"推导;与 `view_messages.mbt` 布局公式共享常量(badge 默认高 24、padding 14/12/8/4、spacing 4/6、行高 `max(size+7, 20)`)。
- 新增 `code_visible_window(heights, spacing, total, offset, viewport) -> (first, last)`:由 `model.scroll_offset.y` 定位可视区 `[offset, offset+viewport]`,前缀高度累加求 index,上下 overscan 12 条,钳制到 `[0, n)`。`offset=1e9`(scroll_to_latest)直接取末尾窗口。
- 窗口外占位:`@views.spacer(min_length=prefix_height, weight=0)` / 底部同理;list 仍 `spacing=4.0`。
- 消息行加稳定 key:`View::key("msg-" + 全局下标)`——窗口滚动时相同全局下标消息节点复用,reconcile 缓存命中。
- **外层结构不变**:`code_message_list` 仍返回 `padding_edges(scroll_view(...))`(`workbench_wbtest.mbt:66-83` 断言 children[0] 是 scroll)。
- 高度估算与真实布局的微小偏差由 overscan 吸收;滚动位置由 scroll_view 按真实内容 clamp,`follow_latest` 不受影响。

### 阶段 3:侧栏窗口化与事件降频

`task_tree_view` 将文件夹和任务叶子扁平化,只挂载可视区前后 6 行,窗口外用 spacer 保持真实滚动高度;任务行使用稳定 key。`WorkbenchModel` 单独持有侧栏 offset,滚动只更新 offset。

`sync_task_tree` 仅由会话列表/活动会话/会话元数据/重建/终止和会话生命周期命令触发;消息滚动、流式 chunk、进度提示等不再重建整个侧栏。

消息行高度也按同一 `messages` 数组做快照,普通滚动复用全部高度,流式更新只重算变化尾部。

### 配套(字符串 O(n²) / Array::copy)——评估后不改

- `Array::copy`:100 条消息 ≈ 800B memcpy,亚微秒,非瓶颈。
- `existing + chunk`:n=单条消息字符数(典型 1 万字符 × 3000 chunk ≈ 30MB 累计,摊 3000 帧每帧微秒级),非瓶颈。
- `workbench_wbtest.mbt:345-362` 要求 messages 每 chunk 反映完整内容;分段缓冲+延迟 join 会破坏该产品语义,且消息内容更新无法低于 O(n)/chunk。
- 结论:不做结构改动,避免引入复杂度与风险;真实成本集中于阶段 1/2。

## 验证

- 新增 wbtest:`message_row_height` 与行数一致;`code_visible_window` 顶部/中部/末尾/超滚;memo 命中返回相同结果。
- `moon test examples/mo_workbench/app --target native` 全绿。
- `moon check examples/mo_workbench/macos_skia --target native` 通过。

## 实施记录:流式渲染节流(第二轮,窗口化后仍卡的原因)

窗口化后"历史消息全量重建"已消除,但**流式输出时仍卡**:流式最后一条消息每帧内容增长 → declaration 变 → 每帧重新逐字符换行 + 逐行 Skia measure,成本 O(当前回复长度),与历史消息数无关,窗口化无法覆盖。

修复(`view_message_body.mbt` 的 `throttled_assistant_message` + `view_code.mbt` 接入):

- 模块级 `StreamRenderSnapshot` 缓存"上次实际渲染的内容快照";内容增量 < 48 字符时复用旧快照(显示滞后 1-2 行,视觉无感)。
- 旧快照换行结果在 `chat_message_display_lines` memo 中命中、text 节点 declaration 不变 → runtime measure 缓存命中 → 流式消息每帧成本 O(1)。
- 节流仅作用于 `is_streaming` 时窗口内最后一条 Assistant;`message_key` 用 `last_assistant_message_id` 防跨 rebuild 误用。
- memo 查找使用 O(1) 长度/宽度/字号桶定位,再做 `char_length` 与完整文本校验,减少长文本比较。
- 新增测试:快照复用/刷新/key 切换(73/73 通过,含 wasm-gc)。
