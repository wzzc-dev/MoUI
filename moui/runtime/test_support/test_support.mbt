///|
/// Shared widget-test helpers for application package tests. They replace the
/// per-app `text_frame` / `has_text` / `click_text` copies with one
/// test-importable surface; app packages import this package only
/// `for "test"`.
///
/// Assertions run on drawn commands (`DrawText` frames) and input is real
/// pointer dispatch through the runtime tree, so a passing harness test
/// exercises layout, hit-testing, and the TEA update loop together.

///|
/// Center of the first drawn `DrawText` frame whose text equals `text`.
pub fn widget_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
/// True when any drawn `DrawText` command carries exactly `text`.
pub fn widget_has_text(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}

///|
/// Tap the center of the first drawn frame matching `text`. Raises `fail`
/// when no frame matches so tests report the missing label directly.
pub fn widget_tap_text(
  runtime : @runtime.AppRuntime,
  text : String,
) -> Unit raise {
  guard widget_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for " + text)
  }
  widget_tap_at(
    runtime,
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
}

///|
/// Dispatch one full tap (Down then Up) at a point.
pub fn widget_tap_at(
  runtime : @runtime.AppRuntime,
  x~ : Double,
  y~ : Double,
) -> Unit {
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Down),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Up),
    ),
  )
}

///|
/// Pump-and-assert harness over one runtime built from a program at fixed
/// dimensions. Convenience for new tests; the free functions above stay the
/// drop-in replacement path for existing per-app helpers.
pub struct WidgetHarness {
  priv runtime : @runtime.AppRuntime
  priv size : @core.Size
}

///|
pub fn[Model, Msg] WidgetHarness::from_program(
  program~ : @core.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
) -> WidgetHarness {
  let runtime = @runtime.new_program_with_dimensions(program~, width~, height~)
  { runtime, size: @core.Size::new(width~, height~), }
}

///|
pub fn WidgetHarness::runtime(self : WidgetHarness) -> @runtime.AppRuntime {
  self.runtime
}

///|
pub fn WidgetHarness::size(self : WidgetHarness) -> @core.Size {
  self.size
}

///|
pub fn WidgetHarness::commands(
  self : WidgetHarness,
) -> Array[@core.DrawCommand] {
  self.runtime.draw_commands()
}

///|
pub fn WidgetHarness::has_text(self : WidgetHarness, text : String) -> Bool {
  widget_has_text(self.commands(), text)
}

///|
pub fn WidgetHarness::text_frame(
  self : WidgetHarness,
  text : String,
) -> @core.Rect? {
  widget_text_frame(self.commands(), text)
}

///|
pub fn WidgetHarness::tap_text(
  self : WidgetHarness,
  text : String,
) -> Unit raise {
  widget_tap_text(self.runtime, text)
}

///|
pub fn WidgetHarness::tap_at(
  self : WidgetHarness,
  x~ : Double,
  y~ : Double,
) -> Unit {
  widget_tap_at(self.runtime, x~, y~)
}

///|
pub fn WidgetHarness::dispatch(
  self : WidgetHarness,
  event : @core.AppEvent,
) -> Unit {
  self.runtime.dispatch_event(event)
}
