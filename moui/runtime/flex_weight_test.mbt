///|
/// `spacer(weight=...)` and `View::flexible`/`View::expanded` declare a flex
/// growth weight. These tests pin the engine behavior that the website's
/// `[spacer(weight=1), content, spacer(weight=1)]` centering relies on; before
/// the fix, weighted children measured 0x0 and never grew, so content stayed
/// flush left.

///|
/// Builds a fixed-size opaque box so flex tests can reason about exact frames.
fn[Msg] flex_test_box(width~ : Double, height~ : Double) -> @core.View[Msg] {
  @views.frame(@views.empty(), width~, height~)
}

///|
/// Descends into the first child of the root layout result. The test roots are
/// `frame(row([...]))`, so the row's flex children live one level below the
/// root frame.
fn flex_child_layout(
  layout : @core.LayoutResult,
  index : Int,
) -> @core.LayoutResult? {
  match layout.children.get(0) {
    Some(row) => row.children.get(index)
    None => None
  }
}

///|
test "weighted spacers center a fixed child horizontally" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.spacer(min_length=0.0, weight=1.0),
        flex_test_box(width=100.0, height=10.0),
        @views.spacer(min_length=0.0, weight=1.0),
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
  // Children are [spacer, box, spacer]; the box is the middle child.
  match flex_child_layout(layout, 1) {
    Some(box) =>
      if box.frame.origin.x != 100.0 || box.frame.size.width != 100.0 {
        fail(
          "expected box centered at x=100 width=100, got x=\{box.frame.origin.x} width=\{box.frame.size.width}",
        )
      }
    None => fail("expected three flex children")
  }
}

///|
test "weighted spacer pushes a trailing child to the right edge" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        flex_test_box(width=40.0, height=10.0),
        @views.spacer(min_length=0.0, weight=1.0),
        flex_test_box(width=60.0, height=10.0),
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
  // Trailing box should sit flush at the right edge: x + width == 300.
  match flex_child_layout(layout, 2) {
    Some(trailing) =>
      if trailing.frame.origin.x != 240.0 || trailing.frame.size.width != 60.0 {
        fail(
          "expected trailing box at x=240 width=60, got x=\{trailing.frame.origin.x} width=\{trailing.frame.size.width}",
        )
      }
    None => fail("expected trailing child")
  }
}

///|
test "weighted spacers center a fixed child vertically in a column" {
  let root : @core.View[Unit] = @views.frame(
    @views.column(
      [
        @views.spacer(min_length=0.0, weight=1.0),
        flex_test_box(width=10.0, height=40.0),
        @views.spacer(min_length=0.0, weight=1.0),
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
  match flex_child_layout(layout, 1) {
    Some(box) =>
      if box.frame.origin.y != 130.0 || box.frame.size.height != 40.0 {
        fail(
          "expected box centered at y=130 height=40, got y=\{box.frame.origin.y} height=\{box.frame.size.height}",
        )
      }
    None => fail("expected middle child")
  }
}

///|
test "unequal weights split slack proportionally" {
  // weight 3 vs weight 1 over 200px of slack: first spacer grows 150, second 50.
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.spacer(min_length=0.0, weight=3.0),
        flex_test_box(width=100.0, height=10.0),
        @views.spacer(min_length=0.0, weight=1.0),
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
  // First spacer (weight 3) grows to 150; box follows at x=150.
  match flex_child_layout(layout, 0) {
    Some(first) =>
      if first.frame.size.width != 150.0 {
        fail(
          "expected weight-3 spacer to grow to 150, got \{first.frame.size.width}",
        )
      }
    None => fail("expected leading spacer")
  }
  match flex_child_layout(layout, 2) {
    Some(last) =>
      if last.frame.size.width != 50.0 {
        fail(
          "expected weight-1 spacer to grow to 50, got \{last.frame.size.width}",
        )
      }
    None => fail("expected trailing spacer")
  }
}

///|
test "View::flexible grows a child to fill remaining space" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        flex_test_box(width=80.0, height=10.0),
        flex_test_box(width=20.0, height=10.0).flexible(weight=1.0),
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
  // First box keeps its 80px base; the flexible box grows from 20 to 220.
  match flex_child_layout(layout, 0) {
    Some(first) =>
      if first.frame.size.width != 80.0 {
        fail("expected fixed box to keep 80, got \{first.frame.size.width}")
      }
    None => fail("expected first child")
  }
  match flex_child_layout(layout, 1) {
    Some(flexible) =>
      if flexible.frame.origin.x != 80.0 || flexible.frame.size.width != 220.0 {
        fail(
          "expected flexible box at x=80 width=220, got x=\{flexible.frame.origin.x} width=\{flexible.frame.size.width}",
        )
      }
    None => fail("expected flexible child")
  }
}
