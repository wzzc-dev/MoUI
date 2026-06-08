#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), "..");

const platforms = {
  darwin: {
    label: "macOS",
    pkg: "examples/pdf_workbench/macos_skia",
    exitEnv: "MOUI_PDF_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    marker: "macOS renderer presented first frame; exiting by request",
  },
  win32: {
    label: "Windows",
    pkg: "examples/pdf_workbench/windows_skia",
    exitEnv: "MOUI_PDF_WORKBENCH_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    marker: "Windows renderer presented first frame; exiting by request",
  },
  linux: {
    label: "Linux",
    pkg: "examples/pdf_workbench/linux_skia",
    exitEnv: "MOUI_PDF_WORKBENCH_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    marker: "Linux renderer presented first frame; exiting by request",
  },
};

function usage() {
  console.log(`Usage: node scripts/pdf-workbench-native-smoke.mjs [options]

Runs the PDF Workbench native Skia real-raster smoke for the current host. The
smoke validates the native PDFium adapter, then launches the matching native
Skia entrypoint with a startup PDF and the first-frame exit flag.

Options:
  --pdf PATH       PDF to open on startup.
                   Default: examples/pdf_workbench/fixtures/minimum.pdf
  --log PATH       Write combined smoke output to PATH.
                   Default: OS temp dir/moui-pdf-workbench-native-smoke.log
  --timeout SEC    Seconds to wait for the first-frame app run. Default: 30.
  --link-mode MODE PDFium link mode: auto, dynamic, or static. Default: auto.
  --platform NAME  Override platform: macos, windows, linux.
                   Default: current host.
  -h, --help       Show this help.`);
}

function parseArgs(argv) {
  const options = {
    pdf: "examples/pdf_workbench/fixtures/minimum.pdf",
    log: path.join(os.tmpdir(), "moui-pdf-workbench-native-smoke.log"),
    timeout: 30,
    linkMode: process.env.MOUI_PDFIUM_LINK_MODE || "auto",
    platform: process.platform,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--pdf":
        options.pdf = argv[++index] || "";
        break;
      case "--log":
        options.log = argv[++index] || "";
        break;
      case "--timeout":
        options.timeout = Number(argv[++index] || "0");
        break;
      case "--link-mode":
        options.linkMode = argv[++index] || "";
        break;
      case "--platform": {
        const value = (argv[++index] || "").toLowerCase();
        options.platform =
          value === "macos" ? "darwin" : value === "windows" ? "win32" : value;
        break;
      }
      case "-h":
      case "--help":
        usage();
        process.exit(0);
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }
  return options;
}

function resolveFromRepo(value) {
  return path.isAbsolute(value) ? value : path.join(repoRoot, value);
}

function appendLog(logPath, text) {
  fs.appendFileSync(logPath, text);
  process.stdout.write(text);
}

function runLogged(logPath, command, args, env) {
  appendLog(logPath, `+ ${[command, ...args].join(" ")}\n`);
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env,
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  appendLog(logPath, output);
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`${command} exited with ${result.status}`);
  }
  return output;
}

function runLoggedWithTimeout(logPath, command, args, env, timeoutSeconds) {
  appendLog(logPath, `+ ${[command, ...args].join(" ")}\n`);
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env,
    encoding: "utf8",
    timeout: timeoutSeconds * 1000,
    killSignal: "SIGTERM",
  });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  appendLog(logPath, output);
  if (result.error) {
    if (result.error.code === "ETIMEDOUT") {
      throw new Error(`${command} timed out after ${timeoutSeconds}s`);
    }
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`${command} exited with ${result.status}`);
  }
  return output;
}

function validateOptions(options) {
  if (!platforms[options.platform]) {
    throw new Error(`Unsupported platform: ${options.platform}`);
  }
  if (!["auto", "dynamic", "static"].includes(options.linkMode)) {
    throw new Error("--link-mode must be auto, dynamic, or static");
  }
  if (!Number.isInteger(options.timeout) || options.timeout < 1) {
    throw new Error("--timeout must be a positive integer number of seconds");
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  validateOptions(options);
  const platform = platforms[options.platform];
  const pdfPath = resolveFromRepo(options.pdf);
  const logPath = resolveFromRepo(options.log);
  if (!fs.existsSync(pdfPath)) {
    throw new Error(`Startup PDF does not exist: ${pdfPath}`);
  }
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  fs.writeFileSync(logPath, "");
  const env = {
    ...process.env,
    MOUI_PDFIUM_LINK_MODE: options.linkMode,
    MOUI_PDF_WORKBENCH_STARTUP_PDF: pdfPath,
    [platform.exitEnv]: "1",
  };

  appendLog(
    logPath,
    [
      `MoUI PDF Workbench ${platform.label} native real-raster smoke`,
      `  repo_root=${repoRoot}`,
      `  pdf=${pdfPath}`,
      `  log=${logPath}`,
      `  timeout=${options.timeout}`,
      `  pdfium_link_mode=${options.linkMode}`,
      `  package=${platform.pkg}`,
      "",
    ].join("\n"),
  );

  runLogged(logPath, "moon", ["test", "examples/pdf_workbench/pdfium_adapter", "--target", "native"], env);
  runLoggedWithTimeout(
    logPath,
    "moon",
    ["run", platform.pkg, "--target", "native"],
    env,
    options.timeout,
  );

  const log = fs.readFileSync(logPath, "utf8");
  if (!log.includes("pdf workbench: rendered page 1 as")) {
    throw new Error("PDF Workbench smoke did not log a PDFium page render");
  }
  if (!log.includes("bitmap:")) {
    throw new Error("PDF Workbench smoke did not log a bitmap output path");
  }
  if (!log.includes(platform.marker)) {
    throw new Error(`PDF Workbench smoke did not print first-frame marker: ${platform.marker}`);
  }
  appendLog(logPath, `MoUI PDF Workbench ${platform.label} native real-raster smoke passed\n`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
