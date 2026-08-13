#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { validateEvidenceManifest } from "./validate-accessibility-foundation.mjs";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const probeSource = resolve(repoRoot, "scripts/macos-accessibility-probe.swift");
const defaultManifest = resolve(repoRoot, "artifacts/accessibility/macos/manifest.json");

const usage = () => {
  console.error(
    "Usage: node scripts/record-macos-accessibility-evidence.mjs " +
    "[--manifest PATH] [--app-log PATH] [--ax-log PATH] [--timeout-ms N] " +
    "[--skip-build] [--require-passed]",
  );
};

const args = process.argv.slice(2);
const options = {
  manifest: defaultManifest,
  appLog: resolve(repoRoot, "artifacts/accessibility/macos/showcase.log"),
  axLog: resolve(repoRoot, "artifacts/accessibility/macos/ax-probe.log"),
  timeoutMs: 30000,
  skipBuild: false,
  requirePassed: false,
};
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (["--manifest", "--app-log", "--ax-log", "--timeout-ms"].includes(arg)) {
    const value = args[index + 1];
    if (!value) throw new Error(`${arg} requires a value`);
    if (arg === "--manifest") options.manifest = resolve(repoRoot, value);
    if (arg === "--app-log") options.appLog = resolve(repoRoot, value);
    if (arg === "--ax-log") options.axLog = resolve(repoRoot, value);
    if (arg === "--timeout-ms") options.timeoutMs = Number(value);
    index += 1;
  } else if (arg === "--skip-build") {
    options.skipBuild = true;
  } else if (arg === "--require-passed") {
    options.requirePassed = true;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    throw new Error(`unknown argument: ${arg}`);
  }
}
if (!Number.isFinite(options.timeoutMs) || options.timeoutMs <= 0) {
  throw new Error("--timeout-ms must be positive");
}

const ensureDir = path => mkdirSync(dirname(path), { recursive: true });
const write = (path, content) => {
  ensureDir(path);
  writeFileSync(path, content);
};
const shell = (cmd, commandArgs, env, outputPath) => {
  ensureDir(outputPath);
  const result = spawnSync(cmd, commandArgs, {
    cwd: repoRoot,
    env: { ...process.env, ...env },
    encoding: "utf8",
  });
  write(outputPath, `${result.stdout ?? ""}${result.stderr ?? ""}`);
  return result;
};
const parseEvidenceLines = lines => {
  const generations = new Set();
  const semanticsCommits = [];
  const receipts = [];
  const announcements = [];
  const requests = [];
  for (const line of lines) {
    const text = line.replace(/^.*moui-a11y\s+/, "");
    const commit = text.match(/^commit kind=(\w+) generation=(\d+)/);
    if (commit) {
      generations.add(commit[2]);
      const details = text.match(/^commit kind=(\w+) generation=(\d+) nodes=(\d+) removed=(\d+) announcements=(\d+)/);
      semanticsCommits.push({
        kind: commit[1],
        generation: commit[2],
        nodeCount: details ? Number(details[3]) : 0,
        removedCount: details ? Number(details[4]) : 0,
        announcementCount: details ? Number(details[5]) : 0,
      });
    }
    const request = text.match(/^action-request id=([^ ]+) node=(\d+) generation=(\d+) kind=([^ ]+) value=(.*)$/);
    if (request) requests.push({
      id: request[1],
      nodeId: request[2],
      generation: request[3],
      kind: request[4],
      value: request[5],
    });
    const receipt = text.match(/^action-receipt node=(\d+) kind=([^ ]+) before=(\d+) after=(\d+) pending=(true|false)$/);
    if (receipt) {
      generations.add(receipt[3]);
      generations.add(receipt[4]);
      receipts.push({
        nodeId: receipt[1],
        kind: receipt[2],
        before: receipt[3],
        after: receipt[4],
        pending: receipt[5] === "true",
        result: "passed",
      });
    }
    const announcement = text.match(/^announcement generation=(\d+) live=([^ ]+) atomic=(true|false) text=(.*)$/);
    if (announcement) announcements.push({
      generation: announcement[1],
      live: announcement[2],
      atomic: announcement[3] === "true",
      text: announcement[4],
    });
  }
  return { generations: [...generations].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1), semanticsCommits, receipts, announcements, requests };
};

const nativeActionKind = action => {
  if (action === "AXPress") return ["activate", "select"];
  if (action === "AXCancel") return ["dismiss"];
  if (action === "AXIncrement") return ["increment"];
  if (action === "AXDecrement") return ["decrement"];
  if (action === "AXFocus") return ["focus"];
  if (action === "AXConfirm") return ["submit"];
  if (action.startsWith("AXSetValue(0.7)")) return ["set_numeric_value"];
  if (action.startsWith("AXSetValue(native AX probe)")) return ["set_text"];
  if (action.startsWith("AXSetSelection")) return ["set_selection"];
  return [];
};

const matchActionTrace = (nativeActions, requests, receipts) => {
  const matched = [];
  const failures = [];
  for (const action of nativeActions) {
    const kinds = nativeActionKind(action.action ?? "");
    const request = requests.find(candidate =>
      candidate.id === action.id && kinds.includes(candidate.kind) &&
      !matched.some(item => item.request === candidate),
    );
    const receipt = request && receipts.find(candidate =>
      candidate.nodeId === request.nodeId && candidate.kind === request.kind &&
      candidate.before === request.generation &&
      !matched.some(item => item.receipt === candidate),
    );
    if (!request || !receipt) {
      failures.push(`native action lacks matching request/receipt: ${action.id} ${action.action}`);
    } else {
      matched.push({ native: action, request, receipt });
    }
  }
  return { matched, failures };
};

const commit = shell("git", ["rev-parse", "HEAD"], {}, options.axLog).stdout.trim();
const host = shell("uname", ["-n"], {}, options.axLog).stdout.trim();
const os = shell("sw_vers", ["-productVersion"], {}, options.axLog).stdout.trim();
const architecture = shell("uname", ["-m"], {}, options.axLog).stdout.trim();
const common = {
  level: "L2",
  commit,
  host,
  os: `macOS ${os}`,
  architecture,
  window: "showcase/accessibility-probe",
  backend: "macos",
  generations: [],
  semanticsCommits: [],
  nativeTree: { source: "ax-api", requiredIdentifiers: [], missingIdentifiers: [], nodes: [], nodeCount: 0 },
  actions: [],
  keyboardFocus: [],
  accessibilityFocus: [],
  announcements: [],
  environment: {},
  result: "failed",
  failures: [],
  unverifiedCapabilities: ["voiceover", "narrator", "orca"],
};

if (process.platform !== "darwin") {
  common.failures.push("macOS AX evidence requires a macOS matching host");
} else {
  if (!options.skipBuild) {
    const build = shell("moon", ["build", "examples/showcase/macos_skia", "--target", "native"], {}, options.appLog);
    if (build.status !== 0) common.failures.push("Showcase macOS build failed");
  }
  const binary = resolve(repoRoot, "_build/native/debug/build/examples/showcase/macos_skia/macos_skia.exe");
  const child = spawn(binary, [], {
    cwd: repoRoot,
    env: {
      ...process.env,
      MOUI_ACCESSIBILITY_PROBE: "1",
      MOUI_ACCESSIBILITY_EVIDENCE: "1",
      MOUI_FIRST_FRAME_EXIT: "0",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const appOutput = [];
  child.stdout.on("data", chunk => appOutput.push(chunk.toString()));
  child.stderr.on("data", chunk => appOutput.push(chunk.toString()));
  if (child.pid) {
    const probe = spawnSync("xcrun", ["swift", probeSource, "--pid", String(child.pid), "--timeout", String(options.timeoutMs / 1000)], {
      cwd: repoRoot,
      env: process.env,
      encoding: "utf8",
    });
    write(options.axLog, probe.stdout ?? "");
    if (probe.stdout) {
      try {
        Object.assign(common, JSON.parse(probe.stdout));
      } catch (error) {
        common.failures.push(`AX probe returned invalid JSON: ${error.message}`);
      }
    }
  }
  if (!child.killed) child.kill("SIGTERM");
  await new Promise(resolvePromise => child.once("close", resolvePromise));
  write(options.appLog, appOutput.join(""));
  const parsed = parseEvidenceLines(appOutput.join("").split(/\r?\n/));
  const nativeActions = Array.isArray(common.actions) ? common.actions : [];
  const trace = matchActionTrace(nativeActions, parsed.requests, parsed.receipts);
  common.generations = parsed.generations;
  common.semanticsCommits = parsed.semanticsCommits;
  common.announcements = parsed.announcements;
  common.actions = [
    ...nativeActions,
    ...parsed.receipts.map(receipt => ({ ...receipt, source: "runtime-receipt" })),
  ];
  common.nativeTree = {
    ...(common.nativeTree ?? {}),
    source: "ax-api",
    runtimeActionRequests: parsed.requests,
    runtimeReceipts: parsed.receipts,
    matchedActionTrace: trace.matched,
  };
  common.failures.push(...trace.failures);
  if (common.result === "passed" && common.failures.length === 0 &&
      nativeActions.length > 0 && trace.matched.length === nativeActions.length &&
      parsed.announcements.length > 0) {
    common.result = "passed";
  } else if (common.failures.length === 0) {
    common.failures.push("AX probe or runtime evidence did not produce a complete L2 trace");
  }
}

const probe = JSON.parse(readFileSync(resolve(repoRoot, "checks/accessibility-probe.json"), "utf8"));
const validation = validateEvidenceManifest(common, probe, false, options.requirePassed);
if (validation.length > 0) common.failures.push(...validation);
write(options.manifest, `${JSON.stringify(common, null, 2)}\n`);
console.log(`wrote ${options.manifest}`);
if (common.failures.length > 0) {
  for (const failure of common.failures) console.error(`- ${failure}`);
  if (options.requirePassed) process.exit(1);
}
