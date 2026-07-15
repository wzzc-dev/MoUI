import assert from "node:assert/strict";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import test from "node:test";

import { readMobileApp } from "../../scripts/mobile/app-config.mjs";
import { resolveAndroidManagedShell } from "./resolve-managed-shell.mjs";

const repoRoot = resolve(import.meta.dirname, "../../..");
const read = path => readFileSync(path, "utf8");

const writeJson = (path, value) => writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);

const managedConfig = () => ({
  schemaVersion: 2,
  id: "android_fixture",
  displayName: "Android & Fixture",
  artifactName: "android_fixture",
  appPackage: "app",
  shellApiVersion: 1,
  runtimeAbiVersion: 1,
  mobile: {
    renderer: "auto",
    systemUi: { fullscreen: true, statusBar: "visible" },
    orientation: "landscape",
    resources: ["app-res", "assets/Splash Logo.PNG"],
    permissions: ["camera", "microphone", "location", "notifications", "photos", "clipboard"],
    plugins: [],
  },
  android: {
    applicationId: "dev.example.androidfixture",
    shellMode: "managed",
    minSdk: 27,
  },
});

const readFixtureApp = (workspaceRoot, config = managedConfig()) => {
  mkdirSync(join(workspaceRoot, "android_skia"), { recursive: true });
  writeFileSync(join(workspaceRoot, "android_skia/moon.pkg"), 'options("is-main": true)\n');
  const configPath = join(workspaceRoot, "mobile.json");
  const contractsPath = join(workspaceRoot, "contracts.json");
  writeJson(configPath, config);
  writeJson(contractsPath, { schemaVersion: 1, apps: {} });
  return readMobileApp("android_fixture", {
    workspaceRoot,
    mouiRoot: join(repoRoot, "moui"),
    skiaRoot: join(repoRoot, "moui_skia"),
    appConfigPath: configPath,
    contractsPath,
  });
};

test("managed Android resolver stages schema-driven manifest, resources, and permissions", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-android-managed-"));
  try {
    mkdirSync(join(workspaceRoot, "app-res/values"), { recursive: true });
    mkdirSync(join(workspaceRoot, "app-res/drawable"), { recursive: true });
    mkdirSync(join(workspaceRoot, "assets"), { recursive: true });
    writeFileSync(
      join(workspaceRoot, "app-res/values/strings.xml"),
      "<resources><string name=\"fixture_name\">Fixture</string></resources>\n",
    );
    writeFileSync(join(workspaceRoot, "app-res/drawable/fixture.txt"), "overlay\n");
    writeFileSync(join(workspaceRoot, "assets/Splash Logo.PNG"), "raw-image\n");

    const app = readFixtureApp(workspaceRoot);
    const buildDir = join(workspaceRoot, "build");
    const result = resolveAndroidManagedShell({ app, buildDir, workspaceRoot });
    const generated = JSON.parse(read(result.configPath));
    const manifest = read(result.manifestPath);

    assert.equal(generated.minSdk, 27);
    assert.equal(generated.compileSdk, 36);
    assert.equal(generated.targetSdk, 35);
    assert.equal(generated.orientation, "landscape");
    assert.equal(generated.screenOrientation, "landscape");
    assert.deepEqual(generated.systemUi, { fullscreen: true, statusBar: "visible" });
    assert.deepEqual(generated.permissionCapabilities, app.mobile.permissions);
    assert.deepEqual(
      generated.androidPermissions.map(permission => permission.name),
      [
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.CAMERA",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.RECORD_AUDIO",
      ],
    );
    assert.equal(
      generated.androidPermissions.find(permission =>
        permission.name === "android.permission.READ_EXTERNAL_STORAGE").maxSdkVersion,
      32,
    );

    assert.match(manifest, /android:label="Android &amp; Fixture"/);
    assert.match(manifest, /android:screenOrientation="landscape"/);
    assert.match(manifest, /android:name="dev\.wzzc\.moui\.FULLSCREEN"[\s\S]*android:value="true"/);
    assert.match(manifest, /android:name="dev\.wzzc\.moui\.STATUS_BAR"[\s\S]*android:value="visible"/);
    assert.match(manifest, /android:name="android\.permission\.CAMERA"/);
    assert.match(
      manifest,
      /android:name="android\.permission\.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/,
    );
    assert.doesNotMatch(manifest, /uses-permission[^\n]+clipboard/i);
    assert.doesNotMatch(manifest, /dev\.wzzc\.moui\.SUPPORTS_SCROLL/);

    assert.equal(generated.resourceDirs.length, 2);
    const overlayRecord = generated.resources.find(resource => resource.kind === "resource-overlay");
    const rawRecord = generated.resources.find(resource => resource.kind === "raw-file");
    assert.equal(read(join(overlayRecord.directory, "values/strings.xml")).includes("fixture_name"), true);
    assert.equal(read(join(overlayRecord.directory, "drawable/fixture.txt")), "overlay\n");
    assert.match(basename(rawRecord.destination), /^moui_app_001_splash_logo\.png$/);
    assert.equal(read(rawRecord.destination), "raw-image\n");
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});

test("ejected Android resolver preserves project-owned manifest, resources, and permission policy", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-android-ejected-"));
  try {
    const config = managedConfig();
    config.android.shellMode = "ejected";
    config.mobile.permissions = ["custom-native-capability"];
    const app = readFixtureApp(workspaceRoot, config);
    const projectManifest = join(workspaceRoot, "android_app/app/src/main/AndroidManifest.xml");
    const projectResource = join(workspaceRoot, "android_app/app/src/main/res/values/project.xml");
    mkdirSync(join(workspaceRoot, "android_app/app/src/main/res/values"), { recursive: true });
    writeFileSync(projectManifest, "<manifest><!-- ejected-custom-manifest --></manifest>\n");
    writeFileSync(projectResource, "<resources><!-- ejected-custom-resource --></resources>\n");

    const result = resolveAndroidManagedShell({
      app,
      buildDir: join(workspaceRoot, "build"),
      workspaceRoot,
    });

    assert.equal(result.configurationOwnership, "project-owned");
    assert.equal(result.manifestPath, null);
    assert.deepEqual(result.resourceDirs, []);
    assert.deepEqual(result.androidPermissions, []);
    assert.equal(read(projectManifest), "<manifest><!-- ejected-custom-manifest --></manifest>\n");
    assert.equal(read(projectResource), "<resources><!-- ejected-custom-resource --></resources>\n");
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});

test("managed Android resolver rejects unknown permission capabilities and invalid resource roots", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-android-managed-invalid-"));
  try {
    mkdirSync(join(workspaceRoot, "app-res"), { recursive: true });
    mkdirSync(join(workspaceRoot, "assets"), { recursive: true });
    writeFileSync(join(workspaceRoot, "app-res/not-an-android-resource.txt"), "invalid\n");
    writeFileSync(join(workspaceRoot, "assets/Splash Logo.PNG"), "raw-image\n");
    const app = readFixtureApp(workspaceRoot);
    app.mobile.permissions = ["bluetooth"];
    assert.throws(
      () => resolveAndroidManagedShell({ app, buildDir: join(workspaceRoot, "build"), workspaceRoot }),
      /does not support mobile\.permissions capability "bluetooth";.*eject the Android shell/,
    );

    app.mobile.permissions = [];
    assert.throws(
      () => resolveAndroidManagedShell({ app, buildDir: join(workspaceRoot, "build"), workspaceRoot }),
      /must contain Android res type directories/,
    );
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});

test("Android managed build consumes only generated schema v2 shell inputs", () => {
  const gradle = read(join(repoRoot, "moui/mobile/android/mobile-app.gradle"));
  const prepare = read(join(repoRoot, "moui/scripts/mobile/prepare-native-build.mjs"));
  const builder = read(join(repoRoot, "moui/scripts/mobile/build-android-apk.sh"));
  const activity = read(join(
    repoRoot,
    "moui/mobile/android/src/main/kotlin/dev/wzzc/moui/mobile/MoUIActivity.kt",
  ));

  assert.match(gradle, /generatedRoot}\/android\/\$\{androidShell}-shell/);
  assert.match(gradle, /generatedShellRoot}\/shell-config\.json/);
  assert.match(gradle, /manifest\.srcFile androidManagedManifest/);
  assert.match(gradle, /res\.srcDirs \+= androidAppResources/);
  assert.match(gradle, /if \(managedAndroidShell\) \{[\s\S]*androidManagedManifest = generatedPath/);
  assert.match(gradle, /ejectedAndroidShell/);
  assert.match(gradle, /must not claim project-owned manifest or resources/);
  const ejectedSourceSetStart = gradle.indexOf("} else if (ejectedAndroidShell) {");
  const ejectedSourceSetEnd = gradle.indexOf("} else {", ejectedSourceSetStart + 1);
  const ejectedSourceSet = gradle.slice(ejectedSourceSetStart, ejectedSourceSetEnd);
  assert.match(ejectedSourceSet, /androidPluginGeneratedKotlin/);
  assert.match(ejectedSourceSet, /androidPluginKotlin/);
  assert.match(ejectedSourceSet, /androidPluginJava/);
  assert.match(ejectedSourceSet, /androidPluginResources/);
  assert.doesNotMatch(ejectedSourceSet, /androidShellSourceRoot|androidManagedManifest|androidAppResources/);
  assert.match(gradle, /minSdkVersion = managedShellConfig\.minSdk\.intValue\(\)/);
  assert.match(gradle, /mouiMinSdk is only supported by the explicit legacy Android shell/);
  assert.ok(
    gradle.indexOf("new JsonSlurper().parse(metadataFile)") > gradle.indexOf("if (modernAndroidShell)"),
    "raw mobile.json parsing must stay inside the explicit legacy branch",
  );
  assert.match(gradle, /mouiCompileSdk"\) \?: "36"/);
  assert.match(gradle, /mouiTargetSdk"\) \?: "35"/);
  assert.match(gradle, /JavaVersion\.VERSION_17/);
  assert.match(gradle, /28\.2\.13676358/);
  assert.match(gradle, /version = "3\.22\.1"/);

  assert.match(prepare, /import \{ resolveAndroidManagedShell \}/);
  assert.match(prepare, /import \{ resolveAndroidNdkHome \} from "\.\/android-ndk\.mjs"/);
  assert.match(prepare, /sdkRoot \? resolveAndroidNdkHome\(sdkRoot\) : ""/);
  assert.match(prepare, /resolveAndroidManagedShell\(\{ app: appConfig, buildDir, workspaceRoot \}\)/);
  assert.match(prepare, /androidShellConfig,/);
  assert.doesNotMatch(builder, /^\s+"-PmouiMinSdk=\$api_level"$/m);
  assert.match(builder, /schema v2 android\.minSdk owns managed builds/);
  assert.match(builder, /legacy_java_shell" -eq 0.*gradle_args\+=\("-PmouiMinSdk=\$api_level"\)/s);
  assert.match(builder, /prepare_args\+=\("--android-shell" "ejected"\)/);
  assert.match(builder, /gradle_args\+=\("-PmouiAndroidShell=ejected"\)/);

  assert.match(activity, /META_STATUS_BAR/);
  assert.match(activity, /WindowInsetsCompat\.Type\.navigationBars\(\)/);
  assert.match(activity, /WindowInsetsCompat\.Type\.statusBars\(\)/);
  assert.match(activity, /STATUS_BAR_HIDDEN -> true/);
  assert.match(activity, /STATUS_BAR_VISIBLE -> false/);
  assert.doesNotMatch(activity, /hide\(WindowInsetsCompat\.Type\.systemBars\(\)\)/);
});
