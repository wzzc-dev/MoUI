///|
/// A released rubber band, settling back to the authoritative offset.
///
/// Only the paint pass reads this: `band` is the visual overshoot itself, so it
/// decays directly and never describes geometry the layout did not produce.
/// `anchor` is the authoritative offset at release; when that offset moves for
/// any other reason (a wheel step, a semantic action, a `ScrollRequest`, a
/// controlled app value) the sample no longer belongs to this surface and is
/// discarded.
priv struct ScrollMotionState {
  anchor : @core.Point
  start_time_ms : Double
  duration : @core.Point
  band : @core.Point
}

///|
impl @core.ViewStateValue for ScrollMotionState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollMotionState.v1")
}

///|
impl @core.ViewStateValue for ScrollMotionState with fn encode_view_state(self) {
  let output = Buffer(size_hint=56)
  output.write_double_be(self.anchor.x)
  output.write_double_be(self.anchor.y)
  output.write_double_be(self.start_time_ms)
  output.write_double_be(self.duration.x)
  output.write_double_be(self.duration.y)
  output.write_double_be(self.band.x)
  output.write_double_be(self.band.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollMotionState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 56 {
    None
  } else {
    match @common.view_decode_doubles(bytes, from=0, count=7) {
      Some(values) =>
        Some({
          anchor: @core.Point::new(x=values[0], y=values[1]),
          start_time_ms: values[2],
          duration: @core.Point::new(x=values[3], y=values[4]),
          band: @core.Point::new(x=values[5], y=values[6]),
        })
      None => None
    }
  }
}

///|
fn scroll_motion_state_slot() -> @core.ViewStateSlot[ScrollMotionState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.motion"),
    initial={
      anchor: @core.Point::new(x=0.0, y=0.0),
      start_time_ms: 0.0,
      duration: @core.Point::new(x=0.0, y=0.0),
      band: @core.Point::new(x=0.0, y=0.0),
    },
  )
}

///|
/// How far one viewport axis may be pulled past its clamp before the damping
/// saturates. Bounding the band is what makes it safe to paint: the overshoot
/// always lands inside the region a laid-out child still covers (windowed lists
/// pad both sides of their visible rows), so no blank strip is exposed.
fn scroll_overscroll_extent(axis : Double) -> Double {
  @common.view_max_double(24.0, @common.view_min_double(120.0, axis * 0.25))
}

///|
/// Bounded nonlinear pull past a clamp edge: `over * extent / (over + extent)`
/// approaches `extent` without reaching it, so dragging a thousand pixels past
/// the end does not become a thousand pixels of visual gap.
fn scroll_overscroll_damped(over : Double, extent~ : Double) -> Double {
  if over == 0.0 || extent <= 0.0 {
    0.0
  } else {
    let magnitude = over.abs()
    let damped = magnitude * extent / (magnitude + extent)
    if over < 0.0 {
      0.0 - damped
    } else {
      damped
    }
  }
}

///|
/// Window a full-band release gets. Long enough to read as a settle, short
/// enough that it never outruns a following gesture.
fn scroll_rebound_duration_ms() -> Double {
  160.0
}

///|
/// Rebound window for one axis: a small pull settles sooner than a full band,
/// and nothing snaps faster than 60ms.
fn scroll_rebound_axis_duration(
  overscroll~ : Double,
  extent~ : Double,
) -> Double {
  if overscroll == 0.0 || extent <= 0.0 {
    0.0
  } else {
    let full = scroll_rebound_duration_ms()
    @common.view_min_double(
      full,
      @common.view_max_double(60.0, full * overscroll.abs() / extent),
    )
  }
}

///|
/// Undo the pull damping so a band grabbed mid-settle keeps being painted where
/// it is instead of snapping smaller. `over * extent / (over + extent)` inverts
/// to `over * extent / (extent - over)`; a saturated band has no finite preimage
/// and is passed through.
fn scroll_overscroll_raw(band : Double, extent~ : Double) -> Double {
  let magnitude = band.abs()
  if band == 0.0 || extent <= 0.0 || magnitude >= extent {
    band
  } else {
    let inverted = magnitude * extent / (extent - magnitude)
    if band < 0.0 {
      0.0 - inverted
    } else {
      inverted
    }
  }
}

///|
/// Overshoot a surface offset is holding past its clamp, per axis. Measured
/// against the clamp rather than against the authoritative offset, so a
/// controlled container whose app never adopts the reported offset still shifts
/// by at most one bounded band.
fn scroll_drag_band(
  raw : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
) -> @core.Point {
  let clamped = scroll_clamp_offset(raw, viewport, child_size)
  @core.Point::new(
    x=scroll_overscroll_damped(
      raw.x - clamped.x,
      extent=scroll_overscroll_extent(viewport.width),
    ),
    y=scroll_overscroll_damped(
      raw.y - clamped.y,
      extent=scroll_overscroll_extent(viewport.height),
    ),
  )
}

///|
fn scroll_motion_axis_band(
  start_time_ms~ : Double,
  duration~ : Double,
  amplitude~ : Double,
  now_ms~ : Double,
) -> Double {
  if amplitude == 0.0 || duration <= 0.0 {
    0.0
  } else {
    let elapsed = now_ms - start_time_ms
    if elapsed >= duration {
      0.0
    } else {
      let remaining = if elapsed <= 0.0 {
        1.0
      } else {
        1.0 - elapsed / duration
      }
      amplitude * remaining * remaining
    }
  }
}

///|
/// Overshoot a settling band is currently holding, or `(0, 0)` once it has
/// settled or stopped describing the authoritative offset.
fn scroll_motion_band(
  motion : ScrollMotionState,
  authoritative : @core.Point,
  now_ms~ : Double,
) -> @core.Point {
  if motion.anchor != authoritative {
    @core.Point::new(x=0.0, y=0.0)
  } else {
    @core.Point::new(
      x=scroll_motion_axis_band(
        start_time_ms=motion.start_time_ms,
        duration=motion.duration.x,
        amplitude=motion.band.x,
        now_ms~,
      ),
      y=scroll_motion_axis_band(
        start_time_ms=motion.start_time_ms,
        duration=motion.duration.y,
        amplitude=motion.band.y,
        now_ms~,
      ),
    )
  }
}

///|
/// Whether a band is still in flight, which is what keeps the host producing
/// frames until it lands (see `docs/tea-program-model.md`).
///
/// The window opens at the release itself: the frame that reacts to `Up` paints
/// in the same instant, so a predicate that required the clock to have already
/// advanced past `start_time_ms` would find the band full, decline to latch and
/// freeze the surface there. This is the boundary `button_transition` uses for
/// the same reason.
fn scroll_motion_is_animating(
  motion : ScrollMotionState,
  authoritative : @core.Point,
  now_ms~ : Double,
) -> Bool {
  motion.anchor == authoritative &&
  (
    (
      motion.duration.x > 0.0 &&
      now_ms < motion.start_time_ms + motion.duration.x
    ) ||
    (
      motion.duration.y > 0.0 &&
      now_ms < motion.start_time_ms + motion.duration.y
    )
  )
}

///|
/// Offset the surface is painted at: the authoritative clamped offset plus
/// whatever overshoot a live drag is holding or a released band is settling.
/// Layout, hit-testing and `on_scroll` keep using the authoritative value.
fn scroll_visible_offset(
  drag : ScrollDragState,
  motion : ScrollMotionState,
  authoritative : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
  now_ms~ : Double,
) -> @core.Point {
  let band = if drag.active {
    scroll_drag_band(drag.raw_offset, viewport~, child_size~)
  } else {
    scroll_motion_band(motion, authoritative, now_ms~)
  }
  @core.Point::new(x=authoritative.x + band.x, y=authoritative.y + band.y)
}
