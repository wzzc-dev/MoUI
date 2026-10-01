# MoUI Studio — 用人话描述，用母语编程，用积木理解

[English](#english)

MoUI Studio 是一个**中英双语的可视化编程环境**：同一份程序有三种同源视图——
易语言式的**窗体设计器**、Scratch 式的**积木编排**、中英双关键字的
**代码编辑器**。自然语言交给 AI，但它只能产出**结构化提案**（可预览、
可 diff、可拒绝），结构上不存在"生成任意代码直接运行"的路径。产物可以
一键导出为**独立 MoUI 应用**（Web / macOS 双端）。

## 五分钟上手（Web，零安装）

```sh
node scripts/package-web-app.mjs examples/moui_studio/web_wasm --out artifacts/web/studio
# ES module 不能用 file:// 打开，需要起一个静态服务：
python3 -m http.server 8766 --directory artifacts/web/studio
# 浏览器打开 http://127.0.0.1:8766 即见 IDE
```

macOS 原生入口：`moon run examples/moui_studio/macos_skia --target native`

### 界面地图（v4 IDE 壳）

```
┌─ 无边框顶带（仅 native 沉浸式）────────────────────────────────┐
│ [系统信号灯] 按住此条拖动窗口                                   │
├─ 顶栏 ─────────────────────────────────────────────────────────┤
│ 运行 · 单步 · 编译 MoonBit        语言 · 命令面板 · 设置        │
├────┬──────────┬────────────────────────────┬──────────────────┤
│图标│ 左栏     │ 中心工作区                 │ 右栏             │
│栏  │ 程序结构 │  实时应用 │ 设计态         │ 属性/状态/数据/  │
│    │ 本地数据 │  ────────────────────────  │ 动作/依赖        │
│    │ ──────── │  积木（分类 · 选中描边）   │ ──────────────── │
│    │ 最近修改 │  ────────────────────────  │ 编辑积木（选中时）│
│    │ 快速插入 │  代码（行号 ┼ IR 映射竖条） │ 快速操作         │
│    │          │                            │ 运行时监视       │
├────┴──────────┴────────────────────────────┴──────────────────┤
│ 运行审计 │ Console                            warn 0 · err 0  │
└───────────────────────────────────────────────────────────────┘
```

- 切语言：顶栏 `English` / `中文`（代码与界面一起切换：`如果…则…结束` ↔ `if…then…end`）
- 换模板：顶栏「班级点名册 / 口算训练营 / 班级小卖部」，打开即玩
- 工作区：图标栏切换**可视化 / 代码 / 空舞台**；再点当前项收起成空舞台
- 积木视图：画布**左侧**是竖排分类轨（色点 + 名称，选中项带强调边）——分类
  不占画布纵向空间；画布支持同层拖拽重排；窗格脚注说明画布底部是**为 AI 层
  预留的避让通道**；长语句按块宽以省略号收尾。
  **语句在右栏改**（IDEA 式「选中在画布、编辑在检查器」）：选中一块积木后
  右栏顶部出现「编辑积木」卡（种类徽章 + 语句输入 + 应用/复制/删除），
  链条**永远是一条连续的链**——不再因选中被切成三段。旧版把编辑卡嵌在链条
  中间，块一多上下两段就只剩几行，读到的现象是「点积木后内容显示不全」
- 代码视图：左侧行号 + 代码，右侧 **IR 映射竖条**；**悬停**代码行或色块即
  双向高亮对应路径（离开还原，与点击的驻留高亮互不干扰）（按行号对齐的分类色块，
  点一下高亮对应积木；与「点代码行高亮积木」是同一状态的两个入口）
- 左栏：程序结构树（可搜索、可折叠）、本地数据（从 IR 派生的文件名/表头预览）、
  最近修改（区分「你」与「Agent」）、快速插入（四个 `+ 控件` 按钮直接落控件）
- 沉浸式（native）：`macos_skia` 入口开 `transparent_titlebar` —— 系统标题栏透明、
  内容延伸到窗口顶端；**系统信号灯照常可用**（关闭/最小化/缩放都是真的，app 不
  重画它们），app 只让出左侧 78pt 并把这条顶带登记为拖拽区。Web 恒关闭
- 右栏：属性/状态/数据/动作/依赖五个页签；选中积木时页签体顶部是**编辑积木**卡
  （见上）；快速操作是**设计稿口径**的单选控件对齐
  （左 `x=24`、居中 `x=(640-w)/2`、右 `x=640-w-24`）+ 复制 + 删除 + AI 优化；
  运行时监视列出被监视变量（未运行时显示空态）
- 底栏：**运行审计**时间线（编译 / 启动 / 副作用 / 错误，副作用卡就地确认）
  与 **Console** 原始日志两页签；点审计条目可跳到对应积木
- 命令面板：`⌘K` 过滤 Studio 命令（每条都是既有消息的封装，不引入新状态通道）
- AI 浮动层：默认居中贴底，可切左/右/停靠右栏，可收成药丸；
  **浮动时自动让出避让带**，不会压住窗格内容
- AI 会话线程：每次生成提案推一张 diff 线程卡（**事件驱动**，不是摆设），
  折叠条显示「Agent 待审计 N」，采纳/拒绝后卡片标记已应用/已拒绝；
  线程超过 3 条给「查看全部会话 →」直达 AI 历史；收成药丸后药丸本身显示
  `Agent 待审计 N`——收起状态下这是唯一的待办读数
- AI 输入条工具行：锚点读数（底部居中 / 左下角 / 右下角 / 停靠 · Context 侧栏）
  + 切换锚点 / 停靠右栏 / 收起三个带名字的按钮（停靠态自动改显「浮出」）
- AI 输入条：模式段 **修改 / 生成 / 解释 / 修复** 决定「发送」走哪条既有通道
  （解释=本地确定性讲解、修复=草稿回到 IR 规范渲染、生成=清空后走同一条提案
  校验链、修改=直接提案）——模式只改**入口路由**，不新增执行路径；右侧是发送
- **空舞台**（三个工作区都收起）时输入框升格为 hero：加宽居中偏上，并列出三条
  示例指令；点击示例只把文字**填进输入框**，按不按发送由你决定
- 运行：点「运行」，按钮真的能点；`提交数据` 会让程序**停下等你确认**。
  运行页里的舞台控件**逐个事件真的会重新执行**：`随机数` 每次给出新值
  （种子跨事件连续推进），所以连点同一个按钮每次都能看到不同结果——
  两轨（解释/真编译）从同一个种子起算，逐位可比
- 停止：点「停止」回到可视化工作区继续编辑（不是停在空白运行页）
- 真编译：点「编译 MoonBit」在 `TMPDIR/moui-studio-compile/<app>` 里真跑
  `moon update / check / build`，**七步进度逐格可见**（准备工作目录 → 解析依赖
  → 类型检查 → 构建 Web 产物 → 构建 native 产物 → 启动产物自检 → 收集产物，
  已完成点满、进行中高亮）；产物是**磁盘上的真实文件**
- 产物卡：**native GUI 应用**（可执行窗口程序）排在第一位，带
  **运行产物**（一键开窗）/ **复制路径** / **在文件夹中打开** 三个动作；
  长路径做**中间省略**（保头保尾，文件名永远读得到）并给出真实字节数。
  `native_smoke` 是**无头启动自检**（打印标记就退出，不开窗），单独标注，
  不会被误当成要运行的应用
- 「运行产物」是**脱离式启动**：进程 reparent 到系统 init，Studio 退出或
  被关掉都不会带走正在用的导出应用（实测：杀掉 Studio 后窗口仍在）

## 三个内置样例（各附教案）

| 样例 | 教什么 | 教案 |
|---|---|---|
| 班级点名册 | 随机数、列表框取行 | [samples/roll_call/README.md](samples/roll_call/README.md) |
| 口算训练营 | 分支、变量、算术 | [samples/drill/README.md](samples/drill/README.md) |
| 班级小卖部 | 跨事件状态、外发闸门 | [samples/store/README.md](samples/store/README.md) |

## macOS 入口（真实模型）

```sh
moon run examples/moui_studio/macos_skia --target native
```

- 真实模型默认指向阶跃星辰（`https://api.stepfun.com/step_plan/v1`，`step-5-preview`）。
- 凭据放在 **gitignored** 的 `examples/moui_studio/.config.json`（可直接在 json 里换 key）：

```json
{ "provider": { "endpoint": "...", "model": "...", "api_key": "..." } }
```

- Web 入口只走确定性假模型——现场演示不依赖网络与凭据。

## 规范文档

- DSL 规范（双语关键字、语句、内建、预算）：[docs/dsl-spec.md](docs/dsl-spec.md)
- 程序 IR 与 `.studio.json` 格式：[docs/ir-schema.md](docs/ir-schema.md)

## 包结构

```text
examples/moui_studio/
  domain/ir/          程序 IR + 不变量 + 预算（零依赖）
  domain/studio_lang/  双语 DSL：关键字表/词法/解析/打印/指令机解释器
  domain/codec/       .studio.json 编解码 + 版本门
  domain/proposals/   AI 提案契约 + 校验链 + diff + 假模型 + 样例
  domain/blocks/      语句 → 积木规格表
  services/export/    独立应用导出（内核快照 + bundle 生成）
  services/model_provider/  OpenAI 兼容协议（纯）
  services/provider_native/  native async worker + .config.json 读取
  app/                TEA shell + 五视图 + 中英 catalog
  web_wasm/  macos_skia/    薄组合根
  tools/sync_kernel/ tools/emit_bundle/
```

## 最小验证循环

```sh
# domain 是多个包（不是单包路径），逐包跑
for p in ir studio_lang codec blocks proposals; do
  moon test examples/moui_studio/domain/$p --target native
done
moon test examples/moui_studio/app --target native
moon test examples/moui_studio/app --target wasm-gc
moon run examples/moui_studio/tools/sync_kernel --target native -- --check
```

---

<a id="english"></a>

# MoUI Studio — describe in words, code in your language, understand with blocks

*(中文说明见上。)*

MoUI Studio is a **bilingual visual programming IDE**. One program, three
same-source views: an E-language-style **form designer**, Scratch-style
**typed blocks**, and a **code editor whose keywords follow the UI language**
(`如果…则…结束` ↔ `if…then…end`). AI may only produce **structured proposals**
(previewable, diffable, rejectable) — there is no path from "generate
arbitrary code" to "run it". Projects export to **standalone MoUI apps**
(Web wasm-gc / macOS Skia).

Try it in five minutes (Web, zero install):

```sh
moon build examples/moui_studio/web_wasm --target wasm-gc
```

- Switch language from the top bar (`English` / `中文`); the DSL keywords
  switch with it.
- Open a template (class roll call / arithmetic drill / class store).
- In the AI panel type "random roll call" → review the field-level diff →
  accept or reject.
- Run: buttons really work, and `submit_data` **pauses the program until you
  confirm** — nothing is sent before you do.

macOS entry (real model, StepFun `step-5-preview`):

```sh
moon run examples/moui_studio/macos_skia --target native
```

Credentials live **only** in the gitignored `examples/moui_studio/.config.json`:

```json
{ "provider": { "endpoint": "...", "model": "...", "api_key": "..." } }
```

Specs: [DSL spec](docs/dsl-spec.md) · [IR & `.studio.json` schema](docs/ir-schema.md).
