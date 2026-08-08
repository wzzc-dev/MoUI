#!/usr/bin/env node

import {
  cpSync,
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
  wgpu: join(temporaryRoot, "moui_wgpu_renderer"),
  skiaBinding: join(temporaryRoot, "moui_skia"),
};

for (const root of Object.values(moduleRoots)) {
  mkdirSync(root, { recursive: true });
}
cpSync("moui/build.js", join(moduleRoots.base, "build.js"));
cpSync("moui_skia_renderer/build.js", join(moduleRoots.skia, "build.js"));
cpSync("moui_wgpu_renderer/build.js", join(moduleRoots.wgpu, "build.js"));

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

try {
  const base = runPrebuild(moduleRoots.base);
  const basePackages = linkPackages(base);
  if (basePackages.has("wzzc-dev/moui_skia_renderer") ||
      basePackages.has("wzzc-dev/moui_wgpu_renderer/fontconfig")) {
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
      linkPackages(disabledSkia).has("wzzc-dev/moui_skia_renderer")) {
    throw new Error("disabled Skia prebuild must expose an empty renderer config");
  }
  const skia = runPrebuild(moduleRoots.skia);
  if (!String(skia.vars.MOUI_SKIA_STUB_CC_FLAGS).includes("MOUI_SKIA_HAS_SKIA") ||
      !String(skia.vars.MOUI_SKIA_STUB_CC_FLAGS).includes("moui-skia-include")) {
    throw new Error("Skia renderer prebuild must reuse binding compile flags");
  }
  if (!flagsFor(skia, "wzzc-dev/moui_skia_renderer").includes("libskia.a")) {
    throw new Error("Skia renderer prebuild must own its link config");
  }

  const wgpu = runPrebuild(moduleRoots.wgpu);
  const wgpuPackages = linkPackages(wgpu);
  if (!wgpuPackages.has("wzzc-dev/moui_wgpu_renderer/directwrite")) {
    throw new Error("WGPU prebuild must own the DirectWrite link config");
  }
  if (process.platform === "linux") {
    if (!wgpuPackages.has("wzzc-dev/moui_wgpu_renderer/fontconfig") ||
        !flagsFor(wgpu, "wzzc-dev/moui_wgpu_renderer/fontconfig")
          .includes("fontconfig")) {
      throw new Error("WGPU prebuild must own Linux Fontconfig link flags");
    }
  } else if (wgpuPackages.has("wzzc-dev/moui_wgpu_renderer/fontconfig")) {
    throw new Error("WGPU prebuild must omit Fontconfig off Linux");
  }

  console.log("split module prebuild tests: ok");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
