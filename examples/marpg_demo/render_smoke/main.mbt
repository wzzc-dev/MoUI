// The played slice, painted for real: the same messages `play_wbtest` sends are
// pumped through the app's `update`, the resulting `view` is laid out by the
// runtime, and its draw commands go through the mainline Skia raster renderer.
// Every milestone is written as a BMP so a run leaves viewable evidence, and the
// pixel assertions are what make the run fail when the painting breaks.
//
// This is presentation evidence, not a frame-rate claim: nothing here times the
// host loop.

///|
let step_ms : Double = 100.0

///|
let notice_wait : Int32 = 25

///|
/// The service desk a played session runs against, the way `play_wbtest` builds
/// one: the fake keeps settings in memory and records every call, so the log the
/// smoke leaves behind shows the save and load really went through `AppServices`.
struct Desk {
  fake : @services.FakeAppServices
  env : @services.AppEnvironment
}

///|
fn play_desk() -> Desk {
  let fake = @services.FakeAppServices::new()
  { fake, env: @services.AppEnvironment::new(services=fake.services()), }
}

///|
fn play_msg(
  model : @marpg.Model,
  msg : @marpg.Msg,
  environment : @services.AppEnvironment,
) -> @marpg.Model {
  let (next, effect) = @marpg.update(model, msg, environment~)
  play_effect(next, effect, environment)
}

///|
fn play_effect(
  model : @marpg.Model,
  effect : @moui.Effect[@marpg.Msg],
  environment : @services.AppEnvironment,
) -> @marpg.Model {
  match effect {
    @moui.Effect::NoEffect => model
    @moui.Effect::Batch(effects) => {
      let mut state = model
      for one in effects {
        state = play_effect(state, one, environment)
      }
      state
    }
    @moui.Effect::Send(message) => play_msg(model, message, environment)
    @moui.Effect::Dispatch(_) => model
    @moui.Effect::Run(_, _) => model
    @moui.Effect::Task(_, start) => {
      let inbox : Array[@marpg.Msg] = []
      let _ = start(message => inbox.push(message))
      let mut state = model
      for message in inbox {
        state = play_msg(state, message, environment)
      }
      state
    }
  }
}

///|
fn seen_in(calls : Array[String], needle : String) -> Bool {
  for call in calls {
    if call == needle {
      return true
    }
  }
  false
}

///|
/// One offscreen Skia surface at the slice's own 240x320 canvas.  `present` runs
/// once per `render`, so a capture that is `None` after a paint means the frame
/// never reached the presenter.
struct Smoke {
  renderer : @render_skia.SkiaRasterRenderer
  captured : Ref[@render_skia.SkiaPixelFrame?]
  dir : String
}

///|
fn Smoke::new(dir : String) -> Smoke raise {
  let captured : Ref[@render_skia.SkiaPixelFrame?] = Ref(None)
  let target = @render_skia.SkiaPresentTarget::new(
    description="marpg demo offscreen smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer = @render_skia.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=240.0, height=320.0),
      scale_factor=1.0,
    ),
    target,
  )
  { renderer, captured, dir, }
}

///|
/// Lay out and paint one model through the app's real view.  A fresh runtime is
/// used per shot because the view is a pure function of the model.
fn Smoke::render(
  self : Smoke,
  model : @marpg.Model,
) -> @render_skia.SkiaPixelFrame raise {
  let runtime = @runtime.AppRuntime::new_view(
    root=@marpg.view(model),
    size=@core.Size::new(width=240.0, height=320.0),
  )
  let commands = runtime.draw_commands()
  let before = self.renderer.present_count()
  self.renderer.render(commands)
  runtime.destroy()
  let presented = self.renderer.present_count() - before
  if presented != 1 {
    abort("one paint presented \{presented} frames instead of one")
  }
  match self.captured.val {
    Some(frame) => frame
    None => abort("the Skia presenter received no frame")
  }
}

///|
fn Smoke::save(
  self : Smoke,
  frame : @render_skia.SkiaPixelFrame,
  name : String,
) -> Unit {
  let path = self.dir + "/marpg-" + name + ".bmp"
  let payload = frame_bmp(frame)
  let path_bytes = @utf8.encode(path, bom=false)
  let result = marpg_smoke_write_file(
    path_bytes,
    path_bytes.length(),
    payload,
    payload.length(),
  )
  if result != 0 {
    abort("failed to write \{path} (ffi code \{result})")
  }
  println("MoUI marpg smoke wrote " + path)
}

///|
fn pixel(
  frame : @render_skia.SkiaPixelFrame,
  x : Int32,
  y : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let pixels = frame.pixels()
  let offset = y * frame.row_bytes() + x * 4
  (
    pixels[offset].to_int(),
    pixels[offset + 1].to_int(),
    pixels[offset + 2].to_int(),
    pixels[offset + 3].to_int(),
  )
}

///|
/// `ink_panel` from `screen.mbt`, the HUD/panel fill the milestones are keyed on.
fn is_panel_rgb(r : Int32, g : Int32, b : Int32) -> Bool {
  (r - 20).abs() <= 2 && (g - 24).abs() <= 2 && (b - 32).abs() <= 2
}

///|
fn expect_pixel(
  frame : @render_skia.SkiaPixelFrame,
  x : Int32,
  y : Int32,
  r : Int32,
  g : Int32,
  b : Int32,
  label : String,
) -> Unit {
  let (actual_r, actual_g, actual_b, actual_a) = pixel(frame, x, y)
  if (actual_r - r).abs() > 2 ||
    (actual_g - g).abs() > 2 ||
    (actual_b - b).abs() > 2 ||
    actual_a != 255 {
    println("MoUI marpg smoke pixel mismatch at \{label} (\{x},\{y})")
    println("  expected rgba \{r},\{g},\{b},255")
    println("  actual   rgba \{actual_r},\{actual_g},\{actual_b},\{actual_a}")
    abort("MoUI marpg smoke pixel assertion failed: " + label)
  }
}

///|
fn expect_not_panel(
  frame : @render_skia.SkiaPixelFrame,
  x : Int32,
  y : Int32,
  label : String,
) -> Unit {
  let (r, g, b, _) = pixel(frame, x, y)
  if is_panel_rgb(r, g, b) {
    println("MoUI marpg smoke expected art at \{label} (\{x},\{y})")
    println("  actual rgba \{r},\{g},\{b}")
    abort("MoUI marpg smoke pixel assertion failed: " + label)
  }
}

///|
/// How many distinct RGB values a region holds.  A layered atlas blit leaves many;
/// a flat fill leaves one, so this is what proves the map is drawn from tiles and
/// not painted over.
fn region_distinct_colors(
  frame : @render_skia.SkiaPixelFrame,
  x0 : Int32,
  y0 : Int32,
  x1 : Int32,
  y1 : Int32,
) -> Int32 {
  let seen : Array[Int32] = []
  for y in y0..<y1 {
    for x in x0..<x1 {
      let (r, g, b, _) = pixel(frame, x, y)
      let key = r * 65536 + g * 256 + b
      let mut found = false
      for value in seen {
        if value == key {
          found = true
        }
      }
      if !found {
        seen.push(key)
      }
    }
  }
  seen.length()
}

///|
/// The first differing payload index, or -1 when the two frames are identical.
fn first_pixel_difference(
  a : @render_skia.SkiaPixelFrame,
  b : @render_skia.SkiaPixelFrame,
) -> Int32 {
  if a.width() != b.width() ||
    a.height() != b.height() ||
    a.row_bytes() != b.row_bytes() {
    return 0
  }
  let pa = a.pixels()
  let pb = b.pixels()
  if pa.length() != pb.length() {
    return 0
  }
  for i in 0..<pa.length() {
    if pa[i].to_int() != pb[i].to_int() {
      return i
    }
  }
  -1
}

///|
fn frame_bmp(frame : @render_skia.SkiaPixelFrame) -> Bytes {
  let width = frame.width()
  let height = frame.height()
  let row_bytes = frame.row_bytes()
  let pixels = frame.pixels()
  let out : Array[Byte] = []
  append_bmp_header(out, width, height)
  // A positive height means bottom-up rows, and the frame is RGBA while BMP's
  // 32-bit form is BGRA.
  for y_offset in 0..<height {
    let y = height - 1 - y_offset
    for x in 0..<width {
      let offset = y * row_bytes + x * 4
      out.push(pixels[offset + 2])
      out.push(pixels[offset + 1])
      out.push(pixels[offset])
      out.push(pixels[offset + 3])
    }
  }
  Bytes::from_array(out)
}

///|
fn append_bmp_header(out : Array[Byte], width : Int32, height : Int32) -> Unit {
  let pixel_byte_count = width * height * 4
  append_bmp_u16_le(out, 0x4D42) // BM
  append_bmp_u32_le(out, 54 + pixel_byte_count)
  append_bmp_u16_le(out, 0)
  append_bmp_u16_le(out, 0)
  append_bmp_u32_le(out, 54)

  append_bmp_u32_le(out, 40)
  append_bmp_u32_le(out, width)
  append_bmp_u32_le(out, height)
  append_bmp_u16_le(out, 1)
  append_bmp_u16_le(out, 32)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, pixel_byte_count)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
}

///|
fn append_bmp_u16_le(out : Array[Byte], value : Int32) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value / 256).land(0xFF).to_byte())
}

///|
fn append_bmp_u32_le(out : Array[Byte], value : Int32) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value / 256).land(0xFF).to_byte())
  out.push((value / 65536).land(0xFF).to_byte())
  out.push((value / 16777216).land(0xFF).to_byte())
}

///|
fn smoke_dir() -> String {
  let names = ["MOUI_MARPG_SMOKE_DIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match @env.get_env_var(name) {
      Some(value) => {
        let clean = value.trim().to_owned()
        if clean != "" {
          return clean
        }
      }
      None => ()
    }
  }
  "/tmp"
}

///|
/// Writes the BMP payload; native-stub, because the example module does not carry
/// a filesystem dependency of its own.
#borrow(path, data)
extern "C" fn marpg_smoke_write_file(
  path : Bytes,
  path_len : Int32,
  data : Bytes,
  data_len : Int32,
) -> Int32 = "marpg_smoke_write_file"

///|
fn main raise {
  if !@render_skia.skia_available() {
    abort(
      "the mainline Skia raster renderer is unavailable; this smoke is native-only",
    )
  }
  let dir = smoke_dir()
  println("MoUI marpg smoke output dir: " + dir)
  let desk = play_desk()
  let smoke = Smoke::new(dir)
  let mut model = @marpg.Model::boot()

  // Title: one engine frame raises the card over the map blit.
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let title = smoke.render(model)
  smoke.save(title, "01-title")
  expect_pixel(title, 2, 130, 20, 24, 32, "title panel row")
  expect_not_panel(title, 2, 2, "title art covers the hud row")
  println("MoUI marpg smoke: title card painted")

  // The key stream's own opening: confirm drops the title, the next frame runs
  // the boot thread's SCENE, confirm closes the arrival strip.
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let map = smoke.render(model)
  smoke.save(map, "02-map")
  expect_pixel(map, 2, 2, 20, 24, 32, "map hud row")
  expect_pixel(map, 2, 310, 20, 24, 32, "map notice strip")
  let map_colors = region_distinct_colors(map, 8, 34, 56, 82)
  if map_colors < 6 {
    abort(
      "the map region holds \{map_colors} colors; the layered blit did not paint",
    )
  }
  println(
    "MoUI marpg smoke: map painted with \{map_colors} colors in one 48x48 crop",
  )

  // Walk four tiles up and one left: the collision layer leaves that path open,
  // and each step is carried by the engine frames the walk clock consumes.
  for dir_step in [0, 0, 0, 0, 3] {
    model = play_msg(model, @marpg.Walk(dir_step), desk.env)
    for _ in 0..<8 {
      model = play_msg(model, @marpg.Frame(step_ms), desk.env)
    }
  }
  let walked = smoke.render(model)
  smoke.save(walked, "03-walked")
  expect_pixel(walked, 2, 2, 20, 24, 32, "hud after the walk")
  if first_pixel_difference(map, walked) < 0 {
    abort("the walk did not change the painted frame")
  }
  println(
    "MoUI marpg smoke: walked to the elder, frame changed under the camera",
  )

  // Confirm with no overlay is the engine's key edge: the auto-talk thread reads
  // it with the contact rect, and the card arrives as the thread's doing.
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let dialog = smoke.render(model)
  smoke.save(dialog, "04-dialog")
  expect_pixel(dialog, 2, 296, 20, 24, 32, "dialog panel")
  expect_pixel(dialog, 2, 2, 20, 24, 32, "hud stays under the dialog")
  expect_not_panel(dialog, 2, 220, "the dialog starts below y=220")
  println("MoUI marpg smoke: elder card painted over the map")

  // Second card, then the choice list; the list's taller panel is what makes the
  // choice frame structurally different from the dialog frame.
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let choice = smoke.render(model)
  smoke.save(choice, "05-choice")
  expect_pixel(choice, 2, 220, 20, 24, 32, "choice panel reaches y=220")
  expect_pixel(choice, 2, 296, 20, 24, 32, "choice panel footer")
  println("MoUI marpg smoke: two-row choice list painted")

  // Take the first row (the true branch): the key is handed over, GIVE ends its
  // frame, and the strip arrives one frame later.
  model = play_msg(model, @marpg.Turn(1), desk.env)
  model = play_msg(model, @marpg.Turn(1), desk.env)
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let message = smoke.render(model)
  smoke.save(message, "06-message")
  expect_pixel(message, 2, 240, 20, 24, 32, "message strip panel")
  println("MoUI marpg smoke: key-handover strip painted")

  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  // The chain parks on the real key wait with the screen already free, and the
  // confirming key opens the arena in the same frame.
  model = play_msg(model, @marpg.Confirm, desk.env)
  model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  let battle = smoke.render(model)
  smoke.save(battle, "07-battle")
  let (br, bg, bb, _) = pixel(battle, 2, 2)
  if is_panel_rgb(br, bg, bb) {
    abort("the arena did not open: the hud row is still on screen")
  }
  expect_pixel(battle, 120, 296, 20, 24, 32, "battle panel")
  println("MoUI marpg smoke: arena painted over the map")

  // The winning policy from `play_arena`, with the frame as the stage sensor: a
  // confirm takes the first row and the first living enemy, and once the arena
  // covers the hud the loop keeps going.  The check runs before every confirm so
  // the key that closes the arena is never replayed onto the map.
  let mut battle_frame = battle
  let mut battle_frames = 0
  let mut fighting = true
  while fighting && battle_frames < 4000 {
    let (r, g, b, _) = pixel(battle_frame, 2, 2)
    if is_panel_rgb(r, g, b) {
      fighting = false
    } else {
      model = play_msg(model, @marpg.Confirm, desk.env)
      model = play_msg(model, @marpg.Frame(step_ms), desk.env)
      battle_frame = smoke.render(model)
      battle_frames = battle_frames + 1
    }
  }
  if fighting {
    abort("the arena did not settle within \{battle_frames} engine frames")
  }
  let victory = battle_frame
  smoke.save(victory, "08-victory")
  expect_pixel(victory, 2, 2, 20, 24, 32, "hud is back after the win")
  println(
    "MoUI marpg smoke: arena settled after \{battle_frames} engine frames, back on the map",
  )

  // The chain finishes and parks, exactly as the played test leaves it.
  for _ in 0..<4 {
    model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  }

  // Save goes through the settings service for real.
  model = play_msg(model, @marpg.Save, desk.env)
  if !seen_in(desk.fake.calls(), "settings:write:" + @marpg.save_key) {
    abort("the save never reached the settings service")
  }
  let saved = smoke.render(model)
  smoke.save(saved, "09-saved")
  expect_pixel(saved, 2, 310, 20, 24, 32, "save notice strip")

  // The exact-restore proof: the same number of frames on both sides of the
  // round trip, so an idle map's tick lands on the same pixel phase.  The frame
  // after save+25 is the reference; the frame after load+25 must match it.
  for _ in 0..<notice_wait {
    model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  }
  let reference = smoke.render(model)
  smoke.save(reference, "10-reference")

  // Perturb with a played step back to the tile the hero came from.
  model = play_msg(model, @marpg.Walk(1), desk.env)
  for _ in 0..<8 {
    model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  }
  let perturbed = smoke.render(model)
  smoke.save(perturbed, "11-perturbed")
  if first_pixel_difference(reference, perturbed) < 0 {
    abort("the played step did not change the painted frame")
  }

  // Load restores the snapshot from the settings service.
  model = play_msg(model, @marpg.Load, desk.env)
  if !seen_in(desk.fake.calls(), "settings:read:" + @marpg.save_key) {
    abort("the load never read the settings service")
  }
  for _ in 0..<notice_wait {
    model = play_msg(model, @marpg.Frame(step_ms), desk.env)
  }
  let restored = smoke.render(model)
  smoke.save(restored, "12-restored")
  let diff = first_pixel_difference(reference, restored)
  if diff >= 0 {
    println("MoUI marpg smoke: restored frame differs at payload byte \{diff}")
    let (rr, rg, rb, ra) = pixel(reference, 2, 2)
    let (sr, sg, sb, sa) = pixel(restored, 2, 2)
    println("  reference (2,2) rgba \{rr},\{rg},\{rb},\{ra}")
    println("  restored  (2,2) rgba \{sr},\{sg},\{sb},\{sa}")
    abort("the loaded frame is not the saved frame")
  }
  println("MoUI marpg smoke: load restored the saved frame byte for byte")

  let diagnostics = smoke.renderer.unsupported_command_diagnostics()
  if diagnostics.length() > 0 {
    println(
      "MoUI marpg smoke: \{diagnostics.length()} unsupported draw commands",
    )
    abort("the app painted commands the mainline renderer does not support")
  }
  smoke.renderer.dispose()
  println(
    "MoUI marpg smoke passed: title, map, walk, dialog, choice, battle, save, load",
  )
}
