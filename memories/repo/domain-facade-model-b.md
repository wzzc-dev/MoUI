# Domain package model B

- `moui/core` owns geometry/graphics/animation/text/state value types and protocols.
- `moui/{geometry,graphics,animation,text,state}` are facades: `pub using @core {type X}` only (plus optional helpers that depend solely on core).
- **Forbidden:** `core` importing any domain package; domain packages cross-importing each other.
- Apps: `wzzc-dev/moui` + `views` + needed domain facades; no main-code `runtime`/`render/*`/platform backends.
- See ADR 0003 and ADR 0014 (`docs/decisions/0014-core-owns-domain-facades.md`).

- `moui/views` must not re-export domain value types (`Color`, `ColorScheme`, `Point`, …). App uses `@graphics`/`@state`/…; views may re-export command/menu + theme construction helpers (`ColorPalette`, `TypographyScale`) and temporary `DateValue`.
