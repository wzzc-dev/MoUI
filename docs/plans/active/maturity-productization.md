# Plan: Productization correctness — package, verify, mobile evidence

- **Status**: active
- **Goal**: Make `moui package` produce honest release artifacts, make
  `moui verify` provenance-aware, and record physical-device evidence for the
  committed mobile routes.
- **Non-goals**: full notarization/installer/auto-update depth (Phase 2),
  cross-compiling unsupported host/target pairs, claiming device evidence that
  was not recorded.

## Packaging

1. `moui package` defaults to a release build; `--debug` keeps the old
   behavior. The release flag flows through `desktop_build_once` and
   `desktop_artifact_path`.
2. macOS bundle reads `moui.project.json` `bundleId` (override with
   `--bundle-id`), copies configured resources/icons, writes `PkgInfo`, and
   optionally signs with `--sign-identity`.
3. Windows portable folder copies `icudtl.dat` and configured WGPU native
   libraries; records WebView2 as an external runtime dependency; output path
   matches the documented `dist/windows`.
4. Linux gains a real `native-bundle` packager: binary, `run.sh`, `.desktop`,
   icon, `moui-package.json`, optional `.tar.gz`.
5. Web packaging writes `moui-package.json` metadata and works in a generated
   project without a repo-local `scripts/` checkout.
6. `moui package` fails fast on a host/target mismatch unless `--allow-cross`
   is explicit.
7. Add `moui_cli/package_build_wbtest.mbt` and a CI `package-smoke` job that
   runs the real CLI on each host.

## Verify

- Android launch uses `android.applicationId`, not the mobile-config `id`.
- `fallbackSkia` comes from build metadata; unknown provenance fails closed.
- Probe timeouts are honored; `moui run --verify` also writes a manifest.
- Usage text and artifact lookup agree on the same path.

## Mobile release and evidence

- `--release` reaches Android (`assembleRelease`, optional AAB), iOS (`-O2`),
  and HarmonyOS (existing signing injection).
- Signing configuration comes from `moui.mobile.json`/environment, never from
  committed secrets.
- Record one physical Android and one physical iOS `build + verify` run in
  `checks/platforms/*.json`; without it, keep the existing limitation text.
- Add `docs/mobile-device-evidence.md` and a `--prepare-only` CI check for all
  three mobile targets.

## Acceptance

- [ ] `moui package` produces a release artifact on macOS, Windows, Linux, and
      Web; manifests validate.
- [ ] Linux packaging is no longer rejected.
- [ ] macOS/Windows bundles include the project identity and runtime
      dependencies.
- [ ] `moui verify` uses the Android application id, reports real provenance,
      and honors timeouts.
- [ ] Physical-device evidence is recorded or the limitation is explicit.
- [ ] `sh scripts/check.sh --profile pr` and packaging smoke pass.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-10 | Packaging defaults to release; `--debug` is the explicit opt-out |
| 2026-11-10 | Linux Phase 1 ships a native bundle, not AppImage/deb |
| 2026-11-10 | No mobile claim changes without matching-device evidence |

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Plan created; implementation starts with the release flag and bundle id. |
| 2026-11-10 | `moui package` now defaults to release (`--debug` opt-out), reads the project bundle id, packs a Linux native bundle, and guards host/target mismatches. `moui verify` records build provenance from `build-manifest.json` and uses `android.applicationId`. CLI tests pass (198). |
| 2026-11-10 | Packaging depth: macOS copies `--icon` + writes `PkgInfo`/`CFBundleIconFile`; Windows copies `icudtl.dat` from the Skia release cache; Web writes `moui-package.json`. Whitebox packaging tests cover macOS/Linux/Windows and the CLI suite is at 206 tests. |
| 2026-11-10 | Mobile release plumbing: `--release` now selects Android `assembleRelease` (with unsigned fallback) and iOS `-O2`; HarmonyOS keeps the project build-profile variant. Signing/store packaging remains host-required. |
| 2026-11-10 | Verify hardening: probes wait a bounded window before dumping logs, `moui run --verify` writes the same provenance-aware manifest, and the usage text matches the `<app>.<ext>` artifact layout. |
| 2026-11-10 | Web standalone packaging: when the repo-local `package-web-app.mjs` is absent, the CLI builds release wasm and writes its own flat bundle (index/runtime/wasm/module-path rewrite + `moui-package.json`). A whitebox test covers generated-project layout. |
