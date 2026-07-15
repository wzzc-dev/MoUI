# Android Release N Legacy Shell

This directory preserves the Java `Activity`/`SurfaceView` shell and its
name-mangled JNI adapter exactly as the Release N compatibility fixture. It is
not the production Android shell and does not receive new platform features.

The default build uses the Kotlin/AndroidX managed shell under
`moui/mobile/android`. Build this fixture only while validating the one-release
compatibility window:

```sh
scripts/build-mobile-android-apk.sh \
  --app counter \
  --fallback-skia \
  --legacy-java-shell \
  --compile-sdk 35
```

The fixture intentionally retains `MobileActivity`, `MobileSurfaceView`,
`MobileClipboardProvider`, and the legacy exported JNI symbols. Remove the
fixture at the documented Release N+1 compatibility boundary; do not copy code
from it back into the managed shell.
