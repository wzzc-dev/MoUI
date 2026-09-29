///|
/// End-to-end coverage for `View::on_hover` through the real runtime.
///
/// The unit suite (`moui/core/modifier_wbtest.mbt`) drives the modifier's
/// `event` closure directly. These tests instead go through
/// `@runtime.AppRuntime::dispatch_event` so they prove the two runtime
/// behaviors the modifier depends on:
///
/// - the runtime synthesizes `PointerPhase::Exit` for a subtree that reports
///   hover, which is the only way a leave is ever delivered (host backends
///   never emit one, and a `Move` outside the element is not delivered to it
///   by hit-testing); and
/// - moving between siblings sends the previously hovered sibling an `Exit`
///   even though the newly entered sibling was hit first.
///
/// `on_hover` is the only hover tracking in these trees — the wrapped leaf has
/// no event handler of its own — so these tests also pin that the modifier's
/// own state bookkeeping is what keeps its leave path reachable.

///|
/// Renders a hover log as `true, false` so failure messages stay readable
/// without relying on the deprecated `Show` implementation for `Array[Bool]`.
fn on_hover_runtime_render(log : Array[Bool]) -> String {
  log.map(hovered => if hovered { "true" } else { "false" }).join(", ")
}

///|
/// A non-interactive filler leaf used to occupy space so the pointer has a
/// region to land on that is not the hover target.
fn[Msg] on_hover_runtime_leaf(
  width~ : Double,
  height~ : Double,
) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="OnHoverLeaf"),
    declaration=() => {
      runtime_fixture_exact_declaration("OnHoverLeaf", [
        ("width", @core.DeclarationKey::double(width)),
        ("height", @core.DeclarationKey::double(height)),
      ])
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
  )
}

///|
/// Two children of 100x40 at fixed frames: the first (x in [0,100)) is the
/// hover target, the second (x in [200,300)) is filler, leaving a hit-testable
/// gap in [100,200) that resolves to the parent rather than the target.
fn[Msg] on_hover_runtime_stage(target~ : @core.View[Msg]) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="OnHoverStage"),
    children=() => [target, on_hover_runtime_leaf(width=100.0, height=40.0)],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let frames : Array[@core.Rect] = []
      for index, _size in ctx.child_sizes {
        let x = if index == 0 { 0.0 } else { 200.0 }
        frames.push(@core.Rect::new(x~, y=0.0, width=100.0, height=40.0))
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=300.0, height=40.0),
        ),
        child_frames=frames,
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
  )
}

///|
fn on_hover_runtime_move(x : Double, y : Double) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Move),
  )
}

///|
/// (a) enter fires once with `true`, (b) repeated `Move` inside does not
/// re-fire, (c) leaving fires once with `false`, (d) re-entering fires `true`.
test "runtime on_hover fires only on hover transitions" {
  let log : Array[Bool] = []
  let target : @core.View[Unit] = on_hover_runtime_leaf(
    width=100.0,
    height=40.0,
  ).on_hover(hovered => {
    log.push(hovered)
    ()
  })
  let root : @core.View[Unit] = on_hover_runtime_stage(target~)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.layout())
  // (a) Enter.
  runtime.dispatch_event(on_hover_runtime_move(10.0, 10.0))
  if log != [true] {
    fail(
      "expected [true] after entering, got [\{on_hover_runtime_render(log)}]",
    )
  }
  // (b) The runtime delivers a `Move` per pointer sample inside the element;
  // continuous motion must not emit a message per sample.
  runtime.dispatch_event(on_hover_runtime_move(20.0, 12.0))
  runtime.dispatch_event(on_hover_runtime_move(30.0, 14.0))
  runtime.dispatch_event(on_hover_runtime_move(40.0, 16.0))
  if log != [true] {
    fail(
      "repeated Move inside must not re-fire, got [\{on_hover_runtime_render(log)}]",
    )
  }
  // (c) Move into the gap: no child is hit, so the runtime must deliver the
  // synthetic `Exit` that produces the leave notification.
  runtime.dispatch_event(on_hover_runtime_move(150.0, 10.0))
  if log != [true, false] {
    fail(
      "expected [true, false] after leaving, got [\{on_hover_runtime_render(log)}]",
    )
  }
  // Staying outside stays quiet.
  runtime.dispatch_event(on_hover_runtime_move(160.0, 10.0))
  if log != [true, false] {
    fail(
      "repeated Move outside must not re-fire, got [\{on_hover_runtime_render(log)}]",
    )
  }
  // (d) Re-enter fires `true` again.
  runtime.dispatch_event(on_hover_runtime_move(10.0, 10.0))
  if log != [true, false, true] {
    fail(
      "expected [true, false, true] after re-entering, got [\{on_hover_runtime_render(log)}]",
    )
  }
}

///|
/// Moving straight from the hover target onto a sibling must clear the
/// target's hover even though the sibling was hit first in the same traversal.
test "runtime on_hover clears when moving to a sibling" {
  let log : Array[Bool] = []
  let target : @core.View[Unit] = on_hover_runtime_leaf(
    width=100.0,
    height=40.0,
  ).on_hover(hovered => {
    log.push(hovered)
    ()
  })
  let root : @core.View[Unit] = on_hover_runtime_stage(target~)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(on_hover_runtime_move(10.0, 10.0))
  runtime.dispatch_event(on_hover_runtime_move(250.0, 10.0))
  if log != [true, false] {
    fail(
      "expected [true, false] after moving to sibling, got [\{on_hover_runtime_render(log)}]",
    )
  }
}

///|
/// The `Exit` that ends hover must reach an `on_hover` observer even when the
/// pointer leaves the whole window instead of moving onto a sibling. At the
/// root there is no parent to synthesize an `Exit`, so the modifier has to
/// resolve the leave from the out-of-frame `Move` itself.
test "runtime on_hover clears when the pointer leaves the root frame" {
  let log : Array[Bool] = []
  let root : @core.View[Unit] = on_hover_runtime_stage(
    target=on_hover_runtime_leaf(width=100.0, height=40.0).on_hover(hovered => {
      log.push(hovered)
      ()
    }),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(on_hover_runtime_move(10.0, 10.0))
  if log != [true] {
    fail(
      "expected [true] after entering, got [\{on_hover_runtime_render(log)}]",
    )
  }
  // Far outside the stage: the target is not hit, so the parent's stale-hover
  // clear path delivers the synthetic Exit.
  runtime.dispatch_event(on_hover_runtime_move(900.0, 900.0))
  if log != [true, false] {
    fail(
      "expected [true, false] after leaving the stage, got [\{on_hover_runtime_render(log)}]",
    )
  }
}

///|
/// A hover observer is transparent: wrapping a region in `on_hover` must not
/// make it focusable, and must not turn a plain container into a semantics
/// boundary in the runtime's committed tree.
test "runtime on_hover adds no focus stop and no semantics boundary" {
  let plain : @core.View[Unit] = on_hover_runtime_leaf(width=100.0, height=40.0)
  let root : @core.View[Unit] = on_hover_runtime_stage(target=plain)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.layout())
  let plain_nodes = match runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot.nodes()
    _ => abort("expected full semantics snapshot")
  }
  // Nothing in either tree is focusable: the modifier must not add a focus stop.
  let hover_target : @core.View[Unit] = on_hover_runtime_leaf(
    width=100.0,
    height=40.0,
  ).on_hover(_hovered => ())
  let hover_root : @core.View[Unit] = on_hover_runtime_stage(
    target=hover_target,
  )
  let hover_runtime = @runtime.AppRuntime::new_view(
    root=hover_root,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(hover_runtime.layout())
  let hover_nodes = match hover_runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot.nodes()
    _ => abort("expected full semantics snapshot")
  }
  if hover_nodes.length() != plain_nodes.length() {
    fail(
      "on_hover must not add semantics nodes: plain=\{plain_nodes.length()} hover=\{hover_nodes.length()}",
    )
  }
  // The runtime resolves pointer focus geometrically; a hover observer must not
  // become a focus target, so no node in the tree may have gained focus.
  let focused = match hover_runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot.focused()
    _ => abort("expected full semantics snapshot")
  }
  assert_true(focused is None)
}
