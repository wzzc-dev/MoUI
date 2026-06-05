#!/usr/bin/env node

import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-renderer-proof-manifest-"));
const validator = "scripts/validate-renderer-proof-manifest.mjs";

const observationEvidence = {
  radialGradient: ["center-mid-edge-pixels", "shader-payload"],
  transformPixels: ["pixel-markers"],
  colorEmojiPixels: ["high-saturation-pixels", "glyph-or-raster"],
  zwjGrapheme: ["single-grapheme-cluster", "no-interior-caret"],
  bidiLayout: ["visual-order"],
  paragraphWrapping: ["line-metrics", "later-line-pixels"],
  asyncImageSecondFrame: ["late-completion", "repaint-request", "second-frame-pixels"],
};

const observations = (status = "passed") =>
  Object.fromEntries(
    Object.entries(observationEvidence).map(([key, evidence]) => [
      key,
      {
        status,
        evidence,
        artifacts: [`artifacts/conformance/renderer-proof/${key}.log`],
      },
    ]),
  );

const manifest = overrides => ({
  schemaVersion: 1,
  mode: "renderer-proof",
  backend: "webgpu-wasm",
  platform: "web",
  status: "passed",
  provenance: {
    kind: "github-actions",
    workflow: "MoUI CI",
    job: "web-runtime-presentation",
    runId: "123456",
    runUrl: "https://github.com/wzzc-dev/moui/actions/runs/123456",
    runner: "ubuntu-24.04",
    artifactName: "moui-web-runtime-presentation",
  },
  artifacts: ["artifacts/conformance/renderer-proof/webgpu-wasm-web.json"],
  observations: observations(),
  ...overrides,
});

const writeFixture = (name, value) => {
  const path = join(tmp, name);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
  return path;
};

const run = (name, value, args = []) => {
  const path = writeFixture(name, value);
  return spawnSync(process.execPath, [validator, path, ...args], {
    encoding: "utf8",
  });
};

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected pass`);
    console.error(result.stdout);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, message) => {
  if (result.status === 0 || !result.stderr.includes(message)) {
    console.error(`${label}: expected failure containing '${message}'`);
    console.error(result.stdout);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass("valid passed manifest", run("valid.json", manifest(), ["--require-passed"]));

expectFail(
  "missing github provenance",
  run(
    "local-provenance.json",
    manifest({
      provenance: {
        ...manifest().provenance,
        kind: "matching-host-artifact",
      },
    }),
    ["--require-passed"],
  ),
  "passed renderer proof requires github-actions provenance",
);

expectFail(
  "caret-only emoji proof",
  run(
    "caret-only.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: ["caret-only", "high-saturation-pixels", "glyph-or-raster"],
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must not use caret-only or coverage-only proof",
);

expectFail(
  "missing async second-frame proof",
  run(
    "missing-async-token.json",
    manifest({
      observations: {
        ...observations(),
        asyncImageSecondFrame: {
          status: "passed",
          evidence: ["late-completion", "repaint-request"],
          artifacts: ["artifacts/conformance/renderer-proof/async.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'second-frame-pixels'",
);

expectFail(
  "unexpected observation key",
  run(
    "unexpected-key.json",
    manifest({
      observations: {
        ...observations(),
        caretCoverage: {
          status: "passed",
          evidence: ["coverage-only"],
          artifacts: ["artifacts/conformance/renderer-proof/caret.log"],
        },
      },
    }),
  ),
  "observations must contain exactly",
);

const artifactRoot = join(tmp, "uploaded");
mkdirSync(join(artifactRoot, "artifacts", "conformance", "renderer-proof"), { recursive: true });
for (const key of Object.keys(observationEvidence)) {
  writeFileSync(
    join(artifactRoot, "artifacts", "conformance", "renderer-proof", `${key}.log`),
    "artifact\n",
  );
}
writeFileSync(
  join(artifactRoot, "artifacts", "conformance", "renderer-proof", "webgpu-wasm-web.json"),
  "{}\n",
);
expectPass(
  "valid passed manifest with artifact root",
  run("valid-artifacts.json", manifest(), ["--require-passed", "--artifact-root", artifactRoot]),
);

expectFail(
  "missing uploaded artifact",
  run("missing-artifact.json", manifest(), [
    "--require-passed",
    "--artifact-root",
    join(tmp, "missing-artifacts"),
  ]),
  "artifact root does not exist",
);

console.log("renderer proof manifest validator tests: ok");
