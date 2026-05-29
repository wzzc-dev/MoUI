///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("MoUI Skia renderer smoke failed")
}

///|
fn assert_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  x : Int,
  y : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit {
  if x < 0 || y < 0 || x >= frame.width || y >= frame.height {
    fail_smoke("pixel sample is outside the Skia frame")
  }
  let offset = y * frame.row_bytes + x * 4
  if offset + 3 >= frame.pixels.length() {
    fail_smoke("pixel sample exceeds the Skia frame payload")
  }
  let actual_r = frame.pixels[offset].to_int()
  let actual_g = frame.pixels[offset + 1].to_int()
  let actual_b = frame.pixels[offset + 2].to_int()
  let actual_a = frame.pixels[offset + 3].to_int()
  if actual_r != r || actual_g != g || actual_b != b || actual_a != a {
    println("unexpected Skia renderer pixel at \{x},\{y}")
    println("expected rgba=\{r},\{g},\{b},\{a}")
    println("actual rgba=\{actual_r},\{actual_g},\{actual_b},\{actual_a}")
    fail_smoke("MoUI Skia renderer smoke pixel mismatch")
  }
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure skia_mbt/native with SKIA_MBT_HAS_SKIA, Skia headers, and linker flags before running this MoUI smoke",
    )
  }

  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia renderer smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  guard (try? @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=32.0, height=32.0),
        scale_factor=1.0,
      ),
      target,
    ))
    is Ok(renderer) else {
    fail_smoke("failed to create MoUI Skia renderer")
  }

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=4.0, width=10.0, height=10.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=18.0, y=4.0, width=10.0, height=10.0),
      @core.Color::rgba(r=0.0, g=1.0, b=0.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=18.0, width=10.0, height=10.0),
      @core.Color::rgba(r=0.0, g=0.0, b=1.0),
    ),
  ]) catch {
    err =>
      fail_smoke("failed to render MoUI Skia smoke frame: \{err.message()}")
  }

  if renderer.present_count() != 1 {
    fail_smoke("MoUI Skia renderer did not present exactly one frame")
  }
  if renderer.unsupported_command_count() != 0 {
    fail_smoke("MoUI Skia smoke hit unsupported renderer commands")
  }

  match captured.val {
    Some(frame) => {
      if frame.width != 32 || frame.height != 32 || frame.row_bytes < 128 {
        fail_smoke("MoUI Skia smoke frame dimensions are unexpected")
      }
      assert_pixel(frame, 0, 0, 255, 255, 255, 255)
      assert_pixel(frame, 8, 8, 255, 0, 0, 255)
      assert_pixel(frame, 22, 8, 0, 255, 0, 255)
      assert_pixel(frame, 8, 22, 0, 0, 255, 255)
      println("MoUI Skia renderer smoke passed")
    }
    None => fail_smoke("MoUI Skia smoke presenter did not receive a frame")
  }
}
