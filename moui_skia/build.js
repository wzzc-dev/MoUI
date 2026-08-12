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

function hostSkiaPlatform() {
  if (process.platform === "darwin") {
    return "macos";
  }
  if (process.platform === "win32") {
    return "windows";
  }
  return process.platform;
}

function skiaReleasePlatform(config) {
  const platform = (
    configEnvValue(config, "MOUI_SKIA_PLATFORM") ||
    configEnvValue(config, "MOUI_SKIA_RELEASE_PLATFORM") ||
    "auto"
  ).trim();
  const allowed = [
    "auto",
    "macos",
    "linux",
    "windows",
    "android",
    "harmonyos",
    "ios",
    "iosSim",
    "tvos",
    "tvosSim",
    "wasm",
  ];
  if (!allowed.includes(platform)) {
    throw new Error(`unsupported MOUI_SKIA_PLATFORM: ${platform}`);
  }
  return platform;
}

function skiaTargetPlatform(config) {
  const platform = skiaReleasePlatform(config);
  return platform === "auto" ? hostSkiaPlatform() : platform;
}

function skiaReleaseArch(config) {
  const arch = (
    configEnvValue(config, "MOUI_SKIA_ARCH") ||
    configEnvValue(config, "MOUI_SKIA_RELEASE_ARCH") ||
    "auto"
  ).trim();
  const allowed = ["auto", "arm64", "x64", "riscv64"];
  if (!allowed.includes(arch)) {
    throw new Error(`unsupported MOUI_SKIA_ARCH: ${arch}`);
  }
  return arch;
}

function skiaReleaseConfig(config) {
  const releaseConfig = (
    configEnvValue(config, "MOUI_SKIA_CONFIG") ||
    configEnvValue(config, "MOUI_SKIA_RELEASE_CONFIG") ||
    "Release"
  ).trim();
  if (!["Release", "Debug"].includes(releaseConfig)) {
    throw new Error(`unsupported MOUI_SKIA_CONFIG: ${releaseConfig}`);
  }
  return releaseConfig;
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
    skiaReleasePlatform(config),
    "--arch",
    skiaReleaseArch(config),
    "--config",
    skiaReleaseConfig(config),
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
          skiaReleasePlatform(config),
          "-Arch",
          skiaReleaseArch(config),
          "-Config",
          skiaReleaseConfig(config),
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

function appendMissingFrameworks(base, frameworks) {
  const parts = base.split(/\s+/).filter(Boolean);
  const result = [];
  const seen = new Set();
  for (let index = 0; index < parts.length; index += 1) {
    if (parts[index] !== "-framework" || index + 1 >= parts.length) {
      result.push(parts[index]);
      continue;
    }
    const framework = parts[index + 1];
    index += 1;
    if (!seen.has(framework)) {
      result.push("-framework", framework);
      seen.add(framework);
    }
  }
  for (const framework of frameworks) {
    if (!seen.has(framework)) {
      result.push("-framework", framework);
      seen.add(framework);
    }
  }
  return result.join(" ");
}

function macosExampleLinkFlags(base, extraFrameworks, platform = hostSkiaPlatform()) {
  if (platform !== "macos") {
    return base;
  }
  return appendMissingFrameworks(base, extraFrameworks);
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
    "MOUI_SKIA_PLATFORM",
    "MOUI_SKIA_RELEASE_PLATFORM",
    "MOUI_SKIA_ARCH",
    "MOUI_SKIA_RELEASE_ARCH",
    "MOUI_SKIA_CONFIG",
    "MOUI_SKIA_RELEASE_CONFIG",
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

function skiaMetalGpuEnabled(config, platform) {
  // Explicit enable/disable wins. Otherwise default Metal on for Apple
  // native targets so auto -> SkiaGpuNative can probe a real Metal path.
  const explicit = configEnvValue(config, "MOUI_SKIA_ENABLE_GPU_METAL");
  if (explicit !== null && String(explicit).trim() !== "") {
    return !falsy(explicit);
  }
  if (truthy(configEnvValue(config, "MOUI_SKIA_DISABLE_GPU_METAL"))) {
    return false;
  }
  const target = platform || process.env.MOUI_SKIA_PLATFORM || "";
  if (["macos", "ios", "iosSim"].includes(String(target))) {
    return true;
  }
  // Host macOS builds without an explicit platform still default Metal on.
  return process.platform === "darwin";
}

function skiaGpuEnabled(config, platform) {
  const names = {
    windows: ["MOUI_SKIA_ENABLE_GPU_D3D12", "MOUI_SKIA_ENABLE_GPU_D3D"],
    linux: ["MOUI_SKIA_ENABLE_GPU_VULKAN"],
    android: ["MOUI_SKIA_ENABLE_GPU_VULKAN", "MOUI_SKIA_ENABLE_GPU_EGL"],
    harmonyos: ["MOUI_SKIA_ENABLE_GPU_EGL"],
  }[platform] || [];
  // Explicit enable wins; explicit disable of any listed flag turns the path off.
  const values = names.map(name => configEnvValue(config, name));
  if (values.some(value => value !== null && String(value).trim() !== "" && truthy(value))) {
    return true;
  }
  if (values.some(value => value !== null && String(value).trim() !== "" && falsy(value))) {
    return false;
  }
  // Product default: native GPU backends are on for the matching target.
  return names.length > 0;
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

function androidStaticSkiaParagraphLinkFlags(libPath, skiaLib) {
  return unixStaticSkiaParagraphLinkFlags(libPath, skiaLib, "android");
}

function unixStaticSkiaParagraphLinkFlags(libPath, skiaLib, platform) {
  const skiaFlag = path.join(libPath, `lib${skiaLib}.a`);
  const paragraphFlags = skiaParagraphLinkLibraryNames(platform)
    .map(name => unixLibraryFlag(
      libPath,
      name,
      "static",
      unixDynamicLibrarySuffix(platform),
    ));
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
  const ganeshExtDynamicLib = path.join(libPath, "libskia_ganesh_ext.dylib");
  const mode = includeGaneshExt && requestedMode === "auto" &&
    fs.existsSync(staticLib) && fs.existsSync(ganeshExtStaticLib)
    ? "static"
    : resolveUnixLibraryMode(requestedMode, libPath, skiaLib, ".dylib");

  if (mode === "dynamic") {
    if (!fs.existsSync(dynamicLib)) {
      throw new Error(
        `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
      );
    }
    if (includeGaneshExt && !fs.existsSync(ganeshExtDynamicLib)) {
      throw new Error(
        `MOUI_SKIA_ENABLE_GPU_METAL with dynamic linking requested, but ${ganeshExtDynamicLib} was not found`,
      );
    }
    const ganeshExtFlag = includeGaneshExt ? `${ganeshExtDynamicLib} ` : "";
    return `${ganeshExtFlag}${dynamicLib} -Wl,-rpath,${libPath}`;
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
  const platform = skiaTargetPlatform(config);
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

  if (platform === "windows") {
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
    if (skiaGpuEnabled(config, platform)) {
      stubCcFlags = appendFlags(
        stubCcFlags,
        "/DMOUI_SKIA_ENABLE_GPU_D3D /DMOUI_SKIA_ENABLE_GPU_D3D12",
      );
      // Ganesh D3D pipelines call D3DCompile from d3dcompiler.
      linkFlags = appendFlags(linkFlags, "d3d12.lib d3dcompiler.lib dxguid.lib");
    }
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(stubCcFlags, "/DMOUI_SKIA_HAS_SKPARAGRAPH /DMOUI_SKIA_HAS_SKSHAPER");
    }
  } else if (platform === "macos") {
    const resolvedLinkMode = resolveUnixLibraryMode(linkMode, libPath, skiaLib, ".dylib");
    const metalGpu = skiaMetalGpuEnabled(config, platform);
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = macosLibraryFlags(config, libPath, skiaLib, metalGpu, linkMode) +
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
    if (metalGpu) {
      stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_METAL");
      linkFlags = appendMissingFrameworks(linkFlags, [
        "Metal",
        "QuartzCore",
        "CoreVideo",
        "IOSurface",
        "AppKit",
      ]);
    }
  } else if (platform === "ios" || platform === "iosSim") {
    const resolvedLinkMode = resolveUnixLibraryMode(linkMode, libPath, skiaLib, ".dylib");
    const metalGpu = skiaMetalGpuEnabled(config, platform);
    stubCcFlags = `-DMOUI_SKIA_HAS_SKIA -std=c++17 -I${includePath}`;
    linkFlags = macosLibraryFlags(
      config,
      libPath,
      skiaLib,
      metalGpu,
      linkMode,
    ) + " -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework QuartzCore -framework UIKit";
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
    if (metalGpu) {
      stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_METAL");
      linkFlags = appendMissingFrameworks(linkFlags, [
        "Metal",
        "CoreVideo",
        "IOSurface",
      ]);
    }
  } else if (platform === "linux") {
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
    if (skiaGpuEnabled(config, platform)) {
      const ganeshExtStaticLib = path.join(libPath, "libskia_ganesh_ext.a");
      if (!fs.existsSync(ganeshExtStaticLib)) {
        throw new Error(
          `MOUI_SKIA_ENABLE_GPU_VULKAN requested, but ${ganeshExtStaticLib} was not found`,
        );
      }
      stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_VULKAN");
      linkFlags = appendMissingFlags(
        `${ganeshExtStaticLib} ${linkFlags}`,
        ["-lvulkan", "-ldl"],
      );
    }
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
    linkFlags = appendMissingFlags(linkFlags, ["-lstdc++", "-pthread"]);
  } else if (platform === "android") {
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
        ? androidStaticSkiaParagraphLinkFlags(libPath, skiaLib)
        : staticLib;
    } else {
      if (!fs.existsSync(dynamicLib)) {
        throw new Error(
          `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
        );
      }
      linkFlags = `-L${libPath} -l${skiaLib}`;
    }
    linkFlags = appendMissingFlags(linkFlags, [
      "-landroid",
      "-llog",
      "-lc++",
      "-lm",
      "-ldl",
    ]);
    if (skiaGpuEnabled(config, platform)) {
      const ganeshExtStaticLib = path.join(libPath, "libskia_ganesh_ext.a");
      if (!fs.existsSync(ganeshExtStaticLib)) {
        throw new Error(
          `Android GPU default/enable requested, but ${ganeshExtStaticLib} was not found`,
        );
      }
      // Default product path enables both Vulkan and EGL so runtime can pick.
      const vulkanExplicit = configEnvValue(config, "MOUI_SKIA_ENABLE_GPU_VULKAN");
      const eglExplicit = configEnvValue(config, "MOUI_SKIA_ENABLE_GPU_EGL");
      const enableVulkan = vulkanExplicit === null || String(vulkanExplicit).trim() === ""
        ? true
        : !falsy(vulkanExplicit);
      const enableEgl = eglExplicit === null || String(eglExplicit).trim() === ""
        ? true
        : !falsy(eglExplicit);
      if (enableVulkan) {
        stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_VULKAN");
        linkFlags = `${ganeshExtStaticLib} ${linkFlags}`;
      }
      if (enableEgl) {
        stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_EGL");
        linkFlags = appendMissingFlags(linkFlags, ["-lEGL", "-lGLESv2"]);
      }
    }
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(
        stubCcFlags,
        "-DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER",
      );
      if (resolvedLinkMode !== "static") {
        linkFlags = appendFlags(linkFlags, skiaParagraphLinkFlags(libPath, resolvedLinkMode, "android"));
      }
    }
  } else if (platform === "harmonyos") {
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
        ? unixStaticSkiaParagraphLinkFlags(libPath, skiaLib, "harmonyos")
        : staticLib;
    } else {
      if (!fs.existsSync(dynamicLib)) {
        throw new Error(
          `MOUI_SKIA_LINK_MODE=dynamic requested, but ${dynamicLib} was not found`,
        );
      }
      linkFlags = `-L${libPath} -l${skiaLib}`;
    }
    linkFlags = appendMissingFlags(linkFlags, [
      "-lc++",
      "-lm",
      "-ldl",
    ]);
    if (skiaGpuEnabled(config, platform)) {
      const ganeshExtStaticLib = path.join(libPath, "libskia_ganesh_ext.a");
      if (!fs.existsSync(ganeshExtStaticLib)) {
        throw new Error(
          `MOUI_SKIA_ENABLE_GPU_EGL requested, but ${ganeshExtStaticLib} was not found`,
        );
      }
      stubCcFlags = appendFlags(stubCcFlags, "-DMOUI_SKIA_ENABLE_GPU_EGL");
      linkFlags = appendMissingFlags(
        `${ganeshExtStaticLib} ${linkFlags}`,
        ["-lEGL", "-lGLESv3"],
      );
    }
    if (paragraphEnabled) {
      stubCcFlags = appendFlags(
        stubCcFlags,
        "-DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER",
      );
      if (resolvedLinkMode !== "static") {
        linkFlags = appendFlags(linkFlags, skiaParagraphLinkFlags(libPath, resolvedLinkMode, "harmonyos"));
      }
    }
  }

  const combinedLinkFlags = appendFlags(linkFlags, extraLinkFlags);
  return {
    stubCcFlags: appendFlags(stubCcFlags, extraCcFlags),
    linkFlags: ["macos", "ios", "iosSim"].includes(platform)
      ? appendMissingFrameworks(combinedLinkFlags, [])
      : combinedLinkFlags,
    androidLinkFlags: platform === "android" ? "-landroid -llog" : "",
  };
}

function fallbackNativeRuntimeLinkFlags(platform) {
  if (platform === "windows") {
    return "";
  }
  if (platform === "linux") {
    return "-lstdc++ -pthread";
  }
  return "-lc++";
}

function fallbackStubCcFlags(platform) {
  if (platform === "windows") {
    // MSVC defaults to C++14, which the native stubs already target.
    return "";
  }
  // macOS (Xcode clang) and Linux default to pre-C++11 without this flag.
  return "-std=c++17";
}

function main() {
  const config = readJsonFromStdin();
  const platform = skiaTargetPlatform(config);
  if (truthy(process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA)) {
    const nativeRuntimeLinkFlags =
      process.env.MOUI_SKIA_CC_LINK_FLAGS ||
      fallbackNativeRuntimeLinkFlags(platform);
    const triangleLinkFlags = macosExampleLinkFlags(
      "",
      ["QuartzCore", "AppKit"],
      platform,
    );
    const metalWindowLinkFlags = macosExampleLinkFlags(
      "",
      ["Metal", "QuartzCore", "CoreVideo", "IOSurface", "AppKit"],
      platform,
    );
    console.log(
      JSON.stringify({
        vars: {
          MOUI_SKIA_STUB_CC_FLAGS:
            process.env.MOUI_SKIA_STUB_CC_FLAGS || fallbackStubCcFlags(platform),
          MOUI_SKIA_CC_LINK_FLAGS:
            nativeRuntimeLinkFlags,
          MOUI_SKIA_ANDROID_LINK_FLAGS:
            process.env.MOUI_SKIA_ANDROID_LINK_FLAGS || "",
          MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
          MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
        },
        link_configs: [],
      }),
    );
    return;
  }
  rejectLegacyLinkModeEnv(config);
  if (!shouldConfigureSkia(config)) {
    const nativeRuntimeLinkFlags =
      process.env.MOUI_SKIA_CC_LINK_FLAGS ||
      fallbackNativeRuntimeLinkFlags(platform);
    const triangleLinkFlags = macosExampleLinkFlags(
      "",
      ["QuartzCore", "AppKit"],
      platform,
    );
    const metalWindowLinkFlags = macosExampleLinkFlags(
      "",
      ["Metal", "QuartzCore", "CoreVideo", "IOSurface", "AppKit"],
      platform,
    );
    console.log(
      JSON.stringify({
        vars: {
          MOUI_SKIA_STUB_CC_FLAGS: fallbackStubCcFlags(platform),
          MOUI_SKIA_CC_LINK_FLAGS: nativeRuntimeLinkFlags,
          MOUI_SKIA_ANDROID_LINK_FLAGS: "",
          MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
          MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
        },
        link_configs: [],
      }),
    );
    return;
  }

  const values = skiaValues(config);
  const flags = platformFlags(config, values);
  const triangleLinkFlags = macosExampleLinkFlags(
    flags.linkFlags,
    ["QuartzCore", "AppKit"],
    platform,
  );
  const metalWindowLinkFlags = macosExampleLinkFlags(
    flags.linkFlags,
    ["Metal", "QuartzCore", "CoreVideo", "IOSurface", "AppKit"],
    platform,
  );

  console.log(
    JSON.stringify({
      vars: {
        MOUI_SKIA_STUB_CC_FLAGS: flags.stubCcFlags,
        MOUI_SKIA_CC_LINK_FLAGS: flags.linkFlags,
        MOUI_SKIA_ANDROID_LINK_FLAGS: flags.androidLinkFlags,
        MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS: triangleLinkFlags,
        MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS: metalWindowLinkFlags,
      },
      link_configs: [],
    }),
  );
}

main();
