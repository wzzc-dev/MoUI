///| Re-exports from the `unicode` sub-package so existing core consumers can
///| keep using the same unqualified names.

///| The grapheme boundary scanner, backed by the Unicode 17.0 property table.
pub type TextGraphemeBoundaries = @unicode.TextGraphemeBoundaries

///| Stabilize caret positions so that carets inside a grapheme cluster share
///| the cluster's leading caret coordinate.
pub fn fallback_stabilize_grapheme_cluster_carets(
  text : String,
  carets : Array[Double],
) -> Array[Double] {
  @unicode.stabilize_grapheme_cluster_carets(text, carets)
}

///| Returns the previous grapheme boundary before `caret`.
pub fn text_previous_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  @unicode.previous_grapheme_caret_boundary(text, caret)
}

///| Returns the next grapheme boundary after `caret`.
pub fn text_next_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  @unicode.next_grapheme_caret_boundary(text, caret)
}

///| Normalizes a `TextRange` to grapheme boundaries. This bridges the core
///| `TextRange` contract to the unicode package's `GraphemeRange` API.
pub fn normalize_grapheme_range(
  boundaries : TextGraphemeBoundaries,
  range : TextRange,
) -> TextRange {
  let result = boundaries.normalize_range(
    @unicode.GraphemeRange::new(start=range.start, end=range.end),
  )
  TextRange::new(start=result.start, end=result.end)
}

///| Computes the deletion range around `caret` in grapheme boundaries. This
///| bridges the core `TextRange` contract to the unicode package's API.
pub fn delete_grapheme_range(
  boundaries : TextGraphemeBoundaries,
  caret : Int,
  before : Int,
  after : Int,
) -> TextRange {
  let result = boundaries.delete_range(caret, before, after)
  TextRange::new(start=result.start, end=result.end)
}
