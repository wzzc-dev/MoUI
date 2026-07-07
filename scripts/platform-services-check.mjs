#!/usr/bin/env node

import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import {
  repoRoot,
  windowDependencyCacheZip,
  windowDependencyPackage,
} from "./lib/window-dependency.mjs";

const run = argv => {
  console.log(`\n==> ${argv.join(" ")}`);
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
};

const unzipContains = (zip, path) => {
  const result = spawnSync("unzip", ["-l", zip, path], {
    cwd: repoRoot,
    stdio: "ignore",
  });
  return result.status === 0;
};

run(["moon", "test", "moui/backend/host", "--target", "native"]);
run(["moon", "test", "moui/backend/web", "--target", "wasm-gc"]);

const windowZip = process.env.MOUI_WINDOW_PACKAGE_ZIP || windowDependencyCacheZip();
if (
  process.platform !== "linux" &&
  existsSync(windowZip) &&
  unzipContains(windowZip, "linux/generated/xdg-decoration-protocol.c") &&
  unzipContains(windowZip, "linux/generated/xdg-shell-protocol.c")
) {
  run(["moon", "test", "moui/backend/linux", "--target", "native"]);
} else if (process.platform === "linux") {
  console.log(
    "\nSkipping backend/linux platform-service sanity check on Linux; the platform profile owns Linux backend/provider tests on Linux hosts.",
  );
} else {
  console.log(
    `\nSkipping backend/linux platform-service tests because ${windowDependencyPackage()} package Wayland generated sources are missing from the local registry cache.`,
  );
}

console.log("\nShared platform service checks passed.");
