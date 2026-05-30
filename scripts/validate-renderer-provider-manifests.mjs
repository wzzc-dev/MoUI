#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();

const read = path => readFileSync(join(root, path), "utf8");

let failed = false;

const fail = message => {
  console.error(message);
  failed = true;
};

const assertAbsent = (path, forbidden) => {
  const text = read(path);
  for (const token of forbidden) {
    if (text.includes(token)) {
      fail(`${path}: forbidden import/dependency token '${token}'`);
    }
  }
};

for (const platform of ["macos", "windows", "linux"]) {
  assertAbsent(`moui/backend/${platform}/moon.pkg`, [
    "wzzc-dev/moui/render",
    "wzzc-dev/moui/render/wgpu",
    "wzzc-dev/moui/render/skia",
    "Milky2018/wgpu_mbt",
    "wzzc-dev/skia_mbt",
  ]);

  assertAbsent(`moui/backend/${platform}/skia/moon.pkg`, [
    "wzzc-dev/moui/render/wgpu",
    "Milky2018/wgpu_mbt",
    `wzzc-dev/moui/backend/${platform}/wgpu`,
  ]);

  assertAbsent(`moui/backend/${platform}/wgpu/moon.pkg`, [
    "wzzc-dev/moui/render/skia",
    "wzzc-dev/skia_mbt",
    `wzzc-dev/moui/backend/${platform}/skia`,
  ]);
}

if (failed) {
  process.exit(1);
}

console.log("renderer provider manifest guard: ok");
