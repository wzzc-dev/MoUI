///|
/// Reproduces the webview_demo layout bug: a greedy child (no intrinsic width,
/// reports `constraints.max.width`, exactly like `web_view`) wrapped in
/// `expanded(...)` should share the row with a fixed-width sibling. Before the
/// tight-fit fix, `expanded` only grew children *beyond* their measured base,
/// and the greedy child's base was already the whole row width — so `slack` was
/// 0, the sibling was pushed past the right edge, and the greedy child filled
/// everything. These tests pin the Flutter `Expanded` semantics (flex-basis 0).
fn greedy_box_option_label(value : Double?) -> String {
  match value {
    Some(v) => "fix-\{v}"
    None => "greedy"
  }
}

///|
/// A child with no intrinsic size that greedily reports `constraints.max`,
/// mirroring `moui_webview/views/web_view.mbt`'s
/// `width.unwrap_or(max)` / `height.unwrap_or(max)` path. Pass `None` on the
/// axis you want greedy; pass `Some(v)` to pin it.
fn[Msg] greedy_box(
  width? : Double? = None,
  height? : Double? = None,
) -> @core.View[Msg] {
  let requested_width = width
  let requested_height = height
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Greedy"),
    revision=() => {
      let w = greedy_box_option_label(requested_width)
      let h = greedy_box_option_label(requested_height)
      "greedy:\{w}:\{h}"
    },
    layout=ctx => {
      let w = match requested_width {
        Some(value) => value
        None => ctx.constraints.max.width
      }
      let h = match requested_height {
        Some(value) => value
        None => ctx.constraints.max.height
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=w, height=h)),
      )
    },
  )
}

///|
/// Descends into the first child of the root layout result. Test roots are
/// `frame(row([...]))`, so the row's flex children live one level below.
fn flex_tight_child(
  layout : @core.LayoutResult,
  index : Int,
) -> @core.LayoutResult? {
  match layout.children.get(0) {
    Some(row) => row.children.get(index)
    None => None
  }
}

///|
/// The core regression: greedy child + fixed sibling. Before the fix the
/// greedy child consumed the full row (300) and the fixed box was pushed to
/// x=300+spacing, i.e. off-screen.
test "expanded greedy child shares the row with a fixed sibling" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.expanded(greedy_box(width=None, height=Some(10.0))),
        @views.frame(@views.empty(), width=100.0, height=10.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=300.0,
    height=10.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=10.0),
  )
  let layout = runtime.layout()
  // Greedy child should fill the leftover 200 (300 - 100 fixed), NOT 300.
  match flex_tight_child(layout, 0) {
    Some(greedy) =>
      if greedy.frame.size.width != 200.0 {
        fail(
          "expected greedy child to fill 200, got \{greedy.frame.size.width}",
        )
      }
    None => fail("expected greedy child")
  }
  // Fixed box must stay on-screen at x=200, not be pushed past the edge.
  match flex_tight_child(layout, 1) {
    Some(fixed) =>
      if fixed.frame.origin.x != 200.0 || fixed.frame.size.width != 100.0 {
        fail(
          "expected fixed box at x=200 width=100, got x=\{fixed.frame.origin.x} width=\{fixed.frame.size.width}",
        )
      }
    None => fail("expected fixed sibling")
  }
}

///|
/// Two greedy `expanded` children split the row evenly (basis 0, weight 1:1).
/// Before the fix both reported the full width and there was no slack to split.
test "two expanded greedy children split the row evenly" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.expanded(greedy_box(width=None, height=Some(10.0))),
        @views.expanded(greedy_box(width=None, height=Some(10.0))),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=300.0,
    height=10.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=10.0),
  )
  let layout = runtime.layout()
  match flex_tight_child(layout, 0) {
    Some(first) =>
      if first.frame.size.width != 150.0 {
        fail("expected first half to be 150, got \{first.frame.size.width}")
      }
    None => fail("expected first child")
  }
  match flex_tight_child(layout, 1) {
    Some(second) =>
      if second.frame.origin.x != 150.0 || second.frame.size.width != 150.0 {
        fail(
          "expected second half at x=150 width=150, got x=\{second.frame.origin.x} width=\{second.frame.size.width}",
        )
      }
    None => fail("expected second child")
  }
}

///|
/// Unequal weights on greedy children split the *whole* row 2:1 (basis 0).
/// Contrast with `flex_weight_test`'s "unequal weights split slack" — there the
/// weighted children were base-0 spacers alongside a fixed box; here the
/// weighted children ARE the content, so tight-fit means 200/100.
test "unequal weights split the whole row between greedy children" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.expanded(greedy_box(width=None, height=Some(10.0)), weight=2.0),
        @views.expanded(greedy_box(width=None, height=Some(10.0)), weight=1.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=300.0,
    height=10.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=10.0),
  )
  let layout = runtime.layout()
  match flex_tight_child(layout, 0) {
    Some(first) =>
      if first.frame.size.width != 200.0 {
        fail("expected weight-2 child to be 200, got \{first.frame.size.width}")
      }
    None => fail("expected first child")
  }
  match flex_tight_child(layout, 1) {
    Some(second) =>
      if second.frame.origin.x != 200.0 || second.frame.size.width != 100.0 {
        fail(
          "expected weight-1 child at x=200 width=100, got x=\{second.frame.origin.x} width=\{second.frame.size.width}",
        )
      }
    None => fail("expected second child")
  }
}

///|
/// The vertical (column) axis must behave symmetrically: a greedy-height
/// child expanded in a column shares it with a fixed-height sibling.
test "expanded greedy child shares a column with a fixed sibling" {
  let root : @core.View[Unit] = @views.frame(
    @views.column(
      [
        @views.expanded(greedy_box(width=Some(10.0), height=None)),
        @views.frame(@views.empty(), width=10.0, height=100.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=10.0,
    height=300.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=10.0, height=300.0),
  )
  let layout = runtime.layout()
  match flex_tight_child(layout, 0) {
    Some(greedy) =>
      if greedy.frame.size.height != 200.0 {
        fail(
          "expected greedy child to fill 200 height, got \{greedy.frame.size.height}",
        )
      }
    None => fail("expected greedy child")
  }
  match flex_tight_child(layout, 1) {
    Some(fixed) =>
      if fixed.frame.origin.y != 200.0 || fixed.frame.size.height != 100.0 {
        fail(
          "expected fixed box at y=200 height=100, got y=\{fixed.frame.origin.y} height=\{fixed.frame.size.height}",
        )
      }
    None => fail("expected fixed sibling")
  }
}
