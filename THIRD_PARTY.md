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

## Skia

`moui_skia` contains MoonBit and native stub/binding code for integrating with
the Skia Graphics Library. The repository does not vendor Skia source code;
real Skia builds are supplied by local or CI setup scripts and remain governed
by Skia's upstream license terms.

## WGPU and WebGPU

The native WGPU diagnostic route uses `Milky2018/wgpu_mbt` and may use
platform-specific `wgpu-native` dynamic libraries or metadata when those
diagnostic entrypoints are built or packaged. The Web route uses browser
WebGPU host imports on `wasm-gc`. MoUI does not vendor `wgpu-native` or browser
WebGPU implementations; any downloaded or packaged WGPU runtime artifacts stay
under their upstream license terms and should be documented when added to a
release or platform package.

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
