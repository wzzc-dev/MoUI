///|
pub type RichTextFormatter = (String) -> RichTextDocument

///|
pub(all) struct RichTextInputTransform {
  text : String
  caret : Int
  selection : TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RichTextDecoration {
  Strikethrough
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextRun {
  text : String
  visual_text : String?
  image_source : String?
  image_size : Size?
  image_fit : ImageFit
  font : FontSpec?
  color : Color?
  background : Brush?
  background_radius : Double
  decoration : RichTextDecoration?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTableCell {
  text : String
  header : Bool
  align : TextAlign?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTable {
  rows : Array[Array[RichTextTableCell]]
  row_height : Double
  cell_padding : Insets
  border : Color
  header_background : Brush?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextBlock {
  runs : Array[RichTextRun]
  table : RichTextTable?
  prefix : String
  font : FontSpec?
  color : Color?
  background : Brush?
  border_left : BorderStyle?
  inset : Insets
  line_height : Double?
  corner_radius : Double
  rule : Bool
  source_range : RichTextSourceRange?
  content_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextDocument {
  blocks : Array[RichTextBlock]
} derive(Eq, Debug, ToJson)

///|
pub fn RichTextRun::new(
  text~ : String,
  visual_text? : String? = None,
  image_source? : String? = None,
  image_size? : Size? = None,
  image_fit? : ImageFit = ImageFit::Contain,
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  background_radius? : Double = 4.0,
  decoration? : RichTextDecoration? = None,
  source_range? : RichTextSourceRange? = None,
) -> RichTextRun {
  {
    text,
    visual_text,
    image_source,
    image_size,
    image_fit,
    font,
    color,
    background,
    background_radius,
    decoration,
    source_range,
  }
}

///|
pub fn RichTextInputTransform::new(
  text~ : String,
  caret~ : Int,
  selection? : TextRange? = None,
) -> RichTextInputTransform {
  { text, caret, selection }
}

///|
pub fn RichTextBlock::new(
  runs~ : Array[RichTextRun],
  table? : RichTextTable? = None,
  prefix? : String = "",
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  border_left? : BorderStyle? = None,
  inset? : Insets = Insets::symmetric(),
  line_height? : Double? = None,
  corner_radius? : Double = 0.0,
  rule? : Bool = false,
  source_range? : RichTextSourceRange? = None,
  content_range? : RichTextSourceRange? = None,
) -> RichTextBlock {
  {
    runs,
    table,
    prefix,
    font,
    color,
    background,
    border_left,
    inset,
    line_height,
    corner_radius,
    rule,
    source_range,
    content_range,
  }
}

///|
pub fn RichTextDocument::new(
  blocks~ : Array[RichTextBlock],
) -> RichTextDocument {
  { blocks, }
}

///|
pub fn RichTextDocument::plain(text : String) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\n' {
      blocks.push(
        RichTextBlock::new(runs=[
          RichTextRun::new(text=String::from_array(current)),
        ]),
      )
      current.clear()
    } else {
      current.push(ch)
    }
  }
  blocks.push(
    RichTextBlock::new(runs=[RichTextRun::new(text=String::from_array(current))]),
  )
  RichTextDocument::new(blocks~)
}
