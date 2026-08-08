///|
pub fn[T, Msg] sectioned_list(
  sections : Array[@layout.SectionListSection[T]],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  header? : (@layout.SectionListSection[T]) -> @core.View[Msg] = section => {
    @text.text(section.title)
  },
  item_height? : Double = 44.0,
  header_height? : Double = 30.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  ignore(item_height)
  ignore(header_height)
  ignore(overscan)
  let entries = sectioned_list_entries(sections)
  if entries.length() == 0 {
    match empty {
      Some(view) => scroll_view(view, height=viewport_height, request?)
      None => scroll_view(@container.empty(), height=viewport_height, request?)
    }
  } else {
    let children : Array[@core.View[Msg]] = []
    for entry in entries {
      children.push(
        sectioned_entry_view(entry, header, row, key).key(
          sectioned_entry_key(entry, key),
        ),
      )
    }
    scroll_view(
      @layout.list(children, spacing~),
      height=viewport_height,
      request?,
    )
  }
}

///|
priv enum SectionedListEntry[T] {
  SectionHeader(@layout.SectionListSection[T])
  SectionItem(T)
}

///|
fn[T] sectioned_list_entries(
  sections : Array[@layout.SectionListSection[T]],
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
fn[T, Msg] sectioned_entry_view(
  entry : SectionedListEntry[T],
  header : (@layout.SectionListSection[T]) -> @core.View[Msg],
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
