# Plan: Ecosystem seed — external apps, addon registry, device plugins

- **Status**: active
- **Goal**: Prove MoUI outside the first-party tree, then let addons and native
  device services grow from real demand instead of speculative APIs.
- **Non-goals**: a marketplace, dynamic plugin loading, camera in Phase 1, a
  typed service registry before external feedback.

## External apps first

1. Publish `docs/external-apps.md` with onboarding, supported versions, known
   gaps, and a feedback template.
2. Record candidates and status in `checks/external-apps.json`; MoMark, Studio,
   and new_world can pilot but do not count as independent adoption.
3. Remove onboarding blockers from generated projects: `moui dev`,
   `moui package`, and `moui test` must not depend on repo-local scripts.
4. Run base + views + addon consumer checks against each pilot; turn gaps into
   issues, not framework abstractions.

## Addon registry seed

1. `checks/addon-registry.json`: the 12 existing addons with module, version,
   capability, quality tier, docs, and source.
2. `scripts/generate-addon-registry.mjs` emits `docs/addon-registry.md` and a
   website JSON; a validator runs in the PR profile.
3. Extend `checks/component-quality.json` to addon modules with
   experimental/preview/stable tiers.
4. Add an addon profile and fixture to `scripts/external-consumer-ci.mjs`.
5. Align the zh-Hans addon guide with the English guide.

## Device plugin vertical slice

Scope: macOS + Web + Android; notifications and permissions first.

1. Reuse `NotificationServices`/`PermissionServices` and the existing
   `PlatformChannel` operation mapping.
2. macOS: UserNotifications bridge and permission query behind the desktop
   host service bridge.
3. Web: Notification API and permission query behind the Web host.
4. Android: NotificationManager/POST_NOTIFICATIONS/permission result through
   the window-hosted template.
5. Add per-operation readiness to host capability summaries and stop reporting
   every `PlatformChannel` as handleable.
6. Add fake-service tests, host tests, and manual macOS/Android smoke.

## Acceptance

- [ ] 2-3 external pilots are recorded and running against a released base.
- [ ] Generated projects package and develop without repo-local scripts.
- [ ] The addon registry seed and validator are in the PR profile.
- [ ] Notifications and permissions work on macOS, Web, and Android, with
      capability flags and docs.
- [ ] No camera/typed-registry code lands before external demand is recorded.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-10 | External apps precede registry and typed plugin APIs |
| 2026-11-10 | Notifications/permissions are the first device slice; camera deferred |
| 2026-11-10 | MoMark/Studio/new_world are pilots, not independent adoption evidence |

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Plan created; onboarding kit and registry seed are next. |
| 2026-11-10 | macOS notification/permission vertical slice landed: `PlatformChannel` dispatch for `notification.send`/`cancel` and `permission.request`, backed by `NSUserNotificationCenter`; other operations stay explicitly unavailable. Web/Android still need the `window` host import/template and remain follow-ups. |
