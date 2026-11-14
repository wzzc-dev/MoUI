///|
/// Offscreen gallery screenshots for the README and the website.
///
/// Mounts `examples/gallery/app` at its published window size (1080×820), paints
/// it through the Skia raster renderer at 2× scale, and writes raw RGBA frames
/// plus `manifest.json`. `scripts/generate-gallery-screenshots.mjs` encodes the
/// PNGs and verifies committed copies, so the images cannot silently drift from
/// the default theme.
///
/// The runtime's frame clear now follows the environment theme background, so
/// the tool renders exactly what the app presents and does not rewrite commands.

///|
struct ShotFrame {
  name : String
  file : String
  width : Int32
  height : Int32
  row_bytes : Int32
  pixels : Bytes
}

///|
fn arg_value(args : Array[String], flag : String) -> String? {
  let mut index = 0
  while index < args.length() {
    if args[index] == flag && index + 1 < args.length() {
      return Some(args[index + 1])
    }
    index = index + 1
  }
  None
}

///|
fn shot_commands(dark~ : Bool) -> Array[@core.DrawCommand] {
  let model = if dark {
    @gallery.update(@gallery.Model::new(), @gallery.SetDark(true))
  } else {
    @gallery.Model::new()
  }
  // Mirror the macOS entrypoint: the runtime environment stays on the desktop
  // spec/system scheme, and the gallery's own root theme switches dark. That
  // keeps the screenshot path honest about the frame clear following the
  // root-scoped theme.
  let environment = @core.Environment::neutral().with_theme_spec(
    @views.desktop_theme_spec(),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=@gallery.program_with_model(model),
    width=1080.0,
    height=820.0,
    environment~,
  )
  runtime.draw_commands()
}

///|
fn shot_render(
  commands : Array[@core.DrawCommand],
  width : Double,
  height : Double,
) -> ShotFrame {
  let captured : Ref[@moui_skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @moui_skia_renderer.SkiaPresentTarget::new(
    description="moui-gallery-screenshot",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let created = try
    @moui_skia_renderer.create_with_present_target(
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width~, height~),
        scale_factor=2.0,
      ),
      target,
    )
  catch {
    _ => abort("skia renderer unavailable: gallery screenshots need Skia")
  } noraise {
    renderer => renderer
  }
  let rendered = try created.render(commands) catch {
    _ => abort("skia render failed while painting the gallery")
  } noraise {
    _ => ()
  }
  ignore(rendered)
  match captured.val {
    Some(frame) =>
      {
        name: "",
        file: "",
        width: frame.width(),
        height: frame.height(),
        row_bytes: frame.row_bytes(),
        pixels: frame.pixels(),
      }
    None => abort("skia present target did not capture a gallery frame")
  }
}

///|
fn shot_manifest(frames : Array[ShotFrame]) -> String {
  let entries : Array[String] = []
  for frame in frames {
    entries.push(
      "{" +
      "\"name\":\"" +
      frame.name +
      "\"," +
      "\"file\":\"" +
      frame.file +
      "\"," +
      "\"width\":" +
      frame.width.to_string() +
      "," +
      "\"height\":" +
      frame.height.to_string() +
      "," +
      "\"rowBytes\":" +
      frame.row_bytes.to_string() +
      "}",
    )
  }
  "{\"frames\":[" + entries.join(",") + "]}"
}

///|
fn shot_write(out_dir : String, frame : ShotFrame) -> Unit raise {
  @fs.write_bytes_to_file(out_dir + "/" + frame.file, frame.pixels)
}

///|
fn run() -> Unit raise {
  let args = @env.args()
  let out_dir = match arg_value(args, "--out") {
    Some(value) => value
    None => abort("usage: gallery_screenshots --out DIR")
  }
  let light = shot_render(shot_commands(dark=false), 1080.0, 820.0)
  let dark = shot_render(shot_commands(dark=true), 1080.0, 820.0)
  let light_frame : ShotFrame = {
    ..light,
    name: "gallery-light",
    file: "gallery-light.rgba",
  }
  let dark_frame : ShotFrame = {
    ..dark,
    name: "gallery-dark",
    file: "gallery-dark.rgba",
  }
  shot_write(out_dir, light_frame)
  shot_write(out_dir, dark_frame)
  @fs.write_string_to_file(
    out_dir + "/manifest.json",
    shot_manifest([light_frame, dark_frame]),
  )
}

///|
fn main {
  run() catch {
    error => {
      println("gallery screenshots failed: \{error}")
      abort("gallery screenshots failed")
    }
  }
}
