# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

## Skia prebuild and prebuilt stub assets

- `moon.mod` points `--moonbit-unstable-prebuild` at `build.mbtx` (a MoonBit
  `.mbtx` script, no Node). It prints one JSON object with `vars` (expanded as
  `${build.*}` in `moon.pkg`) and one `link_configs` entry, the only carrier that
  reaches is-main links.
- Nested `moon` runs from a prebuild (the `moui_skia_renderer` hook and the
  `moui_tests` delegation both re-run `moui_skia/build.mbtx`) need their own
  `MOON_DEP_CACHE`, their own `--target-dir` subtree and their own `TMP`/`TEMP`:
  the parent build holds the shared dep-source cache lock for its whole run and
  runs prebuilds concurrently, so a nested moon that shares any of them fails
  with `Unable to lock dependency source cache`, MSVC `D8018` (cannot create
  linker response file) or `D8050` (cannot put the command line in the debug
  record). Both scripts namespace those paths through
  `MOUI_SKIA_PREBUILD_CACHE_NAMESPACE`.
- The C++ stub (`native/*.cpp`) is **not** part of the `mbt` `native-stub`
  compile anymore. It is published per platform/config/arch in MoUI's own
  `skia-stub-<skia-tag>` release (the `wzzc-dev/skia` release keeps only the
  Skia archives), and recorded in `skia-provider-lock.json` under
  `providers.release.stub_libraries`.
- `.github/workflows/moui-skia-stub-release.yml` owns publishing. Pushes that
  touch `native/*.cpp|*.h`, `build.mbtx`, or `publish-stub-library.sh` run
  `publish-stub-library.sh --check` per matrix leg first: a leg whose lock entry
  still matches `sources_sha256` is a no-op; the others rebuild, upload their raw
  archive as a workflow artifact, and one publish job packages, uploads with
  `--clobber`, verifies the digest and download URL, and commits every refreshed
  lock entry in one commit with `GITHUB_TOKEN` (a token push does not start a
  second CI run, and only the lock changes, so the stub sources are not
  re-triggered). `workflow_dispatch` with `force=true` republishes
  unconditionally; a forced rerun can rewrite the asset `sha256` because
  `ar`/`zip` output is not byte-reproducible.
- `moui_skia/native/moon.pkg` must list no C++ sources. Adding one back
  reintroduces the Windows D8016 clash (CLI `/std:c11` against Skia's
  `/std:c++20`), because `mbt` classifies MSVC stub compiles as C.
- Resolution order: `MOUI_SKIA_STUB_LIB` (explicit archive wins), then
  `MOUI_SKIA_STUB_MODE=auto|prebuilt|build`, then `MOUI_SKIA_STUB_CC` /
  `MOUI_SKIA_STUB_CC_FLAGS`. `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` is the
  pure-build escape hatch, not a rendering path: it skips every Skia
  include/lib/define fetch and still resolves the stub archive
  (`MOUI_SKIA_STUB_LIB` when set, otherwise a local no-Skia compile in the
  prebuild) so native links keep working, but the executable reports Skia
  unavailable. `MOUI_SKIA_STUB_MODE=prebuilt` under the hatch is a hard error
  (nothing was fetched); pass `MOUI_SKIA_STUB_LIB` instead. Non-native
  (wasm/js) targets never compile or link the stub, so web tooling keeps the
  hatch cheap. The hatch is not needed to dodge D8016 either: no `/std:c++20`
  ever reaches `mbt`; native evidence scripts that set it do so only to stay
  offline and avoid the real Skia dependency.
- `providers.release.mirrors` records two fallback kinds. `release-download`
  entries are hosted copies in the GitCode MoUI repository (`skia-<skia-tag>`,
  `skia-stub-<skia-tag>`); `url-prefix` entries are ghproxy-style services used
  as `<prefix><primary url>`, which need no upload and also cover Debug, wasm,
  and the source archive. Both are mirrors, not second producers: `wzzc-dev/skia`
  still builds Skia and MoUI still publishes the stub. `fetch-release-skia.{sh,ps1}`
  try the primary host, then the hosted copies, then the proxies, and verify the
  locked SHA256 and size on every candidate; `MOUI_SKIA_MIRROR` accepts
  `auto|off|<mirror-name>` (flags `--mirror NAME` / `--no-mirror`, `-Mirror` /
  `-NoMirror`). Proxies are third-party and only usable because of that check:
  several of them answer 200 with an error page or a truncated body. Never use a
  proxy as an upload target (`mirror-release-assets.sh` rejects it), and do not
  add a `release-download` entry whose filters claim assets the mirror does not
  serve: those filters are both the upload list for
  `scripts/mirror-release-assets.sh` and the download candidates for the fetch
  helpers. That script needs `GITCODE_TOKEN` and is gated by
  `.github/workflows/moui-skia-gitcode-mirror.yml`;
  `moui_skia/scripts/tests/fetch-release-skia-mirror.sh` proves the fallback
  offline in `pr-static`.
- Published stub coverage is a runner matrix, not one host: macOS arm64 and
  macOS x64 (Apple clang cross-compiled on the arm64 runner because MoonBit has
  no Darwin x86_64 toolchain), Linux x64, Linux arm64, and Windows x64 (MSVC with
  the vcvars environment imported in the build step). Each leg uploads its raw
  archive as a workflow artifact; one publish job packages, uploads, verifies,
  and commits every lock entry in a single commit, so a stale build tool never
  packages on the wrong OS. Android/iOS/tvOS/HarmonyOS and Debug stay unpublished
  on purpose: they need their own SDK toolchains, and `auto` compiles the stub
  locally there.
- `moui_skia/scripts/fetch-release-skia.{sh,ps1}` download the stub zip after
  the Skia package, verify its sha256/size, and emit `MOUI_SKIA_STUB_LIB`
  (plus `MOUI_SKIA_STUB_ASSET_SHA256` / `MOUI_SKIA_STUB_SOURCES_SHA256`) in
  `--print-env` / `-PrintEnv`. With no lock entry for the target they emit an
  empty value and the prebuild compiles `native/*.cpp` locally, so a clean
  checkout still builds; `MOUI_SKIA_STUB_MODE=prebuilt` turns that fallback
  into a hard error.
- Stale-asset risk (temporary, until MoonBit ships a `stub-cxx-flags` c/cpp
  split so the C++ stub can return to the `mbt` build): the released stub is a
  build artifact, so editing `native/*.cpp` without republishing leaves the lock
  pointing at an archive that no longer matches the sources. `build.mbtx`
  stamps the sources (`stub_source_stamp`) into its cache key; the cross-check
  is `moui_skia/scripts/publish-stub-library.sh --check`, which fails when
  `native/*.cpp` no longer hash to the lock's `sources_sha256`.
