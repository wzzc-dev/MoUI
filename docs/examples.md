# Examples

<!-- BEGIN GENERATED PLATFORM TIER MATRIX -->
| Tier | Canonical routes | Gate |
|---|---|---|
| Tier 1 | `macOS Skia`, `Web wasm-gc WebGPU (Canvas2D fallback)` | Blocking: PR build/test, daily presentation, and release evidence |
| Tier 2 | `Windows Skia`, `Linux Skia` | Blocking: L0-L2 and first frame; complete L3 may remain partial |
| Tier 3 | `macOS WGPU (CoreText, Cosmic fallback)`, `Windows WGPU (DirectWrite, Cosmic fallback)`, `Linux WGPU (Fontconfig, Cosmic fallback)`, `Android window-hosted Skia`, `iOS window-hosted Skia`, `HarmonyOS window-hosted Skia`, `macOS Sun`, `Windows Sun`, `Linux Sun`, `WeChat Skyline Canvas2D` | Non-blocking: scheduled/manual build, run, and evidence |

Tier, L0-L3 evidence, and `product_class`/`ready` are independent. Source: `checks/platform-matrix.json`; actual observations remain in `checks/platforms/*.json`.
<!-- END GENERATED PLATFORM TIER MATRIX -->

MoUI examples are runnable documentation. Showcase is the visual catalog and
now follows the same TEA shape as ordinary apps: `Model / Msg / update / view`
driven by `Program::simple_with_environment`. It still contains the Counter and
Todo interaction patterns. The WYSIWYG Markdown editor stays separate because
it demonstrates a larger editing workflow with its own model and parser tests.
Apps that need platform services should capture `AppEnvironment` in the Program
closure and map `ServiceTaskResult` values to `Msg` with `ServiceTask::effect`.
Use `Effect::run` for custom structured runners, `Effect::service_task` when a
service-like one-shot task needs runtime-managed cancellation and stale-dispatch
diagnostics, and `Effect::task` for custom task kinds. Apps that need ongoing
typed callbacks should use `TimerSource` / `RouteSource` or stable custom
`Subscription` keys while keeping concrete host adapters out of `core`.
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
forms, tables, shells, menus, host services, timers, clipboard, window events,
and virtual lists to the examples that exercise them. For a single runnable
surface that packs those host recipes plus canvas paint, open Showcase's
Platform workspace.

Use [App templates](app-templates.md) when starting a new shared app package.
Standalone apps should use `moui new` (see [Getting started](getting-started.md));
the docs skeletons cover counter, dashboard, and document-editor shapes for
monorepo or hand-authored packages. The root `website/` workspace uses the same
app-first shape outside `examples/` so MoUI can render its own bilingual
homepage.

Mobile packaging metadata lives in `moui.mobile.json`. Application code stays
in `examples/<app>/app`; Android, iOS, and HarmonyOS use matching
`*_window_hosted` entrypoints plus the `wzzc-dev/window` templates. The
templates own native lifecycle, surface creation, and input, while the MoUI
entrypoint supplies the program and renderer provider. Run
`sh scripts/window-hosted-hostsim-smoke.sh` after changing the mobile host path.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Website | MoUI-built homepage workspace | `website/app/` | Bilingual product homepage, first-screen MoUI brand hero, compact Counter code snippet, interactive runtime preview, framework foundations, platform matrix, release-readiness cards, quick-start Web commands, runtime Docs portal that fetches packaged same-origin `docs/*.md` Markdown plus MoUI and `moui_skia` README copies, Web-only `website/web_wasm` entrypoint |
| Playground | MoonBit-native browser tutorial and editor | `website/playground/app/`, `website/playground/web_wasm/` | Code editor built with `moui_richtext`, controlled `main.mbt`/`moon.pkg` files, app-safe import validation, pinned MoonBit compiler Worker bridge, sandbox preview host, local persistence, share URL protocol, and six bilingual lesson assets |
| Agent Counter | Minimal agent-controllable runtime example | `examples/agent_counter/`, `examples/agent_counter/main/`, `examples/agent_counter/macos_skia/` | Counter app with semantics/command-intent flow for agent observation and control, plus a native macOS Skia entrypoint |
| Counter | Minimal model/update/view app | `examples/counter/app/` | Simple `Program::simple` flow with retained macOS Skia and Web entrypoints |
| Multi Window | Host-managed scene example | `examples/multi_window/app/` | Independent runtimes through the module-root integration facade, with retained macOS and Web routes |
| HarmonyOS Demo | Standalone experimental HarmonyOS app model | `examples/harmonyos_demo/app/` | Platform-neutral viewport/tap feedback; platform probing belongs to Showcase/tester |
| Button Freeze Probe | Native Skia button freeze repro | `examples/button_freeze_probe/app/` | Minimal button/filter repro with a retained macOS Skia entrypoint |
| Showcase | Unified component, pattern, platform, and diagnostic catalog | `examples/showcase/app/` | Strict TEA root over Components, Patterns, Platform, and pure diagnostic DTOs; module-root integration adapts runtime/render facts. Showcase alone covers all 14 canonical routes. |
| Design Systems | Addon diagnostic theme sampler | `examples/design_systems/app/`, `examples/design_systems/{web_wasm,macos_skia}/` | Source-mapped design-system diagnostics with retained Web and macOS Skia entrypoints |
| Settings | Settings shell pattern | `examples/settings/app/` | Form sections, sidebar navigation, segmented theme mode, toggle preferences, saveable state snapshot/restore |
| Data Table | Operational data browser pattern | `examples/data_table/app/` | Search/filter toolbar pattern, status chips, `ColumnVisibilityState`, sortable table headers with `DataSortState`, app-owned column width/order state, row selection with `SelectionState`, selection toolbar actions, tree filters, loading/error/empty states, `PaginationState`, public `pagination` and `detail_panel`, model-level filtering and data slicing |
| Excel | Spreadsheet workbook prototype | `examples/excel/app/`, `examples/excel/{cell,formula,sheet,xlsx}/`, `examples/excel/macos_skia/` | Native `.xlsx` workflow, spreadsheet shell, formulas, editing, and typed file services |
| File Importer | File import workflow pattern | `examples/file_importer/app/` | Drop zone plus typed `ServiceTaskResult` success/failure/cancellation flow |
| WebView Demo | Native platform WebView pattern | `examples/webview_demo/app/` | Controlled WebView with retained macOS Skia entrypoint |
| DSH Desktop | Thin DeepSeek Harness WebView host | `examples/deepseek_harness_desktop/app/` | Native macOS WKWebView, Windows WebView2, and Linux WebKitGTK surfaces for an existing local Harness Host, with no duplicated Web UI state |
| Browser | Pure-MoonBit HTML browser demo | `examples/browser/app/`, `examples/browser/engine/` | crater (HTML/CSS/paint) + dowdiness/js_engine (pure-MoonBit JS) rendered through MoUI canvas: address bar, link hit-testing, data-URL navigation, page scripts |
| PDF Workbench | PDF reading and light editing prototype | `examples/pdf_workbench/app/` | Typed binary file services, PDF adapters, and retained macOS Skia entrypoint |
| Command Palette | Command metadata and menu pattern | `examples/command_palette/app/` | Command palette, typed `ProgramCommand`, and context-menu service flow through the same TEA queue |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, primary rich text editor, optional source preview |
| Code Editor | Native code editor shell and language-provider prototype | `examples/code_editor/app/` | Native `moui_richtext` editor shell with activity rail, file tab, line-number gutter, status bar, tokenizer-backed highlighting, bracket matching, auto indentation, multi-cursor edits, hidden find/replace overlay, runtime action-command shortcuts, completion overlay, diagnostics, hover, go-to-definition, main-editor Diff mode, and custom language/provider registration through app-owned callbacks |
| Terminal | PTY-backed terminal emulator | `examples/terminal/app/` | Screen buffer (cells/attrs/wide chars/scroll region/scrollback), VT/ANSI parser (SGR/cursor/erase/OSC title/modes), run-merging mono rendering with 16/256/truecolor, native `openpty`+`posix_spawn` PTY host with async read loop, keyboard input encoding (Ctrl/special/function keys), ⌘-arrow scrollback review, and a macOS Skia entrypoint |
| Mo Desktop | macOS-inspired responsive desktop simulation | `examples/mo_desktop/app/` | Lock/unlock session, image wallpaper, menu bar, live dock, calendar/weather/task widgets, responsive Finder with navigation/search/icon-list modes/selection, Safari start page and search results, searchable Apps/Actions launcher, notifications, Control Center toggles/sliders, global light/dark appearance, Web wasm-gc and macOS Skia entrypoints |
| Mo Workbench | Native-Skia-first desktop agent dogfood app | `examples/mo_workbench/app/` | Work/Code/Design task shell with a session dashboard, interactive coding-agent chat, product-state/palette preview, responsive searchable task sidebar, settings overlay, backend-aware OpenSeek/ACP controls, injected stub backend, OpenSeek native transport, generic ACP stdio native transport, and a macOS Skia entrypoint |

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
GitHub Pages workflow packages `website/web_wasm` at the site root, plus
`examples/showcase/web_wasm` at `/showcase/` and
`examples/markdown_editor/web_wasm` at `/markdown-editor/`, using
`scripts/package-web-app.mjs` for release/strip wasm, local runtime JS,
precompressed assets, and `bundle-size.json`. It then runs
`node scripts/sync-website-docs.mjs --out dist/pages/docs` so the published
Website Docs page fetches the same Markdown paths from `docs/`.

The `website/web_wasm` entrypoint ships a static fallback view
(`fallback.js`): browsers without WebAssembly or without the wasm-gc
extension get a Canvas2D brand hero, a showcase screenshot gallery, and the
docs catalog / Markdown reader instead of a blank canvas. Detection is
synchronous for missing WebAssembly and `WebAssembly.validate` on the
downloaded wasm for missing wasm-gc; other Web examples keep the fail-clearly
behavior.

## Counter

Counter is the smallest recommended app shape. It keeps user code in
`Model / Msg / update / view`, then lets `Program::simple` connect that pure
model loop to the runtime. It retains Web and macOS Skia entrypoints; use
Showcase for the full platform matrix:

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
moon build examples/counter/macos_skia --target native
```

Fallback APK and `.app` builds validate packaging paths only. Use a matching
device or simulator smoke before claiming first-frame runtime support.

## HarmonyOS Demo

HarmonyOS Demo is retained as a platform-neutral app model with visible tap and
viewport feedback. Its standalone platform composition root was retired;
Showcase is the sole canonical HarmonyOS route and owns the matching
window-hosted application. The `wzzc-dev/window/harmonyos` template owns the
Stage Ability and XComponent bridge.

Focused HarmonyOS Demo checks:

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
moui build harmonyos showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json" --fallback-skia
```

For real HarmonyOS Skia checks, use the locked HarmonyOS release artifact:

```sh
MOUI_SKIA_PLATFORM=harmonyos MOUI_SKIA_ARCH=arm64 MOUI_SKIA_LINK_MODE=static \
  moon check examples/showcase/harmonyos_window_hosted --target native
```

HarmonyOS `auto` / `skia-gpu` builds require the complete static provider. The
locked shared `libskia.so` is usable for raster rendering, but hides Ganesh
internal symbols referenced by `libskia_ganesh_ext.a`; use dynamic linking only
with explicit `skia-raster`. Leaving `MOUI_SKIA_LINK_MODE` unset lets the shell
builder choose static for GPU and dynamic for raster.

Fallback HAP builds validate MoonBit C/native glue/staged package shape only.
Use a matching device or emulator smoke before claiming HarmonyOS first-frame
runtime support.

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
into the MoUI framework. The app declares shortcut metadata as typed
`ProgramCommand` values; the composition root does not install an app-owned
mutation callback.

Focused Code Editor checks:

```sh
moon test examples/code_editor/app --target native
moon check examples/code_editor/macos_skia --target native
```

## WebView Demo

WebView Demo shows the native platform-view path without involving renderer
draw commands. The shared app owns controlled navigation state: a page link
emits `NavigationRequested`, the model updates `url`, and the host commits the
real native WebView to the next `DrawFrame.platform_views` rectangle. Buttons
exercise the host command queue for load, reload, stop, back, forward, and
JavaScript evaluation.

The retained macOS entrypoint passes `HostWebViewCommandQueue` through platform
host options, so `WKWebView` can drain commands after rendering. Windows
WebView2 and Linux WebKitGTK remain backend capabilities covered by backend and
matching-host probes rather than separate demo composition roots.

Focused WebView Demo checks:

```sh
moon test examples/webview_demo/app --target native
moon check examples/webview_demo/macos_skia --target native
```

## DSH Desktop

DSH Desktop is a thin native WebView host for a local DeepSeek Harness surface.
The DSH Web UI owns navigation, sessions, profiles, settings, and plugin UI.
The shared app only supplies the WebView surface and a native-unavailable
fallback. The macOS, Windows, and Linux composition roots select the matching
WKWebView, WebView2, or WebKitGTK plugin together with the Skia provider route.
The default surface is `http://127.0.0.1:3080`. `Settings…` (`Cmd+,`) edits both
root URLs and the `System`/`Dark`/`Light` theme mode in a MoUI modal. URL and
theme values persist through macOS settings before applying. Saving the current
URL leaves the existing page intact. The resolved theme background is applied to
the native WebView before navigation, so a light host and dark Chat page (or the
reverse) do not flash white or black. The modal uses
the targeted full-window WKWebView overlay path and restores WebView input when
closed. macOS also reserves a 32-point top drag region;
interactive DOM controls and `[data-moui-no-drag]` elements remain clickable
inside it.

Focused DSH Desktop checks:

```sh
moon test examples/deepseek_harness_desktop/app --target native
moon check examples/deepseek_harness_desktop/macos_skia --target native
moon check examples/deepseek_harness_desktop/windows_skia --target native
moon check examples/deepseek_harness_desktop/linux_skia --target native
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
  should restore route focus after a route switch. `@services.RouteSource` provides
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
owns the MoUI application, TEA messages, host-service file effects, and command map,
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

The File Importer example demonstrates strict TEA service flow. The view emits
`BrowseRequested`; the Program closure captures `AppServices` and returns
`files().open_file(...).effect(...)`. Success, failure, and cancellation are
typed messages handled by `update`. Host request ids and completion queues do
not enter the model. Child composition lifts the view and effect with
`View::map` and `Effect::map`.

Browser hosts commonly expose file names while native hosts can expose
filesystem paths, so treat returned strings as service-defined handles.

## PDF Workbench

PDF Workbench is a MoUI example-level PDF reader and light editor. Its shared
app package is intentionally a lightweight UI shell so the native Skia
entrypoint does not pull the full PDF parser into one huge generated C
translation unit. The app keeps host interaction in TEA effects: open uses a
file dialog followed by `AppServices::files().read_bytes`, while save and
save-as write through `AppServices::files().write_bytes`; save-as defaults
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
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/app --target native --filter 'pdf workbench lightweight smoke covers startup raster navigation search and cache'
moon test examples/pdf_workbench/app --target wasm-gc
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target wasm-gc
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdfium_adapter --target native
moon test moui/backend --target native
moon build examples/pdf_workbench/macos_skia --target native
node scripts/pdf-workbench-native-smoke.mjs
scripts/pdf-workbench-macos-smoke.sh
MOUI_PDF_WORKBENCH_STARTUP_PDF=examples/pdf_workbench/fixtures/minimum.pdf moon run examples/pdf_workbench/macos_skia --target native
```

The PDFium provider is a module-level prebuild hook, but it does not download
PDFium by default. Set `MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1` only for real
raster adapter validation, or provide `MOUI_PDFIUM_INCLUDE` plus
`MOUI_PDFIUM_LIB_DIR` to use a local PDFium install.
The named lightweight smoke uses fake document and raster services to exercise
startup open, bitmap drawing, multi-page navigation, search, zoom, and raster
cache reuse without compiling the pdflite helper executable.
`node scripts/pdf-workbench-native-smoke.mjs` is the matching-host real-raster
smoke. It runs the PDFium adapter tests, builds the current host's native Skia
entrypoint, and verifies the log contains the PDFium bitmap path.
`scripts/pdf-workbench-macos-smoke.sh` is a macOS convenience wrapper for the
same runner.

## Command Palette

The Command Palette example keeps command definitions in
`@views.ActionCommand` metadata and declares typed messages with
`Program::with_commands`. Disabled commands remain visible but do not enqueue
messages. Native context-menu selection uses `MenuServices::show_context` and
returns through the same typed update queue as keyboard shortcuts and view
commands.

## Mo Desktop

Mo Desktop is a platform-neutral desktop simulation inspired by the macOS 27
reference. It starts on a full-screen lock surface and unlocks into a layered
desktop with persistent menu and dock chrome. Finder is the primary workspace;
Safari, the app launcher, Control Center, and Notification Center share the
same typed model and update path. Narrow viewports hide decorative widgets,
collapse Finder's sidebar into location tabs, and keep the dock and overlays
inside the available canvas.

The example intentionally implements a smaller set of working apps and system
surfaces instead of rendering inactive dock placeholders. Finder navigation,
search, view modes, and selection are controlled; Safari supports a start page
and query results; Control Center owns appearance, connectivity, brightness,
volume, and battery preferences; Notification Center owns read state and task
completion.

Focused checks:

```sh
moon test examples/mo_desktop/app --target native
moon test examples/mo_desktop/app --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build examples/mo_desktop/macos_skia --target native
```

## Mo Workbench

Mo Workbench is the native-Skia-first desktop agent dogfood app. Its portable
shared app package is a  `Work` / `Code` / `Design` task shell with a
responsive task sidebar and injected `AgentBackendRuntime`; the macOS Skia
entrypoint selects OpenSeek or a generic ACP stdio subprocess backend from
settings.

The current surfaces are:

- **Work**: session summary cards, next actions, and recent tasks. Review,
  Running, and All task actions open the Code tab with the matching sidebar
  filter.
- **Code**: session history, message timeline, starter cards, model/thinking or
  ACP controls, prompt composer, steering while streaming, and permission
  responses.
- **Design**: live task/model/settings/typography state plus control and palette
  previews; it is not a design-document editor.
- **Settings overlay**: API, Agent, and Editor preferences for backend/provider
  configuration, ACP command/args/cwd, working directory, approval policy,
  sandbox, appearance, and font size.

The sidebar supports task search, status filters, expandable task groups,
settings, and the appearance toggle.

The ACP backend implements stdio JSON-RPC as an ACP client/control side. It supports baseline session creation, prompt turns, cancellation, session updates, mode/config updates, and permission requests. It intentionally advertises no client filesystem or terminal capability in this slice.

Focused checks for the current slice:

```sh
moon test examples/mo_workbench/app --target native
moon test examples/mo_workbench/acp_native_transport --target native
moon test examples/mo_workbench/app --target wasm-gc
moon build examples/mo_workbench/macos_skia --target native
```

See [Mo Workbench](mo-workbench.md) for the app architecture, current slice, connector boundary, and transport follow-up notes.

## Web Wasm-GC

Build any Web example from the repository root, then serve the repository with a
local static server:

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open the corresponding `examples/*/web_wasm/index.html` page from the local
server, or `website/web_wasm/index.html` for the homepage/docs workspace. The
Web path uses `wasm-gc + window/web + browser WebGPU host imports`; there is no
JS-target fallback. Serve from the repository root when testing Website Docs so
the browser can fetch the static `docs/*.md` files by relative path.

For release-size checks and packaged Web artifacts, use:

```sh
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
node scripts/package-web-app.mjs examples/counter/web_wasm --out artifacts/web/counter
```

The package helper emits release/strip wasm, MoUI Web runtime JS, precompressed
`.gz`/`.br` siblings, `bundle-size.json`, and any files under the Web entrypoint
`assets/` directory. Keep large app resources out of MoonBit source: small
constants can remain in code, but large images, long Markdown, large JSON, and
fixtures should live under `assets/` and be referenced with relative URLs such
as `assets/logo.png` or `assets/story/buttons.json`. Web text/Markdown/JSON
loads must stay same-origin; the browser host rejects cross-origin text-file
fetches.

## macOS Native

macOS examples use the shared app package plus `backend/macos` and an explicit
renderer package. The recommended `_skia` entrypoints import `moui_skia_renderer` and
compose it with `@macos.entry()` through `@runtime.run_app`:

```sh
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/mo_desktop/macos_skia --target native
moon build examples/mo_workbench/macos_skia --target native
```

The `macos_skia` entrypoints select the native Skia raster renderer explicitly.
They require the local Skia native link setup that makes `moui_skia/native`
available at runtime. Normal macOS Skia runs use the renderer's system
`FontMgr` path; tester-owned first-frame smoke runs explicitly select the
`EmptyTypeface` fallback path. The
Showcase `macos_wgpu` remains the canonical native WGPU diagnostic with Cosmic as an internal fallback.

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
to override the environment for that invocation. HarmonyOS is stricter:
`auto` / `skia-gpu` must resolve to static, while dynamic is supported only for
explicit `skia-raster`.

For a fuller local smoke, pass `--run-showcase-smoke`. The helper builds
Showcase and then runs the unpublished `moui_tests` first-frame smoke. Add
`--run-markdown-smoke` to build Markdown Editor and run the same internal
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
The recommended `_skia` entrypoints import `backend/windows` plus
`moui_skia_renderer` and compose them explicitly through `@runtime.run_app`.
Showcase `windows_wgpu` remains the canonical native WGPU diagnostic; the build/package helpers download and bundle `wgpu_native.dll`
only for those WGPU packages.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
```

To run an entrypoint directly, import the MSVC environment in the same
PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
```

`windows_skia` follows the same Skia availability rules as the backend provider:
if `moui_skia/native` is only in fallback mode, renderer creation reports a
diagnostic instead of opening an empty HWND.
Windows Skia example entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners and cite the
smoke log that actually ran.
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

Linux examples use the `wzzc-dev/window@0.5.4-0.1.5` Wayland host core. The
recommended native entrypoints compose `backend/linux` with `moui_skia_renderer` and
present Skia CPU pixel frames through the Wayland `wl_shm` path. Run them on a configured Linux
host with a Wayland compositor and real Skia link flags:

```sh
moon run examples/showcase/linux_skia --target native
```

Linux Skia example entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners and keep those
logs separate from the window package dependency smoke logs.

For build-only validation, use:

```sh
moon build examples/showcase/linux_skia --target native
```

Showcase `linux_wgpu` remains the canonical native WGPU diagnostic and composes fontconfig with Cosmic as an internal fallback. `showcase/linux_skia` is the canonical Linux Skia evidence route.

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
moon test examples/mo_desktop/app --target native
moon test website/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
