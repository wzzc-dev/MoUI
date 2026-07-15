#!/usr/bin/env node

console.log(`[debug-top] ANDROID_HOME=${process.env.ANDROID_HOME}`);

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { defaultMouiRoot, defaultSkiaRoot, defaultWorkspaceRoot, readMobileApp } from "./app-config.mjs";

const usage = `Usage: moui/scripts/mobile/prepare-native-build.mjs --platform android|ios|harmonyos --app <id> --build-dir <dir> [options]

Options:
  --platform <name>          android, ios, or harmonyos.
  --app <id>                 Registered mobile app id.
  --app-config <path>        App-owned mobile.json. Default examples/<app>/mobile.json or ./mobile.json.
  --contracts <path>         Native contract registry. Default <moui-root>/mobile/build-contracts.json.
  --workspace-root <path>    App workspace root. Default current MoonBit workspace.
  --moui-root <path>         Resolved MoUI package root. Default ./moui or .mooncakes/wzzc-dev/moui.
  --skia-root <path>         Resolved moui_skia package root. Default ./moui_skia or .mooncakes/wzzc-dev/moui_skia.
  --build-dir <dir>          Generated build input directory.
  --abi <abi>                Android ABI, default arm64-v8a.
  --android-shell <mode>     Android managed or legacy shell, default managed.
  --sdk <sdk>                iOS SDK, iphonesimulator or iphoneos.
  --arch <arch>              iOS or HarmonyOS arch, default arm64.
  --renderer <mode>          auto, skia-gpu, or skia-raster. Default auto.
  --fallback-skia            Prepare native build inputs without real Skia.
  -h, --help                 Show this help.
`;

const androidAbiToSkiaArch = new Map([
  ["arm64-v8a", "arm64"],
  ["x86_64", "x64"],
  ["riscv64", "riscv64"],
]);

const androidAbiToTriple = new Map([
  ["arm64-v8a", "aarch64-linux-android"],
  ["x86_64", "x86_64-linux-android"],
  ["riscv64", "riscv64-linux-android"],
]);

const iosSdkToSkiaPlatform = new Map([
  ["iphonesimulator", "iosSim"],
  ["iphoneos", "ios"],
]);

const iosArchToSkiaArch = new Map([
  ["arm64", "arm64"],
  ["x86_64", "x64"],
]);

const harmonyosArchToOhosArch = new Map([
  ["arm64", "arm64-v8a"],
]);

const skiaStubSources = [
  "native/skia_stub.cpp",
  "native/skia_stub_common.cpp",
  "native/skia_stub_surface_image_data.cpp",
  "native/skia_stub_canvas.cpp",
  "native/skia_stub_path.cpp",
  "native/skia_stub_text_font.cpp",
  "native/skia_stub_paragraph.cpp",
  "native/skia_stub_shader_filter.cpp",
  "native/skia_stub_picture.cpp",
  "native/android_vulkan_loader.cpp",
  "native/skia_stub_gpu_worker.cpp",
];

const parseArgs = argv => {
  const options = {
    platform: "",
    app: "",
    appConfigPath: "",
    contractsPath: "",
    workspaceRoot: "",
    mouiRoot: "",
    skiaRoot: "",
    buildDir: "",
    abi: "arm64-v8a",
    androidShell: "managed",
    sdk: "iphonesimulator",
    arch: "arm64",
    renderer: "auto",
    fallbackSkia: false,
    help: false,
  };
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    if (arg === "--platform") {
      options.platform = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--app") {
      options.app = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--app-config") {
      options.appConfigPath = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--contracts") {
      options.contractsPath = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--workspace-root") {
      options.workspaceRoot = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--moui-root") {
      options.mouiRoot = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--skia-root") {
      options.skiaRoot = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--build-dir") {
      options.buildDir = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--abi") {
      options.abi = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--android-shell") {
      options.androidShell = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--sdk") {
      options.sdk = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--arch") {
      options.arch = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--renderer") {
      options.renderer = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--fallback-skia") {
      options.fallbackSkia = true;
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      options.help = true;
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return options;
};

const run = (cmd, args, options = {}) => {
  const result = spawnSync(cmd, args, {
    cwd: options.cwd || process.cwd(),
    env: options.env || process.env,
    stdio: options.stdio || "inherit",
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed with exit code ${result.status}`);
  }
  return result;
};

const ensureDir = path => mkdirSync(path, { recursive: true });

const normalizeBuildDir = (workspaceRoot, value) => isAbsolute(value) ? value : resolve(workspaceRoot, value);

const quoteCmake = value => String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");

const moonbitCPath = (buildDir, moonPackage, generatedC) =>
  join(buildDir, "moonbit/native/debug/build", moonPackage, generatedC);

const splitFlags = flags => flags.trim() === "" ? [] : flags.trim().split(/\s+/g);

const firstLinkDir = flags => {
  for (const flag of splitFlags(flags)) {
    if (flag.startsWith("-L") && flag.length > 2) return flag.slice(2);
  }
  return "";
};

const containsFlag = (flags, expected) => splitFlags(flags).includes(expected);

const latestChildDir = path => {
  if (!existsSync(path)) return "";
  const result = spawnSync("find", [path, "-mindepth", "1", "-maxdepth", "1", "-type", "d"], {
    encoding: "utf8",
  });
  if (result.status !== 0) return "";
  return result.stdout.trim().split("\n").filter(Boolean).sort().at(-1) || "";
};

const androidHome = () => {
  if (process.env.ANDROID_HOME) return process.env.ANDROID_HOME;
  if (process.env.ANDROID_SDK_ROOT) return process.env.ANDROID_SDK_ROOT;
  for (const candidate of [join(process.env.HOME || "", "Library/Android/sdk"), join(process.env.HOME || "", "Android/Sdk")]) {
    if (existsSync(candidate)) return candidate;
  }
  return "";
};

const androidNdkHome = sdkRoot => {
  if (process.env.ANDROID_NDK_HOME) return process.env.ANDROID_NDK_HOME;
  // Keep prepare-native-build aligned with mobile-app.gradle ndkVersion pin.
  const pinnedVersion = process.env.MOUI_ANDROID_NDK_VERSION || "28.2.13676358";
  const pinned = join(sdkRoot, "ndk", pinnedVersion);
  if (existsSync(pinned)) return pinned;
  const bundled = join(sdkRoot, "ndk-bundle");
  if (existsSync(bundled)) return bundled;
  return latestChildDir(join(sdkRoot, "ndk"));
};

const androidPrebuiltHost = ndkHome => {
  const prebuiltRoot = join(ndkHome, "toolchains/llvm/prebuilt");
  if (!existsSync(prebuiltRoot)) return "";
  // Prefer the only/host prebuilt dir; avoid non-deterministic `find` order.
  const hosts = readdirSync(prebuiltRoot).filter(name => {
    try {
      return statSync(join(prebuiltRoot, name)).isDirectory();
    } catch {
      return false;
    }
  }).sort();
  return hosts[0] ? join(prebuiltRoot, hosts[0]) : "";
};

const copyAndroidSharedLibs = ({ abi, ndkHome, skiaLinkFlags, jniLibsDir }) => {
  const abiDir = join(jniLibsDir, abi);
  rmSync(abiDir, { recursive: true, force: true });
  ensureDir(abiDir);
  const triple = androidAbiToTriple.get(abi);
  const hostRoot = androidPrebuiltHost(ndkHome);
  // Exact NDK sysroot path — never pick a stale/minimal libc++ from another NDK.
  const libcxx = hostRoot && triple
    ? join(hostRoot, "sysroot/usr/lib", triple, "libc++_shared.so")
    : "";
  if (libcxx && existsSync(libcxx)) {
    const dest = join(abiDir, "libc++_shared.so");
    copyFileSync(libcxx, dest);
    const size = statSync(dest).size;
    // Full NDK libc++ is multi-MB; a ~1MB stripped/minimal copy is a known crash source
    // (missing std::ostringstream vtable → UnsatisfiedLinkError at dlopen).
    if (size < 2_000_000) {
      throw new Error(
        `Android libc++_shared.so from ${libcxx} is only ${size} bytes; expected a full NDK libc++ (≥2MB). ` +
          `Pin ANDROID_NDK_HOME to a complete NDK and wipe artifacts/*/jniLibs before rebuild.`,
      );
    }
    console.log(`[moui-mobile-android] packaged libc++_shared.so from ${libcxx} (${size} bytes)`);
  } else {
    console.warn(
      `[moui-mobile-android] libc++_shared.so not found for abi=${abi} ndkHome=${ndkHome}; ` +
        `AGP will supply STL from its ndkVersion — pin the same NDK everywhere.`,
    );
  }
  if (containsFlag(skiaLinkFlags, "-lskia")) {
    const skiaLibDir = firstLinkDir(skiaLinkFlags);
    const skiaSo = join(skiaLibDir, "libskia.so");
    if (skiaLibDir && existsSync(skiaSo)) {
      copyFileSync(skiaSo, join(abiDir, "libskia.so"));
    }
  }
};

const resolveSkia = ({ skiaRoot, platform, arch, linkMode, fallback, gpuEnvironment = {} }) => {
  if (fallback) return { stubFlags: "", linkFlags: "" };
  const result = run("node", ["build.js"], {
    cwd: skiaRoot,
    env: {
      ...process.env,
      MOUI_SKIA_PLATFORM: platform,
      MOUI_SKIA_ARCH: arch,
      MOUI_SKIA_LINK_MODE: linkMode,
      ...gpuEnvironment,
    },
    stdio: ["pipe", "pipe", "inherit"],
  });
  const parsed = JSON.parse(result.stdout || "{}");
  return {
    stubFlags: parsed.vars?.MOUI_SKIA_STUB_CC_FLAGS || "",
    linkFlags: parsed.vars?.MOUI_SKIA_CC_LINK_FLAGS || "",
  };
};

const xcrunValue = args => {
  const result = spawnSync("xcrun", args, { encoding: "utf8" });
  if (result.status !== 0) return "";
  return result.stdout.trim();
};

const moonBuildEnv = () => {
  const env = {
    ...process.env,
    MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1",
    MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM: "1",
    MOONBIT_NEW_NATIVE: "0",
  };
  for (const key of [
    "SDKROOT",
    "SDK_NAME",
    "PLATFORM_NAME",
    "EFFECTIVE_PLATFORM_NAME",
    "ARCHS",
    "VALID_ARCHS",
    "IPHONEOS_DEPLOYMENT_TARGET",
    "LLVM_TARGET_TRIPLE_OS_VERSION",
    "LLVM_TARGET_TRIPLE_SUFFIX",
    "LLVM_TARGET_TRIPLE_VENDOR",
  ]) {
    delete env[key];
  }
  if (process.platform === "darwin") {
    const macosSdk = xcrunValue(["--sdk", "macosx", "--show-sdk-path"]);
    const macosCc = xcrunValue(["--sdk", "macosx", "--find", "clang"]);
    const macosCxx = xcrunValue(["--sdk", "macosx", "--find", "clang++"]);
    if (macosSdk) {
      env.SDKROOT = macosSdk;
      env.SDK_NAME = "macosx";
      env.PLATFORM_NAME = "macosx";
    }
    if (macosCc) env.CC = macosCc;
    if (macosCxx) env.CXX = macosCxx;
  }
  return env;
};

const generateMoonbitC = ({ workspaceRoot, moonPackage, generatedC, buildDir }) => {
  const moonbitTargetDir = join(buildDir, "moonbit");
  rmSync(moonbitTargetDir, { recursive: true, force: true });
  ensureDir(moonbitTargetDir);
  const result = spawnSync("moon", ["build", moonPackage, "--target", "native", "--target-dir", join(buildDir, "moonbit")], {
    cwd: workspaceRoot,
    env: moonBuildEnv(),
    stdio: "inherit",
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  const moonbitC = moonbitCPath(buildDir, moonPackage, generatedC);
  if (result.status !== 0 && !existsSync(moonbitC)) {
    throw new Error(`moon build ${moonPackage} --target native --target-dir ${moonbitTargetDir} failed with exit code ${result.status}`);
  }
  if (result.status !== 0) {
    console.error(`[moui-mobile-prepare] moon build returned ${result.status}; continuing because generated C exists: ${moonbitC}`);
  }
};

const validateAndroidLegacyExports = config => {
  if (typeof config.moonbitMainAlias !== "string" || config.moonbitMainAlias.trim() === "") {
    throw new Error("legacy Android shell requires moonbitMainAlias");
  }
  for (const field of [
    "attachSurface",
    "resize",
    "dispatchPointer",
    "frameTick",
    "renderFrame",
    "detachSurface",
  ]) {
    const value = config.exports?.[field];
    if (typeof value !== "string" || value.trim() === "") {
      throw new Error(`legacy Android shell requires exports.${field}`);
    }
  }
  if (config.supportsScroll &&
      (typeof config.exports?.dispatchScroll !== "string" || config.exports.dispatchScroll.trim() === "")) {
    throw new Error("legacy Android shell requires exports.dispatchScroll when scroll is enabled");
  }
};

const writeAndroidCmakeConfig = ({ config, app, buildDir, moonbitC, skia, abi, androidShell, rendererSelection, workspaceRoot, mouiRoot, skiaRoot }) => {
  const nativeDir = join(buildDir, "native");
  ensureDir(nativeDir);
  const cmakePath = join(nativeDir, "moui-mobile-native.cmake");
  const legacySymbolLines = androidShell === "legacy" ? [
    `set(MOUI_MOBILE_MOONBIT_MAIN_ALIAS "${quoteCmake(config.moonbitMainAlias)}")`,
    `set(MOUI_MOBILE_ENABLE_SCROLL ${config.supportsScroll ? "ON" : "OFF"})`,
    `set(MOUI_MOBILE_ATTACH_SURFACE_SYMBOL "${quoteCmake(config.exports.attachSurface)}")`,
    `set(MOUI_MOBILE_RESIZE_SYMBOL "${quoteCmake(config.exports.resize)}")`,
    `set(MOUI_MOBILE_DISPATCH_POINTER_SYMBOL "${quoteCmake(config.exports.dispatchPointer)}")`,
    `set(MOUI_MOBILE_DISPATCH_SCROLL_SYMBOL "${quoteCmake(config.exports.dispatchScroll || "moui_mobile_no_scroll")}")`,
    `set(MOUI_MOBILE_FRAME_TICK_SYMBOL "${quoteCmake(config.exports.frameTick)}")`,
    `set(MOUI_MOBILE_RENDER_FRAME_SYMBOL "${quoteCmake(config.exports.renderFrame)}")`,
    `set(MOUI_MOBILE_DETACH_SURFACE_SYMBOL "${quoteCmake(config.exports.detachSurface)}")`,
  ] : [];
  const lines = [
    "# Generated by moui/scripts/mobile/prepare-native-build.mjs.",
    `set(MOUI_WORKSPACE_ROOT "${quoteCmake(workspaceRoot)}")`,
    `set(MOUI_ROOT "${quoteCmake(mouiRoot)}")`,
    `set(MOUI_SKIA_ROOT "${quoteCmake(skiaRoot)}")`,
    `set(MOUI_MOON_HOME "${quoteCmake(process.env.MOON_HOME || join(process.env.HOME || "", ".moon"))}")`,
    `set(MOUI_MOBILE_LIBRARY_NAME "${quoteCmake(config.nativeLibrary)}")`,
    `set(MOUI_MOBILE_MOONBIT_C "${quoteCmake(moonbitC)}")`,
    `set(MOUI_MOBILE_APP_ARG "${quoteCmake(config.appArg)}")`,
    `set(MOUI_MOBILE_APP_ID "${quoteCmake(app)}")`,
    `set(MOUI_MOBILE_RENDERER_REQUESTED "${quoteCmake(rendererSelection.requested)}")`,
    `set(MOUI_MOBILE_RENDERER_SELECTED "${quoteCmake(rendererSelection.selected)}")`,
    ...legacySymbolLines,
    `set(MOUI_SKIA_STUB_CC_FLAGS "${quoteCmake(skia.stubFlags)}")`,
    `set(MOUI_SKIA_CC_LINK_FLAGS "${quoteCmake(skia.linkFlags)}")`,
    `set(MOUI_MOBILE_ANDROID_ABI "${quoteCmake(abi)}")`,
    "",
  ];
  writeFileSync(cmakePath, lines.join("\n"));
  return cmakePath;
};

const writeHarmonyosCmakeConfig = ({ config, app, buildDir, moonbitC, skia, ohosArch, rendererSelection, workspaceRoot, mouiRoot, skiaRoot }) => {
  const nativeDir = join(buildDir, "native");
  ensureDir(nativeDir);
  const cmakePath = join(nativeDir, "moui-mobile-harmonyos.cmake");
  const lines = [
    "# Generated by moui/scripts/mobile/prepare-native-build.mjs.",
    `set(MOUI_WORKSPACE_ROOT "${quoteCmake(workspaceRoot)}")`,
    `set(MOUI_ROOT "${quoteCmake(mouiRoot)}")`,
    `set(MOUI_SKIA_ROOT "${quoteCmake(skiaRoot)}")`,
    `set(MOUI_MOON_HOME "${quoteCmake(process.env.MOON_HOME || join(process.env.HOME || "", ".moon"))}")`,
    `set(MOUI_MOBILE_LIBRARY_NAME "${quoteCmake(config.nativeLibrary)}")`,
    `set(MOUI_MOBILE_MOONBIT_C "${quoteCmake(moonbitC)}")`,
    `set(MOUI_MOBILE_MOONBIT_MAIN_ALIAS "${quoteCmake(config.moonbitMainAlias)}")`,
    `set(MOUI_MOBILE_APP_ARG "${quoteCmake(config.appArg)}")`,
    `set(MOUI_MOBILE_APP_ID "${quoteCmake(app)}")`,
    `set(MOUI_MOBILE_RENDERER_REQUESTED "${quoteCmake(rendererSelection.requested)}")`,
    `set(MOUI_MOBILE_RENDERER_SELECTED "${quoteCmake(rendererSelection.selected)}")`,
    `set(MOUI_MOBILE_ENABLE_SCROLL ${config.supportsScroll ? "ON" : "OFF"})`,
    `set(MOUI_MOBILE_ATTACH_SURFACE_SYMBOL "${quoteCmake(config.exports.attachSurface)}")`,
    `set(MOUI_MOBILE_RESIZE_SYMBOL "${quoteCmake(config.exports.resize)}")`,
    `set(MOUI_MOBILE_DISPATCH_POINTER_SYMBOL "${quoteCmake(config.exports.dispatchPointer)}")`,
    `set(MOUI_MOBILE_DISPATCH_SCROLL_SYMBOL "${quoteCmake(config.exports.dispatchScroll || "moui_mobile_no_scroll")}")`,
    `set(MOUI_MOBILE_FRAME_TICK_SYMBOL "${quoteCmake(config.exports.frameTick)}")`,
    `set(MOUI_MOBILE_RENDER_FRAME_SYMBOL "${quoteCmake(config.exports.renderFrame)}")`,
    `set(MOUI_MOBILE_DETACH_SURFACE_SYMBOL "${quoteCmake(config.exports.detachSurface)}")`,
    `set(MOUI_SKIA_STUB_CC_FLAGS "${quoteCmake(skia.stubFlags)}")`,
    `set(MOUI_SKIA_CC_LINK_FLAGS "${quoteCmake(skia.linkFlags)}")`,
    `set(MOUI_MOBILE_HARMONYOS_OHOS_ARCH "${quoteCmake(ohosArch)}")`,
    "",
  ];
  writeFileSync(cmakePath, lines.join("\n"));
  return cmakePath;
};

const writeRsp = (path, flags) => {
  ensureDir(dirname(path));
  writeFileSync(path, splitFlags(flags).join("\n"));
};

const writeBuildJson = (path, value) => {
  ensureDir(dirname(path));
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
};

const selectRenderer = (requested, fallbackSkia) => {
  if (!["auto", "skia-gpu", "skia-raster"].includes(requested)) {
    throw new Error(`--renderer must be auto, skia-gpu, or skia-raster: ${requested}`);
  }
  // Product default is GPU for auto/skia-gpu when a real Skia package is linked.
  // fallbackSkia builds cannot provide a native GPU route, so they stay raster.
  if (requested === "skia-raster") {
    return {
      requested,
      selected: "skia-raster",
      gpuPromoted: false,
      fallbackReason: null,
    };
  }
  if (fallbackSkia) {
    return {
      requested,
      selected: "skia-raster",
      gpuPromoted: false,
      fallbackReason: "fallback Skia build cannot provide a native GPU route",
    };
  }
  return {
    requested,
    selected: "skia-gpu",
    gpuPromoted: true,
    fallbackReason: null,
  };
};

const prepareAndroid = ({ app, config, buildDir, abi, androidShell, renderer, fallbackSkia, workspaceRoot, mouiRoot, skiaRoot }) => {
  if (!androidAbiToSkiaArch.has(abi)) throw new Error(`unsupported Android ABI: ${abi}`);
  if (androidShell === "legacy") validateAndroidLegacyExports(config);
  generateMoonbitC({ workspaceRoot, moonPackage: config.moonPackage, generatedC: config.generatedC, buildDir });
  const moonbitC = moonbitCPath(buildDir, config.moonPackage, config.generatedC);
  if (!existsSync(moonbitC)) throw new Error(`MoonBit generated C was not found: ${moonbitC}`);
  const rendererSelection = selectRenderer(renderer, fallbackSkia);
  const skia = resolveSkia({
    skiaRoot,
    platform: "android",
    arch: androidAbiToSkiaArch.get(abi),
    linkMode: process.env.MOUI_SKIA_LINK_MODE || (
      rendererSelection.selected === "skia-gpu" ? "static" : "dynamic"
    ),
    fallback: fallbackSkia,
    gpuEnvironment: rendererSelection.selected === "skia-gpu"
      ? {
        MOUI_SKIA_ENABLE_GPU_VULKAN: "1",
        MOUI_SKIA_ENABLE_GPU_EGL: "1",
      }
      : {},
  });
  const sdkRoot = androidHome();
  const ndkHome = sdkRoot ? androidNdkHome(sdkRoot) : "";
  if (ndkHome) {
    copyAndroidSharedLibs({
      abi,
      ndkHome,
      skiaLinkFlags: skia.linkFlags,
      jniLibsDir: join(buildDir, "jniLibs"),
    });
  }
  const cmakeConfig = writeAndroidCmakeConfig({ config, app, buildDir, moonbitC, skia, abi, androidShell, rendererSelection, workspaceRoot, mouiRoot, skiaRoot });
  writeBuildJson(join(buildDir, "mobile-build.json"), {
    schemaVersion: 1,
    platform: "android",
    app,
    moonbitC,
    cmakeConfig,
    jniLibsDir: join(buildDir, "jniLibs"),
    fallbackSkia,
    renderer: rendererSelection,
    androidShell,
  });
};

const prepareIos = ({ app, config, buildDir, sdk, arch, renderer, fallbackSkia, workspaceRoot, mouiRoot, skiaRoot }) => {
  if (!iosSdkToSkiaPlatform.has(sdk)) throw new Error(`unsupported iOS SDK: ${sdk}`);
  if (!iosArchToSkiaArch.has(arch)) throw new Error(`unsupported iOS arch: ${arch}`);
  if (sdk === "iphoneos" && arch === "x86_64") throw new Error("x86_64 is only valid for iphonesimulator");
  generateMoonbitC({ workspaceRoot, moonPackage: config.moonPackage, generatedC: config.generatedC, buildDir });
  const moonbitC = moonbitCPath(buildDir, config.moonPackage, config.generatedC);
  if (!existsSync(moonbitC)) throw new Error(`MoonBit generated C was not found: ${moonbitC}`);
  const rendererSelection = selectRenderer(renderer, fallbackSkia);
  const skia = resolveSkia({
    skiaRoot,
    platform: iosSdkToSkiaPlatform.get(sdk),
    arch: iosArchToSkiaArch.get(arch),
    linkMode: process.env.MOUI_SKIA_LINK_MODE || "static",
    fallback: fallbackSkia,
    gpuEnvironment: rendererSelection.selected === "skia-gpu"
      ? { MOUI_SKIA_ENABLE_GPU_METAL: "1" }
      : {},
  });
  const nativeDir = join(buildDir, "native");
  const cxxRsp = join(nativeDir, "skia-cxx-flags.rsp");
  const linkRsp = join(nativeDir, "skia-link-flags.rsp");
  writeRsp(cxxRsp, skia.stubFlags);
  writeRsp(linkRsp, skia.linkFlags);
  writeBuildJson(join(buildDir, "mobile-build.json"), {
    schemaVersion: 1,
    platform: "ios",
    app,
    moonbitC,
    skiaCxxRsp: cxxRsp,
    skiaLinkRsp: linkRsp,
    fallbackSkia,
    renderer: rendererSelection,
    appArg: config.appArg,
    productName: config.productName,
    bundleId: config.bundleId,
    infoPlist: isAbsolute(config.infoPlist) ? config.infoPlist : resolve(workspaceRoot, config.infoPlist),
    moonbitMainAlias: config.moonbitMainAlias,
    fullscreen: config.fullscreen,
    supportsScroll: config.supportsScroll,
    exports: config.exports,
    workspaceRoot,
    mouiRoot,
    skiaRoot,
    skiaStubSources: skiaStubSources.map(path => join(skiaRoot, path)),
  });
};

const prepareHarmonyos = ({ app, config, buildDir, arch, renderer, fallbackSkia, workspaceRoot, mouiRoot, skiaRoot }) => {
  if (!harmonyosArchToOhosArch.has(arch)) throw new Error(`unsupported HarmonyOS arch: ${arch}`);
  generateMoonbitC({ workspaceRoot, moonPackage: config.moonPackage, generatedC: config.generatedC, buildDir });
  const moonbitC = moonbitCPath(buildDir, config.moonPackage, config.generatedC);
  if (!existsSync(moonbitC)) throw new Error(`MoonBit generated C was not found: ${moonbitC}`);
  const rendererSelection = selectRenderer(renderer, fallbackSkia);
  const skia = resolveSkia({
    skiaRoot,
    platform: "harmonyos",
    arch,
    linkMode: process.env.MOUI_SKIA_LINK_MODE || (
      rendererSelection.selected === "skia-gpu" ? "static" : "dynamic"
    ),
    fallback: fallbackSkia,
    gpuEnvironment: rendererSelection.selected === "skia-gpu"
      ? { MOUI_SKIA_ENABLE_GPU_EGL: "1" }
      : {},
  });
  const ohosArch = harmonyosArchToOhosArch.get(arch);
  const cmakeConfig = writeHarmonyosCmakeConfig({ config, app, buildDir, moonbitC, skia, ohosArch, rendererSelection, workspaceRoot, mouiRoot, skiaRoot });
  const sharedLibs = [];
  if (containsFlag(skia.linkFlags, "-lskia")) {
    const skiaLibDir = firstLinkDir(skia.linkFlags);
    const skiaSo = join(skiaLibDir, "libskia.so");
    if (skiaLibDir && existsSync(skiaSo)) sharedLibs.push(skiaSo);
  }
  writeBuildJson(join(buildDir, "mobile-build.json"), {
    schemaVersion: 1,
    platform: "harmonyos",
    app,
    moonbitC,
    cmakeConfig,
    fallbackSkia,
    renderer: rendererSelection,
    appArg: config.appArg,
    bundleName: config.bundleName,
    productName: config.productName,
    appName: config.appName,
    moduleName: config.moduleName,
    moduleDescription: config.moduleDescription,
    entryDescription: config.entryDescription,
    nativeLibrary: config.nativeLibrary,
    ohosArch,
    fullscreen: config.fullscreen,
    supportsScroll: config.supportsScroll,
    exports: config.exports,
    workspaceRoot,
    mouiRoot,
    skiaRoot,
    sharedLibs,
  });
};

try {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    process.exit(0);
  }
  if (!options.platform || !options.app || !options.buildDir) {
    throw new Error("--platform, --app, and --build-dir are required");
  }
  if (!["android", "ios", "harmonyos"].includes(options.platform)) {
    throw new Error("--platform must be android, ios, or harmonyos");
  }
  if (options.platform === "android" && !["managed", "legacy"].includes(options.androidShell)) {
    throw new Error("--android-shell must be managed or legacy");
  }
  selectRenderer(options.renderer);
  const workspaceRoot = resolve(options.workspaceRoot || defaultWorkspaceRoot());
  const mouiRootValue = options.mouiRoot || defaultMouiRoot(workspaceRoot);
  if (!mouiRootValue) throw new Error("unable to resolve MoUI package root; set MOUI_PACKAGE_ROOT or --moui-root");
  const mouiRoot = resolve(mouiRootValue);
  const skiaRootValue = options.skiaRoot || defaultSkiaRoot(workspaceRoot, mouiRoot);
  if (!skiaRootValue) throw new Error("unable to resolve moui_skia root; set MOUI_SKIA_ROOT or --skia-root");
  const skiaRoot = resolve(skiaRootValue);
  const appConfig = readMobileApp(options.app, {
    workspaceRoot,
    mouiRoot,
    skiaRoot,
    appConfigPath: options.appConfigPath,
    contractsPath: options.contractsPath,
  });
  const platformConfig = appConfig[options.platform];
  if (!platformConfig) throw new Error(`app ${options.app} does not support ${options.platform}`);
  const buildDir = normalizeBuildDir(workspaceRoot, options.buildDir);
  ensureDir(buildDir);
  if (options.platform === "android") {
    prepareAndroid({
      app: options.app,
      config: platformConfig,
      buildDir,
      abi: options.abi,
      androidShell: options.androidShell,
      renderer: options.renderer,
      fallbackSkia: options.fallbackSkia,
      workspaceRoot,
      mouiRoot,
      skiaRoot,
    });
  } else if (options.platform === "ios") {
    prepareIos({
      app: options.app,
      config: platformConfig,
      buildDir,
      sdk: options.sdk,
      arch: options.arch,
      renderer: options.renderer,
      fallbackSkia: options.fallbackSkia,
      workspaceRoot,
      mouiRoot,
      skiaRoot,
    });
  } else {
    prepareHarmonyos({
      app: options.app,
      config: platformConfig,
      buildDir,
      arch: options.arch,
      renderer: options.renderer,
      fallbackSkia: options.fallbackSkia,
      workspaceRoot,
      mouiRoot,
      skiaRoot,
    });
  }
} catch (error) {
  console.error(`[moui-mobile-prepare] ${error.message}`);
  console.error(usage.trimEnd());
  process.exit(1);
}
