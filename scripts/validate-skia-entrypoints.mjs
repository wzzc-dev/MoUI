#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2] ?? ".";

const entries = [
  {
    packagePath: "examples/showcase/macos_skia",
    platform: "macos",
    appImport: '"examples/showcase/app"',
    appConstructor: "@app.ShowcaseApp::new()",
    backendAlias: "@macos_skia_backend",
    hostBackendImport: '"wzzc-dev/moui/backend/macos" @macos_backend',
    hostSummaryCall: "@macos_backend.macos_capability_summary()",
    optionsType: "MacosSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Showcase"',
    expectedLinkToken: "-framework AppKit",
  },
  {
    packagePath: "examples/showcase/windows_skia",
    platform: "windows",
    appImport: '"examples/showcase/app" @showcase_app',
    appConstructor: "@showcase_app.ShowcaseApp::new()",
    backendAlias: "@windows_skia_backend",
    hostBackendImport: '"wzzc-dev/moui/backend/windows" @windows_backend',
    hostSummaryCall: "@windows_backend.windows_capability_summary()",
    optionsType: "WindowsSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Showcase"',
  },
  {
    packagePath: "examples/showcase/linux_skia",
    platform: "linux",
    appImport: '"examples/showcase/app" @showcase_app',
    appConstructor: "@showcase_app.ShowcaseApp::new()",
    backendAlias: "@linux_skia_backend",
    hostBackendImport: '"wzzc-dev/moui/backend/linux" @linux_backend',
    hostSummaryCall: "@linux_backend.linux_capability_summary()",
    optionsType: "LinuxSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Showcase"',
    expectedLinkToken: "-lz",
  },
  {
    packagePath: "examples/markdown_editor/macos_skia",
    platform: "macos",
    appImport: '"examples/markdown_editor/app"',
    appConstructor: "@app.MarkdownEditorApp::new()",
    backendAlias: "@macos_skia_backend",
    optionsType: "MacosSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Markdown Editor"',
    expectedLinkToken: "-framework AppKit",
  },
  {
    packagePath: "examples/markdown_editor/windows_skia",
    platform: "windows",
    appImport: '"examples/markdown_editor/app" @markdown_app',
    appConstructor: "@markdown_app.MarkdownEditorApp::new()",
    backendAlias: "@windows_skia_backend",
    optionsType: "WindowsSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Markdown Editor"',
  },
  {
    packagePath: "examples/markdown_editor/linux_skia",
    platform: "linux",
    appImport: '"examples/markdown_editor/app" @markdown_app',
    appConstructor: "@markdown_app.MarkdownEditorApp::new()",
    backendAlias: "@linux_skia_backend",
    optionsType: "LinuxSkiaAppOptions",
    runFunction: "run_app_with_options",
    envVar: "MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"MoUI Markdown Editor"',
    expectedLinkToken: "-lz",
  },
  {
    packagePath: "examples/mo_workbench/macos_skia",
    platform: "macos",
    appImport: '"examples/mo_workbench/app"',
    appConstructor: "@app.MoWorkbenchApp::new()",
    backendAlias: "@macos_skia_backend",
    optionsType: "MacosSkiaAppOptions",
    runFunction: "run_app_with_options_async_pump",
    envVar: "MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    appTitle: '"Mo Workbench"',
    expectedLinkToken: "-framework AppKit",
    allowAsyncPump: true,
  },
];

const platformBackendImport = {
  macos: '"wzzc-dev/moui/backend/macos/skia" @macos_skia_backend',
  windows: '"wzzc-dev/moui/backend/windows/skia" @windows_skia_backend',
  linux: '"wzzc-dev/moui/backend/linux/skia" @linux_skia_backend',
};

let failed = false;

const fail = message => {
  console.error(message);
  failed = true;
};

const read = path => readFileSync(join(root, path), "utf8");

const assertContains = (source, token, label) => {
  if (!source.includes(token)) {
    fail(`${label}: missing '${token}'`);
  }
};

const assertNotContains = (source, token, label) => {
  if (source.includes(token)) {
    fail(`${label}: must not contain '${token}'`);
  }
};

for (const entry of entries) {
  const pkgPath = `${entry.packagePath}/moon.pkg`;
  const mainPath = `${entry.packagePath}/main.mbt`;
  const pkg = read(pkgPath);
  const main = read(mainPath);

  assertContains(pkg, '"moonbitlang/core/env"', pkgPath);
  assertContains(pkg, platformBackendImport[entry.platform], pkgPath);
  if (entry.hostBackendImport) {
    assertContains(pkg, entry.hostBackendImport, pkgPath);
  }
  assertContains(pkg, '"wzzc-dev/moui/render/skia" @skia_renderer', pkgPath);
  assertContains(pkg, entry.appImport, pkgPath);
  assertContains(pkg, 'supported_targets = "native"', pkgPath);
  assertContains(pkg, '"is-main": true', pkgPath);
  assertContains(pkg, 'targets: { "main.mbt": [ "native" ] }', pkgPath);

  if (entry.expectedLinkToken) {
    assertContains(pkg, entry.expectedLinkToken, pkgPath);
  }

  assertNotContains(pkg, '"wzzc-dev/moui/render/wgpu"', pkgPath);
  assertNotContains(pkg, '"wzzc-dev/moui/backend/macos/wgpu"', pkgPath);
  assertNotContains(pkg, '"wzzc-dev/moui/backend/windows/wgpu"', pkgPath);
  assertNotContains(pkg, '"wzzc-dev/moui/backend/linux/wgpu"', pkgPath);

  assertContains(main, "///|", mainPath);
  assertContains(main, "fn main", mainPath);
  assertContains(main, entry.appConstructor, mainPath);
  if (entry.hostSummaryCall) {
    assertContains(main, "runtime_with_host_summary", mainPath);
    assertContains(main, entry.hostSummaryCall, mainPath);
  }
  assertContains(main, entry.envVar, mainPath);
  assertContains(main, "==\n    Some(\"1\")", mainPath);
  assertContains(main, "let font_resolution = if exit_after_first_present", mainPath);
  assertContains(main, "@skia_renderer.SkiaFontResolution::EmptyTypeface", mainPath);
  assertContains(main, "@skia_renderer.SkiaFontResolution::SystemFontMgr", mainPath);
  assertContains(main, `${entry.backendAlias}.${entry.runFunction}`, mainPath);
  assertContains(main, entry.appTitle, mainPath);
  assertContains(main, `${entry.backendAlias}.${entry.optionsType}::new`, mainPath);
  assertContains(main, "font_resolution~", mainPath);
  assertContains(main, "exit_after_first_present~", mainPath);

  if (!entry.allowAsyncPump) {
    assertNotContains(main, "run_app_with_options_async_pump", mainPath);
  }
}

if (failed) {
  process.exit(1);
}

console.log("native Skia example entrypoint validation: ok");
