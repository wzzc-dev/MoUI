///|
pub(all) enum RedrawSchedulerState {
  RedrawIdle
  RedrawScheduled
  RedrawInFrame
  RedrawFollowUpScheduled
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RedrawScheduler {
  mut state : RedrawSchedulerState
  mut schedule : () -> Unit
}

///|
pub fn RedrawScheduler::new(schedule~ : () -> Unit) -> RedrawScheduler {
  { state: RedrawIdle, schedule, }
}

///|
pub fn RedrawScheduler::request(self : RedrawScheduler) -> Unit {
  match self.state {
    RedrawIdle => {
      self.state = RedrawScheduled
      (self.schedule)()
    }
    RedrawScheduled | RedrawFollowUpScheduled => ()
    RedrawInFrame => self.state = RedrawFollowUpScheduled
  }
}

///|
fn RedrawScheduler::request_dirty(self : RedrawScheduler) -> Unit {
  self.request()
}

///|
pub fn RedrawScheduler::begin_redraw(self : RedrawScheduler) -> Unit {
  self.state = RedrawInFrame
}

///|
pub fn RedrawScheduler::finish_redraw(self : RedrawScheduler) -> Unit {
  match self.state {
    RedrawFollowUpScheduled => {
      self.state = RedrawScheduled
      (self.schedule)()
    }
    _ => self.state = RedrawIdle
  }
}

///|
pub fn RedrawScheduler::set_schedule(
  self : RedrawScheduler,
  schedule : () -> Unit,
) -> Unit {
  self.schedule = schedule
}

///|
pub fn RedrawScheduler::is_redraw_requested(self : RedrawScheduler) -> Bool {
  self.state == RedrawScheduled || self.state == RedrawFollowUpScheduled
}

///|
pub fn RedrawScheduler::state(self : RedrawScheduler) -> RedrawSchedulerState {
  self.state
}
