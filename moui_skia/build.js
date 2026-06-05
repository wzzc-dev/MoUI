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
  const disabled = configEnvValue(config, "MOUI_SKIA_DISABLE_PREBUILD_SKIA");
  if (truthy(disabled)) {
    return false;
  }
  const enabled = configEnvValue(config, "MOUI_SKIA_ENABLE_PREBUILD_SKIA");
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

function fetchSkiaEnv(config) {
  const common = [
    "--platform",
    "auto",
    "--arch",
    "auto",
    "--config",
    "Release",
    "--link-mode",
    skiaLinkMode(config),
    "--cache-dir",
    ".skia-cache/release",
    "--print-env",
  ];
  if (process.platform === "win32") {
    return parseEnvLines(
      runPowerShell(
        path.join(repoRoot, "scripts", "fetch-release-skia.ps1"),
        [
          "-Platform",
          "auto",
          "-Arch",
          "auto",
          "-Config",
          "Release",
          "-LinkMode",
          skiaLinkMode(config),
          "-CacheDir",
          ".skia-cache/release",
          "-PrintEnv",
        ],
        "fetch Skia release",
      ),
    );
  }
  return parseEnvLines(
    run(
      "bash",
      [ path.join("scripts", "fetch-release-skia.sh"), ...common ],
      "fetch Skia release",
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
    "MOUI_SKIA_SKIA_INCLUDE",
    "MOUI_SKIA_SKIA_LIB_DIR",
    "MOUI_SKIA_SKIA_LIB",
    "MOUI_SKIA_EXTRA_CC_FLAGS",
    "MOUI_SKIA_EXTRA_LINK_FLAGS",
    "MOUI_SKIA_SKIA_LINK_MODE",
    "MOUI_SKIA_MACOS_LINK_MODE",
  ];
  const envValues = overlayEnvValues(config, {}, keys);
  if (envValues.MOUI_SKIA_SKIA_INCLUDE && envValues.MOUI_SKIA_SKIA_LIB_DIR) {
    return envValues;
  }
  return overlayEnvValues(config, fetchSkiaEnv(config), keys);
}

function skiaLinkMode(config) {
  const mode = (
    configEnvValue(config, "MOUI_SKIA_SKIA_LINK_MODE") ||
    configEnvValue(config, "MOUI_SKIA_MACOS_LINK_MODE") ||
    "static"
  ).trim().toLowerCase();
  if (!["auto", "dynamic", "static"].includes(mode)) {
    throw new Error(`unsupported MOUI_SKIA_SKIA_LINK_MODE: ${mode}`);
  }
  return mode;
}

function macosLibraryFlags(config, libPath, skiaLib) {
  const staticLib = path.join(libPath, `lib${skiaLib}.a`);
  const dynamicLib = path.join(libPath, `lib${skiaLib}.dylib`);
  let mode = skiaLinkMode(config);
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
        `MOUI_SKIA_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
      );
    }
    return `${dynamicLib} -Wl,-rpath,${libPath}`;
  }

  if (!fs.existsSync(staticLib)) {
    throw new Error(
      `MOUI_SKIA_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
    );
  }
  return staticLib;
}

function platformFlags(config, values) {
  const includePath = requireValue(values, "MOUI_SKIA_SKIA_INCLUDE");
  const libPath = requireValue(values, "MOUI_SKIA_SKIA_LIB_DIR");
  const skiaLib = values.MOUI_SKIA_SKIA_LIB || "skia";
  const extraCcFlags = values.MOUI_SKIA_EXTRA_CC_FLAGS || "";
  const extraLinkFlags = values.MOUI_SKIA_EXTRA_LINK_FLAGS || "";
  const linkMode = (values.MOUI_SKIA_SKIA_LINK_MODE || skiaLinkMode(config)).trim().toLowerCase();

  let stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -I${includePath}`;
  let linkFlags = `-L${libPath} -l${skiaLib}`;

  if (process.platform === "win32") {
    stubCcFlags = `/DMOUI_SKIA_HAS_SKIA /std:c++20 /EHsc /I${includePath}`;
    const staticLib = path.join(libPath, `${skiaLib}.lib`);
    const dynamicImportLib = path.join(libPath, `${skiaLib}.dll.lib`);
    const dynamicDll = path.join(libPath, `${skiaLib}.dll`);
    let resolvedLinkMode = linkMode;
    if (resolvedLinkMode === "auto") {
      resolvedLinkMode = fs.existsSync(dynamicDll) && fs.existsSync(dynamicImportLib)
        ? "dynamic"
        : "static";
    }
    let skiaLibFlag = staticLib;
    if (resolvedLinkMode === "dynamic") {
      if (!fs.existsSync(dynamicDll)) {
        throw new Error(
          `MOUI_SKIA_SKIA_LINK_MODE=dynamic requested, but ${dynamicDll} was not found`,
        );
      }
      if (!fs.existsSync(dynamicImportLib) && !fs.existsSync(staticLib)) {
        throw new Error(
          `MOUI_SKIA_SKIA_LINK_MODE=dynamic requested, but ${dynamicImportLib} or ${staticLib} was not found`,
        );
      }
      skiaLibFlag = fs.existsSync(dynamicImportLib) ? dynamicImportLib : staticLib;
    } else if (!fs.existsSync(staticLib)) {
      throw new Error(
        `MOUI_SKIA_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
      );
    }
    const packageLibs = fs.readdirSync(libPath)
      .filter(name => name.toLowerCase().endsWith(".lib"))
      .map(name => path.join(libPath, name))
      .sort((a, b) => path.basename(a).localeCompare(path.basename(b)));
    const orderedPackageLibs = [
      skiaLibFlag,
      ...packageLibs.filter(candidate => candidate !== skiaLibFlag),
    ].map(candidate => candidate.replace(/\\/g, "/"));
    linkFlags = `${orderedPackageLibs.join(" ")} user32.lib gdi32.lib ole32.lib opengl32.lib usp10.lib fontsub.lib imm32.lib winmm.lib version.lib dwrite.lib d2d1.lib dxgi.lib advapi32.lib shell32.lib`;
  } else if (process.platform === "darwin") {
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = macosLibraryFlags(config, libPath, skiaLib) +
      " -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices";
  } else if (process.platform === "linux") {
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    const staticLib = path.join(libPath, `lib${skiaLib}.a`);
    const dynamicLib = path.join(libPath, `lib${skiaLib}.so`);
    let resolvedLinkMode = linkMode;
    if (resolvedLinkMode === "auto") {
      resolvedLinkMode = fs.existsSync(dynamicLib) ? "dynamic" : "static";
    }
    if (resolvedLinkMode === "static") {
      if (!fs.existsSync(staticLib)) {
        throw new Error(
          `MOUI_SKIA_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
        );
      }
      linkFlags = staticLib;
    } else {
      if (!fs.existsSync(dynamicLib)) {
        throw new Error(
          `MOUI_SKIA_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
        );
      }
      linkFlags = `-L${libPath} -l${skiaLib} -Wl,-rpath,${libPath}`;
    }
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
          MOUI_SKIA_STUB_CC_FLAGS: "",
          MOUI_SKIA_CC_LINK_FLAGS: "",
          MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
          MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
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
        MOUI_SKIA_STUB_CC_FLAGS: flags.stubCcFlags,
        MOUI_SKIA_CC_LINK_FLAGS: flags.linkFlags,
        MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
        MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
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
