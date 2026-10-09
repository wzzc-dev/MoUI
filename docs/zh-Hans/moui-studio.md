# MoUI Studio

MoUI Studio 是 **MoUI 的 IDE 工具**：一个中英双语（zh-Hans / English）的
可视化编程环境——既服务想做出真软件的极客，也服务想把「一块积木到底在做什么」
讲清楚的老师。UI 走技术风：暗色工程面板、发丝分隔线、等宽字体优先、网格画布、
终端式控制台。

- 源码：`moui_studio/`——独立 git 子仓库（`wzzc-dev/moui_studio`，沿用 `examples/momark` 的子仓库模式），同时是 `moon.work` 成员
- 入口：Web（`web_wasm`）与 macOS（`macos_skia`）
- 项目格式：`moui.studio.project` v1（`.studio.json`），且是唯一格式——
  早期产品世代的项目文件不会被读取或迁移，而是返回结构化拒绝
- 语言：`domain/studio_lang` 的关键字表在 zh-Hans / en-US 下渲染同一棵规范 IR

## 一份程序，三个同源视图

单一语句级 IR（`domain/ir`）支撑所有编辑界面，不存在第二事实来源：

| 视图 | 编辑对象 | 依赖 |
|---|---|---|
| 设计 | 窗体画布上的控件（拖拽、缩放、吸附网格/参考线） | IR `controls` |
| 积木 | 带类型端口的拼图积木，支持同层拖拽重排 | IR 语句投影（`domain/blocks`） |
| 代码 | 双语文本，`如果…则…结束` ↔ `if…then…end` | IR 渲染（`domain/studio_lang`） |

任一视图的编辑都会回写 IR 并刷新其他视图。往返一致是硬门：
`parse(render_zh(ir)) == ir == parse(render_en(ir))`。

## 双轨执行

| | 解释轨 | 编译轨 |
|---|---|---|
| 语义来源 | `domain/studio_lang` 指令机直接执行 IR | IR → 可读 MoonBit 源码 → 真跑 `moon check` / `moon build` |
| 执行方式 | 沙箱：100_000 步预算、提交数据确认闸门、审计日志 | `app/generated_handlers.mbt` 由 `compiled_runtime` 执行面直接执行 |
| 平台 | native + Web（wasm-gc） | 仅 native |
| 运行态 | `RunModel`（单步、聚光灯、变量表） | `CompiledRun`（与解释轨相互独立） |
| 可用性 | 始终可用 | Web 上 `compile_track_available=false`，显式显示 `app.track.unavailable_web` |

**两轨互相独立**：切换轨道不迁移运行态、不静默降级、不隐式编译。

### 编译轨：真构建，无静默降级

编译轨真实串起工具链：

1. 把项目 IR 导出为 bundle（`services/export`），可读 MoonBit handler 源码
   落在 `app/generated_handlers.mbt`；
2. 装载 bundle 项目并执行 `moon update`；
3. 执行 `moon check --target native`；
4. 双端构建 `--target wasm-gc` 与 `--target native`；
5. 启动 native 烟测产物并要求其存活。

代码视图里展示的 MoonBit 预览与实际参与编译的文本**逐字节相同**，不是旁路
展示（有测试锁定）。

失败绝不静默。`moon check` / `moon build` 诊断会被解析为结构化错误
（文件/行/列/错误码），经 `moui_i18n` 本地化后回渲染到代码视图与运行视图，
并且可点击：诊断条目直接跳回产生它的 IR 语句（积木或控件）。编译轨不提供
单步（产物是原生执行），也绝不未经告知就退回解释轨。

导出独立应用遵循同一条「不假装」规则：它需要系统目录选择与真实写盘，
因此 `export_available` 仅在 macOS 入口为真。Web 端点「导出应用」会显式
声明这一限制（`app.export.unavailable_web`），而不是弹一个必然写不进去的
目录框。所有用户可感知的失败路径——保存、打开、导出、预算超限、解析
错误——都经同一 `with_notice` 漏斗回报，并同时弹出可见的 toast。

### 解释轨：沙箱与闸门

指令机执行时强制 100_000 步预算，保留教学级审计日志（每步一句人话摘要），
支持单步执行与语句聚光灯，并在 `提交数据`（`submit_data`）闸门暂停：v1 的
闸门是模拟动作，只写审计日志并弹出确认卡，双端都不发起真实网络请求。

## 双轨差分硬门

`services/diff` 是硬门而非报告。它把四个内置样例（外加每类语句一条合成
handler）先渲染为 zh-Hans 与 en-US，再分别喂给两条轨，逐项断言：

- 控件文本终态
- 变量终态（排除解释轨内部的 `@iN` 计数槽）
- 完整审计序列 `(line, op, detail)`
- 闸门状态与闸门 `(kind, prompt, payload)`
- 运行终态；失败时还包括错误类型与行号

任何一项不一致都是 P0 缺陷，没有「已知差异清单」。该门以
`studio diff matrix tests` 注册在 `pr` profile。

## 外观与交互

- `studio_theme()` 钉死 Dark，朱砂是唯一强调色；石墨色面板、发丝描边、
  紧半径档（`sm 2 / md 4 / lg 6`）。
- 画布：底板、点阵网格、对齐参考线、缩放手柄全部读同一套配色。
- 控制台与生成代码预览使用 Mono 角色；编译报告是终端式排版。
- 键盘优先：`Ctrl+K` / `Cmd+K` 打开可过滤命令面板；撤销/重做、轨道切换与
  主要操作均可纯键盘完成。
- 组合只使用 `moui/views` 现有控件——不新增内置控件、不新增 core 视图枚举。

## 可读可讲解的 AI 提案

AI 永远不写任意代码，只产出带版本的结构化 IR 提案：每个 handler 带双语
`note`、命名必须自解释（`a1`/`tmp` 式命名被拒）、带字段级 diff 预览，并提供
逐语句「解释这个程序」。提案要经过 schema → IR 不变量 → 双语 parser → 预算 →
可读性整链校验，用户显式采纳后才进入 IR。

这让提案可当教材讲：课堂可以先看 diff、再运行、再检查审计，最后毕业到真实的
MoonBit 源码。

## 市场定位

| 竞品 | 它擅长 | MoUI Studio 的取与舍 |
|---|---|---|
| Lovable | 自然语言直接生成可部署应用 | 取「描述即产物」；舍「生成任意代码直接执行」——AI 只产出结构化 IR 提案与 diff |
| Figma | 画布、吸附对齐、组件化编辑 | 取画布/吸附/参考线/检查器纪律；舍「只到设计稿」——每个控件同时是程序声明 |
| FlutterFlow | 可视化搭建 + 真代码导出 | 取「可视化 → 真代码 → 真产物」的毕业通道；舍只导出不落地的预览文本——这里的构建就是验收 |
| Power Apps | 表单类企业应用与数据流 | 取表单域建模与事件驱动 handler；舍托管锁定——产物是独立、可离线构建的 MoUI 工程 |

固定三句差异点：

1. 三视图同源 IR：设计、积木、代码消费同一棵语句级程序，改哪边都不会分叉。
2. 可读可讲解的 AI 提案：模型写结构化 IR，带双语意图说明与字段级 diff，
   并逐语句讲解。
3. 能真编译的毕业通道：IR 降级为可读 MoonBit，真跑 `moon check` /
   `moon build`，产出 native 与 wasm-gc 产物。

## 构建与运行

```sh
# Web（wasm-gc）
moon build moui_studio/web_wasm --target wasm-gc

# macOS native
moon run moui_studio/macos_skia --target native

# Linux / Windows native（Skia；能力缺口显式降级：无 PTY 终端、
# 无 webview 预览、无墙钟 FFI、无沉浸式标题栏；provider/编译轨/构建/持久化/MCP 复用）
moon run moui_studio/linux_skia --target native
moon run moui_studio/windows_skia --target native

# HarmonyOS（window-hosted 嵌入式运行时；experimental，ready=false）
moon run moui_studio/harmonyos_window_hosted --target native

# 测试
moon test moui_studio/app --target native
moon test moui_studio/app --target wasm-gc
```

完整验证循环见 `moui_studio/README.md`，验收矩阵见
`docs/plans/active/moui-studio.md`。
