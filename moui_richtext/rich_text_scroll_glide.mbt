///|
/// An eased scroll glide: the transition between two scroll offsets,
/// evaluated at paint/event time from the runtime's animation clock
/// (`ViewPaintContext.now_ms` / `ViewEventContext.now_ms`).
///
/// Storing the glide instead of a resolved offset is what keeps scrolling
/// smooth: the offset shown is always sampled for the frame being drawn, so
/// there is no timer tick grid to beat against the display refresh, and the
/// animation runs in real time on 60Hz, 120Hz and variable-refresh displays
/// alike. A glide with `from_y == to_y` is at rest and evaluates to a
/// constant.
///
/// A glide is a *follower*, not a keyframe animation: re-keying one mid-flight
/// must always start from the offset currently being shown
/// (`offset_at(now)`), never from the pending target. Starting from the target
/// teleports the view by however far the ease still had to go, which reads as
/// a jump — and when the new target is behind the shown offset (a direction
/// reversal, or a clamp at the document edge) the jump is backwards.

///|
pub(all) struct MarkdownScrollGlide {
  from_y : Double
  to_y : Double
  start_ms : Double
  /// Exponential time constant for this glide, in milliseconds: how quickly
  /// the shown offset closes the remaining distance to `to_y`. Callers pick it
  /// per input kind — a deliberate wheel notch can afford a visible ease,
  /// while a dense momentum stream wants only enough smoothing to even out its
  /// own irregular event cadence.
  tau_ms : Double
} derive(Eq, Debug, ToJson)

///|
let markdown_scroll_geometry_compensation : Ref[Double] = Ref(0.0)

///|
let markdown_scroll_last_frame_time : Ref[Double] = Ref(0.0)

///|
/// Record the runtime clock used by the most recent paint. App-level view
/// construction has no paint context, so this is the only safe timestamp to
/// use when it must apply a measurement compensation between frames.
pub fn markdown_scroll_publish_frame_time(now_ms : Double) -> Unit {
  markdown_scroll_last_frame_time.val = now_ms
}

///|
pub fn markdown_scroll_peek_frame_time() -> Double {
  markdown_scroll_last_frame_time.val
}

///|
/// Publish a measurement compensation for the owner of the controlled editor
/// to consume on its next state/view build.
pub fn markdown_scroll_publish_geometry_compensation(delta : Double) -> Unit {
  if delta != 0.0 {
    markdown_scroll_geometry_compensation.val = markdown_scroll_geometry_compensation.val +
      delta
  }
}

///|
/// Consume pending measurement compensation exactly once.
pub fn markdown_scroll_take_geometry_compensation() -> Double {
  let value = markdown_scroll_geometry_compensation.val
  markdown_scroll_geometry_compensation.val = 0.0
  value
}

///|
/// Read, without consuming, the compensation published by the last paint.
/// Retained view nodes use this while the owning app is between paints and
/// its next state rebuild: geometry has already moved, so rendering against
/// the old glide would expose one frame of backward displacement.
pub fn markdown_scroll_peek_geometry_compensation() -> Double {
  markdown_scroll_geometry_compensation.val
}

///|
/// Sample the offset that the current frame is actually showing.
///
/// Geometry measurement is committed during paint, while the owning app may
/// not have rebuilt its glide yet. Every input and paint path must therefore
/// use the same frame-local value: the exact glide sample plus the pending
/// anchor translation, quantized once at the end.
pub fn MarkdownScrollGlide::display_offset(
  self : MarkdownScrollGlide,
  now_ms : Double,
  compensation? : Double = 0.0,
  scale? : Double = 1.0,
) -> Double {
  markdown_scroll_glide_snap(self.exact_offset_at(now_ms) + compensation, scale)
}

///|
pub fn MarkdownScrollGlide::new(
  from_y~ : Double,
  to_y~ : Double,
  start_ms~ : Double,
  tau_ms? : Double = markdown_scroll_glide_time_constant_ms(),
) -> MarkdownScrollGlide {
  { from_y, to_y, start_ms, tau_ms }
}

///|
/// A glide already at rest at `y`: paints `y` for every clock value.
pub fn MarkdownScrollGlide::settled(y : Double) -> MarkdownScrollGlide {
  {
    from_y: y,
    to_y: y,
    start_ms: 0.0,
    tau_ms: markdown_scroll_glide_time_constant_ms(),
  }
}

///|
/// Apply a geometry anchor compensation while preserving the animation's
/// direction and velocity. Both endpoints move together, so a height change
/// cannot create an input-free reverse jump.
pub fn MarkdownScrollGlide::with_anchor_compensation(
  self : MarkdownScrollGlide,
  compensation : Double,
  max_offset : Double,
  now_ms? : Double = 0.0,
) -> MarkdownScrollGlide {
  let max_offset = max_offset.max(0.0)
  let exact_shown = self.exact_offset_at(now_ms)
  let from = (self.from_y + compensation).max(0.0).min(max_offset)
  let translated_to = self.to_y + compensation
  let unclamped_shifted_shown = exact_shown + compensation
  let shifted_shown = unclamped_shifted_shown.max(0.0).min(max_offset)
  let clamped_to = translated_to.max(0.0).min(max_offset)
  // A range shrink can clamp the translated target past the point currently
  // shown by the glide. Continuing to that target would manufacture a short
  // reverse animation even though the user did not reverse direction. Keep
  // the visible point as the new settled position in that case. Genuine user
  // reversals are preserved because they already have the opposite direction
  // in `self.to_y - exact_shown` before geometry is applied.
  let old_direction = self.to_y - exact_shown
  let new_direction = clamped_to - shifted_shown
  let crosses_shown = old_direction.abs() > 0.0001 &&
    new_direction.abs() > 0.0001 &&
    (
      (old_direction > 0.0 && new_direction < 0.0) ||
      (old_direction < 0.0 && new_direction > 0.0)
    )
  let to = if crosses_shown { shifted_shown } else { clamped_to }
  let candidate : MarkdownScrollGlide = {
    from_y: from,
    to_y: to,
    start_ms: self.start_ms,
    tau_ms: self.tau_ms,
  }
  // Pure translation preserves the existing clock phase exactly. When range
  // clamping clips only one endpoint, however, evaluating the clipped glide
  // at `now_ms` would move the content away from the anchor. Re-key from the
  // already visible, compensated position and keep the clamped target; this
  // changes no displayed frame and only removes the impossible tail.
  if (candidate.exact_offset_at(now_ms) - shifted_shown).abs() > 0.0001 {
    { from_y: shifted_shown, to_y: to, start_ms: now_ms, tau_ms: self.tau_ms }
  } else {
    candidate
  }
}

///|
/// Time constant of the default ease, in milliseconds: the fraction of the
/// remaining distance still ahead after this much time is 1/e ≈ 37%. 90ms
/// settles a wheel notch with the same crisp glide VS Code's editor uses.
fn markdown_scroll_glide_time_constant_ms() -> Double {
  90.0
}

///|
/// Minimum glide speed in px/ms for the ease's tail. The exponential step
/// shrinks below a pixel per frame as the offset nears the target; with
/// whole-pixel snapping that motion rounds away and the glide would stall
/// (or, with an aggressive settle rule, visibly jump). The floor keeps the
/// last few pixels moving at a constant ~125px/s so every notch lands
/// exactly, decelerating imperceptibly.
fn markdown_scroll_glide_min_velocity_px_per_ms() -> Double {
  0.125
}

///|
/// Once the remaining distance drops below this many logical pixels the
/// glide counts as settled: sub-pixel creep is invisible and would only keep
/// the host's animation-driven redraw loop alive.
fn markdown_scroll_glide_settle_px() -> Double {
  0.5
}

///|
/// The distance covered `elapsed_ms` into the glide: exponential decay
/// composed with a constant-velocity floor, never overshooting the target.
/// Time-based rather than step-based, so a late frame simply covers more
/// time instead of slowing the motion.
fn markdown_scroll_glide_travelled(
  remaining_abs : Double,
  elapsed_ms : Double,
  tau_ms : Double,
) -> Double {
  if elapsed_ms <= 0.0 || remaining_abs <= 0.0 {
    return 0.0
  }
  let decay = @math.exp(
    -elapsed_ms /
    (if tau_ms > 0.0 {
      tau_ms
    } else {
      markdown_scroll_glide_time_constant_ms()
    }),
  )
  let exponential = remaining_abs * (1.0 - decay)
  let floored = max_double(
    exponential,
    markdown_scroll_glide_min_velocity_px_per_ms() * elapsed_ms,
  )
  min_double(floored, remaining_abs)
}

///|
/// The scroll offset to draw at `now_ms`, snapped to whole device pixels.
/// Fractional offsets make glyph rasterization shimmer while scrolling;
/// snapping to the physical pixel grid keeps text crisp. The scale factor is
/// the device pixel ratio (`Environment.scale_factor`): at 2x, `scale=2.0`
/// quantizes to 0.5 logical pixels, matching how browsers scroll — a whole
/// *logical* pixel is 2 physical pixels and reads as coarse stepping on a
/// Retina display. The internal state machine (`from_y`/`to_y`, the settle
/// test) stays in exact logical units; only the displayed value is quantized,
/// so the target never accumulates rounding error.
pub fn MarkdownScrollGlide::offset_at(
  self : MarkdownScrollGlide,
  now_ms : Double,
  scale? : Double = 1.0,
) -> Double {
  markdown_scroll_glide_snap(self.exact_offset_at(now_ms), scale)
}

///|
/// Sample the displayed offset after a pending geometry translation and snap
/// that combined value once. Snapping before adding the translation can differ
/// by one device pixel on a scaled display, which is visible as a one-frame
/// backwards nudge when a measured block commits during a glide.
pub fn MarkdownScrollGlide::offset_at_with_compensation(
  self : MarkdownScrollGlide,
  now_ms : Double,
  compensation : Double,
  scale? : Double = 1.0,
) -> Double {
  markdown_scroll_glide_snap(self.exact_offset_at(now_ms) + compensation, scale)
}

///|
/// The un-quantized offset at `now_ms`. Re-keying a mid-flight glide (feeding
/// the shown position back as the new `from_y`) must use this, not the
/// device-snapped `offset_at`: rounding the hidden state would shift the
/// position by up to half a device pixel on every wheel event and reintroduce
/// the sub-pixel jitter the snap exists to remove.
pub fn MarkdownScrollGlide::exact_offset_at(
  self : MarkdownScrollGlide,
  now_ms : Double,
) -> Double {
  let remaining = self.to_y - self.from_y
  let travelled = markdown_scroll_glide_travelled(
    remaining.abs(),
    now_ms - self.start_ms,
    self.tau_ms,
  )
  let directed = if remaining >= 0.0 { travelled } else { -travelled }
  self.from_y + directed
}

///|
/// Round to the nearest device pixel: `scale` logical pixels per device pixel
/// inverted. `scale <= 0` or `1.0` is a whole logical pixel (the default), and
/// larger scales are progressively finer. Round-to-nearest, not floor, so
/// quantization stays unbiased — a floored glide drifts visibly behind target.
fn markdown_scroll_glide_snap(y : Double, scale : Double) -> Double {
  if scale <= 0.0 || scale == 1.0 {
    y.round()
  } else {
    (y * scale).round() / scale
  }
}

///|
/// Whether the glide is still in flight at `now_ms`. False once the offset
/// has reached the target (within the settle threshold), which is what stops
/// the host's animation-driven redraw loop.
pub fn MarkdownScrollGlide::is_animating(
  self : MarkdownScrollGlide,
  now_ms : Double,
) -> Bool {
  let remaining_abs = (self.to_y - self.from_y).abs()
  if remaining_abs <= 0.0 {
    return false
  }
  let travelled = markdown_scroll_glide_travelled(
    remaining_abs,
    now_ms - self.start_ms,
    self.tau_ms,
  )
  remaining_abs - travelled > markdown_scroll_glide_settle_px()
}
