# MoUI Governance

This document describes how decisions are made in MoUI, who makes them, and
what happens if the maintainer becomes unavailable. It exists to make the
project's bus factor survivable: the rules are written down so a contributor
or successor can pick the work up without guessing.

## Current state

MoUI is maintained by a **single maintainer** (`wzzc-dev`), assisted by AI
tooling for code generation and validation. The maintainer:

- Reviews and merges all pull requests.
- Owns the release cadence and what lands on `main`.
- Is the final decision maker on architectural changes.

This is stated plainly because it is the project's largest structural risk.
The rest of this document is about reducing that risk, not hiding it.

## Roles

### Maintainer

A maintainer has merge access to `main` and the authority to decide on PRs,
releases, and roadmap direction. Maintainers are expected to:

- Uphold the [architectural invariants](docs/ai-collaboration.md) and the
  [package boundary rules](docs/moui-app-package-boundary.md).
- Run or delegate the [daily validation](docs/testing.md) before merges that
  touch core/runtime/render/backend.
- Keep `docs/`, `AGENTS.md`, and `skills/` synchronized with the codebase.
- Respond to security reports per [SECURITY.md](SECURITY.md).

### Contributor

Anyone who opens a PR. Contributors follow
[CONTRIBUTING.md](CONTRIBUTING.md), sign off commits via DCO, and respect the
package boundaries. Sustained high-quality contributors may be nominated for
maintainer status (see [Adding maintainers](#adding-maintainers)).

## Decision mechanism

### Routine changes

Daily PRs — bug fixes, new controls in `moui/views`, tests, docs,
non-breaking renderer improvements — are decided by a maintainer during
review. The maintainer checks the change against the
[Review Checklist](docs/moui-app-package-boundary.md#review-checklist) and the
architectural invariants. No separate process is required.

### Architectural changes (lightweight RFC)

Changes that reshape the framework's structure or contracts require a
**lightweight RFC** before code review:

1. **Open an issue** tagged `rfc` describing the change and the motivation.
2. **Identify the affected invariant.** Most architectural changes touch one
   of: the runtime pipeline, a `core` contract, the package ownership map,
   or the mainline/diagnostic status classification.
3. **Maintainer decision.** The maintainer reviews the RFC and either
   accepts, requests changes, or declines. Acceptance is recorded on the
   issue; implementation then proceeds via normal PRs.

Architectural changes that always require an RFC:

- Adding a new top-level package (e.g. a new `moui/<area>`).
- Changing the runtime pipeline (`View[Msg] -> ElementTree -> LayoutTree ->
  RenderTree -> DrawCommand -> renderer`).
- Changing a `core` contract in a way that breaks existing `views`/`runtime`
  code.
- Reclassifying a renderer or platform between `mainline`, `diagnostic`, and
  `pending` (see [docs/maintenance.md](docs/maintenance.md)).
- Changing the default app dependency set (`wzzc-dev/moui` +
  `wzzc-dev/moui/views`).

### Emergency fixes

A security fix or a `main`-breaking regression may be merged under
maintainer discretion without a full RFC, with a post-hoc write-up linked
from the merge commit.

## Roadmap relationship

[docs/roadmap-2026.md](docs/roadmap-2026.md) states the direction the project
is heading. Governance decides *how* changes are made; the roadmap decides
*what* gets prioritized. The maintainer owns the roadmap; contributors can
influence it through RFC issues and PRs.

## Adding maintainers

MoUI aims to grow beyond a single maintainer. A contributor may be nominated
for maintainer status when they have demonstrated:

- Sustained, high-quality contributions across multiple packages (not just
  one example app).
- Sound judgment on package boundaries and the architectural invariants.
- Reliability in review feedback and follow-through.

Nomination requires **unanimous agreement of existing maintainers**. Since
there is currently one maintainer, that means the maintainer's nomination
plus the contributor's acceptance. A new maintainer is announced in a
tracking issue and gains merge access to `main`.

## Project continuity and handover

This section exists because a single-maintainer project must plan for the
maintainer's unavailability. It applies regardless of cause (health, change
of priorities, loss of interest).

### Inactivity threshold

If the sole maintainer is **unresponsive for six months** — no commits, no
PR reviews, no responses to issues or security reports — the project is
considered **stalled**.

### Stewardship fork

Apache-2.0 permits anyone to fork and continue the work. If the project is
stalled, a community steward may:

1. **Announce the intent** to continue the project, publicly (a GitHub issue
   on the original repo, a discussion post, or a README in the fork).
2. **Allow a reasonable response window** (at least 30 days) for the original
   maintainer to object or resume activity.
3. **Preserve attribution and copyright.** Keep the original `LICENSE` and
   copyright notices intact. Do not claim authorship of prior work.
4. **Continue under a clear name** that distinguishes the stewardship fork
   from the original (e.g. a renamed organization or a `-community` suffix)
   unless the original maintainer explicitly transfers the name.

### Transfer of the canonical repo

If the original maintainer returns or actively transfers the project, the
canonical repository is wherever the maintainer designates. A stewardship
fork that has accumulated divergent work should offer to rebase or merge back
into the canonical line.

### What successors should rely on

A successor (maintainer, fork, or contributor picking up the work) can rely
on these surfaces being self-sufficient:

- `AGENTS.md` and `docs/` for boundaries, setup, and validation.
- `scripts/check.sh --profile daily` and the maintenance baseline ratchets for keeping
  entropy bounded.
- `pkg.generated.mbti` and `scripts/validate-api-surface.mjs` for the public
  API surface.
- This governance document for decision rules.

The point of the engineering discipline in this repository is to make the
project survivable across a change of hands. That only holds if these
surfaces stay honest — successors should fix drift they find rather than
paper over it.
