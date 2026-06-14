#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-smoke-gate-"));
const script = "scripts/smoke-gate.mjs";

const run = (args, options = {}) => {
  const result = spawnSync("node", [script, ...args], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  if (options.expectFailure) {
    if (result.status === 0) {
      throw new Error(`expected failure for ${args.join(" ")}\n${result.stdout}`);
    }
  } else if (result.status !== 0) {
    throw new Error(
      `command failed: node ${script} ${args.join(" ")}\n${result.stdout}\n${result.stderr}`,
    );
  }
  return result;
};

const fixtureCatalog = () => ({
  schemaVersion: 1,
  description: "smoke gate runner fixture",
  tiers: ["daily", "nightly", "release"],
  suites: [
    {
      id: "daily.echo",
      tier: "daily",
      kind: "fixture",
      host: "any",
      purpose: "exercise a runnable daily fixture",
      defaultDevCheck: true,
      commands: [{ argv: ["node", "-e", "console.log('daily ok')"], mode: "run" }],
      result: { type: "exit-code" },
      ci: { workflow: ".github/workflows/ci.yml", gate: "pull_request" },
      docs: ["docs/testing.md"],
      artifacts: [],
    },
    {
      id: "nightly.echo",
      tier: "nightly",
      kind: "fixture",
      host: "any",
      purpose: "exercise tier dry-run filtering",
      defaultDevCheck: false,
      commands: [{ argv: ["node", "-e", "console.log('nightly ok')"], mode: "run" }],
      result: { type: "exit-code" },
      ci: { workflow: ".github/workflows/ci.yml", gate: "nightly" },
      docs: ["docs/testing.md"],
      artifacts: [],
    },
    {
      id: "release.manual-platform",
      tier: "release",
      kind: "fixture",
      host: "matching-host",
      purpose: "exercise manual gating and platform placeholder substitution",
      defaultDevCheck: false,
      commands: [
        {
          argv: [
            "node",
            "-e",
            "if (process.argv[1] !== 'linux') process.exit(3); console.log('platform ' + process.argv[1])",
            "<macos|web|windows|linux>",
          ],
          mode: "manual",
        },
      ],
      result: { type: "exit-code" },
      ci: { workflow: ".github/workflows/ci.yml", gate: "release-manual" },
      docs: ["docs/release-readiness.md"],
      artifacts: ["artifacts/window-package-smoke/<platform>.log"],
    },
  ],
});

const fixture = () => {
  const path = join(tmp, "gates.json");
  writeFileSync(path, JSON.stringify(fixtureCatalog(), null, 2));
  return path;
};

const manifest = fixture();

const nightly = run(["--manifest", manifest, "--tier", "nightly", "--dry-run", "--json"]);
const nightlyPlan = JSON.parse(nightly.stdout);
if (nightlyPlan.suiteCount !== 1 || nightlyPlan.suites[0].id !== "nightly.echo") {
  throw new Error("nightly dry-run plan did not select only nightly.echo");
}

const daily = run(["--manifest", manifest, "--suite", "daily.echo", "--run"]);
if (!daily.stdout.includes("daily ok")) {
  throw new Error("daily runner did not execute the fixture command");
}

run(["--manifest", manifest, "--suite", "release.manual-platform", "--run"], {
  expectFailure: true,
});

const manual = run([
  "--manifest",
  manifest,
  "--suite",
  "release.manual-platform",
  "--platform",
  "linux",
  "--allow-manual",
  "--run",
]);
if (!manual.stdout.includes("platform linux")) {
  throw new Error("manual runner did not substitute the platform placeholder");
}

run(["--manifest", manifest, "--suite", "missing.suite", "--dry-run"], {
  expectFailure: true,
});

console.log("smoke gate runner tests: ok");
