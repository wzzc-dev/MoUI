///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let app = @app.MarkdownEditorApp::new_with_services(services)
  let timer_source = @macos_host.macos_timer_source()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services, timer_source=Some(timer_source)),
    width=1000.0,
    height=640.0,
  )
  let commands = app.action_commands(services~)
  runtime.set_action_commands(commands)

  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }

  // Set up native macOS system menu bar. This must run after the app finishes
  // launching (during `did_finish_launching` the default macOS menu bar is
  // installed and would overwrite an earlier custom menu), so it is deferred
  // to the `on_ready` hook which fires once the primary window is created.
  @macos_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      surface_route~,
      transparent_titlebar=true,
      on_ready=Some(() => setup_system_menu(runtime)),
      min_window_size=Some(@dpi.LogicalSize::LogicalSize(816.0, 480.0)),
    ),
  )
}

///|
/// Action IDs for system menu items. Each ID maps to a command that is
/// dispatched through the runtime when the menu item is clicked.
const ACTION_NEW : Int = 1
const ACTION_OPEN : Int = 2
const ACTION_SAVE : Int = 3
const ACTION_SAVE_AS : Int = 4
const ACTION_UNDO : Int = 10
const ACTION_REDO : Int = 11
const ACTION_CUT : Int = 12
const ACTION_COPY : Int = 13
const ACTION_PASTE : Int = 14
const ACTION_SELECT_ALL : Int = 15
const ACTION_FIND : Int = 16
const ACTION_BOLD : Int = 20
const ACTION_ITALIC : Int = 21
const ACTION_CODE : Int = 22
const ACTION_STRIKE : Int = 23
const ACTION_LINK : Int = 24
const ACTION_H1 : Int = 30
const ACTION_H2 : Int = 31
const ACTION_H3 : Int = 32
const ACTION_H4 : Int = 33
const ACTION_H5 : Int = 34
const ACTION_H6 : Int = 35
const ACTION_PARAGRAPH : Int = 36
const ACTION_BULLET_LIST : Int = 37
const ACTION_ORDERED_LIST : Int = 38
const ACTION_TASK_LIST : Int = 39
const ACTION_QUOTE : Int = 40
const ACTION_CODE_BLOCK : Int = 41
const ACTION_TABLE : Int = 42
const ACTION_HORIZONTAL_RULE : Int = 43
const ACTION_SOURCE_MODE : Int = 50
const ACTION_FOCUS_MODE : Int = 51
const ACTION_TYPEWRITER_MODE : Int = 52
const ACTION_ZEN_MODE : Int = 53
const ACTION_TOGGLE_OUTLINE : Int = 54
const ACTION_TOGGLE_FILES : Int = 55
const ACTION_TOGGLE_DOC_INFO : Int = 56
const ACTION_TOGGLE_SOURCE_PREVIEW : Int = 57
const ACTION_TOGGLE_DARK_MODE : Int = 58

///|
/// macOS modifier key masks.
const MODIFIER_COMMAND : Int = 1_048_576
const MODIFIER_COMMAND_SHIFT : Int = 1_048_576 + 131_072
const MODIFIER_COMMAND_OPTION : Int = 1_048_576 + 524_288

///|
/// Build the system menu bar and register the action handler.
fn setup_system_menu(runtime : @runtime.AppRuntime) -> Unit {
  @window_macos.set_system_menu_action_handler(fn(action_id : Int) {
    let intent = match action_id {
      ACTION_UNDO => @moui.CommandIntent::Undo
      ACTION_REDO => @moui.CommandIntent::Redo
      ACTION_CUT => @moui.CommandIntent::Cut
      ACTION_COPY => @moui.CommandIntent::Copy
      ACTION_PASTE => @moui.CommandIntent::Paste
      ACTION_SELECT_ALL => @moui.CommandIntent::SelectAll
      _ => @moui.CommandIntent::Activate
    }
    ignore(runtime.dispatch_command(intent))
  })

  let cmd_mod = MODIFIER_COMMAND
  let cmd_shift = MODIFIER_COMMAND_SHIFT
  let cmd_option = MODIFIER_COMMAND_OPTION

  fn mi(title : String, action_id : Int, key : String, mask : Int) -> @window_macos.SystemMenuItemDescriptor {
    @window_macos.SystemMenuItemDescriptor::new(
      title~, action_id~, key_equivalent=key, key_modifier_mask=mask, separator=false,
    )
  }
  fn sep() -> @window_macos.SystemMenuItemDescriptor {
    @window_macos.SystemMenuItemDescriptor::new(
      title="", action_id=0, key_equivalent="", key_modifier_mask=-1, separator=true,
    )
  }
  fn menu(title : String, items : Array[@window_macos.SystemMenuItemDescriptor]) -> @window_macos.SystemMenuDescriptor {
    @window_macos.SystemMenuDescriptor::new(title~, items~)
  }

  @window_macos.set_system_menus([
    menu("File", [
      mi("New", ACTION_NEW, "n", cmd_mod),
      mi("Open…", ACTION_OPEN, "o", cmd_mod),
      mi("Save", ACTION_SAVE, "s", cmd_mod),
      mi("Save As…", ACTION_SAVE_AS, "s", cmd_shift),
    ]),
    menu("Edit", [
      mi("Undo", ACTION_UNDO, "z", cmd_mod),
      mi("Redo", ACTION_REDO, "z", cmd_shift),
      sep(),
      mi("Cut", ACTION_CUT, "x", cmd_mod),
      mi("Copy", ACTION_COPY, "c", cmd_mod),
      mi("Paste", ACTION_PASTE, "v", cmd_mod),
      mi("Select All", ACTION_SELECT_ALL, "a", cmd_mod),
      sep(),
      mi("Find…", ACTION_FIND, "f", cmd_mod),
    ]),
    menu("Format", [
      mi("Bold", ACTION_BOLD, "b", cmd_mod),
      mi("Italic", ACTION_ITALIC, "i", cmd_mod),
      mi("Inline Code", ACTION_CODE, "e", cmd_mod),
      mi("Strikethrough", ACTION_STRIKE, "x", cmd_shift),
      mi("Link…", ACTION_LINK, "k", cmd_mod),
      sep(),
      mi("Heading 1", ACTION_H1, "1", cmd_mod),
      mi("Heading 2", ACTION_H2, "2", cmd_mod),
      mi("Heading 3", ACTION_H3, "3", cmd_mod),
      mi("Heading 4", ACTION_H4, "4", cmd_mod),
      mi("Heading 5", ACTION_H5, "5", cmd_mod),
      mi("Heading 6", ACTION_H6, "6", cmd_mod),
      mi("Paragraph", ACTION_PARAGRAPH, "0", cmd_mod),
      sep(),
      mi("Bullet List", ACTION_BULLET_LIST, "u", cmd_shift),
      mi("Ordered List", ACTION_ORDERED_LIST, "o", cmd_shift),
      mi("Task List", ACTION_TASK_LIST, "t", cmd_shift),
      mi("Blockquote", ACTION_QUOTE, "q", cmd_shift),
      mi("Code Block", ACTION_CODE_BLOCK, "k", cmd_shift),
      mi("Table", ACTION_TABLE, "", -1),
      mi("Horizontal Rule", ACTION_HORIZONTAL_RULE, "", -1),
    ]),
    menu("View", [
      mi("Source Mode", ACTION_SOURCE_MODE, "/", cmd_shift),
      mi("Focus Mode", ACTION_FOCUS_MODE, "f", cmd_shift),
      mi("Typewriter Mode", ACTION_TYPEWRITER_MODE, "t", cmd_shift),
      mi("Zen Mode", ACTION_ZEN_MODE, "z", cmd_option),
      sep(),
      mi("Toggle Outline", ACTION_TOGGLE_OUTLINE, "o", cmd_option),
      mi("Toggle Files", ACTION_TOGGLE_FILES, "p", cmd_option),
      mi("Document Info", ACTION_TOGGLE_DOC_INFO, "d", cmd_option),
      mi("Source Preview", ACTION_TOGGLE_SOURCE_PREVIEW, "/", cmd_mod),
      sep(),
      mi("Toggle Dark Mode", ACTION_TOGGLE_DARK_MODE, "", -1),
    ]),
  ])
}
