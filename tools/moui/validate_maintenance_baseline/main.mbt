///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct FileBudget {
  path : String
  max_lines : Int
  target_lines : Int
  reason : String
}

///|
struct PubAllBudget {
  label : String
  path : String
  max_pub_all_lines : Int
  target_pub_all_lines : Int
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_maintenance_baseline [--repo-root PATH]
    #|
    #|Audits source-maintenance guardrails for MoUI:
    #|oversized file ratchets, source pub(all) budgets, and root facade
    #|type-forwarding budgets. The current max values lock in today's debt so
    #|future refactors can ratchet them down after splitting files or shrinking
    #|public surface area.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn oversized_file_threshold() -> Int {
  1800
}

///|
fn file_budgets() -> Array[FileBudget] {
  [
    {
      path: "examples/mo_workbench/app/mo_workbench_app_wbtest.mbt",
      max_lines: 633,
      target_lines: 580,
      reason: "keep Mo Workbench composer, backend switching, and shared test helpers compact",
    },
    {
      path: "examples/mo_workbench/app/mo_workbench_pi_ingest_wbtest.mbt",
      max_lines: 420,
      target_lines: 380,
      reason: "keep Mo Workbench Pi transport, diagnostic, plan, and intervention ingest tests compact",
    },
    {
      path: "examples/mo_workbench/app/mo_workbench_pi_session_binding_wbtest.mbt",
      max_lines: 285,
      target_lines: 255,
      reason: "keep Mo Workbench Pi session binding, metrics, expanded action, and RPC error tests compact",
    },
    {
      path: "examples/mo_workbench/app/mo_workbench_pi_rpc_catalog_wbtest.mbt",
      max_lines: 455,
      target_lines: 410,
      reason: "keep Mo Workbench Pi RPC state, transcript, command catalog, model, and compact tests compact",
    },
    {
      path: "examples/mo_workbench/app/mo_workbench_pi_streaming_wbtest.mbt",
      max_lines: 405,
      target_lines: 360,
      reason: "keep Mo Workbench Pi streaming, tool, bash, queue, and raw-line ingest tests compact",
    },
    {
      path: "examples/showcase/app/showcase_app_test.mbt",
      max_lines: 370,
      target_lines: 335,
      reason: "keep Showcase main catalog, section coverage, and layout tests compact",
    },
    {
      path: "examples/showcase/app/showcase_examples_app_test.mbt",
      max_lines: 105,
      target_lines: 90,
      reason: "keep Showcase embedded example and Todo preview tests compact",
    },
    {
      path: "examples/showcase/app/showcase_test_helpers_test.mbt",
      max_lines: 250,
      target_lines: 225,
      reason: "keep Showcase draw-command, hit-test, and click test helpers compact",
    },
    {
      path: "examples/showcase/app/showcase_diagnostics_app_test.mbt",
      max_lines: 380,
      target_lines: 340,
      reason: "keep Showcase diagnostics, advanced rendering, text diagnostics, interaction lab, and renderer tests compact",
    },
    {
      path: "examples/showcase/app/showcase_navigation_app_test.mbt",
      max_lines: 405,
      target_lines: 360,
      reason: "keep Showcase navigation shell, dialog, sheet, route host, sidebar scroll, and IME tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_wbtest.mbt",
      max_lines: 580,
      target_lines: 520,
      reason: "keep Markdown Editor snapshot shape, table, click, selection, and focus-mode tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_formatting_wbtest.mbt",
      max_lines: 420,
      target_lines: 380,
      reason: "keep Markdown Editor formatter source range, hidden marker, reference, and image-preview tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_parser_wbtest.mbt",
      max_lines: 360,
      target_lines: 320,
      reason: "keep Markdown Editor parser, inline metadata, and rich-text formatter tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_source_mapping.mbt",
      max_lines: 1210,
      target_lines: 1120,
      reason: "keep Markdown Editor source, block, inline, and rich-text range mapping compact",
    },
    {
      path: "examples/markdown_editor/app/editor_source_metadata.mbt",
      max_lines: 195,
      target_lines: 175,
      reason: "keep Markdown Editor front matter, active heading, reading time, and outline helpers compact",
    },
    {
      path: "examples/markdown_editor/app/markdown_model.mbt",
      max_lines: 490,
      target_lines: 440,
      reason: "keep Markdown Editor block parsing, front matter, code fence, and line utility model compact",
    },
    {
      path: "examples/markdown_editor/app/markdown_model_inline.mbt",
      max_lines: 560,
      target_lines: 510,
      reason: "keep Markdown Editor inline parsing, reference definitions, HTML inline, and AST text helpers compact",
    },
    {
      path: "examples/markdown_editor/app/markdown_model_rich_text.mbt",
      max_lines: 350,
      target_lines: 320,
      reason: "keep Markdown Editor block-to-rich-text mapping, inline styling, and image preview model compact",
    },
    {
      path: "examples/markdown_editor/app/markdown_model_tables.mbt",
      max_lines: 305,
      target_lines: 280,
      reason: "keep Markdown Editor table parsing, alignment, source ranges, and rich-text preview model compact",
    },
    {
      path: "examples/markdown_editor/app/commands_table.mbt",
      max_lines: 520,
      target_lines: 460,
      reason: "keep Markdown Editor table navigation, cell-range, and structural input helpers compact",
    },
    {
      path: "examples/markdown_editor/app/commands_table_rows.mbt",
      max_lines: 245,
      target_lines: 220,
      reason: "keep Markdown Editor table row insertion, deletion, clearing, and append helpers compact",
    },
    {
      path: "examples/markdown_editor/app/commands_table_columns.mbt",
      max_lines: 380,
      target_lines: 340,
      reason: "keep Markdown Editor table column insertion, deletion, clearing, and alignment helpers compact",
    },
    {
      path: "examples/markdown_editor/app/input_blocks.mbt",
      max_lines: 635,
      target_lines: 580,
      reason: "keep Markdown Editor block input shortcuts, indent, and continuation transforms compact",
    },
    {
      path: "examples/markdown_editor/app/input_blocks_code.mbt",
      max_lines: 390,
      target_lines: 350,
      reason: "keep Markdown Editor code fence completion, quoted code blocks, and code-block enter/exit transforms compact",
    },
    {
      path: "examples/markdown_editor/app/input_blocks_ordered.mbt",
      max_lines: 295,
      target_lines: 260,
      reason: "keep Markdown Editor ordered-list renumbering, offset mapping, and digit parsing compact",
    },
    {
      path: "examples/markdown_editor/app/input_blocks_paste.mbt",
      max_lines: 250,
      target_lines: 220,
      reason: "keep Markdown Editor multiline paste, quote/list paste continuation, and paste line helpers compact",
    },
    {
      path: "examples/markdown_editor/app/input_pairs.mbt",
      max_lines: 600,
      target_lines: 540,
      reason: "keep Markdown Editor paired delimiter and inline marker input helpers compact",
    },
    {
      path: "examples/markdown_editor/app/input_pairs_special_markers.mbt",
      max_lines: 260,
      target_lines: 230,
      reason: "keep Markdown Editor footnote and autolink marker deletion helpers compact",
    },
    {
      path: "examples/markdown_editor/app/input_pairs_reference_markers.mbt",
      max_lines: 320,
      target_lines: 285,
      reason: "keep Markdown Editor inline link, image, and reference marker deletion helpers compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_runtime_wbtest.mbt",
      max_lines: 110,
      target_lines: 95,
      reason: "keep Markdown Editor app runtime smoke tests and draw helpers compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_document_runtime_wbtest.mbt",
      max_lines: 470,
      target_lines: 430,
      reason: "keep Markdown Editor document identity, files, and info panel tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_document_transfer_runtime_wbtest.mbt",
      max_lines: 480,
      target_lines: 440,
      reason: "keep Markdown Editor document transfer and host-service tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_modes_runtime_wbtest.mbt",
      max_lines: 390,
      target_lines: 350,
      reason: "keep Markdown Editor source mode, quick-format, and document-structure tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_writing_modes_runtime_wbtest.mbt",
      max_lines: 285,
      target_lines: 260,
      reason: "keep Markdown Editor writing appearance, focus, typewriter, and zen tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_outline_runtime_wbtest.mbt",
      max_lines: 210,
      target_lines: 190,
      reason: "keep Markdown Editor outline sidebar and heading navigation tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_keyboard_runtime_wbtest.mbt",
      max_lines: 430,
      target_lines: 390,
      reason: "keep Markdown Editor block and indentation runtime shortcut tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_inline_keyboard_runtime_wbtest.mbt",
      max_lines: 295,
      target_lines: 270,
      reason: "keep Markdown Editor inline keyboard shortcut tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_task_runtime_wbtest.mbt",
      max_lines: 55,
      target_lines: 45,
      reason: "keep Markdown Editor task checkbox runtime tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_backspace_delete_runtime_wbtest.mbt",
      max_lines: 285,
      target_lines: 250,
      reason: "keep Markdown Editor Backspace/Delete hidden-marker runtime tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_clipboard_runtime_wbtest.mbt",
      max_lines: 330,
      target_lines: 300,
      reason: "keep Markdown Editor copy, cut, paste, and autolink runtime tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_app_enter_table_keyboard_runtime_wbtest.mbt",
      max_lines: 430,
      target_lines: 380,
      reason: "keep Markdown Editor Enter, Tab, and table keyboard runtime tests compact",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      max_lines: 50,
      target_lines: 45,
      reason: "keep host shared test helpers compact",
    },
    {
      path: "moui/backend/host/host_services_test.mbt",
      max_lines: 255,
      target_lines: 235,
      reason: "keep host service bridge, platform channel, and registered-service tests compact",
    },
    {
      path: "moui/backend/host/host_driver_context_menu_test.mbt",
      max_lines: 240,
      target_lines: 220,
      reason: "keep host driver document context-menu routing and action-map tests compact",
    },
    {
      path: "moui/backend/host/host_subscription_sources_test.mbt",
      max_lines: 275,
      target_lines: 250,
      reason: "keep host and window event subscription source lifecycle tests compact",
    },
    {
      path: "moui/backend/host/host_route_timer_subscription_sources_test.mbt",
      max_lines: 220,
      target_lines: 200,
      reason: "keep host route and timer subscription source lifecycle tests compact",
    },
    {
      path: "moui/backend/host/host_app_services_facade_test.mbt",
      max_lines: 210,
      target_lines: 185,
      reason: "keep host app services facade and binary diagnostic tests compact",
    },
    {
      path: "moui/backend/host/host_async_service_queue_test.mbt",
      max_lines: 210,
      target_lines: 190,
      reason: "keep host async service queue and async driver completion tests compact",
    },
    {
      path: "moui/backend/host/host_service_completion_subscription_test.mbt",
      max_lines: 180,
      target_lines: 160,
      reason: "keep host service completion subscription lifecycle tests compact",
    },
    {
      path: "moui/backend/host/host_image_test.mbt",
      max_lines: 110,
      target_lines: 95,
      reason: "keep host image renderer facade lifecycle and default diagnostics tests compact",
    },
    {
      path: "moui/backend/host/host_image_repaint_tracker_test.mbt",
      max_lines: 305,
      target_lines: 275,
      reason: "keep host image repaint tracker revision, callback, lifecycle-count, stale, and closed-window tests compact",
    },
    {
      path: "moui/backend/host/host_image_completion_source_test.mbt",
      max_lines: 210,
      target_lines: 190,
      reason: "keep host image completion source publish, stale, closed-window, and renderer-apply tests compact",
    },
    {
      path: "moui/backend/host/host_async_image_loader_test.mbt",
      max_lines: 350,
      target_lines: 320,
      reason: "keep host async image loader and native image source tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_test.mbt",
      max_lines: 310,
      target_lines: 280,
      reason: "keep host text input dispatch, clipboard shortcuts, and action fallback tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_context_menu_test.mbt",
      max_lines: 210,
      target_lines: 190,
      reason: "keep host text input context menu command and clipboard paste tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_composition_test.mbt",
      max_lines: 100,
      target_lines: 90,
      reason: "keep host text input composition dispatch tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_ime_test.mbt",
      max_lines: 255,
      target_lines: 230,
      reason: "keep host text input IME session diagnostics and event conversion tests compact",
    },
    {
      path: "moui/backend/host/host_platform_contract_test.mbt",
      max_lines: 255,
      target_lines: 230,
      reason: "keep host app info, capability summary, input host, surface, and window-event contract tests compact",
    },
    {
      path: "moui/backend/host/host_window_lifecycle_test.mbt",
      max_lines: 310,
      target_lines: 285,
      reason: "keep host window lifecycle, platform ids, and scene resolver tests compact",
    },
    {
      path: "moui/backend/host/host_window_runtime_slots_test.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep host window runtime slot and platform driver tests compact",
    },
    {
      path: "moui/backend/host/host_window_commands_test.mbt",
      max_lines: 140,
      target_lines: 125,
      reason: "keep host window commands facade and runtime-slot drain tests compact",
    },
    {
      path: "moui/backend/host/host_window_requests_test.mbt",
      max_lines: 335,
      target_lines: 305,
      reason: "keep host window registry request application and request queue tests compact",
    },
    {
      path: "moui/backend/host/window_lifecycle.mbt",
      max_lines: 520,
      target_lines: 470,
      reason: "keep host window registry, scene resolution, lifecycle updates, and request application compact",
    },
    {
      path: "moui/backend/host/window_runtime_slots.mbt",
      max_lines: 240,
      target_lines: 215,
      reason: "keep host window runtime slot lookup, sync, request, and removal helpers compact",
    },
    {
      path: "moui/backend/host/window_request_queue.mbt",
      max_lines: 150,
      target_lines: 130,
      reason: "keep host window request queue commands, drain, and completion helpers compact",
    },
    {
      path: "moui/backend/host/window_platform_map.mbt",
      max_lines: 110,
      target_lines: 95,
      reason: "keep host platform-window id binding lookup and removal helpers compact",
    },
    {
      path: "moui/backend/web/host_runtime.mbt",
      max_lines: 480,
      target_lines: 430,
      reason: "keep web app startup, surface creation, redraw, text-input sync, and lifecycle compact",
    },
    {
      path: "moui/backend/web/web_async_services.mbt",
      max_lines: 520,
      target_lines: 470,
      reason: "keep web async browser service queueing, completion, and text-file cache helpers compact",
    },
    {
      path: "moui/backend/web/web_events.mbt",
      max_lines: 240,
      target_lines: 215,
      reason: "keep web event conversion, window-event dispatch, modifier tracking, and JS event bridge compact",
    },
    {
      path: "moui/backend/web/web_host.mbt",
      max_lines: 360,
      target_lines: 325,
      reason: "keep web host capability, service bridge, and host-string bridge facade compact",
    },
    {
      path: "moui/backend/web/web_window_requests.mbt",
      max_lines: 200,
      target_lines: 180,
      reason: "keep web window request draining, open/attach, and rollback helpers compact",
    },
    {
      path: "moui/backend/web/web_window_slots.mbt",
      max_lines: 85,
      target_lines: 75,
      reason: "keep web platform-window slot mapping and canvas id helpers compact",
    },
    {
      path: "moui/core/element.mbt",
      max_lines: 330,
      target_lines: 300,
      reason: "keep core element dirty, inspector, component rebuild, and cleanup logic compact",
    },
    {
      path: "moui/core/element_reconcile.mbt",
      max_lines: 340,
      target_lines: 305,
      reason: "keep core element mounting, reconciliation, and child reuse compact",
    },
    {
      path: "moui/core/element_reconcile_dirty.mbt",
      max_lines: 370,
      target_lines: 330,
      reason: "keep core ViewSpec and modifier dirty-kind comparison compact",
    },
    {
      path: "moui/core/element_tree.mbt",
      max_lines: 221,
      target_lines: 210,
      reason: "keep core element node, tree, render node, and cache state compact",
    },
    {
      path: "moui/core/runtime_state.mbt",
      max_lines: 460,
      target_lines: 415,
      reason: "keep core runtime construction, environment, query, draw, and rebuild entrypoints compact",
    },
    {
      path: "moui/core/runtime_events.mbt",
      max_lines: 390,
      target_lines: 350,
      reason: "keep core runtime action command, input event, focus, and animation dispatch compact",
    },
    {
      path: "moui/core/runtime_render_pipeline.mbt",
      max_lines: 330,
      target_lines: 300,
      reason: "keep core runtime render pipeline, damage, cached-layer, and dirty queue helpers compact",
    },
    {
      path: "moui/core/view_tree.mbt",
      max_lines: 360,
      target_lines: 330,
      reason: "keep core view spec, modifier, picker, and sheet contracts compact",
    },
    {
      path: "moui/core/view_spec_ops.mbt",
      max_lines: 370,
      target_lines: 335,
      reason: "keep core ViewSpec key, identity, modifier, and layout propagation helpers compact",
    },
    {
      path: "moui/core/view_style.mbt",
      max_lines: 180,
      target_lines: 160,
      reason: "keep core view alignment, shortcut, image-fit, visual style, shadow, and border contracts compact",
    },
    {
      path: "moui/core/custom_layout.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep core custom layout cache, context, placement, and spec contracts compact",
    },
    {
      path: "moui/core/date_value.mbt",
      max_lines: 135,
      target_lines: 120,
      reason: "keep core date picker mode, value, formatting, range, and calendar helpers compact",
    },
    {
      path: "moui/core/program_subscription.mbt",
      max_lines: 360,
      target_lines: 270,
      reason: "keep core subscription contract, opaque descriptor accessors, and plan summary helpers compact",
    },
    {
      path: "moui/core/program_runtime_diagnostics.mbt",
      max_lines: 275,
      target_lines: 245,
      reason: "keep core program runtime counter diagnostics compact",
    },
    {
      path: "moui/core/program_runtime_snapshot.mbt",
      max_lines: 140,
      target_lines: 125,
      reason: "keep core program runtime snapshot, lifecycle, and empty-state contracts compact",
    },
    {
      path: "moui/core/program_runtime_effect_tasks.mbt",
      max_lines: 135,
      target_lines: 120,
      reason: "keep core program runtime effect-task lifecycle diagnostics compact",
    },
    {
      path: "moui/core/program_runtime_subscriptions.mbt",
      max_lines: 180,
      target_lines: 160,
      reason: "keep core program runtime subscription lifecycle diagnostics compact",
    },
    {
      path: "moui/core/rich_text_document.mbt",
      max_lines: 180,
      target_lines: 160,
      reason: "keep core rich text document, run, table, block, source range, and transform contracts compact",
    },
    {
      path: "moui/core/rich_text_editor_wbtest.mbt",
      max_lines: 300,
      target_lines: 270,
      reason: "keep core rich text editor cache, input, semantics, transform, and placeholder tests compact",
    },
    {
      path: "moui/core/rich_text_editor_drawing_wbtest.mbt",
      max_lines: 320,
      target_lines: 285,
      reason: "keep core rich text editor styled drawing and block geometry tests compact",
    },
    {
      path: "moui/core/rich_text_editor_ime_wbtest.mbt",
      max_lines: 70,
      target_lines: 55,
      reason: "keep core rich text editor IME composition commit and replacement tests compact",
    },
    {
      path: "moui/core/rich_text_editor_mapping_wbtest.mbt",
      max_lines: 290,
      target_lines: 260,
      reason: "keep core rich text editor source-mapped copy, cut, caret, and table mapping tests compact",
    },
    {
      path: "moui/core/rich_text_editor_pointer_mapping_wbtest.mbt",
      max_lines: 270,
      target_lines: 240,
      reason: "keep core rich text editor pointer, selection-highlight, and drag source mapping tests compact",
    },
    {
      path: "moui/core/advanced_layout_wbtest.mbt",
      max_lines: 260,
      target_lines: 235,
      reason: "keep core stack, modifier, grid, list, and measure-pass tests compact",
    },
    {
      path: "moui/core/advanced_layout_custom_wbtest.mbt",
      max_lines: 160,
      target_lines: 145,
      reason: "keep core custom-layout delegate, metrics, cache, and semantics tests compact",
    },
    {
      path: "moui/core/advanced_layout_scroll_wbtest.mbt",
      max_lines: 245,
      target_lines: 220,
      reason: "keep core scroll layout, repaint, clipping, and hit-test behavior tests compact",
    },
    {
      path: "moui/core/redraw_damage_wbtest.mbt",
      max_lines: 200,
      target_lines: 180,
      reason: "keep core damage region, draw-command bounds, scroll/layout damage, and dirty fallback tests compact",
    },
    {
      path: "moui/core/redraw_cached_layer_wbtest.mbt",
      max_lines: 220,
      target_lines: 205,
      reason: "keep core repaint-boundary cached-layer draw-frame and retained redraw tests compact",
    },
    {
      path: "moui/core/text_system_conformance_wbtest.mbt",
      max_lines: 285,
      target_lines: 255,
      reason: "keep core fallback text, caret, paragraph, and shared conformance helpers compact",
    },
    {
      path: "moui/core/text_grapheme_boundary_conformance_wbtest.mbt",
      max_lines: 230,
      target_lines: 205,
      reason: "keep core grapheme boundary, delete-range, and UTF-8 offset conformance tests compact",
    },
    {
      path: "moui/core/text_system_field_conformance_wbtest.mbt",
      max_lines: 290,
      target_lines: 260,
      reason: "keep core text field and rich text unicode conformance tests compact",
    },
    {
      path: "moui/core/engine_text_input_wbtest.mbt",
      max_lines: 285,
      target_lines: 260,
      reason: "keep core text input editing, selection, and undo history tests compact",
    },
    {
      path: "moui/core/engine_text_input_host_wbtest.mbt",
      max_lines: 180,
      target_lines: 160,
      reason: "keep core text input rendering, host-state, searchbar, and focus traversal tests compact",
    },
    {
      path: "moui/core/engine_text_input_ime_wbtest.mbt",
      max_lines: 180,
      target_lines: 155,
      reason: "keep core text input IME composition, composition-caret, and delete-surrounding tests compact",
    },
    {
      path: "moui/core/engine_focus_wbtest.mbt",
      max_lines: 200,
      target_lines: 185,
      reason: "keep core focus text-field, pointer, topmost hit-test, and tab traversal tests compact",
    },
    {
      path: "moui/core/engine_focus_trap_wbtest.mbt",
      max_lines: 220,
      target_lines: 205,
      reason: "keep core focus trap tab, pointer, and keyed focus tests compact",
    },
    {
      path: "moui/core/runtime_component_effects_wbtest.mbt",
      max_lines: 170,
      target_lines: 155,
      reason: "keep core component effect lifecycle, cancellation, and dispose tests compact",
    },
    {
      path: "moui/core/runtime_saveable_state_wbtest.mbt",
      max_lines: 280,
      target_lines: 260,
      reason: "keep core saveable store, codec, scoped state, and stale subscription tests compact",
    },
    {
      path: "moui/core/runtime_effects_wbtest.mbt",
      max_lines: 340,
      target_lines: 305,
      reason: "keep core program effect plan, dispatch, and destroy-late-dispatch tests compact",
    },
    {
      path: "moui/core/runtime_effect_turns_wbtest.mbt",
      max_lines: 280,
      target_lines: 250,
      reason: "keep core program effect bounded-drain and host-callback resume tests compact",
    },
    {
      path: "moui/core/runtime_effect_tasks_wbtest.mbt",
      max_lines: 310,
      target_lines: 280,
      reason: "keep core program effect-task completion, stale dispatch, cancellation, and replacement tests compact",
    },
    {
      path: "moui/core/runtime_subscription_sources_wbtest.mbt",
      max_lines: 280,
      target_lines: 250,
      reason: "keep core subscription descriptors, mapped sources, helper kinds, and active-kind summary tests compact",
    },
    {
      path: "moui/core/runtime_subscriptions_wbtest.mbt",
      max_lines: 365,
      target_lines: 330,
      reason: "keep core program subscription lifecycle, restart, and duplicate-key tests compact",
    },
    {
      path: "moui/core/runtime_subscription_turns_wbtest.mbt",
      max_lines: 150,
      target_lines: 130,
      reason: "keep core program subscription bounded-drain and host-callback resume tests compact",
    },
    {
      path: "moui/core/runtime_controls_wbtest.mbt",
      max_lines: 145,
      target_lines: 130,
      reason: "keep core controlled text input runtime tests compact",
    },
    {
      path: "moui/core/runtime_control_choices_wbtest.mbt",
      max_lines: 235,
      target_lines: 210,
      reason: "keep core controlled checkbox, picker, and datepicker runtime tests compact",
    },
    {
      path: "moui/core/state_holder_wbtest.mbt",
      max_lines: 230,
      target_lines: 205,
      reason: "keep core state holder, keyboard shortcut, disabled, and focus traversal tests compact",
    },
    {
      path: "moui/core/state_gesture_wbtest.mbt",
      max_lines: 170,
      target_lines: 150,
      reason: "keep core high-level gesture wrapper runtime tests compact",
    },
    {
      path: "moui/core/state_lifecycle_wbtest.mbt",
      max_lines: 230,
      target_lines: 205,
      reason: "keep core component lifecycle, keyed reorder, removal, and cache tests compact",
    },
    {
      path: "moui/core/state_build_context_wbtest.mbt",
      max_lines: 165,
      target_lines: 145,
      reason: "keep core build-context watch, binding, and derived-state subscription tests compact",
    },
    {
      path: "moui/core/app_routing_wbtest.mbt",
      max_lines: 145,
      target_lines: 130,
      reason: "keep core router, route history, and route focus tests compact",
    },
    {
      path: "moui/core/app_forms_wbtest.mbt",
      max_lines: 45,
      target_lines: 40,
      reason: "keep core form field and form controller validation tests compact",
    },
    {
      path: "moui/core/app_inspector_wbtest.mbt",
      max_lines: 190,
      target_lines: 170,
      reason: "keep core runtime, layout, render, semantics, and frame inspector tests compact",
    },
    {
      path: "moui/core/test_view_factories_wbtest.mbt",
      max_lines: 75,
      target_lines: 65,
      reason: "keep core wbtest view factory helpers compact",
    },
    {
      path: "moui/core/test_draw_helpers_wbtest.mbt",
      max_lines: 100,
      target_lines: 90,
      reason: "keep core wbtest draw lookup and runtime click helpers compact",
    },
    {
      path: "moui/core/test_layout_helpers_wbtest.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep core wbtest layout, element tree, reconcile, and hit-test helpers compact",
    },
    {
      path: "moui/core/test_runtime_helpers_wbtest.mbt",
      max_lines: 155,
      target_lines: 140,
      reason: "keep core wbtest runtime and ViewSpec modifier helpers compact",
    },
    {
      path: "examples/pdf_workbench/app/app.mbt",
      max_lines: 390,
      target_lines: 360,
      reason: "keep PDF Workbench app model, runtime, and update dispatch compact",
    },
    {
      path: "examples/pdf_workbench/app/host_services.mbt",
      max_lines: 530,
      target_lines: 490,
      reason: "keep PDF Workbench host open/save, completion, writeback, and load flow compact",
    },
    {
      path: "examples/pdf_workbench/app/navigation.mbt",
      max_lines: 230,
      target_lines: 210,
      reason: "keep PDF Workbench page, search, zoom, fullscreen, and preview navigation flow compact",
    },
    {
      path: "examples/pdf_workbench/app/edit_commands.mbt",
      max_lines: 220,
      target_lines: 200,
      reason: "keep PDF Workbench edit command queue, undo, discard, metadata, bookmark, and annotation flow compact",
    },
    {
      path: "examples/pdf_workbench/app/view_layout.mbt",
      max_lines: 190,
      target_lines: 165,
      reason: "keep PDF Workbench root viewport layout and shared panel metrics compact",
    },
    {
      path: "examples/pdf_workbench/app/view_chrome.mbt",
      max_lines: 215,
      target_lines: 195,
      reason: "keep PDF Workbench toolbar, failure banner, status bar, and search labels compact",
    },
    {
      path: "examples/pdf_workbench/app/view_page.mbt",
      max_lines: 245,
      target_lines: 225,
      reason: "keep PDF Workbench page surface, page toolbar, compact edit strip, and scroll sizing compact",
    },
    {
      path: "examples/pdf_workbench/app/view_preview.mbt",
      max_lines: 315,
      target_lines: 290,
      reason: "keep PDF Workbench preview canvas, raster fallback, zoom sizing, and edit overlays compact",
    },
    {
      path: "examples/pdf_workbench/app/view_sidebar.mbt",
      max_lines: 270,
      target_lines: 245,
      reason: "keep PDF Workbench sidebar page navigation and thumbnail rendering compact",
    },
    {
      path: "examples/pdf_workbench/app/view_inspector.mbt",
      max_lines: 470,
      target_lines: 430,
      reason: "keep PDF Workbench inspector summary, edit queue, metadata, and diagnostics panels compact",
    },
    {
      path: "moui/render/skia/skia_renderer_wbtest.mbt",
      max_lines: 75,
      target_lines: 75,
      reason: "keep Skia renderer matrix, surface, and brush smoke tests compact",
    },
    {
      path: "moui/views/style_api.mbt",
      max_lines: 155,
      target_lines: 135,
      reason: "keep views style variants and style mapping compact",
    },
    {
      path: "moui/views/choice_state.mbt",
      max_lines: 25,
      target_lines: 20,
      reason: "keep views choice item, chip variant, and segmented control descriptors compact",
    },
    {
      path: "moui/views/choice_groups.mbt",
      max_lines: 70,
      target_lines: 60,
      reason: "keep views radio and checkbox group helpers compact",
    },
    {
      path: "moui/views/choice_segmented.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views segmented control rendering compact",
    },
    {
      path: "moui/views/choice_chips.mbt",
      max_lines: 160,
      target_lines: 140,
      reason: "keep views chip, tag, filter-chip, and choice-chip helpers compact",
    },
    {
      path: "moui/views/control_choice.mbt",
      max_lines: 85,
      target_lines: 75,
      reason: "keep views toggle, switch, radio, and binding aliases compact",
    },
    {
      path: "moui/views/control_helpers.mbt",
      max_lines: 40,
      target_lines: 30,
      reason: "keep views control color and scalar helpers compact",
    },
    {
      path: "moui/views/control_progress.mbt",
      max_lines: 60,
      target_lines: 40,
      reason: "keep views custom progress painting helper compact",
    },
    {
      path: "moui/views/control_slider.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep views slider painting, drag mapping, and binding helper compact",
    },
    {
      path: "moui/views/control_focus_overlay.mbt",
      max_lines: 95,
      target_lines: 70,
      reason: "keep views focus ring, menu button, and tooltip wrappers compact",
    },
    {
      path: "moui/views/form_state.mbt",
      max_lines: 45,
      target_lines: 35,
      reason: "keep views form status, validation display, and baseline row descriptors compact",
    },
    {
      path: "moui/views/form_layout.mbt",
      max_lines: 65,
      target_lines: 55,
      reason: "keep views form and section layout helpers compact",
    },
    {
      path: "moui/views/form_field.mbt",
      max_lines: 80,
      target_lines: 70,
      reason: "keep views public form field layout wrapper compact",
    },
    {
      path: "moui/views/form_field_state.mbt",
      max_lines: 40,
      target_lines: 35,
      reason: "keep views core form-field state bridge compact",
    },
    {
      path: "moui/views/form_field_support.mbt",
      max_lines: 145,
      target_lines: 125,
      reason: "keep views form field support and semantics helpers compact",
    },
    {
      path: "moui/views/form_validation.mbt",
      max_lines: 205,
      target_lines: 180,
      reason: "keep views validation summary rendering and summary sizing helpers compact",
    },
    {
      path: "moui/views/form_workflow.mbt",
      max_lines: 190,
      target_lines: 170,
      reason: "keep views form action row, workflow footer, and focus-status helpers compact",
    },
    {
      path: "moui/views/form_support_text.mbt",
      max_lines: 40,
      target_lines: 30,
      reason: "keep views form error, helper text, and validation style resolution compact",
    },
    {
      path: "moui/views/input_group_shell.mbt",
      max_lines: 45,
      target_lines: 35,
      reason: "keep views input prefix/suffix shell compact",
    },
    {
      path: "moui/views/input_text_wrappers.mbt",
      max_lines: 95,
      target_lines: 85,
      reason: "keep views clearable and password text wrappers compact",
    },
    {
      path: "moui/views/input_number.mbt",
      max_lines: 105,
      target_lines: 95,
      reason: "keep views number field and stepper helpers compact",
    },
    {
      path: "moui/views/input_multiline.mbt",
      max_lines: 35,
      target_lines: 25,
      reason: "keep views multiline text area shell compact",
    },
    {
      path: "moui/views/feedback_state.mbt",
      max_lines: 135,
      target_lines: 115,
      reason: "keep views feedback tones, state actions, and toast queue helpers compact",
    },
    {
      path: "moui/views/feedback_guidance.mbt",
      max_lines: 70,
      target_lines: 55,
      reason: "keep views inline feedback guidance surfaces compact",
    },
    {
      path: "moui/views/feedback_surface.mbt",
      max_lines: 125,
      target_lines: 105,
      reason: "keep shared feedback surface and tone-style helpers compact",
    },
    {
      path: "moui/views/feedback_transient.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep views transient feedback surfaces compact",
    },
    {
      path: "moui/views/feedback_status.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views workflow state panels and inline error helpers compact",
    },
    {
      path: "moui/views/feedback_progress.mbt",
      max_lines: 150,
      target_lines: 130,
      reason: "keep views progress status layout and progress-label helpers compact",
    },
    {
      path: "moui/views/feedback_badge.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep views badge, status badge, stat card, and badge tone helpers compact",
    },
    {
      path: "moui/views/file_import_state.mbt",
      max_lines: 45,
      target_lines: 35,
      reason: "keep views file import availability and file selection helpers compact",
    },
    {
      path: "moui/views/layout_state.mbt",
      max_lines: 40,
      target_lines: 30,
      reason: "keep views section-list and scroll-to-index descriptors compact",
    },
    {
      path: "moui/views/grid_list.mbt",
      max_lines: 25,
      target_lines: 20,
      reason: "keep views eager grid and list primitive wrappers compact",
    },
    {
      path: "moui/views/virtual_list.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views lazy list, virtual list, scroll intent, and window helpers compact",
    },
    {
      path: "moui/views/sectioned_list.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views sectioned list flattening, windowing, and spacer helpers compact",
    },
    {
      path: "moui/views/lazy_grid.mbt",
      max_lines: 95,
      target_lines: 85,
      reason: "keep views lazy grid row windowing helpers compact",
    },
    {
      path: "moui/views/layout_helpers.mbt",
      max_lines: 170,
      target_lines: 145,
      reason: "keep views simple layout modifiers, custom-layout wrappers, and shared geometry helpers compact",
    },
    {
      path: "moui/views/layout_flow.mbt",
      max_lines: 145,
      target_lines: 130,
      reason: "keep views wrap/flow measurement and placement helpers compact",
    },
    {
      path: "moui/views/layout_responsive_grid.mbt",
      max_lines: 155,
      target_lines: 140,
      reason: "keep views responsive grid measurement, placement, and column helpers compact",
    },
    {
      path: "moui/views/layout_baseline_form.mbt",
      max_lines: 160,
      target_lines: 145,
      reason: "keep views baseline form row layout measurement and placement helpers compact",
    },
    {
      path: "moui/views/toolbar.mbt",
      max_lines: 120,
      target_lines: 105,
      reason: "keep views toolbar, command bar, button group, and status bar helpers compact",
    },
    {
      path: "moui/views/command_palette.mbt",
      max_lines: 120,
      target_lines: 105,
      reason: "keep views command palette filtering and row rendering compact",
    },
    {
      path: "moui/views/disclosure.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views disclosure, accordion, collapsible panel, and resizable panel helpers compact",
    },
    {
      path: "moui/views/navigation_state.mbt",
      max_lines: 140,
      target_lines: 120,
      reason: "keep views menu, popover, sidebar, breadcrumb, and wizard descriptors compact",
    },
    {
      path: "moui/views/popover_surface.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views popover surface and semantics helpers compact",
    },
    {
      path: "moui/views/popover_selectors.mbt",
      max_lines: 135,
      target_lines: 120,
      reason: "keep views dropdown, combobox, and autocomplete wrappers compact",
    },
    {
      path: "moui/views/popover_menu.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views shared popover menu rendering helpers compact",
    },
    {
      path: "moui/views/navigation.mbt",
      max_lines: 125,
      target_lines: 110,
      reason: "keep views route stack, router stack, and tabs helpers compact",
    },
    {
      path: "moui/views/navigation_breadcrumb.mbt",
      max_lines: 45,
      target_lines: 40,
      reason: "keep views breadcrumb helper compact",
    },
    {
      path: "moui/views/navigation_route_header.mbt",
      max_lines: 85,
      target_lines: 75,
      reason: "keep views route header helper compact",
    },
    {
      path: "moui/views/navigation_section_nav.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep views section navigation helper compact",
    },
    {
      path: "moui/views/navigation_sidebar.mbt",
      max_lines: 45,
      target_lines: 40,
      reason: "keep views sidebar helper compact",
    },
    {
      path: "moui/views/navigation_split.mbt",
      max_lines: 115,
      target_lines: 100,
      reason: "keep views split-pane and master-detail helpers compact",
    },
    {
      path: "moui/views/navigation_presentation.mbt",
      max_lines: 120,
      target_lines: 105,
      reason: "keep views wizard and dialog host presentation helpers compact",
    },
    {
      path: "moui/views/dialog_alert.mbt",
      max_lines: 85,
      target_lines: 75,
      reason: "keep views alert dialog content helper compact",
    },
    {
      path: "moui/views/dialog_shell.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views custom dialog shell and action helpers compact",
    },
    {
      path: "moui/views/data_display_state.mbt",
      max_lines: 15,
      target_lines: 10,
      reason: "keep views description item descriptors compact",
    },
    {
      path: "moui/views/data_filter_state.mbt",
      max_lines: 25,
      target_lines: 15,
      reason: "keep views data filter descriptors compact",
    },
    {
      path: "moui/views/data_sort_pagination.mbt",
      max_lines: 105,
      target_lines: 90,
      reason: "keep views sort and pagination app-owned state helpers compact",
    },
    {
      path: "moui/views/data_table_state.mbt",
      max_lines: 45,
      target_lines: 35,
      reason: "keep views table column descriptors compact",
    },
    {
      path: "moui/views/data_table_visibility_state.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views table column visibility state helper compact",
    },
    {
      path: "moui/views/data_table_width_state.mbt",
      max_lines: 75,
      target_lines: 65,
      reason: "keep views table column width state helper compact",
    },
    {
      path: "moui/views/data_table_order_state.mbt",
      max_lines: 65,
      target_lines: 55,
      reason: "keep views table column order state helper compact",
    },
    {
      path: "moui/views/data_selection_state.mbt",
      max_lines: 80,
      target_lines: 65,
      reason: "keep views selection state and selectable list item descriptors compact",
    },
    {
      path: "moui/views/data_tree_state.mbt",
      max_lines: 20,
      target_lines: 12,
      reason: "keep views tree item descriptors compact",
    },
    {
      path: "moui/views/data_display.mbt",
      max_lines: 140,
      target_lines: 125,
      reason: "keep views description list and detail panel helpers compact",
    },
    {
      path: "moui/views/data_pagination.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views pagination helper compact",
    },
    {
      path: "moui/views/data_selectable_list.mbt",
      max_lines: 170,
      target_lines: 150,
      reason: "keep views selectable list and row helpers compact",
    },
    {
      path: "moui/views/data_selection_toolbar.mbt",
      max_lines: 105,
      target_lines: 90,
      reason: "keep views selection toolbar helper compact",
    },
    {
      path: "moui/views/data_avatar.mbt",
      max_lines: 90,
      target_lines: 75,
      reason: "keep views avatar and avatar group helpers compact",
    },
    {
      path: "moui/views/data_tree.mbt",
      max_lines: 145,
      target_lines: 130,
      reason: "keep views tree view expansion and row helpers compact",
    },
    {
      path: "moui/views/data_filter_bar.mbt",
      max_lines: 145,
      target_lines: 125,
      reason: "keep views data filter bar and chip helpers compact",
    },
    {
      path: "moui/views/data_filter_column_visibility.mbt",
      max_lines: 145,
      target_lines: 125,
      reason: "keep views column visibility panel and row helpers compact",
    },
    {
      path: "moui/views/data_table.mbt",
      max_lines: 60,
      target_lines: 50,
      reason: "keep views public table composition compact",
    },
    {
      path: "moui/views/data_table_rendering.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep views table header, row, and sizing helpers compact",
    },
    {
      path: "moui/views/views_test.mbt",
      max_lines: 20,
      target_lines: 20,
      reason: "keep top-level views facade smoke and shared test runtime helper compact",
    },
    {
      path: "moui/views/views_helpers_test.mbt",
      max_lines: 85,
      target_lines: 75,
      reason: "keep views text, click, and semantics test helpers compact",
    },
    {
      path: "moui/views/views_draw_surface_helpers_test.mbt",
      max_lines: 110,
      target_lines: 95,
      reason: "keep views draw surface and rect test helpers compact",
    },
    {
      path: "moui/views/views_data_commands_test.mbt",
      max_lines: 165,
      target_lines: 150,
      reason: "keep views data display composition and semantic smoke tests compact",
    },
    {
      path: "moui/views/views_data_interactions_test.mbt",
      max_lines: 170,
      target_lines: 150,
      reason: "keep views list, table, and selection toolbar interaction tests compact",
    },
    {
      path: "moui/views/views_data_filter_visibility_test.mbt",
      max_lines: 160,
      target_lines: 145,
      reason: "keep views data filter and column visibility interaction tests compact",
    },
    {
      path: "moui/views/views_command_surfaces_test.mbt",
      max_lines: 155,
      target_lines: 140,
      reason: "keep views toolbar, disclosure, resizable panel, command palette, and card tests compact",
    },
    {
      path: "moui/views/views_gesture_file_surfaces_test.mbt",
      max_lines: 145,
      target_lines: 125,
      reason: "keep views gesture wrappers, drop zone, and file import surface tests compact",
    },
    {
      path: "moui/views/views_menu_surfaces_test.mbt",
      max_lines: 190,
      target_lines: 170,
      reason: "keep views menu bar, command menu, and context-menu surface tests compact",
    },
    {
      path: "moui/views/views_form_feedback_test.mbt",
      max_lines: 105,
      target_lines: 95,
      reason: "keep views form field and validation-summary tests compact",
    },
    {
      path: "moui/views/views_form_workflow_test.mbt",
      max_lines: 125,
      target_lines: 110,
      reason: "keep views form workflow, validating-state, and core validation bridge tests compact",
    },
    {
      path: "moui/views/views_input_wrappers_test.mbt",
      max_lines: 40,
      target_lines: 35,
      reason: "keep views enhanced input wrapper composition tests compact",
    },
    {
      path: "moui/views/views_choice_semantics_test.mbt",
      max_lines: 110,
      target_lines: 100,
      reason: "keep views choice controls and cross-component semantics tests compact",
    },
    {
      path: "moui/views/views_feedback_state_test.mbt",
      max_lines: 175,
      target_lines: 155,
      reason: "keep views feedback surface, theme color, and progress action tests compact",
    },
    {
      path: "moui/views/views_theme_style_contracts_test.mbt",
      max_lines: 75,
      target_lines: 65,
      reason: "keep views theme and theme-derived style contract tests compact",
    },
    {
      path: "moui/views/views_control_style_contracts_test.mbt",
      max_lines: 125,
      target_lines: 110,
      reason: "keep views neutral control style contract tests compact",
    },
    {
      path: "moui/views/views_feedback_style_contracts_test.mbt",
      max_lines: 135,
      target_lines: 120,
      reason: "keep views feedback, badge, and validation style contract tests compact",
    },
    {
      path: "moui/views/views_state_helpers_test.mbt",
      max_lines: 75,
      target_lines: 65,
      reason: "keep views app-owned data, selection, column, and toast state helper tests compact",
    },
    {
      path: "moui/views/views_focus_test.mbt",
      max_lines: 80,
      target_lines: 70,
      reason: "keep views shortcut button and focus ring tests compact",
    },
    {
      path: "moui/views/views_focus_trap_test.mbt",
      max_lines: 135,
      target_lines: 120,
      reason: "keep views focus trap, presentation focus, and sheet layout tests compact",
    },
    {
      path: "moui/views/views_overlay_navigation_test.mbt",
      max_lines: 125,
      target_lines: 110,
      reason: "keep views navigation shell composition tests compact",
    },
    {
      path: "moui/views/views_navigation_routing_test.mbt",
      max_lines: 95,
      target_lines: 85,
      reason: "keep views section navigation dispatch and router stack tests compact",
    },
    {
      path: "moui/views/views_adjustable_navigation_controls_test.mbt",
      max_lines: 110,
      target_lines: 100,
      reason: "keep views resizable split and slider drag interaction tests compact",
    },
    {
      path: "moui/views/views_overlay_surfaces_test.mbt",
      max_lines: 65,
      target_lines: 60,
      reason: "keep views popover, dropdown, combobox, and autocomplete surface tests compact",
    },
    {
      path: "moui/views/views_dialog_surfaces_test.mbt",
      max_lines: 170,
      target_lines: 150,
      reason: "keep views alert, dialog, and dialog host surface tests compact",
    },
    {
      path: "moui/core/runtime_wbtest.mbt",
      max_lines: 40,
      target_lines: 35,
      reason: "keep basic RuntimeKernel dispatch smoke compact",
    },
    {
      path: "examples/pdf_workbench/app/pdf_workbench_app_wbtest.mbt",
      max_lines: 25,
      target_lines: 20,
      reason: "keep PDF Workbench document parsing smoke compact",
    },
    {
      path: "examples/markdown_editor/app/editor_input_wbtest.mbt",
      max_lines: 125,
      target_lines: 110,
      reason: "keep Markdown Editor paired delimiter input tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_commands_wbtest.mbt",
      max_lines: 80,
      target_lines: 70,
      reason: "keep Markdown Editor core inline command smoke tests compact",
    },
    {
      path: "examples/markdown_editor/app/editor_commands_blocks_wbtest.mbt",
      max_lines: 205,
      target_lines: 190,
      reason: "keep Markdown Editor current-line block command, paragraph, and setext tests compact",
    },
    {
      path: "moui/render/skia/renderer_text.mbt",
      max_lines: 50,
      target_lines: 40,
      reason: "keep Skia text drawing entrypoint compact",
    },
    {
      path: "moui/core/engine_wbtest.mbt",
      max_lines: 20,
      target_lines: 18,
      reason: "keep general engine mount smoke compact",
    },
    {
      path: "moui/core/view.mbt",
      max_lines: 48,
      target_lines: 40,
      reason: "keep core View wrapper and realization entry compact",
    },
    {
      path: "moui/runtime/runtime.mbt",
      max_lines: 444,
      target_lines: 380,
      reason: "keep runtime AppRuntime facade, dimensions entrypoint, program message loop, and core handoff compact",
    },
    {
      path: "moui/runtime/program_runtime_diagnostics.mbt",
      max_lines: 270,
      target_lines: 240,
      reason: "keep runtime program counters, snapshots, and active lifecycle state compact",
    },
    {
      path: "moui/runtime/program_runtime_effect_tasks.mbt",
      max_lines: 130,
      target_lines: 115,
      reason: "keep runtime effect-task lifecycle handling compact",
    },
    {
      path: "moui/runtime/program_runtime_subscriptions.mbt",
      max_lines: 185,
      target_lines: 160,
      reason: "keep runtime subscription reuse, cancellation, and kind counts compact",
    },
    {
      path: "moui/runtime/program_runtime_wbtest.mbt",
      max_lines: 235,
      target_lines: 205,
      reason: "keep runtime program effects, tasks, and subscription tests compact",
    },
  ]
}

///|
fn pub_all_budgets() -> Array[PubAllBudget] {
  [
    {
      label: "core source",
      path: "moui/core",
      max_pub_all_lines: 156,
      target_pub_all_lines: 120,
    },
    {
      label: "views source",
      path: "moui/views",
      max_pub_all_lines: 15,
      target_pub_all_lines: 5,
    },
    {
      label: "host source",
      path: "moui/backend/host",
      max_pub_all_lines: 79,
      target_pub_all_lines: 45,
    },
    {
      label: "render facade source",
      path: "moui/render",
      max_pub_all_lines: 33,
      target_pub_all_lines: 25,
    },
    {
      label: "skia renderer source",
      path: "moui/render/skia",
      max_pub_all_lines: 8,
      target_pub_all_lines: 8,
    },
    {
      label: "showcase app source",
      path: "examples/showcase/app",
      max_pub_all_lines: 4,
      target_pub_all_lines: 4,
    },
    {
      label: "markdown editor app source",
      path: "examples/markdown_editor/app",
      max_pub_all_lines: 0,
      target_pub_all_lines: 0,
    },
    {
      label: "pdf workbench app source",
      path: "examples/pdf_workbench/app",
      max_pub_all_lines: 10,
      target_pub_all_lines: 10,
    },
    {
      label: "mo workbench app source",
      path: "examples/mo_workbench/app",
      max_pub_all_lines: 5,
      target_pub_all_lines: 5,
    },
    {
      label: "website app source",
      path: "website/app",
      max_pub_all_lines: 0,
      target_pub_all_lines: 0,
    },
  ]
}

///|
fn monitored_roots() -> Array[String] {
  ["moui", "examples", "website"]
}

///|
fn generated_fixture_path(path : String) -> Bool {
  path.has_suffix("_unicode_17_wbtest.mbt")
}

///|
fn skipped_directory_name(name : String) -> Bool {
  name == ".git" ||
  name == ".mooncakes" ||
  name == "_build" ||
  name == "artifacts"
}

///|
fn line_count(text : String) -> Int {
  let mut count = 0
  for index in 0..<text.length() {
    if text[index] == '\n' {
      count += 1
    }
  }
  if text != "" && !text.has_suffix("\n") {
    count += 1
  }
  count
}

///|
fn count_lines_with_prefix(text : String, prefix : String) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    if line_view.to_owned().has_prefix(prefix) {
      count += 1
    }
  }
  count
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn push_max_check(
  failures : Array[String],
  label : String,
  actual : Int,
  max : Int,
) -> Unit {
  if actual > max {
    failures.push(label + " is \{actual}, above ratchet budget \{max}")
  }
}

///|
fn read_dir_names(
  path : String,
  label : String,
) -> Result[Array[String], String] {
  if !@tools.directory_exists(path) {
    return Err(label + " is missing: " + path)
  }
  let entries : Array[String] = @fs.read_dir(path) catch {
    _ => return Err(label + " could not be read: " + path)
  }
  entries.sort()
  Ok(entries)
}

///|
fn collect_mbt_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  let entries = match read_dir_names(absolute_dir, relative_dir) {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(absolute) {
      if !skipped_directory_name(entry) {
        collect_mbt_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) &&
      relative.has_suffix(".mbt") &&
      !relative.has_suffix("pkg.generated.mbti") {
      files.push(relative)
    }
  }
}

///|
fn collect_direct_mbt_files(
  repo_root : String,
  relative_dir : String,
  failures : Array[String],
) -> Array[String] {
  let files : Array[String] = []
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  let entries = match read_dir_names(absolute_dir, relative_dir) {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      return files
    }
  }
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.file_exists(absolute) &&
      relative.has_suffix(".mbt") &&
      !relative.has_suffix("pkg.generated.mbti") {
      files.push(relative)
    }
  }
  files
}

///|
fn array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn tracked_budget_paths() -> Array[String] {
  let paths : Array[String] = []
  for budget in file_budgets() {
    paths.push(budget.path)
  }
  paths
}

///|
fn validate_file_budget(
  repo_root : String,
  budget : FileBudget,
  failures : Array[String],
) -> Unit {
  let text = match read_repo_text(repo_root, budget.path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let lines = line_count(text)
  println(
    "maintenance: " +
    budget.path +
    " lines=\{lines} max=\{budget.max_lines} target=\{budget.target_lines} reason=" +
    budget.reason,
  )
  push_max_check(failures, budget.path + " line count", lines, budget.max_lines)
}

///|
fn validate_untracked_oversized_files(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  for root in monitored_roots() {
    collect_mbt_files(repo_root, root, files, failures)
  }
  let tracked_paths = tracked_budget_paths()
  for path in files {
    if !generated_fixture_path(path) && !array_contains(tracked_paths, path) {
      let text = match read_repo_text(repo_root, path) {
        Ok(value) => value
        Err(message) => {
          failures.push(message)
          continue
        }
      }
      let lines = line_count(text)
      if lines > oversized_file_threshold() {
        failures.push(
          path +
          " has \{lines} lines, above untracked oversized-file threshold \{oversized_file_threshold()}; split it or add a ratchet budget with a target",
        )
      }
    }
  }
}

///|
fn validate_pub_all_budget(
  repo_root : String,
  budget : PubAllBudget,
  failures : Array[String],
) -> Unit {
  let mut count = 0
  for path in collect_direct_mbt_files(repo_root, budget.path, failures) {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    count += count_lines_with_prefix(text, "pub(all)")
  }
  println(
    "maintenance: " +
    budget.label +
    " pub(all)=\{count} max=\{budget.max_pub_all_lines} target=\{budget.target_pub_all_lines}",
  )
  push_max_check(
    failures,
    budget.label + " pub(all) declaration count",
    count,
    budget.max_pub_all_lines,
  )
}

///|
fn validate_root_facade_budget(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/moui.mbt"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let type_aliases = count_lines_with_prefix(text, "pub type ")
  println(
    "maintenance: root facade type aliases=\{type_aliases} max=5 target=5",
  )
  push_max_check(
    failures,
    path + " root facade type-alias forwarding count",
    type_aliases,
    5,
  )
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for budget in file_budgets() {
    validate_file_budget(repo_root, budget, failures)
  }
  validate_untracked_oversized_files(repo_root, failures)
  for budget in pub_all_budgets() {
    validate_pub_all_budget(repo_root, budget, failures)
  }
  validate_root_facade_budget(repo_root, failures)
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("maintenance baseline guardrails: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
        1
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
