#!/usr/bin/env node

import assert from "node:assert/strict";
import {
  buildPerformanceMetricsOverlay,
  parsePerformanceSmokeSummary,
} from "./lib/gpu-performance-metrics.mjs";

const sample = `
macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface; dimensions=2200x1360
macOS GPU performance smoke started; warm_up_presents=30; duration_ms=15000; title=MoUI Showcase
MoUI macOS GPU performance smoke completed refresh_hz=60 duration_ms=15120.5 warm_up_presents=30 presented=940 samples=910 p95_frame_ms=14.2 avg_frame_ms=16.1 max_frame_ms=22.0 dropped_frame_percent=0.4 input_to_present_p_vsync_intervals=0.85 budget_ms=16.7
MoUI macOS GPU promotion lifecycle completed surface_cycles=100 fg_bg_cycles=100 context_loss_done=1 recovered_within_vsyncs=2 recovery_count_before=0 fallback_count=0 automatic_fallback=false mailbox_ok=true readback_eliminated=true runtime_preserved=true
`;

const summary = parsePerformanceSmokeSummary(sample);
assert.ok(summary);
assert.equal(summary.status, "completed");
assert.equal(summary.refreshHz, 60);
assert.equal(summary.samples, 910);
assert.equal(summary.p95FrameMs, 14.2);
assert.equal(summary.droppedFramePercent, 0.4);
assert.equal(summary.metalPresent, true);
assert.ok(summary.lifecycle);
assert.equal(summary.lifecycle.surfaceCycles, 100);
assert.equal(summary.lifecycle.mailboxOk, true);

const metrics = buildPerformanceMetricsOverlay(summary);
assert.equal(metrics.promotionGates.performance.durationSeconds, 15.1205);
assert.equal(metrics.promotionGates.performance.p95FrameMs, 14.2);
assert.equal(metrics.gpuPromoted, undefined);
assert.equal(metrics.promotionGates.mailboxOk, true);
assert.equal(metrics.promotionGates.readbackEliminated, true);
assert.equal(metrics.promotionGates.memory.surfaceRecreationCycles, 100);
assert.equal(metrics.promotionGates.contextLoss.recoveredWithinVsyncs, 2);
assert.equal(metrics.diagnostics.workerThread, true);

assert.equal(parsePerformanceSmokeSummary("no marker"), null);

console.log("test-gpu-performance-metrics: ok");
