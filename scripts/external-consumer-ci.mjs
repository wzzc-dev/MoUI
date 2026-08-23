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
const registryBaseVersion = "0.1.7";

// The head version must track the published module version. Read it from the
// canonical module manifest instead of hardcoding it so version bumps cannot
// leave this script behind.
const headVersion = readFileSync(join(repoRoot, "moui/moon.mod"), "utf8")
  .match(/^version\s*=\s*"([^"]+)"/m)?.[1];
if (!headVersion) {
  throw new Error("unable to resolve wzzc-dev/moui version from moui/moon.mod");
}

const usage = [
  "Usage: node scripts/external-consumer-ci.mjs --source registry|package --profile base|skia|web",
  "",
  "Validates an app copied outside the MoUI checkout. Package mode stages the",
  "current package closure in an isolated MoonBit workspace.",
].join("\n");

const parseArgs = argv => {
  let source = "";
  let profile = "base";
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    if (arg === "--source") {
      source = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--profile") {
      profile = argv[index + 1] || "";
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
  if (!["base", "skia", "web"].includes(profile)) {
    throw new Error("--profile must be base, skia, or web");
  }
  if (source === "registry" && profile !== "base") {
    throw new Error("registry mode currently supports only the stable base profile");
  }
  return { source, profile };
};

const profilePackageNames = profile => {
  if (profile === "skia") return ["moui", "moui_skia", "moui_skia_renderer"];
  if (profile === "web") return ["moui", "moui_web_renderer"];
  return ["moui"];
};

const packageSpecs = (profile, source) => {
  const version = source === "registry" ? registryBaseVersion : headVersion;
  return profilePackageNames(profile).map(packageName => ({
    directory: packageName,
    packageName,
    version,
  }));
};

const profilePackageImport = (profile, version) => {
  if (profile === "skia") {
    return [
      `  "wzzc-dev/moui@${version}",`,
      `  "wzzc-dev/moui_skia_renderer@${version}",`,
    ];
  }
  if (profile === "web") {
    return [
      `  "wzzc-dev/moui@${version}",`,
      `  "wzzc-dev/moui_web_renderer@${version}",`,
    ];
  }
  return [`  "wzzc-dev/moui@${version}",`];
};

const writeConsumerManifest = (consumerRoot, profile, version) => {
  writeFileSync(
    join(consumerRoot, "moon.mod"),
    [
      'name = "moui-external/consumer"',
      "",
      'version = "0.0.1"',
      "",
      "import {",
      ...profilePackageImport(profile, version),
      "}",
      "",
    ].join("\n"),
  );
};

const assertPackageTreeClosure = (tree, profile) => {
  const forbiddenByProfile = {
    base: [
      "wzzc-dev/moui_skia_renderer", "wzzc-dev/moui_sun_renderer",
      "wzzc-dev/moui_web_renderer", "wzzc-dev/moui_wgpu_renderer",
      "wzzc-dev/moui_skia", "wzzc-dev/moui_sun",
      "Milky2018/wgpu_mbt", "Milky2018/moon_cosmic", "Milky2018/moon_swash",
      "mizchi/image", "moonbitlang/quickcheck", "mizchi/pixelmatch",
    ],
    skia: [
      "wzzc-dev/moui_web_renderer", "wzzc-dev/moui_wgpu_renderer",
      "wzzc-dev/moui_sun_renderer", "wzzc-dev/moui_sun", "Milky2018/wgpu_mbt",
      "Milky2018/moon_cosmic", "Milky2018/moon_swash", "mizchi/image",
    ],
    web: [
      "wzzc-dev/moui_skia_renderer", "wzzc-dev/moui_wgpu_renderer",
      "wzzc-dev/moui_sun_renderer", "wzzc-dev/moui_skia", "wzzc-dev/moui_sun",
      "Milky2018/wgpu_mbt", "Milky2018/moon_cosmic", "Milky2018/moon_swash",
      "mizchi/image",
    ],
  };
  const required = profile === "base"
    ? []
    : ["wzzc-dev/moui_" + profile + "_renderer@" + headVersion];
  for (const token of required) {
    if (!tree.includes(token)) {
      throw new Error(profile + " package tree is missing " + token);
    }
  }
  for (const token of forbiddenByProfile[profile]) {
    if (tree.includes(token)) {
      throw new Error(profile + " package tree contains forbidden token: " + token);
    }
  }
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

const findResolvedPackage = (consumerRoot, packageName, version) => {
  const candidates = [
    join(consumerRoot, ".mooncakes/wzzc-dev", packageName),
    join(consumerRoot, ".mooncakes/wzzc-dev", packageName, version),
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
// Keep package-mode consumers tied to the checked-in compatibility contract.
if (options.source === "package") {
  const metadata = spawnSync("node", ["scripts/validate-ecosystem-metadata.mjs"], {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (metadata.status !== 0) process.exit(metadata.status ?? 1);
}
const temporaryRoot = mkdtempSync(join(tmpdir(), "moui-external-consumer-"));
const consumerRoot = join(temporaryRoot, "consumer");
const stagedPackagesRoot = join(temporaryRoot, "packages");
const packageSha256s = [];
const expectedVersion = options.source === "registry"
  ? registryBaseVersion
  : headVersion;
const packagedModules = packageSpecs(options.profile, options.source);

try {
  mkdirSync(consumerRoot, { recursive: true });
  const profileFixture = options.profile === "base"
    ? fixtureRoot
    : join(fixtureRoot, "profiles", options.profile);
  cpSync(join(profileFixture, "app"), join(consumerRoot, "app"), {
    recursive: true,
  });
  writeConsumerManifest(consumerRoot, options.profile, expectedVersion);

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
        "_build/publish/wzzc-dev-" +
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
  if (!tree.includes("wzzc-dev/moui@" + expectedVersion)) {
    throw new Error(
      "moon tree does not contain wzzc-dev/moui@" + expectedVersion,
    );
  }
  if (tree.includes(repoRoot)) {
    throw new Error("moon tree resolved monorepo source from " + repoRoot);
  }
  if (options.source === "package") {
    assertPackageTreeClosure(tree, options.profile);
  }

  if (options.profile === "web") {
    run("moon", ["check", "app", "--target", "wasm-gc"], { cwd: consumerRoot });
  } else {
    run("moon", ["check", "app", "--target", "native"], { cwd: consumerRoot });
  }
  if (options.profile === "base") {
    run("moon", ["check", "app", "--target", "wasm-gc"], { cwd: consumerRoot });
    run("moon", ["test", "app", "--target", "native"], { cwd: consumerRoot });
  }

  if (options.source === "package") {
    const forbiddenBaseArchivePrefixes = [
      "render/skia", "render/sun", "render/wgpu", "render/webgpu_adapter",
      "render/canvas2d", "tests",
    ];
    const archiveList = run(
      "moon",
      ["-C", "moui", "package", "--list"],
      { cwd: repoRoot, capture: true },
    );
    const archivePaths = archiveList.split(/\r?\n/).map(line => line.trim());
    for (const prefix of forbiddenBaseArchivePrefixes) {
      if (archivePaths.some(path => path === prefix || path.startsWith(prefix + "/"))) {
        throw new Error("base archive contains forbidden path: " + prefix);
      }
    }
  }

  const resolvedMoui = options.source === "package"
    ? realpathSync(join(stagedPackagesRoot, "moui"))
    : findResolvedPackage(consumerRoot, "moui", expectedVersion);
  if (isInside(repoRoot, resolvedMoui)) {
    throw new Error(
      "external consumer resolved MoUI from monorepo source: " + resolvedMoui,
    );
  }
  const resolvedManifest = readFileSync(
    join(resolvedMoui, "moon.mod"),
    "utf8",
  );
  if (!resolvedManifest.includes('version = "' + expectedVersion + '"')) {
    throw new Error(
      "resolved MoUI manifest is not version " + expectedVersion,
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
      " profile=" + options.profile +
      " resolved=" + resolvedMoui + " monorepoSource=false" +
      (packageSha256s.length ? " packageSha256s=" + packageSha256s.join(",") : ""),
  );
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
