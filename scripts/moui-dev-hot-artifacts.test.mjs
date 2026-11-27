#!/usr/bin/env node

// Regression coverage for the pre-Moon stale `dev_hot` diagnosis.
//
// The fixtures use the real generator, so the upgrade path (old tree -> stale
// diagnosis -> generator -> passing diagnosis), idempotent regeneration, and
// the marker written by the current generator are all exercised end to end
// without touching the checkout's own `moui_devhost/dev_hot/`.
//
// Run with:
//   node --test scripts/moui-dev-hot-artifacts.test.mjs

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  DEV_HOT_DEFAULT_OUT,
  DEV_HOT_GENERATOR_FORMAT,
  DEV_HOT_MODULE_NAME,
  diagnoseDevHotArtifacts,
  formatDevHotDiagnosis,
} from "./lib/dev-hot-artifacts.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const generatorPath = join(repoRoot, "scripts", "moui-dev-hot-generate.mjs");
const cliPath = join(repoRoot, "scripts", "moui-dev-hot-check.mjs");
const outRel = DEV_HOT_DEFAULT_OUT;

const moduleMembers = [
  ["moui", "wzzc-dev/moui", "0.9.2"],
  ["moui_devhost", "wzzc-dev/moui_devhost", "0.1.0"],
  ["moui_skia_renderer", "wzzc-dev/moui_skia_renderer", "0.9.2"],
  ["moui_devtools", "wzzc-dev/moui_devtools", "0.9.2"],
  ["examples/counter", "examples/counter", "0.1.0"],
];

const withTempRepo = fn => {
  const root = mkdtempSync(join(tmpdir(), "moui-dev-hot-artifacts-"));
  try {
    const members = moduleMembers.map(([dir]) => `  "./${dir}",`).join("\n");
    writeFileSync(join(root, "moon.work"), `members = [\n${members}\n]\n`);
    for (const [dir, name, version] of moduleMembers) {
      mkdirSync(join(root, dir), { recursive: true });
      writeFileSync(
        join(root, dir, "moon.mod"),
        `name = "${name}"\n\nversion = "${version}"\n`,
      );
    }
    mkdirSync(join(root, "examples/counter/app"), { recursive: true });
    writeFileSync(
      join(root, "examples/counter/app/moon.pkg"),
      'import {\n  "wzzc-dev/moui/core",\n}\n',
    );
    writeFileSync(
      join(root, "examples/counter/app/main.mbt"),
      "///|\npub fn program() -> Unit {\n  ()\n}\n",
    );
    return fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
};

// The layout the issue reproduces: manifest plus generated packages but no
// standalone module/workspace manifests, and the app imported by the plugin.
const writeOldShape = (root, { manifest } = {}) => {
  const dir = join(root, outRel);
  mkdirSync(join(dir, "host"), { recursive: true });
  mkdirSync(join(dir, "plugin"), { recursive: true });
  if (manifest !== null) {
    writeFileSync(
      join(dir, "manifest.json"),
      `${JSON.stringify(manifest ?? { schemaVersion: 1, platform: "linux" }, null, 2)}\n`,
    );
  }
  writeFileSync(
    join(dir, "host", "moon.pkg"),
    'import {\n  "wzzc-dev/moui/core",\n}\n\npkgtype(kind: "executable")\n',
  );
  writeFileSync(join(dir, "host", "main.mbt"), "///|\nfn main {\n  ()\n}\n");
  writeFileSync(
    join(dir, "plugin", "moon.pkg"),
    'import {\n  "wzzc-dev/moui/runtime",\n  "examples/counter/app",\n}\n\npkgtype(kind: "foreign_library")\n',
  );
  writeFileSync(join(dir, "plugin", "main.mbt"), "///|\npub fn dev_create() -> Int {\n  0\n}\n");
};

const runGenerator = (root, { app = "examples/counter", platform = "macos" } = {}) => {
  const result = spawnSync(
    process.execPath,
    [generatorPath, "--root", root, "--app", app, "--platform", platform],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, `generator failed:\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
};

const runCli = (root, extraArgs = []) =>
  spawnSync(process.execPath, [cliPath, "--root", root, ...extraArgs], {
    encoding: "utf8",
  });

const snapshotTree = dir => {
  const entries = [];
  const walk = (current, prefix) => {
    const names = readdirSync(current, { withFileTypes: true })
      .map(entry => entry)
      .sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of names) {
      const relativePath = prefix === "" ? entry.name : `${prefix}/${entry.name}`;
      const absolutePath = join(current, entry.name);
      if (entry.isDirectory()) walk(absolutePath, relativePath);
      else entries.push(`${relativePath}\n${readFileSync(absolutePath, "utf8")}`);
    }
  };
  walk(dir, "");
  return entries.join("\n---\n");
};

const codes = diagnosis => new Set(diagnosis.issues.map(issue => issue.code));

test("an absent dev_hot tree is not a failure", () => {
  withTempRepo(root => {
    const diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "absent");
    assert.equal(diagnosis.recovery, null);
    assert.match(formatDevHotDiagnosis(diagnosis), /nothing to check/);
    assert.equal(runCli(root).status, 0);
  });
});

test("the old-shaped tree is diagnosed, then passes after the generator runs", () => {
  withTempRepo(root => {
    writeOldShape(root);

    const stale = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(stale.status, "stale");
    const staleCodes = codes(stale);
    assert.ok(staleCodes.has("dev-hot.moon-mod.missing"), "missing module manifest");
    assert.ok(staleCodes.has("dev-hot.moon-work.missing"), "missing workspace manifest");
    assert.ok(staleCodes.has("dev-hot.manifest.generator-format"), "missing format marker");
    // The manifest in this fixture has no app fields; the app is recovered
    // from the generated plugin import so the recovery command is concrete.
    assert.equal(
      stale.recovery.generateCommand,
      "node scripts/moui-dev-hot-generate.mjs --root . --app examples/counter --platform linux",
    );

    const guidance = formatDevHotDiagnosis(stale);
    assert.ok(guidance.includes(`${outRel}/moon.mod`), "names the module manifest path");
    assert.ok(guidance.includes(`${outRel}/moon.work`), "names the workspace manifest path");
    assert.ok(guidance.includes(stale.recovery.generateCommand), "prints the recovery command");
    assert.match(guidance, /replaces the entire dev_hot\/ directory/);
    assert.match(guidance, /End any 'moui dev --hot' session/);
    assert.match(guidance, /rm -rf moui_devhost\/dev_hot/);

    const cliStale = runCli(root);
    assert.equal(cliStale.status, 1);
    assert.ok(cliStale.stdout.includes(stale.recovery.generateCommand));

    runGenerator(root, { platform: "linux" });
    const healed = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(healed.status, "ok");
    assert.deepEqual(healed.issues, []);
    assert.equal(runCli(root).status, 0);

    const manifest = JSON.parse(readFileSync(join(root, outRel, "manifest.json"), "utf8"));
    assert.equal(manifest.schemaVersion, 1);
    assert.equal(manifest.generatorFormat, DEV_HOT_GENERATOR_FORMAT);
    assert.equal(manifest.module, DEV_HOT_MODULE_NAME);
    const generatedModule = readFileSync(join(root, outRel, "moon.mod"), "utf8");
    assert.ok(generatedModule.includes(`name = "${DEV_HOT_MODULE_NAME}"`));
    assert.ok(generatedModule.includes('"examples/counter@0.1.0"'));
  });
});

test("repeated generation is idempotent and keeps rewriting the marker", () => {
  withTempRepo(root => {
    runGenerator(root);
    const first = snapshotTree(join(root, outRel));
    runGenerator(root);
    const second = snapshotTree(join(root, outRel));
    assert.equal(second, first);

    const manifest = JSON.parse(readFileSync(join(root, outRel, "manifest.json"), "utf8"));
    assert.equal(manifest.generatorFormat, DEV_HOT_GENERATOR_FORMAT);
  });
});

test("a complete tree without the format marker is stale", () => {
  withTempRepo(root => {
    runGenerator(root);
    const manifestPath = join(root, outRel, "manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    delete manifest.generatorFormat;
    writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

    const diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "stale");
    assert.ok(codes(diagnosis).has("dev-hot.manifest.generator-format"));
    const guidance = formatDevHotDiagnosis(diagnosis);
    assert.match(guidance, /older generator \(format 1\)/);
    assert.ok(guidance.includes("--app examples/counter"));
    assert.ok(guidance.includes("--platform macos"), "reuses the recorded platform");
  });
});

test("incomplete generated files are reported with their paths", () => {
  withTempRepo(root => {
    runGenerator(root);
    rmSync(join(root, outRel, "host", "main.mbt"));
    writeFileSync(join(root, outRel, "plugin", "main.mbt"), "");

    const diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "stale");
    const paths = diagnosis.issues.filter(issue => issue.code === "dev-hot.file.missing").map(issue => issue.path);
    assert.ok(paths.includes(`${outRel}/host/main.mbt`), "missing host program named");
    assert.ok(paths.includes(`${outRel}/plugin/main.mbt`), "empty plugin bridge named");
    assert.match(formatDevHotDiagnosis(diagnosis), /host\/main\.mbt: generated host program/);
  });
});

test("a module named after the parent, or missing the app dependency, is stale", () => {
  withTempRepo(root => {
    runGenerator(root);
    const modulePath = join(root, outRel, "moon.mod");

    writeFileSync(
      modulePath,
      'name = "wzzc-dev/moui_devhost"\n\nversion = "0.0.0"\n',
    );
    let diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "stale");
    assert.ok(codes(diagnosis).has("dev-hot.moon-mod.name"));
    assert.ok(codes(diagnosis).has("dev-hot.moon-mod.app-dependency"));

    writeFileSync(
      modulePath,
      `name = "${DEV_HOT_MODULE_NAME}"\n\nversion = "0.0.0"\n\nimport {\n  "wzzc-dev/moui@0.9.2",\n}\n`,
    );
    diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "stale");
    assert.deepEqual(
      [...codes(diagnosis)].filter(code => code.startsWith("dev-hot.moon-mod.")),
      ["dev-hot.moon-mod.app-dependency"],
    );
  });
});

test("a missing workspace manifest or app member is stale", () => {
  withTempRepo(root => {
    runGenerator(root);
    const workPath = join(root, outRel, "moon.work");
    const original = readFileSync(workPath, "utf8");

    rmSync(workPath);
    let diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.ok(codes(diagnosis).has("dev-hot.moon-work.missing"));

    writeFileSync(workPath, original.replace(/"\.\.\/\.\.\/examples\/counter",?\s*/g, ""));
    diagnosis = diagnoseDevHotArtifacts({ repoRoot: root });
    assert.equal(diagnosis.status, "stale");
    assert.ok(codes(diagnosis).has("dev-hot.moon-work.app-member"));
  });
});

test("the CLI reports the same diagnosis as JSON", () => {
  withTempRepo(root => {
    writeOldShape(root);
    const result = runCli(root, ["--json"]);
    assert.equal(result.status, 1);
    const diagnosis = JSON.parse(result.stdout);
    assert.equal(diagnosis.status, "stale");
    assert.equal(diagnosis.out, outRel);
    assert.ok(diagnosis.issues.some(issue => issue.code === "dev-hot.moon-mod.missing"));
  });
});

test("the check facade and dev runner call the detector before Moon", () => {
  const check = readFileSync(join(repoRoot, "scripts", "check.mjs"), "utf8");
  const dev = readFileSync(join(repoRoot, "scripts", "moui-dev.mjs"), "utf8");
  assert.ok(check.includes("diagnoseDevHotArtifacts({ repoRoot })"));
  assert.ok(check.indexOf("diagnoseDevHotArtifacts({ repoRoot })") < check.indexOf("spawnSync(step.argv"));
  assert.ok(dev.includes("diagnoseDevHotArtifacts({ repoRoot: workspaceRoot })"));
});

test("the devhost module keeps app dependencies out of its own manifest", () => {
  const text = readFileSync(join(repoRoot, "moui_devhost", "moon.mod"), "utf8");
  assert.doesNotMatch(text, /examples\//);
});
