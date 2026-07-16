#!/usr/bin/env node

import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const options = {
  kind: "",
  output: "",
  platform: "",
  app: "showcase",
  repoRoot: process.cwd(),
};

for (let index = 2; index < process.argv.length; index += 1) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!value || !key.startsWith("--")) throw new Error(`missing value after ${key}`);
  index += 1;
  switch (key) {
    case "--kind": options.kind = value; break;
    case "--output": options.output = value; break;
    case "--platform": options.platform = value; break;
    case "--app": options.app = value; break;
    case "--repo-root": options.repoRoot = value; break;
    default: throw new Error(`unknown option: ${key}`);
  }
}

if (!options.kind || !options.output) throw new Error("--kind and --output are required");
const repoRoot = resolve(options.repoRoot);
const output = resolve(options.output);
const sourceConfig = JSON.parse(readFileSync(
  resolve(repoRoot, `examples/${options.app}/mobile.json`),
  "utf8",
));

const writeJson = (path, value) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
};

if (options.kind === "plugin-config") {
  sourceConfig.mobile.plugins = ["moui/mobile/test-probe/moui.plugin.json"];
  writeJson(output, sourceConfig);
} else if (options.kind === "eject-project") {
  if (!["android", "ios", "harmonyos"].includes(options.platform)) {
    throw new Error("--platform must be android, ios, or harmonyos for eject-project");
  }
  rmSync(output, { recursive: true, force: true });
  mkdirSync(output, { recursive: true });
  sourceConfig.mobile.plugins = [];
  for (const platform of ["android", "ios", "harmonyos"]) {
    if (platform !== options.platform) delete sourceConfig[platform];
  }
  writeJson(resolve(output, "mobile.json"), sourceConfig);
  writeJson(resolve(output, "moui.project.json"), {
    schemaVersion: 1,
    id: "showcase",
    title: "MoUI Showcase",
    module: "examples/showcase",
    mouiVersion: "0.1.7",
    platforms: [options.platform],
    bundleId: "dev.wzzc.moui.showcase",
  });
} else {
  throw new Error(`unknown fixture kind: ${options.kind}`);
}
