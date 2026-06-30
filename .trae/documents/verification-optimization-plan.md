# MoUI CI功能证明方案

## 概述

**目标**：建立"CI通过证明功能可用"的体系，包含完整CI测试流程、功能→CI证明映射、汇总workflow。

**证明标准**：分层证明
- **L1 API正确性**：包测试通过 = API可用（无需真机，每次PR触发）
- **L2 运行时行为**：matching-host平台smoke通过 = 运行时行为已证明（moui_skia变更时触发）
- **L3 跨平台一致性**：所有平台L2通过 = 功能完整证明

**关键设计**：moui_skia real-Skia smoke 只在 `moui_skia/**` 路径变更时触发，避免非Skia变更的PR等待真机。

## 完整CI测试流程

### 流程图

```
┌─────────────────────────────────────────────────────────────────┐
│ PR / push to main                                                │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ├──────────────────────┬──────────────────────────────┐
              │                      │                              │
              ▼                      ▼                              ▼
┌─────────────────────┐  ┌─────────────────────┐    ┌─────────────────────────┐
│ ci.yml (always)     │  │ ci.yml (always)     │    │ moui-skia-fallback.yml  │
│                     │  │                     │    │ (paths: moui_skia/**)   │
│ ┌─────────────────┐ │  │ ┌─────────────────┐ │    └───────────┬─────────────┘
│ │ conformance     │ │  │ │ api-surface     │ │                │
│ │ (macOS-14)      │ │  │ │ (macOS-14)      │ │                ▼
│ │ dev-check.sh    │ │  │ │ moon info       │ │    ┌─────────────────────────┐
│ │ text conformance│ │  │ │ drift check     │ │    │ fallback gate           │
│ │ golden scaffold │ │  │ └─────────────────┘ │    │ (ubuntu+windows)        │
│ └─────────────────┘ │  │                     │    │ moon check/test/info    │
│ ┌─────────────────┐ │  │ ┌─────────────────┐ │    │ native_smoke build      │
│ │ linux-platform  │ │  │ │ benchmark-      │ │    │ verify-* scripts        │
│ │ (ubuntu-24.04)  │ │  │ │ scaffold        │ │    └───────────┬─────────────┘
│ │ platform tests  │ │  │ │ (macOS-14)      │ │                │
│ └─────────────────┘ │  │ └─────────────────┘ │                │
│ ┌─────────────────┐ │  │                     │                │
│ │ windows-native  │ │  │ ┌─────────────────┐ │                │
│ │ (windows-2022)  │ │  │ │ macos-packaging │ │                │
│ │ MSVC build      │ │  │ │ (macOS-14)      │ │                │
│ └─────────────────┘ │  │ │ app bundle      │ │                │
└─────────┬───────────┘  │ └─────────────────┘ │                │
          │              └─────────┬───────────┘                │
          │                        │                            │
          │    ┌───────────────────┘                            │
          │    │                                                │
          ▼    ▼                                                │
┌──────────────────────────────────┐                            │
│ L1证明完成                        │                            │
│ (所有非Skia功能已证明)            │                            │
└──────────┬───────────────────────┘                            │
           │                                                    │
           │  ┌─────────────────────────────────────────────────┘
           │  │ (仅当 moui_skia/** 变更时)
           │  │
           ▼  ▼
┌─────────────────────────────────────────────────────────────────┐
│ moui-skia-real-skia-pr-smoke.yml (paths: moui_skia/**)          │
│                                                                 │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│ │ macOS real-Skia │ │ Linux real-Skia │ │ Windows real-   │   │
│ │ (macos-14)      │ │ (ubuntu-24.04)  │ │ Skia (windows)  │   │
│ │ release provider│ │ release provider│ │ MSVC release    │   │
│ │ 30min timeout   │ │ 30min timeout   │ │ 30min timeout   │   │
│ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘   │
│          │                   │                   │              │
│          ▼                   ▼                   ▼              │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ verify-native-smoke-log + verify-acceptance-log          │   │
│ │ (3平台并行)                                              │   │
│ └────────────────────────┬─────────────────────────────────┘   │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ L2证明完成                                                       │
│ (Skia渲染器功能+TextShaping+AsyncImage 已证明)                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ feature-proof-summary.yml (workflow_run触发)                     │
│                                                                 │
│ 1. 收集ci.yml + moui-skia-real-skia-pr-smoke.yml所有job status  │
│ 2. generate-feature-proof-report.mjs 生成报告                   │
│ 3. verify-feature-proof-coverage.mjs 验证覆盖                   │
│ 4. 上传 artifact + 写 GITHUB_STEP_SUMMARY                       │
└─────────────────────────────────────────────────────────────────┘
```

### 触发条件矩阵

| Workflow | 触发条件 | 说明 |
|----------|---------|------|
| `ci.yml` | push/PR to main | **总是运行**，L1证明 |
| `moui-skia-fallback.yml` | push/PR + `paths: moui_skia/**` | moui_skia fallback gate（已存在） |
| `moui-skia-real-skia-pr-smoke.yml` | PR + `paths: moui_skia/**` | **新增**，L2证明，仅moui_skia变更时触发 |
| `moui-runtime-smoke-gates.yml` | schedule nightly + manual | nightly Web runtime smoke（已存在，不改） |
| `moui-skia-*-real-skia-smoke.yml` | manual/weekly | 已存在的独立acceptance workflow（不改） |
| `feature-proof-summary.yml` | `workflow_run` on ci.yml completed | **新增**，汇总所有CI状态 |

### CI Job 到功能证明的映射

#### L1证明（ci.yml，每次PR运行）

| Job | 平台 | 证明功能 |
|-----|------|---------|
| `conformance` | macOS-14 | dev-check.sh: core/views/render/backend/host包测试 + 静态检查 + Web构建 + text conformance + golden scaffold |
| `api-surface` | macOS-14 | moon info drift check: API表面稳定性 |
| `linux-platform` | ubuntu-24.04 | Linux backend包测试: Linux平台契约 |
| `windows-native` | windows-2022 | Windows backend包测试 + MSVC构建: Windows平台契约 |
| `macos-packaging` | macOS-14 | macOS app bundle打包: macOS分发能力 |
| `benchmark-scaffold` | macOS-14 | benchmark target构建: 性能scaffold |

**L1证明的功能**（无需真机）：
- Core API (View/Element/Layout/Animation)
- Runtime lifecycle
- Views controls (Text/Button/TextField/Container/Row/Column/Flex/Stack/Scroll/List/Grid/Navigation)
- Host services协议 (clipboard/menus/dialogs URL)
- macOS/Windows/Linux backend包测试
- Web wasm-gc构建
- Renderer capability报告一致性

#### L2证明（moui-skia-real-skia-pr-smoke.yml，仅moui_skia变更时）

| Job | 平台 | 证明功能 |
|-----|------|---------|
| `macos-real-skia` | macOS-14 | macOS real-Skia像素: 17个渲染器功能 + TextShaping(SkParagraph) + EmojiText + AsyncImage(second-frame) |
| `linux-real-skia` | ubuntu-24.04 | Linux real-Skia像素: 同上 + Linux平台specific |
| `windows-real-skia` | windows-2022 | Windows real-Skia像素: 同上 + Windows MSVC |

**L2证明的功能**（需matching-host真机）：
- 17个渲染器功能 (Rect/RoundedRect/Gradient/Shadow/Text/Image/Clip/Transform/Opacity/LayerCompositing/BlendMode/FilterEffect/PathVector/ShaderEffect/TextShaping/EmojiText/AsyncImage)
- 真实Skia像素输出 (assert_pixel精确RGBA对比)
- 真实FontMgr字体fallback
- SkShaper/SkParagraph真实排版
- AsyncImage second-frame repaint

#### L3证明（汇总workflow验证）

`feature-proof-summary.yml` 检查所有L1+L2证据是否齐全：
- 如果moui_skia未变更：L1通过即证明完成
- 如果moui_skia变更：L1+L2都通过才证明完成

## 当前状态分析

### 现有CI workflow结构

| Workflow | 触发 | 平台 | 证明范围 |
|----------|------|------|---------|
| [ci.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/ci.yml) | push/PR | macOS/Linux/Windows | L1: 包测试+静态检查+Web构建 |
| [moui-skia-fallback.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/moui-skia-fallback.yml) | push/PR + `paths: moui_skia/**` | Ubuntu/Windows | L1: moui_skia fallback gate |
| [moui-runtime-smoke-gates.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/moui-runtime-smoke-gates.yml) | schedule+manual | macOS | L2: Web runtime(nightly) + macOS Skia(manual) |
| [moui-skia-macos-real-skia-smoke.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/moui-skia-macos-real-skia-smoke.yml) | manual | macOS | L2: macOS real-Skia acceptance |
| [moui-skia-linux-real-skia-smoke.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/moui-skia-linux-real-skia-smoke.yml) | weekly+manual | Linux | L2: Linux real-Skia acceptance |
| [moui-skia-windows-real-skia-smoke.yml](file:///Volumes/Data/Code/moon/MoUI/.github/workflows/moui-skia-windows-real-skia-smoke.yml) | manual | Windows | L2: Windows real-Skia acceptance |

### 关键gap

1. **PR无法自动证明L2**：real-Skia smoke是manual/weekly，PR不触发
2. **无汇总机制**：无法一目了然查看哪些功能已被CI证明
3. **AsyncImage Windows/Linux second-frame无PR自动化**

## 提议变更

### Part 1: 新增功能→CI证明映射文档

**文件**：`docs/feature-proof-matrix.md`

**内容**：
1. 分层证明标准定义（L1/L2/L3）
2. 完整功能→CI证明映射表
3. 每个功能的CI workflow link、job name、artifact path
4. 触发条件说明（moui_skia变更 vs 总是触发）
5. "如何为新功能添加CI证明"指南
6. 证据状态更新规则

**同步更新**：
- `docs/testing.md` 添加 "Feature Proof Matrix" section link
- `AGENTS.md` "Validation" section 添加 proof matrix link

### Part 2: 新增 moui-skia-real-skia-pr-smoke.yml

**文件**：`.github/workflows/moui-skia-real-skia-pr-smoke.yml`

**触发条件**：`paths: moui_skia/**`（仅moui_skia内容变更时触发）

```yaml
name: MoUI Skia Real-Skia PR Smoke

on:
  pull_request:
    paths:
      - "moui_skia/**"
      - ".github/workflows/moui-skia-real-skia-pr-smoke.yml"
  workflow_dispatch:

jobs:
  macos-real-skia:
    name: macOS real-Skia smoke
    runs-on: macos-14
    timeout-minutes: 30
    defaults:
      run:
        working-directory: moui_skia
    steps:
      - uses: actions/checkout@v5
      - uses: ./.github/actions/setup-moonbit
      - run: ../scripts/ci-moon-update.sh
      - name: Run macOS real-Skia smoke (release provider)
        run: |
          bash scripts/macos-accept-real-skia-smoke.sh \
            --log-dir logs \
            --skia-provider release \
            --link-mode static
      - name: Verify smoke markers
        run: |
          bash scripts/verify-native-smoke-log.sh logs/macos-native-smoke-output.log
          bash scripts/verify-acceptance-log.sh logs/macos-real-skia-acceptance.log
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: macos-real-skia-pr-smoke
          path: moui_skia/logs/
          if-no-files-found: warn

  linux-real-skia:
    name: Linux real-Skia smoke
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    defaults:
      run:
        working-directory: moui_skia
    steps:
      - uses: actions/checkout@v5
      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libwayland-dev libwayland-bin wayland-protocols \
            pkg-config unzip libfontconfig1-dev libfreetype-dev libharfbuzz-dev \
            fonts-noto-color-emoji
      - uses: ./.github/actions/setup-moonbit
      - run: ../scripts/ci-moon-update.sh
      - name: Run Linux real-Skia smoke (release provider)
        run: |
          bash scripts/linux-accept-real-skia-smoke.sh \
            --log-dir logs \
            --skia-provider release \
            --link-mode static
      - name: Verify smoke markers
        run: |
          bash scripts/verify-native-smoke-log.sh logs/linux-native-smoke-output.log
          bash scripts/verify-acceptance-log.sh logs/linux-real-skia-acceptance.log
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: linux-real-skia-pr-smoke
          path: moui_skia/logs/
          if-no-files-found: warn

  windows-real-skia:
    name: Windows real-Skia smoke
    runs-on: windows-2022
    timeout-minutes: 30
    defaults:
      run:
        working-directory: moui_skia
    steps:
      - uses: actions/checkout@v5
      - uses: ./.github/actions/setup-moonbit
      - shell: pwsh
      - name: Run Windows MSVC real-Skia smoke (release provider)
        shell: pwsh
        run: |
          .\scripts\windows-msvc-accept-real-skia-smoke.ps1 -LogDir logs
      - name: Verify smoke markers
        shell: pwsh
        run: |
          .\scripts\verify-native-smoke-log.ps1 -LogPath logs\windows-native-smoke-output.log
          .\scripts\verify-acceptance-log.ps1 -LogPath logs\windows-real-skia-acceptance.log
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: windows-real-skia-pr-smoke
          path: moui_skia/logs/
          if-no-files-found: warn
```

**设计要点**：
- 3个平台并行运行，总时间约20-30分钟
- 使用release provider而非source build（控制时间）
- paths filter确保仅moui_skia变更时触发
- 不影响现有的manual/weekly acceptance workflows

### Part 3: 新增汇总workflow

**文件**：`.github/workflows/feature-proof-summary.yml`

```yaml
name: MoUI Feature Proof Summary

on:
  workflow_run:
    workflows: ["MoUI CI"]
    types: [completed]
  workflow_dispatch:
    inputs:
      ci_run_id:
        description: Specific ci.yml run_id to summarize. Defaults to latest.
        required: false
        default: ""

jobs:
  summarize:
    name: Feature proof summary
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion != 'cancelled' || github.event_name == 'workflow_dispatch' }}
    steps:
      - uses: actions/checkout@v5

      - name: Collect CI workflow statuses
        id: collect
        uses: actions/github-script@v7
        with:
          script: |
            const owner = context.repo.owner;
            const repo = context.repo.repo;

            // 获取ci.yml最新run
            let runId;
            let runUrl;
            if (context.eventName === 'workflow_dispatch' && '${{ inputs.ci_run_id }}' !== '') {
              runId = parseInt('${{ inputs.ci_run_id }}');
            } else if (context.payload.workflow_run) {
              runId = context.payload.workflow_run.id;
            } else {
              const runs = await github.rest.actions.listWorkflowRuns({
                owner, repo, workflow_id: 'ci.yml', per_page: 1
              });
              runId = runs.data.workflow_runs[0].id;
            }

            // 收集ci.yml job status
            const ciJobs = await github.rest.actions.listJobsForWorkflowRun({
              owner, repo, run_id: runId
            });
            const status = {};
            for (const job of ciJobs.data.jobs) {
              status[job.name] = job.conclusion;
            }

            // 尝试收集moui-skia-real-skia-pr-smoke.yml（如果存在）
            try {
              const skiaRuns = await github.rest.actions.listWorkflowRuns({
                owner, repo, workflow_id: 'moui-skia-real-skia-pr-smoke.yml', per_page: 1
              });
              if (skiaRuns.data.workflow_runs.length > 0) {
                const skiaRun = skiaRuns.data.workflow_runs[0];
                const skiaJobs = await github.rest.actions.listJobsForWorkflowRun({
                  owner, repo, run_id: skiaRun.id
                });
                for (const job of skiaJobs.data.jobs) {
                  status[job.name] = job.conclusion;
                }
                status['_skia_smoke_triggered'] = true;
              } else {
                status['_skia_smoke_triggered'] = false;
              }
            } catch (e) {
              status['_skia_smoke_triggered'] = false;
            }

            const run = await github.rest.actions.getWorkflowRun({ owner, repo, run_id: runId });
            core.setOutput('status', JSON.stringify(status));
            core.setOutput('run_id', String(runId));
            core.setOutput('html_url', run.data.html_url);

      - name: Generate feature proof report
        env:
          JOB_STATUS: ${{ steps.collect.outputs.status }}
          RUN_URL: ${{ steps.collect.outputs.html_url }}
        run: |
          mkdir -p artifacts/feature-proof
          node scripts/generate-feature-proof-report.mjs \
            --status "$JOB_STATUS" \
            --run-url "$RUN_URL" \
            --output artifacts/feature-proof/proof-report.json

      - name: Verify feature proof coverage
        run: |
          node scripts/verify-feature-proof-coverage.mjs \
            --report artifacts/feature-proof/proof-report.json

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: feature-proof-summary
          path: artifacts/feature-proof/
          if-no-files-found: warn

      - name: Write summary
        if: always()
        run: |
          echo "## Feature Proof Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          cat artifacts/feature-proof/proof-report.md >> $GITHUB_STEP_SUMMARY
```

### Part 4: 新增脚本

#### 4.1 scripts/generate-feature-proof-report.mjs

读取CI job status，生成proof-report.json和proof-report.md。

**proof-report.json格式**：
```json
{
  "ciRunUrl": "https://github.com/...",
  "ciRunId": 12345,
  "timestamp": "2026-06-30T...",
  "skiaSmokeTriggered": true,
  "features": [
    {
      "feature": "Rect",
      "level": "L1",
      "proofJob": "conformance",
      "status": "success",
      "proven": true
    },
    {
      "feature": "TextShaping",
      "level": "L2",
      "proofJobs": ["macos-real-skia", "linux-real-skia", "windows-real-skia"],
      "status": {"macos-real-skia": "success", "linux-real-skia": "success", "windows-real-skia": "success"},
      "proven": true,
      "platforms": ["macOS", "Linux", "Windows"]
    }
  ],
  "summary": {
    "totalFeatures": 25,
    "proven": 25,
    "partial": 0,
    "gap": 0,
    "note": "skiaSmokeTriggered=false时，L2功能标记为skipped而非gap"
  }
}
```

**关键逻辑**：
- `skiaSmokeTriggered=false`时，L2功能status="skipped"（非gap，因为moui_skia未变更）
- `skiaSmokeTriggered=true`时，L2功能必须有对应job通过

#### 4.2 scripts/verify-feature-proof-coverage.mjs

验证规则：
- L1功能：对应job必须success
- L2功能（skiaSmokeTriggered=true）：对应job必须success
- L2功能（skiaSmokeTriggered=false）：跳过检查
- 输出gap列表，有未证明的必需功能则exit 1

### Part 5: 功能状态dashboard文档

**文件**：`docs/feature-status-dashboard.md`

**内容**：
1. 当前功能状态矩阵
2. 三大follow-up专项跟踪
3. 证据追溯索引
4. 更新规则

**同步更新**：
- `docs/renderer-capability-report.md` 添加dashboard link
- `docs/roadmap-2026.md` "Workstream 4" 添加dashboard link

## 假设与决策

### 假设
- release provider的Skia binary可用于所有平台CI runner
- paths filter `moui_skia/**` 正确覆盖所有Skia相关变更
- GitHub Actions `workflow_run` 可正确触发汇总workflow

### 决策
- **paths filter触发real-Skia smoke**：仅moui_skia变更时触发，非Skia变更PR不等待真机
- **独立workflow文件**：新建 `moui-skia-real-skia-pr-smoke.yml`，不修改ci.yml，职责清晰
- **使用release provider**：控制CI时间，避免source build的90分钟timeout
- **汇总workflow用workflow_run触发**：ci.yml完成后自动运行
- **保持分层证明**：L1(包测试)+L2(平台smoke)+L3(跨平台一致)
- **skiaSmokeTriggered标志**：moui_skia未变更时L2标记skipped而非gap

### 不在范围内
- 不修改ci.yml（保持现有6个job不变）
- 不改变现有 `moui-skia-*-real-skia-smoke.yml` 的manual/weekly调度
- 不改变 `moui-runtime-smoke-gates.yml` 的nightly/manual调度
- 不获取EmojiText跨平台color emoji一致性证据（功能gap）
- 不重构moui_tester→moui_tests

## 验证步骤

### CI验证
1. 创建非moui_skia变更的PR → 确认real-skia-pr-smoke不触发，ci.yml正常
2. 创建moui_skia变更的PR → 确认real-skia-pr-smoke触发，3平台并行
3. ci.yml完成后 → 确认feature-proof-summary自动触发
4. 确认proof-report.json正确反映L1/L2状态

### 文档验证
1. `node scripts/sync-website-docs.mjs --check`
2. 验证feature-proof-matrix.md中所有CI workflow link可访问
3. 验证feature-status-dashboard.md状态准确

### 回归验证
1. 确认现有 `moui-skia-fallback.yml` paths filter不受影响
2. 确认 `smoke/gates.json` catalog validation通过
3. `sh scripts/dev-check.sh` 确保bounded baseline通过

## 实施顺序

1. 创建 `docs/feature-proof-matrix.md`（功能→CI证明映射）
2. 创建 `.github/workflows/moui-skia-real-skia-pr-smoke.yml`（paths-filtered L2证明）
3. 新增 `scripts/generate-feature-proof-report.mjs`
4. 新增 `scripts/verify-feature-proof-coverage.mjs`
5. 创建 `.github/workflows/feature-proof-summary.yml`（汇总workflow）
6. 创建 `docs/feature-status-dashboard.md`
7. 更新 `docs/testing.md`、`AGENTS.md`、`docs/renderer-capability-report.md`、`docs/roadmap-2026.md` 添加links
8. 运行文档同步验证

## 预期产出

完成后：
1. **非moui_skia变更PR**：仅ci.yml运行（~5分钟），L1证明完成
2. **moui_skia变更PR**：ci.yml + real-skia-pr-smoke并行运行（~30分钟），L1+L2证明完成
3. **汇总workflow自动生成** proof-report，显示哪些功能已证明/skipped/gap
4. **开发者可通过文档** 查询每个功能的CI证据需求和触发条件
