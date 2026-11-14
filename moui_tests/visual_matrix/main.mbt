///|
/// Offscreen control-state matrix.
///
/// Renders every interactive control at every visual state in both schemes
/// through the Sun CPU raster renderer, writes one raw RGBA frame per cell plus
/// `report.json`, and reports expected states that paint exactly like the
/// resting state (`missing_states`). `scripts/visual-control-matrix.mjs` adds
/// PNGs and the profile gate on top.
///
/// State detection is command-based, not pixel-based: a control whose only
/// state change is a text or border color must count as "styled" even when the
/// bare test host has no glyphs. Pixels are the artifact, commands are the
/// assertion.

///|
struct MatrixControl {
  id : String
  width : Double
  height : Double
  /// States that must paint differently from the resting state.
  expected : Array[String]
  /// States whose hover/press change must animate (and snap under reduced motion).
  expected_transitions : Array[String]
  /// View-state slot key the control's paint reads (`radio`/`toggle` paint the
  /// checkbox node, which keys its transition as "checkbox").
  transition_key : String
  build : (@core.Theme) -> @core.View[Unit]
}

///|
let matrix_states : Array[String] = [
  "default", "hover", "pressed", "focused", "disabled",
]

///|
fn matrix_controls() -> Array[MatrixControl] {
  [
    {
      id: "button",
      transition_key: "button",
      expected_transitions: ["hover", "pressed"],
      width: 160.0,
      height: 32.0,
      expected: ["hover", "pressed", "focused", "disabled"],
      build: theme => {
        @views.button("Primary", on_click=(), theme~, width=160.0, height=32.0)
      },
    },
    {
      id: "text_field",
      transition_key: "text_field",
      expected_transitions: ["hover"],
      width: 220.0,
      height: 32.0,
      expected: ["hover", "focused", "disabled"],
      build: theme => {
        @views.text_field("api-gateway", on_input=_ => (), theme~, width=220.0)
      },
    },
    {
      id: "checkbox",
      transition_key: "checkbox",
      expected_transitions: ["hover", "pressed"],
      width: 180.0,
      height: 24.0,
      expected: ["hover", "pressed", "focused", "disabled"],
      build: theme => {
        @views.checkbox(
          "Notifications",
          checked=true,
          on_change=_ => (),
          theme~,
        )
      },
    },
    {
      id: "radio",
      transition_key: "checkbox",
      expected_transitions: ["hover", "pressed"],
      width: 180.0,
      height: 24.0,
      expected: ["hover", "pressed", "focused", "disabled"],
      // `radio` is `checkbox` with the circle/dot shape plus a role modifier;
      // the matrix paints the node itself, so build that node directly.
      build: theme => {
        @views.checkbox(
          "Radio",
          checked=true,
          on_change=_ => (),
          theme~,
          box_shape=@views.ChoiceControlShape::Circle,
          check_style=@views.CheckMarkStyle::Dot,
        )
      },
    },
    {
      id: "toggle",
      transition_key: "checkbox",
      expected_transitions: ["hover", "pressed"],
      width: 180.0,
      height: 24.0,
      expected: ["hover", "pressed", "focused", "disabled"],
      // `toggle` is the checkbox node with a switch role modifier; the matrix
      // paints the node itself.
      build: theme => {
        @views.checkbox("Toggle", checked=true, on_change=_ => (), theme~)
      },
    },
    {
      id: "slider",
      transition_key: "slider",
      expected_transitions: ["hover", "pressed"],
      width: 220.0,
      height: 28.0,
      expected: ["hover", "pressed", "focused", "disabled"],
      build: theme => {
        @views.slider(
          0.6,
          label="Volume",
          value_text="60%",
          theme~,
          width=220.0,
        )
      },
    },
  ]
}

///|
fn matrix_state(state : String) -> @core.ViewStateContext {
  let resting : @core.ViewStateContext = {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
  match state {
    "hover" => { ..resting, hovered: true, }
    "pressed" => { ..resting, hovered: true, pressed: true, }
    "focused" => { ..resting, focused: true, }
    "disabled" => { ..resting, disabled: true, }
    _ => resting
  }
}

///|
fn matrix_environment(scheme : @core.ColorScheme) -> @core.Environment {
  @core.Environment::neutral().with_theme_spec(
    @views.desktop_theme_spec(scheme~),
  )
}

///|
fn matrix_theme(scheme : @core.ColorScheme) -> @core.Theme {
  @views.theme_from_spec(
    @views.desktop_theme_spec(scheme~),
    system_scheme=scheme,
  )
}

///|
fn matrix_paint_context(
  environment : @core.Environment,
  state_name : String,
  width : Double,
  height : Double,
  state~ : @core.ViewStateContext,
  now_ms~ : Double,
) -> @core.ViewPaintContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width~, height~),
    child_frames: [],
    focused: state.focused,
    state,
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    },
    environment: if state_name == "disabled" {
      environment.with_enabled(false)
    } else {
      environment
    },
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms,
  }
}

///|
/// Which rasterizer produced the artifacts. The gate never depends on pixels,
/// but the doc previews must be reproducible across hosts, so the preview
/// generator forces one mode instead of taking whatever the host has.
enum MatrixRenderer {
  Auto
  Skia
  Sun
}

///|
struct MatrixFrame {
  width : Int32
  height : Int32
  row_bytes : Int32
  pixels : Bytes
}

///|
fn matrix_render_skia(
  commands : Array[@core.DrawCommand],
  width : Double,
  height : Double,
) -> MatrixFrame? {
  let captured : Ref[@moui_skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @moui_skia_renderer.SkiaPresentTarget::new(
    description="moui-visual-matrix-preview",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let created : Result[@moui_skia_renderer.SkiaRasterRenderer, Unit] = try
    @moui_skia_renderer.create_with_present_target(
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width~, height~),
        scale_factor=2.0,
      ),
      target,
    )
  catch {
    _ => Err(())
  } noraise {
    renderer => Ok(renderer)
  }
  match created {
    Ok(renderer) => {
      let rendered : Result[Unit, Unit] = try renderer.render(commands) catch {
        _ => Err(())
      } noraise {
        _ => Ok(())
      }
      match rendered {
        Ok(_) =>
          match captured.val {
            Some(frame) =>
              Some({
                width: frame.width(),
                height: frame.height(),
                row_bytes: frame.row_bytes(),
                pixels: frame.pixels(),
              })
            None => None
          }
        Err(_) => None
      }
    }
    Err(_) => None
  }
}

///|
fn matrix_render_sun(
  commands : Array[@core.DrawCommand],
  width : Double,
  height : Double,
) -> MatrixFrame raise {
  let frames : Array[@moui_sun_renderer.SunPixelFrame] = []
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width~, height~),
      scale_factor=2.0,
    ),
    @moui_sun_renderer.SunPresentTarget::new(description="moui-visual-matrix", present=frame => {
      frames.push(frame)
      true
    }),
  )
  renderer.render(commands)
  match frames.last() {
    Some(frame) =>
      {
        width: frame.width(),
        height: frame.height(),
        row_bytes: frame.row_bytes(),
        pixels: frame.bytes(),
      }
    None => abort("visual matrix renderer never presented a frame")
  }
}

///|
/// Render with Skia when the host has it (real glyphs for the doc previews),
/// and fall back to the Sun CPU raster when it does not. State detection never
/// depends on pixels, so the renderer choice only changes artifact quality.
fn matrix_render(
  commands : Array[@core.DrawCommand],
  width : Double,
  height : Double,
  background~ : @core.Color,
  renderer~ : MatrixRenderer,
) -> MatrixFrame raise {
  // The control commands are transparent outside their own paint; clear to the
  // theme background so the artifact is a real screenshot, not a black frame.
  let render_commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(background),
  ]
  for command in commands {
    render_commands.push(command)
  }
  match renderer {
    Sun => matrix_render_sun(render_commands, width, height)
    Skia =>
      match matrix_render_skia(render_commands, width, height) {
        Some(frame) => frame
        None =>
          abort(
            "skia renderer unavailable: the doc previews need a Skia-capable host",
          )
      }
    Auto =>
      match matrix_render_skia(render_commands, width, height) {
        Some(frame) => frame
        None => matrix_render_sun(render_commands, width, height)
      }
  }
}

///|
fn matrix_cell_id(control : String, scheme : String, state : String) -> String {
  "\{control}-\{scheme}-\{state}"
}

///|
fn matrix_json_entry(
  control : String,
  scheme : String,
  state : String,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  blank : Bool,
  changed : Bool,
  expected : Bool,
) -> String {
  let missing = expected && !changed
  "{" +
  "\"control\":\"" +
  control +
  "\"," +
  "\"scheme\":\"" +
  scheme +
  "\"," +
  "\"state\":\"" +
  state +
  "\"," +
  "\"file\":\"" +
  matrix_cell_id(control, scheme, state) +
  ".rgba\"," +
  "\"width\":" +
  width.to_string() +
  "," +
  "\"height\":" +
  height.to_string() +
  "," +
  "\"rowBytes\":" +
  row_bytes.to_string() +
  "," +
  "\"blank\":" +
  (if blank { "true" } else { "false" }) +
  "," +
  "\"changedFromDefault\":" +
  (if changed { "true" } else { "false" }) +
  "," +
  "\"expected\":" +
  (if expected { "true" } else { "false" }) +
  "," +
  "\"missing\":" +
  (if missing { "true" } else { "false" }) +
  "}"
}

///|
fn matrix_hex(color : @core.Color) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let channel = fn(value : Double) {
    let clamped = if value <= 0.0 {
      0
    } else if value >= 1.0 {
      255
    } else {
      (value * 255.0).to_int()
    }
    String::from_array([digits[clamped / 16], digits[clamped % 16]])
  }
  "#" + channel(color.r) + channel(color.g) + channel(color.b)
}

///|
fn matrix_transition_target(state : String) -> @core.PressableState {
  match state {
    "hover" => @core.PressableState::Hovered
    "pressed" => @core.PressableState::Pressed
    _ => @core.PressableState::Normal
  }
}

///|
fn matrix_transition_commands(
  view : @core.View[Unit],
  environment : @core.Environment,
  state_name : String,
  control : MatrixControl,
  now_ms : Double,
) -> Array[@core.DrawCommand] {
  let recorded = @common.pressable_state_with_transition(
    matrix_state("default"),
    @core.PressableState::Normal,
    matrix_transition_target(state_name),
    0.0,
    control=control.transition_key,
  )
  view.paint(
    matrix_paint_context(
      environment,
      state_name,
      control.width,
      control.height,
      state=recorded,
      now_ms~,
    ),
  ).commands
}

///|
fn matrix_transition_json_entry(
  control : String,
  scheme : String,
  state : String,
  animated : Bool,
  snaps : Bool,
  expected : Bool,
) -> String {
  let missing = expected && (!animated || !snaps)
  "{" +
  "\"control\":\"" +
  control +
  "\"," +
  "\"scheme\":\"" +
  scheme +
  "\"," +
  "\"state\":\"" +
  state +
  "\"," +
  "\"animated\":" +
  (if animated { "true" } else { "false" }) +
  "," +
  "\"reducedSnaps\":" +
  (if snaps { "true" } else { "false" }) +
  "," +
  "\"expected\":" +
  (if expected { "true" } else { "false" }) +
  "," +
  "\"missing\":" +
  (if missing { "true" } else { "false" }) +
  "}"
}

///|
fn matrix_run(out_dir : String, renderer~ : MatrixRenderer) -> Int32 raise {
  let controls = matrix_controls()
  let entries : Array[String] = []
  let missing : Array[String] = []
  let transitions : Array[String] = []
  let missing_transitions : Array[String] = []
  let mut light_background = ""
  let mut dark_background = ""
  for control in controls {
    for scheme in [@core.ColorScheme::Light, @core.ColorScheme::Dark] {
      let scheme_name = match scheme {
        @core.ColorScheme::Light => "light"
        @core.ColorScheme::Dark => "dark"
      }
      let theme = matrix_theme(scheme)
      let background_hex = matrix_hex(theme.palette.background)
      if scheme == @core.ColorScheme::Light {
        light_background = background_hex
      } else {
        dark_background = background_hex
      }
      let environment = matrix_environment(scheme)
      let view = (control.build)(theme)
      let mut resting_commands : Array[@core.DrawCommand] = []
      let mut resting_ready = false
      for state in matrix_states {
        let context = matrix_paint_context(
          environment,
          state,
          control.width,
          control.height,
          state=matrix_state(state),
          now_ms=0.0,
        )
        let commands = view.paint(context).commands
        let changed = if state == "default" {
          resting_commands = commands
          resting_ready = true
          false
        } else if resting_ready {
          commands != resting_commands
        } else {
          false
        }
        let expected = control.expected.contains(state)
        if expected && !changed {
          missing.push(matrix_cell_id(control.id, scheme_name, state))
        }
        let frame = matrix_render(
          commands,
          control.width,
          control.height,
          background=theme.palette.background,
          renderer~,
        )
        let file = matrix_cell_id(control.id, scheme_name, state) + ".rgba"
        @fs.write_bytes_to_file(out_dir + "/" + file, frame.pixels)
        entries.push(
          matrix_json_entry(
            control.id,
            scheme_name,
            state,
            frame.width,
            frame.height,
            frame.row_bytes,
            commands.is_empty(),
            changed,
            expected,
          ),
        )
      }
      let duration_ms = theme.motion.fast_ms.min(150.0)
      let mid_ms = duration_ms / 2.0
      for state in control.expected_transitions {
        let terminal = view.paint(
            matrix_paint_context(
              environment,
              state,
              control.width,
              control.height,
              state=matrix_state(state),
              now_ms=0.0,
            ),
          ).commands
        let mid = matrix_transition_commands(
          view, environment, state, control, mid_ms,
        )
        let reduced = matrix_transition_commands(
          view,
          environment.with_reduced_motion(true),
          state,
          control,
          mid_ms,
        )
        let animated = mid != resting_commands && mid != terminal
        let snaps = reduced == terminal
        if !(animated && snaps) {
          missing_transitions.push(
            matrix_cell_id(control.id, scheme_name, state),
          )
        }
        transitions.push(
          matrix_transition_json_entry(
            control.id,
            scheme_name,
            state,
            animated,
            snaps,
            true,
          ),
        )
      }
    }
  }
  let controls_json = controls
    .map(control => "\"" + control.id + "\"")
    .join(",")
  let renderer_label = match renderer {
    Sun => "sun"
    Skia => "skia"
    Auto => "auto"
  }
  let report = "{" +
    "\"schemaVersion\":1," +
    "\"renderer\":\"" +
    renderer_label +
    "\"," +
    "\"generatedBy\":\"moui_tests/visual_matrix\"," +
    "\"scaleFactor\":2," +
    "\"controls\":[" +
    controls_json +
    "]," +
    "\"states\":[\"default\",\"hover\",\"pressed\",\"focused\",\"disabled\"]," +
    "\"backgrounds\":{\"light\":\"" +
    light_background +
    "\",\"dark\":\"" +
    dark_background +
    "\"}," +
    "\"entries\":[" +
    entries.join(",") +
    "]," +
    "\"missing_states\":[" +
    missing.map(id => "\"" + id + "\"").join(",") +
    "]," +
    "\"transitions\":[" +
    transitions.join(",") +
    "]," +
    "\"missing_transitions\":[" +
    missing_transitions.map(id => "\"" + id + "\"").join(",") +
    "]" +
    "}"
  @fs.write_string_to_file(out_dir + "/report.json", report)
  if missing.is_empty() && missing_transitions.is_empty() {
    println(
      "visual matrix: \{entries.length()} cells, \{transitions.length()} transitions, no missing styles",
    )
    0
  } else {
    if !missing.is_empty() {
      println(
        "visual matrix: \{missing.length()} missing states: \{missing.join(", ")}",
      )
    }
    if !missing_transitions.is_empty() {
      println(
        "visual matrix: \{missing_transitions.length()} missing transitions: \{missing_transitions.join(", ")}",
      )
    }
    1
  }
}

///|
fn matrix_out_dir(args : Array[String]) -> String {
  let mut index = 1
  let mut out_dir = "artifacts/visual-matrix"
  while index < args.length() {
    if args[index] == "--out" && index + 1 < args.length() {
      out_dir = args[index + 1]
      index = index + 2
    } else {
      index = index + 1
    }
  }
  out_dir
}

///|
fn matrix_renderer(args : Array[String]) -> MatrixRenderer {
  let mut index = 1
  let mut renderer = Auto
  while index < args.length() {
    if args[index] == "--renderer" && index + 1 < args.length() {
      renderer = match args[index + 1] {
        "sun" => Sun
        "skia" => Skia
        _ => Auto
      }
      index = index + 2
    } else {
      index = index + 1
    }
  }
  renderer
}

///|
fn main {
  let out_dir = matrix_out_dir(@env.args())
  let renderer = matrix_renderer(@env.args())
  let code = matrix_run(out_dir, renderer~) catch {
    error => {
      println("visual matrix failed: \{error}")
      1
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
