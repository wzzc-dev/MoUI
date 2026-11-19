///|
/// Renders the MoUI introduction sketch to a PNG frame sequence for offline
/// video assembly. The sketch clock is driven per frame through
/// `SketchView::render_commands`, so the capture is fully deterministic —
/// no window, no display, no real-time dependency.
///
/// Usage: `intro_frames [out_dir] [scale]` (run from the repo root).

///|
fn pad4(value : Int32) -> String {
  if value < 10 {
    "000\{value}"
  } else if value < 100 {
    "00\{value}"
  } else if value < 1000 {
    "0\{value}"
  } else {
    "\{value}"
  }
}

///|
fn main {
  let args = @env.args()
  let out_dir = if args.length() > 1 {
    args[1]
  } else {
    "artifacts/intro-frames"
  }
  let scale = if args.length() > 2 && args[2] == "2" { 2.0 } else { 1.0 }
  let fps = 30
  let duration_ms = 20000.0
  let all_frames = (duration_ms / 1000.0 * fps.to_double()).to_int()
  // Optional 4th/5th args select a frame range [from, to), so several
  // processes can render chunks in parallel.
  let parse = fn(index : Int32, default : Int32) -> Int32 {
    if args.length() > index {
      try @strconv.parse_int(args[index]) catch {
        _ => default
      } noraise {
        value => value
      }
    } else {
      default
    }
  }
  let from = parse(3, 0).max(0).min(all_frames)
  let to = parse(4, all_frames).max(from).min(all_frames)
  let frames = to - from
  @fs.create_dir(out_dir) catch {
    _ => ()
  }
  let save_png : (String, Bytes) -> Bool = fn(path, bytes) {
    try {
      @fs.write_bytes_to_file(path, bytes)
      true
    } catch {
      _ => false
    }
  }
  let view = @p5_app.intro_bank().sketch_view(3)
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=900.0, height=540.0),
    scale_factor=scale,
  )
  let raster = match @skia_raster.SkiaCanvasRaster::new(metrics) {
    Some(raster) => raster
    None => {
      println("could not create the skia raster session")
      return
    }
  }
  view.set_text_system(raster.text_system())
  // Prime the sketch clock at t=0 so a sub-range render carries the same
  // timeline the full render would (setup runs on the first frame call).
  ignore(view.render_commands(0.0))
  let mut written = 0
  for index in from..<to {
    let now_ms = index.to_double() * 1000.0 / fps.to_double()
    let commands = view.render_commands(now_ms)
    if index % 60 == 0 {
      println("frame \{index}: \{commands.length()} commands")
    }
    match raster.capture(commands) {
      Some(image) => {
        let name = "\{out_dir}/frame_\{pad4(index)}.png"
        if image.save(name, saver=save_png) {
          written = written + 1
        } else {
          println("failed to write \{name}")
        }
      }
      None => println("rasterize failed at frame \{index}")
    }
  }
  println(
    "wrote \{written}/\{frames} frames [\{from},\{to}) to \{out_dir} (scale \{scale})",
  )
}
