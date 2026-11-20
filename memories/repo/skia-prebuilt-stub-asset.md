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
- GitCode mirror (China reachability): `providers.release.mirrors` in the lock
  records the MoUI AtomGit/GitCode repository (`gitcode.com/wzzc/MoUI`) as a
  mirror, not a second producer. `gitcode-skia` carries the Release static
  desktop packages (macos/linux/windows x arm64/x64 = 6 assets, 328,799,010
  bytes) under `skia-<skia-tag>`; `gitcode-skia-stub` carries the stub archives
  under `skia-stub-<skia-tag>`. Debug assets stay GitHub-only (they reach ~999 MB
  and are not used by CI).
- Mirror plumbing: `fetch-release-skia.{sh,ps1}` build the candidate list from
  the lock mirror filters, try the primary host then the mirrors, and verify the
  locked sha256 + size on every candidate, so a stale mirror is rejected.
  `MOUI_SKIA_MIRROR=auto|off|<name>` (`--mirror`/`--no-mirror`, `-Mirror`/
  `-NoMirror`) controls the order; `MOUI_SKIA_SKIA_PACKAGE_MIRROR` and
  `MOUI_SKIA_STUB_ASSET_MIRROR` in `--print-env` report the serving source.
- `moui_skia/scripts/mirror-release-assets.sh` fills the mirror: selection comes
  from the same lock filters, uploads go through
  `GET /repos/{owner}/{repo}/releases/{tag}/upload_url` (AtomGit API v5,
  `GITCODE_TOKEN`) followed by a PUT to the signed object-storage URL.
  `--list` (offline), `--dry-run`, `--force`, `--verify`, `--verify-only`.
  AtomGit release attachments can only be served once a tag exists, so the script
  creates the tag from `--ref main` before the release.
- Offline proof of the fallback lives in `pr-static`:
  `moui_skia/scripts/tests/fetch-release-skia-mirror.sh` builds a temporary lock
  whose primary URL is missing and whose mirror is a local `file://` directory,
  then asserts the mirror serves both artifacts, `--no-mirror` fails, `--mirror`
  reorders the candidates, and corrupt mirror bytes are rejected.
- Mirror caveat: GitCode has no `wzzc/skia` code repository, which is why every
  mirrored Skia asset lives in the MoUI GitCode repository. Do not add mirror
  filters that claim assets the script has not uploaded; the fetch helpers will
  spend a failed candidate on them before falling back.
- ghproxy-style fallback: `providers.release.mirrors` also carries `url-prefix`
  entries (`kind: url-prefix`, `prefix`), used as `<prefix><primary url>`. They
  need no upload and cover Debug/wasm/source, but rank after the GitCode copy.
  Measured 2026-11-19 from mainland China on the 80 KB stub asset: `gh-proxy.com`,
  `ghproxy.net`, and `ghproxy.monkeyray.net` returned byte-identical files;
  `ghproxy.cfd`, `ghproxy.cn`, `gh-proxy.net`, `ghproxy.homeboyc.cn`,
  `gitproxy.click` answered 200 with an error page or 401, and `ghfast.top`,
  `ghproxy.cc`, `mirror.ghproxy.com`, `ghp.ci`, `gh.llkk.cc`,
  `github.moeyy.xyz`, `hub.gitmirror.com`, `gh.xxooo.cf`,
  `gh.api.99988866.xyz`, `ghps.cc` were unreachable/404. The 54.7 MB
  `Skia-…-linux-Release-x64.zip` was much slower through these proxies than a
  hosted copy, so do not promote proxies above `gitcode-skia`, and keep the
  SHA256 check as the only reason they are safe to try at all.
- Stub coverage is a runner matrix (`moui-skia-stub-release.yml`): macos arm64 on
  `macos-latest`, macos x64 cross-compiled by Apple clang on the same runner
  (`MOUI_SKIA_STUB_CC` wrapper `cc -arch x86_64`, because MoonBit ships no
  Darwin x86_64 toolchain), linux x64 on `ubuntu-24.04`, linux arm64 on
  `ubuntu-24.04-arm`, windows x64 on `windows-2022` with the vcvars environment
  imported inside the build step. Build legs upload the raw archive as a
  workflow artifact; a single ubuntu publish job packages, uploads, verifies
  digest + download, patches every lock entry, and commits once, so packaging
  never depends on a non-Unix shell's `zip`/`shasum`.
- Android/iOS/tvOS/HarmonyOS and all Debug configs stay unpublished on purpose
  (SDK toolchains are not provisioned; `auto` compiles the stub locally there).
  `build.mbtx`'s stub cache key has no arch component, so the per-leg
  `actions/cache` key must keep `platform-arch` in it or two arches on one OS
  can restore each other's archive.
