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
source-mapped preview UI so Showcase remains a MoUI framework catalog and does
not depend on `moui_theme`. Design Systems has Web wasm-gc and macOS, Windows,
and Linux Skia entrypoints for trying the addon sampler outside the framework
Showcase.

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
| Counter | Minimal model/update/view app | `examples/counter/app/` | Simple `Program::simple` flow, `center`/`card`, typed button messages |
| Button Freeze Probe | Native Skia button freeze repro | `examples/button_freeze_probe/app/` | Minimal `data_filter_bar` filter chips, red primary accent, repeated click counter, direct primary/tonal button comparison, native Skia macOS/Windows/Linux entrypoints |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | TEA-first `Model / Msg / update / view` app, public `views` constructors, validating form fields and workflow bars, `ToastQueue`-backed toast stack/progress/status surfaces, `status_badge` feedback chips, helper-backed table/selectable-list data views, column visibility panel, route header/section-nav/sidebar/breadcrumb shells with app-owned route/deep-link history and route focus restore evidence, custom dialog/alert/sheet/menu surfaces, built-in Counter/Todo patterns, light Markdown preview, neutral core theme toggling, presentation, renderer capability status, advanced rendering demos, text diagnostics, interaction wiring. Showcase intentionally has no `moui_theme` dependency and is not an official design-system compatibility proof. |
| Design Systems | Source-mapped design-system preview and parity sampler | `examples/design_systems/app/`, `examples/design_systems/{web_wasm,macos_skia,windows_skia,linux_skia}/` | Material, Carbon, Primer, and Fluent switching through the `moui_theme/material`, `moui_theme/carbon`, `moui_theme/primer`, and `moui_theme/fluent` entrypoints over shared `moui_theme/common` models, light/dark/high-contrast/system variants, compact/standard/comfortable density, semantic palette roles, typography specimen, spacing/density grid, component-token matrix sampling, component style bundle usage, custom inheritance/override API, Web and native Skia host entrypoints, coverage/parity status labels, and explicit source-mapped preview wording rather than official-complete claims |
| Settings | Settings shell pattern | `examples/settings/app/` | Form sections, sidebar navigation, segmented theme mode, toggle preferences, saveable state snapshot/restore |
| Data Table | Operational data browser pattern | `examples/data_table/app/` | Search/filter toolbar pattern, status chips, `ColumnVisibilityState`, sortable table headers with `DataSortState`, app-owned column width/order state, row selection with `SelectionState`, selection toolbar actions, tree filters, loading/error/empty states, `PaginationState`, public `pagination` and `detail_panel`, model-level filtering and data slicing |
| File Importer | File import workflow pattern | `examples/file_importer/app/` | Drop zone, file dialog facade, unavailable service state, pending completion handling, selected file list |
| WebView Demo | Native platform WebView pattern | `examples/webview_demo/app/` | Controlled `web_view` primitive, native host capability fallback, address bar, navigation commands, JavaScript evaluation command, macOS/Windows/Linux Skia native entrypoints, Web wasm unavailable fallback without iframe |
| PDF Workbench | PDF reading and light editing prototype | `examples/pdf_workbench/app/` | Clean native PDF reader/editor shell, host binary file service open/save flow, PDFium page bitmap preview, fit-width responsive reading canvas, scrollable page/inspector panels, reader fullscreen toggle, page navigation/direct page jump/search/metadata summaries, undoable/discardable preview rotate/crop/stamp/title/bookmark/note edit state, separate `pdflite_adapter` package for real parsing/writeback checks, JSONL pdflite helper protocol plus native process transport, native-only `pdfium_adapter` package for page rasterization, macOS/Windows/Linux Skia native entrypoints |
| Command Palette | Command metadata and menu pattern | `examples/command_palette/app/` | Command palette rows, shortcut labels, enabled/disabled dispatch, command menu, context menu fallback, `runtime_with_services`, and `HostAppServices::show_context_menu` native menu preview |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, primary rich text editor, optional source preview |
| Mo Workbench | Multi-backend agent desktop dogfood app | `examples/mo_workbench/app/` | Codex-style conversation-first coding-agent shell, quiet Agent-branded default UI, signal-only current-agent top-bar chip, expanded-options backend selector, Pi, ACP Demo, and Local backend capabilities, connector runtime fixture, capability-gated advanced controls, lightweight agent focus routing, composer slash-command suggestions, wide three-panel inspector with context/run/diagnostic tabs, low-noise status bar, current task strip, compact current-turn evidence fallback on narrow layouts, backend-neutral backend-status/runtime-signal/session/model/metrics/fork/input-setting/provider-registry/activity/request/composer/timeline/status projections, platform-neutral Pi transport command/event model for the Pi provider, Workbench-to-Pi session binding, manual RPC session refresh, fresh Pi session creation, RPC model/message transcript refresh, explicit model selection, fork candidate discovery and fork refresh, HTML export evidence, manual context compaction, RPC command catalog invocation and session stats refresh, thinking-level and input queue mode controls, RPC bash command evidence, failed-command fix prompts, RPC response plus streaming agent/tool/plan event ingestion, command/file/diff/plan transcript evidence, stderr/nonzero-exit diagnostics, macOS Skia native entrypoint |

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
model loop to the runtime. It has Web, macOS, Windows, Linux, and
`windows_wgpu_cosmic` entrypoints, so it is also the quickest way to verify a thin
platform package without the full Showcase surface:

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

pub fn view(model : Model) -> @core.View[Msg] {
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
```

Focused Counter checks:

```sh
moon test examples/counter/app --target native
moon build examples/counter/web_wasm --target wasm-gc
```

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
Windows/Linux real WebView builds are opt-in: set the matching
`MOUI_WINDOWS_WEBVIEW2_*` or `MOUI_LINUX_WEBKITGTK_*` environment variables so
the `moui` prebuild can add native dependency flags; otherwise those
entrypoints compile as unavailable fallbacks.

Focused WebView Demo checks:

```sh
moon test examples/webview_demo/app --target native
moon check examples/webview_demo/macos_skia --target native
moon check examples/webview_demo/windows_skia --target native
moon check examples/webview_demo/linux_skia --target native
moon check examples/webview_demo/web_wasm --target wasm-gc
```

Showcase is organized around the main catalog order:
`Overview -> Text & Media -> Controls -> Forms -> Data -> Layout -> Navigation
Shell -> Feedback -> Runtime/Renderer -> Diagnostics`. The first eight sections
cover user-facing components and layout patterns. `Runtime/Renderer` displays
host capability and renderer status cards. `Diagnostics` shows a compact
inspector snapshot with runtime, TEA program message/effect task/subscription,
duplicate key names, view, layout, semantics, render command, and render-scope
counters, then links to the deeper diagnostic routes for
interaction wiring, text diagnostics, advanced rendering, and reusable examples
without crowding the main sidebar.

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
  first-invalid focus targets, and submit-guard evidence for the form workflow
  bar.
- `Navigation Shell`: route headers, section navigation, breadcrumbs, dialogs,
  sheets, command metadata, app-owned route/deep-link history, a controlled
  fade/slide route transition preview, a controlled drag-resizable split pane,
  and `RouteFocusStore` evidence showing which `runtime.focus_key(...)` call
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
For first-frame smoke, set `MOUI_PDF_WORKBENCH_STARTUP_PDF` to a PDF path such
as `examples/pdf_workbench/fixtures/minimum.pdf` alongside the platform
`MOUI_PDF_WORKBENCH_*_SKIA_EXIT_AFTER_FIRST_PRESENT=1` flag; the startup path
uses the same binary-read, document-load, and PDFium raster request flow as the
Open button.
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
MOUI_PDF_WORKBENCH_STARTUP_PDF=examples/pdf_workbench/fixtures/minimum.pdf MOUI_PDF_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/pdf_workbench/macos_skia --target native
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
smoke. It runs the PDFium adapter tests, launches the current host's native
Skia entrypoint with the fixture PDF and first-frame exit flag, then verifies
the log contains the PDFium bitmap path and platform first-frame marker.
`scripts/pdf-workbench-macos-smoke.sh` is a macOS convenience wrapper for the
same runner.

## Command Palette

The Command Palette example keeps command definitions in `ActionCommand`
metadata, renders them through the public palette and command menu views, and
uses `ActionCommandMap` for shortcut dispatch. Disabled commands stay visible
for discoverability but do not dispatch through model actions or runtime command
bindings. Its effect-capable `runtime_with_services` path demonstrates
`HostAppServices::show_context_menu`, dispatching the selected native menu
command back through the same typed message loop while preserving the view-level
fallback context menu for hosts without native menu support.

## Mo Workbench

Mo Workbench is the real product-shaped dogfood app for the native Skia route.
It is named `Mo Workbench` with the subtitle `Agent 桌面工作台`, and starts as a
Codex / Claude Code-style multi-backend coding-agent workbench for project
sessions, assistant transcripts, command evidence, diff/file context, and
diagnostics. Pi RPC is the first real backend provider, ACP Demo is a fixture
connector for Agent Connect Protocol style profile/session/message flow, and
Local (`fixture`) is the smoke backend used to verify backend switching and
keep the product shell agent-neutral.
Its current UI uses a compact Codex-like desktop chrome with a lower-left
settings entry for light/dark appearance and workbench preferences, and keeps
the first screen focused on the current task strip, the transcript thread, a
right-side workbench inspector on wide windows, and a bottom composer instead
of long placeholder validation text,
future-workflow filler, or hard-coded attachment cards. The shell now derives
its sidebar, main canvas, scroll area, and composer dimensions from the runtime
viewport instead of a fixed `1200x750` surface, so the macOS Skia entrypoint can
be resized while preserving the session-first hierarchy, including narrower
composer widths in smaller windows. The top bar renders the active session as
one two-line identity block with shortened title, project, and branch labels,
so long paths remain in shared state and transport commands without clipping
the visible chrome. Wide layouts now separate `上下文`, `运行`, and `诊断` into a
compact inspector with empty/error/loading states, expandable command output,
file/diff context, diagnostic fix/clear actions, focused-check shortcuts, and a
low-noise status bar; compact layouts keep the single `当前证据` card in the
conversation flow. The transcript uses compact multi-line message rows for
long Pi replies and draws an explicit scrollbar when the main workflow
overflows. New prompts, local fixture replies, Pi response events, and queued
command evidence pin that scroll area to the latest content. The sidebar also
has a default-visible `新对话` action that immediately creates and selects a new
Workbench session in task history, while the Pi-specific `新会话` RPC control
remains in expanded composer options for replacing the provider session binding.
Message rows no longer expose a message-level `跟进` action.
Matching Pi fork candidates render as a small Codex-style `分叉` affordance
directly under the corresponding assistant reply, including candidates whose
`entryId` points at the preceding user message. Primary UI copy now follows the Codex-style hierarchy:
`当前任务` for the single next action and `当前证据` for the one compact evidence
surface, with Pi/RPC left as provider/protocol nouns. The top bar keeps only
session identity by default; the current-agent chip appears there only for
non-default backends or provider failures, while normal Pi startup/running state
is folded into the compact `Agent：...` task signal. Backend switching plus
refresh/new-session actions share one compact `Agent` row inside expanded
composer options so the default shell stays conversation-first. Provider
descriptions stay out of that row instead of becoming debug prose, and the top
bar gives removed action-button space back to the current session title; hidden
backend/status chips do not reserve width in quiet sessions. The default session can switch between Pi and Local without restarting the app. Switching
clears provider-specific transcript, catalog, fork, metrics, command,
diagnostic, and transport state so evidence from one backend does not leak into
another; the switch event is kept as control history and does not mount a
`当前证据` card by itself. Default chrome uses short project
names and signal-bearing localized session status labels while keeping full
`project_path` values in the shared model and transport commands. The default
shell keeps the composer input prominent and gates refresh/new-session plus
advanced actions by backend capability instead of showing every RPC control.
Active/idle session rows omit status meta instead of showing fake active, queue,
or idle labels; context chips, model/session stats, agent focus controls,
advanced session actions, steering / follow-up composer controls, and
focused-check presets appear once expanded composer options, non-default
context, selected focus, supported backend capabilities, or actionable
diagnostics without command evidence make them relevant. Local keeps prompt
flow local and hides Pi-only controls such as fork, HTML export, model catalog,
thinking level, and input queue modes. The current-turn evidence card includes the
highest-priority command evidence, latest actionable diagnostic or diff summary,
file evidence, or actionable agent/tool timeline event without adding a separate
diagnostics page. Raw transport lifecycle events such as process start and JSONL
send/receive stay out of `当前证据`; normal backend activity is summarized in the
compact Agent task signal instead. Pi bash exit/cancel diagnostics stay in
shared state but are hidden from the card when command evidence already shows
the same failure. When actionable
evidence is present, the current task strip derives one quiet `下一步` row that points
to the next shared-app action, prioritizing cancelable Pi work, failed command
evidence, diagnostics, active plan steps, reviewable diffs, files, and other
independent action signals. Generic transcript-only and event-only activity no
longer creates a duplicate `下一步` row. Failed-command next actions carry the compact command
label plus Pi's exit code and an output-available summary when available,
keeping the repair loop actionable without opening another panel. Command rows
default to collapsed summaries and mount stdout/log details only after
expanding the row; workspace diff summaries follow the same pattern, with
expanded diff details available on demand. Pi `plan_update` JSONL also
feeds a compact `当前计划` row so the visible session state includes current
planning evidence without opening a separate pane. The default fixture no
longer injects mock transcript, sample stats, command catalog rows, file rows,
diff rows, command runs, diagnostic prose, or sample active-task copy. Zero
queues, unbound Pi state, idle transport/agent state, and empty evidence actions
stay visually quiet; transcript rows and the `当前证据` card stay unmounted until
agent, command, or workspace evidence arrives. The empty main canvas shows only a
quiet session-start prompt, not fake task or evidence content. While Pi is still streaming,
Agent status, active tools, and command evidence stay visible; after the
assistant reply is complete, that process evidence collapses into a compact
`已处理` row that can be expanded to inspect the tool, command, and event trail
without crowding the final reply. Assistant `thinking` / `toolCall` content and
Pi `toolResult` / bash transcript entries are treated as process evidence, so
they stay out of the main conversation rows unless `已处理` is expanded.
On wide windows, the shell uses one right inspector instead of the old
progress/execution/work-folder multi-card rail. `上下文`, `运行`, and `诊断` tabs
separate file/diff context, active tools and command output, and fixable
diagnostics; the default tab follows the most actionable evidence while raw
transport lifecycle events stay out of `当前证据`. The inspector collapses on
compact widths so the conversation flow remains primary and the single evidence
card remains the narrow-layout fallback.
Pi `message_end` / `agent_end` JSONL updates merge assistant replies into the
local transcript immediately, while a lightweight RPC refresh follows to
reconcile the full message, fork, and stats state. The default sidebar now stays
focused on brand and task history, while project and branch identity remain in
the top bar instead of repeating as a workspace card or empty-state line.
Lightweight `通用`, `编码`, and `校验` focus controls now share one compact
composer `范围` row with repository, examples, evidence, and backend session
context chips. The row appears after opening composer options, after selecting a
focus, or after changing the default context; direct prompt, steering, and
follow-up submits still prefix the selected scopes into the same
platform-neutral text payloads, while turning all chips off sends the raw input.
Selecting a focus only appends an `agent focus: ...` hint to those same payloads.
Current-turn event rows are
read-only process evidence in the shell; they do not expose message-level
follow-up controls. File context
rows can queue an `Inspect <path>` prompt through the same platform-neutral
prompt transport, turning Pi-provided file evidence into the next coding-agent
action. The diff summary review button likewise queues a concise
`Review diff: ...` prompt, so code review starts from shared app state rather
than a native-only shortcut.
Latest diagnostic rows can queue a `Fix <severity> diagnostic from <source>: ...`
prompt through the same `SendUserInput` path while preserving the current
context chips and selected agent focus, turning build/check failures into the
next agent task without adding a transport-specific command.
The shared app package keeps the Pi boundary as platform-neutral
`PiTransportCommand` and `PiTransportEvent` values so future Web or
automation-focused workflows can reuse the same event model. Structured Pi
JSONL payloads such as command starts/completions, diagnostics, file context,
and diff summaries are ingested inside the shared app model rather than the
native process driver. The native transport also exposes a
`PiNativeTransportOwner` so the macOS Skia entrypoint can keep one
`pi --mode rpc` JSONL process alive across repeated app runtime dispatches
while the shared app remains platform-neutral. Native stderr is surfaced as a
platform-neutral warning event and nonzero process exits become
`TransportFailed` events with the exit code and last stderr line. Unexpected
child exits do not close the native owner; the next UI command batch restarts a
fresh JSONL process, while explicit `Shutdown` remains the close path. The
native encoder targets Pi's actual RPC command names: `get_state`,
`new_session`, `prompt`, `steer`, `follow_up`, `get_available_models`, `get_messages`,
`get_fork_messages`, `fork`, `get_commands`, `get_session_stats`,
`export_html`, `set_model`, `cycle_model`, `compact`, `cycle_thinking_level`,
`set_steering_mode`, `set_follow_up_mode`, `set_session_name`, `bash`,
`abort_bash`, and `abort`, with process shutdown handled by stdin EOF. The
focused smoke for machines with Pi installed is an
offline `get_state` JSONL round trip, a `new_session` acknowledgement, a
`get_messages` transcript response, an offline `get_available_models` model
catalog response, an offline `get_commands` command-catalog response, an
offline `get_fork_messages` response, a `get_session_stats` metrics response,
the expected in-memory `export_html` failure boundary, a
`set_model` no-matching-model failure boundary, a
`cycle_model` no-alternate-model acknowledgement, a
`compact` offline failure boundary, a
`cycle_thinking_level` acknowledgement,
steering/follow-up mode acknowledgements, a `set_session_name`
acknowledgement, steering/follow-up input acknowledgements, and an `abort_bash`
acknowledgement through `pi --mode rpc`,
so it validates the process protocol without requiring a successful model call.
The shared
app ingests
successful and failed Pi RPC `response` JSONL objects: `get_state` refreshes
the current Workbench session snapshot, `get_messages` refreshes the transcript
model, `get_available_models` refreshes the compact model catalog,
`get_fork_messages` refreshes forkable user-message entry ids, `get_commands`
refreshes the available slash/prompt/extension/skill command catalog, and
`get_session_stats` refreshes compact message/tool/token/context metrics that
the session panel consumes through the backend-neutral `AgentSessionMetrics`
projection.
`export_html` success responses add the returned path as current-turn file
evidence, so exported sessions can become handoff, documentation, or knowledge
artifacts without native-only state. Catalog entries can run a command by
sending `/<name>` through the same platform-neutral `SendUserInput` prompt
path, so native transport does not need a command-specific bridge. Typed slash
prompts such as `/review` are sent raw rather than wrapped in composer context.
When command catalog entries are available and the prompt starts with `/`, the
composer hides context/focus/steering controls and shows up to three filtered
slash-command suggestions plus the normal send action. Those suggestions reuse
the same `InvokeCommand` / `SendUserInput` route while keeping the current-turn
evidence card free of catalog-only command rows or focused-check presets. Diagnostics
collected from Pi stderr, RPC failures, structured diagnostic events, and
non-duplicated bash results are surfaced in the current-turn evidence card and can be
cleared from shared app state.
The model catalog summary can send platform-neutral `SetRpcModel` for the
visible `AgentModelInfo` projection and `CycleRpcModel` for Pi's scoped model
cycle; successful `set_model` and `cycle_model` responses update the active
binding model when Pi returns one, while `cycle_model` `data:null` is treated
as a no-op acknowledgement.
The session panel can send platform-neutral `CompactRpcSession`; successful
`compact` responses append the returned summary to the transcript and update
the active session summary, while offline/no-provider failures remain Pi RPC
diagnostics.
`cycle_thinking_level` responses and `thinking_level_changed` events keep the
compact `思考` control and
`PiAgentSnapshot` aligned. `set_steering_mode` and `set_follow_up_mode`
responses acknowledge the compact optional composer controls, while `get_state`
refreshes the source-of-truth modes from Pi. Expanded composer options can also
send explicit platform-neutral steering and follow-up inputs that the native
encoder maps to Pi RPC `steer` and `follow_up`. `set_session_name` responses and
`session_info_changed` events keep the Workbench-to-Pi session binding display
name in sync, while RPC failures become diagnostics without leaking native
process details into the app model.
Workbench command queue actions now dispatch platform-neutral shell commands
that the native encoder maps to Pi RPC `bash`, and successful `bash` responses
mark command evidence as passed, failed, or cancelled inside the shared model
while preserving Pi's optional `fullOutputPath`, stdout preview, and truncation
flag as command evidence. The current-turn evidence card keeps those command
details collapsed by default and expands stdout/log lines only on demand, so
long/truncated command output can stay discoverable without native-only state.
Command rows can queue an `Inspect command output for ...` prompt from command
status, cwd, exit code, and output path, turning bash evidence into the next Pi
task through `SendUserInput` while preserving the current context chips and
selected agent focus. Outside a focused-check batch, the card shows the
highest-priority command evidence: failed first, active next, latest otherwise.
Focused-check batches still expand to all four checks so the batch can be
inspected as a group without a separate log page. Failed command rows use a
`修复` primary action that queues a
`Fix failed command ...` prompt with the command status, exit code, cwd, output
path, and the same context/focus wrapper, turning a failed focused check
directly into the next coding-agent task without adding native-only output
handling. The current task `下一步` row mirrors the latest failed command's
exit code and output path so the fix entrypoint carries the same evidence as
the command row. Matching Pi bash diagnostics remain available in shared state
but no longer render as duplicate evidence.
The current-turn evidence card can rerun a visible command evidence row through the same
`QueueCommand` / `RunShellCommand` path, so common coding-agent checks can be
replayed without introducing a native-only shortcut.
It also exposes focused-check presets for the app native test, app wasm-gc test,
macOS Skia build, and macOS Skia first-frame smoke only while actionable
diagnostics need a validation entry and no command evidence is already visible.
Once command evidence exists, the card keeps the command row primary and relies
on inline analysis, fix, and rerun actions instead of adding a
second preset row. Each preset uses the same `QueueCommand` /
`RunShellCommand` path, so checks started from the UI become normal Pi bash
evidence. The `全部` action batches all four focused checks through one
platform-neutral queue operation while preserving separate `CommandRun`
evidence rows in that focused-check card. Generic Pi `bash` responses are
applied to the next queued/running command, so batched focused-check evidence
keeps the same FIFO order as the UI queue.
It ignores raw transport lifecycle events as evidence chrome, but still surfaces
actionable Pi/agent timeline events from shared app state when no higher-priority
command evidence is present, so useful tool and agent progress is visible next
to command evidence without adding a separate log view.
Cancelling while such a shell command is active now maps to Pi RPC `abort_bash`;
prompt/agent cancellation still maps to Pi RPC `abort`.
The shared app also ingests Pi's streaming session events such as
`agent_start`, `message_update`, `tool_execution_start`,
`tool_execution_end`, `queue_update`, thinking-level changes, compaction, and
auto-retry updates. These refresh a `PiAgentSnapshot`, selected-session status,
timeline events, and command evidence while leaving the native transport as a
JSONL process driver.
Workbench sessions can now carry a Pi `sessionPath`; selecting one through an
injected transport sends `switch_session` followed by `get_state`,
`get_available_models`, `get_messages`, `get_fork_messages`, `get_commands`,
and `get_session_stats`, then records a `PiSessionBinding` from the Workbench
sidebar id to Pi's concrete session id, file/name, model, and binding status
while models and stats refresh the compact status panel.
The session panel now surfaces the backend-neutral `AgentSessionBinding`
projection as a compact backend session row, so a coding-agent run can show the
live provider session name/id and model without opening a separate diagnostics
view.
The current session can also be refreshed manually from the expanded composer
`Agent` row using the same platform-neutral command batch, so the native UI can
resync Pi state, model catalog, transcript, fork affordances, command catalog,
and stats without changing selection.
That row also includes a fresh-session control. It queues
`NewRpcSession` first; after the `new_session` success response arrives,
`ReceiveTransport` queues the state, model catalog, messages, fork candidates,
commands, and stats refresh through the same platform-neutral transport model.
The native encoder emits `{"type":"new_session"}`, and the chained `get_state`
response becomes the source of truth for the new Pi `sessionId` and session file.
This two-stage flow avoids relying on Pi's response order when multiple
JSONL requests are batched. The session panel also discovers forkable
user-message entry ids with `get_fork_messages`; the transcript consumes those
Pi fork rows through the backend-neutral `AgentForkPoint` projection. Selecting
a visible fork candidate sends `{"type":"fork","entryId":...}` and, after an
uncancelled acknowledgement, queues the same second-stage refresh before
rebinding from Pi's next `get_state` response.
The session panel also has an HTML export action. It sends Pi RPC
`export_html`, and a successful response appears as file evidence in the
current-turn evidence card.

The first native entrypoint is macOS Skia:

```sh
moon test examples/mo_workbench/app --target native
moon test examples/mo_workbench/app --target wasm-gc
moon test examples/mo_workbench/native_transport --target native
moon test moui/backend/macos --target native
moon build examples/mo_workbench/macos_skia --target native
printf '{"type":"get_state"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"new_session"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_messages"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_available_models"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_fork_messages"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_commands"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"get_session_stats"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"export_html","outputPath":"/tmp/mo-workbench-export-smoke.html"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_model","provider":"openai","modelId":"gpt-5"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"cycle_model"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"compact"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"cycle_thinking_level"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_steering_mode","mode":"all"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_follow_up_mode","mode":"one-at-a-time"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"steer","message":"Prefer narrow edits"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"follow_up","message":"Update docs"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"set_session_name","name":"Mo Workbench smoke"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
printf '{"type":"abort_bash"}\n' | \
  pi --mode rpc --no-session --no-tools --no-extensions --no-skills \
    --no-prompt-templates --no-themes --offline
```

See [Mo Workbench](mo-workbench.md) for the app architecture, current slice,
connector boundary, and transport follow-up notes.

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
`FontMgr` path; first-frame smoke runs explicitly select the `EmptyTypeface`
fallback path through their exit-after-first-present environment flag. The
`macos_wgpu` and `macos_wgpu_cosmic` packages remain available as native WGPU
and text-provider diagnostics.

After configuring real Skia link flags, run the opt-in real-Skia check to verify
both the binding smoke and MoUI renderer presenter pixels:

```sh
sh scripts/dev-check.sh --skia-real-smoke
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

For a fuller local smoke, pass `--run-showcase-smoke`. The helper then launches
the built Showcase `macos_skia` executable with a first-frame exit flag and
verifies that the Skia renderer presents a frame before the app exits. Add
`--run-markdown-smoke` to build and launch the Markdown Editor Skia entrypoint
with the same first-frame marker:

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
Set `MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` or
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` in the same MSVC
environment for matching-host first-frame smoke runs; those logs are runtime
evidence only for the Windows host that produced them.
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

Linux examples use the `wzzc-dev/window@0.5.1-0.1.4` Wayland host core. The
recommended native entrypoints use `backend/linux/skia` and present Skia CPU
pixel frames through the Wayland `wl_shm` path. Run them on a configured Linux
host with a Wayland compositor and real Skia link flags:

```sh
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

Set `MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` or
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` before the Skia
`moon run` command to collect matching-host first-frame logs on Wayland. Keep
those logs separate from the window package dependency smoke evidence.

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
