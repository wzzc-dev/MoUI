///|
type AppEvent = @core.AppEvent

///|
type Axis = @core.Axis

///|
type Brush = @core.Brush

///|
type CachedLayerSpec = @core.CachedLayerSpec

///|
type Color = @core.Color

///|
type CommandIntent = @core.CommandIntent

///|
type CrossAxisAlignment = @core.CrossAxisAlignment

///|
type DamageRegion = @core.DamageRegion

///|
type DatePickerMode = @core.DatePickerMode

///|
type DateValue = @core.DateValue

///|
type DrawCommand = @core.DrawCommand

///|
type Effect[Msg] = @core.Effect[Msg]

///|
type EffectPlanKind = @core.EffectPlanKind

///|
type EffectTaskCancelReason = @core.EffectTaskCancelReason

///|
type EffectTaskLifecycleStatus = @core.EffectTaskLifecycleStatus

///|
type Environment = @core.Environment

///|
type FontSpec = @core.FontSpec

///|
type PickerItem = @core.PickerItem

///|
type Point = @core.Point

///|
type PointerEvent = @core.PointerEvent

///|
type PointerPhase = @core.PointerPhase

///|
type Program[Model, Msg] = @core.Program[Model, Msg]

///|
type Rect = @core.Rect

///|
type Size = @core.Size

///|
type Subscription[Msg] = @core.Subscription[Msg]

///|
type SubscriptionCancelReason = @core.SubscriptionCancelReason

///|
type SubscriptionLifecycleStatus = @core.SubscriptionLifecycleStatus

///|
type SubscriptionPlanKind = @core.SubscriptionPlanKind

///|
type TextInputEvent = @core.TextInputEvent

///|
type View[Msg] = @core.View[Msg]

///|
fn draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn draw_text_index(commands : Array[DrawCommand], text : String) -> Int {
  for index, command in commands {
    match command {
      DrawCommand::DrawText({ text: value, .. }) =>
        if value == text {
          return index
        }
      _ => ()
    }
  }
  -1
}

///|
fn runtime_wbtest_click(runtime : AppRuntime, x~ : Double, y~ : Double) -> Unit {
  let position = Point::new(x~, y~)
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Down)),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Up)),
  )
}

///|
fn runtime_wbtest_click_draw_text(
  runtime : AppRuntime,
  text : String,
) -> Unit raise {
  guard draw_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  runtime_wbtest_click(
    runtime,
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
}
