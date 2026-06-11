#!/usr/bin/env node

import { mkdirSync, renameSync, rmSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_platform_evidence_manifest";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_platform_evidence_manifest/record_platform_evidence_manifest.exe",
);

const usage = () => {
  console.error(`Usage: node scripts/record-platform-evidence-manifest.mjs <manifest.json> <platform> [options]

Platforms:
  web | macos | windows | linux

Options:
  --status <passed|failed|pending>
  --host <description>
  --window-evidence-command <command>
  --consumer-command <command|pending>
  --set <observation=yes|no|pending>   May be repeated.
  --artifact <path>                    May be repeated.
  --note <text>                        May be repeated.
  --provenance-kind <github-actions|matching-host-artifact>
  --provenance-host <description>
  --provenance-workflow <name>         Required for github-actions provenance.
  --provenance-job <name>              Required for github-actions provenance.
  --provenance-run-url <url>           Required for github-actions provenance.
  --provenance-run-id <id>
  --provenance-runner <label>          Required for github-actions provenance.
  --provenance-artifact <ref>          May be repeated.
  --provenance-note <text>             May be repeated.
  --web-presentation-manifest <path>   Derive the web entry from a validated
                                       web-runtime-presentation manifest.
  --skia-status <passed|failed|pending>
  --skia-set <observation=yes|no|pending>
                                       Native Skia observations; may be repeated.
  --skia-boundary <text>               Override the Skia evidence boundary note.
  --skia-provider-command <command>    Override/add Skia provider command; may repeat.
  --skia-runtime-smoke-command <command>
                                       Override/add Skia runtime smoke command;
                                       may repeat.
  --skia-artifact <path>               Native Skia artifact; may be repeated.
  --skia-note <text>                   Native Skia note; may be repeated.
  --skia-provenance-kind <github-actions|matching-host-artifact>
  --skia-provenance-host <description>
  --skia-provenance-workflow <name>    Required for github-actions provenance.
  --skia-provenance-job <name>         Required for github-actions provenance.
  --skia-provenance-run-url <url>      Required for github-actions provenance.
  --skia-provenance-run-id <id>
  --skia-provenance-runner <label>     Required for github-actions provenance.
  --skia-provenance-artifact <ref>     May be repeated.
  --skia-provenance-note <text>        May be repeated.

The script keeps this compatibility path, delegates manifest update planning to
tools/moui/record_platform_evidence_manifest, and then validates the updated
platform entry with validate-platform-evidence-manifest.mjs.`);
};

const args = process.argv.slice(2);
if (args.length < 2 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 2 ? 2 : 0);
}

const run = (command, commandArgs, options = {}) => {
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd ?? repoRoot,
    encoding: "utf8",
    env: options.env ?? process.env,
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
    const error = new Error(result.error.message);
    error.exitCode = 1;
    throw error;
  }
  if (result.status !== 0) {
    const error = new Error(`command failed: ${command}`);
    error.exitCode = result.status ?? 1;
    throw error;
  }
};

let webPresentationManifest = "";
for (let index = 2; index < args.length; index += 1) {
  if (args[index] === "--web-presentation-manifest") {
    webPresentationManifest = args[index + 1] ?? "";
    index += 1;
  }
}

const manifestPath = resolve(invocationRoot, args[0]);
const platform = args[1];
mkdirSync(dirname(manifestPath), { recursive: true });
const pendingManifestPath = join(
  dirname(manifestPath),
  `.${basename(manifestPath)}.${process.pid}.tmp`,
);

try {
  run("moon", ["build", toolPackage, "--target", "native"]);
  if (webPresentationManifest) {
    run(
      process.execPath,
      [
        join(repoRoot, "scripts/validate-web-runtime-presentation-manifest.mjs"),
        webPresentationManifest,
      ],
      { cwd: invocationRoot },
    );
  }
  run(
    toolExe,
    [
      manifestPath,
      platform,
      "--repo-root",
      repoRoot,
      "--output",
      pendingManifestPath,
      ...args.slice(2),
    ],
    { cwd: invocationRoot, failureStdoutToStderr: true },
  );
  run(
    process.execPath,
    [
      join(repoRoot, "scripts/validate-platform-evidence-manifest.mjs"),
      pendingManifestPath,
      "--platform",
      platform,
    ],
    { cwd: repoRoot },
  );
  renameSync(pendingManifestPath, manifestPath);
  console.log(`${args[0]}: updated ${platform} evidence entry`);
} catch (error) {
  rmSync(pendingManifestPath, { force: true });
  if (typeof error?.exitCode === "number") {
    process.exit(error.exitCode);
  }
  throw error;
}
