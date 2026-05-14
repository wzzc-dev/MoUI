///|
pub(all) struct HostSurfaceMetrics {
  logical_size : @core.Size
  physical_size : @core.Size
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostEvent {
  Resized(HostSurfaceMetrics)
  PointerMoved(@core.Point)
  PointerButton(@core.Point, @core.PointerPhase, Int)
  Keyboard(@core.KeyboardEvent)
  TextInput(String)
  RedrawRequested
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostEventResult {
  needs_rebuild : Bool
  needs_redraw : Bool
  redraw_requested : Bool
  close_requested : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RedrawScheduler {
  mut redraw_requested : Bool
  mut schedule : () -> Unit
}

///|
pub(all) struct HostRuntimeDriver {
  runtime : @backend.AppRuntime
  scheduler : RedrawScheduler
  mut close_requested : Bool
}

///|
pub fn HostSurfaceMetrics::new(
  logical_size~ : @core.Size,
  physical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  { logical_size, physical_size, scale_factor }
}

///|
pub fn HostSurfaceMetrics::from_logical(
  size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  {
    logical_size: size,
    physical_size: @core.Size::new(
      width=size.width * scale_factor,
      height=size.height * scale_factor,
    ),
    scale_factor,
  }
}

///|
pub fn RedrawScheduler::new(schedule~ : () -> Unit) -> RedrawScheduler {
  { redraw_requested: false, schedule }
}

///|
pub fn RedrawScheduler::request(self : RedrawScheduler) -> Unit {
  if !self.redraw_requested {
    self.redraw_requested = true
    (self.schedule)()
  }
}

///|
pub fn RedrawScheduler::begin_redraw(self : RedrawScheduler) -> Unit {
  self.redraw_requested = false
}

///|
pub fn RedrawScheduler::set_schedule(
  self : RedrawScheduler,
  schedule : () -> Unit,
) -> Unit {
  self.schedule = schedule
}

///|
pub fn RedrawScheduler::is_redraw_requested(
  self : RedrawScheduler,
) -> Bool {
  self.redraw_requested
}

///|
pub fn HostRuntimeDriver::new(
  runtime~ : @backend.AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> HostRuntimeDriver {
  let driver = {
    runtime,
    scheduler: RedrawScheduler::new(schedule=schedule_redraw),
    close_requested: false,
  }
  runtime.set_redraw_callback(() => driver.request_redraw())
  driver
}

///|
pub fn HostRuntimeDriver::dispatch(
  self : HostRuntimeDriver,
  event : HostEvent,
) -> HostEventResult {
  match event {
    Resized(metrics) => {
      self.runtime.dispatch_event(@core.AppEvent::Resize(metrics.logical_size))
      self.request_redraw()
    }
    PointerMoved(position) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase=@core.PointerPhase::Move),
        ),
      )
      self.request_redraw_if_needed()
    }
    PointerButton(position, phase, button) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase~, button~),
        ),
      )
      self.request_redraw_if_needed()
    }
    Keyboard(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Keyboard(event))
      self.request_redraw_if_needed()
    }
    TextInput(text) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Keyboard(
          @core.KeyboardEvent::new(key=text, text=Some(text)),
        ),
      )
      self.request_redraw_if_needed()
    }
    RedrawRequested => {
      self.begin_redraw()
      self.finish_redraw()
    }
    CloseRequested => {
      self.close_requested = true
      self.runtime.dispatch_event(@core.AppEvent::CloseRequested)
    }
  }
  self.event_result()
}

///|
pub fn HostRuntimeDriver::request_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.request()
}

///|
pub fn HostRuntimeDriver::set_redraw_scheduler(
  self : HostRuntimeDriver,
  schedule_redraw : () -> Unit,
) -> Unit {
  self.scheduler.set_schedule(schedule_redraw)
}

///|
pub fn HostRuntimeDriver::request_redraw_if_needed(
  self : HostRuntimeDriver,
) -> Unit {
  if self.runtime.needs_redraw() {
    self.request_redraw()
  }
}

///|
pub fn HostRuntimeDriver::begin_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.begin_redraw()
}

///|
pub fn HostRuntimeDriver::finish_redraw(self : HostRuntimeDriver) -> Unit {
  self.runtime.dispatch_event(
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
  )
}

///|
pub fn HostRuntimeDriver::draw_commands(
  self : HostRuntimeDriver,
) -> Array[@core.DrawCommand] {
  self.runtime.draw_commands()
}

///|
pub fn HostRuntimeDriver::size(self : HostRuntimeDriver) -> @core.Size {
  self.runtime.size()
}

///|
pub fn HostRuntimeDriver::event_result(
  self : HostRuntimeDriver,
) -> HostEventResult {
  {
    needs_rebuild: self.runtime.needs_rebuild(),
    needs_redraw: self.runtime.needs_redraw(),
    redraw_requested: self.scheduler.is_redraw_requested(),
    close_requested: self.close_requested,
  }
}

///|
pub fn HostEvent::to_core(self : HostEvent) -> @core.AppEvent? {
  match self {
    Resized(metrics) => Some(@core.AppEvent::Resize(metrics.logical_size))
    PointerMoved(position) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase=@core.PointerPhase::Move),
        ),
      )
    PointerButton(position, phase, button) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase~, button~),
        ),
      )
    Keyboard(event) => Some(@core.AppEvent::Keyboard(event))
    TextInput(text) =>
      Some(
        @core.AppEvent::Keyboard(
          @core.KeyboardEvent::new(key=text, text=Some(text)),
        ),
      )
    RedrawRequested =>
      Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    CloseRequested => Some(@core.AppEvent::CloseRequested)
  }
}
