# 0015: Window-only mobile — retire moui_shell and Embedding API v1

- **Date**: 2026-07-21
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex); user directive
- **Related**: ADR 0010 (superseded for mobile product path), ADR 0005, ADR 0006,
  ADR 0011, `docs/plans/active/window-only-mobile-no-shell-embedding.md`,
  `docs/window-hosted-moui.md`, `window/docs/mobile-hosted-backend.md`,
  [winit](https://github.com/rust-windowing/winit)

## Context

ADR 0010 established managed mobile shells (`moui_shell`) and a fixed Embedding
API v1 (`moui_embedding_get_api_v1`) as the canonical way apps reach the MoUI
runtime on Android, iOS, and HarmonyOS. That model solved early packaging and
ABI ownership, but it diverged from the desktop/Web stack and from the
industry pattern embodied by winit:

- Desktop/Web already use `wzzc-dev/window` (EventLoop / ApplicationHandler /
  raw handles).
- Mobile lifecycle, surface epochs, and input were owned by shell + Embedding
  inject (`attach_surface` / dual paths), not by the same window HostCmd model.
- Agents and product work paid a permanent dual-stack tax: shell evidence,
  export mirrors, `install_embedding`, and window-hosted bridges in parallel.
- User policy (2026-07-21): **do not retain** `moui_shell` or Embedding API v1.

Invariants R3 and M1–M9 currently hard-code shell ownership. They must be
rewritten as part of migration, not treated as permanent product law.

## Decision

1. **Canonical mobile host path** is `wzzc-dev/window` for Android, iOS, and
   HarmonyOS: OS thin template → HostCmd queue → EventLoop →
   `ApplicationHandler` → MoUI backend session/renderer. Behavior is aligned
   with winit (lifecycle + handles + basic input), not with an embedder C ABI.

2. **`moui_shell` is not a product dependency.** New work must not import it,
   stage it, or teach it. After cutover evidence (WS1–WS3 + at least one VM
   pass), remove the package from the main tree (or archive under explicit
   deprecation only if a release train requires one sunset tag). Packaging
   lives under `window/<platform>/template` plus build scripts / CLI retargeted
   to those templates.

3. **Embedding API v1 is retired as a public mobile contract.** No
   `moui_embedding_get_api_v1`, fixed export-mirror tables, or
   `install_embedding` as the app entry. Surface creation is only
   `create_window` / generation under HostCmd readiness. Dual-stack
   inject+HostCmd for the same surface is forbidden.

4. **MoUI mobile backends** expose a window-hosted install/run API (e.g.
   `*_window_hosted` / `run_window_hosted`) as the only supported entry for
   counter, showcase, and external apps. Legacy `embedding_adapter` /
   `embedding_install` are deleted once replacements work; they are not kept as
   “optional service channels.”

5. **Host services** (IME, clipboard, accessibility, PlatformView-class
   features) are redesigned as generation-scoped **window host services**
   owned by MoUI backend + platform native bridges on the window template.
   ADR 0005’s goal (shared channel ownership in `moui/backend/host`) may
   survive **without** Embedding ABI or shell drainers; the wire is not
   Embedding v1. Until bridges land, services may report explicit unsupported
   rather than reintroducing Embedding.

6. **ADR 0010 is superseded** for all new design and acceptance criteria.
   Historical shell evidence remains historical; readiness and CI move to
   window-hosted host-sim and path-triggered VM smoke.

7. **ADR 0011 amendments**: mobile `ready` / `runtime_partial` no longer mean
   “managed shell usable.” They mean **window-hosted host path usable for
   development/demo** with documented evidence class. Do not claim L3/GPU
   seven-gate without matching evidence.

8. **Deletion gate**: bulk removal of `moui_shell` / Embedding sources,
   shell CI, and shell-centric validators requires:
   - this ADR accepted (done);
   - plan WS1–WS3 substantially complete on the cutover path;
   - Android AVD and/or iOS Simulator window-hosted install+launch evidence
     (or honest tooling gap for HarmonyOS only);
   - invariants R3/M* and `moui_cli` doctor rules rewritten so green checks
     enforce window-only, not shell.

## Options Considered

### Option A: Keep shell + Embedding, window as secondary host

- Pros: preserves existing APK/IPA evidence and CLI eject product.
- Cons: permanent dual-stack; contradicts winit alignment and user directive.

### Option B: Window lifecycle, keep Embedding as IME/service ABI only

- Pros: reuses Host Wire / channel code.
- Cons: still ships Embedding product surface; shell packaging often stays;
  user forbade retaining Embedding API v1.

### Option C: Window-only; remove shell and Embedding (chosen)

- Pros: one lifecycle model across platforms; matches winit shape; deletes
  agent/docs confusion; clear ownership.
- Cons: large migration (CLI, validators, IME bridges, readiness docs);
  temporary readiness dip until window-hosted VM evidence exists.

## Rationale

Cross-platform consistency and maintainability outweigh sunk cost in managed
shells. Desktop already proves MoUI on window. Mobile should not be a second
framework. User instruction explicitly rejects transitional retention of
shell/Embedding as product.

## Consequences

- **Easier**: one mental model; window package is the porting surface; fewer
  export-mirror footguns.
- **Harder**: re-home packaging, IME/clipboard/a11y, CLI, CI evidence, and
  invariants before deletion.
- **Migration**: see `docs/plans/active/window-only-mobile-no-shell-embedding.md`.
- **Compatibility**: apps using `install_embedding` / `moui_shell` must move to
  window-hosted entries; no long-term dual public API.

## Agent Notes

- **Session context**: User asked for a goal with **no** retention of
  `moui_shell` or Embedding API v1; window-only mobile cutover.
- **Agent model**: Codex (GPT-based).
- **Key instruction**: 制定目标 — 不保留 moui shell，Embedding API v1 这些东西.
- **Validation**: ADR + plan accepted in-repo; implementation evidence still
  required (host-sim green; VM packaging pending). Do not mark goal complete
  on ADR alone.

## References

- `docs/plans/active/window-only-mobile-no-shell-embedding.md`
- `docs/plans/active/window-mobile-winit-moui-cutover.md` (implementation history;
  shell-retention policy superseded)
- `docs/decisions/0010-managed-mobile-shells-and-runtime-abi.md`
- `docs/invariants.md` (R3, M1–M9 — rewrite in flight)
- `docs/embedding-api-v1.md` (deprecated → removal)
- `moui/backend/{android,ios,harmonyos}/window_hosted.mbt`
