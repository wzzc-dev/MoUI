///|
test "visible_row_window empty list returns None" {
  let range = @common.visible_row_window(
    row_count=0,
    scroll_y=0.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=1,
  )
  match range {
    None => ()
    Some(_) => fail("expected None for empty list")
  }
}

///|
test "visible_row_window full list fits one viewport" {
  // 5 rows of stride 46 (44 + 2) fit exactly in a 230 viewport.
  let range = @common.visible_row_window(
    row_count=5,
    scroll_y=0.0,
    viewport_extent=230.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="0")
      inspect(last_row, content="4")
    }
  }
}

///|
test "visible_row_window mid-scroll window with overscan" {
  // stride = 46; scroll to row 10 exactly.
  let range = @common.visible_row_window(
    row_count=100,
    scroll_y=460.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="10")
      // (460 + 240) / 46 = 15.217 -> floor 15
      inspect(last_row, content="15")
    }
  }
  let with_scan = @common.visible_row_window(
    row_count=100,
    scroll_y=460.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=2,
  )
  match with_scan {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="8")
      inspect(last_row, content="17")
    }
  }
}

///|
test "visible_row_window partially visible rows count as visible" {
  // scroll just past row 9's top edge: row 9 is partially visible.
  let range = @common.visible_row_window(
    row_count=100,
    scroll_y=459.9,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, .. }) => inspect(first_row, content="9")
  }
  // One pixel further: row 9's top is above the viewport, row 10 starts it.
  let range2 = @common.visible_row_window(
    row_count=100,
    scroll_y=460.5,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match range2 {
    None => fail("expected a window")
    Some({ first_row, .. }) => inspect(first_row, content="10")
  }
}

///|
test "visible_row_window clamps at both ends" {
  // Scroll far past the end: last clamps to row_count - 1.
  let range = @common.visible_row_window(
    row_count=100,
    scroll_y=10000.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=3,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="99")
      inspect(last_row, content="99")
    }
  }
  // Negative scroll clamps first to 0.
  let neg = @common.visible_row_window(
    row_count=100,
    scroll_y=-10.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match neg {
    None => fail("expected a window")
    Some({ first_row, .. }) => inspect(first_row, content="0")
  }
}

///|
test "visible_row_window single row always renders itself" {
  let range = @common.visible_row_window(
    row_count=1,
    scroll_y=999.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=0,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="0")
      inspect(last_row, content="0")
    }
  }
}

///|
test "visible_row_window negative overscan treated as zero" {
  let range = @common.visible_row_window(
    row_count=100,
    scroll_y=460.0,
    viewport_extent=240.0,
    row_extent=44.0,
    row_spacing=2.0,
    overscan=-5,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="10")
      inspect(last_row, content="15")
    }
  }
}

///|
test "visible_row_window degenerate stride falls back to full list" {
  let range = @common.visible_row_window(
    row_count=7,
    scroll_y=100.0,
    viewport_extent=240.0,
    row_extent=0.0,
    row_spacing=0.0,
    overscan=0,
  )
  match range {
    None => fail("expected a window")
    Some({ first_row, last_row }) => {
      inspect(first_row, content="0")
      inspect(last_row, content="6")
    }
  }
}

///|
test "windowed_row_count" {
  inspect(@common.windowed_row_count(item_count=0, columns=2), content="0")
  inspect(@common.windowed_row_count(item_count=5, columns=2), content="3")
  inspect(@common.windowed_row_count(item_count=6, columns=2), content="3")
  inspect(@common.windowed_row_count(item_count=7, columns=2), content="4")
  inspect(@common.windowed_row_count(item_count=4, columns=1), content="4")
  inspect(@common.windowed_row_count(item_count=4, columns=0), content="4")
  inspect(@common.windowed_row_count(item_count=4, columns=-3), content="4")
}
