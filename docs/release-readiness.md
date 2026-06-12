# Release Readiness

This page describes the current preview-release validation policy. It is a
checklist for fresh release work, not a permanent evidence ledger.

## Baseline

MoUI is ready for a preview handoff when the repository can demonstrate:

- The public `View[Msg]` / internal runtime tree split still matches
  `docs/architecture.md`, `AGENTS.md`, and the repo-local skills.
- Daily package validation passes on the current checkout.
- Public API changes have reviewed `moon info` output and the API surface guard
  still passes.
- Renderer capability status is synchronized between code, tests, docs, and
  Showcase where visible.
- Platform behavior is scoped to the host that actually ran it.
- Release notes cite a CI run or smoke log instead of checked-in generated
  manifests.

## Required Gates

| Gate | Required Evidence | Command |
| --- | --- | --- |
| daily baseline | Bounded package checks, guidance consistency, API surface guardrails, renderer/provider static checks, Showcase and Markdown Editor app tests, and Web wasm-gc builds pass. Design Systems is addon diagnostic coverage through `--theme-diagnostics`. | `sh scripts/dev-check.sh` |
| Public API audit | Generated interfaces reviewed after public API changes and package budgets/boundary tokens still pass. | `moon info`, then `node scripts/validate-api-surface.mjs` |
| Focused conformance | Input/focus, layout, render, platform service, and text slices pass at their owning layer. | `sh scripts/conformance-check.sh --input`, `--layout`, `--render`, `--platform-services`, `--text`, `--text-diagnostic` |
| Renderer sync | Native Skia and WebGPU mainline capability docs, tests, and visible Showcase coverage agree. Native WGPU remains explicit diagnostic coverage. | `moon test moui/render --target native`, `moon test moui/render/skia --target native`, `moon test moui/render/webgpu_adapter --target wasm-gc`, plus Showcase Web build |
| manual smoke | Real renderer/browser/platform behavior has fresh pass/fail logs from the matching host when the release note claims it. | `scripts/macos-skia-renderer-smoke.sh`, `sh scripts/ci-web-runtime-presentation.sh`, current-platform example first-frame runs |
| Guidance freshness | Docs, `AGENTS.md`, and repo-local skills agree after validation, package, renderer, platform, or example changes. | `node scripts/validate-guidance-consistency.mjs` |

## Smoke Boundaries

Manual smoke logs may demonstrate real-Skia linking, renderer pixel output,
async image second-frame behavior, optional SkParagraph text behavior, WebGPU
browser-session startup, nonblank canvas output, representative input delivery,
or current-platform first-frame presentation.

Those logs are runtime evidence logs for a named host/session. They do not
become a checked-in manifest and they do not automatically promote unrelated
platforms or renderers.

## Artifact Policy

`artifacts/` is ignored. Generated JSON, screenshots, browser logs, and smoke
logs under that directory are disposable local or CI artifacts. Release notes
should cite the CI run, uploaded artifact name, or local smoke log path that was
actually inspected.
