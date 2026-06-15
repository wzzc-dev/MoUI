#!/usr/bin/env node

import { cpSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-"));
const validator = "scripts/validate-skia-entrypoints.mjs";

const copyDir = dir => {
  cpSync(dir, join(tmp, dir), { recursive: true });
};

copyDir("examples/showcase/macos_skia");
copyDir("examples/showcase/windows_skia");
copyDir("examples/showcase/linux_skia");
copyDir("examples/markdown_editor/macos_skia");
copyDir("examples/markdown_editor/windows_skia");
copyDir("examples/markdown_editor/linux_skia");
copyDir("examples/mo_workbench/macos_skia");

const runValidator = root =>
  spawnSync(process.execPath, [validator, root], { encoding: "utf8" });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, root, expectedMessage) => {
  const result = runValidator(root);
  if (result.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass("valid Skia entrypoints", runValidator(tmp));

const badImportRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-import-"));
cpSync(tmp, badImportRoot, { recursive: true });
const badPkg = join(badImportRoot, "examples/showcase/macos_skia/moon.pkg");
writeFileSync(
  badPkg,
  readFileSync(badPkg, "utf8").replace(
    '"wzzc-dev/moui/render/skia" @skia_renderer,',
    '"wzzc-dev/moui/render/wgpu" @skia_renderer,',
  ),
);
expectFail(
  "reject WGPU renderer import",
  badImportRoot,
  'missing \'"wzzc-dev/moui/render/skia" @skia_renderer\'',
);

const badRuntimeImportRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-runtime-import-"));
cpSync(tmp, badRuntimeImportRoot, { recursive: true });
const badRuntimePkg = join(badRuntimeImportRoot, "examples/showcase/macos_skia/moon.pkg");
writeFileSync(
  badRuntimePkg,
  readFileSync(badRuntimePkg, "utf8").replace(
    '  "wzzc-dev/moui/runtime",\n',
    "",
  ),
);
expectFail(
  "reject missing runtime import",
  badRuntimeImportRoot,
  'missing \'"wzzc-dev/moui/runtime"\'',
);

const badEnvRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-env-"));
cpSync(tmp, badEnvRoot, { recursive: true });
const badMain = join(badEnvRoot, "examples/showcase/macos_skia/main.mbt");
writeFileSync(
  badMain,
  readFileSync(badMain, "utf8").replace(
    "surface_route~)",
    "surface_route~,\n      first_frame_smoke_auto_exit=true)",
  ),
);
expectFail(
  "reject example first-frame smoke option",
  badEnvRoot,
  "first_frame_smoke_auto_exit",
);

const badRuntimeCtorRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-runtime-ctor-"));
cpSync(tmp, badRuntimeCtorRoot, { recursive: true });
const badRuntimeMain = join(badRuntimeCtorRoot, "examples/showcase/macos_skia/main.mbt");
writeFileSync(
  badRuntimeMain,
  readFileSync(badRuntimeMain, "utf8").replace(
    "@runtime.new_program_with_dimensions",
    "@runtime.new_view_with_dimensions",
  ),
);
expectFail(
  "reject missing runtime constructor",
  badRuntimeCtorRoot,
  "new_program_with_dimensions",
);

const badHostSummaryRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-host-summary-"));
cpSync(tmp, badHostSummaryRoot, { recursive: true });
const badShowcaseMain = join(badHostSummaryRoot, "examples/showcase/macos_skia/main.mbt");
writeFileSync(
  badShowcaseMain,
  readFileSync(badShowcaseMain, "utf8")
    .replace(
      "program_with_host_summary",
      "program",
    ),
);
expectFail(
  "reject missing Showcase Skia host summary",
  badHostSummaryRoot,
  "program_with_host_summary",
);

console.log("native Skia entrypoint validator tests: ok");
