# Third-Party Notices

MoUI is licensed under Apache-2.0. This file records the main third-party
sources and generated materials that contributors should keep in mind when
updating the project.

## MoonBit Packages

MoonBit package dependencies are declared in the relevant `moon.mod` files.
Notable dependencies include `moonbitlang/async`, `moonbitlang/x`,
`moonbitlang/quickcheck`, `wzzc-dev/window`, `wzzc-dev/moui_skia`,
`wzzc-dev/moui_sun`, `Milky2018/*` graphics/text packages, and small utility
packages such as `mizchi/image`, `mizchi/pixelmatch`, and `mizchi/svg`.

Every dependency this repository resolves declares `Apache-2.0` or `MIT` in its
own manifest, and `wzzc-dev/window` ships a `LICENSE` file alongside that
declaration (verified 2026-10-27 from the unpacked dependency cache,
`.mooncakes/*/*/moon.mod`). The unpacked sub-packages named `*-component`
(`layout-component`, `markdown-component`, `pixelmatch-component`,
`svg-component`, `zlib-component`, `brotli-component`) declare no license field;
their parent packages do.

## Skia

`moui_skia` contains MoonBit and native stub/binding code for integrating with
the Skia Graphics Library. The repository does not vendor Skia source code;
real Skia builds are supplied by local or CI setup scripts and remain governed
by Skia's upstream license terms.

The supplied artifact is a source-derived package tree, and every Skia header
begins with "Use of this source code is governed by a BSD-style license that can
be found in the LICENSE file" — but **the delivered package has no top-level
`LICENSE` file**, so the exact BSD variant cannot be confirmed from the artifact
alone. Treat "Skia is BSD-3-Clause" as upstream knowledge requiring
confirmation against `skia/LICENSE`, not as evidence this repo holds.

What a macOS link actually pulls is determined by `moui_skia/build.js`, not by
what the package happens to contain. With paragraph text and Metal GPU enabled
(static mode), the darwin link line names eight archives
(`macosLibraryFlags` + `skiaParagraphLinkLibraryNames`):

```
libskia_ganesh_ext.a  libskia.a  libskparagraph.a  libskshaper.a
libskunicode_icu.a    libskunicode_core.a  libharfbuzz.a  libicu.a
```

plus `-lc++` and the Apple system frameworks (CoreFoundation, CoreGraphics,
CoreText, ImageIO, ApplicationServices, and — when GPU is enabled — Metal,
QuartzCore, CoreVideo, IOSurface, AppKit).

The artifact a product build resolves is locked by
`moui_skia/skia-provider-lock.json` (`default_provider: "release"` — the
`wzzc-dev/skia` fork at tag `dev-6d73578a36`, commit
`6d73578a36506d10bc044e920cc71037982e481d`). That macOS arm64 static package
*ships* 29 archives in `out/Release-macos-arm64/`, adding Dawn, Adobe DNG SDK,
piex, expat, Wuffs, libjpeg(12/16), libpng, libwebp, zlib, skcms, skottie, sksg
and svg — none of which appear on that link line, so their presence in the cache
must not be read as presence in a MoUI binary.

The two provider paths do not agree on *which* Skia that is. Unless
`--skia-provider` is passed explicitly, `scripts/macos-skia-renderer-smoke.sh`
chooses `jetbrains` with tag `m148-8967a2e80c` (`:120`, `:362-367`), and the
manual workflow that runs it
(`.github/workflows/moui-macos-app-real-skia-manual.yml:28-40`) passes only a log
path — so the macOS real-Skia evidence can be produced from a different upstream
build than the one a product binary links against. Checked 2026-10-27: the two
cached packages have identical 29-archive name sets and identical license-text
paths (`diff` of both, no content comparison), so this is a
provider/evidence-consistency defect, not a change in what gets linked or in the
notice obligations below.

License texts **are** delivered for seven directories: `libpng`, `zlib`,
`harfbuzz` ("Old MIT"), `libwebp` (BSD with the third "Neither the name"
clause), `angle2` (same BSD form), `swiftshader` (Apache-2.0), and
`freetype/docs/FTL.TXT` with its alternative grant `GPLv2.TXT` alongside it. A
`vulkan` BSD-style notice ships under `include/third_party/`.

Against the eight archives the darwin line names, **exactly one ships its license
text: HarfBuzz.** Skia itself, `skparagraph`, `skshaper`, `skunicode_icu`,
`skunicode_core` and — the significant one — **ICU have no license text in the
artifact**: `third_party/icu/` contains only `SkLoadICU.h`. FreeType ships both
its grants but is not linked on Apple platforms at all (`-lfreetype` is appended
only in the Linux branch, `moui_skia/build.js:777`), so its FTL-versus-GPLv2
choice is a Linux-route obligation, not a macOS one.

## WGPU and WebGPU

The native WGPU diagnostic route uses `Milky2018/wgpu_mbt` (declares
`Apache-2.0`) and may use platform-specific `wgpu-native` dynamic libraries or
metadata when those diagnostic entrypoints are built or packaged. The Web route
uses browser WebGPU host imports on `wasm-gc`. MoUI does not vendor
`wgpu-native` or browser WebGPU implementations; any downloaded or packaged
WGPU runtime artifacts stay under their upstream license terms and should be
documented when added to a release or platform package.

The locally cached `wgpu-native` artifact is `v27.0.4.0`
(`.local_deps/wgpu-native/v27.0.4.0/wgpu-macos-aarch64-release/`, tag recorded
in `wgpu-native-meta/wgpu-native-git-tag`). That artifact carries `libwgpu_native.dylib`
and headers with **no `LICENSE` file**, so its upstream MPL-2.0 terms are not
confirmable from disk. Note also that this repo pins two different `wgpu-native`
releases for Windows: `scripts/windows/setup_wgpu_native.ps1` uses `v29.0.1.1`
while `build_windows_msvc.ps1` and `package_windows_app_msvc.ps1` use
`v27.0.4.0`. That is a version-consistency defect independent of licensing, but
it makes "which wgpu-native ships" unanswerable from the scripts alone.

## License Motive Conclusion (plan `no-third-party-gpu-route`, L0.3)

Everything this repository can confirm locally is permissive: the MoonBit
dependency graph is Apache-2.0/MIT, and the license texts the Skia package
delivers are BSD-family, MIT-family, Zlib, libpng, and FTL. FreeType's `GPLv2.TXT`
is the *alternative* to the FTL grant, not an inherited obligation for a project
that links the library under FTL. No copyleft term that would block a
distributable MoUI product was identified.

The residual license exposure is therefore **notice completeness, not IP
blocking**: the darwin link line names eight archives and the delivered artifact
carries text for one of them (HarfBuzz), with no Skia root `LICENSE` and no ICU
terms at all. The action that follows is to collect and ship the missing notices,
not to replace the engine — and because the release provider this repo resolves
is `wzzc-dev/skia`, an artifact this project builds and publishes itself, adding
the root Skia `LICENSE` to the packaged artifact is a fix this repo controls
rather than one it has to wait on an upstream vendor for. Per L0.3's own rule,
"license / IP chain" is struck
from the record as a motive for the no-third-party GPU route; the items still
requiring upstream confirmation — Skia's exact BSD variant, ICU's terms,
`wgpu-native`'s MPL-2.0 text, and what each of the 21 unlisted archives would
obligate if a future route ever links them — are marked NOT CONFIRMED LOCALLY
above because this environment has no network access to
`skia.googlesource.com`, `github.com/gfx-rs/wgpu-native`, or the Unicode terms.

## Window Backend

The `wzzc-dev/window` dependency is used for platform windowing and host
integration. When the local `window/` workspace is enabled for development, its
own `LICENSE` file applies to that package.

## Generated Files and Test Assets

Generated MoonBit interface files such as `pkg.generated.mbti` are produced by
`moon info` and committed where they document public API shape. Screenshots and
local smoke artifacts are used only as project evidence; generated logs,
manifests, build output, caches, and temporary artifacts under ignored paths
such as `artifacts/`, `_build/`, `.mooncakes/`, `.skia-cache/`, and `dist/`
should not be committed.

## Contributor Rule

When adding copied code, generated code, fixtures, screenshots, fonts, sample
documents, or bindings to another library, document the source project, link,
license, and scope of use in this file or in a package-local notice before
submitting the change.
