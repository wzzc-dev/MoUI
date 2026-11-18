#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const temporaryRoot = mkdtempSync(join(tmpdir(), "moui-prebuild-"));

// Split module prebuild contract, in two families:
//   - `build.js` modules still run as Node scripts copied into a temp module.
//   - `moui_skia` / `moui_skia_renderer` own `build.mbtx` scripts that need
//     their real module root (moon resolves `moonbitlang/x`), so they run in
//     place with `--target-dir` under the temp root.
const moduleRoots = {
  base: join(temporaryRoot, "moui"),
  textProviders: join(temporaryRoot, "moui_text_providers"),
  metalRenderer: join(temporaryRoot, "moui_metal_renderer"),
};

for (const root of Object.values(moduleRoots)) {
  mkdirSync(root, { recursive: true });
}
cpSync(join(repoRoot, "moui/build.js"), join(moduleRoots.base, "build.js"));
cpSync(
  join(repoRoot, "moui_text_providers/build.js"),
  join(moduleRoots.textProviders, "build.js"),
);
cpSync(
  join(repoRoot, "moui_metal_renderer/build.js"),
  join(moduleRoots.metalRenderer, "build.js"),
);

const readRepoFile = relative => readFileSync(join(repoRoot, relative), "utf8");

// Static contracts for the prebuilt-stub architecture (option 1). These are the
// invariants that make the Windows D8016 clash unreachable: the `.mbtx` prebuild
// owns the C++ compile, and the `mbt` native-stub list stays C-only (empty here).
for (const module of ["moui_skia", "moui_skia_renderer"]) {
  const manifest = readRepoFile(`${module}/moon.mod`);
  if (!manifest.includes('"--moonbit-unstable-prebuild": "build.mbtx"')) {
    throw new Error(`${module}/moon.mod must point at build.mbtx`);
  }
  if (!existsSync(join(repoRoot, module, "build.mbtx"))) {
    throw new Error(`${module}/build.mbtx is missing`);
  }
  if (existsSync(join(repoRoot, module, "build.js"))) {
    throw new Error(
      `${module}/build.js must stay deleted: the prebuild only supports build.mbtx`,
    );
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

const runNodePrebuild = (root, env = {}) => {
  const result = spawnSync(process.execPath, ["build.js"], {
    cwd: root,
    encoding: "utf8",
    input: JSON.stringify({ build: { target: { kind: "native" } }, env }),
    env: { ...process.env, MOUI_SKIA_DISABLE_PREBUILD_SKIA: "", ...env },
  });
  if (result.status !== 0) {
    throw new Error(
      `prebuild failed in ${root}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
  return JSON.parse(result.stdout);
};

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
const runMbtxPrebuild = (module, env = {}, { expectFailure = false } = {}) => {
  mbtxRuns += 1;
  const targetDir = join(temporaryRoot, `target-${module}-${mbtxRuns}`);
  const result = spawnSync(
    "moon",
    ["run", "build.mbtx", "--target", "native", "--target-dir", targetDir],
    {
      cwd: join(repoRoot, module),
      encoding: "utf8",
      input: JSON.stringify({ build: { target: { kind: "native" } } }),
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
  const base = runNodePrebuild(moduleRoots.base);
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
  const android = runNodePrebuild(moduleRoots.base, {
    MOUI_SKIA_PLATFORM: "android",
  });
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

  const textProviders = runNodePrebuild(moduleRoots.textProviders);
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
  const metalRenderer = runNodePrebuild(moduleRoots.metalRenderer);
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

  if (existsSync(join(repoRoot, "moui_wgpu_renderer/build.js"))) {
    throw new Error("renderer modules must not own platform text link configs");
  }

  console.log("split module prebuild tests: ok");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
