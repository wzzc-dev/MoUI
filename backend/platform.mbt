///|
pub(all) struct WindowConfig {
  title : String
  width : Double
  height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum BackendEventKind {
  Resize
  Redraw
  Close
  PointerMove
} derive(Eq, Debug, ToJson)

///|
pub fn WindowConfig::default(
  title? : String = "MoUI",
  width? : Double = 800.0,
  height? : Double = 600.0,
) -> WindowConfig {
  { title, width, height }
}

///|
pub fn event_kind_to_core(
  kind : BackendEventKind,
  size? : @core.Size,
  position? : @core.Point,
) -> @core.AppEvent {
  match kind {
    Resize =>
      @core.AppEvent::Resize(
        size.unwrap_or(@core.Size::new(width=0.0, height=0.0)),
      )
    Redraw => @core.AppEvent::Redraw(@core.RedrawReason::Explicit)
    Close => @core.AppEvent::CloseRequested
    PointerMove =>
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=position.unwrap_or(@core.Point::new(x=0.0, y=0.0)),
          phase=@core.PointerPhase::Move,
        ),
      )
  }
}
