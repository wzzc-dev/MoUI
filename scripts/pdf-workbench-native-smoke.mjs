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
  },
  win32: {
    label: "Windows",
    pkg: "examples/pdf_workbench/windows_skia",
  },
  linux: {
    label: "Linux",
    pkg: "examples/pdf_workbench/linux_skia",
  },
};

function usage() {
  console.log(`Usage: node scripts/pdf-workbench-native-smoke.mjs [options]

Runs the PDF Workbench native Skia real-raster smoke for the current host. The
smoke validates the native PDFium adapter, then builds the matching native Skia
entrypoint. It does not launch the ordinary app entrypoint with an auto-exit
flag; app runtime smoke belongs in moui_tester.

Options:
  --pdf PATH       PDF to open on startup.
                   Default: examples/pdf_workbench/fixtures/minimum.pdf
  --log PATH       Write combined smoke output to PATH.
                   Default: OS temp dir/moui-pdf-workbench-native-smoke.log
  --link-mode MODE PDFium link mode: auto, dynamic, or static. Default: auto.
  --platform NAME  Override platform: macos, windows, linux.
                   Default: current host.
  -h, --help       Show this help.`);
}

function parseArgs(argv) {
  const options = {
    pdf: "examples/pdf_workbench/fixtures/minimum.pdf",
    log: path.join(os.tmpdir(), "moui-pdf-workbench-native-smoke.log"),
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

function validateOptions(options) {
  if (!platforms[options.platform]) {
    throw new Error(`Unsupported platform: ${options.platform}`);
  }
  if (!["auto", "dynamic", "static"].includes(options.linkMode)) {
    throw new Error("--link-mode must be auto, dynamic, or static");
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
  };

  appendLog(
    logPath,
    [
      `MoUI PDF Workbench ${platform.label} native real-raster smoke`,
      `  repo_root=${repoRoot}`,
      `  pdf=${pdfPath}`,
      `  log=${logPath}`,
      `  pdfium_link_mode=${options.linkMode}`,
      `  package=${platform.pkg}`,
      "",
    ].join("\n"),
  );

  runLogged(logPath, "moon", ["test", "examples/pdf_workbench/pdfium_adapter", "--target", "native"], env);
  runLogged(logPath, "moon", ["build", platform.pkg, "--target", "native"], env);

  const log = fs.readFileSync(logPath, "utf8");
  if (!log.includes("pdf workbench: rendered page 1 as")) {
    throw new Error("PDF Workbench smoke did not log a PDFium page render");
  }
  if (!log.includes("bitmap:")) {
    throw new Error("PDF Workbench smoke did not log a bitmap output path");
  }
  appendLog(logPath, `MoUI PDF Workbench ${platform.label} native real-raster smoke passed\n`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
