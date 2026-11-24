#!/usr/bin/env node

// Headless-browser evidence for `moui dev --web --hot` (Web state-preserving
// refresh). Edits the fixture app, waits for the dev build to advance, and
// asserts the reload restored the committed model plus the framework transient
// snapshot (focus and scroll) that the renderer flushed on unload. Also reports
// edit-to-paint latency over N runs as p50/p95.
//
// Driven by scripts/web-hot-reload-smoke.sh; see docs/testing.md.

import fs from "node:fs";
import path from "node:path";
import { CdpSession, closePageTarget, createPageTarget, evaluate } from "./lib/web-runtime-cdp.mjs";

const args = process.argv.slice(2);
const valueOf = (name, fallback) => {
  const index = args.findIndex((arg) => arg === name || arg.startsWith(`${name}=`));
  if (index < 0) return fallback;
  const arg = args[index];
  if (arg.includes("=")) return arg.slice(arg.indexOf("=") + 1);
  return args[index + 1] ?? fallback;
};
const port = Number(valueOf("--port", "18282"));
const cdpUrl = valueOf("--cdp", "http://127.0.0.1:19333");
const runs = Math.max(1, Number(valueOf("--runs", "10")) || 10);
const appSource = path.resolve(valueOf("--app", "moui_tests/web_hot_fixture/app/app.mbt"));
const evidenceDir = path.resolve(valueOf("--evidence", "artifacts/web-hot-reload"));
const pageUrl = valueOf("--page", `http://127.0.0.1:${port}/`);
const statusUrl = `http://127.0.0.1:${port}/__moui/status`;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const checks = [];
const latencies = [];
const originalSource = fs.readFileSync(appSource, "utf8");
let restored = false;

const record = (name, ok, detail = "") => {
  checks.push({ name, ok, detail });
  if (!ok) process.stderr.write(`FAIL ${name}: ${detail}\n`);
};

async function fetchStatus() {
  const response = await fetch(statusUrl, { cache: "no-store" });
  return await response.json();
}

async function waitFor(fn, { timeoutMs = 120000, intervalMs = 100, label = "condition" }) {
  const deadline = Date.now() + timeoutMs;
  let lastError = "";
  while (Date.now() < deadline) {
    try {
      const value = await fn();
      if (value) return value;
    } catch (error) {
      lastError = String(error?.message || error);
    }
    await sleep(intervalMs);
  }
  throw new Error(`timed out waiting for ${label}${lastError ? ` (last error: ${lastError})` : ""}`);
}

async function evalRetry(session, expression) {
  return await waitFor(async () => {
    try {
      return await evaluate(session, expression);
    } catch (_) {
      return null;
    }
  }, { timeoutMs: 30000, intervalMs: 100, label: "page evaluation" });
}

const readCount = async (session) => {
  const text = await evalRetry(session, `document.querySelector('.moui-semantics-layer')?.textContent ?? ''`);
  const match = String(text).match(/Count:\s*(-?\d+)/);
  return match ? Number(match[1]) : null;
};

async function waitForCount(session, expected) {
  return await waitFor(async () => (await readCount(session)) === expected, {
    timeoutMs: 10000,
    intervalMs: 100,
    label: `model count ${expected}`,
  });
}

// A trusted pointer click, not `element.click()`: the browser moves host focus
// on pointer down, so the transient snapshot carries a focus path as well as
// the committed model update.
const clickIncrement = async (session) => {
  const point = await evalRetry(session, `(() => {
    const button = [...document.querySelectorAll('.moui-semantics-layer [role]')]
      .find(node => node.getAttribute('role') === 'button');
    if (!button) return null;
    const rect = button.getBoundingClientRect();
    return { x: Math.round(rect.x + rect.width / 2), y: Math.round(rect.y + rect.height / 2) };
  })()`);
  if (!point) throw new Error("increment button not found in the semantics layer");
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseMoved", x: point.x, y: point.y, button: "none", pointerType: "mouse",
  });
  await sleep(50);
  await session.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1, pointerType: "mouse",
  });
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1, pointerType: "mouse",
  });
};

async function wheelScroll(session) {
  const region = await evalRetry(session, `(() => {
    const region = [...document.querySelectorAll('.moui-semantics-layer [role]')]
      .find(node => node.getAttribute('role') === 'region');
    if (!region) return null;
    const rect = region.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  })()`);
  if (!region) throw new Error("scroll region not found in the semantics layer");
  const x = Math.round(region.x + region.width / 2);
  const y = Math.round(region.y + region.height / 2);
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "none", pointerType: "mouse" });
  await sleep(80);
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseWheel", x, y, deltaX: 0, deltaY: 120, button: "none", pointerType: "mouse", modifiers: 0,
  });
}

const readOrigin = async (session) => await evalRetry(session, "performance.timeOrigin");
const readHost = async (session) => await evalRetry(session, "globalThis.__mouiDevHost ?? null");
const readTransient = async (session) =>
  await evalRetry(session, `localStorage.getItem("wzzc-dev.moui.moui.dev.transient")`);

async function waitForReload(session, previousOrigin, label) {
  return await waitFor(async () => {
    const origin = await readOrigin(session).catch(() => null);
    if (origin === null || origin === previousOrigin) return null;
    const host = await readHost(session).catch(() => null);
    return host && host.paintedAt > 0 ? { origin, host } : null;
  }, { timeoutMs: 120000, intervalMs: 50, label });
}

async function waitForGeneration(previous) {
  return await waitFor(async () => {
    const status = await fetchStatus();
    return status.ok && status.generation > previous ? status : null;
  }, { timeoutMs: 120000, intervalMs: 100, label: "dev build generation" });
}

let editSequence = 0;
async function editSource() {
  editSequence += 1;
  const startedAt = Date.now();
  fs.appendFileSync(appSource, `\n// web-hot-smoke edit ${editSequence} ${startedAt}\n`);
  return startedAt;
}

const transientLines = (snapshot, prefix) =>
  String(snapshot ?? "")
    .split("\n")
    .filter((line) => line.startsWith(prefix));

async function main() {
  fs.mkdirSync(evidenceDir, { recursive: true });
  const target = await createPageTarget(cdpUrl);
  const session = new CdpSession(target.webSocketDebuggerUrl, 30000);
  await session.connect();
  await session.send("Page.enable");
  await session.send("Runtime.enable");
  try {
    await session.send("Page.navigate", { url: pageUrl });
    await waitFor(async () => {
      const host = await readHost(session).catch(() => null);
      return host && host.paintedAt > 0;
    }, { timeoutMs: 120000, intervalMs: 100, label: "initial dev app paint" });

    // Clear the dev handoff keys so the surviving model/transient can only come
    // from the unload flush and the runtime's per-update model save.
    const origin0 = await readOrigin(session);
    await evalRetry(session, `(() => {
      localStorage.removeItem("wzzc-dev.moui.moui.dev.state");
      localStorage.removeItem("wzzc-dev.moui.moui.dev.transient");
      return true;
    })()`);
    await evalRetry(session, "location.reload(); true").catch(() => {});
    const fresh = await waitForReload(session, origin0, "clean reload");
    await waitForCount(session, 0);

    // Correctness run: interact, then edit without any explicit flush. The real
    // pagehide flush must carry focus/scroll across the dev refresh.
    for (let i = 0; i < 3; i += 1) {
      await clickIncrement(session);
      await sleep(120);
    }
    await waitForCount(session, 3);
    await wheelScroll(session);
    await sleep(250);
    const beforeStatus = await fetchStatus();
    const beforeOrigin = await readOrigin(session);
    const editAt = await editSource();
    const buildStatus = await waitForGeneration(beforeStatus.generation);
    const { host } = await waitForReload(session, beforeOrigin, "reload after correctness edit");
    const paintLatency = host.paintedAt - editAt;
    latencies.push(paintLatency);
    await waitFor(async () => (await readHost(session))?.generation === buildStatus.generation, {
      timeoutMs: 10000, intervalMs: 100, label: "generation marker after reload",
    });

    await waitForCount(session, 3);
    const snapshot1 = await readTransient(session);
    const focus1 = transientLines(snapshot1, "focus ");
    const slots1 = transientLines(snapshot1, "slot ");
    record("model survives refresh", (await readCount(session)) === 3, `count=${await readCount(session)}`);
    record("focus flushed on unload and restored", focus1.length === 1, JSON.stringify(focus1));
    record("scroll flushed on unload and restored", slots1.length >= 1, JSON.stringify(slots1).slice(0, 160));
    record("paint happens after reload", paintLatency > 0, `${paintLatency.toFixed(0)} ms`);

    // Second refresh: the restored transient snapshot must round-trip again.
    await sleep(300);
    const secondOrigin = await readOrigin(session);
    const secondStatus = await fetchStatus();
    const secondEditAt = await editSource();
    const secondBuild = await waitForGeneration(secondStatus.generation);
    const second = await waitForReload(session, secondOrigin, "reload after stability edit");
    latencies.push(second.host.paintedAt - secondEditAt);
    await waitFor(async () => (await readHost(session))?.generation === secondBuild.generation, {
      timeoutMs: 10000, intervalMs: 100, label: "second generation marker",
    });
    const snapshot2 = await readTransient(session);
    record(
      "focus snapshot stable across two refreshes",
      JSON.stringify(transientLines(snapshot2, "focus ")) === JSON.stringify(focus1),
      `first=${JSON.stringify(focus1)} second=${JSON.stringify(transientLines(snapshot2, "focus "))}`,
    );
    record(
      "scroll snapshot stable across two refreshes",
      JSON.stringify(transientLines(snapshot2, "slot ")) === JSON.stringify(slots1),
      `first=${JSON.stringify(slots1).slice(0, 160)} second=${JSON.stringify(transientLines(snapshot2, "slot ")).slice(0, 160)}`,
    );
    await waitForCount(session, 3);

    // Latency runs: each edit must advance the build and repaint while the
    // model stays committed.
    let generation = secondBuild.generation;
    for (let run = 2; run < runs; run += 1) {
      const origin = await readOrigin(session);
      const editAtRun = await editSource();
      const nextStatus = await waitForGeneration(generation);
      generation = nextStatus.generation;
      const reload = await waitForReload(session, origin, `latency run ${run + 1}`);
      latencies.push(reload.host.paintedAt - editAtRun);
      await waitFor(async () => (await readHost(session))?.generation === nextStatus.generation, {
        timeoutMs: 10000, intervalMs: 100, label: `latency run ${run + 1} generation`,
      });
      record(`latency run ${run + 1} preserves model`, (await readCount(session)) === 3, `count=${await readCount(session)}`);
    }

    const overlayDisplay = await evalRetry(session, `(() => {
      const box = document.getElementById('__moui_dev_error');
      return box ? getComputedStyle(box).display : 'none';
    })()`);
    record("no dev error overlay", overlayDisplay === "none", String(overlayDisplay));
  } finally {
    fs.writeFileSync(appSource, originalSource);
    restored = true;
    session.close();
    await closePageTarget({ cdpUrl, id: target.id, timeoutMs: 2000, sleep });
  }
}

let failure = null;
try {
  await main();
} catch (error) {
  failure = error;
  record("smoke completed", false, String(error?.stack || error));
} finally {
  if (!restored) fs.writeFileSync(appSource, originalSource);
  const sorted = [...latencies].sort((a, b) => a - b);
  const percentile = (p) => {
    if (sorted.length === 0) return null;
    const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
    return Math.round(sorted[index]);
  };
  const report = {
    schemaVersion: 1,
    page: pageUrl,
    runs: latencies.length,
    latenciesMs: latencies.map((value) => Math.round(value)),
    p50Ms: percentile(50),
    p95Ms: percentile(95),
    checks,
    ok: !failure && checks.every((check) => check.ok),
    error: failure ? String(failure?.message || failure) : "",
  };
  fs.mkdirSync(evidenceDir, { recursive: true });
  fs.writeFileSync(path.join(evidenceDir, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(
    `web hot reload: ${report.ok ? "ok" : "failed"} runs=${report.runs} ` +
      `p50=${report.p50Ms}ms p95=${report.p95Ms}ms ` +
      `latencies=[${report.latenciesMs.join(", ")}]\n`,
  );
  for (const check of checks) {
    process.stdout.write(`  ${check.ok ? "ok" : "FAIL"} ${check.name}${check.ok ? "" : `: ${check.detail}`}\n`);
  }
  process.exit(report.ok ? 0 : 1);
}
