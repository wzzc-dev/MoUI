# Examples

MoUI examples are runnable documentation. Showcase is the visual catalog and
now follows the same TEA shape as ordinary apps: `Model / Msg / update / view`
driven by `Program::simple_with_environment`. It still contains the Counter and
Todo interaction patterns. The WYSIWYG Markdown editor stays separate because
it demonstrates a larger editing workflow with its own model and parser tests.
Apps that need host-service work should use `Program::new` with `Effect[Msg]`;
prefer `Effect::host_service` when a host-service bridge should carry a stable
diagnostic key, use `Effect::run` for custom structured async bridges, and use
`Effect::service_task` when a service-like one-shot async task needs runtime
managed cancellation, completion, and stale-dispatch diagnostics. Use
`Effect::task` for custom task kinds. Apps that need ongoing typed callbacks can
add `subscriptions=model => ...` and stable `Subscription` keys while keeping
concrete timer or host adapters out of `core`.
Showcase surfaces renderer capability follow-ups first so visible docs do not
hide partial or gap status behind ready features. The dedicated
`examples/design_systems/app` package owns Material, Carbon, Primer, and Fluent
source-mapped preview UI plus the Sickle first-party theme addon sampler, so
Showcase remains a MoUI framework catalog and does not depend on `moui_theme`.
Sickle lives in `moui_theme/sickle` as a first-party theme addon rather than an
official source-mapped preset. Design Systems is addon diagnostic coverage with
Web wasm-gc and macOS, Windows, and Linux Skia entrypoints for trying the addon
sampler outside the framework Showcase.

Use the [Non-render component cookbook](non-render-component-cookbook.md) when
you want to copy a pattern rather than inspect a full example package. It maps
forms, tables, shells, menus, host services, and virtual lists to the examples
that exercise them.

Use [App templates](app-templates.md) when starting a new shared app package.
The templates cover counter, dashboard, and document-editor skeletons without
introducing a generator. The root `website/` workspace uses the same app-first
shape outside `examples/` so MoUI can render its own bilingual homepage.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Website | MoUI-built homepage workspace | `website/app/` | Bilingual product homepage, first-screen MoUI brand hero, compact Counter code snippet, interactive runtime preview, framework foundations, platform matrix, release-readiness cards, quick-start Web commands, runtime Docs portal that fetches packaged same-origin `docs/*.md` Markdown plus MoUI and `moui_skia` README copies, Web-only `website/web_wasm` entrypoint |
| Agent Counter | Minimal agent-controllable runtime example | `examples/agent_counter/`, `examples/agent_counter/main/`, `examples/agent_counter/macos_skia/` | Counter app with semantics/command-intent flow for agent observation and control, plus a native macOS Skia entrypoint |
| Counter | Minimal model/update/view app | `examples/counter/app/` | Simple `Program::simple` flow, `center`/`card`, typed button messages, an experimental Android Skia embedded-session entrypoint, and a Counter Android APK shell |
| Button Freeze Probe | Native Skia button freeze repro | `examples/button_freeze_probe/app/` | Minimal `data_filter_bar` filter chips, red primary accent, repeated click counter, direct primary/tonal button comparison, native Skia macOS/Windows/Linux entrypoints |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | TEA-first `Model / Msg / update / view` app, public `views` constructors, built-in Counter/Todo examples, validating form fields and workflow bars, `ToastQueue`-backed toast stack/progress/status surfaces with dismiss state, `status_badge` feedback chips, helper-backed table/selectable-list data views with app-owned sort/page/column visibility state, route header/section-nav/sidebar/breadcrumb shells with app-owned route/deep-link history and route focus restore state, custom dialog/alert/sheet/menu surfaces, light Markdown preview, neutral core theme toggling, presentation, renderer capability status, advanced rendering demos, text diagnostics, interaction wiring. Showcase intentionally has no `moui_theme` dependency and is not an official design-system compatibility claim. |
| Design Systems | Addon diagnostic source-mapped design-system preview and first-party theme sampler | `examples/design_systems/app/`, `examples/design_systems/{web_wasm,macos_skia,windows_skia,linux_skia}/` | Material, Carbon, Primer, and Fluent switching through the `moui_theme/material`, `moui_theme/carbon`, `moui_theme/primer`, and `moui_theme/fluent` entrypoints over shared `moui_theme/common` models, Sickle switching through `moui_theme/sickle` as a first-party theme addon, light/dark/high-contrast/system variants for official source-mapped presets, compact/standard/comfortable density, semantic palette roles, typography specimen, spacing/density grid, component-token matrix sampling, component style bundle usage, custom inheritance/override API, Web and native Skia host entrypoints, coverage/parity status labels, and explicit source-mapped preview wording rather than official-complete claims |
| Settings | Settings shell pattern | `examples/settings/app/` | Form sections, sidebar navigation, segmented theme mode, toggle preferences, saveable state snapshot/restore |
| Data Table | Operational data browser pattern | `examples/data_table/app/` | Search/filter toolbar pattern, status chips, `ColumnVisibilityState`, sortable table headers with `DataSortState`, app-owned column width/order state, row selection with `SelectionState`, selection toolbar actions, tree filters, loading/error/empty states, `PaginationState`, public `pagination` and `detail_panel`, model-level filtering and data slicing |
| Excel | Spreadsheet workbook prototype | `examples/excel/{cell,formula,sheet,xlsx,app}/`, `examples/excel/{macos_skia,linux_skia}/` | Native `.xlsx` workbook load/save flow through an app-private `xlsx` adapter, desktop spreadsheet shell, formula/name bars, sheet tabs, cell edit/copy/cut/paste/delete, row/column insertion, undo/redo, formula evaluation, number formats, color swatches, heat-map display, host file services, and macOS/Linux Skia entrypoints |
| File Importer | File import workflow pattern | `examples/file_importer/app/` | Drop zone, file dialog facade, unavailable service state, pending completion handling, selected file list |
| WebView Demo | Native platform WebView pattern | `examples/webview_demo/app/` | Controlled `web_view` primitive, native host capability fallback, address bar, navigation commands, JavaScript evaluation command, macOS/Windows/Linux Skia native entrypoints, Web wasm unavailable fallback without iframe |
| PDF Workbench | PDF reading and light editing prototype | `examples/pdf_workbench/app/` | Clean native PDF reader/editor shell, host binary file service open/save flow, PDFium page bitmap preview, fit-width responsive reading canvas, scrollable page/inspector panels, reader fullscreen toggle, page navigation/direct page jump/search/metadata summaries, undoable/discardable preview rotate/crop/stamp/title/bookmark/note edit state, separate `pdflite_adapter` package for real parsing/writeback checks, JSONL pdflite helper protocol plus native process transport, native-only `pdfium_adapter` package for page rasterization, macOS/Windows/Linux Skia native entrypoints |
| Command Palette | Command metadata and menu pattern | `examples/command_palette/app/` | Command palette rows, shortcut labels, enabled/disabled dispatch, command menu, context menu fallback, `program_with_services`, and `HostAppServices::show_context_menu` native menu preview |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, primary rich text editor, optional source preview |
| Code Editor | Native code editor shell and language-provider prototype | `examples/code_editor/app/` | Native `moui_richtext` editor shell with activity rail, file tab, line-number gutter, status bar, tokenizer-backed highlighting, bracket matching, auto indentation, multi-cursor edits, hidden find/replace overlay, runtime action-command shortcuts, completion overlay, diagnostics, hover, go-to-definition, main-editor Diff mode, and custom language/provider registration through app-owned callbacks |
| Mo Workbench | Native-Skia-first desktop agent dogfood app | `examples/mo_workbench/app/` | DeepSeek-GUI-inspired multi-workspace shell with Code chat, starter cards, backend-aware OpenSeek/ACP controls, responsive left rail, optional right inspector, low-noise status bar, grouped Settings form, static Write/Connect Phone/Scheduled Tasks/Plugins surfaces, injected stub backend, OpenSeek native transport, generic ACP stdio native transport, macOS Skia native entrypoint |
| MoUI Quick Example | Minimal MoUI counter for quick start exploration | `examples/moui_example/app/` | Simple `Program::simple` flow, `center`/`card`, typed button messages; macOS / Windows / Linux Skia and Web wasm-gc entrypoints (`readme.mbt.md`) |

Focused Website checks:

```sh
moon test website/app --target native
moon build website/web_wasm --target wasm-gc
```

The Website Docs page is part of the same MoUI app state as the homepage. It
does not precompile Markdown into wasm; the Web host text-file service fetches
the selected same-origin Markdown file from `docs/` at runtime. For local
preview, run `node scripts/sync-website-docs.mjs` so `website/web_wasm/docs/`
contains the root docs plus `moui-readme.md` and `moui-skia-readme.md`. The
GitHub Pages workflow copies those Markdown sources directly into
`dist/pages/docs/` while staging the deployment artifact.

## Counter

Counter is the smallest recommended app shape. It keeps user code in
`Model / Msg / update / view`, then lets `Program::simple` connect that pure
model loop to the runtime. It has Web, macOS, Windows, Linux, an experimental
Android Skia embedded-session entrypoint plus `examples/counter/android_app`
APK shell, and `windows_wgpu_cosmic` entrypoints, so it is also the quickest way
to verify a thin platform package without the full Showcase surface:

```moonbit
using @views {button, card, center, column, row, text}

pub struct Model {
  count : Int
}

pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("MoUI Counter").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}

pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
```

Focused Counter checks:

```sh
moon test examples/counter/app --target native
moon build examples/counter/web_wasm --target wasm-gc
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/android_skia --target native
scripts/build-counter-android-apk.sh --fallback-skia
```

The fallback APK command validates the packaging path only. Use
`scripts/build-counter-android-apk.sh` without `--fallback-skia` plus a
matching device/emulator smoke before claiming Android Skia first-frame runtime
support.

## Button Freeze Probe

Button Freeze Probe isolates the native Skia click-freeze investigation from
the full Showcase surface. It keeps only the reusable `data_filter_bar` search
input, selected filter chips, direct primary/tonal button comparison, and a
small click/action readout so repeated clicks exercise the same focused-input,
button dispatch, and redraw path without table, tree, pagination, or renderer
catalog noise.

Focused Button Freeze Probe checks:

```sh
moon test examples/button_freeze_probe/app --target native
moon build examples/button_freeze_probe/macos_skia --target native
```

## Code Editor

Code Editor is a native-only editor shell. It does not embed Monaco or a
WebView; the editable surface is `moui_richtext.controlled_rich_text_editor`
with app-owned editor chrome, code formatting, and language-service state. The
shared app owns the source buffer, cursors, hidden find/replace overlay,
completion overlay, diagnostics, hover result, definition target,
bracket-match state, and a main-editor Diff mode for review and patch
inspection.

Language support is registered through `CodeLanguageRegistry` and
`CodeLanguageProvider` callbacks. Providers supply tokenizer, completion,
diagnostics, hover, and definition callbacks, so the example demonstrates
custom language registration without moving app-specific language-service APIs
into the MoUI framework. Native entrypoints register the editor's
`ActionCommandMap` with the runtime for shortcut metadata.

Focused Code Editor checks:

```sh
moon test examples/code_editor/app --target native
moon check examples/code_editor/macos_skia --target native
moon check examples/code_editor/windows_skia --target native
moon check examples/code_editor/linux_skia --target native
```

## WebView Demo

WebView Demo shows the native platform-view path without involving renderer
draw commands. The shared app owns controlled navigation state: a page link
emits `NavigationRequested`, the model updates `url`, and the host commits the
real native WebView to the next `DrawFrame.platform_views` rectangle. Buttons
exercise the host command queue for load, reload, stop, back, forward, and
JavaScript evaluation.

Native entrypoints pass the same `HostWebViewCommandQueue` to the Skia provider
options so macOS `WKWebView`, Windows WebView2 builds, and Linux WebKitGTK
builds can drain commands after rendering. Web wasm passes an unavailable
capability and renders fallback UI; it does not create an iframe overlay.
	Windows real WebView builds are auto-detected by the prebuild from
	`.tools/webview2/` (set up by `scripts/windows/setup_msvc_deps.ps1 -InstallWebView2`),
	matching how Linux auto-detects WebKitGTK via `pkg-config`. Override with
	`MOUI_WINDOWS_WEBVIEW2_*` environment variables for custom SDK paths.
	Linux WebKitGTK builds are auto-detected via `pkg-config` when
`libwebkit2gtk-4.1-dev` is installed. Override with `MOUI_LINUX_WEBKITGTK_*`
environment variables for custom setups.
Linux WebKitGTK builds also require a matching-host smoke before claiming
runtime evidence: the backend pumps the GTK main context, syncs
`DrawFrame.platform_views` placements, forwards navigation/title/history/script
events, and drains queued commands after each rendered frame, but package checks
only prove the contract mapping and fallback path.

Focused WebView Demo checks:

```sh
moon test examples/webview_demo/app --target native
moon check examples/webview_demo/macos_skia --target native
moon check examples/webview_demo/windows_skia --target native
moon check examples/webview_demo/linux_skia --target native
moon check examples/webview_demo/web_wasm --target wasm-gc
```

Configured Linux WebKitGTK check (auto-detected when packages are installed):

```sh
moon check examples/webview_demo/linux_skia --target native
```

Showcase is organized around the main catalog order:
`Overview -> Examples -> Text & Media -> Controls -> Forms -> Data -> Layout ->
Navigation Shell -> Feedback -> Runtime/Renderer -> Diagnostics`. The first nine sections
cover user-facing components and layout patterns. `Runtime/Renderer` displays
host capability and renderer status cards. `Diagnostics` shows a compact
inspector snapshot with runtime, TEA program message/effect task/subscription,
duplicate key names, view, layout, semantics, render command, and render-scope
counters, then links to the deeper diagnostic routes for
interaction wiring, text diagnostics, and advanced rendering without crowding
the main sidebar.

The hidden diagnostic routes remain directly addressable for focused tests and
development workflows:

- `Advanced Rendering`: app-local `custom_layout` demos for layer/blend,
  filter, shader effect, path, transform, and opacity draw commands.
- `Text Diagnostics`: CJK mixed text, RTL/bidi samples, emoji status labels,
  fixed-width wrapping, a narrow `TextRun.frame` clipping sample, and a compact
  Markdown/rich text diagnostic.
- `Interaction Lab`: tooltip, file-drop modifier wiring, FocusScope traversal,
  first-invalid targeting, Enter/Escape command targets, shortcut affordances,
  runtime `View::focus_trap` containment, public `shortcut_button` dispatch,
  app-owned `focus_ring` affordances, popover/dropdown expanded semantics,
  pressed/selected/disabled semantic state examples, button/text-field
  variants, and deterministic image lifecycle states.
- `Forms`: validating/help/error/disabled/read-only field states, keyed
  first-invalid focus targets, and submit-guard state for the form workflow
  bar.
- `Navigation Shell`: route headers, section navigation, breadcrumbs, dialogs,
  sheets, command metadata, app-owned route/deep-link history, a controlled
  fade/slide route transition preview, a controlled drag-resizable split pane,
  and `RouteFocusStore` state showing which `runtime.focus_key(...)` call
  should restore route focus after a route switch. `HostRouteSource` provides
  the host-layer route/deep-link subscription fanout that apps can feed into
  this shared state, but the visible route history is still a serializable
  shadow stack and the transition is sampled by app state; browser history,
  automatic route-transition scheduling, and native deep-link
  dispatch remain host/app follow-up work.
- `Feedback`: toast/banner/callout/progress/inline-error surfaces plus a
  `ToastQueue` example that converts queued items into `toast_stack` rows while
  keeping timers in the app model.
- `Examples`: Counter and Todo reusable app patterns until the dedicated
  example apps cover those workflows.

The Markdown editor keeps Markdown source as the saved value while presenting a
formatted editor surface as the primary workflow. Source preview remains
available from the toolbar. See [Markdown Editor](markdown-editor.md) for the
editing model, source/visual mapping, contextual commands, and validation
guidance.

## Settings

The Settings example is a shared app package without platform entrypoints. It
shows the recommended non-render shell for account preferences: a public sidebar
constructor drives controlled section selection, form fields own validation
messages in the app model, segmented controls choose light/dark/system theme
mode, and `SaveableStateStore` snapshots restore the current settings without a
host service.

## Data Table

The Data Table example is also shared-app only. It models the data workflow that
operational tools usually need before renderer-specific polish: controlled
search/filter toolbar, status chips, column visibility, app-owned column width
and order controls, sortable table headers, tree filters, stable model-level
sorting, page navigation, selected-row detail, plus empty/loading/error panels
built from public `views` constructors.
The app keeps filtering, sorting, and page slicing in its TEA model while using
public `DataSortState`, `PaginationState`, `ColumnVisibilityState`,
`ColumnWidthState`, `ColumnOrderState`, `SelectionState`, `data_filter_bar`,
table sort-header, row-selection, `column_visibility_panel`,
`selection_toolbar`, `pagination`, and `detail_panel` helpers for reusable view
structure. Filter predicates, async requests, pointer-specific header gestures,
column width/order persistence, and bulk action effects remain app-owned.

## Excel

The Excel example is a native spreadsheet-workbook prototype. The app package
owns the MoUI shell, TEA messages, host-service file effects, and command map,
while app-private `cell`, `formula`, `sheet`, and `xlsx` packages own cell
coordinates/value formatting, formula evaluation, pure workbook operations, and
`mbtexcel` import/export. The visible surface is intentionally desktop
spreadsheet-first: grouped file/edit/format/number/view controls, formula and
cell-reference inputs, scrollable grid, bottom sheet tabs, status bar, color
swatches, number formatting, and heat-map display.

Focused Excel checks:

```sh
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon check examples/excel/macos_skia --target native
```

## File Importer

The File Importer example demonstrates the non-render file workflow surface. The
view uses `drop_zone` and `file_import_panel`; the pure model accepts dropped
paths, while the effect-capable runtime uses `Program::new` and
`Effect::host_service` to request an app-level host file dialog through
`HostAppServices` and feed unavailable, immediate, or pending responses back as
typed `HostCompleted` messages. Pending file-dialog responses are stored as
model state and declared through `HostAppServices::completion_subscription`, so
the later host completion dispatches through the same typed TEA update path as
synchronous responses and cancels when the model leaves `Pending`. Its app
tests also compose the importer as a child feature with `View::map`,
`Effect::map`, and `Subscription::map`, which is the recommended pattern when a
parent TEA model owns a child workflow that can still return follow-up effects
or ongoing event sources; the parent runtime assertions also keep the mapped
child effect descriptors, active completion subscription descriptor, and
subscription lifecycle cancellation visible through program diagnostics.
Browser hosts commonly expose file
names while native hosts can expose filesystem paths, so production apps should
treat these strings as host-provided display or import handles rather than
assuming one platform shape.

## PDF Workbench

PDF Workbench is a MoUI example-level PDF reader and light editor. Its shared
app package is intentionally a lightweight UI shell so the native Skia
entrypoint does not pull the full PDF parser into one huge generated C
translation unit. The app keeps host interaction in TEA effects: open uses a
file dialog followed by `HostAppServices::read_binary_file`, while save and
save-as write through `HostAppServices::write_binary_file`; save-as defaults
the dialog name to the current PDF file name and appends `.pdf` when the source
path has no `.pdf` suffix. Clean documents write unchanged original bytes, while
dirty documents ask the injected
`PdfWorkbenchDocumentServices` writeback hook for new PDF bytes before writing.
After a dirty save succeeds, the app reloads the written bytes through the same
document service so the clean snapshot, metadata, page summaries, and queued
diagnostics reflect the actual saved PDF rather than stale preview state.
Preview edits are tracked as an app-owned edit log with a clean snapshot so the
user can undo the last queued edit or discard queued changes before saving. The
right inspector keeps those controls grouped as Page, Queue, Document, and
Diagnostics sections: page operations stay near undo/discard, queued edits show
as compact rows, the saved/unsaved badge and zoom percentage stay visible, and
parser/raster/writeback diagnostics are separated from primary editing actions.
The current pdflite adapter applies rotate/crop edits, writes stamp text back as
a standard-font overlay, updates the PDF Info dictionary title, adds
current-page bookmarks, and writes current-page text annotations when saving
dirty documents.
The reader shell is responsive: wide windows show thumbnails, the page canvas,
and the inspector side by side, while narrower windows hide side panels so the
PDF bitmap remains the primary readable surface. The page toolbar can also
switch the reader into a fullscreen window-filling mode that hides the app
chrome and side panels until the user exits it. The page toolbar includes
previous/next, direct page jump, zoom in/out, and a `Fit` action that returns to
the fit-width `100%` baseline while reusing the raster cache when available.
The search field exposes previous/next hit controls and a compact active
match-position label such as `Find: 2/5`; opening a new PDF clears stale search
state so results always refer to the current document.
When the inspector is hidden, the page surface keeps a compact edit strip for
rotate, crop, stamp, undo, and discard so light editing stays available in the
reader-first layout.

`examples/pdf_workbench/pdflite_adapter` owns the direct
`bobzhang/pdflite` dependency for real PDF parse/text/outline/annotation
summary and rotate/crop/stamp/title/bookmark/note writeback checks. It is kept
outside the default native Skia entrypoints for now because directly importing
pdflite into the app executable triggers the same large native compile path the
prototype is trying to avoid. The
`examples/pdf_workbench/pdflite_service_protocol` package defines that boundary
as typed load/writeback requests plus JSONL-safe responses. Request/writeback
PDF bytes use base64 payload fields, while document-loaded responses carry
reconstructable metadata, outline, annotation, page-summary, diagnostic, and
page-count fields without echoing the original PDF bytes. The
`examples/pdf_workbench/pdflite_service_native_transport` package turns that
JSONL protocol into `PdfWorkbenchDocumentServices` by spawning a helper process
per load/writeback request, so native Skia entrypoints can stay thin and avoid
direct pdflite imports. The helper executable itself can still have a slow first
native compile because it intentionally contains pdflite; that cost is isolated
from the PDF Workbench UI binary.
`examples/pdf_workbench/pdfium_adapter` owns the native-only PDFium C FFI for
existing-page rasterization. The shared app depends only on injected
document/raster service interfaces, so Web and app-package tests still build
without pdflite or PDFium while native Skia entrypoints pass the PDFium raster
service. Its focused native test covers both fallback-unavailable behavior and,
when PDFium is linked, real BMP output with expected page dimensions, 32-bit
pixel metadata, file-size consistency, and rendering page 2 of a generated
multi-page PDF.

When PDFium is linked, opening, paging, direct page jumps, or zooming a PDF
requests a bitmap raster and the preview draws it through MoUI `DrawImage` with
a local BMP source path. The shared app keeps a small most-recently-used raster
cache for page/zoom combinations so backtracking stays fast without unbounded
bitmap growth, and the Pages sidebar reuses cached page bitmaps as real
thumbnails for pages the reader has already visited. If PDFium is disabled or
rendering fails, the app keeps the loaded document, falls back to the
structural MoUI preview with diagnostics, and shows a dismissible failure
banner. The Skia PDF backend is reserved for a future export/generation route
that writes MoUI draw commands to PDF; it is not used to rasterize existing PDF
pages.
For an interactive startup run, set `MOUI_PDF_WORKBENCH_STARTUP_PDF` to a PDF
path such as `examples/pdf_workbench/fixtures/minimum.pdf`; the startup path
uses the same binary-read, document-load, and PDFium raster request flow as the
Open button. `node scripts/pdf-workbench-native-smoke.mjs` keeps the automated
check to PDFium real-raster tests plus native entrypoint builds.
Set `MOUI_PDF_WORKBENCH_PDFLITE_HELPER` to an already-built
`pdflite_service_cli` executable when you want native Skia runs to use the real
pdflite document model. Use `MOUI_PDF_WORKBENCH_PDFLITE_HELPER=auto` from the
repository root to target the conventional native debug helper path under
`_build/native/debug/build/examples/pdf_workbench/pdflite_service_cli/`.
`MOUI_PDF_WORKBENCH_PDFLITE_HELPER_ARGS` may be a whitespace-separated argument
string or a JSON string array, and
`MOUI_PDF_WORKBENCH_PDFLITE_HELPER_CWD` sets the helper working directory for
fixture or packaged-app smoke runs. When the helper variable is absent, the
entrypoints keep the lightweight document summary fallback but still use PDFium
for page bitmaps.

Focused PDF Workbench checks:

```sh
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/app --target native
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/app --target native --filter 'pdf workbench lightweight smoke covers startup raster navigation search and cache'
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/app --target wasm-gc
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdflite_service_protocol --target native
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdflite_service_protocol --target wasm-gc
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdflite_service_native_transport --target native
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon test moui/backend/host --target native
moon build examples/pdf_workbench/macos_skia --target native
node scripts/pdf-workbench-native-smoke.mjs
scripts/pdf-workbench-macos-smoke.sh
MOUI_PDF_WORKBENCH_STARTUP_PDF=examples/pdf_workbench/fixtures/minimum.pdf moon run examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
```

Because the PDFium provider is a module-level prebuild hook, disable it for
app-only, protocol, native-transport, or `pdflite_adapter` checks when the
raster adapter is not under test.
The named lightweight smoke uses fake document and raster services to exercise
startup open, bitmap drawing, multi-page navigation, search, zoom, and raster
cache reuse without compiling the pdflite helper executable.
`node scripts/pdf-workbench-native-smoke.mjs` is the matching-host real-raster
smoke. It runs the PDFium adapter tests, builds the current host's native Skia
entrypoint, and verifies the log contains the PDFium bitmap path.
`scripts/pdf-workbench-macos-smoke.sh` is a macOS convenience wrapper for the
same runner.

## Command Palette

The Command Palette example keeps command definitions in `@views.ActionCommand`
metadata, renders them through the public palette and command menu views, and
uses `@views.ActionCommandMap` for shortcut dispatch. Disabled commands stay
visible for discoverability but do not dispatch through model actions or runtime
command bindings. Its effect-capable `program_with_services` path demonstrates
`HostAppServices::show_context_menu`, dispatching the selected native menu
command back through the same typed message loop while preserving the view-level
fallback context menu for hosts without native menu support.

## Mo Workbench

Mo Workbench is the native-Skia-first desktop agent dogfood app. The current shared app package is a platform-neutral multi-workspace shell inspired by DeepSeek-GUI: a left workspace rail, center work surface, topbar controls, optional right inspector, and low-noise status bar. Code is the only interactive agent workspace today; it uses an injected `AgentBackendRuntime` stub by default, while the macOS Skia entrypoint can select either the OpenSeek backend or a generic ACP stdio subprocess backend from settings.

The current workspaces are:

- **Code**: session history, message timeline, starter cards, model/thinking controls, prompt composer, steering while streaming, and fixed inspector cards for plan, todo, changes, and context.
- **Write**: product-shaped static Markdown editor/assistant shell. It does not save files or call completion services yet.
- **Connect Phone**: static channel/timeline setup shell for future IM and webhook automation.
- **Scheduled Tasks**: static task cards and defaults panel for future scheduled prompts.
- **Plugins**: static capability summary for future Skills/MCP/Web tool management.
- **Settings**: runtime and permission preferences for backend selection, OpenAI-compatible provider settings, ACP command/args/cwd, working directory, approval policy, sandbox mode, and font size.

The ACP backend implements stdio JSON-RPC as an ACP client/control side. It supports baseline session creation, prompt turns, cancellation, session updates, mode/config updates, and permission requests. It intentionally advertises no client filesystem or terminal capability in this slice.

Focused checks for the current slice:

```sh
moon test examples/mo_workbench/app --target native
moon test examples/mo_workbench/acp_native_transport --target native
moon test examples/mo_workbench/app --target wasm-gc
moon build examples/mo_workbench/macos_skia --target native
```

See [Mo Workbench](mo-workbench.md) for the app architecture, current slice, connector boundary, and transport follow-up notes.

## MoUI Quick Example

MoUI Quick Example (`examples/moui_example`) is a minimal counter app for quick start exploration. It keeps the same `Model / Msg / update / view` pattern as the main Counter example but with a minimal footprint for developers who want to understand the MoUI basics in one file.

The app logic lives in `examples/moui_example/app/` and the code closely mirrors the main Counter example:

```moonbit
using @views {button, card, center, column, row, text}

pub struct Model {
  count : Int
}

pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

pub fn Model::new() -> Model {
  { count: 0 }
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("MoUI Quick Example").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}

pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
```

Run instructions and platform notes: `examples/moui_example/readme.mbt.md`.

Focused MoUI Quick Example checks:

```sh
moon test examples/moui_example/app --target native
moon build examples/moui_example/web_wasm --target wasm-gc
moon check examples/moui_example/macos_skia --target native
moon check examples/moui_example/windows_skia --target native
moon check examples/moui_example/linux_skia --target native
```

Windows Skia run (after MSVC setup, same PowerShell session):

```powershell
. .\scripts\windows\msvc_env.ps1
moon run examples/moui_example/windows_skia --target native
```

Linux Skia run:

```sh
moon run examples/moui_example/linux_skia --target native
```

## Web Wasm-GC

Build any Web example from the repository root, then serve the repository with a
local static server:

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open the corresponding `examples/*/web_wasm/index.html` page from the local
server, or `website/web_wasm/index.html` for the homepage/docs workspace. The
Web path uses `wasm-gc + window/web + browser WebGPU host imports`; there is no
JS-target fallback. Serve from the repository root when testing Website Docs so
the browser can fetch the static `docs/*.md` files by relative path.

## macOS Native

macOS examples use the shared app package plus the macOS host core and renderer
provider packages. The recommended native entrypoints import
`backend/macos/skia` through the `_skia` packages:

```sh
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
moon build examples/mo_workbench/macos_skia --target native
```

The `macos_skia` entrypoints select the native Skia raster renderer explicitly.
They require the local Skia native link setup that makes `moui_skia/native`
available at runtime. Normal macOS Skia runs use the renderer's system
`FontMgr` path; tester-owned first-frame smoke runs explicitly select the
`EmptyTypeface` fallback path. The
`macos_wgpu` and `macos_wgpu_cosmic` packages remain available as native WGPU
and text-provider diagnostics.

After configuring real Skia link flags, run the opt-in real Skia check to verify
both the binding smoke and MoUI renderer presenter pixels:

```sh
scripts/macos-skia-renderer-smoke.sh
```

On macOS, the helper below resolves the pinned JetBrains Skia binary provider,
temporarily wires the resulting include/library paths into `moui_skia`, the MoUI
renderer smoke, Showcase, Markdown Editor, and Mo Workbench `macos_skia`
packages, then runs the renderer pixel smoke and builds the Showcase entrypoint:

```sh
scripts/macos-skia-renderer-smoke.sh
```

Pass `--enable-skshaper` when the selected Skia binary also provides the
SkShaper module libraries; the helper then verifies the MoUI renderer smoke ran
with the optional shaped-run path available.

Direct local `moon run` commands use the `moui_skia` prebuild hook, so the
checked-in packages do not need machine-local path rewrites. Set
`MOUI_SKIA_LINK_MODE=dynamic|static|auto` before `moon run` to choose the Skia
library mode. Helper smoke runs can still use `--link-mode dynamic|static|auto`
to override the environment for that invocation.

For a fuller local smoke, pass `--run-showcase-smoke`. The helper builds
Showcase and then runs the `moui_tester` first-frame smoke. Add
`--run-markdown-smoke` to build Markdown Editor and run the same tester-owned
first-frame marker:

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

Use `--skia-provider existing` when you already have a local Skia build:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Run the generated executable under `_build/native/debug/build/...` for the
example you built. If `moon run` exposes linker issues, use the build-and-execute
flow described in `platform-notes.md`.

To wrap an example as a local `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

The bundle includes and validates a schema version 1
`Contents/Resources/moui-package.json` manifest so local packaging output can be
inspected without parsing `Info.plist`.

## Windows Native

Windows native examples use the MSVC toolchain and vcpkg `zlib:x64-windows`.
The recommended native entrypoints import `backend/windows/skia` through the
`_skia` packages and select the native Skia raster provider explicitly.
`windows_wgpu` and `windows_wgpu_cosmic` packages remain available as native WGPU
diagnostics; the build/package helpers download and bundle `wgpu_native.dll`
only for those WGPU packages.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows_skia `
  -BuildOnly
```

To run an entrypoint directly, import the MSVC environment in the same
PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

`windows_skia` follows the same Skia availability rules as the backend provider:
if `moui_skia/native` is only in fallback mode, renderer creation reports a
diagnostic instead of opening an empty HWND.
Windows Skia example entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners and cite the
smoke log that actually ran.
Markdown Editor also keeps `examples/markdown_editor/windows_wgpu_cosmic` for
explicit Moon Cosmic text-provider comparison on the native WGPU diagnostic
route.

For a reusable distributable folder with the built executable and runtime DLLs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The package is written under `dist\windows-msvc\MoUIShowcase` and includes a
schema version 1 `moui-package.json`, `run.cmd`, and the runtime DLLs needed by
the selected renderer. Skia packages omit `wgpu_native.dll`; WGPU diagnostic
packages include the WGPU release metadata and set `MBT_WGPU_NATIVE_ROOT`
through `run.cmd`.

## Linux Native

Linux examples use the `wzzc-dev/window@0.5.1-0.1.6` Wayland host core. The
recommended native entrypoints use `backend/linux/skia` and present Skia CPU
pixel frames through the Wayland `wl_shm` path. Run them on a configured Linux
host with a Wayland compositor and real Skia link flags:

```sh
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

Linux Skia example entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners and keep those
logs separate from the window package dependency smoke logs.

For build-only validation, use:

```sh
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/linux_skia --target native
```

The `linux_wgpu` and `linux_wgpu_cosmic` Showcase entrypoints remain available for
explicit native WGPU diagnostics. `linux_wgpu_cosmic` selects the shared Moon Cosmic
text provider explicitly, while the platform-default Linux WGPU entrypoint
composes the fontconfig provider scaffold with the same Cosmic fallback. The
Showcase and Markdown Editor `linux_skia` entrypoints select the native Skia
raster renderer explicitly; configure real Skia link flags before relying on
Skia-rendered pixels.

## Example Validation

Use package-level tests for shared app logic and Web builds for browser entry
points:

```sh
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/settings/app --target native
moon test examples/data_table/app --target native
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon test examples/file_importer/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon test examples/command_palette/app --target native
moon test examples/markdown_editor/app --target native
moon test website/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
