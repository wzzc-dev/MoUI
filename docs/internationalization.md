# Internationalization

MoUI internationalization separates **product messages** from the UI runtime
locale. The optional `wzzc-dev/moui_i18n` addon owns locale normalization,
compiled message catalogs, deterministic fallback, named interpolation, and the
small count-message rules supported by the application. `moui/core` continues
to own only the ambient `Environment.locale` and `LayoutDirection` values.

## Scope

The initial addon supports deterministic `en-US` and `zh-Hans` catalogs:

- BCP-47-style language tags with optional script and region subtags.
- Fallback from the exact tag to its less-specific tag(s), then the app's
  configured default catalog, then a visible missing-key marker.
- Named replacements such as `"Saved {count} files"`.
- Count messages with `one` and `other` variants. English selects `one` only
  for exactly one; Simplified Chinese selects `other`.

It intentionally does **not** provide ICU MessageFormat, gender/select rules,
CLDR data, locale-aware date/number/currency/list formatting, catalog loading
from a filesystem or network, automatic platform-locale detection, or RTL
support. Language selection and writing direction are separate decisions.

## Application pattern

Catalogs are product data. Keep their sources and generated MoonBit tables in
the shared application package; do not put them in `moui/views` or a platform
entrypoint. Render translated content from the existing environment-aware TEA
view API:

```moonbit nocheck
@moui.Program::new_with_environment(
  init=...,
  update=...,
  view=(model, env) => {
    let locale = env.environment().locale
    @views.button(
      translator.translate(locale~, key="actions.save"),
      on_click=Save,
    )
  },
)
```

The platform entrypoint owns `AppRuntime`, so a shared application requests a
locale change through its own injected callback. The entrypoint applies
`runtime.set_environment(runtime.environment().with_locale(tag))`. Shared app
packages must not import `moui/runtime` to make this change.

Always translate semantics labels, descriptions, placeholders, status text,
and host-dialog titles alongside visible text. Do not translate effect keys,
route IDs, service channel names, file paths, package names, API identifiers,
or code examples.

## Catalog generation

Runtime catalog tables are generated and checked in. Do not parse message JSON
at application startup. A source manifest uses this shape:

```json
{
  "schemaVersion": 1,
  "catalogs": [
    "website/app/i18n/en-US.json",
    "website/app/i18n/zh-Hans.json"
  ]
}
```

Each catalog filename must match its `locale` field. Messages use stable dotted
keys; a value is either a string or a count object with exactly `one` and
`other` strings:

```json
{
  "locale": "en-US",
  "messages": {
    "website.locale.label": "Language",
    "website.items": {
      "one": "{count} item",
      "other": "{count} items"
    }
  }
}
```

Generate or check a table with:

```sh
node scripts/generate-i18n-catalogs.mjs \
  --input website/app/i18n/catalogs.json \
  --out website/app/i18n_catalog_generated.mbt
node scripts/generate-i18n-catalogs.mjs \
  --input website/app/i18n/catalogs.json \
  --out website/app/i18n_catalog_generated.mbt \
  --check
```

The generator rejects invalid or duplicated locale/key data, mismatched locale
filenames, missing catalog keys, placeholder mismatches, unsupported message
shapes, and stale generated output.

## Website documentation

Public website documentation has English canonical sources in `docs/` and a
complete Simplified Chinese mirror in `docs/zh-Hans/`. The website catalog uses
stable IDs and locale-specific titles, summaries, keywords, and source paths.
The documentation sync tool publishes the English tree under `docs/` and the
Chinese tree under `docs/zh-Hans/`; it validates parity before writing output.

The Website keeps English canonical URLs unchanged. A Chinese route adds
`lang=zh-Hans`, for example:

```text
?section=docs/getting-started&lang=zh-Hans
```

The selected locale, anchors, and browser history must round-trip together.
