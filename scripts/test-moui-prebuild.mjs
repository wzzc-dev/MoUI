#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const temporaryRoot = mkdtempSync(join(tmpdir(), "moui-prebuild-"));
const moduleRoots = {
  base: join(temporaryRoot, "moui"),
  skia: join(temporaryRoot, "moui_skia_renderer"),
  textProviders: join(temporaryRoot, "moui_text_providers"),
  metalRenderer: join(temporaryRoot, "moui_metal_renderer"),
  skiaBinding: join(temporaryRoot, "moui_skia"),
  realSkiaBinding: join(temporaryRoot, "real_moui_skia"),
};

for (const root of Object.values(moduleRoots)) {
  mkdirSync(root, { recursive: true });
}
cpSync("moui/build.js", join(moduleRoots.base, "build.js"));
cpSync("moui_skia_renderer/build.js", join(moduleRoots.skia, "build.js"));
cpSync(
  "moui_text_providers/build.js",
  join(moduleRoots.textProviders, "build.js"),
);
cpSync("moui_metal_renderer/build.js", join(moduleRoots.metalRenderer, "build.js"));
cpSync("moui_skia/build.js", join(moduleRoots.realSkiaBinding, "build.js"));

writeFileSync(
  join(moduleRoots.skiaBinding, "build.js"),
  `#!/usr/bin/env node
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
if (!input.includes("native")) process.exit(2);
console.log(JSON.stringify({
  vars: {
    MOUI_SKIA_STUB_CC_FLAGS: "-DMOUI_SKIA_HAS_SKIA -std=c++17 -I/tmp/moui-skia-include",
    MOUI_SKIA_CC_LINK_FLAGS: "/tmp/libskia.a",
  },
}));
`,
);

writeFileSync(
  join(moduleRoots.realSkiaBinding, "moon.mod"),
  'name = "wzzc-dev/moui_skia"\n',
);
const fakeSkiaInclude = join(moduleRoots.realSkiaBinding, "include");
const fakeSkiaLibDir = join(moduleRoots.realSkiaBinding, "lib");
mkdirSync(fakeSkiaInclude, { recursive: true });
mkdirSync(fakeSkiaLibDir, { recursive: true });
for (const name of [
  "skia",
  "skia_ganesh_ext",
  "skparagraph",
  "skshaper",
  "skunicode_icu",
  "skunicode_core",
  "harfbuzz",
  "icu",
]) {
  writeFileSync(join(fakeSkiaLibDir, `lib${name}.a`), "");
}

const runPrebuild = (root, env = {}) => {
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

try {
  const base = runPrebuild(moduleRoots.base);
  const basePackages = linkPackages(base);
  if (basePackages.has("wzzc-dev/moui_skia_renderer") ||
      basePackages.has("wzzc-dev/moui_text_providers/fontconfig")) {
    throw new Error("base prebuild must not own renderer link configs");
  }
  if (!basePackages.has("wzzc-dev/moui/backend/linux")) {
    throw new Error("base prebuild is missing the Linux host link config");
  }
  if (process.platform === "darwin" &&
      !flagsFor(base, "wzzc-dev/moui/backend/macos").includes("AppKit")) {
    throw new Error("base prebuild is missing macOS host frameworks");
  }
  const android = runPrebuild(moduleRoots.base, { MOUI_SKIA_PLATFORM: "android" });
  if (!String(android.vars.MOUI_ANDROID_HOST_LINK_FLAGS).includes("-landroid")) {
    throw new Error("base prebuild must expose Android host link flags");
  }

  const disabledSkia = runPrebuild(moduleRoots.skia, {
    MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1",
  });
  if (disabledSkia.vars.MOUI_SKIA_STUB_CC_FLAGS !== "" ||
      disabledSkia.link_configs.length !== 0) {
    throw new Error("disabled Skia prebuild must expose an empty renderer config");
  }
  const skia = runPrebuild(moduleRoots.skia);
  if (!String(skia.vars.MOUI_SKIA_STUB_CC_FLAGS).includes("MOUI_SKIA_HAS_SKIA") ||
      !String(skia.vars.MOUI_SKIA_STUB_CC_FLAGS).includes("moui-skia-include")) {
    throw new Error("Skia renderer prebuild must reuse binding compile flags");
  }
  if (!flagsFor(skia, "wzzc-dev/moui_skia_renderer").includes("libskia.a")) {
    throw new Error("Skia renderer prebuild must own final application link config");
  }
  const skiaBinding = runPrebuild(moduleRoots.skiaBinding);
  if (!String(skiaBinding.vars.MOUI_SKIA_CC_LINK_FLAGS).includes("libskia.a")) {
    throw new Error("Skia binding prebuild must own its native link config");
  }
  if ((skiaBinding.link_configs || []).length !== 0) {
    throw new Error("Skia binding prebuild must not duplicate package link flags");
  }

  const realSkiaBinding = runPrebuild(moduleRoots.realSkiaBinding, {
    MOUI_SKIA_PLATFORM: "macos",
    MOUI_SKIA_LINK_MODE: "static",
    MOUI_SKIA_SKIA_INCLUDE: fakeSkiaInclude,
    MOUI_SKIA_SKIA_LIB_DIR: fakeSkiaLibDir,
    MOUI_SKIA_ENABLE_GPU_METAL: "1",
    MOUI_SKIA_ENABLE_SKPARAGRAPH: "1",
    MOUI_SKIA_EXTRA_LINK_FLAGS: "-framework Metal -framework AppKit",
  });
  // `af9bafa6c` deliberately restored the native `link_configs` entry here, because a
  // package's cc-link-flags never reach an is-main link — `link_configs` is the only
  // carrier that does. The assertion this replaces demanded zero entries, which had
  // been false since then: the real risk is not that the binding carries link flags,
  // it is that the same archive reaches the linker twice.
  const realSkiaLinkConfigs = realSkiaBinding.link_configs || [];
  if (realSkiaLinkConfigs.length !== 1 ||
      realSkiaLinkConfigs[0].package !== "wzzc-dev/moui_skia/native") {
    throw new Error(
      "Skia binding prebuild must carry its native link flags through exactly one " +
        "link_configs entry for wzzc-dev/moui_skia/native",
    );
  }
  const realSkiaArchives = [
    "skia",
    "skia_ganesh_ext",
    "skparagraph",
    "skshaper",
    "skunicode_icu",
    "skunicode_core",
    "harfbuzz",
    "icu",
  ].map(name => join(fakeSkiaLibDir, `lib${name}.a`));
  const realSkiaLinkConfigFlags = String(
    realSkiaLinkConfigs[0].link_flags || "",
  );
  for (const archive of realSkiaArchives) {
    if (tokenCount(realSkiaLinkConfigFlags, archive) !== 1) {
      throw new Error(
        `Skia binding link_configs must contain ${archive} once`,
      );
    }
  }
  const realSkiaFlags = String(realSkiaBinding.vars.MOUI_SKIA_CC_LINK_FLAGS || "");
  for (const archive of realSkiaArchives) {
    if (tokenCount(realSkiaFlags, archive) !== 1) {
      throw new Error(`Skia binding link config must contain ${archive} once`);
    }
  }
  if (tokenCount(realSkiaFlags, "-lc++") !== 1) {
    throw new Error("Skia binding link config must contain -lc++ once");
  }
  if (tokenCount(realSkiaFlags, "-lobjc") !== 0) {
    throw new Error("Apple frameworks must provide the Skia Objective-C runtime");
  }
  for (const framework of [
    "Metal",
    "QuartzCore",
    "CoreVideo",
    "IOSurface",
    "AppKit",
  ]) {
    if (frameworkCount(realSkiaFlags, framework) !== 1) {
      throw new Error(
        `Skia binding link config must contain ${framework} framework once`,
      );
    }
  }

  const textProviders = runPrebuild(moduleRoots.textProviders);
  const textProviderPackages = linkPackages(textProviders);
  if (!textProviderPackages.has("wzzc-dev/moui_text_providers/directwrite")) {
    throw new Error("text provider prebuild must own the DirectWrite link config");
  }
  if (process.platform === "linux") {
    if (!textProviderPackages.has("wzzc-dev/moui_text_providers/fontconfig") ||
        !flagsFor(textProviders, "wzzc-dev/moui_text_providers/fontconfig")
          .includes("fontconfig")) {
      throw new Error("text provider prebuild must own Linux Fontconfig link flags");
    }
  } else if (textProviderPackages.has("wzzc-dev/moui_text_providers/fontconfig")) {
    throw new Error("text provider prebuild must omit Fontconfig off Linux");
  }
  const metalRenderer = runPrebuild(moduleRoots.metalRenderer);
  const metalPackages = linkPackages(metalRenderer);
  if (process.platform === "darwin") {
    if (!metalPackages.has("wzzc-dev/moui_metal_renderer")) {
      throw new Error("metal renderer prebuild must own its Apple framework link config");
    }
    if (!flagsFor(metalRenderer, "wzzc-dev/moui_metal_renderer").includes("-framework Metal")) {
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

  if (existsSync("moui_wgpu_renderer/build.js")) {
    throw new Error(
      "renderer modules must not own platform text link configs",
    );
  }

  console.log("split module prebuild tests: ok");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
