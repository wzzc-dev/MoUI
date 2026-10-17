# AI World

一个以文字对话为核心的 **AI 世界引擎**：整个数据库就是你硬盘上的一个
**文件夹**，每个世界是库里的一个子文件夹、由几个 Markdown 文件组成。
你可以在界面里新建世界、设定人物、和角色以文字对话；配上一个
OpenAI 兼容的模型端点后，还能让 AI 从一句话生成整个世界的图文设定。

Web 是主演示面（wasm-gc + WebGPU）；macOS Skia 是原生路线。

## 运行（Web）

```sh
# 仓库根目录（本示例是 moon.work 成员，直接解析工作区框架）
moon build examples/ai_world/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
# 打开 http://127.0.0.1:8080/examples/ai_world/web_wasm/index.html
```

要求支持 WebGPU 的 Chromium 系浏览器（无 WebGPU 时共享运行时会退到
Canvas2D 渲染）。macOS 原生：`moon run examples/ai_world/macos_skia --target native`。

## 第一次使用

1. **选择世界库**——选一个文件夹作为世界库（浏览器支持目录句柄时直接授权；
   否则退到页面内等价的库存储，键为 `ai_world_library_v1`）。
2. **新建世界**——起个名字，程序在库里建出模板文件夹并落盘。
3. **设定人物**——名字 + 人设（必填），外貌/说话方式/目标/秘密可选；
   创建后角色立即进入世界，点选即可对话。
4. **模型**——右上角「⚙ 设置」进入设置页，填 OpenAI 兼容端点、模型名与
   API key、温度与**上下文规模**（紧凑/标准/宽裕——影响历史保留量与记忆
   压缩频率）；「保存设置」把配置以 JSON 写到世界库根目录的 `config.json`
   （key 存在你自己选择的数据文件夹里，随世界库走）。刷新后设置自动恢复。
   没有完整配置时对话走**本地剧本回复**，世界离线可玩。
   对话超出预算时，最老的片段会自动压写成「此前」记忆笔记随请求携带；
   遇到值得长期记住的事，AI 会递交**记忆草稿**，由你采纳进世界书。
5. **AI 生成世界**——一句话设定（例如「雨夜江南小镇的当铺」）交给模型，
   生成背景叙述、人物卡、世界书与地图地点，写入当前世界文件夹。

## 数据库：一个文件夹，多个 Markdown

```
<世界库>/
  <世界名>/
    world.md            # H1 世界名，背景叙述（自由 Markdown），可选 `## 地点`
    characters/<角色名>.md   # 一人一卡：## 人设/外貌/说话方式/目标/秘密/位置
    world_book.md       # 触发条目：- 关键词 | 另一个: 命中后注入上下文的内容
    conversations.json  # 对话簿（每角色一段，user/assistant 角色）
    events.json         # 事件日志，最新在前
```

- 这些文件**就是**数据库：任何编辑器改完，重新打开世界即生效。
- 解析全部容错：单个文件坏了只降级该文件并给出事件提示；缺 `world.md`
  或无 H1 名字的文件夹不被当作世界；指向已不存在角色的对话单独丢弃并提示。
- 所有世界改动（新建、新角色、AI 生成）都即时写回文件夹；每次发送与回复
  都会把对话簿和事件日志以 JSON 提交进世界文件夹（`journal.mbt`）。
- `world.md` 的 H1 是世界名，文件夹名是库里的条目名；`场景地点` 行格式为
  `- 名称: x=.. y=.. w=.. h=..`（地图逻辑坐标 0..640 × 0..420）。

## 架构

| 部分 | 位置 |
|---|---|
| 世界/角色/世界书（纯数据 + Markdown codec） | `app/world_store.mbt`、`app/scenario.mbt`、`app/scenario_codec.mbt` |
| 对话与事件日志的 JSON 落盘（conversations.json / events.json） | `app/journal.mbt` |
| 提示词组装（预算内截取、世界书命中注入） | `app/context.mbt` |
| 对话簿（按角色封顶的历史） | `app/conversation.mbt` |
| 请求构造与回复解析（纯函数） | `app/llm.mbt` |
| 模型设置页（`config.json` 读写） | `app/view.mbt`（`settings_view`）、`app/update.mbt`（settings 分支） |
| 世界管理/人物创建/AI 生成/消息循环 | `app/update.mbt`、`app/generate_world.mbt`、`app/character_creator.mbt` |
| 无 key 本地剧本回复 | `app/local_reply.mbt` |
| 上下文预算/记忆压缩/长期记忆提议 | `app/context.mbt`（plan_messages·压缩触发·提议提示词）、`app/update.mbt`（SummaryArrived/MemoryProposals/Accept） |
| 三栏产品界面（居中内容块；输入框钉在底边） | `app/view.mbt`、`app/render.mbt` |
| Web 传输与文件桥（wasm-gc） | `llm_web/bridge.mbt` + `web_wasm/index.html` 内联 `ai_world_host` |
| 原生传输与文件 worker | `llm_native/worker.mbt` + `macos_skia/main.mbt` |

注入契约与宿主边界：共享 `app` 包是纯 TEA 包——`TurnRunner`（provider
请求）与 `WorldHost`（库列表/读世界/写世界）都由平台入口注入，`update`
只准备请求、消费类型化结果，网络或写盘失败永远只是事件面板里的一条
提示，不会破坏世界。Web 上字符串按 `begin_create_string`/`begin_read_string`
握手过界，完成经导出的 `ai_llm_complete`/`ai_fs_complete` 回到 wasm
（与剪贴板异步回调同款协议）；不支持目录句柄的浏览器退到页面内等价库。
原生侧复用 `moonbitlang/async` 的 worker 队列模式，世界库默认在
`./ai_world_library`，「选择世界库」会打开 macOS 目录选择框并即时切换库根。

## 测试

```sh
moon test examples/ai_world/app --target native    # 78 项：codec 往返、容错、
                                                   # 创建/回复两路、设置入库、
                                                   # 日志 JSON 落盘与恢复、AI 生成容错、
                                                   # 记忆压缩与长期记忆提议
moon test examples/ai_world/render_check --target native   # 3 项：地图绘制坐标契约
moon build examples/ai_world/web_wasm --target wasm-gc
```

调试小技巧：`?renderer=2d` 强制 Canvas2D 渲染（其画布可被脚本读取，适合自动化目验）。

## 路线

见 `docs/plans/active/ai-world-engine.md`：已完成文件夹数据库、人物创建、
双回复路径、Web 优先运行、AI 生成世界与对话/事件日志的 JSON 落盘；
下一步是图片背景（立绘/场景图）与更丰富的世界事件。
