#!/usr/bin/env node

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-web-renderer-proof-"));
const recorder = "scripts/record-web-renderer-proof-manifest.mjs";

const proofKeys = [
  "radialGradient",
  "transformPixels",
  "colorEmojiPixels",
  "zwjGrapheme",
  "bidiLayout",
  "paragraphWrapping",
  "asyncImageSecondFrame",
];

const writeWebManifest = (name, overrides = {}) => {
  const path = join(tmp, `${name}.json`);
  const observations = Object.fromEntries(proofKeys.map(key => [key, "yes"]));
  writeFileSync(
    path,
    `${JSON.stringify(
      {
        overallStatus: "passed",
        targets: [
          {
            name: "showcase-web-wasm",
            status: "passed",
            observations,
            ...overrides,
          },
        ],
      },
      null,
      2,
    )}\n`,
  );
  return path;
};

const runRecorder = (name, webManifest, extraArgs = []) => {
  const output = join(tmp, "artifacts", "conformance", "renderer-proof", `${name}.json`);
  return {
    output,
    result: spawnSync(
      process.execPath,
      [
        recorder,
        "--web-presentation-manifest",
        webManifest,
        "--output",
        output,
        ...extraArgs,
      ],
      {
        encoding: "utf8",
        env: {
          ...process.env,
          GITHUB_ACTIONS: "true",
          GITHUB_REPOSITORY: "wzzc-dev/moui",
          GITHUB_RUN_ID: "77",
          GITHUB_SERVER_URL: "https://github.com",
          GITHUB_WORKFLOW: "MoUI CI",
          GITHUB_JOB: "web-runtime-presentation",
          RUNNER_NAME: "ubuntu-24.04",
        },
      },
    ),
  };
};

const passed = runRecorder("passed", writeWebManifest("passed"), ["--require-passed"]);
if (passed.result.status !== 0) {
  console.error("expected passed web renderer proof");
  console.error(passed.result.stdout);
  console.error(passed.result.stderr);
  process.exit(1);
}
const passedManifest = JSON.parse(readFileSync(passed.output, "utf8"));
if (passedManifest.status !== "passed") {
  console.error("expected passed renderer proof manifest");
  process.exit(1);
}

const missingZwjManifest = writeWebManifest("missing-zwj", {
  observations: {
    ...Object.fromEntries(proofKeys.map(key => [key, "yes"])),
    zwjGrapheme: "no",
  },
});
const missingZwj = runRecorder("missing-zwj", missingZwjManifest);
if (missingZwj.result.status !== 0) {
  console.error("expected incomplete web renderer proof to validate structurally");
  console.error(missingZwj.result.stdout);
  console.error(missingZwj.result.stderr);
  process.exit(1);
}
const missingManifest = JSON.parse(readFileSync(missingZwj.output, "utf8"));
if (
  missingManifest.status !== "failed" ||
  missingManifest.observations.zwjGrapheme.status !== "failed"
) {
  console.error("missing ZWJ observation should keep web renderer proof failed");
  process.exit(1);
}

const missingRequired = runRecorder("missing-required", missingZwjManifest, ["--require-passed"]);
if (
  missingRequired.result.status === 0 ||
  !missingRequired.result.stderr.includes("status must be passed")
) {
  console.error("expected --require-passed to reject missing ZWJ web proof");
  console.error(missingRequired.result.stdout);
  console.error(missingRequired.result.stderr);
  process.exit(1);
}

console.log("web renderer proof recorder tests: ok");
