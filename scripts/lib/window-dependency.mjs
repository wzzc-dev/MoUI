import { resolve } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import { runMoonbitTool } from "./moonbit-tool-runner.mjs";

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const print = (flag, root = repoRoot) => {
  const result = runMoonbitTool(
    "tools/moui/window_dependency_info",
    ["--repo-root", root, flag],
    { encoding: "utf8", suppressSuccessStdout: true, exitOnFailure: false },
  );
  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || "window dependency lookup failed").trim());
  }
  return (result.stdout || "").trim();
};

export const windowDependencyVersion = (root = repoRoot) => print("--print-version", root);
export const windowDependencyPackage = (root = repoRoot) => print("--print-package", root);
export const windowDependencyCacheZip = (root = repoRoot) => {
  // Keep path construction local for home dir stability; version from MoonBit.
  const version = windowDependencyVersion(root);
  return resolve(homedir(), ".moon/registry/cache/wzzc-dev/window", `${version}.zip`);
};

// retained for any callers that want all versions (now single-pin through MoonBit).
export const windowDependencyVersions = (root = repoRoot) => [windowDependencyVersion(root)];
