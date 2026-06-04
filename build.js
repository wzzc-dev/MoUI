const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const repoRoot = __dirname;

function readJsonFromStdin() {
  try {
    const input = fs.readFileSync(0, "utf8").trim();
    return input ? JSON.parse(input) : {};
  } catch {
    return {};
  }
}

function readModuleName() {
  const jsonPath = path.join(repoRoot, "moon.mod.json");
  if (fs.existsSync(jsonPath)) {
    return JSON.parse(fs.readFileSync(jsonPath, "utf8")).name;
  }
  const modText = fs.readFileSync(path.join(repoRoot, "moon.mod"), "utf8");
  const match = modText.match(/^\s*name\s*=\s*"([^"]+)"/m);
  if (!match) {
    throw new Error("module name not found in moon.mod");
  }
  return match[1];
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

function shouldConfigureSkia(config) {
  const kind = targetKind(config);
  if (kind && ["wasm", "wasm32", "wasmgc", "wasm-gc", "js"].includes(kind)) {
    return false;
  }
  return skiaPrebuildEnabled(config);
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

function falsy(value) {
  return /^(0|false|no|off)$/i.test(String(value || "").trim());
}

function skiaPrebuildEnabled(config) {
  const disabled = configEnvValue(config, "SKIA_MBT_DISABLE_PREBUILD_SKIA");
  if (truthy(disabled)) {
    return false;
  }
  const enabled = configEnvValue(config, "SKIA_MBT_ENABLE_PREBUILD_SKIA");
  if (enabled !== null && String(enabled).trim() !== "") {
    return !falsy(enabled);
  }
  return true;
}

function parseEnvLines(output) {
  const values = {};
  for (const line of output.split(/\r?\n/)) {
    const index = line.indexOf("=");
    if (index <= 0) {
      continue;
    }
    values[line.slice(0, index)] = line.slice(index + 1);
  }
  return values;
}

function run(command, args, description) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: [ "ignore", "pipe", "inherit" ],
  });
  if (result.error) {
    throw new Error(`failed to ${description}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`failed to ${description}; ${command} exited with ${result.status}`);
  }
  return result.stdout.trim();
}

function runPowerShell(script, args, description) {
  const baseArgs = [ "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, ...args ];
  let result = spawnSync("powershell.exe", baseArgs, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: [ "ignore", "pipe", "inherit" ],
  });
  if (result.error && result.error.code === "ENOENT") {
    result = spawnSync("pwsh", [ "-NoProfile", "-File", script, ...args ], {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: [ "ignore", "pipe", "inherit" ],
    });
  }
  if (result.error) {
    throw new Error(`failed to ${description}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`failed to ${description}; PowerShell exited with ${result.status}`);
  }
  return result.stdout.trim();
}

function fetchSkiaEnv() {
  const common = [
    "--platform",
    "auto",
    "--arch",
    "auto",
    "--config",
    "Release",
    "--cache-dir",
    ".skia-cache/jetbrains",
    "--print-env",
  ];
  if (process.platform === "win32") {
    return parseEnvLines(
      runPowerShell(
        path.join(repoRoot, "scripts", "fetch-jetbrains-skia.ps1"),
        [
          "-Platform",
          "auto",
          "-Arch",
          "auto",
          "-Config",
          "Release",
          "-CacheDir",
          ".skia-cache/jetbrains",
          "-PrintEnv",
        ],
        "fetch JetBrains Skia",
      ),
    );
  }
  return parseEnvLines(
    run(
      "bash",
      [ path.join("scripts", "fetch-jetbrains-skia.sh"), ...common ],
      "fetch JetBrains Skia",
    ),
  );
}

function requireValue(values, key) {
  const value = values[key];
  if (!value) {
    throw new Error(`fetch output is missing ${key}`);
  }
  return value;
}

function appendFlags(base, extra) {
  if (!extra) {
    return base;
  }
  if (!base) {
    return extra;
  }
  return `${base} ${extra}`;
}

function appendMissingFlags(base, flags) {
  const parts = base.split(/\s+/).filter(Boolean);
  for (const flag of flags) {
    if (!parts.includes(flag)) {
      parts.push(flag);
    }
  }
  return parts.join(" ");
}

function macosExampleLinkFlags(base, extraFrameworks) {
  if (process.platform !== "darwin") {
    return base;
  }
  return appendFlags(base, extraFrameworks);
}

function overlayEnvValues(config, values, keys) {
  const merged = { ...values };
  for (const key of keys) {
    const value = configEnvValue(config, key);
    if (value !== null && String(value).trim() !== "") {
      merged[key] = value;
    }
  }
  return merged;
}

function skiaValues(config) {
  const keys = [
    "SKIA_MBT_SKIA_INCLUDE",
    "SKIA_MBT_SKIA_LIB_DIR",
    "SKIA_MBT_SKIA_LIB",
    "SKIA_MBT_EXTRA_CC_FLAGS",
    "SKIA_MBT_EXTRA_LINK_FLAGS",
  ];
  const envValues = overlayEnvValues(config, {}, keys);
  if (envValues.SKIA_MBT_SKIA_INCLUDE && envValues.SKIA_MBT_SKIA_LIB_DIR) {
    return envValues;
  }
  return overlayEnvValues(config, fetchSkiaEnv(), keys);
}

function macosLinkMode(config) {
  const mode = (
    configEnvValue(config, "SKIA_MBT_MACOS_LINK_MODE") || "auto"
  ).trim().toLowerCase();
  if (!["auto", "dynamic", "static"].includes(mode)) {
    throw new Error(`unsupported SKIA_MBT_MACOS_LINK_MODE: ${mode}`);
  }
  return mode;
}

function macosLibraryFlags(config, libPath, skiaLib) {
  const staticLib = path.join(libPath, `lib${skiaLib}.a`);
  const dynamicLib = path.join(libPath, `lib${skiaLib}.dylib`);
  let mode = macosLinkMode(config);
  if (mode === "auto") {
    if (fs.existsSync(dynamicLib)) {
      mode = "dynamic";
    } else if (fs.existsSync(staticLib)) {
      mode = "static";
    } else {
      throw new Error(
        `Skia library lib${skiaLib}.dylib or lib${skiaLib}.a was not found in ${libPath}`,
      );
    }
  }

  if (mode === "dynamic") {
    if (!fs.existsSync(dynamicLib)) {
      throw new Error(
        `SKIA_MBT_MACOS_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
      );
    }
    return `${dynamicLib} -Wl,-rpath,${libPath}`;
  }

  if (!fs.existsSync(staticLib)) {
    throw new Error(
      `SKIA_MBT_MACOS_LINK_MODE=static requested, but ${staticLib} was not found`,
    );
  }
  return staticLib;
}

function platformFlags(config, values) {
  const includePath = requireValue(values, "SKIA_MBT_SKIA_INCLUDE");
  const libPath = requireValue(values, "SKIA_MBT_SKIA_LIB_DIR");
  const skiaLib = values.SKIA_MBT_SKIA_LIB || "skia";
  const extraCcFlags = values.SKIA_MBT_EXTRA_CC_FLAGS || "";
  const extraLinkFlags = values.SKIA_MBT_EXTRA_LINK_FLAGS || "";

  let stubCcFlags = `-DSKIA_MBT_HAS_SKIA -I${includePath}`;
  let linkFlags = `-L${libPath} -l${skiaLib}`;

  if (process.platform === "win32") {
    stubCcFlags = `/DSKIA_MBT_HAS_SKIA /std:c++20 /EHsc /I${includePath}`;
    const skiaLibFlag = path.join(libPath, `${skiaLib}.lib`).replace(/\\/g, "/");
    linkFlags = `${skiaLibFlag} user32.lib gdi32.lib ole32.lib opengl32.lib usp10.lib fontsub.lib imm32.lib winmm.lib version.lib dwrite.lib d2d1.lib dxgi.lib advapi32.lib shell32.lib`;
  } else if (process.platform === "darwin") {
    stubCcFlags = `-DSKIA_MBT_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = macosLibraryFlags(config, libPath, skiaLib) +
      " -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices";
  } else if (process.platform === "linux") {
    stubCcFlags = `-DSKIA_MBT_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = appendMissingFlags(linkFlags, [
      "-lstdc++",
      "-lfontconfig",
      "-lfreetype",
      "-lharfbuzz",
    ]);
  }

  return {
    stubCcFlags: appendFlags(stubCcFlags, extraCcFlags),
    linkFlags: appendFlags(linkFlags, extraLinkFlags),
  };
}

function main() {
  const config = readJsonFromStdin();
  if (!shouldConfigureSkia(config)) {
    const triangleLinkFlags = macosExampleLinkFlags(
      "",
      "-framework QuartzCore -framework AppKit",
    );
    const metalWindowLinkFlags = macosExampleLinkFlags(
      "",
      "-framework Metal -framework QuartzCore -framework CoreVideo -framework IOSurface -framework AppKit",
    );
    console.log(
      JSON.stringify({
        vars: {
          SKIA_MBT_STUB_CC_FLAGS: "",
          SKIA_MBT_CC_LINK_FLAGS: "",
          SKIA_MBT_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
          SKIA_MBT_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
        },
      }),
    );
    return;
  }

  const moduleName = readModuleName();
  const nativePackageName = `${moduleName}/native`;
  const values = skiaValues(config);
  const flags = platformFlags(config, values);
  const triangleLinkFlags = macosExampleLinkFlags(
    flags.linkFlags,
    "-framework QuartzCore -framework AppKit",
  );
  const metalWindowLinkFlags = macosExampleLinkFlags(
    flags.linkFlags,
    "-framework Metal -framework QuartzCore -framework CoreVideo -framework IOSurface -framework AppKit",
  );

  console.log(
    JSON.stringify({
      vars: {
        SKIA_MBT_STUB_CC_FLAGS: flags.stubCcFlags,
        SKIA_MBT_CC_LINK_FLAGS: flags.linkFlags,
        SKIA_MBT_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
        SKIA_MBT_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
      },
      link_configs: [
        {
          package: nativePackageName,
          link_flags: flags.linkFlags,
        },
      ],
    }),
  );
}

main();
