# Plan: AI World — 从示例到产品，并毕业为子模块

- **Status**: active
- **Goal**: 把 `examples/ai_world` 从「技术上闭环的示例」推进为**可用的本地优先
  AI 叙事工具**，补齐立绘与同类产品已被验证的成熟能力，最后按
  `moui-studio-standalone-subrepo` 的先例毕业为独立仓库 + submodule。
  共享 `app` 包继续保持纯 TEA；平台入口保持薄。
- **Non-goals**: 多人联机、语音、本地模型推理（llama.cpp/onnx）、自建后端、
  框架 invariant 改动。任何新能力先落在 `app` 与 app-private 包里，证明可复用
  再上提到框架。

## 定位（本计划的前提）

三个候选定位中选 **B：本地优先的 AI 叙事工具**，用 A 的方式交付：

- **A（框架参考实现）**：已由 Showcase / mo_desktop 承担，第四个演示边际价值低。
- **B（本地优先叙事工具）**：`世界 = 文件夹` 是唯一别人抄不走的差异点，且
  缺口全是小工程。**本计划兑现这一条。**
- **C（自主世界模拟）**：需要新的时间/关系/在场模型，风险高；只在阶段三做
  最小验证，不承诺完整模拟。

## 现状基线（2026-10-17 审计后）

| 项 | 事实 |
|---|---|
| 代码 | `app` 约 4,400 行实现 + 1,957 行测试（88 项），4 个平台/桥接包 |
| 请求链路 | 完整消息数组（人设 → 摘要 → 世界书 → 历史 → 本轮） |
| 持久化 | 每个世界一个文件夹：`world.md` + `characters/*.md` + `world_book.md` + `conversations.json` + `events.json` |
| 编辑能力 | **无**重生成 / 无编辑历史 / 无清空对话 / 无导出导入 |
| 在场模型 | `selected : String?`——一次只能与一个角色私聊 |
| 世界推进 | **无** tick / 无时间 / 无自主事件 |
| Web 授权 | `rootHandle` 只在内存，**刷新即丢** |
| 写入粒度 | 每轮对话全量重写世界文件夹；localStorage 回退每次重写整个库 |
| 展示状态 | `catalog.json` 里 `featured: false`；`resource/screenshots/` **无截图**；plan acceptance 全未勾 |

## 目标阶梯

### 阶段〇：已完成的正确性修复（2026-10-17）

历史入请求、journal 回读、Web boot 队列字符串生命周期、草稿保护、发送门控、
文件夹名清洗、API key 不落盘、TEA 纯度、死消息闸门覆盖。详见
[ai-world-engine](ai-world-engine.md) 的 Progress 末行。

### 阶段一：兑现「文件夹即数据库」

这是**它配得上叫产品**的门槛，全部是小工程：

1. **目录句柄跨刷新**：`rootHandle` 落 IndexedDB（File System Access API 的
   标准做法），刷新后 `queryPermission` 静默恢复；权限被撤销时回落到选择态而
   不是丢掉库。
2. **增量写入**：`commit_files` 改为只提交变更文件；对话按角色拆
   `conversations/<角色>.json`（保留 `conversations.json` 作为旧格式迁移源）。
   localStorage 回退按世界分键，不再 `stringify` 整个库。
3. **导出 / 导入世界**：一个世界 = 一个可分享的文件夹（zip 或目录复制），
   含 `world.md` / 角色卡 / 世界书 / 立绘 / 日志。导出不带 `config.json`
   （那里面有端点，且 key 本就不写）。
4. **产品化收尾**：补 `resource/screenshots/ai_world.png`，`examples/catalog.json`
   置 `featured: true`，勾掉 `ai-world-engine` 的 acceptance。

**验收**：刷新浏览器后无需重新授权即可继续上次世界；改一个角色的某个字段
只写一个文件；导出的文件夹在另一台机器导入后世界、对话、立绘完整。

### 阶段二：补齐对话编辑能力（同类产品已验证的刚需）

对照市场，这个品类里决定「能不能长期用」的不是花哨功能，是**这四件**：

1. **重生成 / 候选切换（swipes）**：一条回复可有多个候选，左右切换选定。
   模型层需把 `Conversation.lines[i]` 从「单条」扩展为「一条 + 候选集」，
   这是本阶段唯一需要动的数据结构。
2. **编辑 / 删除 / 清空**：编辑任何一条历史（含玩家自己的），删除单条，
   清空某角色或整个世界的对话。
3. **世界书命中可视化**：现在 `world_book_for` 的注入对玩家不可见，玩家不知道
   角色为什么突然知道当铺的事。把「本轮命中了哪几条、注入了多少字」显示在
   对话旁，并可点开看原文。
4. **回复渲染增强**：用 `moui_richtext/markdown_viewer` 渲染角色回复里的
   Markdown（现在全部当纯文本，`*动作*` 和列表都糊成一行）。
   → 已落地：角色回复走 `@moui_richtext.markdown_viewer`，玩家的话保持原样。

**验收**：对一条不满意的回复重生成并切回原答案；编辑第 3 条历史后后续上下文
随之改变；能看清本轮注入了哪几条世界书。

### 阶段三：从「私聊」到「场景」+ 立绘

#### 3a. 人物立绘（本计划新增的产品面）

技术现状（已验证）：

- `@views.image(source, width, height, fit, corner_radius)` 存在，
  `mo_desktop` 已有用法先例。
- **Web**：canvas2d 与 WebGPU 都接受 `data:` / `blob:` 源（跨源时设
  `crossOrigin`）。
- **原生 Skia**：接受本地文件路径或 `data:` URI。
- **阻塞点**：`WorldHost::read_world` 目前返回纯文本
  `Array[(String, String)]`，**没有二进制通道**。

设计：

- 数据落盘：`characters/<角色名>.png` 与 `.md` 同目录；卡片用
  `portrait: <文件名>` 引用，**不把 base64 塞进 Markdown**（可读性优先）。
- 通道：`WorldHost` 增加 `read_binary(path) -> (ok, base64)` 或让 `read_world`
  对图片返回 base64 + 一个 `binary_paths` 标记；app 侧统一转 `data:` URI
  交给 `@views.image`。原生侧可直接给路径（省一次 base64）。
- 呈现：左侧名单头像（圆形裁切）+ 舞台立绘（`fit=Cover`）+ 地图标记可选
  使用头像。缺图时回落到现有 `character_color` 生成的色块首字。
- 生成：AI 生成世界时同时产出立绘**提示词**（不直接生成图，避免引入图像
  API 依赖），玩家可粘贴到任意绘图工具后把图片丢进文件夹。

#### 3b. 场景与多角色同场

- 新增 `Scene`：一组在场角色 + 地点 + 时间点。`selected` 保留（私聊），
  但增加「场景」页：把 2–3 个角色放进同一轮，模型看到的是**多方对话**，
  每条回复标注说话人。
- 这是让地图从装饰变成语义的关键：地图点地点 → 进入该地点的场景。

#### 3c. 世界推进（最小验证）

- 一个显式「推进时间」动作（不是后台 tick，避免无谓的 provider 花费）：
  玩家离开后点一次，生成一段「这段时间里世界发生了什么」的事件日志，
  可选写回 `world.md` 的时间线小节。
- **不做**自主循环 tick，除非 3b 验证后有明确收益。

### 毕业：独立子仓库

按 [moui-studio-standalone-subrepo](../done/moui-studio-standalone-subrepo.md) 先例：

- `git subtree split -P examples/ai_world` → 独立仓库 `wzzc-dev/ai_world`。
- 模块名 `examples/ai_world` → `wzzc-dev/ai_world`；子包 import 同步。
- 挂载为 `ai_world/` submodule（对齐 `moui_studio/`、`examples/momark`）。
- 同步：`moon.work`、`checks/profiles.json`、`checks/dead-message-catalog.json`、
  `examples/catalog.json`、`docs/examples.md`、`docs/markdown-editor.md` 式
  指针文档、`memories/repo/`。
- 毕业**前置条件**：阶段一、二完成 + 立绘完成 + 截图/featured 就位。

## 借鉴清单（同类产品的成熟件，只取与「本地优先 + 文件夹数据库」相容的）

| 来源 | 借鉴什么 | 不借鉴什么 |
|---|---|---|
| SillyTavern | 角色卡字段模型（本仓库已对齐）；Lorebook 的 priority / position / 递归深度 / 概率触发（**均已落地**，见 `app/lore.mbt`）；swipes 候选切换（已落地）；群聊（已落地为场景） | 插件生态、世界书 UI 的复杂度上限 |
| Character.AI | 开箱即用的创建向导（**已落地**：`creator_archetypes` 模板 + 一句话 AI 起草） | 云端托管、内容审核体系、订阅制、角色发现 |
| AI Dungeon / NovelAI | 故事模式的 do / say / story 三种输入意图（**已落地**，见 `InputIntent` + `frame_player_text`）；场景化多角色（已落地） | 纯续写、无世界持久化 |
| ChatGPT / Claude | 重生成（已落地）、编辑单条消息（已落地）、分支对话（**已落地**：分叉落成同级文件 `角色~N.json`，名单里可达，原对话不动） | 通用助手形态 |
| Replika | 关系/长期记忆的可见化（记忆草稿面板 + `lore_summary` 的世界书命中提示） | 拟人化外观 |

**取舍原则**：只吸收能落在「文件夹里的文件」上的能力。任何需要服务端状态、
账号体系或插件运行时的特性一律不做——那会毁掉唯一的差异点。

## 验收

- [x] 刷新浏览器免重授权；增量写入只动变更文件。
- [x] 世界可导出为一个 `.aiworld.json`，在另一台机器导入后世界/对话完整；
      **立绘也随包**（`bundle.mbt` 的 `is_world_file_name(path) ||
      is_portrait_file_name(path)`，立绘本来就是以 base64 过桥的形态）。
      导入端只接受世界文件与立绘，且拒绝含 `..` 的路径，避免 bundle 越出世界目录。
- [x] 重生成、候选切换、编辑、删除、清空对话均可用且有测试。
- [x] 世界书命中在 UI 可见。
- [x] 角色立绘与缺图回落**在 Web 路已按渲染命令验证**：`characters/<名>.png`
      经 base64 过桥、`portrait_data_uri` 转 `data:` URI、最终成为带
      `data:image/png;base64,` 前缀的 `DrawImage`；无立绘时图像命令为 0 而文本
      照常绘制（`render_check/portrait_probe.mbt`，并做过反向验证）。
      **macOS 路只做到代码审查 + 构建通过**：`macos_skia/main.mbt` 用
      `@fs.read_file(...).binary()` + `@app.base64_encode` 读同名资产，与 Web
      宿主同构；但该入口是交互式窗口，本环境无法驱动，**未在真实窗口内目视确认**。
      这是一条明确的验证边界，不是"两路都验证过"。
- [x] 场景模式可让 2–3 个角色同场对话，回复标注说话人。
- [x] 「推进时间」生成事件日志（最小验证，非循环 tick）。
- [x] 截图与 `featured: true` 就位（`resource/screenshots/ai_world.png`）；`docs/examples.md` 描述待毕业时统一更新。
- [x] 全部静态校验器与 `pr` profile 绿（`ai_world` 的测试/渲染契约/Web 构建已注册进 `pr`，
      `moon.work`、`dead-message-catalog`、`catalog.json`、截图、featured 就位）。
- [x] 毕业的**机械部分已验证**：`git subtree split -P examples/ai_world` 成功
      产出独立历史（`5c6c728a`，47 个文件，`README.md` 在根、`app/` 在下一层），
      即"这个示例能被干净地抽成独立仓库"成立。runbook 见下方。
- [ ] 毕业为 `wzzc-dev/ai_world` submodule —— **两个阻塞**：
      1. **远端仓库不存在**：`git ls-remote git@github.com:wzzc-dev/ai_world.git`
         → `Repository not found`（https 同样）。按 `moui-studio-standalone-subrepo`
         先例，这是明确的人工步骤。
      2. **示例依赖未发布的 `moui` API**。已精确到单个函数（第 30 轮复查）：
         registry 上最新是 `wzzc-dev/moui@0.2.3`，其 `views/text` 的 `text()`
         签名为 `(text, role?, theme?, width?, height?, align?)`——**没有 `wrap`**；
         而工作区 `./moui` 里 `text(wrap? : Bool = false)` 存在且已提交在
         `80b332cd1`。对照检查：`wzzc-dev/moui_richtext@0.2.1`（已发布）**有**
         `markdown_viewer(... key?)`，所以富文本那条链没问题，唯一缺口就是 `wrap`。
         影响面：`view.mbt` 的 `wrapped_body`/`wrapped_caption` 两个 helper、
         共 19 处调用。**不建议**为了毕业去掉 `wrap`——它承担真实的中日韩段落换行，
         删掉是产品退化。正确顺序是先发布 `moui`（升版本 + 同步
         `examples/ai_world/moon.mod`），再毕业。

      两件事都不是示例内的代码缺陷，因此在仓库与发布就绪前不擅自改
      `moon.work`/`.gitmodules`/版本号——那会留下半毕业或半发布的坏状态。

      **第 39 轮复核的毕业就绪度**（下一个接手的人按这三条走即可）：

      1. **必须先提交**。当前 `git status` 下 `examples/ai_world` 有 **18 个未跟踪文件**
         （`conversation_view.mbt`、`editing.mbt`、`library.mbt`、11 个护栏测试、
         3 个 render_check 探针）和 28 个已修改文件。`git subtree split` 只遍历
         提交历史，不提交就毕业会**丢掉整个应用核心**，而脚本照样报成功。
         `scripts/graduate-ai-world.sh` 现在会在这种情况明确说明这个后果。
      2. **创建远端仓库**：`https://github.com/new` → owner `wzzc-dev`、name `ai_world`，
         空仓库（不要 README、不要 .gitignore）。
      3. **发布 `moui`**：先在 `moui/moon.mod` 升版本、发布，再把
         `examples/ai_world/moon.mod` 的 `wzzc-dev/moui@0.2.3` 改成新版本。
         脚本会打印 `note: 3 use(s) of text(wrap=true); needs a moui newer than 0.2.3`。

      三条就绪后直接跑 `./scripts/graduate-ai-world.sh`（可先 `--dry-run`），
      脚本自己完成 7 步并做"独立仓库能否编译"的检查。

## Decision log

| Date | Decision |
|---|---|
| 2026-10-17 | 定位选 B（本地优先叙事工具），按 A 的纯度交付；C 只在阶段三做最小验证。 |
| 2026-10-17 | 立绘走「同目录图片文件 + 卡片引用」，不把 base64 写进 Markdown；需要给 `WorldHost` 增加二进制通道。 |
| 2026-10-17 | 世界推进做成显式动作而非后台 tick：provider 调用要花钱，不该由时钟触发。 |
| 2026-10-17 | 借鉴范围限定为「能落在文件上」的能力；服务端/账号/插件运行时一律不做。 |

## Progress

| Date | Note |
|---|---|
| 2026-10-17 | 计划起草。前置的正确性修复（历史入请求、journal 回读、boot 队列、草稿保护、发送门控、路径清洗、key 不落盘、TEA 纯度、死消息闸门）已完成，app 测试 88 项。 |
| 2026-10-17 | 阶段一落地。**存储**：`rootHandle` 存 IndexedDB（`ai_world_handles`），首个 listing 静默恢复；权限判定抽成纯函数 `permissionAllowsRestore`（只认 `granted`/无 API；`prompt`/`denied` 一律不认并清掉陈旧记录）。**增量写入**：新增 `CommitScope{World, Conversation(id)}`，一轮对话只写 `conversations/<角色>.json` + `events.json`；世界级改动才写 Markdown 与世界书，并写 `conversations/_index.json` 记录本世界拥有哪些对话文件（避免同名世界继承旧历史）。**legacy 兼容**：老的单文件 `conversations.json` 继续读，读取时按角色合并（新格式优先）；页面内回退库从单键 `ai_world_library_v1` 迁到按世界分键 `ai_world_world_v1:<世界>`，读到旧键会惰性迁移并清空旧副本。**导入导出**：`bundle.mbt` 定义 `moui.ai-world/1`（`{"format","name","files"}`），解码侧只收 `is_world_file_name` 且拒绝 `..`，名字过 `world_folder_name`；两端宿主都实现（Web 用 `showSaveFilePicker`/`showOpenFilePicker` + 下载回退，原生走 `HostFileDialogKind::SaveFile/OpenFile` 且对话框在主线程、只有写盘进 worker）；导入永不覆盖已有世界（`名字 (2)`）。**收尾**：补 `resource/screenshots/ai_world.png`（1412×800 真实渲染）、catalog `featured: true`、`ai-world-engine` 的 6 条 acceptance 全部勾选。**验证**：app 测试 88→94（bundle 往返/篡改拒绝/路径穿越/名字清洗/导入上舞台），浏览器实测按世界分键、legacy 迁移、handle store→recall→restore 全链路。**过程中修掉的真实缺陷**：`restoreHandle` 里多余的 `showDirectoryPicker` 前置判断会让已存句柄永远无法恢复（自动化下暴露）。 |
| 2026-10-17 | 阶段二落地。**swipe 模型**：`ChatLine` 增加 `alternatives`/`selected`，逻辑候选列表为 `candidate_slots()`（索引 0 是初版），`with_alternative` 把旧回复收进候选、新回复成为当前选中；`with_candidate` 在切换时重建 `alternatives` 以保持「选中项不在候选里」的不变量（第一版实现破坏了这条，导致编辑第二个候选时写不进去——被测试抓到）。**编辑**：`RegenerateReply`（无 key 时确定性换版，有 key 时走同一 `TurnRunner` 且请求的是"去掉最后一条回复后的历史"）、`Regenerated`、`SwipeReply(行, 方向)`（循环切换）、`EditLine`/`EditLineChanged`/`EditLineCommit`/`EditLineCancel`（就地编辑，空白拒绝）、`DeleteLine`、`ClearConversation`；编辑状态 `editing_line`/`edit_buffer` 只存在于模型、提交才写盘。**持久化**：候选随 `conversations/<角色>.json` 落盘（`alternatives` + `selected`），手改坏的 `selected` 钳到 0。**可见性**：`lore_hint` 在对话尾部显示本轮注入的世界书关键词；角色回复改走 `@moui_richtext.markdown_viewer`（app 包新增 `moui_richtext` 依赖，符合 addon 依赖政策）。**验证**：app 测试 94→105（新增 `editing_wbtest.mbt` 11 项：候选往返/循环/越界惰性/编辑单候选/删除/清空/落盘/坏索引回退/lore 提示）；浏览器实测重生成→`1/2`→切回原文→就地编辑全链路通过，Markdown 加粗与列表真实渲染。 |
| 2026-10-17 | 阶段三 a（立绘）落地。**模型**：`CharacterCard` 增加 `portrait`（卡片里只存文件名，字节不进 Markdown），Markdown 段落名 `## 立绘`，JSON codec 同步。**二进制通道**：`WorldFiles` 增加 `portraits : Array[(String, String)]`（文件名 + base64），`is_portrait_file_name`（png/jpg/jpeg/webp，大小写不敏感）；Web 宿主用 `arrayBuffer` + 手写 base64，原生宿主用 `@fs.read_file(...).binary()` + app 侧 `base64_encode`（新增 `app/portrait.mbt`，含标准向量测试与容错解码）；`portrait_uri` 把字节转成 `data:` URI 交给 `@views.image`。**呈现**：名单 30px 圆头像、舞台 40px 方头像，缺图回落 `character_color` 色块 + 名字首字（`avatar` 助手）。**导出**：bundle 的准入规则扩到图片，世界发给朋友时带脸；导入同样恢复立绘。**验证**：app 测试 105→111（base64 三种 padding/规范向量/坏输入、URL 解析与回落、卡片 Markdown 往返、扩展名识别、bundle 携带立绘）；浏览器实测真实 PNG 在名单与舞台同时渲染，无立绘角色显示色块首字。 |
| 2026-10-17 | 阶段三 b/c 落地。**场景**：`app/scene.mbt` — `scene_key("scene:<地点>")` 复用 `ConversationBook`（不新造存储格式），`cast_at` 按 `location` 或矩形包含判定在场，`build_scene_prompt` 把房间、在场众人（含"（你）"标记）与"不要替其他角色发言"写进系统提示，`responder_for` 先按名字匹配再轮转（不额外花一次 provider 调用）。**turn 分流**：`Send` 按 `scene_location` 走 `send_scene_turn` / `send_private_turn`，私聊逻辑原样抽成函数；场景回复走新 `SceneReply(场景 key, 回应者 id, 文本)`，行内 `Speaker::Character(回应者)` 保证多声部正确归属（**离线分支原先错误地把回复记在场景 key 上，被测试抓到后改为 `append_scene_reply`**）。**UI**：左侧地点有 ≥2 人时出现「场景 · 地点（N）」chip，地图点地点进场景、点人进私聊（`location_at` + 顺序保证人优先），场景面板有在场头像条、逐行标注说话人、独立 composer。**时间推进**：`AdvanceTime` 显式按钮（不是后台 tick），`advance_time_prompt` 写出地点/在场；无 key 时仍写一条确定性事件；`time_advanced_event` 把回复裁到 240 字并以「（这段时间）」前缀落进事件日志。**验证**：app 测试 111→123（新增 `scene_wbtest.mbt` 12 项：在场判定/回应者匹配与轮转/进场景与空地点拒绝/场景 turn 不污染私聊/提示词内容/回复归属/键不冲突/地图命中顺序/离线推进/带 key 推进/提示词/裁剪）；浏览器实测场景 chip、进入场景、场景发言、推进时间全链路通过，截图确认在场头像条与"2 人在场"。 |
| 2026-10-18 | 阶段三 b/c 收尾与「毕业」评估。**拆分**：`update.mbt` 涨到 1869 行，触发 `validate-maintenance-baseline` 的 1800 行预算，把两个 turn 流水线（`send_private_turn` / `send_scene_turn`）拆到 `app/turn.mbt`（1649 + 233 行），预算闸门恢复绿——按"可读的消息 switch"而不是给文件加豁免。**毕业**：`git subtree split -P examples/ai_world` 实测成功（`5c6c728a`，47 文件，目录层级正确），机械部分验证完毕；剩 `git ls-remote git@github.com:wzzc-dev/ai_world.git` → `Repository not found` 一个阻塞。按 studio 先例，远端仓库创建是人工步骤，因此写出可执行 runbook 并记阻塞，不擅自改 `moon.work`/`.gitmodules` 造成半毕业状态。**修正**：先前一度记录"`git subtree` 不可用"，实为探测方式错误（测的是 `--help` 而非子命令），已在 runbook 中更正。 |

## 毕业 runbook（人工前置：创建远端仓库）

**一键执行**：`scripts/graduate-ai-world.sh --dry-run` 先看步骤，
去掉 `--dry-run` 执行。脚本会自己检查两个前置条件（远端可达、工作树干净）
和第 6 步的「脱离工作区能否编译」，任一不满足就中止并说明原因，不会留下
半毕业状态。下面的步骤是它做的事，供人工复核。

前置条件已满足：阶段一/二/三全部落地，111+123 项测试、渲染契约、Web 构建、
7 个静态校验器与 `pr` profile 全绿，截图与 `featured: true` 就位。

**第 0 步（人工，必经）**：创建 GitHub 仓库 `wzzc-dev/ai_world`（空仓库，
不要初始化 README），并确认本机 `git ls-remote git@github.com:wzzc-dev/ai_world.git`
能读到。

**第 1 步：提交当前工作**。毕业是 git 历史操作，工作树必须先干净：

```sh
git add -A && git commit -m "feat(ai_world): local-first narrative tool (stages 1-3)"
```

**第 2 步：抽历史**。本机 `git subtree` 不可用时用 `filter-repo`：

```sh
# 首选（安装了 git-subtree 时）
git subtree split -P examples/ai_world -b ai-world-split

# 备选（git-filter-repo）
git filter-repo --path examples/ai_world --to-subdirectory-filter . --force
```

**第 3 步：推到新仓库**：

```sh
git remote add aiworld git@github.com:wzzc-dev/ai_world.git
git push aiworld ai-world-split:main     # subtree 方案
# 或 filter-repo 方案：在临时 clone 里 push main
```

**第 4 步：改模块名与内部依赖**（在新仓库里做）：

- `moon.mod`: `name = "examples/ai_world"` → `wzzc-dev/ai_world`。
- 子包 import：`"examples/ai_world/app"` → `"wzzc-dev/ai_world/app"`，
  `"examples/ai_world/llm_web"` / `llm_native` 同理。
- 仓库内 `README.md` 的相对截图路径改为本仓库自带资源。

**第 5 步：挂 submodule 回 MoUI**：

```sh
git rm -r examples/ai_world
git submodule add git@github.com:wzzc-dev/ai_world.git ai_world
```

**第 6 步：同步 MoUI 侧引用**（缺一不可，否则闸门会红）：

| 文件 | 改动 |
|---|---|
| `moon.work` | `"./examples/ai_world"` → `"./ai_world"` |
| `checks/profiles.json` | 三处 `examples/ai_world/...` → `ai_world/...` |
| `checks/dead-message-catalog.json` | `path`/`scanRoots` 改 `ai_world/app/msg.mbt` |
| `examples/catalog.json` | `path` → `ai_world`（`featured` 保持 true） |
| `docs/examples.md` | 表格行路径改 `ai_world/`，说明指向独立仓库 |
| `docs/plans/README.md` | `ai-world-engine` / `ai-world-product` 行标注「已毕业」 |
| `memories/repo/ai-world-web-host-bridge.md` | 路径全部改 `ai_world/...` |
| `docs/markdown-editor.md` 式指针文档 | 新增 `docs/ai-world.md` 指向独立仓库 |

**第 7 步：验证**：

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-release-module-closures.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/check-generated-interfaces.mjs
sh scripts/check.sh --profile pr
```

**已知障碍**：
1. 远端仓库尚未创建。
2. **示例依赖未发布的 `moui` API**。独立仓库从 registry 解析
   `wzzc-dev/moui@0.2.3`，其 `views/text` 的 `text()` 没有 `wrap` 参数，而
   工作区 `./moui` 有（已提交，但版本号仍是 0.2.3，即 registry 上那个）。
   所以第 6 步在干净 clone 里 `moon check app` 会失败。修复路径：
   发布当前 `moui` 并升版本 → 同步 `examples/ai_world/moon.mod`；或去掉示例
   对 `text(..., wrap=true)` 的依赖（`wrapped_body` / `wrapped_caption`）。

`git subtree` 在本机可用，`git subtree split -P examples/ai_world` 已实测产出
47 个文件的干净历史（`5c6c728a`），改名步骤也已验证残留旧引用为 0。
| 2026-10-18 | 借鉴清单里的 Lorebook 四项落地（原先只是大小写不敏感子串）。**模型**：`WorldEntry` 增加 `priority` / `position`（`Before`/`After`）/ `recursion` / `probability`，全部带默认值，旧文件的裸行不需要改。**语法**：修饰符写在关键词后、冒号前，`- 酒 | 花雕 [priority=10] [position=before] [recursion=2] [probability=60]: 内容`，顺序任意、大小写不敏感、未知项忽略、坏值夹紧（`probability` 0-100、负 `priority`/`recursion` 归 0），**永不因为修饰符写错而丢条目**；写回只输出非默认值，普通条目保持原来那一行的形状。**选取**：新增 `app/lore.mbt` — `select_lore` 先直接匹配、再按已注入内容重扫做链式触发（`lore_recursion_cap = 4` 防止手改 `[recursion=99]` 变成无界扫描），`lore_passes_probability` 用 `(entry, turn)` 的稳定哈希，**同一轮重试结果固定**，`sort_lore_hits` 按优先级降序且同级保持场景顺序。**接线**：`plan_messages` 把 `Before` 条目放在 `【世界规则】` 段（人设之前）、`After` 放在 `【相关背景】`（历史之前）；`local_reply` 与 UI 的 `lore_hint`/`lore_summary` 全部改用同一个 `select_lore`，所以离线回复、提示词、面板三者不会互相矛盾。**验证**：app 测试 123→135（新增 `lore_wbtest.mbt` 12 项：修饰符任意顺序/坏值夹紧/未知项忽略/未闭合括号当字面量/只写非默认值/优先级排序/位置分流/递归链与关闭递归/递归上限/概率同轮确定与跨轮分布/提示词置位/摘要/完整文件夹往返/probability=0 不进提示词）；浏览器实测带修饰符的世界书能载入并显示命中提示。 |
| 2026-10-18 | 借鉴清单里的 AI Dungeon 输入意图落地。新增 `InputIntent{Say, Do, Story}`（`app/conversation.mbt`，`marker`/`label`）与 `Msg::IntentChanged(Int)`；`WorldModel.intent` 是会话级 UI 状态。`frame_player_text`（`app/context.mbt`）只给**送给模型的那一句**加框：`Do` → `*动作*（请回应它的后果，不要当成对白回答）`，`Story` → `（旁白）…（请接着往下写）`，`Say` 原样。接线在 `turn.mbt` 的私聊路径：把 `plan.messages` 的最后一条替换为 framed 版本，而不是再追加一条（测试断言「推开门」在 wire 里只出现一次）。存档始终是玩家原样打的字，所以旧 journal 不受影响、也不需要迁移。UI 在输入框上方加 `说 / 做 / 旁白` segmented control。**验证**：app 测试 135→138（framing 三态/不改变存档/选择器映射与回落/Do 回合 wire 上带动作标记且不重复），浏览器实测三档控件可见。 |
| 2026-10-18 | 借鉴清单收尾两项。**创建向导（Character.AI）**：`creator_archetypes()` 四个模板（掌柜/旅人/官差/陌生人），`CharacterDraft::with_archetype` 只填空缺、**不覆盖玩家已打的名字与外貌**；`character_idea_prompt` + `parse_generated_character` 支持「一句话 → 整张卡」，解析容错（无 name/persona 即 `None`，被散文包住也能抠出 JSON）；无 key 时退回模板并明说，不假装生成。**分支对话（ChatGPT/Claude）**：解决了我最初担心的「与一个世界一份历史冲突」——分支落成**同级文件** `conversations/<角色>~2.json`（`branched_key`/`split_branch`），不是内存树，因此"世界=可读文件夹"的承诺不破；`BranchAt(行)` 复制到该行为止的历史、原对话不动；`character_name` 认识分支键（`林掌柜 · 分支 2`）。**UI 可达性**：第一版只加「分叉」按钮，分支建完却没有入口回去——等于死路；补了名单里角色下的 `↳ 分支 N（M 条）` 列表（按编号排序、可点选），这是本次自查抓到的一个真实用例缺口。**验证**：app 测试 138→154（新增 `wizard_wbtest.mbt` 9 项 + `editing_wbtest.mbt` 6 项分支测试：模板填充/不覆盖名字/越界惰性/无 key 退回/带 key 请求内容/起草合并/坏卡片忽略/直接创建；分支复制/连分两次编号/越界惰性/键拆分/命名/落盘往返）；浏览器实测模板填充、分叉、名单出现分支、分支可点选。 |
| 2026-10-18 | 线预算再触发一次（`update.mbt` 涨到 1813 行）。把「创建 + 生成」这一整块（ToggleCreator / CreatorChanged / CharacterCreated / UseArchetype / CharacterIdeaChanged / DraftCharacter / CharacterDrafted / WorldIdeaChanged / GenerateWorld / WorldGenerated）搬进 `app/creation.mbt`（`update_creation` 分发函数），`update.mbt` 只留逐条委托；`WorldNameChanged`/`NewWorld` 本就在原文件里，避免重复分支时把这两条排除掉了。结果 `update.mbt` 1557 行 + `creation.mbt` 297 行，预算闸门恢复绿。**过程记录**：MoonBit 的 or-pattern 不能跨不同载荷的变体绑定同一个名字，`A | B(_) as x` 会退化成不可达分支，所以委托时逐条写而不是合并。 |
| 2026-10-18 | 把「毕业」从 runbook 变成可执行脚本 `scripts/graduate-ai-world.sh`，并用本地 bare repo 完整彩排，**发现并修掉脚本自身两个问题、同时暴露一个真实的上游阻塞**。脚本修的两处：① `git subtree --help` 在已安装时也返回非零，改用 `$(git --exec-path)/git-subtree` 探测；② 模块改名原来只 grep `*.mbt/*.pkg/*.json`，漏掉 `README.md`、`web_wasm/index.html`、四个 `pkg.generated.mbti`，改成覆盖全部文本文件（彩排验证：改名后残留旧引用 0 个，之前是 6 个）。**新发现的上游阻塞**：独立仓库从 registry 解析 `moui@0.2.3`，其 `views/text` 的 `text()` 签名是 `(String, role?, theme?, width?, height?, align?)`——**没有 `wrap`**；而工作区 `./moui` 里 `text(wrap?=false)` 存在且已提交在 `80b332cd1`，`moui/moon.mod` 版本却仍是 `0.2.3`。也就是说工作区跑的是**未发布**的 MoUI。彩排到第 6 步时 `moon check app` 在干净 clone 里失败，脚本据此中止并给出两条修复路径（发布 moui 并升版本 / 去掉对未发布 API 的依赖）。另：`git submodule add` 对本地路径默认被 CVE-2022-39253 保护拦住，脚本对本地 remote 自动加 `-c protocol.file.allow=always`，真实 `git@github.com:` remote 不受影响。 |
| 2026-10-18 | 用一次性探针测试扫鲁棒性边界（空文件 / 20 万字单行 / 六种坏 JSON / 恶意世界名），发现并修掉一个真实缺陷：`world_folder_name` **没有长度上限**，500 字的 CJK 世界名会产出约 1500 字节的目录名，超过多数文件系统单段 255 字节上限，写入会以一个玩家无法处理的 "invalid argument" 失败。修法：`folder_name_max_bytes = 120`（给 `~N` 去重后缀和分隔符留余量），`utf8_width` 按真实 UTF-8 宽度计费——**按字节而非字符截断**，因为截在字符中间会产出非法 UTF-8、照样被拒；ASCII 不被过度截断（100 个 ASCII 字符仍是 100 字符）。探针其余结论：空 `world.md` → `parse_world_files` 返回 `None`（正确，没有名字就不算世界）；坏 JSON 不会让世界解析失败（按文件容错）；超长单行可正常入档。新增 2 项永久测试（长名上限 + 恶意名中和：路径穿越/控制字符/分隔符/`.`/`..`/前导点/全分隔符）。测试 154→156。 |
| 2026-10-18 | 写了跨特性接缝测试（`app/integrity_wbtest.mbt`，6 项），专门验证**后加的功能能否走通早先建的持久化/导出路径**——一次性抓到三个真实缺陷，都是阶段一之后才出现、既有测试覆盖不到的。① **立绘从不落盘**：`commit_files(model, World)` 只用 `scenario.world_files()`，而立绘字节在 `model.portraits` 里，结果导出的世界在另一台机器上每张脸都丢失（Markdown 里 `portrait:` 引用的文件不存在）。修法：World 作用域把 `portraits` 一起写进 `characters/`。② **场景在重载时被静默删除**（最严重）：`parse_world_files` 的「孤儿对话」规则要求 `conversation.character_id()` 必须是存在的角色，而场景键是 `scene:<地点>`，于是**每一次重载都丢掉全部多角色历史**。③ **分支同样被删**：分支键 `林掌柜~2` 也不是角色 id。②③ 一起修：场景键直接放行，分支键用 `split_branch` 解析回基角色再判定存活。验证：单元测试 156→162（6 项接缝测试全过），且**浏览器实测**——进入场景发言后刷新页面，场景内容仍在（修复前会被清空）。`conversation_path` 会把 `scene:吧台` 落成 `conversations/scene_吧台.json`（冒号被消毒成下划线），这点也写进了测试断言。 |
| 2026-10-18 | 接缝测试继续扩大到「写路径」，抓到第四个真实缺陷：**清空对话根本没有落盘**。`journal_files` 只在 `!lines.is_empty()` 时才写文件，而 `ClearConversation` 的结果正是空对话 —— 于是 scope 提交里只剩 `events.json`，磁盘上旧的 `conversations/林掌柜.json` 原封不动，**下次加载历史整个复活**（浏览器实测确认：清空后刷新，旧对话回来）。修法：空对话也要写（写一个空文档），因为 host 从不删文件，"已删除" 只能表达为"空文档"；World 作用域同样无条件写每个对话文件。加 3 项测试（清空后 scope 提交确实含该文件 + 重载为 0 行 / 逐条删除不复活 / World 提交包含空对话）。**另一次自我纠错**：我一度认为 `with_text` 保留 `alternatives` 是 bug（编辑后 swipe 仍显示 1/2），改成清空候选——结果打破了既有测试 `editing the shown candidate updates only that candidate`。读了 `candidate_slots`/`with_candidate` 的不变量后确认**原设计是对的**：`text` 就是"当前显示的那个候选"，编辑即改写该槽位，其余候选保留，玩家改完错字仍能翻回上一版。已回滚我的改动并补上说明注释。测试 162→165。 |
| 2026-10-18 | 第五个数据完整性缺陷：**每次加载都往世界自己的事件日志里追加一条「已载入…」**。日志既是 UI 展示也是持久化内容，而载入提示描述的是"打开文件"这个动作、不是世界里发生的事；结果每刷新一次 `events.json` 就永久多一行同样的文字，玩家的真实事件被逐渐淹没。实测：连续 reload 5 次后文件里有 4 条载入提示。修法分两处：① `events_json_text` 用 `is_transient_log_line` 在**写入时**过滤掉载入提示与解析警告；② 重读同一文件夹时先清掉内存里的旧提示，避免内存里也堆叠。UI 行为不变（玩家仍能看到一条"已载入"）。**浏览器实测**：刷新 3 次后界面只显示 1 条提示，而 localStorage 里的 `events.json` 只有真实事件、没有任何载入记录。测试 165→168（不增长 / 瞬时行识别正向反向 / 真实事件精确往返且提示不重复）。 |
| 2026-10-18 | 第六、七个数据完整性缺陷，都在「记忆压缩」这条最隐蔽的路径上。**⑥ 摘要覆盖范围不落盘**：`summarized_upto`（摘要覆盖到第几行）从未写进文件，读回时被硬编码为「覆盖所有已加载行」。后果是一个只压缩了前 10 行、另有 10 行未压缩的对话，重载后摘要会**谎称覆盖全部 20 行**，于是 `needs_compression` 永不触发，过时摘要一直冒充真实历史进入提示词。修法：写 `summarized_upto` 字段；读时信任文件值并夹紧到实际行数（手改 999 不会永远免压缩，负数退化为 0）；**旧文件无此字段时回退到旧语义**（覆盖已加载全部），保证向前兼容。**⑦ 压缩结果根本没提交**：`SummaryArrived` 返回 `Effect::none()`，摘要只活在内存里，重载后压缩成果消失、下次启动重做一遍。修法：改为 `commit_effect(Conversation(id))`。测试 168→174（覆盖范围往返 / 旧文件兼容 / 手改值夹紧 / 空摘要不宣称覆盖 / 提交确有其事 / 失败不改状态）。 |
| 2026-10-18 | 不再逐个抓 bug，改为**建系统性护栏**。前 7 个缺陷形状完全相同：`update` 改了状态但没进 `commit_files`，或读回时被丢掉；逐个抓不可扩展。新增 `app/roundtrip_wbtest.mbt`，断言**性质**而非个例：`reload(commit(model))` 必须保持用户该保留的状态。`persisted_shape(model)` 把「必须存活」的部分归一化成可比较结构（按 key 排序的对话行与说话人、摘要、摘要覆盖范围、世界书、非瞬时事件、角色、立绘引用、地点），**刻意排除**会话态（草稿、选中、编辑缓冲、瞬时提示、pending），因为它们本来就该重置。覆盖 10 种用户动作 × 场景/分支 × 世界编辑（建角色、接受记忆、带全部修饰符的世界书）× 候选集与 swipe。**护栏有效性已验证**：我故意注入三次回归（去掉 `summarized_upto` 落盘 / 去掉立绘落盘 / 跳过分支文件写入），三次都被测试拦下；恢复后 178 项全绿。测试 174→178。 |
| 2026-10-18 | 把护栏从「落盘性质」扩到另一条 TEA 不变量：**`update` 不得写穿入参模型**。原有的纯性测试只手写覆盖 2 条消息，而我在 2~10 轮新增了大量会改容器的分支。新增 `app/purity_wbtest.mbt`：`model_fingerprint` 把可被写穿的部分（日志、选中、草稿、场景、意图、创建器、记忆草稿、世界列表、地点、每个对话的行/候选/摘要/覆盖/pending）压成指纹，对 **58 条消息**逐条断言 `update(model, msg)` 后入参指纹不变。**立即抓到 3 个真实缺陷**：① `WorldGenerated` 用 `{ ..model, generating: false }`（无 fork）后 `push_log`，把提示写进了调用方仍持有的模型；② `DiscardMemory` 同样没 fork；③ `AcceptMemory` 同样没 fork。另发现一处**死代码**：`NewWorld` 里把清洗警告 push 进一个随即丢弃的 `warned` 副本，警告从未出现——改为在返回的 `next` 上补发，既有测试 `a world name with path syntax is sanitized before it reaches the host` 立刻由红转绿。修完后再用脚本静态扫描全部 `{ ..model,` 站点，确认剩余 6 处都不在变更路径上。测试 178→180。 |
| 2026-10-18 | **重要修正**：此前我一直只跑单个 validator 并报告「全部静态校验器绿」，本轮第一次跑完整 `sh scripts/check.sh --profile pr`（74 步 / 196 个分节），发现它**一直是红的**——三个真实失败：① `docs/repository-facts.md` 过期（我加的 `./examples/ai_world` workspace 成员与 catalog 行从未重新生成）；② `validate_source_file_policy` 报 `update.mbt` 1581、`view.mbt` 1489 **逻辑行超 1200 硬上限**——注意这两个文件在我动手前是 1154/953，是**我**推过线的，所以不能走 ratchet 豁免，必须拆分；③ `moon fmt --check` 在 release 目标下对若干 ai_world 文件不收敛（`@app`/`@llm_web` 恰好等于默认别名，formatter 会把它当冗余省略）。修法：重新生成 repository facts；把历史编辑（10 条消息）拆到 `app/editing.mbt`、世界库（8 条）拆到 `app/library.mbt`、会话视图拆到 `app/conversation_view.mbt`，`update.mbt` 1161 / `view.mbt` 1045 回到限内；别名改成 `@world_app`/`@llm_web_gateway` 避免被省略；用脚本迭代采纳 release-formatter 输出直到收敛。**现在 `pr` profile 全绿（exit 0，"MoUI pr checks passed."）**。另补一处 objective 明确要求但缺失的能力：世界书命中提示只报条目名、不报注入量，`lore_summary` 现在输出「N 条，M 字」。测试 180 全过。 |
| 2026-10-18 | 顺手跑了 `--profile daily` 验证边界。它在 `node scripts/test-moui-prebuild.mjs` 失败（"Skia binding prebuild must leave link ownership to moon.pkg"）。**已确认与本目标无关**：`git stash -u` 把我全部改动（examples/ai_world + docs + checks + memories + resource + catalog + 脚本）暂存后，该脚本仍然一模一样地失败；且失败点在 `moui_skia` 的 prebuild 链接配置，属于仓库既有状态。objective 要求的范围是 `moon test examples/ai_world/app`、`render_check`、`moon build web_wasm` 与 **静态校验器**（`pr` profile，已全绿），`daily` 不在其中，因此不在本目标内擅自修 Skia 链接所有权。同时验证了 macOS 原生入口能构建（`moon build examples/ai_world/macos_skia --target native` 通过），并核对其立绘路径确实走 `@fs.read_file(...).binary()` + `@app.base64_encode`。 |
| 2026-10-18 | 补一处真实兼容性缺口：**provider 返回 content 为块数组时整条回复被丢弃**。`llm_parse_reply` 只接受 `content` 是字符串，而 Anthropic 形状的网关（以及部分 OpenAI 兼容代理）返回 `[{"type":"text","text":…}]`。对这种端点，每条回复都会被当成 provider 失败，玩家只看到"失败"却查不出原因——这是接真实服务时必然遇到的问题。修法：新增 `text_from_blocks` 拼接所有 `text` 块、跳过非文本块；**全无文本块（如纯 tool_use）仍返回 `None`**，让失败路径保持诚实而不是追加空行。新增 1 组测试（多块拼接 / 混合块跳过非文本 / 无文本块仍失败 / 字符串形式不受影响 / 错误体仍失败 / 空 choices 仍失败）。测试 180→181。另核对：macOS 原生入口可构建、立绘走 `@fs.read_file(...).binary()` + `@app.base64_encode`；`pr` profile 复跑仍全绿。 |
| 2026-10-18 | 验证了此前从未端到端跑过的一段：**原生 HTTP 传输**。写了一个本地 OpenAI 兼容桩服务器（Python，监听 127.0.0.1:8791），用 `async test` 真发一次 POST，确认 URL 解析、`Authorization: Bearer` 头、请求体、`choices[0].message.content` 解析全链路正确——**实测通过**（`llm_fetch` 返回 `掌柜的回话。`；第一次失败只是因为桩服务器没起，起后即绿）。因为需要外部服务器的测试不能进套件，最终落地为 3 项**无 socket** 的测试（`llm_native/worker_wbtest.mbt`）：base URL 补 `/chat/completions`、已含路径时原样使用（OpenAI SDK 规则，重复拼接会 404 而看起来像 key 错了）、尾斜杠与首尾空格归一化；请求体含 model 与**全部**计划消息（防"只发首尾"回归）、且 **API key 不出现在 body**（它只是 header）。已把该包注册进 `pr` profile（`AI World native transport tests`），CI 会跑。`moon fmt --check` 对新测试文件不收敛，用 release-formatter 采纳脚本修好。`pr` profile 复跑 **exit 0**。 |
| 2026-10-18 | 补 objective 里被我漏掉的一条明确要求：**「AI 生成世界时产出立绘提示词」**。检查发现 `world_idea_prompt` 的 schema 根本没有 `portrait` 相关字段——生成的世界永远不可能带立绘提示词。修法：schema 增加 `portrait_prompt`（并写明"约40字、不写名字/画风参数、本程序不会调用图像接口"），`CharacterCard` 增加 `portrait_prompt` 字段，Markdown 写入 `## 立绘提示词`、JSON codec 同步，UI 在舞台副标题显示「立绘提示词（拿去生图后存为 characters/<名>.png）：…」，且只在**还没有立绘**时显示。**过程中又抓到两个同类字段丢失缺陷**：① `rename_card` 逐字段重建卡片时忘了 `portrait_prompt`，导致每次加载都把它丢掉——这是"新增字段忘了在这里复制"的典型陷阱，因此补了一个**全字段往返测试**（每个字段设成不同值，新增字段没接线就会失败）；② `CharacterCard.location`（决定 `cast_at` 谁在场）**从未写入 Markdown**，于是站在矩形外的角色重载后会从场景里消失——新增 `## 所在` 段。测试 181→186。`pr` profile 复跑 **exit 0**。 |
| 2026-10-18 | 把上一轮的「全字段往返」从**角色卡**扩展到**所有持久化类型**，一次抓到四个真实缺陷——它们全是"字段存在于模型、但编解码器没带上"的同一形状。① **世界地图尺寸不落盘**：`map_width`/`map_height` 从未写进 `world.md`，每次重载地图都退回默认 640×420，自定义地图被静默缩小；新增 `## 地图` 段（`- 尺寸: w=700 h=460`）。② **地点描述不落盘**：解析器早就支持"第二个冒号后面是描述"，但写入端**从来没输出过**，玩家写的每个地点描述都在保存时丢失；改为在矩形参数后用 `: 描述` 附上。③ **JSON codec 丢掉世界书四项修饰符**：`world_entry_json` 只写 `keys`/`content`，`priority`/`position`/`recursion`/`probability` 全部丢失，于是 AI 生成或导出成 JSON 的世界会失去世界书调参；改为只写非默认值并在解码时回落到构造器默认。④ 复查 `creation.mbt` 里 `Scenario::new` 的逐字段重建，确认 8 个字段齐全（没有遗漏）。**契约澄清**：`id` 在文件夹 codec 里由目录名/文件名派生（`world.md` 只存展示名），所以往返后 id 会变——这不是 bug，测试已按真实契约断言。测试 186→189。`pr` profile **exit 0**。 |
| 2026-10-18 | 把「全形状护栏」扩到第三种持久化类型 `Conversation`/`ChatLine`，并钉住**哪些字段该落盘、哪些不该**：落盘 = `character_id`/行/说话人/`text`/`alternatives`/`selected`/`summary`/`summarized_upto`；**不落盘** = `pending`（in-flight 请求，重载本就该没有）与 `appended`（由行数重算）——显式测试防止有人为了"让往返相等"而把一个卡住的 pending 标志持久化。**又抓到一个真实缺陷（第 17 个）**：AI 生成/JSON 世界的**地点 id 是英文 slug**（`bar`），而角色卡用 `location` 引用这个 id；但文件夹 codec 把地点 id 从**显示名**派生，于是重载后地点变成 `吧台`、角色仍指向 `bar`，`cast_at` 判定失败 —— **场景在场人数从 2 变 0**，多人对话直接空掉。修法：`world.md` 的地点行在 id 与显示名不同时写 `id=bar`，解析端识别并保留；id 等于名称时不写（手写世界不增加噪音）。测试 189→194（对话全字段文件往返 / 世界往返 / 会话态不落盘 / slug id 场景存续 / 冗余 id 不写入）。`pr` profile **exit 0**。 |
| 2026-10-18 | 做了一次**此前从未做过的端到端验证：浏览器 + 真实 HTTP provider**。之前 18 轮的 Web 验证都只跑离线剧本分支（没配 key），provider 路径只做过单测。这次起了一个带 CORS 的本地 OpenAI 兼容桩，用 `localStorage['ai_world_config_v1']` 注入 endpoint/model/key，然后在真实页面里点选角色、输入、发送，抓到桩服务器实际收到的请求：`POST /v1/chat/completions`、`Authorization: Bearer sk-stub`、`model=stub-model`、`temperature=0.7`，**回复正常渲染进 UI**。进一步验证了两件只有真跑才能确认的事：① 私聊 prompt 结构正确（system 含【世界】【你是林掌柜】【场景】+ user 原话）；② **带 `[position=before]` 的世界书条目真的排在 persona 之前**——发「想喝点酒」后请求变成 3 条消息，第 0 条是 `【世界规则】- 规矩：只温不冰。`、第 1 条才是 persona，priority/position 在真实请求里生效而不只是在单测里。顺带确认 `llm_parse_reply` 的块数组支持（第 14 轮修的）在真实响应下也正常。 |
| 2026-10-18 | 把端到端验证推进到**场景**路径，抓到第 18 个真实缺陷：**多人场景其实一直是单人独白**。`send_scene_turn` 用 `conversation.lines().length()` 作为 `responder_for` 的轮转索引，而一个场景回合会追加 2 行（玩家 + 回应），于是索引每轮 +2；在 2 人阵容下取模恒为 0，**永远同一个人回答**。单测 `responder_for(cast, text, 1)` 是直接传索引的，所以从来没暴露这个问题——只有真跑两轮才会看到。修法：索引改为**玩家行数**（`lines().filter(speaker is Player).length()`），一轮一步。**端到端验证**（带 CORS 的本地桩 + 真实页面）：场景 prompt 结构正确（`你在一场多人场景中扮演林掌柜…【场景】吧台 / 【这里】木柜台。 / 【在场】- 林掌柜（你）/ - 赶考书生：… / 只输出林掌柜说的话…`），世界书 `【相关背景】` 注入、玩家原话作为最后一条；修复后两轮分别由林掌柜、赶考书生回答，UI 逐行标注说话人正确（`赶考书生: …` / `林掌柜: …`）。测试 194→196。`pr` profile **exit 0**。 |
| 2026-10-18 | 端到端验证「重新生成 + 候选切换」，走了弯路但结论明确。**先记方法论教训**：我最初用 `document.body.innerText` 判断回复是否更新，得出「重新生成没生效」的错误结论，随后基于错误观察改了三处代码（markdown `key`、自写高度估算、`visible_viewport_height`）——**全部是无效改动**。改用截图才看清：**功能本来就是对的**（截图里 `版本2。` 正确显示），因为 Markdown 是 canvas 绘制的，`innerText` 根本读不到它（这一点我在第 7 轮就写进记忆了，本轮忘了）。已确认 `Regenerated` 后模型状态正确（`text="v2"`、`alternatives=["v1"]`、`selected=1`，单测断言通过），磁盘 JSON 也正确。**保留**：给两处 `markdown_viewer` 加 `key`（身份随文本走，避免原地改写时复用旧节点）——这是符合框架 `ViewIdentity` 语义的小改进。**回退**：自写 `line_markdown_height` 估算与 `visible_viewport_height=1200`，两者都无证据支持，不留投机改动。**遗留真实布局缺陷（未解决，已记录）**：多段 Markdown 回复在舞台里只显示第一段，且该行的操作按钮（改/删/分叉/swipe）被挤到 composer 下方。这是 transcript 布局/裁剪问题，不属于 provider 或数据正确性，本轮时间用尽未定位到根因。测试 196 全过，`pr` profile **exit 0**。 |
| 2026-10-18 | **定位并修掉第 21 轮遗留的布局缺陷（第 19 个真实缺陷）**。这次不靠猜：`render_check` 里加了 `transcript_probe.mbt`，用 `AppRuntime` 渲染真实视图树并读出 `PushClip` 矩形与每个 `DrawText` 的坐标。硬数据：transcript 的裁剪矩形是 `y=614..918`，而最新几段文字画在 `y=834 / 896 / 958`，**第三段与整行操作按钮都在裁剪区之外**——所以玩家等到的回复看不见。根因：`scroll_view` 自己保存滚动偏移且**不会跟随新内容**，而 transcript 是从视口顶部往下增长的。修法：给两处 transcript 的 `scroll_view` 传 `request=follow_tail_request(行数)`（`@moui.ScrollRequest`，id 随内容变化，运行时把超大 offset 夹到真实内容高度；id 不变时不会打断玩家手动拖动）。**护栏已验证有效性**：把 request 去掉后新测试立刻失败（`lowest=896` 未达 `clip_bottom=918`），加回即绿——`rows` 从 12 降到 11、`lowest` 从 896 升到 918，可量化对比。render_check 3→4 项，app 测试 196 不变。`pr` profile **exit 0**。 |
| 2026-10-18 | 把上一轮的测量方法推广到**整条渲染链**，新增两类护栏（render_check 4→8 项）。① `panels_probe.mbt`：遍历全部 draw command，维护 clip 栈，断言**没有任何文本画在所有活动 clip 之外**（当前 51 个文本运行、0 逃逸）。这类缺陷视图树是"正确"的、单测看不出来，只有几何能发现。② `portrait_probe.mbt`：立绘链路有四个环节（卡片 `portrait:` 字段 → `characters/<名>.png` 资产 → `portrait_data_uri` → `@views.image`），此前所有测试都停在**模型**（URI 字符串）这一层；本探针一路跟到 `DrawImage` 命令，断言确实存在带 `data:image/png;base64,` 前缀的图像命令，并验证**无立绘时图像命令为 0、但文本仍正常绘制**（色块回落不依赖图像）。**两条护栏都做了反向验证**：把 `portrait_data_uri` 改成直接返回文件名后，立绘测试立刻失败；clip 检测逻辑另有单元级固定（构造内/外两个矩形，断言 detector 分别通过/拒绝），避免护栏本身失效却无人察觉。`pr` profile **exit 0**。 |
| 2026-10-18 | 补两块从未验证过的**可用性**面。① **无障碍**：全 app 52 个交互控件、`accessibility_label` 出现 **0 次**。框架的 `button` 没有 a11y 参数（文案即标签），但 `image` 有——立绘此前是个无名图片，屏幕阅读器只能读出"图片"，于是给名单头像与舞台立绘都加上「<角色名> 的立绘」。更实际的一处是滑动切换：`‹` / `›` 这种纯符号按钮对屏幕阅读器和第一次玩的玩家都不可读，而 `button` 又给不了标签，于是把文案本身做成自解释的「‹ 上一版」「下一版 ›」，按钮宽度 32→64。② **动作行放得下吗**：按钮变宽后可能被裁，新增 render_check 断言「改/删/分叉/上一版/下一版」里最靠右的文本不超过舞台右边界；并且**断言两个测量值都非零**，否则这个测试会变成永远通过的摆设（第一版就是这样的，我把它改成了非空断言）。截图确认新文案与"跟随尾部"滚动同时生效。render_check 8→9 项，`pr` profile **exit 0**。 |
| 2026-10-18 | 增加「极端输入」护栏：让模型无视长度提示（或玩家粘贴一大段）时布局是否还成立。测一个 400 倍重复的回复（约 2400 字）。**第一版测试写错了两次**：先断言"没有文本画在活动 clip 之外"，结果 169 条失败——但排查后发现那是因为长消息本身高于视口，**旧内容滚到裁剪区上方是正确的滚动行为**，不是 bug（我还怀疑过 `y=100000` 的 offset 没被夹紧，查了 `scroll_clamp_offset` 确认框架会夹）。第二次改成"不在窗口外"，仍然 226 条失败——因为我取的"最外层 clip"实际是某个子面板而非窗口。第三次才问到对的问题：**换行后的段落会不会横向溢出它所在的列**。这个断言是真正的不变量，且已验证有效（把 `markdown_viewer` 宽度改成 `stage_width + 200` 后测试失败）。顺带确认：即使超长回复，composer 仍在场（玩家可以继续输入）。render_check 9→10 项，`pr` profile **exit 0**。 |
| 2026-10-18 | 两件事。① **浏览器实测「全保真往返」**：种一个把此前所有修复都用上的世界（自定义地图尺寸、slug 地点 id、地点描述、角色 `所在`、立绘提示词、世界书四项修饰符、候选集与 selected、摘要与 `summarized_upto`），加载后读回 app 自己写出的 localStorage —— **八项全部保留**。这等于在真实运行环境里回归验证了第 16~18 轮修的六个字段丢失缺陷。② **新增 `orphan_wbtest.mbt` 钉住"世界被手改后历史怎么办"**："文件夹即数据库"意味着玩家会手动增删角色，这是设计意图，不是异常。三条断言：删掉的角色，其对话**不复活成幽灵角色**、也**不被静默保留**、而是**带警告丢弃**（玩家能知道发生了什么）；场景按地点键存续，所以改阵容不会连带删掉多人对话；分支若基角色消失则随基角色一起丢弃。测试 196→199。`pr` profile **exit 0**。 |
| 2026-10-18 | 本轮检查「毕业前置条件是否真的自洽」，抓到两个会让毕业**静默丢代码**的问题。① **12 个未跟踪文件**：`git subtree split` 只遍历**提交历史**，而我这 26 轮新建的 `scene.mbt`/`lore.mbt`/`editing.mbt`/`library.mbt`/`turn.mbt`/`creation.mbt`/`conversation_view.mbt`/四个护栏测试/三个 render_check 探针**在 HEAD 里一个都没有**（`git ls-tree HEAD -- examples/ai_world/app/` 匹配数为 0）——如果直接毕业，独立仓库会缺掉整个应用的核心实现，而脚本照样报成功。把 dirty-tree 检查的报错改成**说明这个后果**（"N untracked path(s) … would be MISSING from the graduated repository"）。② **脚本自身两个 shell 缺陷**：彩排时脚本在 "checking the working tree" 后**静默退出**，`bash -x` 追到 `junk=0` 之后中断——原因是 `set -euo pipefail` 下 `grep '^!!'` 无匹配时返回 1，经 `pipefail` 传播成致命错误；已给该管道加 `|| true` 并注释原因。另删掉一个我早前 `cat >>` 打错文件名留下的空文件 `integrity_wbtest.mt2`。彩排复跑到第 6 步，按设计停在真实阻塞（未发布的 `moui`）。测试 199 + render_check 10 全绿。 |
| 2026-10-18 | 补「长对话连续性」这一从未被覆盖的场景——记忆压缩是唯一"只有玩到几十轮才会暴露"的功能，没测过就只是看起来能跑。新增 `long_chat_wbtest.mbt` 5 项：① 连玩 40 轮后历史不超过 `chat_history_limit`（60 行），**且最新一轮仍在**（截断只能丢最旧的，不能丢玩家刚写的）；② `compression_source` 只交出"摘要尚未覆盖"的部分，最新 10 行不重复折叠，条数恰为 `行数 - summary_keep_recent`；③ 压缩不会为同一批材料重复触发——刚压完不触发、5 轮后仍不触发、再攒够 `summary_min_new_lines`（10 行）才触发；④ **摘要必须在其原始行被裁掉之后仍然进入提示词**（这正是摘要存在的意义）；⑤ 场景对话同样受 60 行上限约束（`Conversation` 是共用类型，不能只对私聊生效）。**过程中我又把 fixture 写错一次**：用 25 行去断言"应当触发压缩"，但阈值是 `60 - 10 = 50` 行——代码是对的，测试是错的，已改成 55 行并把这个阈值写进注释。测试 199→204。`pr` profile **exit 0**。 |
| 2026-10-18 | 端到端验证**AI 生成世界**这条主线（此前只有单测）。用本地桩返回一个完整的 JSON 世界，在真实页面里输入一句话设定 → 点「生成世界」→：**请求确实带上了 `portrait_prompt` 字段**（第 16 轮加的 schema）；返回的世界成功导入并上舞台（「雨夜酒馆」「林掌柜」都出现）；写入 localStorage 的 `characters/林掌柜.md` 保留了立绘提示词、`world_book.md` 保留了世界书。随后**继续把它玩下去**：点选角色、发言，第二次请求的 system prompt 里含该角色人设，回复正常渲染——即"生成 → 能玩"整条链路成立。过程中一个操作细节：canvas 应用的 input `placeholder` 在 DOM 里是空的（文字由 canvas 绘制），所以按 placeholder 找输入框会失败，改成按位置（x > 900 的那一个）选取才对——这条已记进记忆，避免下次再踩。 |
| 2026-10-18 | 把毕业阻塞**从文字描述变成脚本可复现的诊断**。① 精确定位：解包 registry 缓存里的 `wzzc-dev/moui@0.2.3` 与 `wzzc-dev/moui_richtext@0.2.1` 对照，确认缺口**只有 `text(wrap=)` 一个函数**（richtext 的 `markdown_viewer(..., key?)` 已发布，富文本链没问题）；影响面是 `view.mbt` 两个 helper、3 处 `wrap=true`、19 处调用点。**不建议**为毕业删掉 `wrap`——它承担真实的中日韩段落换行，删了是产品退化。② 让脚本自己说出来：`graduate-ai-world.sh` 新增前置检查 2c，在示例被 `git rm` 之前先统计 `wrap=true` 的使用数与 `moon.mod` 里声明的 `moui` 版本，输出 `note: N use(s) of text(wrap=true); needs a moui newer than X to be published`；第 6 步失败时也会带上这两个数字。**过程中修了两个 shell 坑**：该统计原本放在第 6 步，但那时 `examples/ai_world` 已被删掉、grep 结果为 0；以及那段用的 `<<'EOF'` 是引号 heredoc、`${wrap_sites}` 不会展开——拆成两个 heredoc，需要插值的那段不加引号。彩排确认两条消息都能正确插值。`pr` profile **exit 0**，app 测试 204 全过。 |
| 2026-10-18 | **死代码清理**。30 轮迭代后做一次 API 审计：扫描全部 `pub fn` 声明与调用点，找出 8 个「声明了但没人用」的候选，逐个核实（不是只看 `uses<=1`，因为首类引用/跨包引用不会体现为 `name(`）。确认 **5 个确实已死**并删除：`world_book_for` / `lore_for_turn`（重构后已被 `select_lore` + `lore_block_at` 取代的薄包装）、`parse_conversation_index`（按角色拆文件后不再有聚合索引文件，`conversations.json` 现在整份读入做兼容，不走索引）、`InputIntent::marker`（`context.mbt` 已就地渲染更完整的意图文本）、`WorldModel::conversations()`（与同名字段重复的访问器）。**保留** 3 个：`ai_fs_complete` / `ai_llm_complete` 是 WASM 导出 ABI（JS 侧调用，MoonBit 内部看不到调用点）、`active_conversation_key` 供宿主使用。删除后 `moon info` 确认 `pkg.generated.mbti` 里这 5 个名字已消失，app 204 项 / render_check 10 项 / web_wasm 与 macos_skia 构建全绿，`pr` profile **exit 0**。 |
| 2026-10-18 | **文档与代码对齐审计**。31 轮改动后，README 的「文件夹即数据库」一节已明显过时：目录树里没有 `characters/<名>.png`（立绘），把 `conversations.json` 当现状写（实际早已按角色拆成 `conversations/<键>.json`，聚合文件只读不写），地图尺寸写成固定 640×420（实际可用 `## 地图` 改），也没提地点 `id=` 后缀。逐条对照代码后修正。更重要的是**把文档claim变成测试**：新增 `docclaim_wbtest.mbt` 3 项，把 README 里印的三段示例（普通条目 `- 酒 | 花雕: …`、四修饰符条目、`## 地图` + `- 吧台 id=bar:` 地点）**原样喂进真实解析器**，断言字段值正确、且写回时只写非默认修饰符、`id=bar` 不丢。这样"文档里写的语法"若哪天失效，测试会先失败。测试 204→207，`pr` profile **exit 0**。 |
| 2026-10-18 | 测**提供商失败**这条从没测过的路径，发现 2 个真实缺陷（第 20、21 个）。新增 `failure_wbtest.mbt` 4 项：① 失败后 `pending` 必须清掉（否则输入框永久禁用）、玩家那句话不能丢、并且要告诉玩家；② 失败后可以立刻重试（`pending` 卡住会让重发被静默丢弃）；③ **重新生成失败时不能把已有的好回复抹掉**；④ 空白回复不能被当成一条空消息存下来。**缺陷一**：失败提示是英文 `no reply from provider for 林掌柜`——整个界面都是中文，这一行读起来像是内部错误泄漏，已改为「林掌柜 没有回应（请求失败）。可以再发一次。」。**缺陷二**：provider 返回纯空白（或只剩自己的名字前缀）时 `llm_clean_reply` 会清成空串，而代码**无条件 append**，于是存档里多出一条永远删不掉的空气泡——现在空串按失败处理（私聊与场景两条路径都改）。测试 207→211，`pr` profile **exit 0**。 |
| 2026-10-18 | 测**迟到回复**（第 22 个真实缺陷）。新增 `late_reply_wbtest.mbt` 3 项：玩家发出请求后立刻切到别的角色、或进入场景，回复回来时是否还落在正确的对话里、是否只清自己的 `pending`、私聊与场景两个请求能否同时在飞。发现：`ConversationBook::for_character` 对**未知 id 会返回一个全新的空 Conversation**，于是给"已经不在世界里的角色"送来的回复会被 append 进这个新建对象——**存盘后就是一份孤儿文件，加载时又被丢弃**。修复：两条回复路径都加守卫（`reply_target_exists`），不存在的目标按丢弃处理并给出中文提示。**并修正一个把 bug 当契约的旧测试**：`update_wbtest.mbt` 原来断言 `jianghu`（该世界并不存在的角色）会得到一条回复，正是这个缺陷；已改为断言被丢弃，同时保留"真实存在的另一角色仍能正确收到回复"这一半。加守卫时 `update.mbt` 一度涨到 1202 行、越过 1200 硬限，把逻辑抽成 `turn.mbt` 里的两个函数而不是加 ratchet。测试 211→214，`pr` profile **exit 0**。 |
| 2026-10-18 | 测**宿主失败**（承接第 33/34 轮的异常路径思路）。新增 `host_failure_wbtest.mbt` 4 项，全部用真实 `Msg` 驱动：① 世界读取失败（`WorldFilesArrived(folder, ok=false, [])`，对应权限被撤销、文件夹被移动、磁盘错误）必须给出提示且**不装成"已打开的空世界"**；② 失败的世界切换**不能把上一个世界的角色留在新世界名下**（世界 A 的阵容出现在世界 B 的标签下）；③ 写入失败（`WorldCommitted(folder, false)`）时**内存里的回合必须还在**——丢掉写入已经够糟，再丢掉玩家刚打的字就是双重损失；④ 失败后输入框仍可用，下一条消息不会被吞。核实提示文案质量：`写入失败：{folder}（世界仍在内存中，可重试或检查文件夹权限）` —— 有原因也有出路，不需要改。**过程中改了两处自己的错误预期**：fixture 的文件夹名是 `tavern` 不是 `酒馆`；以及"提交失败后 pending 应为 false"是错的——那次发送本来就没收到回复，`pending` 理应为 true，把测试改对而不是把代码改错。测试 214→218，`pr` profile **exit 0**。 |
| 2026-10-18 | 在浏览器里真的点了一遍**地图 → 场景**（此前只测过状态机）。链路是通的：场景 chip 出现（`场景 · 吧台（2）`）、点进去、`2 人在场`、发言、回复正确署名「甲」、有「离开场景」。**但截图暴露第 25 个真实缺陷**：地图上只有**一个**标记。原因是 `character_point` 对只写 `## 所在`、不写坐标的角色回落到 `rect_center(place.rect())`——同地点的人全部落在**同一个像素**上，后画的把先画的盖掉。而"只写所在不写坐标"正是 AI 生成世界和手写文件夹的常见形态。修复：同一地点内、无显式坐标的角色按阵容顺序均匀分布在中心周围一个小环上（`ring_point`），单人仍精确居中，有显式坐标的仍以作者为准；环形半径被夹在地块内，保证标记不越界。补充 `moonbitlang/core/math` 到 `moon.pkg`（原本是隐式导入，会产生 `core_package_not_imported` 警告）。新增 `marker_wbtest.mbt` 2 项钉住不变量（三人互不重合且都在地块内；单人居中；显式坐标优先）。截图确认修复后甲、乙两个标记都可见。测试 218→220，`pr` profile **exit 0**。 |
| 2026-10-18 | 重做 **featured 截图**（毕业前置条件之一），并在截图过程中抓到**第 26 个真实缺陷**。原图拍于 01:21，早于第 24 轮（无障碍文案）和第 36 轮（场景 chip），已经看不出现在的界面。重拍时发现：**两步的短对话显示为空**——只剩一排 `‹ 上一版 / 1/2 / 下一版 ›` 按钮。根因是第 22 轮我自己加的跟随尾部滚动：`ScrollRequest` **按原值直接采用、不做 clamp**（`scroll_view_layout.mbt:110`），而我传的是 `y=100000` 常量。历史高过视口时无碍，但**短历史时会把内容整个顶出可视区**，新开的对话看起来是空的。修复分两步：先把常量改成"行数 × 单行高度"，仍不够（因为请求语义是"目标偏移"而非"增量"），最终改成 **`行数 × 行高 − 视口允许量`，负值取 0**，短历史请求 0、长历史才下滚。新增 render_check「短历史不被顶上移出」把这条钉住（render_check 10→11）。顺带把立绘换成有头肩轮廓的占位图，让截图看起来像游戏而不是色块。截图已更新为 2824×1474。测试 220 + render_check 11 全绿，`pr` profile **exit 0**。 |
| 2026-10-18 | 逐条核对目标里的验收项，把**只在函数层验证过**的那条补到渲染层。① 「世界书命中在 UI 可见」此前只有 `lore_wbtest` 断言 `lore_summary` 字符串拼得对——那证明的是"字符串被造出来了"，不是"它被画出来了"。新增 render_check 断言 `本轮注入世界书` 与命中键 `酒/花雕` 都出现在 `DrawText` 里；**并做了反向验证**：把 `lore_summary(...)` 换成 `""` 后测试立刻失败。render_check 11→12。② 复核 macOS 立绘链路：`macos_skia/main.mbt:338` 用 `@fs.read_file(...).binary()` + `@app.base64_encode` 收 `characters/*.png`，与 Web 宿主同构（Web 侧第 23 轮的 `portrait_probe` 已断言它确实成为 `DrawImage`）。macOS 入口是交互式窗口、本环境无法驱动，**不声称已在真实窗口里目视验证**。修正 README 里 render_check 的项数。测试 220 + render_check 12 + llm_native 3 全绿，`pr` profile **exit 0**。 |
| 2026-10-18 | 核对验收项时**抓到一个从未被测过的真实缺陷（第 27 个）：导出会丢掉立绘**。`bundle_wbtest` 早已断言"bundle 能携带立绘"，但那测的是**编解码器**：把立绘交给它，它能带。真实路径里 `model.portraits` 的键是 `characters/林掌柜.png`，而 `commit_files` 又套了一次 `world_folder_name`（把 `/` 换成 `_`）再拼 `characters/`，于是导出成 `characters/characters_林掌柜.png`——卡片里的 `portrait:` 引用永远对不上。新增 `export_portrait_wbtest.mbt` 2 项直接断言 `commit_files(model, World)` 的产物含 `characters/林掌柜.png` 且字节一致、并断言 bundle 往返后卡片仍能解析出 `data:` URI。修复：新增 `portrait_world_path`（已是 `characters/` 前缀就原样保留）。**并诚实区分了因果**：反向验证显示"只改路径"即可让测试通过，而"只调整 `characters/` 分支顺序"仍失败——所以根因是路径重复拼接，分支重排只是防止 `.png` 落进卡片列表的防御性修正，我没有把它写成主因。加注释时 `update.mbt` 涨到 1201 行越限，把判断抽成 `world_store.mbt` 的 `is_card_or_portrait_path`（`CharacterAssetKind`）而不是加 ratchet。测试 220→222，`pr` profile **exit 0**。 |
| 2026-10-18 | 收敛轮：核对全部验收项，修正两处**说过头**的文档表述，并把毕业就绪度写成可执行的下一步。① 「立绘在 Web 与 macOS 两路都正确显示」改为分层陈述——Web 路有 `DrawImage` 反向验证过的断言，macOS 路只做到代码审查 + 构建通过，**未在真实窗口目视确认**；把两者写成"都验证过"正是前面几轮那些"功能对但看不见"缺陷的来源。② 「导出（立绘待阶段三）」已过时：`bundle.mbt` 收 `is_portrait_file_name(path)`，立绘随包。③ 毕业就绪度写成三条：先提交（当前 18 个未跟踪文件不提交就会在 `subtree split` 时整包丢失）、建远端空仓库、发布 `moui` 后升依赖版本。最终状态：app 222 + render_check 12 + llm_native 3 = **237 项全绿**，`web_wasm`/`macos_skia` 构建通过，`fmt` 干净，`pr` profile **exit 0**。 |
