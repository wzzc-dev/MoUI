#!/usr/bin/env node

import { cpSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-prebuild-"));
const mouiRoot = join(tmp, "moui");
const skiaRoot = join(tmp, "moui_skia");

mkdirSync(mouiRoot, { recursive: true });
mkdirSync(skiaRoot, { recursive: true });
cpSync("moui/build.js", join(mouiRoot, "build.js"));

writeFileSync(
  join(skiaRoot, "build.js"),
  `#!/usr/bin/env node
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
if (!input.includes("native")) {
  process.exit(2);
}
console.log(JSON.stringify({
  vars: {
    MOUI_SKIA_STUB_CC_FLAGS: "-DMOUI_SKIA_HAS_SKIA -std=c++17 -I/tmp/moui-skia-include",
    MOUI_SKIA_CC_LINK_FLAGS: "/tmp/libskia.a",
    MOUI_SKIA_ANDROID_LINK_FLAGS: "-landroid -llog",
  },
}));
`,
);

const runPrebuild = (env = {}) => {
  const result = spawnSync(process.execPath, ["build.js"], {
    cwd: mouiRoot,
    encoding: "utf8",
    input: JSON.stringify({ build: { target: { kind: "native" } }, env }),
    env: { ...process.env, MOUI_SKIA_DISABLE_PREBUILD_SKIA: "", ...env },
  });
  if (result.status !== 0) {
    throw new Error(
      `moui prebuild failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
  return JSON.parse(result.stdout);
};

const fallback = runPrebuild({ MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1" });
if (fallback.vars.MOUI_SKIA_STUB_CC_FLAGS !== "") {
  throw new Error("fallback prebuild should expose empty MOUI_SKIA_STUB_CC_FLAGS");
}
if (fallback.vars.MOUI_ANDROID_HOST_LINK_FLAGS !== "") {
  throw new Error("host-native fallback should not expose Android link flags");
}

const realSkia = runPrebuild();
if (!realSkia.vars.MOUI_SKIA_STUB_CC_FLAGS.includes("-DMOUI_SKIA_HAS_SKIA")) {
  throw new Error("real Skia prebuild should expose provider stub Skia flags");
}
if (!realSkia.vars.MOUI_SKIA_STUB_CC_FLAGS.includes("/tmp/moui-skia-include")) {
  throw new Error("real Skia prebuild should reuse moui_skia include flags");
}
if (realSkia.vars.MOUI_ANDROID_HOST_LINK_FLAGS !== "") {
  throw new Error("host-native prebuild should not expose Android link flags");
}

const android = runPrebuild({
  MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1",
  MOUI_SKIA_PLATFORM: "android",
});
if (!android.vars.MOUI_ANDROID_HOST_LINK_FLAGS.includes("-landroid")) {
  throw new Error("Android cross-build should expose Android host link flags");
}

const linkPackages = new Set(
  (realSkia.link_configs || []).map((entry) => entry.package),
);
const requirePackage = (name) => {
  if (!linkPackages.has(name)) {
    throw new Error(`missing link_configs entry for ${name}`);
  }
};
const flagsFor = (name) =>
  String(
    (realSkia.link_configs || []).find((entry) => entry.package === name)
      ?.link_flags || "",
  );

// Platform system libraries stay on host packages. Renderer libraries stay on
// renderer packages; fontconfig libraries are emitted only on Linux hosts.
requirePackage("wzzc-dev/moui/backend/linux");
requirePackage("wzzc-dev/moui/render/skia");
if (!flagsFor("wzzc-dev/moui/backend/linux").includes("-lz")) {
  throw new Error("linux host link_configs should include -lz");
}
if (!flagsFor("wzzc-dev/moui/render/skia").includes("/tmp/libskia.a")) {
  throw new Error("render/skia link_configs should include Skia link flags");
}
if (process.platform === "linux") {
  requirePackage("wzzc-dev/moui/render/wgpu/fontconfig");
  if (!flagsFor("wzzc-dev/moui/render/wgpu/fontconfig").includes("fontconfig")) {
    throw new Error("fontconfig link_configs should include fontconfig libs");
  }
} else if (flagsFor("wzzc-dev/moui/render/wgpu/fontconfig").includes("fontconfig")) {
  throw new Error("fontconfig link_configs should be omitted off Linux");
}

// DirectWrite is a renderer text implementation and remains renderer-owned.
requirePackage("wzzc-dev/moui/render/wgpu/directwrite");

if (process.platform === "darwin") {
  requirePackage("wzzc-dev/moui/backend/macos");
  if (!flagsFor("wzzc-dev/moui/backend/macos").includes("AppKit")) {
    throw new Error("macOS backend link_configs should include AppKit");
  }
  if (!String(fallback.vars.MOUI_MACOS_BACKEND_HOST_LINK_FLAGS || "").includes("AppKit")) {
    throw new Error("fallback should still expose macOS host framework vars");
  }
}

if (!String(realSkia.vars.MOUI_LINUX_BACKEND_HOST_LINK_FLAGS || "").includes("-lz")) {
  throw new Error("prebuild should expose MOUI_LINUX_BACKEND_HOST_LINK_FLAGS");
}

console.log("moui prebuild tests: ok");
