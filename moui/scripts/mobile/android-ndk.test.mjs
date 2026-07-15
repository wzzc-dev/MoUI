import assert from "node:assert/strict";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { resolveAndroidNdkHome } from "./android-ndk.mjs";

const writeCompleteNdk = (root, revision) => {
  const bin = join(root, "toolchains/llvm/prebuilt/test-host/bin");
  mkdirSync(bin, { recursive: true });
  writeFileSync(join(root, "source.properties"), `Pkg.Revision = ${revision}\n`);
  const clang = join(bin, process.platform === "win32" ? "clang.exe" : "clang");
  writeFileSync(clang, "fake clang\n");
  chmodSync(clang, 0o755);
};

test("Android NDK resolution ignores an incompatible environment override", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-android-ndk-"));
  try {
    const sdkRoot = join(root, "sdk");
    const incompatible = join(root, "ndk-25");
    const required = join(sdkRoot, "ndk/28.2.13676358");
    writeCompleteNdk(incompatible, "25.2.9519653");
    writeCompleteNdk(required, "28.2.13676358");

    assert.equal(resolveAndroidNdkHome(sdkRoot, {
      ANDROID_NDK_HOME: incompatible,
    }), required);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("Android NDK resolution accepts only complete matching candidates", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-android-ndk-order-"));
  try {
    const sdkRoot = join(root, "sdk");
    const incomplete = join(root, "incomplete-ndk");
    const configured = join(root, "configured-ndk-root");
    const sideBySide = join(sdkRoot, "ndk/28.2");
    mkdirSync(incomplete, { recursive: true });
    writeFileSync(
      join(incomplete, "source.properties"),
      "Pkg.Revision = 28.2.13676358\n",
    );
    writeCompleteNdk(configured, "28.2.13676358");
    writeCompleteNdk(sideBySide, "28.2.13676358");

    assert.equal(resolveAndroidNdkHome(sdkRoot, {
      ANDROID_NDK_HOME: incomplete,
      ANDROID_NDK_ROOT: configured,
      MOUI_ANDROID_NDK_VERSION: "28.2",
    }), configured);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("Android NDK resolution enforces the configured version floor", () => {
  assert.throws(
    () => resolveAndroidNdkHome("/missing-sdk", {
      MOUI_ANDROID_NDK_VERSION: "27.2",
    }),
    /below the 28\.2 floor/,
  );
  assert.throws(
    () => resolveAndroidNdkHome("/missing-sdk", {
      MOUI_ANDROID_NDK_VERSION: "invalid",
    }),
    /is invalid/,
  );
});

test("Android NDK resolution reports no match without guessing a newer directory", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-android-ndk-missing-"));
  try {
    const sdkRoot = join(root, "sdk");
    writeCompleteNdk(join(sdkRoot, "ndk/29.0.1"), "29.0.1");
    assert.equal(resolveAndroidNdkHome(sdkRoot, {}), "");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
