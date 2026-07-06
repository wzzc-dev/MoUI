# MoUI Theme

`wzzc-dev/moui_theme` is the optional design-system addon workspace member for
MoUI.

The core framework remains in `wzzc-dev/moui`; applications that only need the
neutral `@core.Theme` surface do not need this module.

`wzzc-dev/moui_theme/common` contains the shared source-mapped preview model,
coverage reports, customization helpers, and component token metadata.
`wzzc-dev/moui_theme/material`, `wzzc-dev/moui_theme/carbon`,
`wzzc-dev/moui_theme/primer`, and `wzzc-dev/moui_theme/fluent` expose
package-local official-system entrypoints over that common model, including
light, dark, high-contrast, and system theme helpers.

`wzzc-dev/moui_theme/sickle` exposes a first-party Sickle theme inspired by
Smartisan-style visual precision: layered skeuomorphic surfaces, inset control
edges, and flat semantic action/status colors. It offers light, dark,
skeuomorphic, flat, and hybrid theme helpers without claiming official
source-mapped design-system parity.

These adapters are not official-complete compatibility claims. They remain
source-mapped previews until source import coverage, source locks, official
anchors, parity reports, runtime token alignment, component token matrices, and
adaptation differences are all closed by tests and golden evidence.
