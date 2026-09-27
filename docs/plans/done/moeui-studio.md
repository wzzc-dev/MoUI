# Mo易 Studio（AI 赋能的 MoUI/MoonBit 版易语言）

- Status: done
- Superseded by: ../active/momao.md（2026-09-27：MoMao 墨卯统一取代 Mo易/MoBlocks 双 Studio，本计划对应代码 `examples/moeui_studio` 已删除，salvage 映射见新计划第 11 节）
- Goal: 在 MoUI 上构建一个易语言风格的中文可视化编程 IDE：表单设计器 +
  中文事件子程序 DSL + 一键运行 + AI 生成整个应用（窗体 + 中文代码）。
  产品名 Mo易 Studio，落位 `examples/moeui_studio`，项目格式 `.moeui.json`。

## 定位与边界

- 易语言三要素的映射：
  - 全中文编程 → 中文 DSL（关键字/命令全中文，见下文语法），纯 MoonBit
    lexer/parser/解释器，无 UI 依赖，可独立 `moon test`。
  - 可视化表单设计器 → 自绘 canvas（点选/拖动/属性编辑），交互原语复用
    MoBlocks Studio 已验证的模式。
  - 事件驱动 → TEA：设计期事件表（控件.事件 → 子程序源码），运行期按钮
    点击/输入变化触发解释执行对应子程序。
- AI 赋能 → 复用 MoBlocks 的提案契约模式：模型只产出版本化 JSON 提案，
  严格 schema 校验后进入待采纳状态；确定性假模型离线可演示，真实
  OpenAI 兼容 provider 走 native async worker。
- 硬边界：IDE 全部逻辑在 `examples/moeui_studio/app`（平台中立）；
  provider 协议/worker 在 `examples/moeui_studio/services/*`；入口只做
  组合根接线（`web_wasm` / `macos_skia`）。不新增 `moui/views` 内置控件。

## 中文 DSL（v1）

- 语句：`变量 x = 表达式`（声明）、`x = 表达式`（赋值）、
  `如果 条件 则 … [否则 …] 结束`、`计次循环 表达式 次 [为 i] … 结束`、
  `当 条件 循环 … 结束`、表达式语句（命令调用）。
- 表达式：数字/字符串/真/假、`+ - * /`（字符串 + 拼接）、比较
  `= <> < > <= >=`（兼容 `≠ ≤ ≥`）、`且 或 非`、括号、函数调用。
- 词法容错：全角标点（（）＋－＝＜＞，）在词法层归一化为 ASCII，
  中文/英文标识符均合法。
- 内置（host 注入，解释器不碰 UI）：
  - 命令：`信息框(文本)`、`设置文本(控件名, 文本)`。
  - 函数：`取文本(控件名)`、`取数值(控件名)`、`转文本(表达式)`、
    `取长度(字符串)`、`文本包含(串, 子串)`。
- 安全：语句步数预算（默认 100_000）防死循环冻结 UI；运行错误带行号，
  中文报错信息。

## 窗体模型与格式

- 控件 v1：`Button`（按钮）、`Label`（标签）、`TextField`（输入框）；
  属性：名称（唯一）、文本、x/y/宽/高。
- 事件 v1：按钮 `被单击`、输入框 `内容改变`；每对（控件, 事件）唯一，
  源码即 DSL。
- `.moeui.json`：`format: "moeui.project"`，`version: 1`，含
  metadata/window/controls/handlers；编解码 + 完整校验（未知 kind、重名、
  事件归属、DSL 语法全拒绝）。

## AI 生成契约

- 提案 v1 JSON：window + controls + handlers（同格式子集）。
- 校验链：schema 字段 → 名称/事件合法性 → 每个 handler 源码过 DSL
  parser（语法错误即拒绝提案）。
- 假模型：按关键词路由内置模板（计算器/问候应用），确定性离线可演示；
  真实模式系统提示词讲清 schema 与 DSL 语法。

## IDE（TEA）

- 三模式：设计（画布 + 组件面板 + 属性检查器）/ 代码（事件子程序列表 +
  `text_area` 编辑器 + 实时语法检查）/ 运行（`stack` + `offset` + `frame`
  按坐标摆真实控件，按钮点击/输入变化驱动解释器）。
- 顶栏：新建/打开/保存（`@services` files）/模式切换；AI 面板在检查器区
  （提示词、provider 切换、提案预览）。
- 运行会话状态独立于设计模型（控件实时文本、信息框横幅），停止即丢弃。

## 交付切片

1. 本切片：上述全部 v1 能力 + 双平台入口 + `moon test` 覆盖语言核心、
   编解码、AI 提案校验、画布命中、运行会话。
2. 后续（未排期）：表格化代码编辑器（易语言标志性表格呈现）、
   MoonBit 源码导出（脱离解释器真编译）、运行器模板打包、更多控件
   （复选框/下拉）、`内容改变` 防抖、多窗体。

## 验证

- `moon test examples/moeui_studio/app --target native`
- `moon build examples/moeui_studio/web_wasm --target wasm-gc`
- 手动烟测：`moon run examples/moeui_studio/macos_skia --target native`
- 改动 guidance/examples 目录时跑静态 validator 三件套与
  `node scripts/sync-website-docs.mjs`。
