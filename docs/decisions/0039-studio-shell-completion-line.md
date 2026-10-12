# ADR 0039: MoUI Studio 壳收敛完成线与预算棘轮

- **Status**: accepted (2026-10-12)
- **Context**: ADR 0038 确立了静态插件架构，但迁移处于「无限并行」状态：
  app 包实测 53 个源文件 / 37,279 行源码，`Model` 155 字段、`Msg` 291
  变体（立项时约 100/150），kernel+plugins 仅约 3.3k 行（完成度 ~6%）。
  没有结构性约束阻止新功能继续落进旧壳——每加一个功能都在给旧壳加权，
  而插件化迁移没有终点判据。
- **Decision**:
  1. **设完成线，不设截止日**：完成 = 四项预算达标 + 六域提取（project /
     run / ai / blocks / design / code）+ 三共享真源 root 持有 + 跨域只走
     事件/服务/root 委托臂。预算：app 源码 ≤ 18,000 行、源文件 ≤ 30、
     `Model` 字段 ≤ 55、`Msg` 变体 ≤ 90（口径排除 `*_test.mbt`、
     `*wbtest.mbt`、i18n 生成物）。
  2. **棘轮先于切片**：扩展 `tools/moui/validate_maintenance_baseline`
     增加四个计数器，预算冻结为今日基线（37,279 / 53 / 155 / 291），
     **只降不升**；上调必须改预算目录并写 reason（即审计记录）。该工具
     已在静态三件套与 pr profile 中，扩展即全链生效。
  3. **每域一片、先浅后深**：project（服务耦合最浅，M5 记录「先 project
     后 blocks」）→ run → ai 补完 → blocks → design → code；每片独立
     可验收、可中止；机制沿用 ai/terminal 先例（状态切片 +
     `Feature::scope` 委托 + `[Msg]` 泛型视图构建器 + root 薄臂负责
     事件/undo/通知三跨域面）。
  4. **禁反向依赖**：插件包禁 import app；组合根是唯一反向边；视图构建器
     以回调/translator 参数注入壳类型需求。
- **Consequences**:
  - 新功能在完成线之前默认落插件包；落 app 需预算表登记（评审可见）。
  - 完成线之后 app 只剩壳 + 组合根 + 共享漏斗 + 壳级回归测试（合法常驻
    ~15–18k 行）；「app 归零」不是目标。
  - `services/export`（12.7k 行）与 domain 包不在本决定范围。
- **Verification**: 每片 `moon test moui_studio/app`（native+wasm-gc）+
  新插件包双目标全绿 + 六静态门；棘轮破断验证（故意超线确认会红）；
  计划与进度记录在 `docs/plans/active/moui-studio-shell-completion.md`。
