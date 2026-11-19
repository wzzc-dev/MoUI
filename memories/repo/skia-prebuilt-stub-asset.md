# Prebuilt Skia Stub Asset (macOS arm64)

2026-11-19:

- The macOS arm64 Release stub is published on the existing
  `wzzc-dev/skia` release `dev-6d73578a36`, next to the Skia archives:
  - asset `MoUISkiaStub-dev-6d73578a36-macos-Release-arm64.zip`
  - url `https://github.com/wzzc-dev/skia/releases/download/dev-6d73578a36/MoUISkiaStub-dev-6d73578a36-macos-Release-arm64.zip`
  - `sha256` `9c4692020357932c1c13ec755c592540388edc26bed483c19b76757b4fc694ab`, size 80,748 bytes
  - `sources_sha256` `0c4b6517b29a131178d91235dffb6f16619faa926f65f3da48d072c51de6d778`
- `skia-provider-lock.json` (`providers.release.stub_libraries.macos.Release.arm64`)
  already recorded the same name/sha/size/sources hash, so publishing needed no
  lock edit; the upload is what made the entry resolvable.
- Verify after any republish:
  - `bash moui_skia/scripts/publish-stub-library.sh --check` (sources match lock)
  - `curl -fsSL <url> | shasum -a 256` equals the lock `sha256`
  - `bash moui_skia/scripts/fetch-release-skia.sh --platform macos --arch arm64
    --config Release --print-env` reports `MOUI_SKIA_STUB_LIB=.../libmoui_skia_stub.a`
  - `MOUI_SKIA_STUB_MODE=prebuilt` prebuild emits the stub archive first in
    `MOUI_SKIA_CC_LINK_FLAGS`
- Only macOS arm64 has a published stub. Other platforms keep the `auto`
  fallback: when the lock has no entry (or the asset is absent) the prebuild
  compiles `native/*.cpp` locally; `MOUI_SKIA_STUB_MODE=prebuilt` makes that
  fallback a hard error.
- Republish whenever `moui_skia/native/*.cpp` changes; a stale asset is the known
  risk until MoonBit ships the `stub-cxx-flags` c/cpp split.
