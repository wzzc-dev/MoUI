# Prebuilt Skia Stub Asset (macOS arm64)

2026-11-19:

- The macOS arm64 Release stub is published on MoUI's own release
  `skia-stub-dev-6d73578a36`, not on `wzzc-dev/skia` (that release keeps only
  the upstream Skia archives):
  - asset `MoUISkiaStub-dev-6d73578a36-macos-Release-arm64.zip`
  - url `https://github.com/wzzc-dev/MoUI/releases/download/skia-stub-dev-6d73578a36/MoUISkiaStub-dev-6d73578a36-macos-Release-arm64.zip`
  - lock `sha256`/`size`/`sources_sha256` live in
    `skia-provider-lock.json` (`providers.release.stub_libraries.macos.Release.arm64`)
- Publishing is automated by `.github/workflows/moui-skia-stub-release.yml`:
  push triggers on `moui_skia/native/*.cpp|*.h`, `build.mbtx`,
  `publish-stub-library.sh`, and the workflow file; first step is
  `publish-stub-library.sh --check` (no-op while `sources_sha256` matches), then
  `moon run build.mbtx` with `MOUI_SKIA_STUB_MODE=build` compiles the stub on
  `macos-latest`, `gh release upload --clobber` publishes it to
  `skia-stub-<skia-tag>`, the digest and download URL are checked, and the lock
  is committed with `GITHUB_TOKEN` (token pushes do not start a second CI run).
  `workflow_dispatch` with `force=true` republishes unconditionally.
- The asset name stays `MoUISkiaStub-<skia-tag>-<platform>-<config>-<arch>.zip`
  across releases; rebuilding changes the zip `sha256` because `ar`/`zip` output
  is not byte-reproducible, so a forced republish always rewrites the lock.
- `publish-stub-library.sh` flags used by the workflow: `--tag` names the hosted
  release (`skia-stub-<skia-tag>`), `--asset-tag` keeps `<skia-tag>` inside the
  asset name, `--release-owner/--release-repo` move the upload target off the
  lock's default `wzzc-dev/skia`, and `--print-sources` prints
  `MOUI_SKIA_STUB_SOURCES_SHA256=...` without packaging.
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
