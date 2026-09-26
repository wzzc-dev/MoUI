# MoBlocks Studio 项目介绍

> 按大赛要求的四个维度组织：**创新 / 可用 / 开源 / 案例**。
> 事实口径以本文件与 `README.md`、`DEMO_SCRIPT.md`、`THIRD_PARTY.md` 为准；
> 所有数字均在仓库中可复现（命令见文末「复现清单」）。

**一句话**：像搭积木一样构建应用，也可以让 AI 直接生成**可视、可改、可验证**的工作流。

底座是 [MoUI](../../../README.md)：一个用 MoonBit 写的跨平台声明式 UI 框架
（严格 TEA：Model / Msg / update / view）。MoBlocks Studio 是构建在其上的完整产品，
不改框架内核即完成全部能力；过程中对框架的疑问以最小复现复核后**补充回归测试**，
而不是在产品里打补丁绕过（见「开源」节的回馈记录）。

---

## 一、创新

### 1. AI 生成的是「版本化积木图提案」，不是可执行代码

模型输出被约束为 `BlockGraphProposal v2` JSON（节点 + 端口类型化连线），用户看到的是
一张可以预览、可以拒绝、可以直接编辑的图。生成结果**不可能**是任意代码，也就从结构上
不存在「生成物绕过审查直接运行」的路径。生成回路对 Markdown 代码栅栏宽容（```json
围栏也能解析），解析失败会给出中文原因而不是静默失败。

### 2. 端口类型系统 + 验证器：错误连接在界面上就不可能发生

17 种积木、8 种端口类型（Text/Number/Bool/Json/FileRef/Table/ChatMessage/ToolResult
+ 执行流 Unit）。校验器覆盖 20 类失败（含 3 类输入解析）：类型错连、输入端口被多条边占用、环、
入口可达性、预算越界（64 节点 / 96 边 / ForEach 上限 64）、以及**权限路径**——
数据外发节点（`external_submit`）的 `approved` 输入必须从某个 `UserConfirmation`
积木的 `approved` 输出**直接连线**，只做到"图上可达"不够（确认节点挂在无关支路上
一律拒绝），图直接拒绝运行。「连接到…」菜单只列出类型匹配且输入为空的候选，把校验前置成交互约束。

### 3. 数据外发闸门与审计留痕

`UserConfirmation` 是硬闸门：模型调用跑到外发点会**停下来等人**，确认才放行、拒绝则
流程失败且无副作用。执行器是有界的事件状态机：重试次数与超时预算从上游
`Retry`/`Timeout` 积木推导，取消保留已完成记录；每次运行可导出 Markdown 审计报告
（步骤、状态、截断摘要），外发内容不落盘到项目文件。执行语义的口径是诚实的：
状态机负责**编排与闸门**（拓扑序推进、确认暂停、重试/超时/取消），模型步骤的回复由
确定性假模型承担，因此离线即可完整跑通。

### 4. 纯函数内核 + 薄 UI（可测试性是设计出来的）

图模型、校验、项目 codec、编辑/撤销重做、执行状态机、AI 提案解码全部是无 IO 的纯
MoonBit 代码，UI 只做渲染与消息分发。因此 65 个测试可以在**不启动窗口**的情况下
覆盖全部核心语义（执行器含「无 UI 确定性运行」用例），并同时跑 native 与 wasm-gc
两个编译目标。

### 5. 导出应用与 Studio 共享同一个执行引擎

导出的可执行应用把领域内核（块图/校验/执行状态机）**逐字节同源**拷入（`tools/sync_kernel`
同步 + `--check` 漂移门），runner 是 ~200 行通用 TEA 驱动。因此「Studio 里能跑的图」
与「导出应用能跑的图」是同一套语义，不会出现两边行为分叉；被导出的项目若本身不合法，
导出应用会用同一套校验器原样阻止并说明原因。

### 6. 一份逻辑，两个平台

同一份应用代码跑在 Web（wasm-gc + WebGPU）与 macOS（Skia）上；平台差异只存在于
薄入口（`web_wasm/main.mbt` 与 `macos_skia/main.mbt`）。真实模型 provider 需要
async HTTP，而 `moonbitlang/async/http` 只有 native 目标——因此 HTTP 工作者放在
native 组合根，Web 路径用确定性假模型，两条路径共享同一个 `provider_submit`
函数签名。这是对工具链现状的诚实适配，而不是在 Web 里硬塞一个不能用的按钮。

---

## 二、可用

- **5 分钟跑起来**：Web 主评审路径只需 `moon build examples/moblocks_studio/web_wasm
  --target wasm-gc` + 任意静态服务器；README 的 Quick Start 逐步到「第一次看到
  金色高亮停在确认闸门」。
- **离线可演示**：默认假模型是确定性的，演示视频（`DEMO_SCRIPT.md`）录制与评审现场
  都不依赖网络；API Key 只存会话内存，编码后的项目文件不含 Key（有测试断言）。
- **三个内置模板**（对话机器人 / 文档分析助手 / CSV 助手）覆盖三种典型数据形态，
  均带 decode→validate 往返测试；AI 生成 additionally 带自动布局。
- **撤销/重做 100 步**，属性面板实时校验，自动运行把执行过程变成可见的时间线 +
  画布聚光灯（绿旗时刻）。
- **导出即可运行**：做好的应用导出为**独立的 MoUI 项目**（15 个文件，标准
  `moon.mod`/`moon.pkg`，不含任何 MoBlocks 专有依赖）。Web 宿主页的运行时 JS 从
  该项目 `moon build` 后生成的 `.mooncakes` 依赖目录加载（版本与 `moon.mod` 固定的一致，
  不需要手工拷贝任何文件）。导出的应用内嵌与 Studio 逐字节同源的领域内核
  （块图/校验/执行引擎）和一个通用 TEA runner：
  加载项目 → 校验 → 运行 → 数据外发停在人工确认闸门（确认/拒绝是真实按钮）→
  逐步时间线 + 安全审计。浏览器里点一遍即可跑完（见「案例」）。
- **65 个测试 / 两个编译目标**：app 52、model_provider 5、export 8，另有 6 个仓库级
  静态校验（API 表面、release 闭合、指引一致性等）。

---

## 三、开源

- **许可证**：随 MoUI 仓库以 **Apache-2.0** 分发；第三方与参考边界见
  `THIRD_PARTY.md` 与 `NOTICE`。
- **无供应商锁定**：导出项目是普通 MoUI 项目，构建命令就是标准 `moon build`；
  依赖清单（`deps.txt`）与 `THIRD_PARTY.md` 中的表格一致，可逐一核对。
- **明确的参考边界**：架构上研究了 scratch-editor 的 monorepo 职责分离与
  「工具箱 → 工作区 → 即时反馈」交互模型，但**未复制任何源码、素材、积木文案、
  品牌或角色/舞台语义**，与其 AGPL-3.0 不存在衍生关系——声明写死在 `THIRD_PARTY.md`。
- **安全模型成文**：六条安全模型（本地优先 / 外发闸门 / Key 不落盘 / 有界执行 /
  审计留痕 / 导出内容透明）见 `README.md`，其中「Key 不出现在编码产物」由测试保证。
- **对上游的回馈**：开发中一度怀疑框架的指针命中缺陷（row 子级按钮、`on_drag`
  手势），以 8 种形状探针复核后确认是**坐标系误用导致的测试误判**而非框架缺陷
  （画布 draw 命令的文本帧是画布局部坐标，指针事件是屏幕坐标）。澄清结果连同新增的
  5 项指针输入回归测试（`moui/runtime/row_child_pointer_input_test.mbt`，双端
  140/140）一起落入 `docs/plans/done/row-child-hit-testing.md`，Studio 画布积木
  拖拽这条原本被降级的 L1 交互也随之恢复并有端到端回归。

---

## 四、案例

### 案例 1：对话机器人（ flagship demo ）

AppStart → UserPrompt → ConversationMemory → PromptTemplate → ParseJson →
UserConfirmation → ModelCall → ShowMarkdown 共 8 个积木 / 15 条连线。演示动线
（完整分镜见 `DEMO_SCRIPT.md`）：

1. 点「生成」→ 出现提案预览（8 积木 / 15 连线）→「接受替换」；
2. 点「自动运行到阻塞点」→ 金色高亮沿画布推进（绿旗时刻）→ 停在「模型调用 ·
   等待人工确认」（数据外发闸门）；
3. 「确认外发」跑到完成；再来一次「拒绝」→ 失败且无副作用；
4. 导出为独立 MoUI 项目，一条命令构建运行。

### 案例 2：导出项目在干净环境真实可跑（本仓库外验证）

以模板项目生成导出 bundle 到 workspace 外目录，实际执行并全部通过：

```sh
moon run examples/moblocks_studio/tools/emit_bundle --target native -- \
  examples/moblocks_studio/fixtures/demo_project.moblocks.json "Demo Export" /tmp/moblocks-export-verify
cd /tmp/moblocks-export-verify/Demo-Export
moon check app --target native      # 0 errors
moon check app --target wasm-gc     # 0 errors
moon build web_wasm --target wasm-gc # 产物 web_wasm.wasm
# 以该目录为静态服务器根，浏览器打开 web_wasm/index.html
```

浏览器实测：canvas 2560×1440、状态 **Running**，然后点「运行」→ 时间线逐格推进到
「模型调用 · 等待人工确认」（按钮变为确认外发/拒绝外发）→ 点「确认外发」→ 8 步全部
完成（含「模型调用 · 已确认并执行」「渲染回复」），时间线显示「已完成」。
定位并修复的真实缺陷有四个：Web 运行时 JS 的相对导入目录错位；可执行包缺少 ABI
垫片导致 wasm 只导出 `_start`（Moon 只导出可执行包自身定义的函数）；内嵌源码
转义过度把内核里的 `\{x}` 插值写成字面量，使校验器的「输入占用」键退化成同一个
字符串（任意合法图都会被误判为 6 处冲突）；以及最初 Studio 内「导出为 MoUI 项目」
只写 15 个生成文件、不带运行时 JS，按 README 走会在浏览器停在 Loading——现改为
宿主页从导出项目自身的 `.mooncakes` 依赖目录加载运行时（与 `moon.mod` 固定的版本
一致），目录契约由 `export_test` 固定。四者均有测试固定，不再回归。

### 案例 3：同一份逻辑跨平台

`macos_skia` 入口用同一 app 逻辑 + Skia 渲染器启动，并挂载真实 OpenAI 兼容
provider 工作者（async）；Web 入口走 wasm-gc + WebGPU。两条路径共享 `program()`
与全部纯函数内核，差异只在薄入口与渲染后端。

---

## 复现清单

```sh
# 测试（native + wasm-gc 双端）
moon test examples/moblocks_studio/app --target native
moon test examples/moblocks_studio/app --target wasm-gc
moon test examples/moblocks_studio/services/model_provider --target native
moon test examples/moblocks_studio/services/export --target native

# Web 构建与演示
moon build examples/moblocks_studio/web_wasm --target wasm-gc
python3 -m http.server 8791   # 以仓库根为根目录
# http://127.0.0.1:8791/examples/moblocks_studio/web_wasm/index.html

# macOS（Skia）入口检查
moon check examples/moblocks_studio/macos_skia --target native

# 导出 bundle（workspace 外验证）
moon run examples/moblocks_studio/tools/emit_bundle --target native -- \
  examples/moblocks_studio/fixtures/demo_project.moblocks.json "Demo Export" /tmp/moblocks-export-verify
```

可用性说明：画布内按下即选中积木、按住拖动可移动（回归测试
`M2：画布积木可经拖拽移动`）；底部按钮列表与检查器扁平列保留为同等可用的
替代入口。给画布写测试时要注意：draw 命令里的文本帧是画布局部坐标，指针事件是
屏幕坐标，二者相差画布原点（Studio 画布原点为 (0,42) = notice 32px + 根 column
间距 10px）。
