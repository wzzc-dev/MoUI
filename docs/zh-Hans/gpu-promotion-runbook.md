# GPU 晋升运行手册

如何记录 ADR 0006 所需的 matching-host 证据，并最终翻转 `NativeGpuPlatform::gpu_promoted`，使 `auto` 选择 `SkiaGpuNative`。

这是 **Wave A** 工具链：scaffold manifests、gate inventory、macOS short-path hooks 和 validators。它本身**不会**晋升任何平台。

## 规则

1. Source paths、package tests、offscreen GPU smoke 和 `PictureRecorded` **不是** promotion。
2. 每个平台**独立**晋升。
3. 只有在 manifest 通过 `node scripts/validate-gpu-promotion-manifest.mjs <file> --require-passed` 后，才在源码中翻转 `gpu_promoted`（移动端：在 `--require-passed` 下使用带 `gpuPromotionEvidence` 的 runtime manifest）。
4. 不要提交 `artifacts/` 下的生成文件（已 gitignored）。从 ADR 0006 / release notes 链接 CI artifacts 或 smoke logs。

## Seven gates

| Gate | 要求 |
| --- | --- |
| `readbackEliminated` | 生产 present path：没有 full-frame CPU readback / image intermediates |
| `rendererThread` | Worker 拥有 GPU context/surface |
| `mailboxOk` | Latest-wins frames；lifecycle controls 永不丢弃 |
| `performance` | >= 600s；p95 <= 16.7ms@60 / 8.3ms@120；dropped &lt; 1%；input->present <= 2 VSync |
| `memory` | 有界；>= 100 次 surface recreations；>= 100 次 fg/bg cycles |
| `contextLoss` | Recover <= 3 VSyncs；raster fallback 保持 `AppRuntime` |
| `rasterFallback` | repeated recovery failure 后自动发生 |

Schema 示例：[`gpu-promotion-manifest.example.json`](../gpu-promotion-manifest.example.json)。

## 命令

### MoonBit scaffold tool

```sh
moon run tools/moui/gpu_promotion_scaffold --target native -- \
  --platform macos --out-dir artifacts/gpu-promotion/macos/manual
moon test tools/moui/gpu_promotion_scaffold --target native
```

Node `scripts/record-gpu-promotion-smoke.mjs` 是这个工具之上的薄 orchestrator（并可选运行 macOS short-smoke）。


### Static guard（worker 不得通过 readback present）

```sh
node scripts/validate-gpu-worker-no-readback.mjs
```

### Scaffold 一个 pending manifest + gap report

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos
```

写入 `artifacts/gpu-promotion/<platform>/<timestamp>/`：

- `gpu-promotion-manifest.json` — Wave A 中始终为 `gpuPromoted: false`
- `gap-report.md` — 阻塞 `auto` -> GPU 的剩余事项
- `gate-inventory.json` — 每个 gate 的工具覆盖情况
- `recorder.log`

### macOS short-path smoke（仅 partial diagnostics）

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode short-smoke
```

运行 `scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke --run-showcase-smoke`，解析 Metal markers，并填充 **partial** diagnostics。仍然**不是** promotion。

直接 smoke（不通过 recorder）：

```sh
scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke --run-showcase-smoke
```

### Validate

```sh
# Schema / structural checks (pending manifests OK)
node scripts/validate-gpu-promotion-manifest.mjs \
  artifacts/gpu-promotion/macos/<ts>/gpu-promotion-manifest.json

# Promotion bar (must fail until gates are real)
node scripts/validate-gpu-promotion-manifest.mjs \
  artifacts/gpu-promotion/macos/<ts>/gpu-promotion-manifest.json \
  --require-passed
```

### macOS performance harness（partial gate）

```sh
# 15s measured window after warm-up (dev)
node scripts/run-macos-gpu-performance-smoke.mjs --duration-ms 15000 --prepare

# ADR performance gate length
node scripts/run-macos-gpu-performance-smoke.mjs --duration-ms 600000 --prepare

# or via recorder
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode performance --duration-seconds 15
```

成功日志必须包含 `surface_route=metal-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface`。如果看到 `Ganesh Metal runtime is unavailable; falling back to raster`，这些数字就不是 GPU-present 证据。普通运行使用 `moon run ... --target native`；Skia/Metal flags 来自 moui_skia prebuild。

写出带 p95/drop%/duration 的 `metrics.json`。它仍会让 mailbox/memory/context-loss gates 保持 incomplete，且永远不会设置 `gpuPromoted=true`。

### Dry-run

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --dry-run
```

### Lib self-test

```sh
node scripts/test-gpu-promotion-manifest-lib.mjs
```

## Modes

| Mode | 状态 | 含义 |
| --- | --- | --- |
| `scaffold` | implemented | Pending manifest + inventory |
| `short-smoke` | macOS only | Metal first-frame / GPU smoke markers |
| `full` | skeleton only | 写出 `full-plan.json` + `metrics-template.json`，可合并 `--metrics-json`，退出 `3` |

`full` 仍会以 `3` 退出，因此自动化不能把它视为 promotion success。测量值可以通过以下方式合并：

```sh
moon run tools/moui/gpu_promotion_scaffold --target native -- \
  --platform macos --out-dir artifacts/gpu-promotion/macos/manual \
  --mode full --metrics-json path/to/metrics.json
```

即使合并了 metrics，该工具也**永远不会**设置 `gpuPromoted=true`。

本地 macOS short-path recording 示例（仅 partial evidence）：

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode short-smoke
# expect shortPathOk=true, gpuPromoted=false, schema validate ok
```

## 产品默认值（当前）

截至 2026-07-14，**所有** `NativeGpuPlatform::gpu_promoted` 分支都返回 `true`。只要 host surface 可用，产品 `auto` 就会选择 GPU。本运行手册仍用于记录 matching-host seven-gate evidence，以支撑 quality claims；它不再 gate product default。

继续保持：

- 显式 `skia-raster` / `MOUI_SKIA_RENDERER=skia-raster`
- terminal GPU failure 后的 sticky raster recovery
- fallback-Skia packaging（`gpuPromoted: false`，selected raster）

## 证据收集的平台顺序（建议）

1. macOS Metal（claim already recorded）  
2. Web WebGPU（optional promotion record；already product GPU mainline）  
3. iOS Metal（device）  
4. Android Vulkan（+ API 23 GLES fallback evidence）  
5. HarmonyOS EGL（signed device）  
6. Windows D3D12（MSVC host）  
7. Linux Wayland Vulkan  

## 相关文档

- ADR：[`decisions/0006-mobile-gpu-surface-and-render-thread.md`](../decisions/0006-mobile-gpu-surface-and-render-thread.md)
- 路线图：[`shell-mainline-roadmap.md`](shell-mainline-roadmap.md)
- 能力说明：[`renderer-capability-report.md`](renderer-capability-report.md)
- 会话：[`ai-sessions/2026-07-13-all-platform-native-gpu-workers.md`](../ai-sessions/2026-07-13-all-platform-native-gpu-workers.md)
