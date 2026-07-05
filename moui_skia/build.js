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

function objectHasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object || {}, key);
}

function configEnvKeyPresent(config, key) {
  return (
    objectHasOwn(process.env, key) ||
    objectHasOwn(config?.env, key) ||
    objectHasOwn(config?.build?.env, key) ||
    objectHasOwn(config?.build_info?.env, key)
  );
}

function rejectLegacyLinkModeEnv(config) {
  for (const key of ["MOUI_SKIA_SKIA_LINK_MODE", "MOUI_SKIA_MACOS_LINK_MODE"]) {
    if (configEnvKeyPresent(config, key)) {
      throw new Error(
        `${key} is no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto.`,
      );
    }
  }
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
    "MOUI_SKIA_LINK_MODE",
    "MOUI_SKIA_PROVIDER",
    "MOUI_SKIA_SKIA_PROVIDER",
    "MOUI_SKIA_RELEASE_TAG",
  ];
  const envValues = overlayEnvValues(config, {}, keys);
  if (envValues.MOUI_SKIA_SKIA_INCLUDE && envValues.MOUI_SKIA_SKIA_LIB_DIR) {
    return envValues;
  }
  return overlayEnvValues(config, fetchSkiaEnv(config), keys);
}

function skiaLinkMode(config) {
  const mode = (configEnvValue(config, "MOUI_SKIA_LINK_MODE") || "static")
    .trim()
    .toLowerCase();
  if (!["auto", "dynamic", "static"].includes(mode)) {
    throw new Error(`unsupported MOUI_SKIA_LINK_MODE: ${mode}`);
  }
  return mode;
}

function skiaMetalGpuEnabled(config) {
  return truthy(configEnvValue(config, "MOUI_SKIA_ENABLE_GPU_METAL"));
}

function skiaParagraphEnabled(config) {
  const value = configEnvValue(config, "MOUI_SKIA_ENABLE_SKPARAGRAPH");
  if (value !== null && String(value).trim() !== "") {
    return !falsy(value);
  }
  return true;
}

function skiaParagraphRequired(config) {
  return truthy(configEnvValue(config, "MOUI_SKIA_REQUIRE_SKPARAGRAPH"));
}

function skiaParagraphHeaderPaths(includePath) {
  return [
    "modules/skparagraph/include/Paragraph.h",
    "modules/skparagraph/include/ParagraphBuilder.h",
    "modules/skparagraph/include/ParagraphStyle.h",
    "modules/skparagraph/include/TextStyle.h",
    "modules/skparagraph/include/FontCollection.h",
  ].map(candidate => path.join(includePath, candidate));
}

function skiaParagraphLibraryCandidates(libPath, name) {
  if (process.platform === "win32") {
    return [
      path.join(libPath, `${name}.lib`),
      path.join(libPath, `${name}.dll.lib`),
    ];
  }
  if (process.platform === "darwin") {
    return [
      path.join(libPath, `lib${name}.a`),
      path.join(libPath, `lib${name}.dylib`),
    ];
  }
  return [
    path.join(libPath, `lib${name}.a`),
    path.join(libPath, `lib${name}.so`),
  ];
}

function skiaParagraphRequiredLibraryNames(platform = process.platform) {
  const names = ["skparagraph", "skshaper", "skunicode_icu", "skunicode_core"];
  if (platform === "darwin") {
    return [...names, "harfbuzz", "icu"];
  }
  return names;
}

function skiaParagraphLinkLibraryNames(platform = process.platform) {
  if (platform === "win32") {
    return skiaParagraphRequiredLibraryNames(platform);
  }
  return [...new Set([...skiaParagraphRequiredLibraryNames(platform), "harfbuzz", "icu"])];
}

function skiaParagraphLibrariesPresent(libPath) {
  const names = ["skparagraph", "skshaper", "skunicode_icu", "skunicode_core"];
  return names.every((name) => {
    if (process.platform === "win32") {
      return (
        fs.existsSync(path.join(libPath, `${name}.lib`)) ||
        fs.existsSync(path.join(libPath, `${name}.dll.lib`))
      );
    }
    return (
      fs.existsSync(path.join(libPath, `lib${name}.a`)) ||
      fs.existsSync(path.join(libPath, `lib${name}.so`)) ||
      fs.existsSync(path.join(libPath, `lib${name}.dylib`))
    );
  });
}

function requireSkiaParagraphArtifacts(config, includePath, libPath) {
  if (!skiaParagraphRequired(config)) {
    return;
  }
  const missingHeaders = skiaParagraphHeaderPaths(includePath)
    .filter(candidate => !fs.existsSync(candidate));
  if (missingHeaders.length > 0) {
    throw new Error(
      `MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but headers were missing: ${missingHeaders.join(", ")}`,
    );
  }
  const missingLibs = skiaParagraphRequiredLibraryNames()
    .filter(name => !skiaParagraphLibraryCandidates(libPath, name).some(fs.existsSync));
  if (missingLibs.length > 0) {
    throw new Error(
      `MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but libraries were missing in ${libPath}: ${missingLibs.join(", ")}`,
    );
  }
}

function unixDynamicLibrarySuffix(platform = process.platform) {
  return platform === "darwin" ? ".dylib" : ".so";
}

function resolveUnixLibraryMode(requestedMode, libPath, skiaLib, dynamicSuffix) {
  const staticLib = path.join(libPath, `lib${skiaLib}.a`);
  const dynamicLib = path.join(libPath, `lib${skiaLib}${dynamicSuffix}`);
  let mode = requestedMode;
  if (mode === "auto") {
    if (fs.existsSync(dynamicLib)) {
      mode = "dynamic";
    } else if (fs.existsSync(staticLib)) {
      mode = "static";
    } else {
      throw new Error(
        `Skia library lib${skiaLib}${dynamicSuffix} or lib${skiaLib}.a was not found in ${libPath}`,
      );
    }
  }
  return mode;
}

function unixLibraryFlag(libPath, name, resolvedLinkMode, dynamicSuffix) {
  const staticLib = path.join(libPath, `lib${name}.a`);
  const dynamicLib = path.join(libPath, `lib${name}${dynamicSuffix}`);
  const candidates = resolvedLinkMode === "dynamic"
    ? [dynamicLib, staticLib]
    : [staticLib, dynamicLib];
  const existing = candidates.find(fs.existsSync);
  return existing || `-l${name}`;
}

function skiaParagraphLinkFlags(libPath, resolvedLinkMode, platform = process.platform) {
  const dynamicSuffix = unixDynamicLibrarySuffix(platform);
  const libraryFlags = skiaParagraphLinkLibraryNames(platform)
    .map(name => unixLibraryFlag(libPath, name, resolvedLinkMode, dynamicSuffix));
  if (platform === "linux" && resolvedLinkMode === "static") {
    return [
      `-L${libPath}`,
      "-Wl,--start-group",
      ...libraryFlags,
      "-Wl,--end-group",
    ].join(" ");
  }
  return [`-L${libPath}`, ...libraryFlags].join(" ");
}

function linuxStaticSkiaParagraphLinkFlags(libPath, skiaLib) {
  const skiaFlag = path.join(libPath, `lib${skiaLib}.a`);
  const paragraphFlags = [
    "skparagraph",
    "skshaper",
    "skunicode_icu",
    "skunicode_core",
    "harfbuzz",
    "icu",
  ]
    .map(name => unixLibraryFlag(libPath, name, "static", ".so"));
  return [
    `-L${libPath}`,
    "-Wl,--start-group",
    skiaFlag,
    ...paragraphFlags,
    "-Wl,--end-group",
  ].join(" ");
}

function linuxReleaseSkParagraphAbiFlags(values) {
  // The locked Linux release SkParagraph archive exports old libstdc++ ABI symbols.
  const provider = (
    values.MOUI_SKIA_SKIA_PROVIDER ||
    values.MOUI_SKIA_PROVIDER ||
    ""
  ).trim().toLowerCase();
  if (provider !== "release" && !values.MOUI_SKIA_RELEASE_TAG) {
    return [];
  }
  return ["-D_GLIBCXX_USE_CXX11_ABI=0"];
}

function macosLibraryFlags(config, libPath, skiaLib, includeGaneshExt = false, requestedMode = skiaLinkMode(config)) {
  const staticLib = path.join(libPath, `lib${skiaLib}.a`);
  const dynamicLib = path.join(libPath, `lib${skiaLib}.dylib`);
  const ganeshExtStaticLib = path.join(libPath, "libskia_ganesh_ext.a");
  const mode = resolveUnixLibraryMode(requestedMode, libPath, skiaLib, ".dylib");

  if (mode === "dynamic") {
    if (!fs.existsSync(dynamicLib)) {
      throw new Error(
        `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
      );
    }
    return `${dynamicLib} -Wl,-rpath,${libPath}`;
  }

  if (!fs.existsSync(staticLib)) {
    throw new Error(
      `MOUI_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
    );
  }
  if (includeGaneshExt) {
    if (!fs.existsSync(ganeshExtStaticLib)) {
      throw new Error(
        `MOUI_SKIA_ENABLE_GPU_METAL requested, but ${ganeshExtStaticLib} was not found`,
      );
    }
    return `${ganeshExtStaticLib} ${staticLib}`;
  }
  return staticLib;
}

function platformFlags(config, values) {
  const includePath = requireValue(values, "MOUI_SKIA_SKIA_INCLUDE");
  const libPath = requireValue(values, "MOUI_SKIA_SKIA_LIB_DIR");
  const skiaLib = values.MOUI_SKIA_SKIA_LIB || "skia";
  let extraCcFlags = values.MOUI_SKIA_EXTRA_CC_FLAGS || "";
  const extraLinkFlags = values.MOUI_SKIA_EXTRA_LINK_FLAGS || "";
  const linkMode = (values.MOUI_SKIA_LINK_MODE || skiaLinkMode(config)).trim().toLowerCase();
  let paragraphEnabled = skiaParagraphEnabled(config) || skiaParagraphRequired(config);
  if (paragraphEnabled && !skiaParagraphLibrariesPresent(libPath)) {
    if (skiaParagraphRequired(config)) {
      throw new Error(
        `MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but one or more SkParagraph libraries were not found in ${libPath}`,
      );
    }
    paragraphEnabled = false;
  }

  requireSkiaParagraphArtifacts(config, includePath, libPath);

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
          `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicDll} was not found`,
        );
      }
      if (!fs.existsSync(dynamicImportLib) && !fs.existsSync(staticLib)) {
        throw new Error(
          `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicImportLib} or ${staticLib} was not found`,
        );
      }
      skiaLibFlag = fs.existsSync(dynamicImportLib) ? dynamicImportLib : staticLib;
    } else if (!fs.existsSync(staticLib)) {
      throw new Error(
        `MOUI_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
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
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(stubCcFlags, "/DMOUI_SKIA_HAS_SKPARAGRAPH /DMOUI_SKIA_HAS_SKSHAPER");
    }
  } else if (process.platform === "darwin") {
    const resolvedLinkMode = resolveUnixLibraryMode(linkMode, libPath, skiaLib, ".dylib");
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = macosLibraryFlags(config, libPath, skiaLib, skiaMetalGpuEnabled(config), linkMode) +
      " -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices";
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(
        stubCcFlags,
        "-DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER",
      );
      linkFlags = appendFlags(
        linkFlags,
        skiaParagraphLinkFlags(libPath, resolvedLinkMode, "darwin"),
      );
    }
    if (skiaMetalGpuEnabled(config)) {
      stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_METAL");
      linkFlags = appendFlags(
        linkFlags,
        "-framework Metal -framework QuartzCore -framework CoreVideo -framework IOSurface -framework AppKit -lobjc",
      );
    }
  } else if (process.platform === "linux") {
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    const staticLib = path.join(libPath, `lib${skiaLib}.a`);
    const dynamicLib = path.join(libPath, `lib${skiaLib}.so`);
    const resolvedLinkMode = resolveUnixLibraryMode(linkMode, libPath, skiaLib, ".so");
    if (resolvedLinkMode === "static") {
      if (!fs.existsSync(staticLib)) {
        throw new Error(
          `MOUI_SKIA_LINK_MODE=static requested, but ${staticLib} was not found`,
        );
      }
      linkFlags = paragraphEnabled
        ? linuxStaticSkiaParagraphLinkFlags(libPath, skiaLib)
        : staticLib;
    } else {
      if (!fs.existsSync(dynamicLib)) {
        throw new Error(
          `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
        );
      }
      linkFlags = `-L${libPath} -l${skiaLib} -Wl,-rpath,${libPath}`;
    }
    linkFlags = appendMissingFlags(linkFlags, [
      "-lfontconfig",
      "-lfreetype",
      "-lharfbuzz",
    ]);
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(
        stubCcFlags,
        "-DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER",
      );
      extraCcFlags = appendMissingFlags(
        extraCcFlags,
        linuxReleaseSkParagraphAbiFlags(values),
      );
      if (resolvedLinkMode !== "static") {
        linkFlags = appendFlags(linkFlags, skiaParagraphLinkFlags(libPath, resolvedLinkMode, "linux"));
      }
    }
    linkFlags = appendMissingFlags(linkFlags, ["-lstdc++"]);
  }

  return {
    stubCcFlags: appendFlags(stubCcFlags, extraCcFlags),
    linkFlags: appendFlags(linkFlags, extraLinkFlags),
  };
}

function main() {
  if (truthy(process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA)) {
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
  const config = readJsonFromStdin();
  rejectLegacyLinkModeEnv(config);
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
