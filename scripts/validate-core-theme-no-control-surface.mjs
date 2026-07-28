#!/usr/bin/env node

/// validate-core-theme-no-control-surface.mjs
///
/// Enforces ADR 0017 + invariant P3: `moui/core` carries no control-only
/// vocabulary on its public surface. The neutral cross-runtime contract
/// package must not export concrete control themes, control token structs,
/// control shape/appearance enums, or the `ComponentThemes` aggregate. New
/// controls add tokens in `moui/views` (`ControlThemeSet`), never in `core`.
///
/// Mechanizable: scans `moui/core/pkg.generated.mbti` for a frozen denylist
/// of control-only type names. The denylist only shrinks (or grows via an RFC
/// entry in this file); growth needs an ADR superseding 0017.

import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const coreInterfacePath = resolve(repoRoot, "moui/core/pkg.generated.mbti");

if (!existsSync(coreInterfacePath)) {
  console.error(
    `validate-core-theme-no-control-surface: missing ${coreInterfacePath}; run \`moon info moui/core\` first.`,
  );
  process.exit(1);
}

/// Control-only type names that must never appear on `core`'s public surface.
/// Each entry is a whole-word type identifier (struct/enum/alias). If a name
/// must be admitted back into `core`, file an ADR superseding 0017 and add it
/// to `allowlist` with the RFC reference.
const denylist = [
  // Aggregate
  "ComponentThemes",
  // Control theme token structs (per-control)
  "ButtonTheme",
  "TextFieldTheme",
  "SurfaceTheme",
  "ChoiceControlTheme",
  "ProgressTheme",
  "SliderTheme",
  "PickerTheme",
  "FeedbackTheme",
  "BadgeTheme",
  "FormValidationTheme",
  // Control token layer + resolved layer
  "ControlStateTokens",
  "ControlStateStyle",
  "StateLayerTokens",
  "ToneTokens",
  // Control variant + shape + appearance enums
  "ButtonVariantToken",
  "ChoiceControlShape",
  "CheckMarkStyle",
  "ThumbShape",
  "TextFieldAppearance",
];

/// Admitted back into `core` with an explicit RFC/ADR reference. Today this
/// is empty: ADR 0017 moved all of the above out of `core`. The neutral
/// `InteractionState` enum and the gesture-driven `PressableState` enum
/// (formerly `ButtonState`, renamed to make its neutral role clear) are
/// **not** in the denylist — they are the neutral gesture/interaction state
/// machine consumed by `core`'s own view-tree and gesture layers (ADR 0017
/// rationale), so they are allowed to remain in `core`.
const allowlist = [];

if (allowlist.length > 0) {
  console.error(
    `validate-core-theme-no-control-surface: allowlist is non-empty; each entry needs an ADR superseding 0017 recorded as a comment here.`,
  );
}

const interfaceText = readFileSync(coreInterfacePath, "utf8");

/// Match each denylist name as a whole word so `ButtonTheme` does not match
/// `ButtonThemeResolve` or similar. The generated interface uses `pub(all)
/// struct Name`, `pub(all) enum Name`, `pub using @core {type Name}`, and
/// `type Name` aliases — so a `(enum|struct|using|type|fn) Name` sentinel scan
/// is sufficient; we scan for the bare identifier preceded by a boundary.
const violations = [];
for (const name of denylist) {
  if (allowlist.includes(name)) continue;
  // Word-boundary match: the name is surrounded by non-identifier chars or
  // string starts/ends. `pkg.generated.mbti` declares each type with `Name`
  // appearing as a token after `struct`/`enum`/`using`/`type`.
  const pattern = new RegExp(`(^|[^A-Za-z0-9_])${name}([^A-Za-z0-9_]|$)`);
  if (pattern.test(interfaceText)) {
    violations.push(name);
  }
}

if (violations.length > 0) {
  console.error(
    `\nvalidate-core-theme-no-control-surface: control-only vocabulary leaked back into moui/core (ADR 0017, invariant P3):`,
  );
  for (const name of violations) {
    console.error(`  - ${name}`);
  }
  console.error(
    `\nControls own their tokens in moui/views (ControlThemeSet). If a name must return to core, file an ADR superseding 0017 and add it to the allowlist in scripts/validate-core-theme-no-control-surface.mjs.`,
  );
  process.exit(1);
}

console.log(
  `validate-core-theme-no-control-surface: ok (core public surface carries no control-only types; ${denylist.length} denylist entries)`,
);
