# Plan: Feature 组合子（TEA 单元 + scope 挂载）+ views/form 字段键控 API + settings/workbench 试点

- **Status**: active
- **Goal**: 用「TEA 单元局部化」消解单状态循环的表达成本——在 `moui/core` 新增 `Feature[Model, Msg]`（与 `Program` 同构的五元组，可独立演化、独立测试）和 `Feature::scope`（镜头挂载 + 四路抬升的唯一入口），`Program` 保持 runtime 根不变并新增 `Program::from_feature` 桥接；在 `moui/views/form` 新增 `FieldAction` 字段键控 API；用 `examples/settings/app`（必选）和 `examples/mo_workbench/app` 的现成委托点（天然试验场）做行为等价试点；更新 tea-program-model / cookbook / architecture 文档。
- **Non-goals**: `Feature::combine`（update 路由语义待试点后定）；单向/双向 `Feature::map`（见「类型修正」，留给 prism 版本）；`index` 动态镜头；分层 `ResourceSlot`、`Request[T]` 泛化、代码生成器；invariant 条文改动；RFC/ADR（治理决定：只写计划；P13 澄清进 doc comment + PR 描述）。

## Governance note

PR 描述引用 `docs/invariants.md` P13 原文澄清：镜头 `set : (Child, Parent) -> Parent` 是纯函数值，不是 "arbitrary setters"（后者指绕过 `update` 改 Model 的框架通道）；`docs/tea-program-model.md` 已有同口径 "they do not receive a setter or a mutable application-state holder"。

## Naming and structure

```text
Feature[Model, Msg]          ← 完整 TEA 单元（CodeWorkspace/SettingsWorkspace 的抽象）
 ├── init / update / view / subscriptions / commands   （与 Program 五元组同构）
 │
 ├── Feature::scope(get~, set~, feature, wrap~) → ScopedFeature
 │        挂载到父级：镜头取/放 + wrap 抬升
 │        ScopedFeature::{init, update(parent,msg), view(parent,env), subscriptions(parent), commands(parent)}
 │        update 内部 = set(child_update(get(parent))) + Effect::map(wrap)
 │        view/subscriptions 内部 = 现有 View::map / Subscription::map
 │
Program[Model, Msg]          ← 保留为 runtime-facing 根，不动 AppRuntime 接线
 └── Program::from_feature(feature)   ← 一行桥接（字段同构）
```

- **类型修正（对 `Feature::map`）**: 单向 fmap 在 `update` 输入侧不封闭——`map(f : Msg -> M2)` 抬升了产出消息，但输入也变成 `M2`，缺反向函数无法喂回。P1 不提供 `Feature::map`；抬升由 `scope(wrap)` 全权承担（父 match 臂天然完成解包，与 showcase/mo_workbench/file_importer 现有手写形状一致）。双向 map 留给未来 prism（`wrap`+`unwrap`）版本。
- **命名消歧**: `Feature`（core，TEA 组合单元）≠ `RendererFeature`（render，渲染能力枚举，标识符不冲突）≠ 文档 `feature-status`/`feature-proof` 页面。cookbook/tea 文档各加一句消歧。
- **避开词**: `embed`/`route`（backend/导航已占用）；不叫 `SubProgram`/`Component`/`Module`。scope 结果类型叫 `ScopedFeature`（不叫 `Scope`，避免与 `focus_scope.mbt` 的 FocusScope 语义纠缠）。

## Background (verified)

1. `moui/core/program.mbt`: `Program` 私有 struct 五元组 + pub 工厂；`Effect::map`(L150)、`ProgramCommand::map`(L72)、`Subscription::map`(program_subscription.mbt L126)、`View::map`(view_modifiers.mbt L2) 齐备——scope 的四路抬升全部复用，零新协议。
2. 手写委托先例（scope 必须复现的形状）: `examples/file_importer/app/file_importer_app_test.mbt:253-291`（含 Effect 抬升的最小范本）、`examples/showcase/app/update.mbt:73-91`、`examples/mo_workbench/app/task_update.mbt:461-471`（`CodeMsg`/`SettingsMsg` 两个委托点，带 `Effect::map` 注释——试验场落点）。
3. 字段键控先例: `SettingsMsg::UpdateProviderField(String, ProviderField, String)`（workbench model.mbt:546+）。`moui/views/form` 有 `FormFieldState`（abstract、`name` 字符串键、`with_value`）、`FormController`（Array 存储），**无** `FieldAction`/Map 键控。
4. 名称可用性: `moui/`+`examples/` 无 `pub struct/enum Feature`；`RendererFeature` 仅在 render 包。
5. 分类器: `tools/moui/validate_api_surface/main.mbt:88` 与 `:157` 两处 token 表含 `"Program"/"Subscription"`——加 `"Feature"` 后新行自动归 `advanced_core_protocol`（预算 643）；core 预算 `max_pub_lines: 560`、`pub(all) max 190`、per-file ratchet 可能被新文件触发。
6. 试点: settings 486 行、零 effect、9 变体中 7 个逐字段拷贝、4 个行为测试（含真实点击）、无平台入口——最小爆炸半径；`SettingsSnapshot` 往返 28 行字段拷贝可用镜头去重。
7. 治理: `docs/plans/active/<id>.md` + README Active 登记是编码前置（plans README: "Multi-package, public API… before coding"）。

## Acceptance

- [x] A1 `moon test moui/core --target native` 绿（99/99，含 8 个 Feature 测试）：`Feature` 五元组工厂 + `with_commands`；`scope` 的镜头三定律（GetSet/SetGet/SetSet/no-op 恒等）；**scope 与手写 wrapper-variant 委托行为等价**（含 `Effect::map`、`View::map` 事件路径、`Subscription::map` runtime_sources 消息、`ProgramCommand::map` 抬升）；`init` 启动 effect 抬升；双 scope 互不串扰。
- [x] A2 `Program::from_feature` 往返：init/update/view(identity)/subscriptions(descriptors)/commands 消息序列与 `Feature::runtime_*` 逐一相等。
- [x] A3 `moon info` 后 `check-generated-interfaces` 干净（208 tracked packages ok）；`validate-api-surface` 通过——分类器 `core_api_surface_name_tokens` 已加 `"Feature"`，根 facade required 表与 sugar 域禁表已加 `Feature`/`ScopedFeature`；预算按 Review Rules 同改动更新（root 40/12→43/14，core 2140/560→2159/572，均带 owning-package 理由注释）。
- [x] A4 `validate-maintenance-baseline` 通过（core `pub(all)` 190 未动；views 65→66 已带理由注释——FieldAction 枚举）。
- [x] A5 `moui/views/form` `FieldAction { Text; Toggle; Select }` + `FormFieldState::apply_action` + `update_named_field`（未知 name 不变）；form 测试 7/7 绿；经 `views.mbt` 门面 `pub using @form` re-export（`type FieldAction` + `update_named_field`）。
- [x] A6 settings 试点：Model 拆 `profile/workspace/preferences/shell` 四段，三段 `Feature` + `scope`，外层 `SettingsMsg` 为 wrapper-variant（Profile/Workspace/Preferences + 3 个 shell 臂）；profile 段采用 `Field(String, FieldAction)`；snapshot 往返经 `read`/`write` 镜头重建（wire 格式保持扁平 `SettingsSnapshot`）；`moon test examples/settings/app` **5/5 绿**（断言语义等价，仅消息路径与字段路径改写）。根 `Program::simple` → `Program::simple_with_environment`（纯 update 形状不变，仅 view 签名带 env 以便把真实 `ViewEnvironment` 传给 scoped view）。
- [x] A7 workbench 试点：`task_update.mbt` `SettingsMsg::AppearanceChanged` 委托点从手写 `Effect::map` 改为 `settings_scope().update`（`settings_feature` + 镜头 + wrap）；**结构性发现**：该 section 的 view 由 `settings_overlay_view` 以父级输入（appearance/theme/窗口尺寸）组合，子 Feature 无法持有真实 view，故 scope 的 `view` 字段显式 `abort`（更新了诚实失败信息 + 注释指向真实组合点）——scope 仅覆盖 update/effect 抬升。验证：`moon check` 干净 + `moon test examples/mo_workbench/app` **77/77 绿**（未降级到 check-only，包测试存在且全过）。
- [x] A8 文档：`docs/tea-program-model.md` 文末新增 `## Feature Composition`（含 Feature/RendererFeature/feature-status 三词消歧 + `Feature::map` 类型修正 + P13 镜头澄清）；`docs/non-render-component-cookbook.md` 新增 `## Feature Composition With Scope` 与 `### Keyed field messages`（`FormMsg::Field(String, FieldAction)` 单臂范例）；`docs/architecture.md` Public View API 关键面补 `Feature`/`scope`/`ScopedFeature`/`from_feature`。
- [x] A9 全部静态校验绿（exit 0 ×9）：`validate-maintenance-baseline`、`validate-api-surface`、`validate-guidance-consistency`、`validate-core-theme-no-control-surface`、`validate-host-import-baseline`、`validate-release-module-closures`、`validate-renderer-capability-consistency`、`validate-doc-references`、`check-generated-interfaces`。回归：core 99 + views 37 + settings 5 + workbench 77 全绿。
- [x] A10 （可选加分，**未做**）quickcheck 属性化镜头三定律——确定性三定律已在 core 测试覆盖；quickcheck 留作后续可选增强，不阻塞本计划。

## Slices

| Slice | Content | Key files |
|-------|---------|-----------|
| 1 | 落盘本计划 + README Active 表登记（编码前置） | `docs/plans/active/feature-scope-composition.md`、`docs/plans/README.md` |
| 2 | Core 实现：`Feature` 五元组 + `scope`/`ScopedFeature` + `Program::from_feature` | `moui/core/feature.mbt`（新）、`moui/core/program.mbt` |
| 3 | Core 测试：三定律、scope≡手写委托、init 合并、双 scope 隔离、from_feature 往返（A1/A2） | `moui/core/feature_test.mbt`（新） |
| 4 | 门禁: `moon test moui/core` → `moon info` → 分类器 token 加 `"Feature"`（main.mbt:88/:157 两处）→ `validate-api-surface` → `validate-maintenance-baseline`；预算被 flag 则同改动更新 | `tools/moui/validate_api_surface/main.mbt`、`pkg.generated.mbti`×2、budget catalog（条件） |
| 5 | 根 facade re-export `Feature`/`ScopedFeature`，重生成根 `.mbti` | `moui/moui.mbt` |
| 6 | views/form 键控 API + 测试（A5） | `moui/views/form/form_field_action.mbt`（新）+ 测试 |
| 7 | settings 试点（A6；结构与测试原子提交） | `examples/settings/app/{app,settings_app_test}.mbt` |
| 8 | workbench 试点（A7；先探测包测试再执行，降级路径见 A7） | `examples/mo_workbench/app/task_update.mbt` |
| 9 | 文档三处（A8），cookbook 体例对齐 Forms 节 | `docs/tea-program-model.md`、`docs/non-render-component-cookbook.md`、`docs/architecture.md` |
| 10 | 收口（A9 + 回归两试点包测试）；可选 A10 quickcheck | `scripts/*.mjs` |

Execution order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10.

**Minimal loop** (AGENTS router): editing-time `moon test <pkg> --target native`; slices 4/10 run matching validators. No daily/platform profiles (both pilots are headless package-level).

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-23 | 范围 = Feature 核心 + views/form 键控 API + settings（必选）/workbench 双试点 + 文档（用户选定） |
| 2026-09-23 | 治理 = 只写计划不写 RFC/ADR；P13 澄清进 doc comment + PR 描述（用户选定） |
| 2026-09-23 | 命名 = `Feature`（单元按角色命名而非谱系命名；`SubProgram` 谱系名弃用）+ `scope` 挂载 + `ScopedFeature` 结果类型；消歧 `RendererFeature`/feature-status 文档词 |
| 2026-09-23 | 结构 = Feature 与 scope 分离（同单元可挂不同父级）；`Program` 保留 runtime 根 + `from_feature` 桥接 |
| 2026-09-23 | 类型修正 = P1 不做 `Feature::map`（单向 fmap 在 update 输入侧不封闭），抬升全在 `scope(wrap)`；`combine` 与 prism 双向 map 后置 |
| 2026-09-23 | 试点保外层 wrapper-variant 枚举与 `Program::simple` 接线形状（对齐 showcase/mo_workbench 先例，最小化测试 churn） |
| 2026-09-23 | 计划获批（ExitPlanMode），开始执行 |
| 2026-09-23 | 镜头参数名 `get`/`set` → `read`/`write`：`get` 是 MoonBit 保留/上下文关键字，作为字段名与参数名直接解析失败；概念文档仍用 get/set 术语 |
| 2026-09-23 | MoonBit 语法规则：参数/字段类型的箭头函数左侧必须带括号（`(Parent) -> Child`，裸 `Parent -> Child` 解析失败）；`pub enum` 变体外部只读，对外可构造枚举用 `pub(all) enum` |
| 2026-09-23 | workbench settings scope 的 `view` 字段显式 `abort`：子 section 视图依赖父级输入（appearance/theme/窗口尺寸），scope 只覆盖 update/effect 抬升；若未来拆出 child-pure 视图再接线 `ScopedFeature::view`（已写入代码注释与 cookbook 规则） |
| 2026-09-23 | settings 根程序 `Program::simple` → `Program::simple_with_environment`：纯 update 形状保留，view 签名带 env 只为把真实 `ViewEnvironment` 传给 scoped view（与「保 Program::simple 形状」的原意一致：不引入 effectful 根 update） |

## Progress

| Date | Note |
|------|------|
| 2026-09-23 | 计划定稿并获批；探索结论已核实（program.mbt 签名、settings 486 行/4 测试、form 无键控 API、分类器 token 两处、Feature 标识符可用） |
| 2026-09-23 | Slice 1：计划落盘 + README Active 登记（guidance 校验通过） |
| 2026-09-23 | Slice 2-3：`moui/core/feature.mbt` + `feature_test.mbt` 落地，core 99/99 绿。环境修复：homebrew simdjson ABI 升级导致 node 断链（缺 `libsimdjson.29.dylib`），以 Cellar 4.2.4 的 .29 建符号链接恢复（node 不依赖 simdjson，重装 bottle 同样断链，符号链接是正确修法） |
| 2026-09-23 | Slice 4：分类器三处 token + 预算三处带理由更新（root/core api-surface、views pub(all)）→ api/maintenance/generated 三校验绿 |
| 2026-09-23 | Slice 5-6：根 facade `pub using @core {type Feature, ScopedFeature}`；`form_field_action.mbt` + 测试（form 7/7）；`views.mbt` 门面 re-export `type FieldAction` + `update_named_field` |
| 2026-09-23 | Slice 7：settings 试点完成，5/5 绿。三段 Feature + scope、profile 键控 FieldAction、snapshot 镜头往返、`simple_with_environment` 根接线 |
| 2026-09-23 | Slice 8：workbench `AppearanceChanged` 委托点改 scope，77/77 绿；记录 view-字段 abort 的结构性边界（父级输入无法进入子 Feature view） |
| 2026-09-23 | Slice 9：三处文档落地（tea `## Feature Composition`、cookbook `## Feature Composition With Scope` + `### Keyed field messages`、architecture 关键面） |
| 2026-09-23 | Slice 10：九个静态校验全绿；回归 core 99 + views 37 + settings 5 + workbench 77 = 218 项全绿。A10 quickcheck 未做（可选，不阻塞）。**计划整体完成，状态可迁 `done/`** |
