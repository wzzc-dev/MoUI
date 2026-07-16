///|
/// Auto-moving canvas orb. Phase is sampled from the runtime paint clock
/// (`now_ms`) via `@views.animated_canvas` — no host timer subscription.
pub struct Model {
  label : String
}

///|
/// Small sine approximation so we do not need `moonbitlang/core/math`
/// (Playground user packages only allow the MoUI app import set).
fn approx_sin(x : Double) -> Double {
  // Wrap into [-pi, pi]
  let pi = 3.141592653589793
  let two_pi = pi * 2.0
  let mut t = x
  while t > pi {
    t = t - two_pi
  }
  while t < 0.0 - pi {
    t = t + two_pi
  }
  // Taylor: x - x^3/6 + x^5/120
  let x2 = t * t
  t * (1.0 - x2 / 6.0 + x2 * x2 / 120.0)
}

///|
fn phase_from_clock(now_ms : Double) -> Double {
  // One full cycle roughly every ~3s at the 0.08 Showcase step scale.
  now_ms / 1000.0 * 2.0
}

///|
fn orb_x(frame : @geometry.Rect, phase : Double) -> Double {
  frame.origin.x + 24.0 + 18.0 * approx_sin(phase)
}

///|
fn orb_opacity(phase : Double) -> Double {
  0.55 + 0.45 * ((approx_sin(phase * 0.5) + 1.0) * 0.5)
}

///|
fn paint_orb(
  ctx : @views.PaintContext,
  frame : @geometry.Rect,
  phase : Double,
) -> Unit {
  @views.fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect=frame, radius=12.0),
    @graphics.Brush::solid(@graphics.Color::rgba(r=0.93, g=0.95, b=0.98)),
  )
  @views.push_opacity(ctx, orb_opacity(phase))
  let orb = @geometry.Rect::new(
    x=orb_x(frame, phase),
    y=frame.origin.y + 24.0,
    width=48.0,
    height=48.0,
  )
  @views.fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect=orb, radius=24.0),
    @graphics.Brush::solid(@graphics.Color::rgba(r=0.2, g=0.45, b=0.9)),
  )
  @views.pop_opacity(ctx)
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  @views.column(
    [
      @views.text("Auto-moving orb"),
      @views.text(model.label),
      @views.animated_canvas(
        measure=constraints => {
          constraints.constrain(@geometry.Size::new(width=360.0, height=120.0))
        },
        draw=(ctx, frame, now_ms) => {
          paint_orb(ctx, frame, phase_from_clock(now_ms))
        },
        semantics_label="Tutorial animated orb",
      ),
      @views.text(
        "Phase comes from the paint clock (now_ms). animated_canvas keeps frames flowing without HostTimerSource.",
      ),
    ],
    spacing=12.0,
  )
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(
    init={ label: "Driven by ViewPaintContext.now_ms" },
    update=(model, _) => model,
    view~,
  )
}
