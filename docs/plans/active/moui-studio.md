# MoUI Studio——中英双语的积木/代码同源可视化编程环境

- Status: active
- Goal: 用单一产品取代 `examples/moeui_studio` 与 `examples/moblocks_studio`：
  一个中文优先、IDE 界面中英双语的可视化编程环境。一份带 schema 版本的程序 IR
  同时支撑「窗体设计 / 积木编排 / 双语代码」三种编辑视图与结构化 AI 提案，
  运行期带安全闸门，产物可导出为独立 MoUI 应用。落位 `examples/moui_studio`，
  项目格式 `.studio.json`。
- **可读性是一等公民**：AI 生成的程序必须能被人类看懂——每个生成的
  handler 必须携带双语「意图说明」，代码按规范格式渲染，AI 面板提供
  「解释这个程序」的逐语句人话讲解；可读性是验收项，不是锦上添花。
- Non-goals（v1 冻结范围）：游戏/动画/精灵系统；多窗体；作品内容本地化
  （项目内按钮文案等字符串）；移动端入口；真实网络外发（`提交数据` 是闸门化
  模拟动作，只记录审计）；MoBlocks 式工作流重试/超时状态机；断点调试器；
  RTL。比赛版只做「表单类应用」域。**真编译毕业通道不是 non-goal**：
  IR → 可读 MoonBit 源码 → `moon check/build` → 可执行产物是 v1 验收项（§8）。

## 1. 产品定位

**名字**：MoUI Studio。墨 = 中文书写；卯 = 榫卯——一凸一卯、互相咬合的传统
构件工艺，是积木的东方本源。产品形态 = MoUI Studio（Web 与 macOS 双入口）。

**定位**：MoUI 的 IDE 工具——兼顾极客与入门教学，UI 走技术风（暗色工程面板、
等宽字体、网格画布、终端式控制台、全键盘可达）；极客拿它做真代码毕业，
课堂拿它讲清一行积木到底对应哪一行代码。

**一句话**：用人话描述，用母语编程，用积木理解，做出真正能跑的跨平台应用。

**市场对标**（各取其一，不拼贴）：

| 竞品 | 它擅长 | MoUI Studio 的取与舍 |
|------|--------|----------------------|
| Lovable | 自然语言直接生成可部署应用 | 取「描述即产物」的入口；舍「生成任意代码直接执行」——AI 只产出结构化 IR 提案，校验 + 字段级 diff，可读、可拒、可讲解 |
| Figma | 画布、吸附对齐、组件化编辑体验 | 取画布/吸附/参考线/检查器纪律；舍「只到设计稿」——画布上的每个控件同时是程序声明，直接进入运行 |
| FlutterFlow | 可视化搭建 + 真代码导出 | 取「可视化 → 真代码 → 真产物」的毕业通道；舍只导出不落地的预览文本——本轮打通 `moon check/build`，生成源码就是编译输入 |
| Power Apps | 表单类企业应用与数据流 | 取表单域建模与事件子程序驱动；舍闭源托管锁定——产物是独立 MoUI 工程，可离线构建、可 git 管理 |

**差异三句**（对外固定口径）：

1. 三视图同源 IR：设计 / 积木 / 代码消费同一棵语句级 IR，改哪边都不会分叉。
2. 可读可讲解的 AI 提案：AI 只写结构化 IR 提案，带双语意图说明与字段级 diff，
   人话讲解逐语句可投屏——不是黑箱吐代码。
3. 能真编译的毕业通道：IR 生成可读 MoonBit 源码并真跑 `moon check/build`，
   产出 native + wasm-gc 可执行产物，而不是「文本预览」。

**参考综合**（各补一个缺口，不是拼贴）：

| 来源 | 继承 | 拒绝 |
|------|------|------|
| 易语言 | 中文语法编程、窗体设计器+属性面板、事件子程序驱动、「非程序员也能做真软件」的承诺 | 闭源、仅 Windows、生态停滞、学完没有出路 |
| Scratch | 拖放积木、类型端口、即时反馈、极低门槛 | 仅英文、玩具优先（游戏/动画）、无毕业通道、绑定平台 |
| MoonBit/MoUI | 类型安全、wasm-gc + native 双端、TEA 可测、真实控件体系 | —— |
| AI | 结构化提案 + 字段级 diff 预览 + 可拒绝 | 生成任意代码直接执行 |

**核心差异点（三视图同源）**：自然语言提案、积木图、双语代码消费同一棵
带 schema 版本的受约束程序 IR；任一处编辑立即回写 IR 并刷新其他视图。
AI 只被允许产出 IR 提案，结构上不存在「生成任意代码直接运行」的路径——
可预览、可拒绝、可静态校验、可当教材讲。

```
        自然语言（"做一个算平均分的表单"）
              │ AI 提案（版本化 JSON + 全量校验 + diff 预览）
              ▼
   ┌── 设计视图（窗体画布，易语言式）──┐
   │        单一程序 IR (.studio.json)   │
   └── 积木视图（Scratch 式，类型端口）──┘
   └── 代码视图（MoUI Studio DSL，中/英关键字）┘
              │ 运行（步数预算 + 外发闸门 + 审计）
              ▼
   同一份逻辑 → Web wasm-gc / macOS Skia 双端
              │ 导出
              ▼
      独立 MoUI 应用（一条命令即可运行）
```

**目标用户**：中小学信息科技课与职校、非计算机专业学生、中文编程遗产人群
（易语言爱好者、企业内部工具制作者）、需要「讲给家长和学校听的安全叙事」的
课堂场景。

## 2. 产品形态：IDE 完整界面

单窗口五区 + 右栏 AI 面板（沿用两个前代的 IDE 经验，四区/三区教训见
`memories/repo/moui-studio.md`）：

- **顶栏**：项目名（可改）、语言切换（中文 / English，按钮显示目标语言）、
  模板库、保存/打开（`.studio.json`）、导出独立应用、运行/停止、帮助。
- **左栏（工具箱）**：控件面板（设计视图）/ 积木分类面板（积木视图）/
  事件子程序列表（代码视图）。
- **中部（工作区）**：按当前模式切换：设计画布 / 积木画布 / 代码编辑器。
- **右栏（检查器 / AI 面板，tab 切换）**：
  - 检查器：选中控件属性（名称/文本/位置尺寸）或选中语句属性；
  - AI 面板：prompt 输入、fake/真实 provider 切换（key 只存会话内存）、
    提案 diff 预览（字段级，本地化标签）、采纳/拒绝按钮、会话内提案历史。
- **底部（运行视图）**：真实渲染的窗体 + 变量表 + 审计日志（运行期才出现）。
- **帮助**：DSL 双语速查表（按当前语言显示）。

模式切换（顶栏 tab）：设计 / 积木 / 代码。运行是从任意模式进入的叠加态。

## 3. 程序 IR：单一事实来源

`.studio.json`，`format: "moui.studio.project"`，`version: 1`（单一版本常量，
自带迁移政策声明；取代 `.moeui.json` 与 `.moblocks.json` 两套格式）：

```moonbit
pub(all) struct StudioProgram {
  format : String
  version : Int
  window : WindowSpec            // title, width, height
  controls : Array[Control]      // id, kind, name, rect, props
  variables : Array[Variable]    // name, init
  handlers : Array[Handler]      // control_name, event, note: {zh,en}, body
}
```

- **可读性契约**：`Handler.note`（双语意图说明，必填于 AI 提案新增/修改的
  handler，代码视图渲染为子程序头部的注释行）；名称必须是「人能读的」标识符
  ——AI 提案禁止 `a1`/`tmp`/`x` 式无语义命名（校验拒绝），变量名允许中英文
  但必须自解释；代码视图输出确定性规范格式（缩进、关键字按当前语言、
  每行一语句），同一 IR 的任何渲染结果必须逐字节稳定（快照测试锁定）。

- **控件 v1**（表单应用域，6 类）：button 按钮 / label 标签 / text_field
  输入框 / check_box 选择框 / list_box 列表框 / table 表格（字符串网格，
  支持追加行与取所选行）。属性：名称（唯一）、文本、x/y/宽/高。
- **事件 v1**：`被单击`（button/list_box/table）、`内容改变`
  （text_field/check_box/list_box 选择变化）。每对（控件, 事件）唯一。
- **语句**（IR 是语句级，不是自由图——这是与 MoBlocks 的关键分野）：
  `Assign(name, Expr)`、`If(cond, then, else_ifs, else)`、
  `CountLoop(times, iter?, body)`、`WhileLoop(cond, body)`、`Break`、
  `Call(cmd, args)`。
- **表达式**：字面量 / 变量 / 一元 / 二元 / 函数调用。
- **校验不变量**（decode、编辑、AI 提案、导出四处共用同一套，继承 MoBlocks
  20 类失败码的纪律）：名称唯一且合法（ASCII 或中文标识符）、handler 引用
  已存在控件且事件受支持、语句预算（单 handler ≤ 512、总计 ≤ 4096）、
  循环嵌套 ≤ 64、控件数 ≤ 128；**每个 handler 的 body 必须能在 zh-Hans 与
  en-US 两套关键字表下往返解析一致**（`parse(render_zh(ir)) == ir ==
  parse(render_en(ir))`，IR 是唯一事实来源，源码只是渲染）。

## 4. MoUI Studio DSL：中英双语关键字

词法/语法/解释器由 `domain/studio_lang` 持有（salvage `moe_lang.mbt`），
**关键字按当前界面语言渲染**，内部始终是规范 IR：

| 概念 | zh-Hans | en-US |
|------|---------|-------|
| 声明 | `变量 x = 1` | `let x = 1` |
| 分支 | `如果 条件 则 … 否则如果 条件 则 … 否则 … 结束` | `if c then … else if c then … else … end` |
| 计数循环 | `计次 3 次 [为 i] … 结束` | `repeat 3 times [as i] … end` |
| 条件循环 | `当 条件 循环 … 结束` | `while c do … end` |
| 跳出 | `跳出循环` | `break` |
| 逻辑 | `且 或 非` | `and or not` |
| 比较 | `= <> < > <= >=`（兼容 `≠ ≤ ≥`） | 同左 |
| 命令 | `信息框` `设置文本` `取文本` `询问` `追加行` `取所选行` `提交数据` | `message_box` `set_text` `get_text` `ask` `append_row` `selected_row` `submit_data` |
| 函数 | `取数值` `转文本` `取长度` `文本包含` `随机数` | `to_number` `to_text` `length` `contains` `random` |

- 词法容错：全角标点归一化为 ASCII；中英文标识符均合法（`变量 姓名 = ""`）。
- 内置 UI 效果由 host 注入（解释器不依赖任何 UI 包）；`随机数` 用可播种
  RNG，默认种子在 UI 层注入（时间），测试层注入固定种子 → 全确定性。
- 报错：解释器返回**结构化错误**（`{kind, line, col, token?}`），界面层再
  按当前语言本地化——内核保持语言中立，绝不把可读文案烤进领域层。
- 命令/关键字是 catalog 数据（`keywords.mbt` 一张双语表），不是硬编码分支。

## 5. 积木视图

- 积木是 IR 语句的**投影**，不是第二事实来源：编辑积木 = 编辑 IR，代码
  视图与设计视图即时刷新。务实路线（前代已判定双向自由互转两周内不现实），
  v1 做「双向、但以代码视图为文本真身」：积木编辑产出 IR 语句变更，代码
  视图重渲染；代码视图的手工修改也即时反映到积木链。
- 值类型 4 种（收敛 MoBlocks 的 9 种端口类型）：文本 / 数值 / 逻辑 / 任意。
- 积木形态：事件头（handler 头部）、变量、控制流（如果/计次/当）、命令、
  函数（表达式作为积木内嵌槽或配置文本）。从 `domain/blocks` 的 spec 表渲染。
- **运行聚光灯**：运行时按 cursor 高亮当前语句对应的积木块（salvage
  MoBlocks 的 spotlight 绘制方案，纯 draw-plan）。
- 拼图视觉（凸卯/榫头外形与分类配色）salvage `canvas.mbt`；拖拽命中沿用
  反向序顶层优先 + puzzle 几何。

## 6. 执行与安全闸门

- 单一树遍历解释器（`run(program, handler, values, rng) -> RunOutcome`，
  纯函数，测试不碰 UI）：
  - 步数预算（默认 100_000）防死循环冻结 UI；运行错误带行号。
  - `RunOutcome { values, audit: Array[StepRecord], gate: Gate? }`，
    审计即教学材料（每步一句人话摘要 + 结果）。
- **外发闸门**：`提交数据(变量, "目标标识")` 是 v1 唯一的外发动作，且为
  **闸门化模拟**（写审计 + 弹确认卡，不发起任何真实网络请求，Web 端同样
  安全）。闸门卡展示「将要送出什么、送到哪」，用户点确认才继续，拒绝则跳过
  该语句并记账。这条叙事能原样讲给家长和学校听。
- AI 永不执行：提案只有被用户显式采纳后才进入 IR；执行只发生在运行视图。

## 7. AI 提案契约

- 提案 v1 JSON：`{ version: 1, summary: {zh, en}, window?, controls: {add,
  update, remove}, variables, handlers: {add, update, remove},
  open_handler? }`。
- 校验链（任一失败整单拒绝，附本地化原因）：JSON schema → IR 不变量 →
  **每个 handler 的 body 过双语 parser** → 预算 → 策略（提案不得突破预算）。
  统一由 `domain/proposals` 一套代码承担（修复 moeui 时代 codec 与提案
  两套重复校验的债务）。
- **字段级 diff 预览**：add/update/remove 逐字段列出旧值→新值（本地化
  标签），采纳/拒绝；采纳的提案进会话历史。
- 假模型（默认、零配置）：确定性关键词路由，覆盖三个内置样例 + 通用表单
  兜底；浏览器离线全功能可演示——现场路演不依赖网络与凭据。
- 真实 provider（可选，仅 native）：OpenAI 兼容，默认配置指向阶跃星辰
  StepFun —— `endpoint = https://api.stepfun.com/step_plan/v1`，
  `model = step-5-preview`。**凭据唯一来源是 gitignored 的
  `examples/moui_studio/.config.json`**（`{ "provider": { endpoint, model,
  api_key } }`，已在根 `.gitignore` 登记）：native 组合根启动时读取并预填
  provider 面板，面板内仍可改；`services/provider_native` 提供
  `load_provider_config`（native-only，`x/fs` + 纯 JSON 解析）与一个
  **可选 live smoke 测试**（读到配置才跑、否则跳过）。key 禁止进入源码、
  `.studio.json`、导出 bundle（测试断言）；web 入口不读配置、只暴露假模型。

### 7.1 可读性：让 AI 生成的程序被人类看懂

AI 产物默认人看不懂，是本产品要解决的核心矛盾。机制：

- **结构可读**（硬约束，见 §3 可读性契约）：双语 `note` 必填、命名必须
  自解释、确定性格式渲染——校验链直接从「能不能跑」扩展到「跑得起来之外
  还必须读得懂」，不可读的提案整单拒绝。
- **变更可读**：diff 预览每项改动带 `summary.zh/en` 一句话理由；采纳后
  IR 更新，其他视图（积木/设计）即时反映，用户能在自己熟悉的视图里核对
  AI 干了什么。
- **讲解可读**：AI 面板「解释这个程序」——选中 handler，模型逐语句产出
  当前语言的人话讲解（输入 = 该 handler 的 IR + 渲染代码 + note），
  流式或整段显示；讲课场景可直接投屏。假模型对三个内置样例句库响应。
- **运行可读**：审计日志每步一句人话摘要（§6），配合聚光灯，运行即讲解。

## 8. 导出（毕业通道）

`services/export`（salvage MoBlocks 导出引擎）+ `tools/sync_kernel` 漂移门
+ `tools/emit_bundle` 离线 CLI：把当前项目导出为独立 MoUI 应用
（moon.mod + 内嵌项目的 app 包 + web_wasm 入口 + README + deps），
导出的应用**走编译轨可跑**——项目 IR 在导出时被 codegen 成
`app/generated_handlers.mbt`，由 `compiled_runtime` 执行面直接执行（bundle 里
没有指令流解释器）；领域内核与 IDE 共享逐字节相同的快照，两轨审计文本与
运行语义可比。
- 内核集收缩为 3 个：`domain/ir`、`domain/studio_lang`、`domain/codec`
  （导出的应用不需要 IDE/积木/提案，MoBlocks 的 5+1 内核是自由图模型遗留）。
- 漂移门已注册进 `checks/profiles.json` 的 pr profile（`studio export kernel
  sync` = `moon run examples/moui_studio/tools/sync_kernel --target native --
  --check`），并配 `studio export build` 夜间档烟测（`scripts/studio-export-smoke.sh`）。
- **真编译毕业通道（v1 验收项）**：IR → 可读 MoonBit 源码
  （`services/export/moonbit_codegen.mbt`）→ 本地 `moon check` →
  `moon build --target native` 与 `--target wasm-gc` → 可执行产物。
  代码视图的 MoonBit 预览与 bundle 里 `app/generated_handlers.mbt` 是
  同一个 codegen 函数的同一份文本（有逐字节测试锁定），预览即编译输入，
  不存在「展示一份、编译另一份」的旁路。
- **编译执行器**（`services/compile_native`，native-only）：导出 bundle →
  工作区外 `moon update` → `moon check` → wasm-gc 构建 → native 构建 →
  native 产物启动存活；逐步产出结构化 `CompileReport`，失败立即停止。

### 8.1 双轨语义定义（解释轨 / 编译轨）

| | 解释轨（Interpret） | 编译轨（Compile） |
|---|---|---|
| 语义来源 | `domain/studio_lang` 指令机直接执行语句级 IR | IR → 可读 MoonBit 源码 → 真参加 `moon check/build` |
| 执行方式 | 沙箱指令机：100_000 步预算 + 外发闸门 + 审计日志 | 生成 `app/generated_handlers.mbt`，由 `compiled_runtime` 执行面直接执行 |
| 可用端 | native + Web（wasm-gc） | 仅 native；Web 显式声明「本端只有解释轨 + 源码预览」，不是缺陷 |
| 运行态 | app 内 `RunModel`；单步/继续、聚光灯 | `CompiledRun` 独立状态；与解释轨产物、运行态互不影响 |
| 一致性 | —— | 差分硬门：三样例 × 每类语句 × 双语，控件文本 / 变量终态 / 审计序列逐项相同（P0 处理，无已知差异清单） |
| 失败行为 | 结构化错误 + 行号 | `moon check/build` 诊断解析为文件/行/列/错误码，本地化后回渲染，点击跳回 IR 语句；**绝不静默降级回解释轨** |

**边界**：编译轨不提供单步（编译产物是原生执行）；解释轨的计次循环内部槽
`@iN` / `@iN#n` 属实现细节，差分比较时排除，其余全部逐项比较。

## 9. 国际化（zh-Hans + en-US）

- 用 `wzzc-dev/moui_i18n`（locale 归一化 / catalog 查找 / 回退 / 具名插值 /
  count 规则）；catalog 源 `examples/moui_studio/app/i18n/{en-US,zh-Hans}.json`，
  由 `node scripts/generate-i18n-catalogs.mjs` 生成 MoonBit 表并纳入仓库，
  `--check` 进验证循环（参照 website 双语实践）。
- 语言存放：app model 持有 `Language{ZhHans|EnUs}`（mo_desktop 模式），
  存进 settings 快照持久化；顶栏切换按钮显示目标语言标签（"中文"/"English"）。
- 环境联动：入口通过宿主回调 `runtime.set_environment(...with_locale(tag))`
  同步 `Environment.locale`（website 模式），平台对话框标题随之本地化；
  shared app 不 import `moui/runtime`。
- DSL 关键字表、错误文案（结构化错误的映射）、积木标签、审计摘要全部走
  catalog；**作品内容**（按钮文本等）v1 保持单语，进路线图。
- CJK 字体：两大参考平台（macOS/Web）默认 SystemUi 栈已覆盖
  （PingFang/浏览器默认，Windows YaHei、Linux Noto），不内嵌字体；
  Linux 依赖 `fonts-noto-cjk` 的事实写进 README。

## 10. 包结构与边界

`examples/moui_studio`（独立 module + moon.work 成员 + catalog 条目）：

```text
examples/moui_studio/
  README.md（双语）  THIRD_PARTY.md  NOTICE  moon.mod
  domain/ir/            程序 IR + 不变量 + 预算（纯 MoonBit，零依赖）
  domain/studio_lang/    lexer/parser/printer/interpreter + 双语关键字表 + 结构化错误
  domain/codec/         .studio.json 编解码（ir + lang + core/json）
  domain/blocks/        语句→积木 spec（端口类型、分类、配色查询表）
  domain/proposals/     提案 schema + 校验 + diff + 假模型
  services/export/      导出 bundle 生成器 + kernel_* 快照
  services/model_provider/  OpenAI 兼容协议（纯）
  services/provider_native/ 仅 native async HTTP worker
  app/                  TEA shell + 五视图（native+wasm-gc）
  web_wasm/  macos_skia/   薄组合根（runtime + backend + 单个 renderer）
  tools/sync_kernel/  tools/emit_bundle/
```

- `app/` 只依赖 `wzzc-dev/moui` + 域 facade + `views` + `services` + 本模块
  domain/services 包；测试 import 走 `for "test"`。
- domain 包保持零 UI 依赖（唯一例外允许 `@graphics.Color` 查询表，照
  MoBlocks 先例）；入口只做接线，无业务 UI。
- 框架扩展（按需允许）：MoUI Studio 如需 MoUI 框架本身不具备的能力，可直接为
  框架增量——新控件走 `moui/views` 的具体 `@core.ViewNode` 实现 +
  `@core.View::from_node`（不新增 core 视图枚举变体），按 framework skill
  流程带测试与文档，并同步 `moon test moui/views --target native` 与
  `validate_api_surface` 预算。默认仍优先用现有控件 API组合，框架改动
  需在本计划的 decision log 记录理由。
  （text_field/list/table/button/checkbox）。

## 11. 迁移映射（前代 → MoUI Studio）

`examples/moeui_studio`（约 4.8k 行）：

| 前代文件 | 去向 | 动作 |
|---|---|---|
| `app/moe_lang.mbt`（1222 行） | `domain/studio_lang/` 拆分 | 移植全角归一化/步数预算；拆 keywords/lexer/parser/printer/interpreter/errors；加英文关键字表、结构化错误、`随机数/询问/追加行/取所选行/提交数据` |
| `app/form_model.mbt` | `domain/ir/ir.mbt` | 泛化（变量表、6 类控件、事件表、不变量） |
| `app/project_codec.mbt` | `domain/codec/codec.mbt` | 与新 IR 对齐；与提案校验合一 |
| `app/ai_generation.mbt` | `domain/proposals/` | 提案 schema 升级为 IR diff；加字段级 diff；与 codec 统一校验（修重复校验债） |
| `app/run_session.mbt` | 并入解释器 RunOutcome + app run model | — |
| `app/designer_canvas.mbt` | `app/views/designer_canvas.mbt` | 移植命中/拖拽/裁剪；扩控件种类 |
| `app/app.mbt` + `app/view.mbt` | `app/app.mbt` + `app/view_*.mbt` | 扩为五视图 + i18n + 语言切换 |
| `services/model_provider`、`services/provider_native` | 同名保留 | 逐字节移植（修拷贝遗留的错误 doc 注释） |
| `web_wasm/`、`macos_skia/` | 同名保留 | 薄根平移 |

`examples/moblocks_studio`（约 10.5k 行）：

| 前代资产 | 去向 | 动作 |
|---|---|---|
| `app/graph_validation.mbt`（20 类失败码） | `domain/ir` 不变量 + `domain/proposals` 校验 | 移植纪律与失败码枚举；自由图 reachable/cycle 等整体删除 |
| `app/block_graph.mbt` + `block_catalog.mbt`（端口类型子集） | `domain/blocks/blocks.mbt` | 只移植端口类型与「语句→积木」spec；节点/边图机制删除 |
| `app/execution_reducer.mbt`（闸门/步摘要/审计） | 解释器闸门 + StepRecord | 移植 confirm 闸门语义与 step 摘要；重试/超时/Tick 状态机进路线图 |
| `app/canvas.mbt`（puzzle/spotlight） | `app/views/block_canvas.mbt` | 移植绘制方案与命中几何 |
| `app/graph_editing.mbt`（100 步 undo） | app 编辑器 undo | 命令式 undo 用于设计/积木视图 |
| `services/export/` + `tools/sync_kernel` + `tools/emit_bundle` + runner 模板 | 同名保留 | 内核集收缩为 ir/lang/codec；runner 模板按 MoUI Studio IR 重写 |
| `fixtures/` 镜像模式 | `examples/moui_studio/fixtures/` | 保留（MoonBit 测试环境无同步文件读取） |
| `THIRD_PARTY.md` / `NOTICE` | 同名保留并扩写 | 追加易语言「仅概念参考、无代码/资产复用」声明；scratch-editor 维持架构研究声明 |

**P0 已执行的仓库手术**（2026-09-27，随本计划同一 PR）：删除
`examples/moeui_studio` 与 `examples/moblocks_studio`；`moon.work` 移除两个
成员（顺带修复 moeui_studio 缺失 catalog 条目的漂移）；`examples/catalog.json`
移除 MoBlocks 条目；`checks/profiles.json` 移除 "export kernel sync" 旧条目；
`docs/examples.md` 移除两行；重生成 `docs/repository-facts.md` 并同步
website 副本；三个前代计划归档至 `docs/plans/done/` 并标注被本计划取代；
`moui/runtime/row_child_pointer_input_test.mbt` 的场景来源注释改为中性表述；
`memories/repo/moblocks-studio.md` 重写为 `memories/repo/moui-studio.md`。

## 12. 内置样例与教学材料

1. **点名册**：班级名单 → 随机抽取 → 信息框展示（`随机数`/列表框）。
2. **口算训练营**：随机出题 → 作答校验 → 计分 → `询问` 重来（循环+分支）。
3. **班级小卖部**：表格商品 + 库存增减 + 营业额标签 + `提交数据` 闸门演示。
4. **问候**：最小 starters（按钮改标签文本）。

每个样例一份一页教案（目标/步骤/可提问的拓展）随仓库 `examples/moui_studio/samples/`；
README 双语含 5 分钟 Quick Start。

## 13. 测试与验证策略

- 双目标（native + wasm-gc）：`domain/*` 与 `app` 全量测试；入口
  `moon build examples/moui_studio/web_wasm --target wasm-gc` +
  `moon check examples/moui_studio/macos_skia --target native`。
- 必测清单：双语往返一致（`parse∘render_zh == parse∘render_en == id`）、
  20 类提案拒绝矩阵（≥15 条实测试用）、codec 往返 + 版本门、闸门
  确认/拒绝/无副作用、步数预算、审计内容、假模型确定性、导出 bundle
  结构 + run-to-completion、凭据消毒（encode 产物不含 key）、
  catalog 生成 `--check`、sync_kernel `--check` 漂移门。
- 静态 trio（每次触及指导/API/包布局的提交）：`validate-maintenance-baseline`、
  `validate-api-surface`、`validate-release-module-closures`、
  `validate-guidance-consistency`、`validate-doc-references`、
  `validate-renderer-capability-consistency`。
- 手动烟测（路径触发）：`scripts/macos-skia-renderer-smoke.sh` 与
  `sh scripts/ci-web-runtime-presentation.sh` 在双入口首次跑通时执行。

## 14. 里程碑（对齐外部 10/16 报名+提交截止，10/29 上海线下路演）

| 阶段 | 日期 | 内容 |
|---|---|---|
| P0 仓库手术 | 9/27 | 本计划 + 删除两个前代 + 引用更新（同一 PR） |
| P1 骨架与内核 | 9/28–9/30 | 包结构、IR、双语 DSL、codec；i18n catalog + 语言切换；双目标绿；web 入口跑通空 IDE 壳 |
| P2 三视图 + 运行 | 10/1–10/5 | 设计视图（属性/拖拽）、积木视图（+聚光灯）、代码视图（速查表）、运行视图（闸门/审计）、AI 面板（diff） |
| P3 样例 + 导出 | 10/6–10/8 | 3 样例 + 教案；导出引擎 + sync_kernel 漂移门重新注册 + emit_bundle |
| P4 证据与文档 | 10/9–10/11 | 双语 README、DSL 规范页、IR schema 页；演示视频；一次真实课堂/工作坊试点录像 |
| P5 回归与提交 | 10/12–10/15 | 全量双目标回归 + 静态 trio + 入口烟测；提交材料；buffer |

## 15. 风险与取舍

- **时间**：19 天。冻结范围见 Non-goals；比赛版只做表单类应用域，
  把「不做游戏系统」作为克制讲给评委。唯一允许的新功能是 AI 字段级
  diff 预览（直接把「把查询改成模糊查询并按成绩排序」变成现场可演示），
  其余只做整合不加功能。
- **双语 DSL 蔓延**：关键字必须是 catalog 数据 + 往返测试锁死，
  不允许在解释器里写 `if keyword == "如果"` 式分支。
- **积木↔代码同步复杂度**：v1 以代码视图为文本真身、积木为投射，
  双向但单向文本生成，避免往返保真难题。
- **报名口径**：一个仓库一个产品，只报 MoUI Studio，不把两个前代并列提交；
  前代以「 salvage 来源」身份存在于本计划与 git 历史。
- **AGPL/商标边界**：THIRD_PARTY.md 照前代成文做法——只研究
  scratch-editor 的架构与交互模型，不复制源码素材，与 AGPL 无衍生关系；
  易语言为闭源产品，仅概念参考，不复制代码、素材与商标。
- **全局依赖警告（待办，不阻塞 MoUI Studio）**：`examples/mo_workbench` 依赖
  已弃用的 `bobzhang/openseek@0.2.2`（连同 `bobzhang/jsonl@0.2.0`），
  污染所有 `moon` 命令输出。修法：mo_workbench 的 moon.mod bump 到
  `moonbitlang/openseek`，`openseek_native_transport/moon.pkg` 的 6 个
  import 路径同步改（agent/agent_runtime/agent_session/agent_session/
  store/deepseek/prompt），`moon update` 后跑 mo_workbench 测试验证兼容。
  2026-09-27 决定：不在 MoUI Studio 时间盒内修，仅记录。

## Acceptance

- [x] **1 改名零兼容**：模块路径、计划/记忆、README、website、i18n catalog、
  checks 全量换轨到 MoUI Studio，旧产品名在仓库源码与文档零残留（grep 断言）；
  项目格式唯一化 `moui.studio.project` v1，旧 `format`/`version` 结构化拒绝、
  不读取不迁移（commit `f5cdfac6a`）。
- [x] **2 双轨真编译**：IR → 可读 MoonBit 源码 → `moon check` →
  `moon build --target native` / `--target wasm-gc` → 可执行产物；预览源码与
  bundle 内 `app/generated_handlers.mbt` 逐字节同源（commit `e64ff3ffe`）。
- [x] **3 解释轨 + 显式双轨切换**：100_000 步预算、提交数据闸门、审计日志、
  聚光灯保留；顶栏显式切换并标示当前轨；两轨产物/运行态互相独立
  （commit `36a2de9b7`）。
- [x] **4 双轨差分硬门**：三/四样例 × 每类语句 × zh-Hans/en-US 关键字渲染，
  控件文本、变量终态、审计序列逐项断言，无已知差异清单（commit `80d003420`）。
- [x] **5 编译失败不静默降级**：诊断解析为结构化错误（文件/行/列/错误码），
  本地化回渲染到代码与运行视图，点击跳到对应积木/控件（commit `ed4a7dd1c`）。
- [x] **6 技术风 UI**：暗色工程面板 + 发丝分隔线 + 等宽优先 + 网格画布 +
  终端式控制台 + 左节点树/右 Inspector；命令面板 Ctrl/Cmd+K 全键盘可达；
  朱砂唯一强调色；复用 `moui/views` 既有控件（commit `102ebe578`）。
- [x] **7 市场叙事**：docs 定位页 + website 双语页，对标 Lovable / Figma /
  FlutterFlow / Power Apps，差异三句固定口径。
- [x] **8 退出门**：app native/wasm-gc、domain/services 全绿；工作区外真编译
  smoke 通过（native + wasm-gc 产物存在、native 启动存活）；差分矩阵全绿；
  六静态 validator + sync_kernel `--check` + i18n `--check` 全绿。

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-27 | 产品定名 MoUI Studio，取代 moeui_studio/moblocks_studio，落位 examples/moui_studio |
| 2026-09-27 | IR 为语句级（非自由图）；积木是 IR 投影而非第二事实来源 |
| 2026-09-27 | 内核语言中立：可读文案一律 catalog key，界面层本地化 |
| 2026-09-27 | v1 外发动作为闸门化模拟，不做真实网络请求 |
| 2026-09-27 | 双语关键字表 + 往返一致测试为 DSL 硬约束 |
| 2026-09-27 | 真实模型默认阶跃星辰 StepFun（endpoint `api.stepfun.com/step_plan/v1`，model `step-5-preview`），凭据唯一来源为 gitignored 的 `examples/moui_studio/.config.json`（native 组合根启动读取、live smoke 测试按存在性跳过），假模型仍为默认模式 |
| 2026-09-27 | 可读性为一等目标：handler 双语 note 必填、命名自解释、确定性渲染、「解释这个程序」讲解功能 |
| 2026-09-27 | 允许按需扩展 MoUI 框架本身（新控件走 `moui/views` 的具体 `ViewNode`，core 不加枚举变体），决策需记录理由 |
| 2026-09-27 | 品牌主题 `studio_theme` 需 `ColorPalette::from_seed`（朱砂 seed 派生全角色盘，手动覆盖派生角色质量更差）——studio app 主导入块引 `wzzc-dev/moui/core`，按 browser/mo_workbench/showcase 先例加入 validate-api-surface 的 shared-app core 导入授权名单 |
| 2026-09-29 | 产品定位定为 MoUI 的 IDE 工具：兼顾极客与入门教学，UI 技术风化（暗色工程面板、等宽优先、网格画布、终端控制台、命令面板）；竞品对标 Lovable/Figma/FlutterFlow/Power Apps |
| 2026-09-29 | 双轨定为显式产品语义：解释轨（沙箱指令机 100_000 步 + 闸门 + 审计）与编译轨（IR→可读 MoonBit→`moon check/build`→可执行产物）；两轨运行态独立，编译轨仅 native，Web 显式声明「只有解释轨 + 源码预览」 |
| 2026-09-29 | 编译轨失败**不静默降级**：诊断结构化回渲染并提供 IR 语句跳转；禁止隐式编译、禁止单步（编译产物是原生执行） |
| 2026-09-29 | **技术风暗色壳的混色缺陷根治（ADR 0036）**：声明期组件（container/card/divider/toolbar/choice_groups）改为 paint 期按环境主题解析表面 chrome（ambient 契约，与 button/text 对齐）；框架侧 `container_box` 增可选 `ambient?` 参数，未钉 background/theme 的容器在 `.theme()` 子树下跟随环境。app 侧：根容器显式铺 `studio_window_background()`（宿主窗口不铺底，macOS 浅色系统给白底）、badge/callout/inline_error/empty_state/loading_state/disclosure/command_palette 约 20 个声明期取色调用点显式钉 `theme=studio_theme()`、命令面板入口移至顶栏首行（1280 宽第二行超预算裁掉「导出应用」）。证据：web 1280×832 实测此前不可见文字从 1.16–2.79:1 提升到 14–18:1，全键盘/三视图/命令面板交互复查通过；container/divider 环境主题矩阵回归测试（暗/亮/中性/钉定）入 moui/views |
| 2026-09-27 | 设计画布手柄优先于控件体命中（按中选中控件角点 ±6px 即缩放）；吸附只做移动（缩放时参考线仅显示）；UI 新建子程序 note 留空——可读性 note 必填是 AI 提案约束；控件/子程序预算（MAX_CONTROLS/MAX_HANDLERS）在 UI 层同样生效，超限设 notice 不静默 |
| 2026-09-30 | **UI 按 v4 设计稿（`moui_studio.html`）重写为 JetBrains 式 IDE 壳**：顶栏单行 40pt（logo/品牌/脏标/面包屑 + 运行/单步/编译/中EN/⌘K/头像）、48pt 图标栏（可视化/代码/结构/数据/AI/设置，再点一次=空舞台）、左面板（搜索+结构树+最近修改+快速插入，数据视图切换）、中心多窗格工作区（Live App + 积木 + 分隔条拖拽宽度）、底部横条（运行审计时间线 + Console 日志，可折叠/拖拽高度）、右栏（Context 属性 + 快速操作 + 运行时监视）、20pt 状态栏、AI 浮动层避让体系、设置/AI 历史对话框、toast 层 |
| 2026-09-30 | **三模式（设计/积木/代码）→ 双工作区 + 多窗格**：模式切换不再互斥——`workspace`（visual/code/empty）与 `live/blocks` 窗格显隐正交，设计画布即 Live App 的「设计态」（同一 `form_widget` 构造，选择/拖拽/参考线叠加），积木链与代码编辑器无文本真身冲突（积木编辑仍走 IR 写回）。理由：设计稿把三视图统一进一个可视工作区，切换成本从「换模式」降为「点图标」，同时保留 IR 单源不变量 |
| 2026-09-30 | **AI 层按设计稿补齐 composer 模式段 / hero 态 / 示例指令**：`#modeSeg` 的 修改·生成·解释·修复 从「只切高亮」变成真实入口路由（`ComposerRun` 按 `ComposerMode` 分流到既有 `ExplainHandler` / `RestoreCodeDraft` / `GenerateProposal`，只改入口不改执行路径，不新增通道）；空舞台升格 hero 态（卡宽 700、贴上方 42%、多一行示例指令芯片，点击只 `SetPrompt` 填入）；发送按钮改为设计稿的 `.cfoot` 形态（手搓芯片避开 `@views.button` 最小值自撑宽顶出卡片）。连带修掉两个真缺陷：**带高为 0 时浮动层被塞进 0 高段而整块消失**（改按 band 分流：有让位用两段式、无让位用 stack 覆盖）、**无背景 container 刷不透明底板盖住工作区**（纯定位外层改 `@views.center`），后者症状是「布局全对、文字在绘制流里、屏幕上一片空」 |
| 2026-09-30 | **会话线程卡接上真实生产者（此前是死 UI）**：`AiCard` 结构、卡渲染、折叠条计数、`#seeAll`、药丸「待审计 N」都已写好，但 `push_ai_card` 无任何调用方、`ai_cards` 恒为空——整条线程永远不出现。现在 `proposal_from_completion`（假模型与真实 provider 共用的唯一提案漏斗）推 diff 线程卡，采纳/拒绝经 `settle_newest_thread_card` 标记已处理（只动最新一张）。同时补设计稿的 `.ctools` 行（锚点读数 + 切换锚点/停靠右栏/收起，停靠态改显「浮出」）、`#seeAll`（>3 条且未折叠时出现，跳既有 AI 历史）、药丸改为 `Agent 待审计 N` 形态。连带修掉**高度预算双算**：线程区在视图层与 `ai_card_height` 各算一份，卡一多就把 composer 顶出卡片（实测一张 diff 卡即触发）——抽 `thread_area_height` 单点计算并去掉二次 clamp |
| 2026-09-30 | **代码编辑器自带轻量双语高亮**：`code_lines()` 用 `@studio_lang` 关键字表 + 数字/字符串/标点扫描产出 `CodeToken{kind,text}`，不做通用 lexer（IR 是唯一事实来源，源码只是渲染——高亮失败不改变语义）。IR↔行双向高亮用幂等重渲染保证的「行号映射」：`ir_line_spans()` 顺序渲染每条语句取行区间，不引入行号进 IR |
| 2026-09-30 | **绝对定位用框架现成 `View::offset` + `View::align` 组合**（`mo_desktop` 先例），不新增布局控件：窗格内浮动层（AI 层/分隔条/toast）用 `stack([背景, 定位层])`，定位层内每个子项 `.align(...).offset(...)`；避免引入新 ViewNode（core 不加枚举变体）也避免 `custom_children_layout` 的测量-放置两段式复杂度 |
| 2026-09-30 | **AI 浮动层的 4 个锚点态（底部居中/左下/右下/停靠侧栏）+ 药丸收起 = 纯视图态**，由 `ai_anchor`/`ai_docked`/`ai_pill` 三个 model 字段驱动，不引入运行时 portal；避让（`--ai-res`）等价物 = 工作区底部预留高度由模型字段 `ai_reserve` 计算，不做 DOM 式测量回填 |
| 2026-09-30 | **「最近修改」与运行审计是会话内 UI 事实**：`recent_changes`（属性/插入/AI diff 三类来源）与 `audit_entries`（含副作用确认卡）留在 app model，不进 IR、不持久化——它们是「人做过什么」的教学材料，不是程序语义 |
| 2026-09-30 | **副作用确认（审计 warn 内联卡）复用解释轨既有闸门**：`提交数据` 的确认路径不变（`AnswerGate` + `Runtime.gate`），审计卡只做「告知 + 跳转」，不新增第二条外发通道 |
| 2026-09-30 | **新增 `.mbt` 文件承载 UI 组件与工作区，不改 views.mbt 的既有结构**：`views.mbt` 保留顶栏/左栏/右栏/运行表单的既有契约，新建 `ide_chrome.mbt`（图标栏/面板头/树/徽标/状态栏/toast/设置对话框）、`workspace.mbt`（Live App/积木/代码/空舞台/分隔条）、`ide_state.mbt`（最近修改/审计/控制台/监视/高亮的纯数据推导）。理由：`views.mbt` 已 1762 行、source-file-policy 棘轮 1727（需下调到实际值），继续堆会撞 1800 硬线 |

## Progress

| Date | Note |
|------|------|
| 2026-09-30 | **v4 IDE 壳重写（对齐 `moui_studio.html` v4 稿）**：① 新增 `ide_chrome/ide_shell/ide_context/ide_ai/ide_dialogs/ide_root/ide_state/workspace/undo_history` 九文件承载新壳（顶栏 40 + 图标栏 48 + 左栏 232 + 中心 + 右栏 272 + 底栏 + 状态栏 22）；② **布局陷阱根治**：容器盒居中 + `padding_layout` 钳宽导致「不定宽的 row 拿不到权重 slack、整行被居中」——新增 `fill_row` 统一通道，所有带权重 spacer 的行/列显式定尺（顶栏内容因此从窗口中间回到两端贴边）；`AlignModifier` 只把自己量成子尺寸，`.frame().align()` 是空操作，浮动层改「权重 spacer + 定高」贴底；`scroll_view` 子节点是无界约束，画布宽必须由调用方传入（原写死 470 会溢出到隔壁面板）；`set_workspace` 通配臂写成 `(other, _) => other` 导致任何工作区切换都静默退回原工作区（三处只有落布局才暴露）。③ **拟真舞台**：设计/运行舞台改为浅色 App 窗口（34pt 标题条 + 红黄绿信号点），新增 `design_total_height`，背景/覆盖层/控件层/指针换算四处共用同一起点（`stage_point`）。④ **AI 避让带**：中心列拆上下两段，内容段 = 行高 − `ai_card_height`，浮动卡落在带内不遮内容；药丸/停靠态带高为 0。⑤ **接线补齐**：接受/拒绝提案 → 审计 + Console + 最近修改 + toast 四路派生；编译完成 → 审计（含诊断）+ Console；运行启动/收尾/副作用闸门 → 审计（终态只在 `merge_run_back` 记一次）；所有 IR 编辑经 `with_undo_point` 单一漏斗记「最近修改」，并把**合并**（连续同类编辑）与**留痕**（离散动作）拆成两个入口（`with_undo_point` / `with_recent_undo_point`）——同一 key 表达两者会把连插两个控件粘成一步撤销（被既有 undo depth 测试抓到）。⑥ i18n 新增 ~370 键（zh/en 各 369→…）、catalog 重生成（1786 行）。测试：app 76 → **104 用例 ×2 目标全绿**（新增壳布局 9 例 + 行为链 19 例：左右栏几何、工作区切换、底栏页签、避让带契约、空舞台、上下文页签、命令面板过滤、模态宿主、对齐夹取、toast 上限、split 夹取、树分组/过滤、IR↔行双向映射、最近修改计数与 no-op 不记账）。`update.mbt` 因越过 1200 行硬上限拆出 `undo_history.mbt`（1226 → 994 + 241）。验证：source-file-policy 1950 文件全绿、六静态 validator 全绿、i18n `--check` ok、web 1280×800 截图逐项复查 |
| 2026-09-27 | 计划建立；P0 仓库手术完成（删两个前代 + moon.work/catalog/profiles/docs 更新 + 计划归档 + memory 重写） |
| 2026-09-27 | 完善①：接入阶跃星辰真实模型；新增「AI 生成程序可读性」目标与 §7.1 机制、验收项 |
| 2026-09-27 | 完善②：真实凭据走 gitignored `examples/moui_studio/.config.json`（含 live smoke 测试，文件已建）；新增「按需扩展 MoUI 框架」许可与边界 |
| 2026-09-27 | P1 完成：五个领域包（ir/studio_lang/codec/proposals/blocks）双目标全绿 51 测试×2；app 包 TEA + 五视图 + 中英 catalog 双目标 14/14；web/macos 薄入口就位；.studio.json 注册进 moon.work/catalog/examples.md/profiles（漂移门 studio export kernel sync）；教案×3 + 双语 README + DSL/IR 规范成文 |
| 2026-09-27 | P1 收官：services/{model_provider,provider_native,export} + tools/{sync_kernel,emit_bundle} 全部就位（provider_native 含 .config.json 读取与 live smoke，export 8/8，sync --check 绿）；app 导出桩换真 @export；web/macos 入口编译通过且 apply_locale 宿主回调接通；emit_bundle 端到端验证（25 文件 bundle、内核逐字节一致、工作区外独立 wasm-gc 构建 49 任务 0 错误）；moon fmt 后重同步内核；facts/website 重生成；六项静态验证全绿 |
| 2026-09-27 | 补齐四项：①「解释这个程序」（本地确定性讲解 + 真实 provider 路径）；② 界面语言经 SettingsServices 持久化（studio.language）+ 入口 set_environment 同步 Environment.locale；③ provider key 不入 bundle 的测试断言；④ .config.json 路径改为仓库根相对。全量：81 用例×2 目标 + native 2，六门全绿 |
| 2026-09-27 | 收官两项：⑤ i18n catalog 迁移为 generate-i18n-catalogs.mjs 生成（app/i18n/{zh-Hans,en}.json → i18n_catalog_generated.mbt，i18n.mbt 瘦身为 142 行适配器），--check 以 "studio i18n catalogs" 注册进 pr profile，source-file-policy 白名单同步；catalog 全 key 双语解析 + 插值测试进 moon test（漂移可测：改 JSON 后 --check 报 out of date 已验证）。⑥ 积木视图编辑回写：domain/blocks 增加语句路径（BlockItem.path）+ replace_stmt_at/delete_stmt_at/stmt_at，app 增加 SelectBlock/EditBlock/CommitBlock/DeleteBlock，块行可点、语句级 DSL 编辑器应用/删除即写回 IR 并同步代码视图（就地语义已有测试固定）。终态 83 用例×2 目标 + native 2；六门全绿；emit_bundle 端到端三验通过（25 文件、内核逐字节一致、独立构建 49 任务 0 错误） |
| 2026-09-27 | 评审修复四项：① 运行视图受控输入框值回写（ControlChanged 把输入写进 runtime_texts 与 run.state.texts，修「输入不落表、取文本读旧值」）；② 真实 provider 接线收敛为 ProviderRequestSpec（endpoint/key/model/system/prompt 由 app 组装、入口只转发）——同时修掉 system prompt 双重拼接、「解释这个程序」错挂提案 system prompt、面板模型名不进请求体（原硬编码 studio-proposal）三个缺陷；③ 设计视图拖拽落地（CanvasPress 建立偏移拖拽态、DragTo 经 @ir.Control::with_rect_field 夹取移动、Release 清除）+ 检查器位置/尺寸四字段（复用 app.inspector.position/size 键，域侧 RectField + 夹取规则 + MIN_CONTROL_SIZE）；④ README 验证循环改为可用的逐包命令 + 补 NOTICE。新增测试：app 3 例（输入回写/拖拽夹取/属性框编辑）、ir 1 例（with_rect_field 夹取）；domain 命令修正 |
| 2026-09-27 | 首次真实运行验收（web + macOS 双端实测）修复四类问题：① **web 入口 index.html 启动 API 错误**（用了不存在的 default 导出，页面静默卡加载）→ 改为 `bootMouiWasmGcApp({wasmUrl, canvasHost, onStatus})`；② **row 内 Horizontal divider 测量成整行宽并 FillRect 盖住后续兄弟**——画布「不可见」、右栏「消失」、大片灰底的真实根因（Skia/web 双端一致），row 内改用 `divider(axis=Vertical)`；③ **画布绘制契约**：MoUI paint 命令是窗口全局坐标（render 管线不逐层平移），draw 内容须按 `frame.origin` 偏移，measure 固定 640x480 不吃约束；④ **框架新增 `View::on_tap_with_frame`**（moui/core OnTapWithFrameModifier，透明无语义角色，单击带坐标）——拖拽识别器对纯单击不产生事件，画布点选由此补齐；app 增 CanvasTap（命中选中/空白取消、拖拽结束的 tap 以 drag 态区分）。另：顶栏拆两行 + container padding（修按钮贴边溢出）、根视图钉浅色主题（深色系统白字白底）、web 快速上手命令补 HTTP 服务说明。测试 +1（core 102，on_tap_with_frame 行为测试）+1（app 26，tap 选中/拖拽区分）；双端实测：点选/取消/拖拽移动/夹取、检查器字段、模板与语言切换全部通过 |
| 2026-09-27 | 用户反馈微调：左右侧栏内容加 container padding=10（控件面板按钮不再贴窗口左缘，检查器/AI 按钮不再满宽贴缘） |
| 2026-09-27 | 验收清单核验（P4 教学证据按指示暂缓）：当场重跑全绿——domain 55×2（ir 9 / studio_lang 25 / codec 5 / blocks 7 / proposals 9）、app 26×2、model_provider 5×2、export 8×2、provider_native 2（native）；sync_kernel `--check`、i18n catalog `--check`、六项静态验证当场重跑全绿。逐项证据核验后勾选 7/8：往返一致（"round trip zh and en are stable"）、语言切换（SwitchLanguage 往返 + ui_language_from_tag + catalog 双语 key 全解析）、闸门审计（OpGate 暂停/恢复 + app_test "run gate pauses submit and confirm completes"；v1 无真实外发路径——web 仅假模型、native provider 仅用于 AI 提案）、可读性（note 必填 + 命名 blocklist + 确定性渲染 + ExplainHandler 讲解测试）、导出（工作区外构建三验 + sync 零漂移）、文档（双语 README + dsl-spec + ir-schema + 教案×3）。**唯一未勾**：第 2 项的 live smoke 测试从未落地（早期 Progress/记忆声称有，git 历史无此测试，worker_test 仅 2 个 load_provider_config 解析测试）——样例离线可玩（双端实测）、.gitignore:52、key 哨兵断言（app_test "exported bundle never carries the provider key"）、macOS 入口预填（main.mbt load_provider_config）均已证。memory 已同步纠偏 |
| 2026-09-27 | 完善批次落地（计划外追加，四批全部完成）：**批1 质量闭环**——update.mbt 拆分为 update/update_run/update_blocks/update_ai 四文件（1034→630 行，链式 Option 分发，消息构造器互斥）；补 live smoke（provider_live_completion + 跳过式 async test），**首跑即抓到真实 provider 404**：endpoint 是 base URL、手写 @http.post 不会拼 /chat/completions，新增 @provider.completion_url 统一组装（base 拼/全路径原样/尾斜杠归一），StepFun step-5-preview 端到端首次打通；explain 测试扩为 4 模板×双语全覆盖；openseek 弃用依赖记入风险节（决定不修）；**批2 B1**——品牌主题 studio_theme（朱砂 from_seed 派生浅色全角色盘）、模式 tab 换 button_group、文件按钮配图标、三栏卡片化（card）、diff 行 badge 语义 tone、真 checkbox（RunModel.checks + RunToggle）、inline_error；**批3 B2/B3**——积木视图彩色圆角块化（block_fill 分类色 + padding_edges 缩进 + on_tap 选中 + 朱砂描边，替代空格缩进/【】/文本按钮），运行视图窗体框舞台（callout Warning 闸门卡 + 审计时间线色点 audit_dot_color + 隔行底色），SelectTemplate 重置积木选择态；**批4 B4/B5/A4**——画布点阵网格 + 拖拽对齐参考线（alignment_guides ≤4px 容差）+ 四角手柄 + 朱砂选中描边，**抓到第二个真 bug：RealGenerationFinished 无处理器、真实生成结果被静默丢弃**（移入 update_ai 纯域走同一条校验链），ai_busy 加载态（loading_state）；导出回归自动化 scripts/studio-export-smoke.sh（emit_bundle → 临时目录 moon update + 独立 wasm-gc 构建）注册 smoke/gates.json `studio.export-build`（nightly 档）。新增测试 5 例（画布计划/讲解全覆盖/真实生成回写/completion_url），app 29×2 全绿；web+macOS 双端实测通过（积木点选/模板切换/运行闸门/确认卡） |
| 2026-09-27 | 承诺兑现批次（清偿设计画布「画了但没实现」的债 + 教学闭环断点）：① **角手柄缩放落地**——IR 增 `DragCorner` + `Control::resize_from_corner`（对角固定、四角语义各异，夹取与 with_rect_field 同纪律：完整落画布内 + MIN_CONTROL_SIZE），DragState 拆 `Move(offset)/Resize(corner)`，CanvasPress 手柄优先（6px 命中半径）再控件体命中；② **移动拖拽吸附**——`snap_move_position` 复用 alignment_guides 同一目标集与 4px 容差（画线与吸附不分叉），取平移量最小者精确对齐，吸附后仍过夹取（参考线目标都在画布内，不会越界）；③ **新建子程序入口**——`CreateHandler(control, event)`（控件存在 + 事件受支持 + (控件,事件) 不重复 + MAX_HANDLERS 预算内建空子程序并选中），左栏对选中控件列出「支持但尚无 handler」的事件按钮（catalog 里 `app.handler.new`/`event.*` 键早已备好、首次接线）；④ **i18n 残账**——画布 `semantics_label` 改经翻译器（新键 `app.design.canvas`），全应用不再有绕过 catalog 的用户可见文案；⑤ 小账三笔——DeleteControl 仅在被删子程序正被选中时清草稿（其余情况保住未提交编辑）、AddControl 加 MAX_CONTROLS 防呆（超限设 notice `app.status.controls_limit`）、design 常量统一到 `@ir.DESIGN_WIDTH/HEIGHT`。内核 ir.mbt 变更已重同步（sync_kernel --check 零漂移）；测试 ir 12×2 目标、app 36×2 目标全绿（新增 8 例：resize_from_corner×3、手柄命中、手柄缩放流、吸附纯函数+集成、创建子程序、预算防呆、删除草稿）；六项静态验证全绿。教训：旧拖拽测试按下点取控件原点+5px，落进新手柄命中区触发缩放——手柄优先是设计工具标准语义，测试改按控件主体；新建 UI handler 的 note 留空（可读性必填约束只针对 AI 提案） |
| 2026-09-28 | **参赛冲刺批次（上海赛=MoUI Studio 口径，材料换轨 + 教学完备六包）**：G' 材料——`moui-milestones` 新增 MoUI Studio 口径作品介绍（CONTENT_STUDIO.md → render_studio_pdf.py，7 页 PDF）、演示脚本（MoUI Studio 主线 7 分镜）、提交清单两赛分叉（上海=MoUI Studio / 北京=MoUI）；A 撤销重做——快照栈（深度 50，程序+选中+草稿）+ with_undo_point 签名守卫（no-op 不入栈）+ 同 key 合并（连续文本编辑/整段拖拽手势一个还原点）+ DuplicateControl（新名/+16px 级联/夹取）+ 顶栏撤销重做按钮；B 单步运行——RunModel.single_step 冻结 30ms 计时器、RunStep 走一条指令、RunResume 恢复，运行视图补计划承诺的变量表（run.state.vars 排序渲染）+ 单步/继续按钮；C MoonBit 毕业通道预览（v1.1 提前）——services/export 新增 moonbit_preview 纯函数（逐字节稳定快照锁定），第 4 模式 tab 只读展示，docs/moonbit-preview.md；D 提案历史——ProposalRecord（采纳/拒绝+摘要+diff+seq），AI 面板历史区；E 帮助页——从 keywords_for 双语表 + builtin_catalog **数据生成**速查表（零手抄）+ 问候教案（第 4 份）；F 回归加固——提案 13 类错误全覆盖（decode 篡改 + struct 变异两路）、studio_lang 边界（全角/≠≤≥/混合标识符/错误行号/15 层嵌套；实际关键字是「计次循环」）、blocks 路径手术（else-if 臂/越界安全）；**抓到真漏洞：IrError::DuplicateHandler 是死变体——计划声明的 (控件,事件) 唯一不变量从未被 validate_program 强制**，已补检查（内核重同步 + 导出烟测绿）；H 素材——playwright 合成指针事件驱动 web 入口，29 张分镜截图 + 3 张标题卡 + README 索引入库 moui-milestones/video/assets（闸门作天然暂停点解单步拍摄）。测试：app 49×2、ir 13×2、lang 30×2、blocks 9×2、proposals 19×2、codec 5×2、export 10×2 全绿；六静态门 + sync_kernel --check + 导出烟测绿。提交：main 上 20743ebe(A)→B/C/D/E/F 逐包 + moui-milestones 两笔。已发现待修：导出 runner 控件未接品牌主题（黑块按钮，视频素材已注明规避） |
| 2026-09-28 | 完善批次（分析驱动，冻结前收尾）：① **运行舞台条溢出修复**——单行 436px 裁掉继续/停止（截图实证），拆两行（标题行 + 按钮行）；单步/继续在活运行（含 WaitingGate）时显示、终态隐藏；**闸门待确认 Warning 徽标**上舞台条（确认卡滚出视野后仍可发现）；② **导出 runner 排版**——卡片容器 + 「由 MoUI Studio 导出」标注 + 变量表（与 Studio 同承诺）+ 审计语义色点 + 闸门 Warning callout + Primary/Outline 确认按钮；bundle app_pkg 增 moui/core + graphics + views/style（style 是 views 子包，首写成 moui/style 被烟测拦下）；runner 模板已接朱砂 from_seed 主题（内核重同步 + 烟测绿）；③ 速查占位改为引导帮助页；④ macOS 入口实机验证：native 构建通过、进程启动存活超 30s 无崩溃；窗口级 AX/截图在本会话不可达（后台会话无 WindowServer 上下文，前台会话待补）。素材 05f/05f2/06a/06b 已重拍入库（moui-milestones） |
| 2026-09-29 | **双轨真编译目标批次（1–6 落地）**：① 零兼容改名 MoUI Studio（模块/计划/记忆/i18n/checks/README/website 全换轨，旧产品名 grep 断言零残留；格式唯一 `moui.studio.project` v1，旧 format/version 结构化拒绝，不读取不迁移）——`f5cdfac6a`；② 真编译轨：`services/export/moonbit_codegen.mbt` 生成可读 MoonBit，预览与 bundle 内 `app/generated_handlers.mbt` 逐字节同源，`compiled_runtime` 执行面 + `services/compile_native` 执行器（moon update→check→wasm-gc build→native build→native 启动存活）——`e64ff3ffe`；③ 显式双轨切换 `RunTrack{Interpret,Compile}` + 独立运行态（`RunModel` vs `CompiledRun`），Web 显式声明 `app.track.unavailable_web`——`36a2de9b7`；④ `services/diff` 双轨差分矩阵硬门（样例×语句类×双语，控件文本/变量终态/审计序列逐项断言，无已知差异清单）——`80d003420`；⑤ `CompileReport` 结构化诊断（文件/行/列/错误码）+ 本地化回渲染 + `CompileJump` 跳回 IR 积木路径 + 控制台重开——`ed4a7dd1c`；⑥ 技术风 UI：`studio_theme()` 钉 Dark + 朱砂唯一强调色、发丝描边、紧半径档、stage/grid/console 专项色、控制台/预览等宽、`Ctrl/Cmd+K` 命令面板（`command_palette.mbt`，`Effect::send` 执行通道）——`102ebe578`。证据：app 76/76 native、`moon check` 0 error、i18n `--check` ok、source-file policy ok（files=1956 review=42 ratchets=62） |
| 2026-09-29 | **双轨真编译目标批次（7 市场叙事 + 8 退出门，收官）**：⑦ 定位页双语文档 `docs/moui-studio.md` + `docs/zh-Hans/moui-studio.md`（三视图同源 IR / 双轨语义表 / 编译轨五步 / 差分门 / 技术风 / 四竞品对标表 + 固定差异三句），`docs/INDEX.md`、`docs/examples.md`、`docs/zh-Hans/examples.md`、`website/docs-catalog.json` 同步挂载（website sync 50 条）；⑧ 退出门证据：app 76/76 native + 76/76 wasm-gc、domain/services 全包绿（ir 15 / studio_lang 31 / codec 5 / proposals 21 / blocks 13 / export 22 / compiled_runtime 1 / diff 3 / model_provider 6 / provider_native 3 / compile_native 2）、web_wasm wasm-gc build ok、macos_skia native build ok、`sh scripts/studio-export-smoke.sh` ok（native+wasm-gc）、`sync_kernel --check` current、i18n `--check` ok、六项静态 validator 全绿，`studio compile native tests` 入 pr profile；`moon fmt --check` 收敛全部漂移，`moui/core/pkg.generated.mbti` 补 `on_tap_with_frame` 漂移 |
| 2026-09-28 | 冻结后批次（分析清单落地）：① **吸附完善**——移动无参考线命中时落 32px 网格（与点阵一致，参考线 4px 优先、delta-0 精确对齐也算命中）；新增 snap_resize_position：缩放时**移动边**按角位向参考线/网格钳制后再缩放（对角固定与夹取不变）；② **审计↔积木双向跳转**——运行视图审计条目可点（AuditJump），切积木视图并选中 detail 匹配的语句（与聚光灯同款匹配），越界安全；③ **键盘快捷键**——调查确认 MoUI 已有 KeyboardShortcut modifier + runtime 全窗口分发（ADR 0033 键盘策略），无需新通路；撤销/重做换 @views.shortcut_button（Ctrl+Z / Ctrl+Shift+Z 徽标可见，链式追加 Cmd 变体兼容 macOS——shortcut 按修饰键精确匹配需各注册一份）；空栈撤销/重做 no-op 有测试；④ **积木画布（拼图视觉 + 同层拖拽重排）**——积木视图从 widget 行改为 canvas 绘制（设计画布同契约）：榫头/卯口拼图外形 + 分类配色 + 深度缩进 + 选中描边 + 聚光灯；按下抓取同层拖拽（朱砂落槽线随指针移动）、松手经 @blocks.reorder_stmt（克隆语义、list_path 寻址：顶层/then/else-if 臂/else/循环体）重排，选中跟随移动块；跨层移动不在 v1；⑤ **修复真 bug**：commit_block/delete_block 用就地 replace/delete 直接改共享 body 数组——**撤销快照被污染**（恢复的是改后语句），改为 clone_stmts 后手术并加 program_signature 回归测试；⑥ macOS 入口 native 构建通过 + 进程启动存活。测试：app 54×2、blocks 13×2 全绿；六静态门 + i18n --check 绿；积木画布/重排/快捷键徽标 web 实测截图验证 |


| 2026-09-29 | **CI 全绿与仓库收尾**：① 删除 `examples/deepseek_harness_desktop` 子模块（官方版已独立发布）——`.gitmodules`、`moon.work` 成员、`examples/catalog.json`、双语文档与 memories 引用全部清理，`validate-doc-references` 112 文件全解析；② Windows MSVC 构建改走 `MOON_CC=<VS 自带 clang-cl.exe>`（MoonBit CLI 对 MSVC 桩编译无条件注入 `/std:c11`，与 Skia 桩需要的 `/std:c++20` 在 cl.exe 上冲突 D8016；clang-cl 同时接受两者并由 moon 自动配同目录 `llvm-lib.exe`），`moui/scripts/windows/msvc_env.ps1`、`moui_skia` 三个 smoke/triangle/text helper、`windows-platform-evidence.sh`、`build.js` 与 Windows 平台文档同步换轨；<br>③ 顺带修出真实缺陷：`win32_timer_host.c` 的 `timeBeginPeriod/timeEndPeriod` 在 `WIN32_LEAN_AND_MEAN` 下缺 `mmsystem.h` 声明——cl.exe 只警告，clang-cl 报错 `call to undeclared function`，已显式 include。**CI 证据（commit `ca088d521`）**：MoUI CI（含 Windows MSVC native smoke、PR profile gate、MoonBit workspace baseline）success；MoUI Renderer Real Skia CI success；MoUI Skia Provider Real Skia Acceptance（Windows static+dynamic）success；MoUI Feature Proof Summary success。本地关门复跑：app 76/76 native + 76/76 wasm-gc、domain/services 全包绿（ir 15 / studio_lang 31 / codec 5 / blocks 13 / proposals 21 / export 22 / compiled_runtime 1 / diff 3 / model_provider 6 / compile_native 2）、`web_wasm` wasm-gc 与 `macos_skia` native 构建 0 error、`studio-export-smoke.sh` native+wasm-gc ok、六静态 validator 全绿、`sync_kernel --check` current、i18n `--check` ok、`check-generated-interfaces` 224 包零漂移 |
| 2026-09-29 | **混色缺陷根治批次（ADR 0036，用户截图触发）**：用户 13:09 截图实测暴露白字白底（1.16:1）——根因是声明期组件经 `views_ambient_theme(None)` 回退中性浅色主题烘焙表面色，而文字在绘制期读环境暗色主题。修复 = 框架 ambient 契约（container/card/divider/toolbar/choice_groups，见 ADR 0036 与计划 decision log）+ app 侧三项（根底色/钉主题/顶栏重排）。验证：views 37/37 native、container+divider 17/17、app 76/76 native + 93/93 wasm-gc（含 container/divider）、domain/services 117/117 native、`check-generated-interfaces` 224 包零漂移、`moon fmt --check` 干净、sync_kernel/i18n `--check` 绿、`studio-export-smoke.sh` ok；web 1280×832 截图实测全部文字 ≥5.3:1（多数 14–18:1）、三视图+命令面板交互复查通过。注：release-closures 与 guidance 两 validator 的失败是并行的版本 bump（moui/window 0.2.0）连带，与本批次无关 |

| 2026-09-30 | **沉浸式无边框 + 差异修复批次（用户六图对比驱动）**：① **响应式布局缺陷族**（全部由新的**裁剪感知** `overflow_report` 测试助手发现，而非肉眼看截图）：顶栏在窄窗溢出（`status_cells` 写死 112pt/格 → 按文字实测宽按比例收缩）、右栏从 872px 起被挤出窗口（新增 `ShellChromeWidths` + `shell_chrome_widths`：宽窗用设计值，窄窗右栏收到 232，再窄则**收起左栏**）、右栏 4 处仍读死 `RIGHTBAR_WIDTH` 导致上一修无效、上下文 tab 行 `(width-12)/5` 恰好占满 272 无内垫（改为扣除 4 个间距）、快速操作 `@views.button` 被最小宽撑到 88px（手搓 `ai_action_chip`）、代码页脚按钮被截成「按 IR 重渲」/「编译 MoonB」（按文字实测宽给宽）、积木栏被压到 160px（`visual_workspace` 最小宽规则 + 单栏回退）；② **代码视图居中对齐修复**——`code_line_row` 内层 row 量到自身内容宽、被容器居中，行号在 x=205 而代码在 x≈460；加 `.frame(width=)` 后代码贴到 gutter 右侧，并加「gutter 与代码两列左对齐」回归测试；③ **设计舞台与背景板缩放失步**——`StageLayout::layout` 用 `constraints.min`（测量期为 0）推缩放，得 1.0，而 `canvas` 的 `auto_fit_measure` 用 `constraints.max`；改为统一的 `fit_scale(max…)`；④ **沉浸式无边框窗口**——`WINDOW_CHROME_HEIGHT=26` 顶带置于顶栏**之上**（不挤占 IDE 操作面）+ `transparent_titlebar` 接线到 `@macos.entry(options=…)`；⑤ **关键取舍修正**：`transparent_titlebar` **不隐藏系统信号灯**，自绘三个点会叠成六个、且缩放按钮无后端请求（`WindowRequest` 无 zoom 变体）——改为**用系统信号灯 + 让出 `TRAFFIC_LIGHT_INSET=78`**，删掉自绘点与随之失效的 `WindowClose/WindowMinimize/WindowZoom/WindowDragBy` 死消息链；拖拽按 `docs/invariants.md` P10（drag decode 属平台本地）交由 `set_drag_region` 处理，**不走 WindowRequest**（`performWindowDragWithEvent:` 需要 `mouseDown:` 内的活事件，排队式必失败）；⑥ **IR 映射竖条**（设计稿 `#irRuler`）——从「一行行号芯片」改为**按行号对齐的竖排色块**（canvas 绘制，stack/align 无法任意偏移），空间上呈现「哪几行属于同一条积木」；⑦ 补齐代码说明条（设计稿 `#codeFoot`）、窗格关闭按钮、运行徽标、`IR 映射 · 与代码同步` 副标题。测试 120→123（新增 immersive 两条 + 胶囊内垫一条），native + wasm-gc 双目标全绿。**教训**：写断言后必须**故意破坏一次**确认它会红——「顶带里不许有小圆角方块」抓不到自绘信号灯（圆点与顶带合并成一次填充），改用「提示文字 x >= TRAFFIC_LIGHT_INSET」的可观测代理后，把 inset 改 0 立即报 x=45 |

| 2026-09-30 | 分类轨改**竖排**（设计稿 `#catbar` 86pt，色点 + 名称 + 选中强调边），并排在画布左侧而非压在上方 | 横排芯片条白吃 30pt 画布高，积木视图纵向最紧 | 积木画布可用高 +30pt |
| 2026-09-30 | 积木块体与标签按画布宽夹取 + 省略号截断（`fit_label`，`blocks_item_rects(avail_width=)`） | 块宽写死 430，1280 窗口下画到右栏上（实测文字右缘 1289 > 裁剪区 1164） | 块不再越界，长语句显示「…」 |
| 2026-09-30 | 积木窗格脚注（设计稿 `#blocksFoot`） | 补设计稿要素，并解释画布底部留白是**有意的 AI 避让通道** | 设计对齐 |
| 2026-09-30 | 文字宽度估算标定修正：主题正文是 **16pt**，估算口径偏窄 ~2% | `fit_label` 曾按 12/13 折算，预算虚高 8%，「截断了却还溢出 5pt」 | 所有按估算分配宽度的格子不再贴边溢出 |
| 2026-09-30 | 截断扫描补两个盲区：无裁剪区文字、跨窗格文字 | 原扫描只看有 `PushClip` 的文字，积木脚注（无裁剪区）越界 5pt 却是绿的 | 三段互补断言 |
| 2026-09-30 | 代码行 ↔ IR 映射**悬停联动**（设计稿 `irHl`）落地：新增瞬态 `hover_path` + 复用框架新增的 `View::on_hover` | 设计稿脚注承诺「悬停查看 ↔ 行映射」，此前只有点击；且需要框架先有逐元素 hover 能力 | 悬停代码行/右缘色块即高亮对应路径，离开还原；与驻留点击高亮互不干扰 |
| 2026-09-30 | 框架新增 `View::on_hover`（`moui/core/modifier_hover.mbt`，透明观察者，仅状态翻转时发消息） | Studio 需要逐元素 hover；这是设计稿多处交互的前置能力 | 所有 app 可做悬停反馈；core/runtime 各自新增测试 |
| 2026-09-30 | IR 映射竖条从**一整块 canvas** 改成**逐行可命中单元**：每行各自持有 `on_hover`（瞬态预览）+ `on_tap`（驻留高亮） | 脚注承诺「悬停色块看映射」，而 canvas 是纯绘制节点、`on_hover` 只给 Bool 拿不到指针位置，悬停方向**永远做不出来**；逐行单元同时让对齐变成天然（两列同为 20pt 行高） | 悬停/点击右缘色块都能双向高亮代码行，已用真实浏览器验证 |
| 2026-09-30 | 截断/交互测试补「绘制指纹」比较（`paint_signature`） | 只比 update 状态的断言会漏掉「状态对了、界面没变」——实测把 `hover_path` 从视图里删掉，update 断言全绿 | 视图层回归可被抓住 |
| 2026-09-30 | 单窗格加**恢复带**（设计稿 `#btnAddLive`/`#btnAddBlocks`）：隐藏一个窗格后顶部出现「+ 另一个窗格」 | 单窗格分支原本直接 `return live_pane(...)`，「隐藏此窗格」点了之后那个窗格**再也回不来**，只能重启——真实可用性缺陷 | 隐藏↔恢复往返可用，已用真实浏览器验证 |
| 2026-09-30 | 无边框窗口的**拖拽区**打通：`moui/services` 新增 `WindowDragRegionSource`（声明式状态 + revision 去重），Studio 在视图构建期声明顶部 26pt，宿主 loop tick 下发 AppKit | 无边框窗口没有标题栏，不接这条通道就完全没法移动窗口 | app 侧写、宿主侧读、真窗口路径已通；原生手势需人工确认 |
| 2026-09-30 | 沉浸式标题栏**合并**为一条 56pt（原 26 窗控带 + 40 顶栏两条，交界有色缝、上半条空置） | 用户对照 IDEA 指出「最上面的窗口边框不沉浸」 | 已改；`window_chrome_bar` 删除，`WINDOW_CHROME_HEIGHT` 语义改为标题栏总高 |
| 2026-09-30 | 拖拽区避开右侧动作簇（`topbar_drag_width`），估算改取**上界** | 命中拖拽区的事件不再进入运行时，盖住按钮会让它们变成拖窗口；实测按 1.02 补偿仍差 8pt | 中英双语 × 四档宽度各留约 41pt 余量；两条测试故意破坏均失败 |
| 2026-09-30 | `shell_rects` 补收 brush 变体（第三类扫描盲区） | 只收 `FillRect`/`FillRoundedRect` 导致「按钮盒在哪」的断言静默落空 | 已修；该盲区曾让一个真实缺陷漏过一轮 |
| 2026-09-30 | AI 药丸居中（原贴右下角，偏 313pt）+ 定位层改 `center` | 设计稿 `#aiLayer` 是水平居中；无背景 container 会铺不透明底板 | 已改；宽度改按内容累加以适配中英文 |
| 2026-09-30 | 窗格头宽度分配改为**单一计算源** `pane_head_layout`（原写死 90/120/140） | 积木窗格头固定需求 444 > 窗格 398，尾巴「IR 映射 · 与代码同步」被裁 71pt | 已修；新增「窗格头文字不越出自己的窗格」测试 |
| 2026-09-30 | 积木编辑条按钮宽度改 `button_label_width`（原写死 64） | 按钮实际要 92.8，配合 `w-190` 使总宽 = w+22，删除按钮盒 932..1028 越出窗格右缘 1006 | 已修；新增「编辑条塞进积木窗格」测试（比**按钮盒**不比文字） |
| 2026-09-30 | 记录**第四类扫描盲区**：窗格头不在裁剪区内，溢出后被兄弟面板盖住 | 既有两道扫描（窗口边界 / 未裁剪）都抓不到 | 新测试按窗格 x 范围直接断言 |
| 2026-09-30 | `workspace.mbt` 1162 行拆为 `workspace.mbt`(593) + `code_view.mbt`(578) | 逼近 1200 硬上限 | review 队列 46 → 45 |
| 2026-09-30 | 面板头尾部动作贴右缘（标题改内容宽，余量交给权重 spacer） | 左栏关闭 ✕ 离右缘 40pt，看起来「位置不对」；且标题吃满剩余会让该约束无法被单独破坏 | 新增「尾部贴右缘」测试，故意改 weight=0 会红 |
| 2026-09-30 | `panel_head` 尾部预留按实际控件宽（`trailing_widths`） | 统一按 22 预留使 56 宽的计数徽标越出右缘（w=1440 时 x=1407） | 已修 |
| 2026-09-30 | 删除顶栏四色 logo（`brand_mark`） | 无边框窗口里紧挨系统信号灯，视觉嘈杂且无信息量 | 纯删除，不写绘制断言（该 logo 会合并成一次填充，断言抓不到） |
| 2026-09-30 | 新增 `ClearSelection`（设计稿 `#clearSel`） | 只清控件会让右栏回退显示上一个子程序，用户以为「点了没变」 | 同时清 handler/block；新增测试 |
| 2026-09-30 | 积木窗格跟随选中（`blocks_pane_wanted`） | 没选子程序时积木必然是空画布却占一半中心列；`SelectControl` 需同时清 handler 才能真的跟随 | 已修；新增 3 段测试 |
| 2026-09-30 | 删除单窗格恢复带，恢复入口统一到空舞台（设计稿 `#btnAddLive`/`#btnAddBlocks` 语义） | 那条带子是实现者自加的、设计稿没有，凭空多一条工具带并挤掉舞台高度 | 新增 `ShowPaneLive`/`ShowPaneBlocks`（幂等显示 + 切回 WsVisual + 选首个 handler） |
| 2026-09-30 | 空舞台按钮改按内容宽 + 折行（`empty_stage_button_rows`） | 5×150+4×10=790 > 中心列 724，`+ 积木窗格` 被裁 | 已修 |
| 2026-09-30 | `shell_responsive_wbtest.mbt` 1225 行拆出 `pane_lifecycle_wbtest.mbt`(538) | 超 1200 硬上限 | review 队列 45 → 44 |
| 2026-09-30 | 右栏头 ✕ 改为「关闭整个右栏」；清空选中移回对象名旁（设计稿 `.objchip` 内） | 上一版把 `ClearSelection` 放在整行最右端，那正是关闭面板按钮的位置，点它面板不动 | 新增 `right_visible` + `SetRightVisible`；右栏与分隔线一并收起，图标栏可重开 |
| 2026-09-30 | 右栏新增收起能力（原先完全没有） | `shell_chrome_widths.right == 0.0` 表示收起，中心列吃掉这份宽度；命令面板加 `studio.right.toggle` | 已修；新增测试（两个 ✕ 语义分离 + 真能收起/重开） |
| 2026-09-30 | **AI 卡二次精简（用户三点反馈：标题行多余 / +@提示难看 / 输入框应两行）**：① **删掉整个头部**——「AI 提案 / 底部居中 / 离线模型」标题行与 5 个图标全部移除，浮层输入盒不需要标题栏（Codex 口径）；停靠/收起/历史收敛为输入盒脚注的 ghost 图标（停靠态=浮出，窄卡只留收起），锚点循环与 provider 设置走命令面板。② **删掉 +@上下文芯片行**——快捷建议与可移除芯片整体移除（用户判定无必要），模型消息保留、仅视图路径删除。③ **输入区改两行文本域**——`text_area(lines=3, line_height=20, on_submit=ComposerRun)`，Enter 直接发送；**高度必须含 text_area 内部 8pt×2 垂直内垫**（首版 lines=2×18=36 扣内垫可见仍是一行，用户抓到），`COMPOSER_HEIGHT` 98，回归断言「占位→发送垂直距离 ≥50pt（单行 ~30）」破断验证。空闲卡高 **110**（避让带 134）。④ 测试锚点从「AI 提案」标题迁到输入盒占位文案「描述你想要的应用」（6 处），「底部居中」读数断言删除；app 150×2 全绿 | 卡片 = 一个输入盒 + 线程卡，无任何标题 chrome |
| 2026-09-30 | **AI 卡现代化（用户反馈「不好看」，参考 Codex/ZCode）**：① **输入盒**——裸文本框 + 外挂按钮行改为圆角 8 输入盒（ide_panel 底 + 发丝边框）：盒内 = `Plain` 无边框输入 + 盒内脚注（模式胶囊芯片靠左、**圆形强调色发送钮**靠右，忙碌变灰禁用）；宽窄卡同构不再分支，`composer_height` 恒 64。② **无缝头部**——`ide_panel_alt` 色条 + 5 个方块图标改为与卡片同色的 **ghost 图标**（新 `ghost_icon_button(surface)`，选中才点亮），头部融入卡面。③ 圆角语言统一：卡片 6→10、线程/审计卡 4→8、hero 示例芯片改胶囊（10）。④ 断言基建：发送改图标后无「发送」文字，新增 `shell_find_send_button`（按「强调色实心圆 w=h≈24」的绘制指纹定位），5 处旧文字断言迁移；破断验证（发送恒禁用 → 3 测红）。预算不变：空闲卡 132 ≤ 140 钉死 | 视觉对齐现代 AI 工具；结构契约全部有测试守门 |
| 2026-09-30 | **中心工作区重构（用户截图驱动：可视化编辑 + 积木 + AI 对话布局失调）**。三个成因与修法：① **AI 浮动卡常驻 chrome ~190pt**——工具行（切换锚点/停靠右栏/收起）与头部图标功能完全重复、状态行只有「待命」两个字、输入条三层堆叠。改为成熟 AI 面板口径（Copilot/Cursor）：常驻 = 头部（标题 + 锚点读数 + 假模型徽标 + 锚点/收起/停靠/历史/设置图标）+ 单行输入条（模式段｜输入｜发送，窄卡折两行）+ 按需的芯片行/决策行/线程区；空闲卡高 190 → **102**（避让带 126），历史入口进头部，忙碌态由发送芯片表态，`composer_height`/`context_chips_height`/`decision_bar_height`(空=0) 全部单点计算。② **积木窗格两条常驻截断提示行是噪音**（脚注 + 编辑条空态）——删除（Scratch/Figma 不在画布上放常驻用法提示），编辑条只在选中语句时出现，`blocks_body_height` 单点计算；连带修真缺陷：**scroll_view 把短于视口的内容垂直居中**，块链一短就悬浮在画布中段——画布高度取 max(内容高, 视口高) 顶对齐（Scratch 口径）。③ **Live 舞台信箱式留黑**——640×480 拟真窗口在宽窗格里居中，四周死黑。改 Figma 式**满幅点阵画布**：新增 `stage_mapping`（fit_scale [0.5,1] + 居中原点）单一映射，背景/控件层（StageLayout）/覆盖层/指针换算四处共用；点阵晶格从舞台内容区向四周铺满窗格并与舞台内部网格连续，白色窗口浮在画布上；参考线只画在舞台范围内；顺带修两个既有缺陷：`auto_fit_measure` 不钳 1.0 而 StageLayout 钳 1.0 的缩放失步隐患（solo 窗格才暴露）、覆盖层 GuideH 漏加标题条偏移 34pt。回归：新增 3 测试（满幅画布居中+晶格、AI 卡空闲 ≤140、无常驻提示行），居中断言破断验证（映射改顶对齐 → 红 30 vs 230）；app 150×2 目标全绿 | 中心区三层各归其位：画布满幅、积木顶对齐、AI 卡只占一行输入 |
| 2026-09-30 | **沉浸标题栏高度由信号灯位置决定（56 → 32）**：用户截图指出「系统信号灯和顶栏其他图标高度不一致」。根因：`transparent_titlebar` 不给移动信号灯的能力（自绘是死 UI、挪系统按钮要碰私有层级），AppKit 把三灯圆心固定在窗口顶往下 **15.8pt**（实测），而 56pt 带子把内容居中在 28——差 12pt 成两条线。修法：带高取 2×15.8≈**32**，内容垂直居中即与灯共线（macOS 原生紧凑标题栏口径）；新增 `TRAFFIC_LIGHT_CENTER_Y = 15.8` 常量，测试从「下移增量的一半」改为「run 标签/品牌中心落在灯线上 ±2.5」，故意破坏验证（改回 56 → 红，报 run 中心 28） | 信号灯与标题/芯片读作同一行；拖拽区（高度=WINDOW_CHROME_HEIGHT）随动 |
| 2026-09-30 | **六项 UI 批次（框架语义叠加 / 去朱砂 / 顶栏紧凑化 / 舞台产品主题 / AI 层修正 / 固定宽根治）**：① **框架修复**：`ModifierViewNode::semantics()` 从「替换子节点」改为**叠加合并**（`ViewSemanticsInfo::overlaying`：modifier 显式设置的字段获胜，composition/text 不从子节点继承）——`.semantics_role(TreeItem).on_hover(...)` 读回 role 不再是 None；core 新增 3 测试，runtime 146 / views 37 全绿；`moui/core` mbti 棘轮 +1/+1（`checks/api-surface-report.json` 与 `tools/moui/validate_api_surface` 同步）。② **去朱砂**：`studio_theme()` 主色改 `ide_accent()`（IDE 蓝 #3574F0，IDEA/VSCode 口径），设计画布选中描边/名牌/手柄与积木选中/聚光灯的朱砂字面量全部改 `ide_accent()`；审计语义色点保持独立语义色。③ **顶栏紧凑化**：`@views.button`（声明 28 实渲 36）换成 24pt 高 / 13pt Caption 字的 `topbar_action` 芯片，运行=唯一强调色填充主行动作、单步可禁用；`topbar_chip_bound` 与 `topbar_actions_width`/拖拽区共用同一计算源。④ **舞台产品主题**：`stage_layout`（设计/运行舞台唯一构造点）套 `.theme(studio_product_theme())`（浅色+IDE 蓝），runner 模板 `runner_theme()` 同值内联（sync_kernel 同步）——设计所见 = 运行所见 = 导出应用所见；拟真浅色舞台上不再出现暗色控件。⑤ **AI 浮动层**：居中锚改对称权重 spacer 居中（旧实现贴中心列左缘，破断实测偏 22pt）；决策条/线程卡的 `@views.button` 换 `action_chip`（严格等高），`decision_bar_height` 同步（36pt 实渲按钮曾超预算）；发送/模式段/工具行芯片宽度全部按文案实测。⑥ **固定宽根治**：新增 `wrap_text_lines`/`hint_lines_view`（拉丁按词、CJK 逐字贪心换行）治长提示溢出（英文 `app.ai.key_hint` 766pt 曾装 392pt 行），`empty_hint` 改签名 `(label, width, height)` 并最多 3 行；紧凑条（决策条错误行/审计 gate_hint/代码脚注/ai.no_context）走 `fit_label` 截断；`count_badge`/`panel_head` meta/`topbar_brand`/`tab_button`/设置对话框按钮等改按内容宽。回归：新增 `app/ui_regression_wbtest.mbt` 5 测试（AI 卡居中、舞台产品主题、换行器、芯片宽），**两条关键断言按纪律故意破坏验证会红**（居中锚改回单 cell → 红 -22pt；舞台主题改回暗色 → 红 r=0.9）。全量：app 147×2 目标、core 110、runtime 146、views 37、domain/services 全包绿、六静态 validator、i18n `--check`、sync_kernel `--check` 全绿 | 中英双语界面在任何宽度不再截断/溢出；IDE 视觉统一为「中性深壳 + 单一蓝强调」；框架语义叠加让 hover 与 role 可共存 |
