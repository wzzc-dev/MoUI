///|
pub struct SectionListSection[T] {
  id : String
  title : String
  items : Array[T]
}

///|
pub struct ScrollToIndexIntent {
  index : Int
  offset : @core.Point
}

///|
pub fn[T] SectionListSection::new(
  id~ : String,
  title~ : String,
  items~ : Array[T],
) -> SectionListSection[T] {
  { id, title, items }
}

///|
fn ScrollToIndexIntent::new(
  index~ : Int,
  offset~ : @core.Point,
) -> ScrollToIndexIntent {
  { index, offset }
}
