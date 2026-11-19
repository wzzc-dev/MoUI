#!/usr/bin/env node

import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const temporaryRoot = mkdtempSync(join(tmpdir(), "moui-prebuild-"));

// Every module with a `--moonbit-unstable-prebuild` hook owns a `build.mbtx`
// script. They need their real module root (moon resolves `moonbitlang/x`, and
// hooks such as `moui_tests` delegate to a sibling module), so each one runs in
// place with `--target-dir` under the temp root.
const prebuildModules = new Map([
  ["moui", join(repoRoot, "moui")],
  ["moui_webview", join(repoRoot, "moui_webview")],
  ["moui_text_providers", join(repoRoot, "moui_text_providers")],
  ["moui_metal_renderer", join(repoRoot, "moui_metal_renderer")],
  ["moui_tests", join(repoRoot, "moui_tests")],
  ["moui_skia", join(repoRoot, "moui_skia")],
  ["moui_skia_renderer", join(repoRoot, "moui_skia_renderer")],
  ["pdf_workbench", join(repoRoot, "examples/pdf_workbench")],
]);

const readRepoFile = relative => readFileSync(join(repoRoot, relative), "utf8");

// Static contracts. Every prebuild hook must be a `.mbtx` script: Node
// `build.js` hooks are gone, and `moui_skia` additionally owns the C++ stub, so
// its `.mbtx` prebuild has to stay the only compile owner (the `mbt`
// native-stub list stays C-only, which is what makes Windows D8016 unreachable).
for (const [module, moduleRoot] of prebuildModules) {
  const relative = module === "pdf_workbench"
    ? "examples/pdf_workbench"
    : module;
  const manifest = readRepoFile(`${relative}/moon.mod`);
  if (!manifest.includes('"--moonbit-unstable-prebuild": "build.mbtx"')) {
    throw new Error(`${relative}/moon.mod must point at build.mbtx`);
  }
  if (!existsSync(join(moduleRoot, "build.mbtx"))) {
    throw new Error(`${relative}/build.mbtx is missing`);
  }
  if (existsSync(join(moduleRoot, "build.js"))) {
    throw new Error(
      `${relative}/build.js must stay deleted: the prebuild only supports build.mbtx`,
    );
  }
}
for (const entry of readdirSync(repoRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  if (existsSync(join(repoRoot, entry.name, "build.js"))) {
    throw new Error(`${entry.name}/build.js must stay deleted: use build.mbtx`);
  }
}
const nativePkg = readRepoFile("moui_skia/native/moon.pkg");
if (nativePkg.includes('"native-stub"')) {
  throw new Error(
    "moui_skia/native/moon.pkg must not list C++ sources: the CLI injects " +
      "/std:c11 for MSVC stub compiles and cl.exe rejects it next to /std:c++20 (D8016)",
  );
}
if (nativePkg.includes("stub-cc-flags")) {
  throw new Error(
    "moui_skia/native/moon.pkg must not carry stub-cc-flags: the C++ stub is compiled by build.mbtx",
  );
}
if (!nativePkg.includes("MOUI_SKIA_CC_LINK_FLAGS")) {
  throw new Error("moui_skia/native/moon.pkg must link binding-local tests with Skia flags");
}

const lastJsonLine = stdout => {
  const lines = String(stdout || "")
    .split("\n")
    .map(line => line.trim())
    .filter(line => line.startsWith("{"));
  if (lines.length === 0) {
    throw new Error(`prebuild produced no JSON line\nstdout:\n${stdout}`);
  }
  return JSON.parse(lines[lines.length - 1]);
};

let mbtxRuns = 0;
const runMbtxPrebuild = (
  module,
  env = {},
  { expectFailure = false, config = { build: { target: { kind: "native" } } } } = {},
) => {
  mbtxRuns += 1;
  const moduleRoot = prebuildModules.get(module);
  if (!moduleRoot) {
    throw new Error(`unknown prebuild module: ${module}`);
  }
  const targetDir = join(
    temporaryRoot,
    `target-${module.replaceAll("/", "-")}-${mbtxRuns}`,
  );
  const result = spawnSync(
    "moon",
    ["run", "build.mbtx", "--target", "native", "--target-dir", targetDir],
    {
      cwd: moduleRoot,
      encoding: "utf8",
      input: JSON.stringify(config),
      env: { ...process.env, MOUI_SKIA_DISABLE_PREBUILD_SKIA: "", ...env },
    },
  );
  if (expectFailure) {
    if (result.status === 0) {
      throw new Error(
        `${module}/build.mbtx was expected to fail but exited 0 with:\n${result.stdout}`,
      );
    }
    return result;
  }
  if (result.status !== 0) {
    throw new Error(
      `${module}/build.mbtx failed (exit ${result.status})\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
  return lastJsonLine(result.stdout);
};

const linkPackages = config =>
  new Set((config.link_configs || []).map(entry => entry.package));
const flagsFor = (config, name) =>
  String(
    (config.link_configs || []).find(entry => entry.package === name)
      ?.link_flags || "",
  );
const tokenCount = (flags, token) =>
  String(flags).split(/\s+/).filter(candidate => candidate === token).length;
const frameworkCount = (flags, framework) => {
  const parts = String(flags).split(/\s+/);
  let count = 0;
  for (let index = 0; index + 1 < parts.length; index += 1) {
    if (parts[index] === "-framework" && parts[index + 1] === framework) {
      count += 1;
    }
  }
  return count;
};

// Fake release-provider layout: include/lib dirs plus a prebuilt stub archive,
// so the prebuild never fetches or compiles; the assertions below only cover the
// emitted flag/link-config string contract.
const fakeSkia = join(temporaryRoot, "fake-skia");
const fakeInclude = join(fakeSkia, "include");
const fakeLib = join(fakeSkia, "lib");
const fakeStub = join(fakeSkia, "libmoui_skia_stub.a");
mkdirSync(fakeInclude, { recursive: true });
mkdirSync(fakeLib, { recursive: true });
writeFileSync(fakeStub, "");
writeFileSync(join(fakeLib, "libskia.a"), "");
writeFileSync(join(fakeLib, "libskia_ganesh_ext.a"), "");
writeFileSync(join(fakeLib, "skia.lib"), "");

const stubKind = "libmoui_skia_stub.a";

const releaseEnv = {
  MOUI_SKIA_PLATFORM: "macos",
  MOUI_SKIA_LINK_MODE: "static",
  MOUI_SKIA_SKIA_INCLUDE: fakeInclude,
  MOUI_SKIA_SKIA_LIB_DIR: fakeLib,
  MOUI_SKIA_ENABLE_GPU_METAL: "1",
  MOUI_SKIA_ENABLE_SKPARAGRAPH: "0",
  MOUI_SKIA_STUB_LIB: fakeStub,
};

try {
  const base = runMbtxPrebuild("moui");
  const basePackages = linkPackages(base);
  if (
    basePackages.has("wzzc-dev/moui_skia_renderer") ||
    basePackages.has("wzzc-dev/moui_text_providers/fontconfig")
  ) {
    throw new Error("base prebuild must not own renderer link configs");
  }
  if (!basePackages.has("wzzc-dev/moui/backend/linux")) {
    throw new Error("base prebuild is missing the Linux host link config");
  }
  if (
    process.platform === "darwin" &&
    !flagsFor(base, "wzzc-dev/moui/backend/macos").includes("AppKit")
  ) {
    throw new Error("base prebuild is missing macOS host frameworks");
  }
  const android = runMbtxPrebuild("moui", { MOUI_SKIA_PLATFORM: "android" });
  if (!String(android.vars.MOUI_ANDROID_HOST_LINK_FLAGS).includes("-landroid")) {
    throw new Error("base prebuild must expose Android host link flags");
  }

  // `moui_skia`: one native link config that starts with the stub archive and
  // carries the release Skia archives exactly once.
  const skiaBinding = runMbtxPrebuild("moui_skia", releaseEnv);
  const skiaBindingPackages = linkPackages(skiaBinding);
  if (
    skiaBindingPackages.size !== 1 ||
    !skiaBindingPackages.has("wzzc-dev/moui_skia/native")
  ) {
    throw new Error(
      "Skia binding prebuild must carry exactly one link_configs entry for " +
        "wzzc-dev/moui_skia/native",
    );
  }
  const skiaBindingStubFlags = String(
    skiaBinding.vars.MOUI_SKIA_STUB_CC_FLAGS || "",
  );
  if (
    !skiaBindingStubFlags.includes("MOUI_SKIA_HAS_SKIA") ||
    !skiaBindingStubFlags.includes(fakeInclude)
  ) {
    throw new Error(
      "Skia binding prebuild must expose the Skia include dir through stub flags",
    );
  }
  const skiaBindingLinkFlags = String(
    skiaBinding.vars.MOUI_SKIA_CC_LINK_FLAGS || "",
  );
  if (flagsFor(skiaBinding, "wzzc-dev/moui_skia/native") !== skiaBindingLinkFlags) {
    throw new Error(
      "Skia binding link_configs must carry the same flags as MOUI_SKIA_CC_LINK_FLAGS",
    );
  }
  if (tokenCount(skiaBindingLinkFlags, fakeStub) !== 1) {
    throw new Error("Skia binding link flags must name the stub archive once");
  }
  if (skiaBinding.vars.MOUI_SKIA_STUB_LIB_PATH !== fakeStub) {
    throw new Error(
      "MOUI_SKIA_STUB_LIB must win over the lock entry and be reported verbatim",
    );
  }
  if (tokenCount(skiaBindingLinkFlags, join(fakeLib, "libskia.a")) !== 1) {
    throw new Error("Skia binding link flags must name libskia.a once");
  }
  if (
    tokenCount(skiaBindingLinkFlags, join(fakeLib, "libskia_ganesh_ext.a")) !== 1
  ) {
    throw new Error(
      "Metal GPU link flags must name libskia_ganesh_ext.a once",
    );
  }
  if (tokenCount(skiaBindingLinkFlags, "-lc++") !== 1) {
    throw new Error("Skia binding link config must contain -lc++ once");
  }
  if (tokenCount(skiaBindingLinkFlags, "-lobjc") !== 0) {
    throw new Error("Apple frameworks must provide the Skia Objective-C runtime");
  }
  for (const framework of [
    "Metal",
    "QuartzCore",
    "CoreVideo",
    "IOSurface",
    "AppKit",
  ]) {
    if (frameworkCount(skiaBindingLinkFlags, framework) !== 1) {
      throw new Error(
        `Skia binding link config must contain ${framework} framework once`,
      );
    }
  }

  // `moui_skia_renderer` delegates to the binding prebuild and re-emits one
  // final-application link config instead of duplicating Skia knowledge.
  const skiaRenderer = runMbtxPrebuild("moui_skia_renderer", releaseEnv);
  const skiaRendererPackages = linkPackages(skiaRenderer);
  if (
    skiaRendererPackages.size !== 1 ||
    !skiaRendererPackages.has("wzzc-dev/moui_skia_renderer")
  ) {
    throw new Error(
      "Skia renderer prebuild must own exactly one final-application " +
        "link_configs entry for wzzc-dev/moui_skia_renderer",
    );
  }
  const rendererFlags = flagsFor(skiaRenderer, "wzzc-dev/moui_skia_renderer");
  if (rendererFlags !== skiaBindingLinkFlags) {
    throw new Error(
      "Skia renderer prebuild must delegate the binding link flags unchanged",
    );
  }
  if (
    !String(skiaRenderer.vars.MOUI_SKIA_STUB_CC_FLAGS || "").includes(
      fakeInclude,
    )
  ) {
    throw new Error(
      "Skia renderer prebuild must delegate the binding stub compile flags",
    );
  }

  // `MOUI_SKIA_STUB_MODE` failures: unsupported value and a requested prebuilt
  // asset with no lock entry must both fail instead of falling back silently.
  runMbtxPrebuild(
    "moui_skia",
    { ...releaseEnv, MOUI_SKIA_STUB_LIB: "", MOUI_SKIA_STUB_MODE: "bogus" },
    { expectFailure: true },
  );
  runMbtxPrebuild(
    "moui_skia",
    {
      ...releaseEnv,
      MOUI_SKIA_STUB_LIB: "",
      MOUI_SKIA_PLATFORM: "windows",
      MOUI_SKIA_STUB_MODE: "prebuilt",
    },
    { expectFailure: true },
  );

  // Escape hatch: `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` compiles the stub locally
  // without Skia defines and still threads its archive into the native link.
  // Skip on Windows hosts because it shells out to `cl` and expects a VS env.
  if (process.platform === "win32") {
    console.log("escape-hatch stub compile skipped on Windows host");
  } else {
    const escapeHatch = runMbtxPrebuild("moui_skia", {
      MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1",
    });
    const escapeHatchStubFlags = String(
      escapeHatch.vars.MOUI_SKIA_STUB_CC_FLAGS || "",
    );
    if (escapeHatchStubFlags.includes("MOUI_SKIA_HAS_SKIA")) {
      throw new Error(
        "the escape hatch must compile the stub without Skia defines",
      );
    }
    const stubPath = String(escapeHatch.vars.MOUI_SKIA_STUB_LIB_PATH || "");
    if (!stubPath.endsWith(stubKind)) {
      throw new Error(
        `MOUI_SKIA_STUB_LIB_PATH must point at the locally built stub archive (got '${stubPath}')`,
      );
    }
    const escapeHatchFlags = String(
      escapeHatch.vars.MOUI_SKIA_CC_LINK_FLAGS || "",
    );
    if (tokenCount(escapeHatchFlags, stubPath) !== 1) {
      throw new Error("the escape hatch must still link the locally built stub");
    }
    if (escapeHatchFlags.includes("libskia.a")) {
      throw new Error("the escape hatch must not link real Skia archives");
    }
    if (
      (escapeHatch.link_configs || []).length !== 1 ||
      escapeHatch.link_configs[0].package !== "wzzc-dev/moui_skia/native"
    ) {
      throw new Error(
        "the escape hatch must still emit one native link_configs entry",
      );
    }
  }

  const textProviders = runMbtxPrebuild("moui_text_providers");
  const textProviderPackages = linkPackages(textProviders);
  if (!textProviderPackages.has("wzzc-dev/moui_text_providers/directwrite")) {
    throw new Error("text provider prebuild must own the DirectWrite link config");
  }
  if (process.platform === "linux") {
    if (
      !textProviderPackages.has("wzzc-dev/moui_text_providers/fontconfig") ||
      !flagsFor(textProviders, "wzzc-dev/moui_text_providers/fontconfig").includes(
        "fontconfig",
      )
    ) {
      throw new Error(
        "text provider prebuild must own Linux Fontconfig link flags",
      );
    }
  } else if (textProviderPackages.has("wzzc-dev/moui_text_providers/fontconfig")) {
    throw new Error("text provider prebuild must omit Fontconfig off Linux");
  }
  const metalRenderer = runMbtxPrebuild("moui_metal_renderer");
  const metalPackages = linkPackages(metalRenderer);
  if (process.platform === "darwin") {
    if (!metalPackages.has("wzzc-dev/moui_metal_renderer")) {
      throw new Error(
        "metal renderer prebuild must own its Apple framework link config",
      );
    }
    if (
      !flagsFor(metalRenderer, "wzzc-dev/moui_metal_renderer").includes(
        "-framework Metal",
      )
    ) {
      throw new Error("metal renderer link config must name the Metal framework");
    }
    const textProviderFlags = flagsFor(
      textProviders,
      "wzzc-dev/moui_text_providers/coretext",
    );
    if (!textProviderFlags.includes("-framework CoreText")) {
      throw new Error(
        "coretext must ship its own framework link config: a package's cc-link-flags " +
          "never reach an is-main link, so the symbols only resolve when a platform " +
          "backend happens to link the ApplicationServices umbrella",
      );
    }
  } else if (metalPackages.has("wzzc-dev/moui_metal_renderer")) {
    throw new Error("metal renderer prebuild must omit Apple frameworks off darwin");
  } else if (textProviderPackages.has("wzzc-dev/moui_text_providers/coretext")) {
    throw new Error("text provider prebuild must omit CoreText off darwin");
  }

  // `moui_webview`: the WebView host libraries travel as vars plus link configs,
  // and the WebView2 env var pair is rejected when it is incomplete.
  const webview = runMbtxPrebuild("moui_webview", {
    MOUI_WINDOWS_ENABLE_WEBVIEW2: "",
    MOUI_WINDOWS_WEBVIEW2_INCLUDE: "",
    MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS: "",
    MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS: "",
    MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS: "",
  });
  if (process.platform === "darwin") {
    if (
      !flagsFor(webview, "wzzc-dev/moui_webview/backend/macos").includes(
        "-framework WebKit",
      )
    ) {
      throw new Error("webview prebuild must own the macOS WebKit link config");
    }
  } else if (linkPackages(webview).has("wzzc-dev/moui_webview/backend/macos")) {
    throw new Error("webview prebuild must omit the WebKit config off darwin");
  }
  runMbtxPrebuild(
    "moui_webview",
    { MOUI_WINDOWS_ENABLE_WEBVIEW2: "1", MOUI_WINDOWS_WEBVIEW2_INCLUDE: "" },
    { expectFailure: true },
  );

  // `moui_tests` re-emits the renderer vars for its own harnesses and owns no
  // link config, so its Skia link flags must equal the renderer's.
  const tests = runMbtxPrebuild("moui_tests", releaseEnv);
  if ((tests.link_configs || []).length !== 0) {
    throw new Error("moui_tests prebuild must not own link_configs");
  }
  if (
    String(tests.vars.MOUI_SKIA_CC_LINK_FLAGS || "") !==
    String(skiaRenderer.vars.MOUI_SKIA_CC_LINK_FLAGS || "")
  ) {
    throw new Error(
      "moui_tests prebuild must re-emit the renderer Skia link flags",
    );
  }

  // `pdf_workbench` disables PDFium for non-native targets and for a bare
  // config, so the disabled shape is the empty var pair.
  const pdfDisabled = runMbtxPrebuild(
    "pdf_workbench",
    {},
    { config: { build: { target: { kind: "wasm-gc" } } } },
  );
  if (
    String(pdfDisabled.vars.MOUI_PDFIUM_STUB_CC_FLAGS || "") !== "" ||
    String(pdfDisabled.vars.MOUI_PDFIUM_CC_LINK_FLAGS || "") !== ""
  ) {
    throw new Error("pdf_workbench prebuild must stay disabled on wasm targets");
  }

  console.log("split module prebuild tests: ok");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
