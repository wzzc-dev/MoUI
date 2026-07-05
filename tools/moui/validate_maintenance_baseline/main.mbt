///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct FileBudget {
  path : String
  max_lines : Int
}

///|
struct LineBudgetOverflow {
  path : String
  lines : Int
}

///|
struct CountBudget {
  kind : String
  label : String
  path : String
  max_count : Int
}

///|
struct CountBudgetOverflow {
  kind : String
  label : String
  count : Int
  max_count : Int
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_maintenance_baseline [--repo-root PATH]
    #|
    #|Checks the tracked maintenance ratchets for oversized files, direct
    #|source-level pub(all) counts, and root facade type forwarding. The
    #|current max values lock in previous debt so future refactors can ratchet
    #|them down after splitting files or shrinking public exposure.
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
    { path: "examples/showcase/app/showcase_app_test.mbt", max_lines: 386 },
    {
      path: "examples/showcase/app/showcase_examples_app_test.mbt",
      max_lines: 105,
    },
    {
      path: "examples/showcase/app/showcase_test_helpers_test.mbt",
      max_lines: 350,
    },
    {
      path: "examples/showcase/app/showcase_diagnostics_app_test.mbt",
      max_lines: 380,
    },
    {
      path: "examples/showcase/app/showcase_navigation_app_test.mbt",
      max_lines: 405,
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_wbtest.mbt",
      max_lines: 1000,
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_formatting_wbtest.mbt",
      max_lines: 420,
    },
    {
      path: "examples/markdown_editor/app/editor_snapshot_parser_wbtest.mbt",
      max_lines: 360,
    },
    {
      path: "examples/markdown_editor/app/editor_app_runtime_wbtest.mbt",
      max_lines: 116,
    },
    {
      path: "examples/markdown_editor/app/editor_app_document_runtime_wbtest.mbt",
      max_lines: 470,
    },
    {
      path: "examples/markdown_editor/app/editor_app_document_transfer_runtime_wbtest.mbt",
      max_lines: 800,
    },
    {
      path: "examples/markdown_editor/app/editor_app_modes_runtime_wbtest.mbt",
      max_lines: 440,
    },
    {
      path: "examples/markdown_editor/app/editor_app_writing_modes_runtime_wbtest.mbt",
      max_lines: 285,
    },
    {
      path: "examples/markdown_editor/app/editor_app_outline_runtime_wbtest.mbt",
      max_lines: 210,
    },
    {
      path: "examples/markdown_editor/app/editor_app_keyboard_runtime_wbtest.mbt",
      max_lines: 800,
    },
    {
      path: "examples/markdown_editor/app/editor_app_inline_keyboard_runtime_wbtest.mbt",
      max_lines: 295,
    },
    {
      path: "examples/markdown_editor/app/editor_app_task_runtime_wbtest.mbt",
      max_lines: 56,
    },
    {
      path: "examples/markdown_editor/app/editor_app_backspace_delete_runtime_wbtest.mbt",
      max_lines: 299,
    },
    {
      path: "examples/markdown_editor/app/editor_app_clipboard_runtime_wbtest.mbt",
      max_lines: 345,
    },
    {
      path: "examples/markdown_editor/app/editor_app_enter_table_keyboard_runtime_wbtest.mbt",
      max_lines: 430,
    },
    { path: "moui/backend/host/host_test.mbt", max_lines: 50 },
    { path: "moui/backend/host/host_services_test.mbt", max_lines: 255 },
    {
      path: "moui/backend/host/host_driver_context_menu_test.mbt",
      max_lines: 240,
    },
    {
      path: "moui/backend/host/host_subscription_sources_test.mbt",
      max_lines: 275,
    },
    {
      path: "moui/backend/host/host_route_timer_subscription_sources_test.mbt",
      max_lines: 220,
    },
    {
      path: "moui/backend/host/host_app_services_facade_test.mbt",
      max_lines: 210,
    },
    {
      path: "moui/backend/host/host_async_service_queue_test.mbt",
      max_lines: 210,
    },
    {
      path: "moui/backend/host/host_service_completion_subscription_test.mbt",
      max_lines: 180,
    },
    { path: "moui/backend/host/host_image_test.mbt", max_lines: 110 },
    {
      path: "moui/backend/host/host_image_repaint_tracker_test.mbt",
      max_lines: 305,
    },
    {
      path: "moui/backend/host/host_image_completion_source_test.mbt",
      max_lines: 210,
    },
    {
      path: "moui/backend/host/host_async_image_loader_test.mbt",
      max_lines: 500,
    },
    { path: "moui/backend/host/host_text_input_test.mbt", max_lines: 310 },
    {
      path: "moui/backend/host/host_text_input_context_menu_test.mbt",
      max_lines: 210,
    },
    {
      path: "moui/backend/host/host_text_input_composition_test.mbt",
      max_lines: 100,
    },
    { path: "moui/backend/host/host_text_input_ime_test.mbt", max_lines: 255 },
    {
      path: "moui/backend/host/host_platform_contract_test.mbt",
      max_lines: 255,
    },
    { path: "moui/backend/host/host_window_lifecycle_test.mbt", max_lines: 310 },
    {
      path: "moui/backend/host/host_window_runtime_slots_test.mbt",
      max_lines: 185,
    },
    { path: "moui/backend/host/host_window_commands_test.mbt", max_lines: 140 },
    { path: "moui/backend/host/host_window_requests_test.mbt", max_lines: 335 },
    { path: "moui/backend/host/window_lifecycle.mbt", max_lines: 520 },
    { path: "moui/backend/host/window_runtime_slots.mbt", max_lines: 240 },
    { path: "moui/backend/host/window_request_queue.mbt", max_lines: 150 },
    { path: "moui/backend/host/window_platform_map.mbt", max_lines: 110 },
    { path: "moui/backend/web/host_runtime.mbt", max_lines: 480 },
    { path: "moui/backend/web/web_async_services.mbt", max_lines: 620 },
    { path: "moui/backend/web/web_events.mbt", max_lines: 240 },
    { path: "moui/backend/web/web_host.mbt", max_lines: 390 },
    { path: "moui/backend/web/web_window_requests.mbt", max_lines: 200 },
    { path: "moui/backend/web/web_window_slots.mbt", max_lines: 85 },
    { path: "moui/core/view_tree.mbt", max_lines: 896 },
    { path: "moui/core/view_style.mbt", max_lines: 180 },
    { path: "moui/core/custom_layout.mbt", max_lines: 130 },
    { path: "moui/core/date_value.mbt", max_lines: 135 },
    { path: "moui/core/program_subscription.mbt", max_lines: 360 },
    { path: "examples/pdf_workbench/app/app.mbt", max_lines: 390 },
    { path: "examples/pdf_workbench/app/host_services.mbt", max_lines: 530 },
    { path: "examples/pdf_workbench/app/navigation.mbt", max_lines: 230 },
    { path: "examples/pdf_workbench/app/edit_commands.mbt", max_lines: 220 },
    { path: "examples/pdf_workbench/app/view_layout.mbt", max_lines: 190 },
    { path: "examples/pdf_workbench/app/view_chrome.mbt", max_lines: 215 },
    { path: "examples/pdf_workbench/app/view_page.mbt", max_lines: 245 },
    { path: "examples/pdf_workbench/app/view_preview.mbt", max_lines: 315 },
    { path: "examples/pdf_workbench/app/view_sidebar.mbt", max_lines: 285 },
    { path: "examples/pdf_workbench/app/view_inspector.mbt", max_lines: 470 },
    { path: "moui/render/skia/skia_renderer_wbtest.mbt", max_lines: 75 },
    { path: "moui/render/sun/renderer.mbt", max_lines: 1950 },
    { path: "moui/views/style_api.mbt", max_lines: 178 },
    { path: "moui/views/choice_state.mbt", max_lines: 25 },
    { path: "moui/views/choice_groups.mbt", max_lines: 70 },
    { path: "moui/views/choice_segmented.mbt", max_lines: 60 },
    { path: "moui/views/choice_chips.mbt", max_lines: 160 },
    { path: "moui/views/control_choice.mbt", max_lines: 89 },
    { path: "moui/views/control_helpers.mbt", max_lines: 40 },
    { path: "moui/views/control_progress.mbt", max_lines: 69 },
    { path: "moui/views/control_slider.mbt", max_lines: 167 },
    { path: "moui/views/control_focus_overlay.mbt", max_lines: 95 },
    { path: "moui/views/form_state.mbt", max_lines: 45 },
    { path: "moui/views/form_layout.mbt", max_lines: 69 },
    { path: "moui/views/form_field.mbt", max_lines: 82 },
    { path: "moui/views/form_field_state.mbt", max_lines: 40 },
    { path: "moui/views/form_field_support.mbt", max_lines: 145 },
    { path: "moui/views/form_validation.mbt", max_lines: 205 },
    { path: "moui/views/form_workflow.mbt", max_lines: 198 },
    { path: "moui/views/form_support_text.mbt", max_lines: 48 },
    { path: "moui/views/text_input_controls.mbt", max_lines: 1809 },
    { path: "moui/views/input_group_shell.mbt", max_lines: 45 },
    { path: "moui/views/input_text_wrappers.mbt", max_lines: 95 },
    { path: "moui/views/input_number.mbt", max_lines: 105 },
    { path: "moui/views/feedback_state.mbt", max_lines: 135 },
    { path: "moui/views/feedback_guidance.mbt", max_lines: 70 },
    { path: "moui/views/feedback_panel.mbt", max_lines: 125 },
    { path: "moui/views/feedback_transient.mbt", max_lines: 130 },
    { path: "moui/views/feedback_status.mbt", max_lines: 185 },
    { path: "moui/views/feedback_progress.mbt", max_lines: 150 },
    { path: "moui/views/feedback_badge.mbt", max_lines: 130 },
    { path: "moui/views/file_import_state.mbt", max_lines: 45 },
    { path: "moui/views/layout_state.mbt", max_lines: 40 },
    { path: "moui/views/grid_list.mbt", max_lines: 25 },
    { path: "moui/views/virtual_list.mbt", max_lines: 185 },
    { path: "moui/views/sectioned_list.mbt", max_lines: 185 },
    { path: "moui/views/lazy_grid.mbt", max_lines: 95 },
    { path: "moui/views/layout_helpers.mbt", max_lines: 180 },
    { path: "moui/views/layout_flow.mbt", max_lines: 145 },
    { path: "moui/views/layout_responsive_grid.mbt", max_lines: 155 },
    { path: "moui/views/layout_baseline_form.mbt", max_lines: 160 },
    { path: "moui/views/toolbar.mbt", max_lines: 120 },
    { path: "moui/views/command_palette.mbt", max_lines: 121 },
    { path: "moui/views/disclosure.mbt", max_lines: 194 },
    { path: "moui/views/navigation_state.mbt", max_lines: 203 },
    { path: "moui/views/popover_overlay.mbt", max_lines: 60 },
    { path: "moui/views/popover_selectors.mbt", max_lines: 137 },
    { path: "moui/views/popover_menu.mbt", max_lines: 60 },
    { path: "moui/views/navigation.mbt", max_lines: 125 },
    { path: "moui/views/navigation_breadcrumb.mbt", max_lines: 50 },
    { path: "moui/views/navigation_route_header.mbt", max_lines: 93 },
    { path: "moui/views/navigation_section_nav.mbt", max_lines: 133 },
    { path: "moui/views/navigation_sidebar.mbt", max_lines: 56 },
    { path: "moui/views/navigation_split.mbt", max_lines: 115 },
    { path: "moui/views/navigation_presentation.mbt", max_lines: 120 },
    { path: "moui/views/dialog_alert.mbt", max_lines: 85 },
    { path: "moui/views/dialog_shell.mbt", max_lines: 185 },
    { path: "moui/views/data_display_state.mbt", max_lines: 15 },
    { path: "moui/views/data_filter_state.mbt", max_lines: 25 },
    { path: "moui/views/data_sort_pagination.mbt", max_lines: 105 },
    { path: "moui/views/data_table_state.mbt", max_lines: 45 },
    { path: "moui/views/data_table_visibility_state.mbt", max_lines: 60 },
    { path: "moui/views/data_table_width_state.mbt", max_lines: 75 },
    { path: "moui/views/data_table_order_state.mbt", max_lines: 65 },
    { path: "moui/views/data_selection_state.mbt", max_lines: 88 },
    { path: "moui/views/data_tree_state.mbt", max_lines: 20 },
    { path: "moui/views/data_display.mbt", max_lines: 141 },
    { path: "moui/views/data_pagination.mbt", max_lines: 60 },
    { path: "moui/views/data_selectable_list.mbt", max_lines: 170 },
    { path: "moui/views/data_selection_toolbar.mbt", max_lines: 105 },
    { path: "moui/views/data_avatar.mbt", max_lines: 103 },
    { path: "moui/views/data_tree.mbt", max_lines: 145 },
    { path: "moui/views/data_filter_bar.mbt", max_lines: 149 },
    { path: "moui/views/data_filter_column_visibility.mbt", max_lines: 150 },
    { path: "moui/views/data_table.mbt", max_lines: 63 },
    { path: "moui/views/data_table_rendering.mbt", max_lines: 185 },
    {
      path: "examples/pdf_workbench/app/pdf_workbench_app_wbtest.mbt",
      max_lines: 25,
    },
    {
      path: "examples/markdown_editor/app/editor_input_wbtest.mbt",
      max_lines: 157,
    },
    {
      path: "examples/markdown_editor/app/editor_commands_wbtest.mbt",
      max_lines: 80,
    },
    {
      path: "examples/markdown_editor/app/editor_commands_blocks_wbtest.mbt",
      max_lines: 205,
    },
    { path: "moui/render/skia/renderer_text.mbt", max_lines: 50 },
    { path: "moui/tests/skia_renderer_smoke/native/main.mbt", max_lines: 1880 },
    { path: "moui/runtime/runtime.mbt", max_lines: 455 },
    { path: "moui/runtime/program_runtime_diagnostics.mbt", max_lines: 270 },
    { path: "moui/runtime/program_runtime_effect_tasks.mbt", max_lines: 130 },
    { path: "moui/runtime/program_runtime_subscriptions.mbt", max_lines: 185 },
  ]
}

///|
fn pub_all_budgets() -> Array[CountBudget] {
  [
    { kind: "pub(all)", label: "moui/core", path: "moui/core", max_count: 280 },
    { kind: "pub(all)", label: "moui/views", path: "moui/views", max_count: 82 },
    {
      kind: "pub(all)",
      label: "moui/runtime",
      path: "moui/runtime",
      max_count: 42,
    },
    {
      kind: "pub(all)",
      label: "moui/backend/host",
      path: "moui/backend/host",
      max_count: 170,
    },
    {
      kind: "pub(all)",
      label: "moui/render",
      path: "moui/render",
      max_count: 118,
    },
    {
      kind: "pub(all)",
      label: "examples/showcase/app",
      path: "examples/showcase/app",
      max_count: 8,
    },
    {
      kind: "pub(all)",
      label: "examples/markdown_editor/app",
      path: "examples/markdown_editor/app",
      max_count: 0,
    },
    {
      kind: "pub(all)",
      label: "examples/pdf_workbench/app",
      path: "examples/pdf_workbench/app",
      max_count: 20,
    },
    {
      kind: "pub(all)",
      label: "examples/mo_workbench/app",
      path: "examples/mo_workbench/app",
      // Multi-workspace shell (Code/Write/Settings implemented + 3 reserved)
      // exposes Workspace/AppearanceMode/ApprovalPolicy/SandboxMode/
      // ChatMessage/WorkbenchMsg/CodeMsg/SettingsMsg/WriteMsg +
      // AgentBackendRuntime/AgentBackendFixture/AgentCommand/AgentEvent/
      // ModelChoice/ThinkingChoice/TurnStatus/SessionSummary. Budget leaves
      // headroom for the reserved workspaces (ConnectPhone/ScheduledTasks/
      // Plugins) to gain their own pub(all) types when implemented.
      max_count: 20,
    },
    {
      kind: "pub(all)",
      label: "website/app",
      path: "website/app",
      max_count: 0,
    },
  ]
}

///|
fn root_facade_forward_budget() -> CountBudget {
  {
    kind: "root facade forwards",
    label: "moui/moui.mbt",
    path: "moui/moui.mbt",
    max_count: 50,
  }
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
fn count_lines_containing_token(text : String, token : String) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.contains(token) {
      count += 1
    }
  }
  count
}

///|
fn count_root_facade_forwards(text : String) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.has_prefix("pub type ") {
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
fn record_file_budget_overflow(
  repo_root : String,
  budget : FileBudget,
  overflows : Array[LineBudgetOverflow],
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
  if lines > budget.max_lines {
    overflows.push({ path: budget.path, lines })
  }
}

///|
fn record_untracked_oversized_files(
  repo_root : String,
  overflows : Array[LineBudgetOverflow],
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
        overflows.push({ path, lines })
      }
    }
  }
}

///|
fn sort_line_budget_overflows(overflows : Array[LineBudgetOverflow]) -> Unit {
  overflows.sort_by((left, right) => {
    let by_lines = right.lines - left.lines
    if by_lines != 0 {
      by_lines
    } else {
      right.path.compare(left.path)
    }
  })
}

///|
fn line_budget_overflow_paths(
  overflows : Array[LineBudgetOverflow],
) -> Array[String] {
  sort_line_budget_overflows(overflows)
  overflows.map(overflow => overflow.path)
}

///|
fn collect_line_budget_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[LineBudgetOverflow] {
  let overflows : Array[LineBudgetOverflow] = []
  for budget in file_budgets() {
    record_file_budget_overflow(repo_root, budget, overflows, failures)
  }
  record_untracked_oversized_files(repo_root, overflows, failures)
  sort_line_budget_overflows(overflows)
  overflows
}

///|
fn record_count_budget_overflow(
  budget : CountBudget,
  count : Int,
  overflows : Array[CountBudgetOverflow],
) -> Unit {
  if count > budget.max_count {
    overflows.push({
      kind: budget.kind,
      label: budget.label,
      count,
      max_count: budget.max_count,
    })
  }
}

///|
fn count_pub_all_in_tree(
  repo_root : String,
  root : String,
  failures : Array[String],
) -> Int {
  let files : Array[String] = []
  collect_mbt_files(repo_root, root, files, failures)
  let mut count = 0
  for path in files {
    if !generated_fixture_path(path) {
      match read_repo_text(repo_root, path) {
        Ok(text) => count += count_lines_containing_token(text, "pub(all)")
        Err(message) => failures.push(message)
      }
    }
  }
  count
}

///|
fn collect_count_budget_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[CountBudgetOverflow] {
  let overflows : Array[CountBudgetOverflow] = []
  for budget in pub_all_budgets() {
    let count = count_pub_all_in_tree(repo_root, budget.path, failures)
    record_count_budget_overflow(budget, count, overflows)
  }
  let root_budget = root_facade_forward_budget()
  match read_repo_text(repo_root, root_budget.path) {
    Ok(text) =>
      record_count_budget_overflow(
        root_budget,
        count_root_facade_forwards(text),
        overflows,
      )
    Err(message) => failures.push(message)
  }
  sort_count_budget_overflows(overflows)
  overflows
}

///|
fn sort_count_budget_overflows(overflows : Array[CountBudgetOverflow]) -> Unit {
  overflows.sort_by((left, right) => {
    let by_kind = left.kind.compare(right.kind)
    if by_kind != 0 {
      by_kind
    } else {
      left.label.compare(right.label)
    }
  })
}

///|
fn count_budget_overflow_message(overflow : CountBudgetOverflow) -> String {
  overflow.kind +
  " budget exceeded: " +
  overflow.label +
  " count=\{overflow.count} max=\{overflow.max_count}"
}

///|
fn count_budget_overflow_messages(
  overflows : Array[CountBudgetOverflow],
) -> Array[String] {
  sort_count_budget_overflows(overflows)
  overflows.map(count_budget_overflow_message)
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let overflows = collect_line_budget_overflows(repo_root, failures)
  let count_overflows = collect_count_budget_overflows(repo_root, failures)
  if !failures.is_empty() {
    failures
  } else {
    let messages = line_budget_overflow_paths(overflows)
    messages.append(count_budget_overflow_messages(count_overflows))
    messages
  }
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
