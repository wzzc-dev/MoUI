# Vendor Workflow For External Apps

MoMark (`wzzc-dev/MoMark`) and MoUI Studio (`wzzc-dev/moui_studio`) are
**external repositories**. They are not submodules or `moon.work` members of
this repository. They consume published `wzzc-dev/moui*` modules.

When one of those apps needs a framework change, do not patch a vendored copy
and leave it there. Use a local vendor checkout, prove the change in the app,
then send the framework change back to MoUI as a PR.

## 1. Clone side by side

```sh
git clone https://github.com/wzzc-dev/MoUI.git vendor/MoUI
git clone https://github.com/wzzc-dev/MoMark.git
# or: git clone https://github.com/wzzc-dev/moui_studio.git
```

Keep `vendor/` out of the consumer commit:

```gitignore
vendor/
```

## 2. Point the consumer at the vendor checkout

MoonBit has no path dependency in `moon.mod`; use a local `moon.work` override.
In the consumer repository, add the framework modules the app actually uses:

```text
members = [
  ".",
  "vendor/MoUI/moui",
  "vendor/MoUI/moui_richtext",
  "vendor/MoUI/moui_markdown",
]
```

Add renderer/binding modules only when the consumer entrypoint names them
(for example `moui_skia_renderer`, `moui_web_renderer`, `moui_i18n`). A module
listed in `moon.work` overrides the registry pin with the local source.

## 3. Make and prove the change

Edit `vendor/MoUI`, then run the consumer's own tests against it. Also run the
MoUI gate for the touched surface:

```sh
# in vendor/MoUI
moon test moui/core moui/runtime moui/views --target native
sh scripts/check.sh --profile pr
```

A change that only works in the consumer and has no MoUI test is not ready for
a PR.

## 4. Send the framework change to MoUI

Create a branch in `vendor/MoUI` (it is a normal clone), commit the framework
change and its tests, push it to a fork or the upstream repository, and open a
PR against `wzzc-dev/MoUI`. Follow `CONTRIBUTING.md` and the task router in
`AGENTS.md`.

The PR must not include the consumer repository, its generated bundle, or the
`vendor/` directory.

## 5. Update the consumer pin after release

After the MoUI change is released:

1. Bump the consumer's `wzzc-dev/moui*` versions in `moon.mod`.
2. Remove the temporary `vendor/MoUI` members from the consumer `moon.work`.
3. Run the consumer tests against the published packages.
4. Keep `vendor/` gitignored; delete it or leave it as an uncommitted local
   cache.

## Rules

- **No orphan patches.** If `vendor/MoUI` contains a change the app depends on,
  there must be a corresponding MoUI PR.
- **No vendor commits.** Never commit `vendor/` to an app repository.
- **New packages/modules are release-first.** If the consumer needs a new
  public package, publish it from MoUI first, then pin it in the consumer.
- **External CI stays registry-based.** Local vendor overrides are a development
  tool; CI must resolve published versions.
- **Framework ownership stays here.** App-local models, screens, and platform
  entrypoints stay in the consumer repository; only reusable framework changes
  cross into MoUI.
