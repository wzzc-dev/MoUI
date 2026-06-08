const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

const repoRoot = __dirname;
const lock = JSON.parse(
  fs.readFileSync(path.join(repoRoot, "pdfium-provider-lock.json"), "utf8"),
);

function readJsonFromStdin() {
  try {
    const input = fs.readFileSync(0, "utf8").trim();
    return input ? JSON.parse(input) : {};
  } catch {
    return {};
  }
}

function targetKind(config) {
  return (
    config?.build?.target?.kind ||
    config?.build_info?.target?.kind ||
    config?.target?.kind ||
    config?.target?.backend ||
    config?.env?.MOON_TARGET ||
    null
  );
}

function configEnvValue(config, key) {
  return (
    process.env[key] ||
    config?.env?.[key] ||
    config?.build?.env?.[key] ||
    config?.build_info?.env?.[key] ||
    null
  );
}

function truthy(value) {
  return /^(1|true|yes|on)$/i.test(String(value || "").trim());
}

function shouldConfigurePdfium(config) {
  const kind = targetKind(config);
  if (kind && ["wasm", "wasm32", "wasmgc", "wasm-gc", "js"].includes(kind)) {
    return false;
  }
  return !truthy(configEnvValue(config, "MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM"));
}

function pdfiumLinkMode(config) {
  const mode = (configEnvValue(config, "MOUI_PDFIUM_LINK_MODE") || "auto")
    .trim()
    .toLowerCase();
  if (!["auto", "dynamic", "static"].includes(mode)) {
    throw new Error(`unsupported MOUI_PDFIUM_LINK_MODE: ${mode}`);
  }
  return mode;
}

function platformAssetKey() {
  const arch = os.arch();
  if (process.platform === "darwin") {
    if (arch === "arm64") {
      return "mac-arm64";
    }
    if (arch === "x64") {
      return "mac-x64";
    }
  } else if (process.platform === "linux") {
    if (arch === "arm64") {
      return "linux-arm64";
    }
    if (arch === "x64") {
      return "linux-x64";
    }
  } else if (process.platform === "win32") {
    if (arch === "arm64") {
      return "win-arm64";
    }
    if (arch === "x64") {
      return "win-x64";
    }
  }
  throw new Error(`unsupported PDFium platform ${process.platform}/${arch}`);
}

function run(command, args, description) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  if (result.error) {
    throw new Error(`failed to ${description}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`${command} exited with ${result.status} while trying to ${description}`);
  }
  return result.stdout.trim();
}

function sha256(filePath) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}

function fetchFile(url, outputPath) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (process.platform === "win32") {
    const script = [
      "$ProgressPreference = 'SilentlyContinue'",
      `Invoke-WebRequest -Uri ${JSON.stringify(url)} -OutFile ${JSON.stringify(outputPath)}`,
    ].join("; ");
    const result = spawnSync(
      "powershell.exe",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
      { cwd: repoRoot, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
    );
    if (!result.error && result.status === 0) {
      return;
    }
  }
  run(
    "curl",
    [
      "-LfsS",
      "--connect-timeout",
      "20",
      "--retry",
      "2",
      "--retry-delay",
      "2",
      "-o",
      outputPath,
      url,
    ],
    "download PDFium archive",
  );
}

function ensureArchive(asset, archivePath) {
  if (fs.existsSync(archivePath) && sha256(archivePath) === asset.sha256) {
    return;
  }
  if (fs.existsSync(archivePath)) {
    fs.rmSync(archivePath);
  }
  const tmpPath = `${archivePath}.tmp`;
  if (fs.existsSync(tmpPath)) {
    fs.rmSync(tmpPath);
  }
  fetchFile(asset.url, tmpPath);
  const actual = sha256(tmpPath);
  if (actual !== asset.sha256) {
    fs.rmSync(tmpPath, { force: true });
    throw new Error(
      `PDFium archive checksum mismatch for ${asset.name}: expected ${asset.sha256}, got ${actual}`,
    );
  }
  fs.renameSync(tmpPath, archivePath);
}

function extractArchive(archivePath, extractDir) {
  const includePath = path.join(extractDir, "include");
  if (fs.existsSync(path.join(includePath, "fpdfview.h"))) {
    return;
  }
  fs.rmSync(extractDir, { recursive: true, force: true });
  fs.mkdirSync(extractDir, { recursive: true });
  run("tar", ["-xzf", archivePath, "-C", extractDir], "extract PDFium archive");
}

function bundledValues(config) {
  const includeOverride = configEnvValue(config, "MOUI_PDFIUM_INCLUDE");
  const libDirOverride = configEnvValue(config, "MOUI_PDFIUM_LIB_DIR");
  if (includeOverride && libDirOverride) {
    return {
      includePath: includeOverride,
      libDir: libDirOverride,
      binDir: libDirOverride,
    };
  }

  const key = platformAssetKey();
  const asset = lock.assets[key];
  if (!asset) {
    throw new Error(`PDFium lock has no asset for ${key}`);
  }
  const cacheRoot = path.join(repoRoot, ".pdfium-cache", lock.release.tag.replace(/\//g, "-"), key);
  const archivePath = path.join(cacheRoot, asset.name);
  const extractDir = path.join(cacheRoot, "pdfium");
  ensureArchive(asset, archivePath);
  extractArchive(archivePath, extractDir);
  return {
    includePath: path.join(extractDir, "include"),
    libDir: path.join(extractDir, "lib"),
    binDir: path.join(extractDir, "bin"),
  };
}

function existing(candidates) {
  return candidates.find(candidate => fs.existsSync(candidate));
}

function shellPath(value) {
  return value.replace(/\\/g, "/");
}

function macosNormalizePdfiumInstallName(dynamicLib) {
  const targetId = "@rpath/libpdfium.dylib";
  let currentId = "";
  try {
    const output = run("otool", ["-D", dynamicLib], "inspect PDFium dylib install name");
    currentId = output
      .split(/\r?\n/)
      .map(line => line.trim())
      .filter(line => line && !line.endsWith(":"))[0] || "";
  } catch {
    currentId = "";
  }
  if (currentId === targetId) {
    return;
  }
  run(
    "install_name_tool",
    ["-id", targetId, dynamicLib],
    "rewrite PDFium dylib install name",
  );
}

function platformFlags(config, values) {
  const includePath = values.includePath;
  const libDir = values.libDir;
  const binDir = values.binDir || libDir;
  const mode = pdfiumLinkMode(config);
  if (!fs.existsSync(path.join(includePath, "fpdfview.h"))) {
    throw new Error(`PDFium header not found under ${includePath}`);
  }

  if (process.platform === "win32") {
    const dynamicImport = existing([
      path.join(libDir, "pdfium.dll.lib"),
      path.join(libDir, "pdfium.lib"),
    ]);
    const dynamicDll = existing([
      path.join(binDir, "pdfium.dll"),
      path.join(libDir, "pdfium.dll"),
    ]);
    const staticLib = path.join(libDir, "pdfium.lib");
    let resolved = mode;
    if (resolved === "auto") {
      resolved = dynamicDll && dynamicImport ? "dynamic" : "static";
    }
    if (resolved === "dynamic") {
      if (!dynamicDll || !dynamicImport) {
        throw new Error("MOUI_PDFIUM_LINK_MODE=dynamic requested, but pdfium.dll/pdfium.dll.lib were not found");
      }
      return {
        stubCcFlags: `/DMOUI_PDFIUM_HAS_PDFIUM /I${shellPath(includePath)}`,
        linkFlags: `${shellPath(dynamicImport)} user32.lib advapi32.lib`,
      };
    }
    if (!fs.existsSync(staticLib)) {
      throw new Error(`MOUI_PDFIUM_LINK_MODE=static requested, but ${staticLib} was not found`);
    }
    return {
      stubCcFlags: `/DMOUI_PDFIUM_HAS_PDFIUM /I${shellPath(includePath)}`,
      linkFlags: `${shellPath(staticLib)} user32.lib advapi32.lib`,
    };
  }

  if (process.platform === "darwin") {
    const dynamicLib = existing([
      path.join(libDir, "libpdfium.dylib"),
      path.join(binDir, "libpdfium.dylib"),
    ]);
    const staticLib = path.join(libDir, "libpdfium.a");
    let resolved = mode;
    if (resolved === "auto") {
      resolved = dynamicLib ? "dynamic" : "static";
    }
    const stubCcFlags = `-DMOUI_PDFIUM_HAS_PDFIUM -I${shellPath(includePath)}`;
    if (resolved === "dynamic") {
      if (!dynamicLib) {
        throw new Error("MOUI_PDFIUM_LINK_MODE=dynamic requested, but libpdfium.dylib was not found");
      }
      macosNormalizePdfiumInstallName(dynamicLib);
      const dynamicDir = path.dirname(dynamicLib);
      return {
        stubCcFlags,
        linkFlags: `-L${shellPath(dynamicDir)} -lpdfium -Wl,-rpath,${shellPath(dynamicDir)}`,
      };
    }
    if (!fs.existsSync(staticLib)) {
      throw new Error(`MOUI_PDFIUM_LINK_MODE=static requested, but ${staticLib} was not found`);
    }
    return {
      stubCcFlags,
      linkFlags: `${shellPath(staticLib)} -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices`,
    };
  }

  const dynamicLib = existing([
    path.join(libDir, "libpdfium.so"),
    path.join(binDir, "libpdfium.so"),
  ]);
  const staticLib = path.join(libDir, "libpdfium.a");
  let resolved = mode;
  if (resolved === "auto") {
    resolved = dynamicLib ? "dynamic" : "static";
  }
  const stubCcFlags = `-DMOUI_PDFIUM_HAS_PDFIUM -I${shellPath(includePath)}`;
  if (resolved === "dynamic") {
    if (!dynamicLib) {
      throw new Error("MOUI_PDFIUM_LINK_MODE=dynamic requested, but libpdfium.so was not found");
    }
    return {
      stubCcFlags,
      linkFlags: `-L${shellPath(path.dirname(dynamicLib))} -lpdfium -Wl,-rpath,${shellPath(path.dirname(dynamicLib))} -pthread`,
    };
  }
  if (!fs.existsSync(staticLib)) {
    throw new Error(`MOUI_PDFIUM_LINK_MODE=static requested, but ${staticLib} was not found`);
  }
  return {
    stubCcFlags,
    linkFlags: `${shellPath(staticLib)} -ldl -pthread -lstdc++ -lm`,
  };
}

function disabledVars() {
  return {
    MOUI_PDFIUM_STUB_CC_FLAGS: "",
    MOUI_PDFIUM_CC_LINK_FLAGS: "",
  };
}

function main() {
  if (truthy(process.env.MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM)) {
    console.log(JSON.stringify({ vars: disabledVars() }));
    return;
  }
  const config = readJsonFromStdin();
  if (!shouldConfigurePdfium(config)) {
    console.log(JSON.stringify({ vars: disabledVars() }));
    return;
  }
  const flags = platformFlags(config, bundledValues(config));
  console.log(
    JSON.stringify({
      vars: {
        MOUI_PDFIUM_STUB_CC_FLAGS: flags.stubCcFlags,
        MOUI_PDFIUM_CC_LINK_FLAGS: flags.linkFlags,
      },
    }),
  );
}

main();
