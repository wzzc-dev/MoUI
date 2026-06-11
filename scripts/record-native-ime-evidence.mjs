#!/usr/bin/env node

import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_native_ime_evidence";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_native_ime_evidence/record_native_ime_evidence.exe",
);

const usage = () => {
  console.error(`Usage: node scripts/record-native-ime-evidence.mjs <manifest.json> <macos|windows|linux> [options]

Options:
  --host <description>                  Matching host that produced the logs.
  --consumer-command <command>          Showcase native Skia command that
                                        produced the IME logs.
  --candidate-anchor-log <path>         Log proving IME candidate anchor.
  --surrounding-text-log <path>         Log proving surrounding text offsets.
  --composition-visual-log <path>       Log proving composition visuals.
  --commit-delete-log <path>            Log proving IME commit/delete flows.
  --cursor-update-log <path>            Log proving cursor-area updates.
  --scroll-anchor-log <path>            Log proving anchor after scrolling.
  --scale-dpr-anchor-log <path>         Log proving anchor after scale/DPR.
  --resize-anchor-log <path>            Log proving anchor after resize.
  --note <text>                         Additional IME evidence note; may repeat.`);
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
const tmp = mkdtempSync(join(tmpdir(), "moui-native-ime-evidence-plan-"));
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
    "--consumer-command",
    plan.consumerCommand,
    "--provenance-kind",
    "matching-host-artifact",
    "--provenance-host",
    plan.host,
  ];

  for (const key of Object.keys(plan.observations)) {
    recorderArgs.push("--set", `${key}=${plan.observations[key]}`);
  }
  for (const artifact of plan.artifacts) {
    recorderArgs.push("--artifact", artifact);
  }
  for (const artifact of plan.provenanceArtifacts) {
    recorderArgs.push("--provenance-artifact", artifact);
  }
  for (const note of plan.notes) {
    recorderArgs.push("--note", note);
    recorderArgs.push("--provenance-note", note);
  }

  run(process.execPath, recorderArgs, { cwd: repoRoot });
  console.log(`${manifestPath}: recorded ${platform} native IME evidence (${plan.status})`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
