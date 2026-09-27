# MoMao 墨卯 — THIRD_PARTY / 第三方边界声明

## 许可

MoMao（`examples/momao`）是 MoUI 仓库的一部分，随 MoUI 以 **Apache-2.0** 分发。

运行时依赖（版本固定，见 `moon.mod`）：`wzzc-dev/moui@0.1.12`、
`wzzc-dev/window@0.5.4-0.1.7`、`wzzc-dev/moui_skia_renderer@0.1.11`、
`wzzc-dev/moui_web_renderer@0.1.10`、`wzzc-dev/moui_i18n@0.1.7`、
`moonbitlang/async@0.22.1`、`moonbitlang/x@0.5.5`（均为 Apache-2.0 / MIT 兼容）。
导出的独立应用 bundle 通过 `deps.txt` 重新列明同一组依赖。

## 架构参考（无源码/素材复用）

- **Scratch（scratchfoundation/scratch-editor，AGPL-3.0）**：仅研究其
  架构与交互模型——monorepo 的角色分离（GUI/VM/render/paint/storage）、
  工具箱→工作区→即时反馈的交互模式、结构化项目持久化。**未复制任何源码、
  视觉素材、积木文本、品牌、商标或角色/舞台语义**；不存在衍生关系，
  无链接期依赖。Scratch 名称与 Scratch Cat 商标归 Scratch Foundation 所有。
- **易语言（ proprietary ）**：仅参考其**概念**——中文语法编程、窗体设计器
  与属性面板、事件子程序驱动。易语言为闭源产品；MoMao **未使用其任何源码、
  素材、文件格式或商标**，中文关键字表为独立设计。
- **MoonBit / MoUI**：`moui` 及 `moui_i18n` 属 wzzc-dev；MoMao 是它们的
  应用方，不修改其源码。

## 凭据

真实模型（阶跃星辰 StepFun）的 endpoint/model/key 只来自 gitignored 的
`examples/momao/.config.json` 或用户运行时输入；key 只进会话内存，
禁止进入源码、`.momao.json` 与导出 bundle（有测试断言）。
