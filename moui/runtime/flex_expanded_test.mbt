///| Regression guards for the playground blank-editor bug: weighted flex
///| children (`expanded`/`flexible`) measured 0x0 (correct flex base) but
///| also placed their content in a 0x0 frame, and root-level background
///| modifiers loosened the root's tight constraints so a `column(...)`
///| measured its content height and the expanded child never received slack.
///| Together these collapsed every `expanded` subtree on the web playground
///| (and any desktop app using the same layout shape).

///|
/// Builds a fixed-size opaque box so flex tests can reason about exact frames.
fn[Msg] expanded_test_box(width~ : Double, height~ : Double) -> @core.View[Msg] {
  @views.frame(@views.empty(), width~, height~)
}

///|
test "expanded column child fills remaining height and hosts its content" {
  let root : @core.View[Unit] = @views.frame(
    @views.column(
      [
        expanded_test_box(width=10.0, height=30.0),
        @views.expanded(expanded_test_box(width=10.0, height=100.0)),
        expanded_test_box(width=10.0, height=26.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=100.0,
    height=300.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=300.0),
  )
  let layout = runtime.layout()
  match layout.children.get(0) {
    Some(column) =>
      match column.children.get(1) {
        Some(expanded) => {
          if expanded.frame.size.height != 244.0 {
            fail(
              "expected expanded frame height 244, got \{expanded.frame.size.height}",
            )
          }
          let inner = match expanded.children.get(0) {
            Some(inner) => inner
            None => {
              fail("expanded child should have one content child")
              return
            }
          }
          if inner.frame.size.height != 244.0 {
            fail(
              "expected expanded content height 244, got \{inner.frame.size.height}",
            )
          }
          // CrossAlign::Start keeps the child's content width (10).
          if inner.frame.size.width != 10.0 {
            fail(
              "expected expanded content width 10 (Start align), got \{inner.frame.size.width}",
            )
          }
        }
        None => fail("expected three column children")
      }
    None => fail("expected root to wrap a column")
  }
}

///|
test "background root keeps tight constraints so expanded fills the viewport" {
  // Playground root is `column(...).background(...)`: the background modifier
  // must not loosen the root's tight constraints, or the column measures its
  // content height and the expanded editor never receives slack.
  let root : @core.View[Unit] = @views.column(
    [
      expanded_test_box(width=640.0, height=30.0),
      expanded_test_box(width=640.0, height=28.0),
      @views.expanded(expanded_test_box(width=640.0, height=736.0)),
      expanded_test_box(width=640.0, height=26.0),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  ).background(@core.Color::white())
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=820.0),
  )
  let layout = runtime.layout()
  match layout.children.get(0) {
    Some(column) =>
      match column.children.get(2) {
        Some(expanded) => {
          if expanded.frame.size.height != 736.0 {
            fail(
              "expected expanded height 736 in background root, got \{expanded.frame.size.height}",
            )
          }
          let inner = match expanded.children.get(0) {
            Some(inner) => inner
            None => {
              fail("expanded should host its content child")
              return
            }
          }
          if inner.frame.size.height != 736.0 {
            fail(
              "expected expanded content height 736, got \{inner.frame.size.height}",
            )
          }
        }
        None => fail("expected four column children")
      }
    None => fail("expected a column root")
  }
}
