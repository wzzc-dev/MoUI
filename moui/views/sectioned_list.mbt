///|
pub fn[T, Msg] sectioned_list(
  sections : Array[SectionListSection[T]],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state? : @core.ScrollState = @core.ScrollState::new(),
  header? : (SectionListSection[T]) -> @core.View[Msg] = section => {
    text(section.title)
  },
  item_height? : Double = 44.0,
  header_height? : Double = 30.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
) -> @core.View[Msg] {
  let entries = sectioned_list_entries(sections)
  if entries.length() == 0 {
    match empty {
      Some(view) =>
        scroll_view(view, state=Some(state), width=0.0, height=viewport_height)
      None =>
        scroll_view(
          @container.empty(),
          state=Some(state),
          width=0.0,
          height=viewport_height,
        )
    }
  } else {
    let offset = state.offset().y
    let limit = offset + viewport_height
    let overscan = @common.view_max_int(0, overscan)
    let children : Array[@core.View[Msg]] = []
    let mut cursor = 0.0
    let mut first_visible = -1
    let mut last_visible = -1
    for index, entry in entries {
      let height = sectioned_entry_height(entry, header_height, item_height)
      let top = cursor
      let bottom = top + height
      if bottom >= offset - overscan.to_double() * item_height &&
        top <= limit + overscan.to_double() * item_height {
        if first_visible < 0 {
          first_visible = index
        }
        last_visible = index
        children.push(
          sectioned_entry_view(entry, header, row, key).key(
            sectioned_entry_key(entry, key),
          ),
        )
      }
      cursor = cursor + height + spacing
    }
    let virtual_children : Array[@core.View[Msg]] = []
    if first_visible > 0 {
      virtual_children.push(
        spacer(
          min_length=sectioned_entries_height(
            entries, 0, first_visible, header_height, item_height, spacing,
          ),
          weight=0.0,
        ).key("sectioned-list-before"),
      )
    }
    for child in children {
      virtual_children.push(child)
    }
    if last_visible + 1 < entries.length() {
      virtual_children.push(
        spacer(
          min_length=sectioned_entries_height(
            entries,
            last_visible + 1,
            entries.length(),
            header_height,
            item_height,
            spacing,
          ),
          weight=0.0,
        ).key("sectioned-list-after"),
      )
    }
    scroll_view(
      list(virtual_children, spacing~),
      offset=state.offset(),
      width=0.0,
      height=viewport_height,
      state=Some(state),
    )
  }
}

///|
priv enum SectionedListEntry[T] {
  SectionHeader(SectionListSection[T])
  SectionItem(T)
}

///|
fn[T] sectioned_list_entries(
  sections : Array[SectionListSection[T]],
) -> Array[SectionedListEntry[T]] {
  let entries : Array[SectionedListEntry[T]] = []
  for section in sections {
    entries.push(SectionHeader(section))
    for item in section.items {
      entries.push(SectionItem(item))
    }
  }
  entries
}

///|
fn[T] sectioned_entry_height(
  entry : SectionedListEntry[T],
  header_height : Double,
  item_height : Double,
) -> Double {
  match entry {
    SectionHeader(_) => header_height
    SectionItem(_) => item_height
  }
}

///|
fn[T, Msg] sectioned_entry_view(
  entry : SectionedListEntry[T],
  header : (SectionListSection[T]) -> @core.View[Msg],
  row : (T) -> @core.View[Msg],
  _key : (T) -> String,
) -> @core.View[Msg] {
  match entry {
    SectionHeader(section) => header(section)
    SectionItem(item) => row(item)
  }
}

///|
fn[T] sectioned_entry_key(
  entry : SectionedListEntry[T],
  key : (T) -> String,
) -> String {
  match entry {
    SectionHeader(section) => "section-header-" + section.id
    SectionItem(item) => key(item)
  }
}

///|
fn[T] sectioned_entries_height(
  entries : Array[SectionedListEntry[T]],
  start : Int,
  end : Int,
  header_height : Double,
  item_height : Double,
  spacing : Double,
) -> Double {
  let mut total = 0.0
  let end = entries.length().min(end)
  for index in start..<end {
    total = total +
      sectioned_entry_height(entries[index], header_height, item_height)
    if index + 1 < end {
      total = total + spacing
    }
  }
  total
}
