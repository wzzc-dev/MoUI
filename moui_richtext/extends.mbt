// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CodeHighlightToken with Debug::{to_repr}

///|
#doc(hidden)
pub extend CodeHighlightToken with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownBlock with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownBlock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownBlock with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownBlockKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownBlockKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownBlockKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentBlock with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentBlock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentBlock with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentBlockHeightMetric with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentBlockHeightMetric with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentBlockHeightMetric with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentDirtyRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentDirtyRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentDirtyRange with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentHeightIndex with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentHeightIndex with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentHeightIndex with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutBlock with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutBlock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutBlock with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutCache with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutCache with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentLayoutCache with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentRichTextWindow with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentRichTextWindow with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentRichTextWindow with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentSession with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentSession with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentSession with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownDocumentTextStore with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownDocumentTextStore with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownDocumentTextStore with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditReason with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditReason with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditReason with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditTransaction with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditTransaction with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditTransaction with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorBlock with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorBlock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorBlock with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorCommand with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorEditResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorEditResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorEditResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorHtmlBlockParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorHtmlBlockParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorIndentedCodeParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorIndentedCodeParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorOutlineItem with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorOutlineItem with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorOutlineItem with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorParagraphParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorParagraphParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorRunSourceRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorRunSourceRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorSelection with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorSelection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorSelection with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorSetextHeadingParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorSetextHeadingParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownEditorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownHtmlBlockParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownHtmlBlockParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownHtmlEntityDecodeResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownHtmlEntityDecodeResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownIndentedCodeParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownIndentedCodeParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownInline with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownInline with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownInline with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownInlineKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownInlineKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownInlineKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownLinkBounds with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownLinkBounds with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownParagraphParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownParagraphParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownReferenceContext with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownReferenceContext with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownScrollGlide with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownScrollGlide with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownScrollGlide with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownSetextHeadingParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownSetextHeadingParseResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownSourceRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownSourceRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownSourceRange with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownTextSegment with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownTextSegment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MarkdownTextSegment with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextBlock with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextBlock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextBlock with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextDecoration with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextDecoration with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextDecoration with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextDocument with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextDocument with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextDocument with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextInputTransform with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextInputTransform with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextInputTransform with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextMarker with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextMarker with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextMarker with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextRun with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextRun with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextRun with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextSourceRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextSourceRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextSourceRange with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextTable with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextTable with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextTable with ToJson::{to_json}

///|
#doc(hidden)
pub extend RichTextTableCell with Debug::{to_repr}

///|
#doc(hidden)
pub extend RichTextTableCell with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RichTextTableCell with ToJson::{to_json}
