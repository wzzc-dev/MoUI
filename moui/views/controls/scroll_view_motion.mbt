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
/// Whether an axis has any scroll range at all: the content is bigger than the
/// viewport along it. Travel along a rangeless axis is not scroll input, so it
/// pulls no band — there is nothing on that axis to reveal, and a surface that
/// slides sideways under the pointer is only ever hiding a child that measured
/// wider than the viewport it was given.
///
/// Only the horizontal axis is gated at its two call sites. A `scroll_view` is
/// always declared as a vertical scroller, so a vertical range is intended even
/// when a short list has none right now; a horizontal range is never declared
/// and only ever appears as an overflow.
fn scroll_axis_has_range(viewport_axis~ : Double, child_axis~ : Double) -> Bool {
  child_axis > viewport_axis
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
  let x_extent = if scroll_axis_has_range(
      viewport_axis=viewport.width,
      child_axis=child_size.width,
    ) {
    scroll_overscroll_extent(viewport.width)
  } else {
    0.0
  }
  @core.Point::new(
    x=scroll_overscroll_damped(raw.x - clamped.x, extent=x_extent),
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
/// freeze the surface there. This is the boundary `pressable_transition` uses for
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

///|
/// A released fling: release velocity the runtime advances frame by frame.
///
/// `anchor` is the authoritative offset the fling owns. The tick handler
/// rewrites it with every advance, so an offset that moved for any other
/// reason — a wheel step, a semantic action, a `ScrollRequest`, a controlled
/// app value — no longer matches and the fling is discarded, the same rule
/// the rebound band follows.
priv struct ScrollFlingState {
  anchor : @core.Point
  start_time_ms : Double
  last_time_ms : Double
  velocity : @core.Point
}

///|
impl @core.ViewStateValue for ScrollFlingState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollFlingState.v1")
}

///|
impl @core.ViewStateValue for ScrollFlingState with fn encode_view_state(self) {
  let output = Buffer(size_hint=48)
  output.write_double_be(self.anchor.x)
  output.write_double_be(self.anchor.y)
  output.write_double_be(self.start_time_ms)
  output.write_double_be(self.last_time_ms)
  output.write_double_be(self.velocity.x)
  output.write_double_be(self.velocity.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollFlingState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 48 {
    None
  } else {
    match @common.view_decode_doubles(bytes, from=0, count=6) {
      Some(values) =>
        Some({
          anchor: @core.Point::new(x=values[0], y=values[1]),
          start_time_ms: values[2],
          last_time_ms: values[3],
          velocity: @core.Point::new(x=values[4], y=values[5]),
        })
      None => None
    }
  }
}

///|
fn scroll_fling_state_slot() -> @core.ViewStateSlot[ScrollFlingState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.fling"),
    initial={
      anchor: @core.Point::new(x=0.0, y=0.0),
      start_time_ms: 0.0,
      last_time_ms: 0.0,
      velocity: @core.Point::new(x=0.0, y=0.0),
    },
  )
}

///|
/// Velocity decay time constant: a flick retains about a third of its speed
/// after this much clock time, which reads as a glide rather than a slide.
fn scroll_fling_decay_tau_ms() -> Double {
  325.0
}

///|
fn scroll_fling_decay_factor(dt~ : Double) -> Double {
  @math.exp(-dt / scroll_fling_decay_tau_ms())
}

///|
/// Below this the motion reads as stopped: one tick advances well under a
/// pixel even at a fast frame rate.
fn scroll_fling_stop_velocity_px_per_ms() -> Double {
  0.02
}

///|
/// Release velocity under this never reads as a flick; keep the plain release.
fn scroll_fling_start_velocity_px_per_ms() -> Double {
  0.08
}

///|
/// A release whose last tracked movement is older than this is a lift, not
/// the end of a flick: the tracked velocity could be from any earlier moment,
/// so the plain release wins.
fn scroll_fling_track_window_ms() -> Double {
  120.0
}

///|
/// Per-axis velocity clamp so one tracking glitch cannot launch the surface.
fn scroll_fling_max_velocity_px_per_ms() -> Double {
  4.0
}

///|
fn scroll_fling_clamp_velocity(v : Double) -> Double {
  let bound = scroll_fling_max_velocity_px_per_ms()
  v.clamp(min=0.0 - bound, max=bound)
}

///|
/// One fling step never advances the clock more than this much, so a stalled
/// host cannot teleport the surface.
fn scroll_fling_max_step_ms() -> Double {
  100.0
}

///|
/// Hard lifetime cap: even a host that keeps the animation latch alive cannot
/// tick a fling past this.
fn scroll_fling_max_duration_ms() -> Double {
  4000.0
}

///|
/// Edge-hit bounce: leftover velocity is read as this much equivalent travel
/// before the drag-band damping bounds it.
fn scroll_fling_edge_band_ms() -> Double {
  80.0
}

///|
/// Whether a fling still owns frame motion: the authoritative offset is still
/// the one it anchored, the clock is live, and at least one axis is above the
/// stop threshold. Paint reads this to keep the host producing frames while
/// the runtime's frame pump keeps advancing the offset.
fn scroll_fling_is_live(
  fling : ScrollFlingState,
  authoritative : @core.Point,
  now_ms~ : Double,
) -> Bool {
  fling.anchor == authoritative &&
  now_ms > 0.0 &&
  now_ms >= fling.start_time_ms &&
  now_ms < fling.start_time_ms + scroll_fling_max_duration_ms() &&
  (
    fling.velocity.x.abs() >= scroll_fling_stop_velocity_px_per_ms() ||
    fling.velocity.y.abs() >= scroll_fling_stop_velocity_px_per_ms()
  )
}

///|
/// One axis of a fling step: the clamped position after advancing, the decayed
/// velocity, and the rebound band amplitude if the step hit the clamp edge.
priv struct ScrollFlingAxisStep {
  position : Double
  velocity : Double
  band : Double
}

///|
/// Advance one fling axis by `dt`. Velocity decays exponentially; a step that
/// runs past the clamp lands on it, stops that axis, and hands the leftover
/// speed to the rebound band as a bounded bounce (`extent` of 0.0 — a
/// rangeless axis — means no band, just the stop).
fn scroll_fling_axis_step(
  velocity~ : Double,
  position~ : Double,
  dt~ : Double,
  extent~ : Double,
  max_offset~ : Double,
) -> ScrollFlingAxisStep {
  if velocity.abs() < scroll_fling_stop_velocity_px_per_ms() {
    return { position, velocity: 0.0, band: 0.0, }
  }
  let decayed = velocity * scroll_fling_decay_factor(dt~)
  let advanced = position + decayed * dt
  let clamped = advanced.clamp(min=0.0, max=max_offset)
  if clamped != advanced {
    let band = scroll_overscroll_damped(
      decayed * scroll_fling_edge_band_ms(),
      extent~,
    )
    return { position: clamped, velocity: 0.0, band, }
  }
  { position: advanced, velocity: decayed, band: 0.0, }
}
// Scroll drag state moved here from `scroll_view_layout.mbt`: the drag/velocity
// state is motion machinery (overshoot retention, release-velocity tracking)
// and the layout file was past its line budget.

///|
/// Transient pointer state for touch/mouse dragging over the scroll surface.
/// The runtime owns this value so it survives the rebuild triggered by a
/// scroll-state update without leaking platform pointer state into controls.
///
/// `raw_offset` is the offset the pointer has pulled the surface to *before*
/// clamping. The authoritative offset stays hard-clamped — layout, hit-testing
/// and `on_scroll` all report that value — while `raw_offset` retains the
/// overshoot so the paint pass can draw a bounded rubber band and release can
/// settle it back.
///
/// `track_position`/`track_time_ms`/`velocity` carry release-velocity tracking
/// for the fling: the tracked pair is the last sample with a distinct clock
/// stamp and real travel, and `velocity` is that interval's offset-space
/// speed in px/ms.
priv struct ScrollDragState {
  active : Bool
  dragging : Bool
  origin : @core.Point
  last_position : @core.Point
  raw_offset : @core.Point
  track_position : @core.Point
  track_time_ms : Double
  velocity : @core.Point
}

///|
impl @core.ViewStateValue for ScrollDragState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollDragState.v2")
}

///|
impl @core.ViewStateValue for ScrollDragState with fn encode_view_state(self) {
  let output = Buffer(size_hint=90)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_byte(if self.dragging { 1 } else { 0 })
  output.write_double_be(self.origin.x)
  output.write_double_be(self.origin.y)
  output.write_double_be(self.last_position.x)
  output.write_double_be(self.last_position.y)
  output.write_double_be(self.raw_offset.x)
  output.write_double_be(self.raw_offset.y)
  output.write_double_be(self.track_position.x)
  output.write_double_be(self.track_position.y)
  output.write_double_be(self.track_time_ms)
  output.write_double_be(self.velocity.x)
  output.write_double_be(self.velocity.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollDragState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 90 {
    // A rejected decode falls back to the slot's initial value, i.e. no drag
    // in progress. The pre-overscroll encodings are rejected rather than
    // folded into this shape: a fabricated `raw_offset` would pull the surface
    // to the head of the content on the next `Move`.
    None
  } else {
    let flags = (
      match bytes[0] {
        0 => Some(false)
        1 => Some(true)
        _ => None
      },
      match bytes[1] {
        0 => Some(false)
        1 => Some(true)
        _ => None
      },
    )
    match (flags, @common.view_decode_doubles(bytes, from=2, count=11)) {
      ((Some(active), Some(dragging)), Some(values)) =>
        Some({
          active,
          dragging,
          origin: @core.Point::new(x=values[0], y=values[1]),
          last_position: @core.Point::new(x=values[2], y=values[3]),
          raw_offset: @core.Point::new(x=values[4], y=values[5]),
          track_position: @core.Point::new(x=values[6], y=values[7]),
          track_time_ms: values[8],
          velocity: @core.Point::new(x=values[9], y=values[10]),
        })
      _ => None
    }
  }
}

///|
fn scroll_drag_state_slot() -> @core.ViewStateSlot[ScrollDragState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.drag"),
    initial={
      active: false,
      dragging: false,
      origin: @core.Point::new(x=0.0, y=0.0),
      last_position: @core.Point::new(x=0.0, y=0.0),
      raw_offset: @core.Point::new(x=0.0, y=0.0),
      track_position: @core.Point::new(x=0.0, y=0.0),
      track_time_ms: 0.0,
      velocity: @core.Point::new(x=0.0, y=0.0),
    },
  )
}
