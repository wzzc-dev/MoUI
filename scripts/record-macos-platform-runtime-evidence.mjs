#!/usr/bin/env node

import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_macos_platform_runtime_evidence";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_macos_platform_runtime_evidence/record_macos_platform_runtime_evidence.exe",
);

const usage = () => {
  console.error(`Usage: node scripts/record-macos-platform-runtime-evidence.mjs <manifest.json> [options]

Options:
  --host <description>                  Matching macOS host that produced logs.
  --consumer-command <command>          Showcase macOS Skia command that
                                        produced runtime logs.
  --window-evidence-command <command>   Window recorder command to store.
  --runtime-log <path>                  macOS runtime log; may repeat.
  --window-smoke-log <path>             macOS window-fork runtime smoke log;
                                        may repeat.
  --app-runtime-log <path>              Showcase macOS Skia first-frame runtime
                                        log; may repeat.
  --note <text>                         Additional platform evidence note; may
                                        repeat.
  --provenance-kind <github-actions|matching-host-artifact>
  --provenance-workflow <name>
  --provenance-job <name>
  --provenance-run-url <url>
  --provenance-run-id <id>
  --provenance-runner <label>
  --provenance-artifact <path>          Provenance artifact; may repeat.
  --provenance-note <text>              Provenance note; may repeat.

The helper validates matching-host macOS platform runtime log markers with the
MoonBit tools/moui/record_macos_platform_runtime_evidence package, requires the
macOS Skia and native IME observations to already be passed in the manifest,
updates only the macOS platform entry to passed, and delegates schema validation
to record-platform-evidence-manifest.mjs.`);
};

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(0);
}
if (args.length < 1) {
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

const requiredString = (value, field) => {
  if (typeof value !== "string") {
    console.error(`macOS platform runtime evidence plan is missing ${field}`);
    process.exit(1);
  }
  return value;
};

const manifestPath = resolve(invocationRoot, args[0]);
const tmp = mkdtempSync(join(tmpdir(), "moui-macos-platform-runtime-evidence-plan-"));
const planPath = join(tmp, "plan.json");

try {
  run("moon", ["build", toolPackage, "--target", "native"]);
  run(
    toolExe,
    [
      manifestPath,
      "--repo-root",
      repoRoot,
      "--plan-output",
      planPath,
      ...args.slice(1),
    ],
    { cwd: invocationRoot, failureStdoutToStderr: true },
  );

  const plan = JSON.parse(readFileSync(planPath, "utf8"));
  const host = requiredString(plan.host, "host");
  let provenanceKind = requiredString(plan.provenanceKind, "provenanceKind");
  let provenanceWorkflow = requiredString(plan.provenanceWorkflow, "provenanceWorkflow");
  let provenanceJob = requiredString(plan.provenanceJob, "provenanceJob");
  let provenanceRunUrl = requiredString(plan.provenanceRunUrl, "provenanceRunUrl");
  let provenanceRunId = requiredString(plan.provenanceRunId, "provenanceRunId");
  let provenanceRunner = requiredString(plan.provenanceRunner, "provenanceRunner");

  if (!provenanceKind) {
    provenanceKind = process.env.GITHUB_ACTIONS === "true"
      ? "github-actions"
      : "matching-host-artifact";
  }
  if (
    provenanceKind !== "github-actions" &&
    provenanceKind !== "matching-host-artifact"
  ) {
    console.error("--provenance-kind must be github-actions or matching-host-artifact");
    process.exit(2);
  }

  if (provenanceKind === "github-actions") {
    const serverUrl = process.env.GITHUB_SERVER_URL ?? "https://github.com";
    const repository = process.env.GITHUB_REPOSITORY ?? "";
    const runId = provenanceRunId || process.env.GITHUB_RUN_ID || "";
    provenanceWorkflow ||= process.env.GITHUB_WORKFLOW || "";
    provenanceJob ||= process.env.GITHUB_JOB || "";
    provenanceRunUrl ||= repository && runId
      ? `${serverUrl}/${repository}/actions/runs/${runId}`
      : "";
    provenanceRunId ||= runId;
    provenanceRunner ||= [
      process.env.RUNNER_NAME,
      process.env.RUNNER_OS,
      process.env.RUNNER_ARCH,
    ].filter(Boolean).join(" ");
  }

  const provenanceArtifacts = new Set(plan.provenanceArtifacts ?? []);
  const provenanceNotes = new Set(plan.provenanceNotes ?? []);
  provenanceNotes.add(
    provenanceKind === "github-actions"
      ? "macOS platform runtime evidence came from a successful GitHub Actions matching-host job."
      : "macOS platform runtime evidence came from local matching-host artifacts.",
  );

  const recorderArgs = [
    join(repoRoot, "scripts/record-platform-evidence-manifest.mjs"),
    manifestPath,
    "macos",
    "--status",
    "passed",
    "--host",
    host,
    "--window-evidence-command",
    requiredString(plan.windowEvidenceCommand, "windowEvidenceCommand"),
    "--consumer-command",
    requiredString(plan.consumerCommand, "consumerCommand"),
    "--provenance-kind",
    provenanceKind,
    "--provenance-host",
    host,
  ];

  for (const [key, value] of Object.entries(plan.observations ?? {})) {
    recorderArgs.push("--set", `${key}=${value}`);
  }
  for (const artifact of plan.artifacts ?? []) {
    recorderArgs.push("--artifact", artifact);
  }
  for (const note of plan.notes ?? []) {
    recorderArgs.push("--note", note);
  }
  for (const artifact of provenanceArtifacts) {
    recorderArgs.push("--provenance-artifact", artifact);
  }
  for (const note of provenanceNotes) {
    recorderArgs.push("--provenance-note", note);
  }
  if (provenanceKind === "github-actions") {
    recorderArgs.push("--provenance-workflow", provenanceWorkflow);
    recorderArgs.push("--provenance-job", provenanceJob);
    recorderArgs.push("--provenance-run-url", provenanceRunUrl);
    recorderArgs.push("--provenance-run-id", provenanceRunId);
    recorderArgs.push("--provenance-runner", provenanceRunner);
  }

  run(process.execPath, recorderArgs, { cwd: repoRoot });
  console.log(`macOS platform runtime evidence recorded: ${manifestPath}`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
