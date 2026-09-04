///|
/// ADR 0035 tight-fit re-measure: a weighted (`expanded`) child is measured
/// under the loose main-axis extent but placed into its narrower weighted
/// share. With `flex` marking its child frames tight, the placement pass must
/// re-measure that subtree under the final frame so content that depends on
/// the width it actually occupies (wrapping) re-lays out instead of keeping
/// its measure-time layout and being clipped.

///|
/// Leaf that simulates wrapping text: it requests `natural` width but wraps
/// its height to `ceil(natural / available) * line_height`, exactly the
/// geometry a wrapping `Text` node produces under the text system.
fn[Msg] wrap_leaf_box(
  natural~ : Double,
  line_height~ : Double,
) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="WrapLeaf"),
    layout=ctx => {
      let available = ctx.constraints.max.width
      let width = if available < natural { available } else { natural }
      let lines = if width <= 0.0 {
        1
      } else {
        let ratio = natural / width
        let whole = ratio.to_int()
        if ratio > whole.to_double() {
          whole + 1
        } else {
          whole
        }
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width~, height=lines.to_double() * line_height),
        ),
      )
    },
  )
}

///|
/// The stale-wrap regression: in a 300-wide row, an `expanded` column holding
/// a 500-wide wrapping leaf gets a 200-wide frame. Before the tight-fit
/// re-measure the leaf kept its intrinsic single-line height (10) inside the
/// 200-wide frame — clipped instead of wrapped. After the fix the subtree is
/// re-measured at the placed width and the leaf is 200 wide, 3 lines tall.
test "expanded wrapping child re-measures to its weighted width" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.expanded(
          @views.column([wrap_leaf_box(natural=500.0, line_height=10.0)]),
        ),
        @views.frame(@views.empty(), width=100.0, height=10.0),
      ],
      spacing=0.0,
    ),
    width=300.0,
    height=100.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=100.0),
  )
  let layout = runtime.layout()
  let column = match layout.children.get(0) {
    Some(row) =>
      match row.children.get(0) {
        Some(expanded) =>
          match expanded.children.get(0) {
            Some(column) => column
            None => {
              fail("expanded should host the column")
              return
            }
          }
        None => fail("expected expanded child")
      }
    None => fail("expected row child")
  }
  if column.frame.size.width != 200.0 {
    fail("expected expanded column width 200, got \{column.frame.size.width}")
  }
  let leaf = match column.children.get(0) {
    Some(leaf) => leaf
    None => {
      fail("column should host the wrapping leaf")
      return
    }
  }
  if leaf.frame.size.width != 200.0 {
    fail("expected leaf width 200, got \{leaf.frame.size.width}")
  }
  if leaf.frame.size.height != 30.0 {
    fail(
      "expected leaf to wrap to 3 lines (30) at 200 width, got \{leaf.frame.size.height}",
    )
  }
}

///|
/// Re-measure must not change children whose frames already match their
/// measured size: a fixed sibling and a non-weighted wrapping child keep their
/// measured geometry, and the leaf in the weighted child settles after the
/// first re-measure (constraint-keyed memo keeps repeats cheap).
test "tight-fit re-measure leaves matched children untouched" {
  let root : @core.View[Unit] = @views.frame(
    @views.row(
      [
        @views.frame(@views.empty(), width=100.0, height=10.0),
        @views.expanded(
          @views.column(
            [wrap_leaf_box(natural=150.0, line_height=10.0)],
            align=@views.CrossAlign::Start,
          ),
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=300.0,
    height=100.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=100.0),
  )
  let layout = runtime.layout()
  match layout.children.get(0) {
    Some(row) => {
      match row.children.get(0) {
        Some(fixed) => {
          let fixed_kept = fixed.frame.size.width == 100.0 &&
            fixed.frame.size.height == 10.0
          if !fixed_kept {
            fail(
              "fixed sibling must keep its measured 100x10, got \{fixed.frame.size.width}x\{fixed.frame.size.height}",
            )
          }
        }
        None => fail("expected fixed sibling")
      }
      let leaf = match row.children.get(1) {
        Some(expanded) =>
          match expanded.children.get(0) {
            Some(column) =>
              match column.children.get(0) {
                Some(leaf) => leaf
                None => {
                  fail("column should host the wrapping leaf")
                  return
                }
              }
            None => fail("expanded should host the column")
          }
        None => fail("expected expanded child")
      }
      // 150 natural width fits inside the 200-wide weighted frame, so the
      // leaf stays at its natural size and does not wrap.
      if leaf.frame.size.width != 150.0 || leaf.frame.size.height != 10.0 {
        fail(
          "expected unwrapped leaf 150x10, got \{leaf.frame.size.width}x\{leaf.frame.size.height}",
        )
      }
    }
    None => fail("expected row child")
  }
}
