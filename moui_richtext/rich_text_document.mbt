///|
type RichTextFormatter = (String) -> RichTextDocument

///|
pub(all) struct RichTextInputTransform {
  text : String
  caret : Int
  selection : @core.TextRange?
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
  image_size : @core.Size?
  image_width_fraction : Double?
  image_fit : @core.ImageFit
  font : @core.FontSpec?
  color : @core.Color?
  background : @core.Brush?
  background_radius : Double
  decoration : RichTextDecoration?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTableCell {
  text : String
  header : Bool
  align : @core.TextAlign?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTable {
  rows : Array[Array[RichTextTableCell]]
  row_height : Double
  cell_padding : @core.Insets
  border : @core.Color
  header_background : @core.Brush?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextBlock {
  runs : Array[RichTextRun]
  table : RichTextTable?
  prefix : String
  font : @core.FontSpec?
  color : @core.Color?
  background : @core.Brush?
  border_left : @core.BorderStyle?
  inset : @core.Insets
  line_height : Double?
  corner_radius : Double
  rule : Bool
  line_align : @core.TextAlign?
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
  image_size? : @core.Size? = None,
  image_fit? : @core.ImageFit = @core.ImageFit::Contain,
  font? : @core.FontSpec? = None,
  color? : @core.Color? = None,
  background? : @core.Brush? = None,
  background_radius? : Double = 4.0,
  decoration? : RichTextDecoration? = None,
  source_range? : RichTextSourceRange? = None,
  image_width_fraction? : Double? = None,
) -> RichTextRun {
  {
    text,
    visual_text,
    image_source,
    image_size,
    image_width_fraction,
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
  selection? : @core.TextRange? = None,
) -> RichTextInputTransform {
  { text, caret, selection }
}

///|
pub fn RichTextBlock::new(
  runs~ : Array[RichTextRun],
  table? : RichTextTable? = None,
  prefix? : String = "",
  font? : @core.FontSpec? = None,
  color? : @core.Color? = None,
  background? : @core.Brush? = None,
  border_left? : @core.BorderStyle? = None,
  inset? : @core.Insets = @core.Insets::symmetric(),
  line_height? : Double? = None,
  corner_radius? : Double = 0.0,
  rule? : Bool = false,
  source_range? : RichTextSourceRange? = None,
  content_range? : RichTextSourceRange? = None,
  line_align? : @core.TextAlign? = None,
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
    line_align,
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
