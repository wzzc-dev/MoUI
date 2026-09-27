# MoMao 墨卯 — 用人话描述，用母语编程，用积木理解

[English](#english)

MoMao 是一个**中英双语的可视化编程环境**：同一份程序有三种同源视图——
易语言式的**窗体设计器**、Scratch 式的**积木编排**、中英双关键字的
**代码编辑器**。自然语言交给 AI，但它只能产出**结构化提案**（可预览、
可 diff、可拒绝），结构上不存在"生成任意代码直接运行"的路径。产物可以
一键导出为**独立 MoUI 应用**（Web / macOS 双端）。

## 五分钟上手（Web，零安装）

```sh
moon build examples/momao/web_wasm --target wasm-gc
# 用 scripts/package-web-app.mjs 打包后浏览器打开，即见 IDE
```

- 切语言：顶栏 `English` / `中文`（代码与界面一起切换：`如果…则…结束` ↔ `if…then…end`）
- 换模板：顶栏「班级点名册 / 口算训练营 / 班级小卖部」，打开即玩
- AI 面板：输入「帮我做一个随机点名」→ 生成提案 → 逐项核对 diff → 采纳
- 运行：点「运行」，按钮真的能点；`提交数据` 会让程序**停下等你确认**

## 三个内置样例（各附教案）

| 样例 | 教什么 | 教案 |
|---|---|---|
| 班级点名册 | 随机数、列表框取行 | [samples/roll_call/README.md](samples/roll_call/README.md) |
| 口算训练营 | 分支、变量、算术 | [samples/drill/README.md](samples/drill/README.md) |
| 班级小卖部 | 跨事件状态、外发闸门 | [samples/store/README.md](samples/store/README.md) |

## macOS 入口（真实模型）

```sh
moon run examples/momao/macos_skia --target native
```

- 真实模型默认指向阶跃星辰（`https://api.stepfun.com/step_plan/v1`，`step-5-preview`）。
- 凭据放在 **gitignored** 的 `examples/momao/.config.json`（可直接在 json 里换 key）：

```json
{ "provider": { "endpoint": "...", "model": "...", "api_key": "..." } }
```

- Web 入口只走确定性假模型——现场演示不依赖网络与凭据。

## 规范文档

- DSL 规范（双语关键字、语句、内建、预算）：[docs/dsl-spec.md](docs/dsl-spec.md)
- 程序 IR 与 `.momao.json` 格式：[docs/ir-schema.md](docs/ir-schema.md)

## 包结构

```text
examples/momao/
  domain/ir/          程序 IR + 不变量 + 预算（零依赖）
  domain/momao_lang/  双语 DSL：关键字表/词法/解析/打印/指令机解释器
  domain/codec/       .momao.json 编解码 + 版本门
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
for p in ir momao_lang codec blocks proposals; do
  moon test examples/momao/domain/$p --target native
done
moon test examples/momao/app --target native
moon test examples/momao/app --target wasm-gc
moon run examples/momao/tools/sync_kernel --target native -- --check
```

---

<a id="english"></a>

# MoMao — describe in words, code in your language, understand with blocks

*(中文说明见上。)*

MoMao is a **bilingual visual programming IDE**. One program, three
same-source views: an E-language-style **form designer**, Scratch-style
**typed blocks**, and a **code editor whose keywords follow the UI language**
(`如果…则…结束` ↔ `if…then…end`). AI may only produce **structured proposals**
(previewable, diffable, rejectable) — there is no path from "generate
arbitrary code" to "run it". Projects export to **standalone MoUI apps**
(Web wasm-gc / macOS Skia).

Try it in five minutes (Web, zero install):

```sh
moon build examples/momao/web_wasm --target wasm-gc
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
moon run examples/momao/macos_skia --target native
```

Credentials live **only** in the gitignored `examples/momao/.config.json`:

```json
{ "provider": { "endpoint": "...", "model": "...", "api_key": "..." } }
```

Specs: [DSL spec](docs/dsl-spec.md) · [IR & `.momao.json` schema](docs/ir-schema.md).
