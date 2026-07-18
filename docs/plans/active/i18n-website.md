# Plan: i18n addon and bilingual public website

- **Status:** completed
- **Goal:** Ship a reusable `en-US` / `zh-Hans` localization addon and use it to make the full public MoUI website and its documentation catalog available in either language.
- **Non-goals:** system locale discovery, locale-change host events, RTL support, ICU/CLDR MessageFormat, general locale-aware date/number formatting, and platform resource bundles.

## Acceptance

- [x] `moui_i18n` is a pure optional addon with native and `wasm-gc` coverage.
- [x] The deterministic catalog generator validates source catalogs and generated-source drift.
- [x] The Website supports an in-app locale switch and preserves `lang=zh-Hans` in shareable routes.
- [x] The Website localizes visible UI, semantic text, document metadata, catalog navigation, and all published documentation pages.
- [x] Root documentation is canonical English and `docs/zh-Hans/` is a complete public translation mirror.
- [x] The docs sync tool emits and validates both published locale trees and locale-aware sitemap URLs.
- [ ] Focused package/tool tests, static guards, daily validation, packaged-site smoke, and a browser locale-switch smoke pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-18 | Use optional `moui_i18n` rather than add catalogs/loaders to `moui/core`, `moui/views`, or the root facade. |
| 2026-07-18 | The first supported locales are `en-US` and `zh-Hans`, using compiled generated catalogs and named interpolation plus narrow English/Chinese plural selection. |
| 2026-07-18 | The Website is the pilot. English remains the default legacy route; Chinese uses `lang=zh-Hans` alongside the existing `section` and `anchor` query values. |
| 2026-07-18 | Public documentation is authored as English canonical sources with a full `docs/zh-Hans/` mirror. Code, commands, URLs, paths, package names, and API identifiers remain literal. |

## Ownership

| Area | Owner |
|------|-------|
| Locale parsing, catalog lookup, fallback, message interpolation | `moui_i18n` optional addon |
| Catalog source validation and MoonBit generation | `tools/moui/generate_i18n_catalogs` |
| Product copy, catalog selection, locale choice | `website/app` |
| Runtime environment application and browser metadata | `website/web_wasm`, `moui/backend/web` |
| Public document source and translated mirror | `docs/`, `docs/zh-Hans/` |
| Locale-aware docs copy, generated outputs, sitemap | `tools/moui/sync_website_docs` |

## Delivery sequence

1. Register the addon, write standing guidance, and implement the pure translation API with cross-target tests.
2. Add generator schema, integrity checks, checked-in generated website catalog data, and drift coverage.
3. Introduce Website locale state/control, environment wiring, query preservation, translated UI/a11y strings, document metadata, and Unicode-safe wrapping.
4. Upgrade Web route serialization so `section`, `lang`, and `anchor` round-trip without collapsing into the legacy `route` query parameter.
5. Move the catalog/sync pipeline to locale-aware metadata and output trees; add the canonical English source normalization and complete Chinese public-doc mirror.
6. Run package/tool/static/daily checks, package the Website, and smoke direct localized links, switching, browser history, metadata, accessibility labels, long Chinese layout, and localized Markdown links.

## Progress

| Date | Note |
|------|------|
| 2026-07-18 | Plan approved. Implementation started. |
| 2026-07-18 | Addon, generator, full Website localization, bilingual docs sync, and documentation mirror completed; final repository and presentation validation remains. |
