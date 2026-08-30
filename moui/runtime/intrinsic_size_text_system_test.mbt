///|
/// A stand-in for a real (renderer-backed) text system: it reports a width
/// proportional to the string, wide enough to exceed `text()`'s default 160px
/// box. The core fallback estimates advances from font size alone, so it
/// *underestimates* such runs — that divergence is what this regression pins.
fn wide_text_system() -> @core.TextSystem {
  @core.TextSystem::new(id="test-wide-text-system", measure=input => {
    size: @core.Size::new(
      width=input.text.length().to_double() * 20.0,
      height=input.font.size,
    ),
    baseline: input.font.size * 0.8,
    caret_positions: [],
  })
}

///|
/// Mirrors `moui/views`' `text()`: layout measures the string through the
/// injected text system and treats the 160x32 default as a minimum. Declared
/// Uncacheable so every runtime measures with its own text system.
fn[Msg] measured_text_fixture(label : String) -> @core.View[Msg] {
  let min_size = @core.Size::new(width=160.0, height=32.0)
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="MeasuredText"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Uncacheable,
        paint=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(label),
        ),
        semantics=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(label),
        ),
        platform=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(label),
        ),
      )
    },
    layout=ctx => {
      let measured = ctx.text_system.measure_text(
        @core.TextLayoutInput::new(
          text=label,
          font=ctx.style.font.unwrap_or(@core.FontSpec::new(size=16.0)),
        ),
      )
      let width = if measured.size.width > min_size.width {
        measured.size.width
      } else {
        min_size.width
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width~, height=min_size.height),
        ),
      )
    },
  )
}

///|
/// A container that hugs its single child: it reports whatever intrinsic size
/// the runtime computed for that child. This is the exact path the bug took —
/// `ElementNode::intrinsic_size` produced the `child_sizes` handed to a parent
/// during placement — so the root frame width exposes the measurement used.
fn[Msg] hug_container(child : @core.View[Msg]) -> @core.View[Msg] {
  runtime_fixture_view(
    children=() => [child],
    // The root is placed with tight constraints, so anything the root reports
    // is clamped to the window. Let the child size itself loosely instead; its
    // frame is then the box the renderer would clip glyphs to.
    child_constraints=_ => {
      @core.Constraints::loose(@core.Size::new(width=1000.0, height=200.0))
    },
    identity=() => @core.ViewIdentity::new(kind="HugContainer"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Uncacheable,
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Constant,
        platform=@core.DeclarationChannel::Constant,
      )
    },
    layout=ctx => {
      // Report the child's intrinsic size and hand it back as the child frame.
      // The runtime only places children for which the parent emitted a
      // `child_frames` entry.
      let child_size = match ctx.child_sizes.get(0) {
        Some(size) => size
        None => @core.Size::new(width=0.0, height=0.0)
      }
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(child_size), child_frames=[
        @core.Rect::new(
          x=0.0,
          y=0.0,
          width=child_size.width,
          height=child_size.height,
        ),
      ])
    },
  )
}

///|
/// The text child's frame width after a full runtime layout pass driven by the
/// given text system. This is the box the renderer clips glyphs to.
fn runtime_intrinsic_child_width(text_system~ : @core.TextSystem) -> Double {
  let root : @core.View[Unit] = hug_container(
    measured_text_fixture("MoUI Showcase"),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=1000.0, height=200.0),
  )
  runtime.set_text_system(text_system)
  match runtime.layout().children.get(0) {
    Some(child) => child.frame.size.width
    None => 0.0
  }
}

///|
/// The regression: intrinsic sizing must use the host's text system, not
/// `TextSystem::fallback()`.
///
/// `ElementNode::intrinsic_size` feeds the `child_sizes` a parent uses during
/// placement. When it measured with the core fallback while the renderer drew
/// with the real system, a text view was handed a frame narrower than the
/// glyphs it drew, and renderers clip glyphs to the `TextRun` frame — so the
/// text was silently truncated.
///
/// It surfaced on Linux because DejaVu Sans is wider than the Windows/macOS
/// defaults, but the wrong measurement was never platform-specific: every
/// platform got the fallback estimate, and only wide fonts exceeded it.
test "intrinsic sizing uses the host text system, not the core fallback" {
  // The host system measures 13 * 20 = 260, past the 160 default box.
  let with_host_system = runtime_intrinsic_child_width(
    text_system=wide_text_system(),
  )
  // The fallback underestimates, so the box stays at the 160 minimum.
  let with_fallback = runtime_intrinsic_child_width(
    text_system=@core.TextSystem::fallback(),
  )
  if with_host_system <= 160.0 {
    fail(
      "expected the host text system to widen the box past 160, got \{with_host_system}",
    )
  }
  if with_host_system <= with_fallback {
    fail(
      "expected the host text system to measure wider than the fallback, got \{with_host_system} vs \{with_fallback}",
    )
  }
}
