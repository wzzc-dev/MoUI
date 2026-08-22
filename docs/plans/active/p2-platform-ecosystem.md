# Plan: Complete P2 Platform Ecosystem

- **Status**: active
- **Goal**: Deliver P2 platform ecosystem improvements in independently verifiable commits: expanded app-facing platform service contracts, a unified packaging/publishing workflow, and compatibility/ecosystem governance.
- **Non-goals**: Do not claim native runtime support where matching-host evidence is absent; do not add concrete platform implementations or new renderer dependencies in the base module; do not expand mobile product readiness.

## Acceptance
- [x] Add neutral typed contracts and fake-service coverage for notifications, tray, permissions, sharing, printing, protocol/file associations, app lifecycle, and window persistence without violating package boundaries.
- [ ] Extend moui package into a validated, manifest-producing packaging workflow with explicit platform/artifact metadata and dry-run/build modes, preserving existing behavior where possible.
- [ ] Add versioning/deprecation/compatibility policy, third-party control and host-service extension templates, quality metadata, and an external-consumer compatibility gate.
- [ ] Run focused tests and required static/API/closure/guidance validators after each public-surface or package-layout commit.
- [ ] Commit each completed part separately.

## Decision log
| Date | Decision |
|---|---|
| 2026-08-22 | Keep contracts neutral in moui/services and moui/backend; concrete OS behavior remains platform-owned and may report unavailable until matching-host evidence. |
| 2026-08-22 | Make packaging deterministic and manifest-first; artifact creation is opt-in and platform-specific, with dry-run as the portable baseline. |
| 2026-08-22 | Treat compatibility templates and consumer CI as repository governance/addon tooling, not base runtime dependencies. |

## Progress
| Date | Note |
|---|---|
| 2026-08-22 | Initial repository, skill, architecture, service, CLI, release-closure, and plan inspection completed. |
| 2026-08-23 | Added typed `PlatformServices`, lifecycle subscriptions, fake coverage, `PlatformChannel` adapter wiring, and host-contract guidance. Static/API/boundary checks pass; package tests are blocked by unavailable Skia download. |
