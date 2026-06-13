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
      max_lines: 700,
      target_lines: 640,
      reason: "keep Mo Workbench Pi transport, diagnostic, session, and error ingest tests compact",
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
      max_lines: 690,
      target_lines: 620,
      reason: "keep Showcase main catalog, section coverage, layout, and reusable example tests compact",
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
      path: "examples/markdown_editor/app/input_blocks.mbt",
      max_lines: 1260,
      target_lines: 1150,
      reason: "keep Markdown Editor block input shortcuts, code fences, paste, indent, and continuation transforms compact",
    },
    {
      path: "examples/markdown_editor/app/input_blocks_ordered.mbt",
      max_lines: 295,
      target_lines: 260,
      reason: "keep Markdown Editor ordered-list renumbering, offset mapping, and digit parsing compact",
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
      max_lines: 480,
      target_lines: 430,
      reason: "keep host service bridge and driver context-menu tests compact",
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
      max_lines: 615,
      target_lines: 560,
      reason: "keep host image renderer, repaint tracker, and completion source tests compact",
    },
    {
      path: "moui/backend/host/host_async_image_loader_test.mbt",
      max_lines: 350,
      target_lines: 320,
      reason: "keep host async image loader and native image source tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_test.mbt",
      max_lines: 515,
      target_lines: 470,
      reason: "keep host text input clipboard, shortcut, and context-menu tests compact",
    },
    {
      path: "moui/backend/host/host_text_input_ime_test.mbt",
      max_lines: 345,
      target_lines: 315,
      reason: "keep host text input IME session and event conversion tests compact",
    },
    {
      path: "moui/backend/host/host_window_lifecycle_test.mbt",
      max_lines: 555,
      target_lines: 510,
      reason: "keep host window lifecycle, platform ids, and scene resolver tests compact",
    },
    {
      path: "moui/backend/host/host_window_runtime_slots_test.mbt",
      max_lines: 185,
      target_lines: 165,
      reason: "keep host window runtime slot and platform driver tests compact",
    },
    {
      path: "moui/backend/host/host_window_requests_test.mbt",
      max_lines: 465,
      target_lines: 420,
      reason: "keep host window request queue and command helper tests compact",
    },
    {
      path: "moui/core/rich_text_editor_wbtest.mbt",
      max_lines: 665,
      target_lines: 600,
      reason: "keep core rich text editor cache, input, IME, drawing, and placeholder tests compact",
    },
    {
      path: "moui/core/rich_text_editor_mapping_wbtest.mbt",
      max_lines: 540,
      target_lines: 490,
      reason: "keep core rich text editor source-mapped visual text, pointer, selection, and table mapping tests compact",
    },
    {
      path: "examples/pdf_workbench/app/app.mbt",
      max_lines: 1335,
      target_lines: 1250,
      reason: "keep PDF Workbench app runtime, service, and edit command flow compact",
    },
    {
      path: "moui/render/skia/skia_renderer_wbtest.mbt",
      max_lines: 75,
      target_lines: 75,
      reason: "keep Skia renderer matrix, surface, and brush smoke tests compact",
    },
    {
      path: "moui/views/views_test.mbt",
      max_lines: 20,
      target_lines: 20,
      reason: "keep top-level views facade smoke and shared test runtime helper compact",
    },
    {
      path: "moui/views/views_data_commands_test.mbt",
      max_lines: 485,
      target_lines: 440,
      reason: "keep views data display, filtering, table, list, and selection tests compact",
    },
    {
      path: "moui/views/views_command_surfaces_test.mbt",
      max_lines: 475,
      target_lines: 430,
      reason: "keep views toolbar, command, menu, gesture, card, and file-import surface tests compact",
    },
    {
      path: "moui/views/views_form_feedback_test.mbt",
      max_lines: 365,
      target_lines: 330,
      reason: "keep views form field, workflow, input wrapper, choice, and semantics tests compact",
    },
    {
      path: "moui/views/views_feedback_state_test.mbt",
      max_lines: 245,
      target_lines: 220,
      reason: "keep views feedback surface, theme color, state helper, and progress action tests compact",
    },
    {
      path: "moui/views/views_overlay_navigation_test.mbt",
      max_lines: 320,
      target_lines: 285,
      reason: "keep views navigation shell, split, slider, section navigation, and router tests compact",
    },
    {
      path: "moui/views/views_overlay_surfaces_test.mbt",
      max_lines: 225,
      target_lines: 200,
      reason: "keep views popover, dropdown, alert, dialog, and dialog host tests compact",
    },
    {
      path: "moui/core/runtime_wbtest.mbt",
      max_lines: 40,
      target_lines: 35,
      reason: "keep basic AppRuntime dispatch smoke compact",
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
      max_lines: 40,
      target_lines: 35,
      reason: "keep core View wrapper and realization entry compact",
    },
  ]
}

///|
fn pub_all_budgets() -> Array[PubAllBudget] {
  [
    {
      label: "core source",
      path: "moui/core",
      max_pub_all_lines: 211,
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
    "maintenance: root facade type aliases=\{type_aliases} max=16 target=16",
  )
  push_max_check(
    failures,
    path + " root facade type-alias forwarding count",
    type_aliases,
    16,
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
