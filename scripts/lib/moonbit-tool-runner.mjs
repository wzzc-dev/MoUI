import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

export const runCommand = (command, args, options = {}) => {
  const captureOutput =
    options.encoding ||
    options.failureStdoutToStderr ||
    options.suppressSuccessStdout ||
    options.exitOnFailure === false;
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
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

export const runMoonbitTool = (toolPackage, toolArgs = [], options = {}) =>
  runCommand(
    "moon",
    [ "run", toolPackage, "--target", "native", "--", ...toolArgs ],
    options,
  );
