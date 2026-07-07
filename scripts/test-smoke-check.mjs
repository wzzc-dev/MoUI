#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-smoke-check-"));
const script = "scripts/smoke-check.mjs";

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

const validCatalog = () => ({
  schemaVersion: 1,
  description: "test catalog",
  tiers: ["daily", "nightly", "release"],
  suites: [
    {
      id: "daily.check",
      tier: "daily",
      kind: "package-baseline",
      host: "any",
      purpose: "test daily",
      defaultDevCheck: true,
      commands: [{ argv: ["sh", "scripts/check.sh", "--profile", "daily"], mode: "run" }],
      result: { type: "exit-code" },
      ci: { workflow: ".github/workflows/ci.yml", gate: "pull_request" },
      docs: ["docs/testing.md"],
      artifacts: [],
    },
    {
      id: "web.runtime-presentation",
      tier: "nightly",
      kind: "browser-runtime-smoke",
      host: "macos-14",
      purpose: "test nightly",
      defaultDevCheck: false,
      commands: [{ argv: ["sh", "scripts/ci-web-runtime-presentation.sh"], mode: "run" }],
      result: {
        type: "manifest",
        path: "artifacts/smoke/web-runtime-presentation/presentation-smoke.json",
        validator: [
          "node",
          "scripts/validate-web-runtime-presentation-manifest.mjs",
          "artifacts/smoke/web-runtime-presentation/presentation-smoke.json",
        ],
      },
      ci: { workflow: ".github/workflows/ci.yml", gate: "nightly" },
      docs: ["docs/testing.md"],
      artifacts: ["artifacts/smoke/web-runtime-presentation/presentation-smoke.json"],
    },
    {
      id: "macos.skia-real",
      tier: "release",
      kind: "native-real-renderer-smoke",
      host: "macos-14",
      purpose: "test release",
      defaultDevCheck: false,
      commands: [{ argv: ["sh", "scripts/macos-skia-renderer-smoke.sh"], mode: "manual" }],
      result: { type: "log-marker", markers: ["MoUI Skia renderer smoke passed"] },
      ci: { workflow: ".github/workflows/moui-macos-app-real-skia-manual.yml", gate: "release-manual" },
      docs: ["docs/release-readiness.md"],
      artifacts: ["artifacts/platform-observation/macos/skia-renderer-smoke.log"],
    },
  ],
});

const fixture = (name, patch) => {
  const catalog = validCatalog();
  patch?.(catalog);
  const path = join(tmp, `${name}.json`);
  writeFileSync(path, JSON.stringify(catalog, null, 2));
  return path;
};

run(["--check"]);
const nightly = run(["--tier", "nightly", "--json"]);
const nightlyPlan = JSON.parse(nightly.stdout);
if (nightlyPlan.suiteCount < 1 || nightlyPlan.suites.some(suite => suite.tier !== "nightly")) {
  throw new Error("nightly JSON plan did not filter to nightly suites");
}
run(["--list"]);
run(["--manifest", fixture("valid"), "--check"]);
run(["--manifest", fixture("bad-schema", catalog => { catalog.schemaVersion = 2; }), "--check"], {
  expectFailure: true,
});
run([
  "--manifest",
  fixture("bad-default", catalog => { catalog.suites[1].defaultDevCheck = true; }),
  "--check",
], { expectFailure: true });
run([
  "--manifest",
  fixture("bad-workflow", catalog => { catalog.suites[2].ci.workflow = ".github/workflows/missing.yml"; }),
  "--check",
], { expectFailure: true });
run([
  "--manifest",
  fixture("bad-artifact", catalog => { catalog.suites[2].artifacts = ["tmp/log.txt"]; }),
  "--check",
], { expectFailure: true });

console.log("smoke gate catalog validator tests: ok");
