# MoUI Android Template

This template is published with the `wzzc-dev/moui` package. The managed build
script stages it into the selected build directory, so normal applications do
not keep an `android_app` project in source control.

Build through the published package script:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

Schema v2 `mobile.json` files use the fixed Mobile Runtime ABI v1 contract; the
build resolves the MoonBit entrypoint and native library name without an
app-specific export map. Use `--android-project` only for a repository fixture
or an app-owned ejected shell.

The template uses the canonical Kotlin `MoUIActivity : ComponentActivity` and
registered JNI bridge. Its root is a `FrameLayout` containing the MoUI surface
below a native PlatformView overlay. Keep `android.builtInKotlin=true` and use a
JVM 17+ JDK. Install Android SDK Platform 36 for compilation; the generated app
continues to target API 35 and supports API 23+.

The preserved Java shell is a one-release framework fixture, not an app
template. Repository maintainers must pass its explicit Gradle project with
`--android-project` when using `--legacy-java-shell`; external apps should
remain on the default managed shell.
