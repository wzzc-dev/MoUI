#!/usr/bin/env node

import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_native_skia_evidence";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_native_skia_evidence/record_native_skia_evidence.exe",
);

const usage = () => {
  console.error(`Usage: node scripts/record-native-skia-evidence.mjs <manifest.json> <macos|windows|linux> [options]

Options:
  --host <description>                  Matching host that produced the logs.
  --provider-preflight-log <path>       Log proving the platform Skia provider.
  --fallback-unavailable-log <path>     Log proving fallback unavailable output.
  --renderer-smoke-log <path>           Real MoUI Skia renderer pixel smoke log.
  --gpu-renderer-smoke-log <path>       Real MoUI Skia GPU route smoke log.
  --async-image-log <path>              Real MoUI Skia async image smoke log.
  --showcase-log <path>                 Showcase *_skia first-frame log.
  --gpu-showcase-log <path>             Showcase macOS GPU first-frame log.
  --note <text>                         Additional Skia evidence note; may repeat.`);
};

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(0);
}
if (args.length < 2) {
  usage();
  process.exit(2);
}

const run = (command, commandArgs, options = {}) => {
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd ?? repoRoot,
    encoding: "utf8",
  });
  if (
    result.stdout &&
    !(options.failureStdoutToStderr && result.status !== 0)
  ) {
    process.stdout.write(result.stdout);
  }
  if (result.stdout && options.failureStdoutToStderr && result.status !== 0) {
    process.stderr.write(result.stdout);
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) process.exit(result.status ?? 1);
};

const manifestPath = resolve(invocationRoot, args[0]);
const platform = args[1];
const tmp = mkdtempSync(join(tmpdir(), "moui-native-skia-evidence-plan-"));
const planPath = join(tmp, "plan.json");

try {
  run("moon", ["build", toolPackage, "--target", "native"]);
  run(
    toolExe,
    [
      manifestPath,
      platform,
      "--repo-root",
      repoRoot,
      "--plan-output",
      planPath,
      ...args.slice(2),
    ],
    { cwd: invocationRoot, failureStdoutToStderr: true },
  );

  const plan = JSON.parse(readFileSync(planPath, "utf8"));
  const recorderArgs = [
    join(repoRoot, "scripts/record-platform-evidence-manifest.mjs"),
    manifestPath,
    platform,
    "--host",
    plan.host,
    "--skia-status",
    plan.status,
    "--skia-provenance-kind",
    "matching-host-artifact",
    "--skia-provenance-host",
    plan.host,
  ];

  for (const key of Object.keys(plan.observations)) {
    recorderArgs.push("--skia-set", `${key}=${plan.observations[key]}`);
  }
  for (const artifact of plan.artifacts) {
    recorderArgs.push("--skia-artifact", artifact);
    recorderArgs.push("--skia-provenance-artifact", artifact);
  }
  for (const note of plan.notes) {
    recorderArgs.push("--skia-note", note);
    recorderArgs.push("--skia-provenance-note", note);
  }

  run(process.execPath, recorderArgs, { cwd: repoRoot });
  console.log(`${manifestPath}: recorded ${platform} native Skia evidence (${plan.status})`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
