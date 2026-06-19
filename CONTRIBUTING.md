# Contributing to MoUI

MoUI is a multi-platform MoonBit GUI framework. The project is currently
maintained by a single maintainer with AI assistance, and external
contributions are welcome. Pull requests are the primary entry point for
changes.

This guide describes how to set up a local environment, where changes should
land, what a contribution must satisfy before review, and how the review
process works. It complements — and does not repeat — the project-specific
documents listed under [Before you contribute](#before-you-contribute).

## Project posture

- **Single maintainer, AI-assisted.** The maintainer reviews and merges all
  PRs. Review latency may be longer than a staffed project; please be patient.
- **Open to contributions.** Bug fixes, new controls, renderer/backend
  improvements, docs, and tests all belong in PRs. Architecturally sensitive
  changes follow the [RFC process](GOVERNANCE.md#decision-mechanism) in
  `GOVERNANCE.md`.
- **No CLA.** MoUI is Apache-2.0. Contributors certify origin via the
  lightweight [DCO](#developer-certificate-of-origin) below; no Contributor
  License Agreement is required.
- **Scope of support.** Only the `main` branch is supported. There is no LTS
  line. See [SECURITY.md](SECURITY.md) for the security support scope.

## Before you contribute

Read these first; they define the boundaries a contribution must respect:

- [AGENTS.md](AGENTS.md) — repository working rules for any contributor or
  agent. Start here.
- [docs/architecture.md](docs/architecture.md) — package map and runtime
  pipeline (`View[Msg] -> ElementTree -> LayoutTree -> RenderTree ->
  DrawCommand -> renderer`).
- [docs/moui-app-package-boundary.md](docs/moui-app-package-boundary.md) —
  owning-package rules and the Review Checklist used during review.
- [docs/ai-collaboration.md](docs/ai-collaboration.md) — project invariants
  and the recommended contributor/agent workflow.
- [docs/development.md](docs/development.md) — local setup, workspace members,
  and focused development loops.
- [docs/testing.md](docs/testing.md) — daily validation script, focused
  checks, and manual smoke commands.

## Local setup

From the repository root:

```sh
moon update
sh scripts/dev-check.sh
```

`moon update` refreshes registry packages. `dev-check.sh`
is the daily validation gate (dependency guards, guidance consistency,
maintenance baseline ratchets, API surface, `moon check`, core/view/render/
backend package tests, Showcase and Markdown Editor app tests, Web wasm-gc
builds).

Report your MoonBit toolchain version with any issue or PR:

```sh
moon version
moon info   # for the relevant package, when reporting API-surface issues
```

## Where changes should land

The owning-package rules are authoritative in
[docs/moui-app-package-boundary.md](docs/moui-app-package-boundary.md). The
short version:

- **`moui/core`** — platform-neutral contracts, opaque `View`, typed events,
  `Program`/`Effect`/`Subscription`, geometry, draw, semantics, text contract,
  neutral theme token surface. Do **not** add concrete controls, runtime
  implementation, or design-system brand content here.
- **`moui/views`** — public view constructors and concrete control behavior
  via `@core.View::node`. New controls go here, including the app-facing
  constructor and any private `*_control`/`*_layout`/`*_surface` helper.
- **`moui/runtime`** — runtime lifecycle, element/layout/render tree
  execution, effects, subscriptions, diagnostics.
- **`moui/backend/host`** — host service contracts; concrete platform
  behavior in the platform backend packages.
- **`moui/render/*`** — renderer facade and concrete renderers (Skia, WGPU,
  WebGPU adapter).
- **`examples/*/app`** — shared app logic; platform entrypoints stay thin.
- **`moui_theme/*`** — design-system addons only; not a default app dependency.

### Architectural invariants

These are non-negotiable. Cross-reference
[docs/ai-collaboration.md](docs/ai-collaboration.md) for the full list.

- Public view constructors return opaque `@moui.View[Msg]`; concrete behavior
  lives in `moui/views` via `@core.View::node`.
- The runtime pipeline stays `View[Msg] -> ElementTree -> LayoutTree ->
  RenderTree -> DrawCommand -> renderer`.
- Do **not** add new `core` enum variants, primitive constructors, or runtime
  lowering arms to support a new control. New controls are expressed in
  `moui/views`.
- Do **not** let ordinary app packages (`examples/*/app`) depend on
  `moui/runtime`, `moui/render/*`, or platform backends. They default to
  `wzzc-dev/moui` and `wzzc-dev/moui/views`.
- Renderer status (mainline / diagnostic) must stay synchronized across code,
  tests, docs, and Showcase. Native WGPU is diagnostic; native Skia is the
  mainline.

## Pull request requirements

Every PR should:

1. **Stay focused.** One logical change per PR. Broad churn is harder to
   review and more likely to be rejected.
2. **Run `sh scripts/dev-check.sh`** locally and ensure it passes. If your
   change touches `moui_theme` or `examples/design_systems`, also run
   `sh scripts/dev-check.sh --theme-diagnostics`.
3. **Update the API surface** when public API changes. Regenerate
   `pkg.generated.mbti` and confirm `node scripts/validate-api-surface.mjs`
   passes. The maintenance baseline tracks `pub(all)` counts and root facade
   forwarding counts; if your change moves those numbers, update the ratchet
   budget in the same PR.
4. **Keep docs and guidance in sync.** If your change affects workflow,
   package layout, examples, or text/rendering boundaries, update `docs/`,
   `AGENTS.md`, and the relevant files under `skills/`. The guidance
   consistency guard checks these surfaces.
5. **Do not commit `artifacts/`.** Generated logs, screenshots, manifests, and
   benchmark scaffolds are disposable local or CI evidence. Release notes cite
   the CI run or smoke log instead.
6. **Respect the maintenance baseline.** If a change would grow a tracked
   large file or ratchet counter past its `max`, refactor to stay within the
   budget rather than bumping `max`, or justify the exception in the PR.

### Manual smoke

Automated tests cover the bounded daily baseline. Real platform, browser, or
renderer claims require the smallest matching manual smoke — see
[docs/testing.md](docs/testing.md) and `AGENTS.md`. Cite the smoke log in the
PR description when the change touches rendering, native FFI, or host
behavior.

## Commit and PR style

- Use [Conventional Commits](https://www.conventionalcommits.org/) format:
  `type(scope): subject`. Examples from the project history:
  - `feat(views): outline button uses surface tint, no foreground shift`
  - `fix(views): use lg shadow for floating layers in minimal theme`
  - `refactor(theme): remove single-value compatibility aliases`
  - `feat(core): thread ViewStyle through layout and event contexts`
- Common `type` values: `feat`, `fix`, `refactor`, `docs`, `build`, `test`,
  `diagnostic`.
- Common `scope` values: `core`, `views`, `runtime`, `theme`, `backend`,
  `render`, `layout`, `build`.
- Keep the subject line lowercase and imperative.

## Developer Certificate of Origin

MoUI uses a lightweight DCO. By submitting a pull request, you certify that
your contribution is your own original work (or that you have the right to
submit it under Apache-2.0) by adding a `Signed-off-by` line to your commits:

```sh
git commit -s
```

This adds `Signed-off-by: Your Name <your.email@example.com>` to the commit
message. Use your real name and the email associated with your GitHub
account. If a commit is missing the line, amend it before pushing.

The full text is the
[Developer Certificate of Origin v1.1](https://developercertificate.org/).

## Review process

1. **Open a PR** against `main`. Fill in the pull request template.
2. **Maintainer review.** The maintainer reviews against the architectural
   invariants and the [Review Checklist](docs/moui-app-package-boundary.md#review-checklist)
   in the package-boundary doc. Expect comments on package ownership, API
   surface impact, and whether the change belongs in `core` vs `views` vs
   `runtime`.
3. **Architecturally sensitive changes** — new top-level packages, runtime
   pipeline changes, `core` contract changes, status-class reclassification —
   require a lightweight RFC (an issue tagged `rfc`) before code review.
   See [GOVERNANCE.md](GOVERNANCE.md).
4. **Address feedback** by pushing new commits (do not force-push over
   reviewed commits unless asked).
5. **Merge** is at the maintainer's discretion, typically as a squash or
   rebase to keep `main` linear.

## Reporting issues

- **Bugs and feature requests:** use the GitHub issue templates. Bug reports
  must include the platform × renderer matrix and the MoonBit toolchain
  version.
- **Security vulnerabilities:** do **not** open a public issue. Follow
  [SECURITY.md](SECURITY.md) for private disclosure.
- **Questions and discussion:** prefer GitHub Discussions or an issue tagged
  `question`.

## Questions about boundaries

When unsure where a change belongs, open a draft PR or an issue tagged
`question` and ask before implementing. A short conversation up front is
cheaper than reworking a PR that lands in the wrong package.
