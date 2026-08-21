import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const staticToolsRoot = resolve(repoRoot, "tools");

export const readPinnedToolchain = (toolchainFile = ".moonbit-toolchain") => {
  const path = resolve(repoRoot, toolchainFile);
  const data = JSON.parse(readFileSync(path, "utf8"));
  return {
    moonc: data.moonc ?? null,
    mooncWorker: data["moonc-worker"] ?? null,
    mooncWorkerIntegrity: data["moonc-worker-integrity"] ?? null,
  };
};

export const resolveToolPathArgs = (args, pathFlags, defaults = {}, passthroughFlags = []) => {
  const resolvedArgs = [...args];
  const seen = new Set();
  for (let index = 0; index < resolvedArgs.length; index += 1) {
    const flag = resolvedArgs[index];
    if (passthroughFlags.includes(flag)) {
      seen.add(flag);
      index += 1;
      continue;
    }
    if (!pathFlags.includes(flag)) continue;
    seen.add(flag);
    const value = resolvedArgs[index + 1];
    if (value && !isAbsolute(value)) {
      resolvedArgs[index + 1] = resolve(repoRoot, value);
    }
    index += 1;
  }
  for (const [flag, value] of Object.entries(defaults)) {
    if (!seen.has(flag)) {
      resolvedArgs.push(flag, resolve(repoRoot, value));
    }
  }
  return resolvedArgs;
};

export const runCommand = (command, args, options = {}) => {
  const captureOutput =
    options.encoding ||
    options.failureStdoutToStderr ||
    options.suppressSuccessStdout ||
    options.exitOnFailure === false;
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    env: options.env ?? process.env,
    encoding: captureOutput ? (options.encoding ?? "utf8") : undefined,
    stdio: captureOutput ? undefined : "inherit",
  });
  const failed = result.status !== 0 || result.error;
  const redirectStdout =
    options.failureStdoutToStderr && failed && result.stdout;
  if (result.stdout && !redirectStdout && !(options.suppressSuccessStdout && !failed)) {
    process.stdout.write(result.stdout);
  }
  if (redirectStdout) {
    process.stderr.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  if (result.error) {
    console.error(result.error.message);
    if (options.exitOnFailure !== false) {
      process.exit(1);
    }
    return { ...result, status: 1 };
  }
  if (result.status !== 0 && options.exitOnFailure !== false) {
    process.exit(result.status ?? 1);
  }
  return result;
};

export const runMoonbitTool = (toolPackage, toolArgs = [], options = {}) => {
  const isStaticTool = toolPackage.startsWith("tools/");
  const packagePath = isStaticTool ? toolPackage.slice("tools/".length) : toolPackage;
  const workspaceArgs = isStaticTool ? [ "-C", staticToolsRoot ] : [];
  return runCommand(
    "moon",
    [ ...workspaceArgs, "run", packagePath, "--target", "native", "--", ...toolArgs ],
    {
      ...options,
      env: {
        ...process.env,
        MOUI_SKIA_DISABLE_PREBUILD_SKIA:
          process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
        ...(options.env ?? {}),
      },
    },
  );
};
