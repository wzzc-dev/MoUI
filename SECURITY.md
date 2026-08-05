# Security Policy

## Supported versions

MoUI is maintained by a single maintainer and does **not** offer long-term
support (LTS) branches. Only the latest commit on the `main` branch receives
security fixes.

| Version | Supported |
|---------|-----------|
| `main` (latest) | ✅ |
| Tagged releases | Best-effort, via backport to `main` |
| Older branches | ❌ |

If you depend on a pinned commit or tag, rebase onto the latest `main` to
receive fixes.

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities through GitHub's private vulnerability reporting:

1. Go to the [MoUI repository](https://github.com/wzzc-dev/MoUI).
2. Click the **Security** tab.
3. Select **Report a vulnerability** to open a private advisory.

This keeps the report visible only to repository maintainers until a fix is
coordinated. If GitHub private reporting is unavailable, contact the
maintainer through the email on their GitHub profile.

### What to include

- A description of the vulnerability and its impact.
- The affected component (see [Scope](#scope)).
- Steps to reproduce or a proof of concept.
- The MoonBit toolchain version (`moon version`) and the relevant platform /
  renderer combination.
- Suggested fix, if any.

## Response expectations

- **Acknowledgement:** within 72 hours of the report.
- **Initial assessment:** within 7 days, including severity triage.
- **Fix timeline:** depends on severity and the maintainer's availability.
  Critical issues in native FFI or host-import paths are prioritized.

The maintainer is a single person. If a report goes unanswered for an
extended period, follow the [continuity process](GOVERNANCE.md#project-continuity-and-handover)
in `GOVERNANCE.md`.

## Disclosure

- Fixes are published as normal commits to `main` once a fix is ready.
- The reporter is credited in the advisory unless they prefer to remain
  anonymous.
- Coordinated disclosure: the reporter is notified before a fix is made
  public where practical.

## Scope

MoUI ships native FFI, a Web host-import surface, and third-party
dependencies. In-scope components:

- **Native FFI bindings** — `moui_skia` (Skia bindings), native WGPU
  bindings, and any `extern "c"` surface. Memory safety, FFI boundary
  handling, and renderer resource leaks are in scope.
- **Web host imports** — the `web_wasm` host surface, browser WebGPU adapter,
  and any `extern "wasm"` / JS interop. Sandboxing, origin handling, and
  untrusted input handling are in scope.
- **Host services** — `moui/backend` contracts and platform backends:
  clipboard, file dialogs, WebView, text input, drag/drop. Untrusted input
  from these services is in scope.
- **Runtime** — event dispatch, text input, and any path that processes
  untrusted document content (e.g. rich text, markdown) is in scope.
- **Third-party dependencies** — `wzzc-dev/window`, `wzzc-dev/moui_skia`,
  and mooncakes. Vulnerabilities introduced upstream should be reported here
  so the MoUI pin can be updated; report the upstream issue to the
  dependency's maintainer as well.

### Out of scope

- Bugs that require already-compromised native code execution to exploit.
- Rendering correctness issues that are not security-relevant (use a normal
  bug report).
- Performance issues (use a normal issue).
- Vulnerabilities in a fork that has diverged from `main`.

## Hardening notes for integrators

MoUI is a framework; the security posture of an app built on MoUI depends on
how the app wires host services and renders untrusted content. Integrators
should:

- Treat rich text, markdown, and WebView content as untrusted input.
- Review the host-service contracts in `moui/backend` before enabling
  clipboard, file dialogs, or WebView in untrusted contexts.
- Keep native FFI pins (`moui_skia`, Skia version) current with `main`.
