# THIRD_PARTY — MoBlocks Studio

本作品（`examples/moblocks_studio`）为独立 MoonBit/MoUI 实现，随 MoUI 仓库以
Apache-2.0 分发。以下为第三方材料与参考边界声明。

## 依赖（运行时与构建）

| 组件 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| wzzc-dev/moui | 0.1.12 | Apache-2.0 | 跨平台 UI 框架与 TEA 运行时 |
| wzzc-dev/moui_web_renderer | 0.1.10 | Apache-2.0 | Web 渲染 |
| wzzc-dev/moui_skia_renderer | 0.1.11 | Apache-2.0 | macOS Skia 渲染 |
| moonbitlang/async | 0.22.1 | Apache-2.0 | native provider worker 的 async 运行时与 HTTP |
| moonbitlang/core | 工具链内置 | Apache-2.0 | 语言标准库 |

依赖清单同时写入 `services/export` 生成的 `deps.txt`（随导出项目分发）。

## 架构研究参考（无代码/素材复用）

| 项目 | 许可证 | 参考内容 | 边界 |
|---|---|---|---|
| scratchfoundation/scratch-editor | AGPL-3.0 | package monorepo 的职责分离（scratch-gui / scratch-vm / scratch-render / scratch-paint / scratch-storage / scratch-svg-renderer）；「工具箱 → 工作区 → 即时运行反馈」的产品交互模型；结构化项目持久化思路 | **未复制任何源码、视觉素材、积木文案、品牌、商标、角色/舞台语义**；MoBlocks 为独立实现，术语与视觉均为自有 |

AGPL-3.0 是强 copyleft 许可证。本作品与其之间**不存在衍生关系**：仅作架构思路参考，
无源码嵌入、无资产搬运、无链接依赖。Scratch 名称与 Scratch Cat 等商标归
Scratch Foundation 所有，本作品不作任何暗示性使用。

## 商标

- MoBlocks、MoBlocks Studio 为本作品自有名称。
- MoUI 归 wzzc-dev（MoUI 仓库）所有。
