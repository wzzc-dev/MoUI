#!/usr/bin/env node
// Unit tests for the pure hot-reload planning helpers. Run with:
//   node --test scripts/moui-dev-hot-plan.test.mjs
import assert from "node:assert/strict";
import test from "node:test";
import {
  WINDOWS_PLUGIN_EXPORTS,
  hotFastStepMatches,
  hotLinkArgs,
  hotLinkEnvironment,
  hotPlatformForNodePlatform,
  hotPluginFileName,
  picRuntimeCompile,
} from "./moui-dev-hot-plan.mjs";

test("macOS, Linux, and Windows hosts accept --hot", () => {
  assert.equal(hotPlatformForNodePlatform("darwin"), "macos");
  assert.equal(hotPlatformForNodePlatform("linux"), "linux");
  assert.equal(hotPlatformForNodePlatform("win32"), "windows");
  assert.equal(hotPlatformForNodePlatform("freebsd"), null);
});

test("plugin generations use a platform-native shared-library name", () => {
  assert.equal(hotPluginFileName("macos"), "plugin.dylib");
  assert.equal(hotPluginFileName("linux"), "plugin.so");
  assert.equal(hotPluginFileName("windows"), "plugin.dll");
});

test("macOS link uses force_load and the archive path", () => {
  const args = hotLinkArgs({
    platform: "macos",
    pluginArchive: "/repo/build/plugin.a",
    moonHome: "/moon",
    output: "/repo/gen-1/plugin.dylib",
  });
  assert.deepEqual(args, [
    "-shared",
    "-Wl,-force_load,/repo/build/plugin.a",
    "/moon/lib/libbacktrace.a",
    "-lm",
    "-o",
    "/repo/gen-1/plugin.dylib",
  ]);
});

test("Linux link uses whole-archive, PIC archive, and -Bsymbolic", () => {
  const args = hotLinkArgs({
    platform: "linux",
    pluginArchive: "/repo/build/plugin.a",
    picArchive: "/repo/pic/plugin.pic.a",
    moonHome: "/moon",
    output: "/repo/gen-1/plugin.so",
  });
  assert.deepEqual(args, [
    "-shared",
    "-Wl,-Bsymbolic",
    "-Wl,--whole-archive",
    "/repo/pic/plugin.pic.a",
    "-Wl,--no-whole-archive",
    "/moon/lib/libbacktrace.a",
    "-lm",
    "-o",
    "/repo/gen-1/plugin.so",
  ]);
});

test("runtime C compile rewrites its object and appends -fPIC", () => {
  const line =
    "/usr/bin/cc -o ./_build/native/debug/build/runtime-backtrace.o '-I$MOON_HOME/include' -g -c -fwrapv '$MOON_HOME/lib/runtime/backtrace.c'";
  const rewritten = picRuntimeCompile(line, "/tmp/pic/runtime-backtrace.o");
  assert.equal(
    rewritten,
    "/usr/bin/cc -o /tmp/pic/runtime-backtrace.o '-I$MOON_HOME/include' -g -c -fwrapv '$MOON_HOME/lib/runtime/backtrace.c' -fPIC",
  );
  assert.equal(
    picRuntimeCompile(
      "/usr/bin/cc -o ./_build/native/debug/build/wzzc-dev/moui_dev_hot/plugin/__moonbit_link_core__/plugin.o ./plugin.c",
      "/tmp/pic/plugin.o",
    ),
    null,
  );
  assert.equal(picRuntimeCompile("moonc build-package ./app.mbt", "/tmp/x"), null);
});

test("fast plan recompiles the generated plugin C before archiving", () => {
  const compile =
    "/usr/bin/cc -o ./_build/native/debug/build/wzzc-dev/moui_dev_hot/plugin/__moonbit_link_core__/plugin.o -I$MOON_HOME/include -g -c ... plugin.c -fPIC";
  assert.equal(hotFastStepMatches(compile, { appModule: "examples/counter" }), true);
  assert.equal(
    hotFastStepMatches("/usr/bin/cc -o /tmp/unrelated.o unrelated.c", {
      appModule: "examples/counter",
    }),
    false,
  );
});

test("fast plan keeps app/plugin compile, link-core, and archive steps", () => {
  const options = { appModule: "examples/counter" };
  assert.equal(
    hotFastStepMatches(
      "moonc build-package ./examples/counter/app/app.mbt -o ./_build/app.core",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "moonc build-package ./plugin/main.mbt -o ./_build/plugin.core",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "moonc build-package ./moui/core/core.mbt -o ./_build/core.core",
      options,
    ),
    false,
  );
  assert.equal(
    hotFastStepMatches(
      "moonc link-core ./a.core -main wzzc-dev/moui_dev_hot/plugin -o ./plugin.o",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "moon tool archive --output ./_build/wzzc-dev/moui_dev_hot/plugin/plugin.a -- /usr/bin/ar -r -c -s x.o",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "libtool -static -o ./_build/wzzc-dev/moui_dev_hot/plugin/plugin.a a.o",
      options,
    ),
    true,
  );
  assert.equal(hotFastStepMatches("/usr/bin/cc -c ./runtime/fs.c", options), false);
});

test("Windows link whole-archives the archive and exports every ABI entry", () => {
  const args = hotLinkArgs({
    platform: "windows",
    pluginArchive: "C:/repo/_build/plugin.lib",
    moonHome: "C:/Users/dev/.moon",
    output: "C:/repo/out/gen-1/plugin.dll",
  });
  assert.deepEqual(args.slice(0, 4), [
    "/NOLOGO",
    "/DLL",
    "/OUT:C:/repo/out/gen-1/plugin.dll",
    "/WHOLEARCHIVE:C:/repo/_build/plugin.lib",
  ]);
  for (const name of WINDOWS_PLUGIN_EXPORTS) {
    assert.equal(args.includes(`/EXPORT:${name}`), true, `missing /EXPORT:${name}`);
  }
  assert.equal(args.includes("moonbit_init"), false);
  assert.equal(args.includes("C:/repo/_build/plugin.lib"), true);
  assert.equal(args.includes("libcmt.lib"), true);
  assert.equal(args.includes("libbacktrace.a"), false);
});

test("Windows plugin link clears the inherited MSVC LINK environment", () => {
  assert.deepEqual(hotLinkEnvironment("windows"), { LINK: "" });
  assert.deepEqual(hotLinkEnvironment("linux"), {});
  assert.deepEqual(hotLinkEnvironment("macos"), {});
});

test("Windows fast plan matches cl.exe/.obj, lib.exe/.lib, and backslashes", () => {
  const options = { appModule: "examples/counter", archiveFragment: "moui_dev_hot/plugin/plugin.lib" };
  assert.equal(
    hotFastStepMatches(
      '"C:\\Program Files\\LLVM\\bin\\clang-cl.exe" /c /Fo.\\_build\\native\\debug\\build\\wzzc-dev\\moui_dev_hot\\plugin\\__moonbit_link_core__\\plugin.obj .\\plugin.c',
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "C:\\Program Files\\Microsoft Visual Studio\\VC\\Tools\\MSVC\\bin\\Hostx64\\x64\\lib.exe /nologo /Out:./_build/native/debug/build/wzzc-dev/moui_dev_hot/plugin/plugin.lib ./plugin.obj",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches(
      "moonc build-package ./examples/counter/app/app.mbt -o ./_build/app.core",
      options,
    ),
    true,
  );
  assert.equal(
    hotFastStepMatches("cl.exe /c /Fo./unrelated.obj ./unrelated.c", options),
    false,
  );
});
