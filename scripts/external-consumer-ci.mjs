#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fixtureRoot = join(repoRoot, "checks/external-consumer");
const mouiVersion = "0.1.7";

const usage = [
  "Usage: node scripts/external-consumer-ci.mjs --source registry|package",
  "",
  "Validates an app copied outside the MoUI checkout. Package mode stages the",
  "current moon package over the resolved external .mooncakes dependency.",
].join("\n");

const parseArgs = argv => {
  let source = "";
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    if (arg === "--source") {
      source = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--help" || arg === "-h") {
      console.log(usage);
      process.exit(0);
    } else {
      throw new Error("unknown argument: " + arg);
    }
  }
  if (source !== "registry" && source !== "package") {
    throw new Error("--source must be registry or package");
  }
  return { source };
};

const run = (command, args, { cwd, capture = false } = {}) => {
  const result = spawnSync(command, args, {
    cwd,
    env: { ...process.env, MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1" },
    encoding: "utf8",
    stdio: capture ? "pipe" : "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const detail = capture ? "\n" + result.stdout + result.stderr : "";
    throw new Error(
      command + " " + args.join(" ") + " failed with exit code " +
        result.status + detail,
    );
  }
  return result.stdout || "";
};

const isInside = (root, candidate) => {
  const path = relative(root, candidate);
  return path === "" ||
    (path !== ".." && !path.startsWith(".." + sep) && !isAbsolute(path));
};

const findResolvedMoui = consumerRoot => {
  const candidates = [
    join(consumerRoot, ".mooncakes/wzzc-dev/moui"),
    join(consumerRoot, ".mooncakes/wzzc-dev/moui", mouiVersion),
  ];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return realpathSync(candidate);
  }
  throw new Error(
    "external consumer did not materialize .mooncakes/wzzc-dev/moui",
  );
};

const extractPackage = (packageZip, destination) => {
  rmSync(destination, { recursive: true, force: true });
  mkdirSync(destination, { recursive: true });
  if (process.platform === "win32") {
    run(
      "powershell",
      [
        "-NoProfile",
        "-Command",
        "Expand-Archive -LiteralPath '" +
          packageZip.replaceAll("'", "''") +
          "' -DestinationPath '" +
          destination.replaceAll("'", "''") +
          "' -Force",
      ],
      { cwd: repoRoot },
    );
  } else {
    run("unzip", ["-q", packageZip, "-d", destination], { cwd: repoRoot });
  }
};

const options = parseArgs(process.argv.slice(2));
const temporaryRoot = mkdtempSync(join(tmpdir(), "moui-external-consumer-"));
const consumerRoot = join(temporaryRoot, "consumer");
let packageSha256 = "";

try {
  cpSync(fixtureRoot, consumerRoot, { recursive: true });
  run("moon", ["update"], { cwd: consumerRoot });

  if (options.source === "package") {
    run("moon", ["-C", "moui", "package"], { cwd: repoRoot });
    const packageZip = join(
      repoRoot,
      "_build/publish/wzzc-dev-moui-" + mouiVersion + ".zip",
    );
    if (!existsSync(packageZip)) {
      throw new Error("moon package output is missing: " + packageZip);
    }
    packageSha256 = createHash("sha256")
      .update(readFileSync(packageZip))
      .digest("hex");
    extractPackage(
      packageZip,
      join(consumerRoot, ".mooncakes/wzzc-dev/moui"),
    );
    rmSync(join(consumerRoot, "_build"), { recursive: true, force: true });
  }

  const tree = run("moon", ["tree"], { cwd: consumerRoot, capture: true });
  process.stdout.write(tree);
  if (!tree.includes("wzzc-dev/moui@" + mouiVersion)) {
    throw new Error(
      "moon tree does not contain wzzc-dev/moui@" + mouiVersion,
    );
  }
  if (tree.includes(repoRoot)) {
    throw new Error("moon tree resolved monorepo source from " + repoRoot);
  }

  run("moon", ["check", "--target", "native"], { cwd: consumerRoot });
  run("moon", ["check", "--target", "wasm-gc"], { cwd: consumerRoot });
  run("moon", ["test", "app", "--target", "native"], { cwd: consumerRoot });

  const resolvedMoui = findResolvedMoui(consumerRoot);
  if (isInside(repoRoot, resolvedMoui)) {
    throw new Error(
      "external consumer resolved MoUI from monorepo source: " + resolvedMoui,
    );
  }
  const resolvedManifest = readFileSync(
    join(resolvedMoui, "moon.mod"),
    "utf8",
  );
  if (!resolvedManifest.includes('version = "' + mouiVersion + '"')) {
    throw new Error(
      "resolved MoUI manifest is not version " + mouiVersion,
    );
  }
  console.log(
    "[external-consumer] source=" + options.source +
      " resolved=" + resolvedMoui + " monorepoSource=false" +
      (packageSha256 ? " packageSha256=" + packageSha256 : ""),
  );
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
