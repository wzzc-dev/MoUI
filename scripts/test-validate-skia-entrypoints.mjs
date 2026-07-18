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

const replaceRequired = (source, oldValue, newValue) => {
  if (!source.includes(oldValue)) {
    throw new Error(`fixture mutation token not found: ${oldValue}`);
  }
  return source.replace(oldValue, newValue);
};

copyDir("examples/showcase/macos_skia");
copyDir("examples/showcase/windows_skia");
copyDir("examples/showcase/linux_skia");
copyDir("examples/markdown_editor/macos_skia");
copyDir("examples/markdown_editor/windows_skia");
copyDir("examples/markdown_editor/linux_skia");
copyDir("examples/mo_workbench/macos_skia");
copyDir("moui/backend/macos/skia");
copyDir("moui/backend/windows/skia");
copyDir("moui/backend/linux/skia");

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
  replaceRequired(
    readFileSync(badPkg, "utf8"),
    '  "wzzc-dev/moui/runtime",\n',
    '  "wzzc-dev/moui/runtime",\n  "wzzc-dev/moui/render/wgpu",\n',
  ),
);
expectFail(
  "reject WGPU renderer import",
  badImportRoot,
  'must not contain \'"wzzc-dev/moui/render/wgpu"\'',
);

const badPackageKindRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-package-kind-"));
cpSync(tmp, badPackageKindRoot, { recursive: true });
const badPackageKind = join(badPackageKindRoot, "examples/showcase/macos_skia/moon.pkg");
writeFileSync(
  badPackageKind,
  replaceRequired(
    readFileSync(badPackageKind, "utf8"),
    'pkgtype(kind: "executable")',
    'options("is-main": true)',
  ),
);
expectFail(
  "reject legacy executable package marker",
  badPackageKindRoot,
  'missing \'pkgtype(kind: "executable")\'',
);

const badEntrypointLinkRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-entrypoint-link-"));
cpSync(tmp, badEntrypointLinkRoot, { recursive: true });
const badEntrypointLink = join(badEntrypointLinkRoot, "examples/showcase/macos_skia/moon.pkg");
writeFileSync(
  badEntrypointLink,
  replaceRequired(
    readFileSync(badEntrypointLink, "utf8"),
    '"cc-link-flags": ""',
    '"cc-link-flags": "-framework AppKit"',
  ),
);
expectFail(
  "reject entrypoint-owned platform links",
  badEntrypointLinkRoot,
  "must not contain '-framework AppKit'",
);

const badProviderLinkRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-provider-link-"));
cpSync(tmp, badProviderLinkRoot, { recursive: true });
const badProviderLink = join(badProviderLinkRoot, "moui/backend/macos/skia/moon.pkg");
writeFileSync(
  badProviderLink,
  replaceRequired(
    readFileSync(badProviderLink, "utf8"),
    "-framework AppKit",
    "-framework Foundation",
  ),
);
expectFail(
  "require provider-owned platform links",
  badProviderLinkRoot,
  "missing '-framework AppKit'",
);

const badSurfaceRouteRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-surface-route-"));
cpSync(tmp, badSurfaceRouteRoot, { recursive: true });
const badSurfaceRouteMain = join(badSurfaceRouteRoot, "examples/showcase/macos_skia/main.mbt");
writeFileSync(
  badSurfaceRouteMain,
  replaceRequired(
    readFileSync(badSurfaceRouteMain, "utf8"),
    "@macos_skia_backend.MacosSkiaAppOptions::new()",
    "@macos_skia_backend.MacosSkiaAppOptions::new(surface_route=@render.SkiaSurfaceRoute::MetalGpuSurfaceRoute)",
  ),
);
expectFail(
  "reject entrypoint-owned macOS surface route",
  badSurfaceRouteRoot,
  "must not contain '@render.SkiaSurfaceRoute::'",
);

const badProviderRouteRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-provider-route-"));
cpSync(tmp, badProviderRouteRoot, { recursive: true });
const badProviderRoute = join(badProviderRouteRoot, "moui/backend/macos/skia/macos_skia_provider.mbt");
writeFileSync(
  badProviderRoute,
  replaceRequired(
    readFileSync(badProviderRoute, "utf8"),
    "surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment()",
    "surface_route? : @render.SkiaSurfaceRoute",
  ),
);
expectFail(
  "require provider-owned macOS surface route default",
  badProviderRouteRoot,
  "missing 'surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment()'",
);

const badRuntimeImportRoot = mkdtempSync(join(tmpdir(), "moui-skia-entrypoints-bad-runtime-import-"));
cpSync(tmp, badRuntimeImportRoot, { recursive: true });
const badRuntimePkg = join(badRuntimeImportRoot, "examples/showcase/macos_skia/moon.pkg");
writeFileSync(
  badRuntimePkg,
  replaceRequired(
    readFileSync(badRuntimePkg, "utf8"),
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
  replaceRequired(
    readFileSync(badMain, "utf8"),
    "@macos_skia_backend.MacosSkiaAppOptions::new()",
    "@macos_skia_backend.MacosSkiaAppOptions::new(first_frame_smoke_auto_exit=true)",
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
  replaceRequired(
    readFileSync(badRuntimeMain, "utf8"),
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
  replaceRequired(
    readFileSync(badShowcaseMain, "utf8"),
    "program_with_host(",
    "program(",
  ),
);
expectFail(
  "reject missing Showcase Skia host summary",
  badHostSummaryRoot,
  "program_with_host_summary",
);

console.log("native Skia entrypoint validator tests: ok");
