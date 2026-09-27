# Mo易 Studio

AI 赋能的 MoUI/MoonBit 版易语言：表单设计器 + 中文事件子程序 + 一键运行。

## 它是什么

- **可视化表单设计器**：从组件面板添加按钮/标签/输入框，在画布上拖动布置，
  属性检查器改名称/文本/位置尺寸。
- **Mo易语言（中文 DSL）**：`变量 x = 1`、`如果 … 则 … 否则 … 结束`、
  `计次循环 n 次 为 i`、`当 条件 循环 … 结束`；内置 `信息框`、`设置文本`、
  `取文本`、`取数值`、`转文本`、`取长度`、`文本包含`。全角标点/数字/字母
  自动归一化，中文 IME 直接写代码。
- **事件驱动运行**：按钮「被单击」、输入框「内容改变」触发对应中文子程序，
  在真实控件上解释执行；语句步数预算防死循环冻结 UI。
- **AI 赋能**：一句话描述应用 → 模型产出版本化 JSON 提案（窗体 + 中文代码），
  全量校验（含子程序语法）后待采纳。离线确定性假模型可演示；macOS 入口
  支持真实 OpenAI 兼容 provider（async worker，凭据不落盘）。
- **项目格式 `.moeui.json`**：新建/打开/保存走平台文件服务。

## 运行

```sh
moon run examples/moeui_studio/macos_skia --target native   # 完整体验（真实 provider）
moon build examples/moeui_studio/web_wasm --target wasm-gc  # Web（假模型）
moon test examples/moeui_studio/app --target native         # 测试
```

## 结构

| 路径 | 职责 |
|---|---|
| `app/moe_lang.mbt` | 中文 DSL 词法/语法/解释器（纯 MoonBit，无 UI 依赖） |
| `app/form_model.mbt` | 控件/事件子程序模型与项目级校验 |
| `app/project_codec.mbt` | `.moeui.json` 编解码 |
| `app/ai_generation.mbt` | AI 提案解码/校验/系统提示词/假模型 |
| `app/run_session.mbt` | 运行会话（不可变值语义，副本上解释执行） |
| `app/designer_canvas.mbt` | 设计器画布（纯数据绘制计划 + 拖拽） |
| `app/app.mbt` / `app/view.mbt` | TEA 模型与三模式 IDE 视图 |
| `services/model_provider` | OpenAI 兼容对话补全协议（平台中立） |
| `services/provider_native` | native async HTTP worker（仅 macOS 入口） |

设计决策与后续切片见 `docs/plans/active/moeui-studio.md`。
