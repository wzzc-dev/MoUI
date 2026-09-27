# MoMao（墨卯）——中英双语的积木/代码同源可视化编程环境

- Status: active
- Goal: 用单一产品取代 `examples/moeui_studio` 与 `examples/moblocks_studio`：
  一个中文优先、IDE 界面中英双语的可视化编程环境。一份带 schema 版本的程序 IR
  同时支撑「窗体设计 / 积木编排 / 双语代码」三种编辑视图与结构化 AI 提案，
  运行期带安全闸门，产物可导出为独立 MoUI 应用。落位 `examples/momao`，
  项目格式 `.momao.json`。
- **可读性是一等公民**：AI 生成的程序必须能被人类看懂——每个生成的
  handler 必须携带双语「意图说明」，代码按规范格式渲染，AI 面板提供
  「解释这个程序」的逐语句人话讲解；可读性是验收项，不是锦上添花。
- Non-goals（v1 冻结范围）：游戏/动画/精灵系统；多窗体；作品内容本地化
  （项目内按钮文案等字符串）；移动端入口；真实网络外发（`提交数据` 是闸门化
  模拟动作，只记录审计）；MoBlocks 式工作流重试/超时状态机；MoonBit 源码导出
  （v1.1 路线图）；断点调试器；RTL。比赛版只做「表单类应用」域。

## 1. 产品定位

**名字**：MoMao，墨卯。墨 = 中文书写；卯 = 榫卯——一凸一卯、互相咬合的传统
构件工艺，是积木的东方本源。产品形态 = MoMao Studio（Web 与 macOS 双入口）。

**一句话**：用人话描述，用母语编程，用积木理解，做出真正能跑的跨平台应用。

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
   │        单一程序 IR (.momao.json)   │
   └── 积木视图（Scratch 式，类型端口）──┘
   └── 代码视图（MoMao DSL，中/英关键字）┘
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
`memories/repo/momao.md`）：

- **顶栏**：项目名（可改）、语言切换（中文 / English，按钮显示目标语言）、
  模板库、保存/打开（`.momao.json`）、导出独立应用、运行/停止、帮助。
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

`.momao.json`，`format: "momao.project"`，`version: 1`（单一版本常量，
自带迁移政策声明；取代 `.moeui.json` 与 `.moblocks.json` 两套格式）：

```moonbit
pub(all) struct MomaoProgram {
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

## 4. MoMao DSL：中英双语关键字

词法/语法/解释器由 `domain/momao_lang` 持有（salvage `moe_lang.mbt`），
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
  `examples/momao/.config.json`**（`{ "provider": { endpoint, model,
  api_key } }`，已在根 `.gitignore` 登记）：native 组合根启动时读取并预填
  provider 面板，面板内仍可改；`services/provider_native` 提供
  `load_provider_config`（native-only，`x/fs` + 纯 JSON 解析）与一个
  **可选 live smoke 测试**（读到配置才跑、否则跳过）。key 禁止进入源码、
  `.momao.json`、导出 bundle（测试断言）；web 入口不读配置、只暴露假模型。

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
导出的应用**自带解释器可跑**，与 IDE 共享逐字节相同的内核快照。
- 内核集收缩为 3 个：`domain/ir`、`domain/momao_lang`、`domain/codec`
  （导出的应用不需要 IDE/积木/提案，MoBlocks 的 5+1 内核是自由图模型遗留）。
- 漂移门重新注册进 `checks/profiles.json` 的 pr profile（P0 已随 MoBlocks
  删除移除旧条目，新增条目在 P3 落地时补：`moon run
  examples/momao/tools/sync_kernel --target native -- --check`）。
- v1.1 路线图：IR → 可读 MoonBit 源码的预览级导出（文本生成、不真编译），
  即「毕业通道」叙事的产品化。

## 9. 国际化（zh-Hans + en-US）

- 用 `wzzc-dev/moui_i18n`（locale 归一化 / catalog 查找 / 回退 / 具名插值 /
  count 规则）；catalog 源 `examples/momao/app/i18n/{en-US,zh-Hans}.json`，
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

`examples/momao`（独立 module + moon.work 成员 + catalog 条目）：

```text
examples/momao/
  README.md（双语）  THIRD_PARTY.md  NOTICE  moon.mod
  domain/ir/            程序 IR + 不变量 + 预算（纯 MoonBit，零依赖）
  domain/momao_lang/    lexer/parser/printer/interpreter + 双语关键字表 + 结构化错误
  domain/codec/         .momao.json 编解码（ir + lang + core/json）
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
- 框架扩展（按需允许）：MoMao 如需 MoUI 框架本身不具备的能力，可直接为
  框架增量——新控件走 `moui/views` 的具体 `@core.ViewNode` 实现 +
  `@core.View::from_node`（不新增 core 视图枚举变体），按 framework skill
  流程带测试与文档，并同步 `moon test moui/views --target native` 与
  `validate_api_surface` 预算。默认仍优先用现有控件 API组合，框架改动
  需在本计划的 decision log 记录理由。
  （text_field/list/table/button/checkbox）。

## 11. 迁移映射（前代 → MoMao）

`examples/moeui_studio`（约 4.8k 行）：

| 前代文件 | 去向 | 动作 |
|---|---|---|
| `app/moe_lang.mbt`（1222 行） | `domain/momao_lang/` 拆分 | 移植全角归一化/步数预算；拆 keywords/lexer/parser/printer/interpreter/errors；加英文关键字表、结构化错误、`随机数/询问/追加行/取所选行/提交数据` |
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
| `services/export/` + `tools/sync_kernel` + `tools/emit_bundle` + runner 模板 | 同名保留 | 内核集收缩为 ir/lang/codec；runner 模板按 MoMao IR 重写 |
| `fixtures/` 镜像模式 | `examples/momao/fixtures/` | 保留（MoonBit 测试环境无同步文件读取） |
| `THIRD_PARTY.md` / `NOTICE` | 同名保留并扩写 | 追加易语言「仅概念参考、无代码/资产复用」声明；scratch-editor 维持架构研究声明 |

**P0 已执行的仓库手术**（2026-09-27，随本计划同一 PR）：删除
`examples/moeui_studio` 与 `examples/moblocks_studio`；`moon.work` 移除两个
成员（顺带修复 moeui_studio 缺失 catalog 条目的漂移）；`examples/catalog.json`
移除 MoBlocks 条目；`checks/profiles.json` 移除 "export kernel sync" 旧条目；
`docs/examples.md` 移除两行；重生成 `docs/repository-facts.md` 并同步
website 副本；三个前代计划归档至 `docs/plans/done/` 并标注被本计划取代；
`moui/runtime/row_child_pointer_input_test.mbt` 的场景来源注释改为中性表述；
`memories/repo/moblocks-studio.md` 重写为 `memories/repo/momao.md`。

## 12. 内置样例与教学材料

1. **点名册**：班级名单 → 随机抽取 → 信息框展示（`随机数`/列表框）。
2. **口算训练营**：随机出题 → 作答校验 → 计分 → `询问` 重来（循环+分支）。
3. **班级小卖部**：表格商品 + 库存增减 + 营业额标签 + `提交数据` 闸门演示。
4. **问候**：最小 starters（按钮改标签文本）。

每个样例一份一页教案（目标/步骤/可提问的拓展）随仓库 `examples/momao/samples/`；
README 双语含 5 分钟 Quick Start。

## 13. 测试与验证策略

- 双目标（native + wasm-gc）：`domain/*` 与 `app` 全量测试；入口
  `moon build examples/momao/web_wasm --target wasm-gc` +
  `moon check examples/momao/macos_skia --target native`。
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
- **报名口径**：一个仓库一个产品，只报 MoMao，不把两个前代并列提交；
  前代以「 salvage 来源」身份存在于本计划与 git 历史。
- **AGPL/商标边界**：THIRD_PARTY.md 照前代成文做法——只研究
  scratch-editor 的架构与交互模型，不复制源码素材，与 AGPL 无衍生关系；
  易语言为闭源产品，仅概念参考，不复制代码、素材与商标。
- **全局依赖警告（待办，不阻塞 MoMao）**：`examples/mo_workbench` 依赖
  已弃用的 `bobzhang/openseek@0.2.2`（连同 `bobzhang/jsonl@0.2.0`），
  污染所有 `moon` 命令输出。修法：mo_workbench 的 moon.mod bump 到
  `moonbitlang/openseek`，`openseek_native_transport/moon.pkg` 的 6 个
  import 路径同步改（agent/agent_runtime/agent_session/agent_session/
  store/deepseek/prompt），`moon update` 后跑 mo_workbench 测试验证兼容。
  2026-09-27 决定：不在 MoMao 时间盒内修，仅记录。

## Acceptance

- [x] `moon test examples/momao/app --target native` 与 `--target wasm-gc` 全绿
- [x] 三个样例在 Web 入口离线可玩（假模型）；macOS 入口从
      `examples/momao/.config.json` 读取 StepFun 配置预填面板，live smoke
      测试可跑通，且 `.config.json` 被 gitignore 覆盖、key 不入任何产物
      （2026-09-27 补齐 live smoke：`provider_live_completion` + 跳过式
      async test；顺带抓到并修复真实 provider 404——base URL 未拼
      `/chat/completions`，`@provider.completion_url` 统一组装，
      StepFun step-5-preview 端到端首次打通）
- [x] AI 生成程序的可读性验收：每个生成 handler 带双语 note；无语义命名
      （`a1`/`tmp` 类）被校验拒绝；同一 IR 渲染逐字节稳定（快照测试）；
      「解释这个程序」对三个样例给出正确讲解
      （讲解机制有测试锁定；三样例×双语覆盖可作廉价补强）
- [x] 导出 bundle 在工作区外 `moon build` 可跑，sync_kernel `--check` 零漂移
- [x] 中/英界面切换 + DSL 双语关键字往返一致测试通过
- [x] `提交数据` 闸门在确认前无任何真实外发（审计可证）
- [x] 静态 trio 与 catalog `--check` 通过；pr profile 重新注册 MoMao 漂移门
- [x] README 双语 + DSL 规范 + IR schema + 教案齐备

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-27 | 产品定名 MoMao（墨卯），取代 moeui_studio/moblocks_studio，落位 examples/momao |
| 2026-09-27 | IR 为语句级（非自由图）；积木是 IR 投影而非第二事实来源 |
| 2026-09-27 | 内核语言中立：可读文案一律 catalog key，界面层本地化 |
| 2026-09-27 | v1 外发动作为闸门化模拟，不做真实网络请求 |
| 2026-09-27 | 双语关键字表 + 往返一致测试为 DSL 硬约束 |
| 2026-09-27 | 真实模型默认阶跃星辰 StepFun（endpoint `api.stepfun.com/step_plan/v1`，model `step-5-preview`），凭据唯一来源为 gitignored 的 `examples/momao/.config.json`（native 组合根启动读取、live smoke 测试按存在性跳过），假模型仍为默认模式 |
| 2026-09-27 | 可读性为一等目标：handler 双语 note 必填、命名自解释、确定性渲染、「解释这个程序」讲解功能 |
| 2026-09-27 | 允许按需扩展 MoUI 框架本身（新控件走 `moui/views` 的具体 `ViewNode`，core 不加枚举变体），决策需记录理由 |
| 2026-09-27 | 品牌主题 `momao_theme` 需 `ColorPalette::from_seed`（朱砂 seed 派生全角色盘，手动覆盖派生角色质量更差）——momao app 主导入块引 `wzzc-dev/moui/core`，按 browser/mo_workbench/showcase 先例加入 validate-api-surface 的 shared-app core 导入授权名单 |
| 2026-09-27 | 设计画布手柄优先于控件体命中（按中选中控件角点 ±6px 即缩放）；吸附只做移动（缩放时参考线仅显示）；UI 新建子程序 note 留空——可读性 note 必填是 AI 提案约束；控件/子程序预算（MAX_CONTROLS/MAX_HANDLERS）在 UI 层同样生效，超限设 notice 不静默 |

## Progress

| Date | Note |
|------|------|
| 2026-09-27 | 计划建立；P0 仓库手术完成（删两个前代 + moon.work/catalog/profiles/docs 更新 + 计划归档 + memory 重写） |
| 2026-09-27 | 完善①：接入阶跃星辰真实模型；新增「AI 生成程序可读性」目标与 §7.1 机制、验收项 |
| 2026-09-27 | 完善②：真实凭据走 gitignored `examples/momao/.config.json`（含 live smoke 测试，文件已建）；新增「按需扩展 MoUI 框架」许可与边界 |
| 2026-09-27 | P1 完成：五个领域包（ir/momao_lang/codec/proposals/blocks）双目标全绿 51 测试×2；app 包 TEA + 五视图 + 中英 catalog 双目标 14/14；web/macos 薄入口就位；.momao.json 注册进 moon.work/catalog/examples.md/profiles（漂移门 momao export kernel sync）；教案×3 + 双语 README + DSL/IR 规范成文 |
| 2026-09-27 | P1 收官：services/{model_provider,provider_native,export} + tools/{sync_kernel,emit_bundle} 全部就位（provider_native 含 .config.json 读取与 live smoke，export 8/8，sync --check 绿）；app 导出桩换真 @export；web/macos 入口编译通过且 apply_locale 宿主回调接通；emit_bundle 端到端验证（25 文件 bundle、内核逐字节一致、工作区外独立 wasm-gc 构建 49 任务 0 错误）；moon fmt 后重同步内核；facts/website 重生成；六项静态验证全绿 |
| 2026-09-27 | 补齐四项：①「解释这个程序」（本地确定性讲解 + 真实 provider 路径）；② 界面语言经 SettingsServices 持久化（momao.language）+ 入口 set_environment 同步 Environment.locale；③ provider key 不入 bundle 的测试断言；④ .config.json 路径改为仓库根相对。全量：81 用例×2 目标 + native 2，六门全绿 |
| 2026-09-27 | 收官两项：⑤ i18n catalog 迁移为 generate-i18n-catalogs.mjs 生成（app/i18n/{zh-Hans,en}.json → i18n_catalog_generated.mbt，i18n.mbt 瘦身为 142 行适配器），--check 以 "momao i18n catalogs" 注册进 pr profile，source-file-policy 白名单同步；catalog 全 key 双语解析 + 插值测试进 moon test（漂移可测：改 JSON 后 --check 报 out of date 已验证）。⑥ 积木视图编辑回写：domain/blocks 增加语句路径（BlockItem.path）+ replace_stmt_at/delete_stmt_at/stmt_at，app 增加 SelectBlock/EditBlock/CommitBlock/DeleteBlock，块行可点、语句级 DSL 编辑器应用/删除即写回 IR 并同步代码视图（就地语义已有测试固定）。终态 83 用例×2 目标 + native 2；六门全绿；emit_bundle 端到端三验通过（25 文件、内核逐字节一致、独立构建 49 任务 0 错误） |
| 2026-09-27 | 评审修复四项：① 运行视图受控输入框值回写（ControlChanged 把输入写进 runtime_texts 与 run.state.texts，修「输入不落表、取文本读旧值」）；② 真实 provider 接线收敛为 ProviderRequestSpec（endpoint/key/model/system/prompt 由 app 组装、入口只转发）——同时修掉 system prompt 双重拼接、「解释这个程序」错挂提案 system prompt、面板模型名不进请求体（原硬编码 momao-proposal）三个缺陷；③ 设计视图拖拽落地（CanvasPress 建立偏移拖拽态、DragTo 经 @ir.Control::with_rect_field 夹取移动、Release 清除）+ 检查器位置/尺寸四字段（复用 app.inspector.position/size 键，域侧 RectField + 夹取规则 + MIN_CONTROL_SIZE）；④ README 验证循环改为可用的逐包命令 + 补 NOTICE。新增测试：app 3 例（输入回写/拖拽夹取/属性框编辑）、ir 1 例（with_rect_field 夹取）；domain 命令修正 |
| 2026-09-27 | 首次真实运行验收（web + macOS 双端实测）修复四类问题：① **web 入口 index.html 启动 API 错误**（用了不存在的 default 导出，页面静默卡加载）→ 改为 `bootMouiWasmGcApp({wasmUrl, canvasHost, onStatus})`；② **row 内 Horizontal divider 测量成整行宽并 FillRect 盖住后续兄弟**——画布「不可见」、右栏「消失」、大片灰底的真实根因（Skia/web 双端一致），row 内改用 `divider(axis=Vertical)`；③ **画布绘制契约**：MoUI paint 命令是窗口全局坐标（render 管线不逐层平移），draw 内容须按 `frame.origin` 偏移，measure 固定 640x480 不吃约束；④ **框架新增 `View::on_tap_with_frame`**（moui/core OnTapWithFrameModifier，透明无语义角色，单击带坐标）——拖拽识别器对纯单击不产生事件，画布点选由此补齐；app 增 CanvasTap（命中选中/空白取消、拖拽结束的 tap 以 drag 态区分）。另：顶栏拆两行 + container padding（修按钮贴边溢出）、根视图钉浅色主题（深色系统白字白底）、web 快速上手命令补 HTTP 服务说明。测试 +1（core 102，on_tap_with_frame 行为测试）+1（app 26，tap 选中/拖拽区分）；双端实测：点选/取消/拖拽移动/夹取、检查器字段、模板与语言切换全部通过 |
| 2026-09-27 | 用户反馈微调：左右侧栏内容加 container padding=10（控件面板按钮不再贴窗口左缘，检查器/AI 按钮不再满宽贴缘） |
| 2026-09-27 | 验收清单核验（P4 教学证据按指示暂缓）：当场重跑全绿——domain 55×2（ir 9 / momao_lang 25 / codec 5 / blocks 7 / proposals 9）、app 26×2、model_provider 5×2、export 8×2、provider_native 2（native）；sync_kernel `--check`、i18n catalog `--check`、六项静态验证当场重跑全绿。逐项证据核验后勾选 7/8：往返一致（"round trip zh and en are stable"）、语言切换（SwitchLanguage 往返 + ui_language_from_tag + catalog 双语 key 全解析）、闸门审计（OpGate 暂停/恢复 + app_test "run gate pauses submit and confirm completes"；v1 无真实外发路径——web 仅假模型、native provider 仅用于 AI 提案）、可读性（note 必填 + 命名 blocklist + 确定性渲染 + ExplainHandler 讲解测试）、导出（工作区外构建三验 + sync 零漂移）、文档（双语 README + dsl-spec + ir-schema + 教案×3）。**唯一未勾**：第 2 项的 live smoke 测试从未落地（早期 Progress/记忆声称有，git 历史无此测试，worker_test 仅 2 个 load_provider_config 解析测试）——样例离线可玩（双端实测）、.gitignore:52、key 哨兵断言（app_test "exported bundle never carries the provider key"）、macOS 入口预填（main.mbt load_provider_config）均已证。memory 已同步纠偏 |
| 2026-09-27 | 完善批次落地（计划外追加，四批全部完成）：**批1 质量闭环**——update.mbt 拆分为 update/update_run/update_blocks/update_ai 四文件（1034→630 行，链式 Option 分发，消息构造器互斥）；补 live smoke（provider_live_completion + 跳过式 async test），**首跑即抓到真实 provider 404**：endpoint 是 base URL、手写 @http.post 不会拼 /chat/completions，新增 @provider.completion_url 统一组装（base 拼/全路径原样/尾斜杠归一），StepFun step-5-preview 端到端首次打通；explain 测试扩为 4 模板×双语全覆盖；openseek 弃用依赖记入风险节（决定不修）；**批2 B1**——品牌主题 momao_theme（朱砂 from_seed 派生浅色全角色盘）、模式 tab 换 button_group、文件按钮配图标、三栏卡片化（card）、diff 行 badge 语义 tone、真 checkbox（RunModel.checks + RunToggle）、inline_error；**批3 B2/B3**——积木视图彩色圆角块化（block_fill 分类色 + padding_edges 缩进 + on_tap 选中 + 朱砂描边，替代空格缩进/【】/文本按钮），运行视图窗体框舞台（callout Warning 闸门卡 + 审计时间线色点 audit_dot_color + 隔行底色），SelectTemplate 重置积木选择态；**批4 B4/B5/A4**——画布点阵网格 + 拖拽对齐参考线（alignment_guides ≤4px 容差）+ 四角手柄 + 朱砂选中描边，**抓到第二个真 bug：RealGenerationFinished 无处理器、真实生成结果被静默丢弃**（移入 update_ai 纯域走同一条校验链），ai_busy 加载态（loading_state）；导出回归自动化 scripts/momao-export-smoke.sh（emit_bundle → 临时目录 moon update + 独立 wasm-gc 构建）注册 smoke/gates.json `momao.export-build`（nightly 档）。新增测试 5 例（画布计划/讲解全覆盖/真实生成回写/completion_url），app 29×2 全绿；web+macOS 双端实测通过（积木点选/模板切换/运行闸门/确认卡） |
| 2026-09-27 | 承诺兑现批次（清偿设计画布「画了但没实现」的债 + 教学闭环断点）：① **角手柄缩放落地**——IR 增 `DragCorner` + `Control::resize_from_corner`（对角固定、四角语义各异，夹取与 with_rect_field 同纪律：完整落画布内 + MIN_CONTROL_SIZE），DragState 拆 `Move(offset)/Resize(corner)`，CanvasPress 手柄优先（6px 命中半径）再控件体命中；② **移动拖拽吸附**——`snap_move_position` 复用 alignment_guides 同一目标集与 4px 容差（画线与吸附不分叉），取平移量最小者精确对齐，吸附后仍过夹取（参考线目标都在画布内，不会越界）；③ **新建子程序入口**——`CreateHandler(control, event)`（控件存在 + 事件受支持 + (控件,事件) 不重复 + MAX_HANDLERS 预算内建空子程序并选中），左栏对选中控件列出「支持但尚无 handler」的事件按钮（catalog 里 `app.handler.new`/`event.*` 键早已备好、首次接线）；④ **i18n 残账**——画布 `semantics_label` 改经翻译器（新键 `app.design.canvas`），全应用不再有绕过 catalog 的用户可见文案；⑤ 小账三笔——DeleteControl 仅在被删子程序正被选中时清草稿（其余情况保住未提交编辑）、AddControl 加 MAX_CONTROLS 防呆（超限设 notice `app.status.controls_limit`）、design 常量统一到 `@ir.DESIGN_WIDTH/HEIGHT`。内核 ir.mbt 变更已重同步（sync_kernel --check 零漂移）；测试 ir 12×2 目标、app 36×2 目标全绿（新增 8 例：resize_from_corner×3、手柄命中、手柄缩放流、吸附纯函数+集成、创建子程序、预算防呆、删除草稿）；六项静态验证全绿。教训：旧拖拽测试按下点取控件原点+5px，落进新手柄命中区触发缩放——手柄优先是设计工具标准语义，测试改按控件主体；新建 UI handler 的 note 留空（可读性必填约束只针对 AI 提案） |
| 2026-09-28 | **参赛冲刺批次（上海赛=MoMao 口径，材料换轨 + 教学完备六包）**：G' 材料——`moui-milestones` 新增 MoMao 口径作品介绍（CONTENT_MOMAO.md → render_momao_pdf.py，7 页 PDF）、演示脚本（MoMao 主线 7 分镜）、提交清单两赛分叉（上海=MoMao / 北京=MoUI）；A 撤销重做——快照栈（深度 50，程序+选中+草稿）+ with_undo_point 签名守卫（no-op 不入栈）+ 同 key 合并（连续文本编辑/整段拖拽手势一个还原点）+ DuplicateControl（新名/+16px 级联/夹取）+ 顶栏撤销重做按钮；B 单步运行——RunModel.single_step 冻结 30ms 计时器、RunStep 走一条指令、RunResume 恢复，运行视图补计划承诺的变量表（run.state.vars 排序渲染）+ 单步/继续按钮；C MoonBit 毕业通道预览（v1.1 提前）——services/export 新增 moonbit_preview 纯函数（逐字节稳定快照锁定），第 4 模式 tab 只读展示，docs/moonbit-preview.md；D 提案历史——ProposalRecord（采纳/拒绝+摘要+diff+seq），AI 面板历史区；E 帮助页——从 keywords_for 双语表 + builtin_catalog **数据生成**速查表（零手抄）+ 问候教案（第 4 份）；F 回归加固——提案 13 类错误全覆盖（decode 篡改 + struct 变异两路）、momao_lang 边界（全角/≠≤≥/混合标识符/错误行号/15 层嵌套；实际关键字是「计次循环」）、blocks 路径手术（else-if 臂/越界安全）；**抓到真漏洞：IrError::DuplicateHandler 是死变体——计划声明的 (控件,事件) 唯一不变量从未被 validate_program 强制**，已补检查（内核重同步 + 导出烟测绿）；H 素材——playwright 合成指针事件驱动 web 入口，29 张分镜截图 + 3 张标题卡 + README 索引入库 moui-milestones/video/assets（闸门作天然暂停点解单步拍摄）。测试：app 49×2、ir 13×2、lang 30×2、blocks 9×2、proposals 19×2、codec 5×2、export 10×2 全绿；六静态门 + sync_kernel --check + 导出烟测绿。提交：main 上 20743ebe(A)→B/C/D/E/F 逐包 + moui-milestones 两笔。已发现待修：导出 runner 控件未接品牌主题（黑块按钮，视频素材已注明规避） |
