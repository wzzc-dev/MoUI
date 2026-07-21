# Plan: Window-only mobile — remove moui_shell + Embedding API v1

- **Status**: active  
- **Goal**: 移动端 **唯一** lifecycle / surface / 输入路径为 `wzzc-dev/window`（winit 形：EventLoop + ApplicationHandler + HostCmd + raw handles）。**不保留** `moui_shell` 与 **Embedding API v1** 作为产品或过渡主路径；最终树中删除或迁出相关代码、文档、CI、invariants。  
- **Supersedes (policy)**:  
  - `docs/plans/active/window-mobile-winit-moui-cutover.md` 中「shell 可过渡打包 / Embedding 可选服务通道」条款  
  - ADR 0010（Managed Mobile Shells + Embedding ABI）对 **新主路径** 的约束 → 需 **RFC + 新 ADR supersede**  
- **Related**: `window-cross-platform-parity.md`, `docs/window-hosted-moui.md`, `window/docs/mobile-hosted-backend.md`, ADR 0005/0006/0010/0011  
- **Non-goal (explicit)**: 在 window 内复刻 Embedding v1 / PlatformView 插件体系 / `shell.json` 产品模型  

## Architecture (target end-state)

```text
┌──────────────────────────────────────────────────────────┐
│  OS host (thin template only)                            │
│  window/<platform>/template/{android,ios,harmonyos}                │
│  Activity / UIApplication / Ability + native HostCmd     │
└────────────────────────┬─────────────────────────────────┘
                         │ HostCmd / C queue / JNI|ObjC|NAPI
                         ▼
┌──────────────────────────────────────────────────────────┐
│  wzzc-dev/window/{android,ios,harmonyos}  ≈ winit        │
│  EventLoop · ApplicationHandler · Window · handles       │
│  soft present MVP · basic pointer/text · generation      │
└────────────────────────┬─────────────────────────────────┘
                         │ ApplicationHandler callbacks
                         ▼
┌──────────────────────────────────────────────────────────┐
│  MoUI backend (window-hosted primary path)               │
│  RuntimeSession + Skia/presenter from raw handle         │
│  IME/clipboard/a11y: platform-native services on window  │
│  generation — NOT EmbedderHostChannel / Embedding ABI    │
└──────────────────────────────────────────────────────────┘
```

| Layer | Owns | Must not exist |
|-------|------|----------------|
| **window** | OS entry, surface epoch, HostCmd, handles, basic input, soft present | Embedding export table, shell.json, plugin ABI |
| **MoUI backend** | TEA/session, renderer, window ApplicationHandler | `install_embedding`, `embedding_adapter`, inject/attach surface |
| **templates** | Gradle/Xcode/Hvigor app shells as **window packaging**, not `moui_shell/*` | Managed eject product, shell SDK version lock |
| **moui_shell** | **Deleted** after cutover (or `archive/` + one release deprecation only if RFC requires) | Runtime dependency of MoUI or window |
| **Embedding API v1** | **Deleted** (`moui_embedding_get_api_v1`, fixed export mirrors, Host Wire v1 as shell product) | Public mobile entry contract |

**winit reference**: no shell SDK, no embedding C API, no dual inject path. MoUI is a **consumer** of window like an app using winit.

## Why this supersedes the soft cutover

Previous plan allowed:

1. Temporary APK shell packaging via `moui_shell`  
2. Embedding as optional IME/clipboard channel  

User directive (2026-07-21): **不保留** `moui_shell` 与 Embedding API v1。  
Therefore:

- Packaging = `window/{android,ios,harmonyos}/template` + `moui_cli` (or build scripts) that **never** stage `moui_shell`  
- Host services (IME/clipboard/a11y) = **new** thin platform bridges owned by backend/window generation, not `EmbedderHostChannel` + Embedding table  
- No dual-stack period longer than a single PR series with feature-flag; default is window-only  

## Governance (must land early)

Breaking hard invariants today:

| Current invariant / ADR | Conflict | Required action |
|-------------------------|----------|-----------------|
| ADR 0010 managed shells + Embedding ABI | Shell is canonical mobile product | RFC + **ADR 00xx supersede 0010**: window-hosted is canonical |
| ADR 0011 `runtime_partial` + managed shell evidence | Evidence scripts target shell | Redefine readiness on window-hosted VM evidence |
| `docs/invariants.md` R3, M1–M6, M9 | Require shell_embedding exports, install_embedding, moui_shell ownership | RFC rewrite: window ApplicationHandler + template ownership |
| `memories/repo/mobile-mainline.md` | Shell SDK mainline | Rewrite after ADR lands |
| CI shell evidence workflows | `*-shell-runtime-evidence.yml` | Path-trigger retire → window-hosted VM smoke |
| `moui_cli` shell generate/eject | Product entry | Retarget to window templates or remove eject product |

**Rule**: do not mass-delete shell code before RFC/ADR + replacement packaging path exists; do not leave shell as silent default.

## Workstreams

### WS0 — Policy freeze (docs first)

- [x] Open RFC under `docs/` / GOVERNANCE process: **window-only mobile; remove moui_shell + Embedding v1** (ADR 0015)  
- [x] Draft ADR **superseding 0010** (and amending 0005/0006 host-channel ownership as needed)  
- [x] Rewrite active plan linkage: this file is policy SoT; cutover plan becomes implementation detail  
- [x] Update `docs/window-hosted-moui.md`: remove “legacy managed shell remains” language  
- [x] Mark `docs/embedding-api-v1.md` as **deprecated → removal** with sunset checklist  

### WS1 — window mobile complete (MoUI-ready, no shell)

Same M1–M4 as cutover plan, packaging **only** from `window/{android,ios,harmonyos}/template`:

- [ ] Android: HostCmd + ANativeWindow + soft present + AVD evidence  
- [ ] iOS: HostCmd + UIView handle + soft present + Simulator evidence  
- [ ] HarmonyOS: HostCmd + XComponent path + host-sim green; HVD if tooling  
- [ ] Smoke: `window/scripts/check_{android,ios,harmonyos}_hosted_smoke.sh` green  
- [ ] **No** `moui_shell` import or path in window module  

### WS2 — MoUI primary path = window ApplicationHandler

- [ ] Promote `moui/backend/{android,ios,harmonyos}/window_hosted.mbt` to **only** public mobile install path  
- [ ] Replace `install_embedding(...)` with e.g. `run_window_hosted(...)` / `install_window_app(...)`  
- [ ] Delete or quarantine: `embedding_adapter.mbt`, `embedding_install.mbt`, `*_skia` entries that call install_embedding  
- [ ] Examples: counter/showcase mobile entries only `*_window_hosted`  
- [ ] Host services: design **WindowHostServices** (IME/clipboard/a11y) without Embedding ABI; MVP may stub with explicit “unsupported” until native bridges land  
- [ ] `moon test moui/backend/{android,ios,harmonyos}` host-sim green without shell types  

### WS3 — Packaging & CLI without moui_shell

- [ ] `scripts/build-window-hosted-android-apk.sh` (and ios/harmonyos peers) produce installable artifacts from window templates + MoUI app package  
- [ ] `moui_cli`: remove or hard-fail `shell` / `eject` product commands once replacements exist; doctor checks require window-hosted entry  
- [ ] Stop generating `embedding_exports.mbt` / fixed `moui_embedding_*` export mirrors  
- [ ] Version lock: apps depend on `wzzc-dev/window` + `wzzc-dev/moui`, **not** `wzzc-dev/moui_shell`  

### WS4 — Remove moui_shell + Embedding from tree

Order (after WS1–WS3 green on at least one platform VM):

1. [ ] CI: disable shell evidence jobs; enable window-hosted host-sim + path-triggered VM  
2. [ ] Delete example deps and docs that teach shell  
3. [ ] Remove `moui_shell/` package (or move to `archive/moui_shell` one release if RFC mandates deprecation window)  
4. [ ] Remove Embedding v1 sources, validators, export lists, Host Wire shell product docs  
5. [ ] Update `docs/invariants.md` M*/R3, validators (`validate-harness-invariants`, guidance consistency)  
6. [ ] Update `docs/platform-readiness-declaration.md`, `memories/repo/mobile-mainline.md`, INDEX  
7. [ ] Static trio green: maintenance-baseline, api-surface, guidance-consistency  

### WS5 — VM completion bar (definition of done)

| Platform | Pass criteria |
|----------|----------------|
| Android AVD | Install window-hosted APK; launch; no crash; surface/first frame or log assert; **no** Embedding symbols required |
| iOS Simulator | Install window-hosted app; same |
| HarmonyOS | HVD same **or** explicit tooling gap documented + host-sim green (not fake device pass) |
| Codebase | No runtime dep on `moui_shell`; no public Embedding API v1; no dual inject path |

## Sequencing

```text
WS0 RFC/ADR (blocks mass delete)
   │
   ├─► WS1 window M1–M4 + templates only
   ├─► WS2 MoUI window_hosted primary
   └─► WS3 packaging/CLI retarget
          │
          ▼
       WS5 VM evidence (at least Android AVD + iOS Sim)
          │
          ▼
       WS4 delete moui_shell + Embedding + rewrite invariants
```

## Validation (minimal loops)

| Change | Command |
|--------|---------|
| Policy/docs | `node scripts/validate-guidance-consistency.mjs` |
| window mobile | `cd window && bash scripts/check_*_hosted_smoke.sh` |
| MoUI backends | `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/{android,ios,harmonyos} --target native` |
| Host-sim suite | `sh scripts/window-hosted-hostsim-smoke.sh` |
| APK | `JAVA_HOME=… MOONBIT_NEW_NATIVE=0 bash scripts/build-window-hosted-android-apk.sh` |
| Full static | maintenance-baseline + api-surface + guidance-consistency |
| After delete | `rg moui_shell` / `rg moui_embedding_get_api_v1` must be empty outside archive/changelog |

## Risk register

| Risk | Mitigation |
|------|------------|
| IME/clipboard/a11y regress when Embedding dies | MVP stubs + phased WindowHostServices; do not block lifecycle cutover |
| Showcase evidence currently shell-based | Accept readiness dip until window-hosted evidence; document honestly |
| Large CLI/validator surface | Delete generators after replacement; keep validators failing closed |
| HarmonyOS tooling gap | host-sim + explicit HVD skip; no shell fallback |

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-21 | User: **不保留** moui_shell 与 Embedding API v1。 |
| 2026-07-21 | Target architecture = window-only (winit-shaped); shell/Embedding are removal targets, not transitional product. |
| 2026-07-21 | Deletion gated on RFC/ADR superseding 0010 + at least one platform VM pass on window-hosted path. |
| 2026-07-21 | Host services reimplemented outside Embedding; not “optional Embedding channel”. |

## Progress

| Date | Note |
|------|------|
| 2026-07-21 | Plan opened. Phase1 window_hosted bridges already exist; packaging/VM and shell removal not started. Previous cutover plan still has soft language — policy SoT is **this** file. |
| 2026-07-21 | **ADR 0015** accepted; ADR 0010 superseded; 0011 amended; embedding-api-v1 deprecated banner. WS0 policy freeze in progress (invariants rewrite still open). |
| 2026-07-21 | Android window-hosted APK packaging fixed (getentropy compat, no host simdutf, Java HostedActivity); **AVD install+launch passed** on moui_api34. iOS sim packaging script added. |
| 2026-07-21 | iOS Simulator packaging linked (getentropy compat, UIKit host, skia view glue); **sim install+launch passed** on iPhone 17. |
| 2026-07-21 | HarmonyOS: hosted smoke green; HVD/HAP packaging still tooling gap (`hdc` may be absent). Backend `install_embedding` marked deprecated (ADR 0015). Shell tree not deleted yet (invariants/CLI gate). |
| 2026-07-21 | Invariants R3/M* rewritten for window-hosted; harness validator + moui_cli doctor retargeted; host harness OK. `moui_shell` tree still present pending WS4 delete after CI/CLI generator retirement. |
| 2026-07-21 | **Deleted `moui_shell` tree**; transport moved to `host_session_transport`; backends/examples on window-hosted; shell CI disabled; HOS M5 validator retargeted. HVD HAP install still not device-passed (empty hdc). |
| 2026-07-21 | **Real-run re-verification (window-hosted counter):** Android AVD moui_api34 — install+launch OK (pid 4140, HostedActivity topResumed, Displayed +814ms, `loaded native library=window_android_app`). iOS Simulator iPhone 17 — install+launch OK (pid 76241 under launchctl, bundle dev.wzzc.window.hosted.counter). HarmonyOS — host-sim green, HAP packaging verified (libwindow_harmonyos_hosted.so 7.2MB, EntryAbility/mainAbility, api target 21); `hdc list targets: [Empty]` — DevEco Studio HVD is GUI-only Qt app with no local system-image/AVD; **tooling gap recorded per ADR 0015**, fail-closed (no fake device pass). Evidence: artifacts/window-hosted-{android/avd-evidence.md, ios/sim-evidence.md, harmonyos/status.md}. WS5 Android+iOS pass; HarmonyOS pending DevEco IDE-created HVD or physical device. |

## References

- winit (lifecycle model only)  
- `docs/plans/active/window-mobile-winit-moui-cutover.md` (implementation history; policy superseded)  
- `docs/decisions/0010-managed-mobile-shells-and-runtime-abi.md` (to supersede)  
- `docs/invariants.md` R3, M1–M9  
- `docs/embedding-api-v1.md`  
- `window/docs/mobile-hosted-backend.md`  
