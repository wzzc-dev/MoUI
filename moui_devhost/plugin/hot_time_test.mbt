///|
priv struct HotTimeProbeView {
  ticks : Int32
}

///|
impl @core.ViewNode for HotTimeProbeView with fn identity(_self) {
  @core.ViewIdentity::new(kind="HotTimeProbeView")
}

///|
impl @core.ViewNode for HotTimeProbeView with fn layout(self, context) {
  ignore(self)
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=200.0, height=40.0),
    ),
  )
}

///|
impl @core.ViewNode for HotTimeProbeView with fn paint(self, context) {
  let frame = context.frame
  let font = @core.FontSpec::new(size=12.0)
  let lines = [
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="ticks \{self.ticks}",
        frame~,
        font~,
        color=@core.Color::black(),
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="clock \{context.now_ms.to_int()}",
        frame=@core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y + 16.0,
          width=frame.size.width,
          height=16.0,
        ),
        font~,
        color=@core.Color::black(),
      ),
    ),
  ]
  @core.ViewPaintPlan::animating_commands(lines)
}

///|
priv enum HotTimeMsg {
  TimerTick(@core.Frame)
}

///|
fn hot_time_program() -> @core.Program[Int32, HotTimeMsg] {
  let environment = @plugin.hot_environment()
  let timer = environment.timer()
  @core.Program::new_with_environment(
    init=() => (0, @core.Effect::none()),
    update=(ticks, message) => {
      match message {
        TimerTick(frame) => {
          ignore(frame)
          (ticks + 1, @core.Effect::none())
        }
      }
    },
    view=(ticks, _env) => @core.View::from_node(HotTimeProbeView::{ ticks, }),
    subscriptions=_ticks => {
      match timer {
        Some(timer) =>
          @services.TimerSource::subscription(
            timer,
            interval_ms=50.0,
            map=frame => TimerTick(frame),
            key="hot-time-test",
            label="Hot time test",
          )
        None => @core.Subscription::none()
      }
    },
  )
}

///|
fn dispatch_frame(session : @plugin.Session, time_ms : Double) -> Bool {
  let event = @core.AppEvent::FrameTick(
    @core.Frame::new(time_ms~, delta_ms=16.0),
  )
  let payload = match @protocol.encode_event(event) {
    Some(payload) => payload
    None => abort("frame tick failed to encode")
  }
  session.dispatch_json(payload)
}

///|
fn frame_texts(session : @plugin.Session) -> Array[String] {
  let commands = match @protocol.decode_frame(session.frame_json()) {
    Some(commands) => commands
    None => abort("plugin frame failed to decode")
  }
  let texts : Array[String] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
  texts
}

///|
test "host frame ticks advance the plugin clock and fire app timers" {
  let runtime = @runtime.new_program_with_dimensions(
    program=hot_time_program(),
    width=200.0,
    height=40.0,
  )
  let session = @plugin.Session::new(runtime, None)
  if !dispatch_frame(session, 0.0) {
    abort("frame tick rejected")
  }
  let initial = frame_texts(session)
  if initial[0] != "ticks 0" {
    abort("timer fired before it was due")
  }
  if !dispatch_frame(session, 60.0) {
    abort("frame tick rejected")
  }
  let after_one = frame_texts(session)
  if after_one[0] != "ticks 1" {
    abort("app timer did not fire after a host frame tick")
  }
  if after_one[1] != "clock 60" {
    abort("paint clock did not advance with the host frame")
  }
  if !dispatch_frame(session, 120.0) {
    abort("frame tick rejected")
  }
  let after_two = frame_texts(session)
  if after_two[0] != "ticks 2" {
    abort("app timer did not fire a second time")
  }
  if after_two[1] != "clock 120" {
    abort("paint clock did not keep advancing")
  }
  session.destroy()
}
