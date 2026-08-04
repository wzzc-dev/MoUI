# Plan: Validation hygiene cleanup

- **Status**: done and archived（2026-08-04）
- **Goal**: 消除 MoUI 验证体系中的"验证验证体系本身"工作量——validator
  自测（`test-*.mjs` 与 `tools/moui/*` wbtest）、dry-run 假门禁、纯 token
  形态检查——把验证投入转向真实行为校验（渲染器能力声明一致性、文档引用
  解析）。**产品代码行为零变化（仅 wgpu provider 能力自报诚实化一处）**。
- **Decisions**: 用户决策（2026-08-03）：全面整顿；validator 自测直接删除；
  新增两个行为校验器。
- **Related**: `docs/plans/active/moonbit-tooling-formalization.md`
  （其 "Keep as Node tests" 条目被本计划撤销）、`docs/testing.md`、
  `checks/profiles.json`、`smoke/gates.json`。

## 依据（实测数据，2026-08-03 清点）

`scripts/` 下 94 个文件，其中 21 个 `test-*.mjs`；`tools/moui/` 32 个包，
31 个包带 `*_wbtest.mbt`。`daily` profile 约 30 个追加步骤中约 20 个是
validator 自测。`pr` profile 含 "smoke nightly dry-run" 步骤（只打印计划，
不执行任何 smoke）。`smoke/gates.json` 6 个 suite，CI 实际只执行 2 个。

## 删除清单

### A. 纯验证体系自测 test-*.mjs（13 个）

| 文件 | 引用点 |
|---|---|
| `scripts/test-check-runner.mjs` | profiles.json:467；docs/testing.md:64；docs/zh-Hans/testing.md:48 |
| `scripts/test-gpu-performance-metrics.mjs` | profiles.json:460；docs/testing.md:63；docs/zh-Hans/testing.md:47 |
| `scripts/test-gpu-promotion-manifest-lib.mjs` | profiles.json:453；docs/testing.md:62；docs/zh-Hans/testing.md:46；docs/gpu-promotion-runbook.md:123；docs/zh-Hans/gpu-promotion-runbook.md:113 |
| `scripts/test-record-web-runtime-presentation.mjs` | profiles.json:419；docs/testing.md:58；docs/zh-Hans/testing.md:42 |
| `scripts/test-smoke-check.mjs` | profiles.json:474；moui-runtime-gates.yml:48-49；docs/testing.md:65,404-405；docs/zh-Hans/testing.md:49,255-256 |
| `scripts/test-smoke-gate.mjs` | profiles.json:481；moui-runtime-gates.yml:52-53；docs/testing.md:67；docs/zh-Hans/testing.md:51 |
| `scripts/test-sync-website-docs.mjs` | profiles.json:530 |
| `scripts/test-validate-architecture-validators.mjs` | 孤儿（无任何引用） |
| `scripts/test-validate-conformance-capture-manifest.mjs` | profiles.json:375；docs/testing.md:52；docs/zh-Hans/testing.md:36 |
| `scripts/test-validate-skia-entrypoints.mjs` | profiles.json:333；docs/testing.md:47；docs/zh-Hans/testing.md:31 |
| `scripts/test-validate-web-runtime-handoff-manifest.mjs` | profiles.json:398；docs/testing.md:55；docs/zh-Hans/testing.md:39 |
| `scripts/test-validate-web-runtime-handoff.mjs` | profiles.json:616；docs/testing.md:98；docs/zh-Hans/testing.md:70 |
| `scripts/test-validate-web-runtime-presentation-manifest.mjs` | profiles.json:426；docs/testing.md:59；docs/zh-Hans/testing.md:43 |

### B. tools/moui validator/generator wbtest（31 个）

全部 31 个 `tools/moui/*/*_wbtest.mbt`（claim_macos_gpu_promotion、
conformance_capture_scaffold、generate_feature_proof_report、
generate_grapheme_break_fixtures、generate_grapheme_property_data、
generate_i18n_catalogs、generate_repo_docs、gpu_promotion_scaffold、
interpret_macos_gpu_smoke_log、refresh_evidence_table、sync_website_docs、
validate_api_surface、validate_check_profiles、
validate_conformance_capture_manifest、validate_gpu_promotion_manifest、
validate_gpu_worker_no_readback、validate_guidance_consistency、
validate_harness_invariants、validate_maintenance_baseline、
validate_package_manifest、validate_platform_adapter_duplication、
validate_renderer_provider_manifests、validate_skia_entrypoints、
validate_smoke_catalog、validate_source_file_policy、
validate_web_runtime_handoff、validate_web_runtime_handoff_manifest、
validate_web_runtime_presentation_manifest、validate_window_dependency、
verify_feature_proof_coverage、window_dependency_info）。无 docs/checks/
workflows 独立引用；仅被 profiles.json 的 5 个 `moon test tools/moui/*`
步骤覆盖（一并删除）。

### C. 假门禁与 profile 步骤

- `pr` profile "smoke nightly dry-run" 步骤（profiles.json:129-138）
- `daily` profile 16 个自测步骤（Skia entrypoint validator tests、
  generated repository facts tests、source file policy tests、capture
  manifest validator tests、Web runtime handoff manifest tests、Web
  runtime presentation recorder tests、Web runtime presentation manifest
  tests、GPU promotion manifest tests、GPU promotion scaffold tests、GPU
  promotion scaffold node wrapper tests、GPU performance metrics parser
  tests、check runner tests、smoke catalog tests、smoke gate tests、
  website docs catalog tests、Web runtime handoff tests）
- `moui-runtime-gates.yml` catalog job：`test-smoke-check.mjs` ×2、
  `test-smoke-gate.mjs` ×2、`smoke-gate.mjs --tier "$SMOKE_GATE" --dry-run --json`

## 保留清单（产品行为/构建测试，8 个 test-*.mjs）

`test-browser-route-history.mjs`、`test-browser-runtime-events.mjs`、
`test-moui-prebuild.mjs`（测 moui/build.js 构建链）、
`test-playground-assets.mjs`、`test-web-bundle-tools.mjs`、
`test-web-canvas2d-lazy-fallback.mjs`、`test-web-semantics-dom.mjs`、
`test-webgpu-runtime-radial.mjs`。

## 后续阶段（Phase 2-6 概要）

1. **Phase 2**：删除 A/B/C 清单文件，更新 profiles.json、moui-runtime-gates.yml、
   docs/testing.md + zh-Hans、moonbit-tooling-formalization.md、budgets。
2. **Phase 3**：收窄 smoke gates 执行面——审计 6 个 suite 的 CI 接线，
   能接线的接线，不能的显式改 `manual`。
3. **Phase 4**：新增行为校验器 A `validate_renderer_capability_consistency`
   （代码自报 vs renderer-capability-report.md），修复现有不一致。
4. **Phase 5**：新增行为校验器 B `validate_doc_references`（文档路径/符号
   引用必须真实存在），替代 guidance token 检查，修复现有漂移。
5. **Phase 6**：文档收尾与全量验证（pr + daily 全绿）。

## 验收口径

1. **完成度**：删除清单全部落地；daily profile 步骤数显著下降；无遗留
   对被删文件的引用（grep 验证）。
2. **可维护性**：验证体系不再测试自身；daily 中产品测试占比提升。
3. **工程质量**：两个新行为校验器接入 pr profile 并带规格测试；此前
   文档/能力声明漂移全部修复或显式豁免。
4. **长期维护**：gates.json 目录与 CI 执行面一致；budgets 与删除同步。

## 验证结果（2026-08-03）

- 所有与本次改动相关的门禁步骤全绿：`check profile catalog`、
  `guidance consistency`、`doc references`（新）、
  `renderer capability consistency`（新）、harness invariants、platform
  adapter duplication、renderer provider manifests、GPU promotion manifest、
  GPU worker no-readback、smoke catalog、generated interface drift、
  `moon fmt --check`、`moon check`、lint。
- 核心产品测试全绿：moui/core 77/77、moui/views 11/11、
  moui/render 39/39、moui/runtime 87/87。
- 新校验器规格测试全绿：capability 7/7、doc references 13/13。
- **既有技术债（非本次引入，已用文件状态与 stash 对照证实）**：
  - `validate_api_surface`：moui/render/pkg.generated.mbti 906 行 > 846、
    声明 300 > 274、renderer_contract 301 > 275（并级联导致
    `generate-repo-docs --check` 失败）。
  - `validate_maintenance_baseline`：line_budget_catalog.mbt 394 > 390、
    command_palette.mbt 141 > 130。
  - `validate_source_file_policy`：wgpu/native_renderer.mbt 1571 > 1570、
    native_smoke.mbt 1249 > 1248、validate_api_surface/main.mbt 2044 > 2042。
  - `validate_window_dependency`：checks/window-dependency-exception.txt
    遗留豁免文件（provider-phase-e-local-window）在 moon.work 无 window
    member 时失效。
  - 以上建议作为后续债务项单独处理（放宽预算或缩减 API/行数）。
