#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fixtureRoot = join(repoRoot, "checks/external-consumer");
const mouiVersion = "0.1.7";
const packagedModules = [
  { directory: "moui", packageName: "moui", version: mouiVersion },
  { directory: "moui_shell", packageName: "moui_shell", version: mouiVersion },
  { directory: "moui_skia", packageName: "moui_skia", version: mouiVersion },
  { directory: "moui_sun", packageName: "moui_sun", version: mouiVersion },
  { directory: "third_party/mizchi_image", packageName: "image", version: "0.4.2" },
];

const usage = [
  "Usage: node scripts/external-consumer-ci.mjs --source registry|package",
  "",
  "Validates an app copied outside the MoUI checkout. Package mode stages the",
  "current package closure in an isolated MoonBit workspace.",
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

const findResolvedPackage = (consumerRoot, packageName) => {
  const candidates = [
    join(consumerRoot, ".mooncakes/wzzc-dev", packageName),
    join(consumerRoot, ".mooncakes/wzzc-dev", packageName, mouiVersion),
  ];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return realpathSync(candidate);
  }
  throw new Error(
    "external consumer did not materialize .mooncakes/wzzc-dev/" + packageName,
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
const stagedPackagesRoot = join(temporaryRoot, "packages");
const packageSha256s = [];

try {
  cpSync(fixtureRoot, consumerRoot, { recursive: true });

  if (options.source === "registry") {
    run("moon", ["update"], { cwd: consumerRoot });
  } else {
    // Packaging must resolve the monorepo package graph before each ZIP is
    // produced. CI starts with no cached MoonBit registry, unlike a developer
    // checkout that has already run a workspace build.
    run("moon", ["update"], { cwd: repoRoot });
    const workspaceMembers = ["./consumer"];
    for (const packagedModule of packagedModules) {
      run("moon", ["-C", packagedModule.directory, "package"], { cwd: repoRoot });
      const packageZip = join(
        repoRoot,
        "_build/publish/" +
          (packagedModule.directory === "third_party/mizchi_image"
            ? "mizchi-"
            : "wzzc-dev-") +
          packagedModule.packageName + "-" + packagedModule.version + ".zip",
      );
      if (!existsSync(packageZip)) {
        throw new Error("moon package output is missing: " + packageZip);
      }
      const archiveSha256 = createHash("sha256")
        .update(readFileSync(packageZip))
        .digest("hex");
      extractPackage(
        packageZip,
        join(stagedPackagesRoot, packagedModule.packageName),
      );
      packageSha256s.push(packagedModule.packageName + "=" + archiveSha256);
      workspaceMembers.push("./packages/" + packagedModule.packageName);
    }
    writeFileSync(
      join(temporaryRoot, "moon.work"),
      "members = [\n" +
        workspaceMembers.map(member => "  \"" + member + "\",").join("\n") +
        "\n]\n",
    );
    run("moon", ["update"], { cwd: consumerRoot });
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

  const resolvedMoui = options.source === "package"
    ? realpathSync(join(stagedPackagesRoot, "moui"))
    : findResolvedPackage(consumerRoot, "moui");
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
  if (options.source === "package") {
    for (const packagedModule of packagedModules) {
      const stagedPackage = realpathSync(
        join(stagedPackagesRoot, packagedModule.packageName),
      );
      if (isInside(repoRoot, stagedPackage)) {
        throw new Error(
          "external consumer staged package from monorepo source: " +
            stagedPackage,
        );
      }
      const stagedManifest = readFileSync(join(stagedPackage, "moon.mod"), "utf8");
      if (!stagedManifest.includes('version = "' + packagedModule.version + '"')) {
        throw new Error(
          "staged " + packagedModule.packageName + " manifest is not version " +
            packagedModule.version,
        );
      }
    }
  }
  console.log(
    "[external-consumer] source=" + options.source +
      " resolved=" + resolvedMoui + " monorepoSource=false" +
      (packageSha256s.length ? " packageSha256s=" + packageSha256s.join(",") : ""),
  );
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
