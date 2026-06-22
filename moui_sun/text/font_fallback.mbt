///|
/// A contiguous text segment covered by the same font-face index.
struct FontFallbackSpan {
  face_index : Int
  text : String
  char_count : Int
} derive(Debug)

///|
/// A font fallback plan for a text string.
struct FontFallbackPlan {
  spans : Array[FontFallbackSpan]
  char_count : Int
  missing_char_count : Int
} derive(Debug)

///|
/// Get the index of the selected face, or -1 when no face covers this span.
pub fn FontFallbackSpan::get_face_index(self : FontFallbackSpan) -> Int {
  self.face_index
}

///|
/// Get the text covered by this span.
pub fn FontFallbackSpan::get_text(self : FontFallbackSpan) -> String {
  self.text
}

///|
/// Get the number of Unicode scalar values in this span.
pub fn FontFallbackSpan::get_char_count(self : FontFallbackSpan) -> Int {
  self.char_count
}

///|
/// Return whether no provided face covers this span.
pub fn FontFallbackSpan::is_missing(self : FontFallbackSpan) -> Bool {
  self.face_index < 0
}

///|
/// Get fallback spans in source-text order.
pub fn FontFallbackPlan::get_spans(
  self : FontFallbackPlan,
) -> Array[FontFallbackSpan] {
  copy_font_fallback_spans(self.spans)
}

///|
/// Get the number of fallback spans.
pub fn FontFallbackPlan::span_count(self : FontFallbackPlan) -> Int {
  self.spans.length()
}

///|
/// Get the number of Unicode scalar values examined by this plan.
pub fn FontFallbackPlan::get_char_count(self : FontFallbackPlan) -> Int {
  self.char_count
}

///|
/// Get the number of scalar values not covered by any provided face.
pub fn FontFallbackPlan::get_missing_char_count(self : FontFallbackPlan) -> Int {
  self.missing_char_count
}

///|
/// Return whether any scalar value lacks glyph coverage.
pub fn FontFallbackPlan::has_missing_glyphs(self : FontFallbackPlan) -> Bool {
  self.missing_char_count > 0
}

///|
/// Return whether the plan has no text spans.
pub fn FontFallbackPlan::is_empty(self : FontFallbackPlan) -> Bool {
  self.spans.length() is 0
}

///|
/// Select the first face that maps a Unicode codepoint to a drawable glyph.
pub fn select_font_face_index_for_char(
  faces : Array[FontFace],
  char_code : Int,
) -> Int {
  for i in 0..<faces.length() {
    if faces[i].has_glyph_for_char(char_code) {
      return i
    }
  }
  -1
}

///|
/// Segment text by the first provided face that covers each Unicode scalar.
pub fn plan_font_fallback(
  faces : Array[FontFace],
  text : String,
) -> FontFallbackPlan {
  let spans = []
  let mut current_face_index = -2
  let mut current_text = ""
  let mut current_char_count = 0
  let mut char_count = 0
  let mut missing_char_count = 0

  for ch in text {
    let face_index = select_font_face_index_for_char(faces, ch.to_int())
    if face_index < 0 {
      missing_char_count += 1
    }
    if current_char_count > 0 && face_index != current_face_index {
      spans.push(
        make_font_fallback_span(
          current_face_index, current_text, current_char_count,
        ),
      )
      current_text = ""
      current_char_count = 0
    }
    current_face_index = face_index
    current_text = current_text + ch.to_string()
    current_char_count += 1
    char_count += 1
  }

  if current_char_count > 0 {
    spans.push(
      make_font_fallback_span(
        current_face_index, current_text, current_char_count,
      ),
    )
  }

  { spans, char_count, missing_char_count }
}

///|
fn make_font_fallback_span(
  face_index : Int,
  text : String,
  char_count : Int,
) -> FontFallbackSpan {
  { face_index, text, char_count }
}

///|
fn copy_font_fallback_spans(
  spans : Array[FontFallbackSpan],
) -> Array[FontFallbackSpan] {
  let copied = []
  for span in spans {
    copied.push(span)
  }
  copied
}
