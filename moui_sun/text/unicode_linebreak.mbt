///|
/// Unicode Line Break classes (UAX #14)
pub enum LineBreakClass {
  BK // Mandatory Break
  CR // Carriage Return
  LF // Line Feed
  SP // Space
  OP // Opening Punctuation
  CL // Closing Punctuation
  QU // Quotation
  GL // Non-breaking
  NS // Nonstarter
  EX // Exclamation/Interrogation
  SY // Symbols allowing break after
  IS // Infix Numeric Separator
  NU // Numeric
  AL // Alphabetic
  ID // Ideographic
  IN // Inseparable characters
  HY // Hyphen
  BA // Break After
  BB // Break Before
  B2 // Break Opportunity Before and After
  ZW // Zero Width Space
  CM // Combining Mark
  WJ // Word Joiner
  H2 // Hangul L Jamo
  H3 // Hangul LV Syllable
  JL // Hangul LVT Syllable
  JT // Hangul V Jamo
  JV // Hangul T Jamo
  CP // Close Parenthesis
  RI // Regional Indicator
  EB // EBase
  EModifier // EModifier
  ZWJ // Zero Width Joiner
  AI // Ambiguous
  Unknown
} derive(Eq, Debug)

///|
pub impl Show for LineBreakClass with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn LineBreakClass::to_string(self : LineBreakClass) -> String {
  match self {
    BK => "BK"
    CR => "CR"
    LF => "LF"
    SP => "SP"
    OP => "OP"
    CL => "CL"
    QU => "QU"
    GL => "GL"
    NS => "NS"
    EX => "EX"
    SY => "SY"
    IS => "IS"
    NU => "NU"
    AL => "AL"
    ID => "ID"
    IN => "IN"
    HY => "HY"
    BA => "BA"
    BB => "BB"
    B2 => "B2"
    ZW => "ZW"
    CM => "CM"
    WJ => "WJ"
    H2 => "H2"
    H3 => "H3"
    JL => "JL"
    JT => "JT"
    JV => "JV"
    CP => "CP"
    RI => "RI"
    EB => "EB"
    EModifier => "EModifier"
    ZWJ => "ZWJ"
    AI => "AI"
    Unknown => "Unknown"
  }
}

///|
/// Get line break class for a character
pub fn get_line_break_class(ch : Int) -> LineBreakClass {
  // Basic implementation - can be extended with full Unicode data
  match ch {
    _ if ch < 0 || ch > 0x10FFFF => Unknown

    // Line break mandatory
    0x000A => LF // Line Feed
    0x000D => CR // Carriage Return
    0x000B => BK // Vertical Tab
    0x000C => BK // Form Feed
    0x0085 => BK // Next Line
    0x2028 => BK // Line Separator
    0x2029 => BK // Paragraph Separator

    // Space
    0x0020 => SP // Space
    0x00A0 => GL // No-Break Space
    0x2000 => BA // En Quad
    0x2001 => BA // Em Quad
    0x2002 => BA // En Space
    0x2003 => BA // Em Space
    0x2004 => BA // Three-Per-Em Space
    0x2005 => BA // Four-Per-Em Space
    0x2006 => BA // Six-Per-Em Space
    0x2007 => GL // Figure Space
    0x2008 => BA // Punctuation Space
    0x2009 => BA // Thin Space
    0x200A => BA // Hair Space
    0x200B => ZW // Zero Width Space
    0x0300..=0x036F => CM // Combining Diacritical Marks
    0x1F1E6..=0x1F1FF => RI // Regional Indicator Symbols
    0x1F3FB..=0x1F3FF => EModifier // Emoji modifiers
    0x2060 => WJ // Word Joiner
    0xFEFF => WJ // Zero Width No-Break Space

    // Opening Punctuation
    0x0028 => OP // Left Parenthesis
    0x005B => OP // Left Square Bracket
    0x007B => OP // Left Curly Bracket
    0x00AB => QU // Left-Pointing Double Angle Quotation Mark
    0x2018 => QU // Left Single Quotation Mark
    0x201C => QU // Left Double Quotation Mark
    0x201D => QU // Right Double Quotation Mark
    0x2039 => QU // Single Left-Pointing Angle Quotation Mark
    0x3008 => OP // Left Angle Bracket
    0x300A => OP // Left Double Angle Bracket
    0x300C => OP // Left Corner Bracket
    0x300E => OP // Left White Corner Bracket
    0x3010 => OP // Left Black Lenticular Bracket
    0x3014 => OP // Left Tortoise Shell Bracket
    0x3016 => OP // Left White Lenticular Bracket
    0x3018 => OP // Left White Tortoise Shell Bracket
    0x301A => OP // Left White Square Bracket
    0xFF08 => OP // Fullwidth Left Parenthesis
    0xFF3B => OP // Fullwidth Left Square Bracket
    0xFF5B => OP // Fullwidth Left Curly Bracket

    // Closing Punctuation
    0x0029 => CP // Right Parenthesis
    0x005D => CL // Right Square Bracket
    0x007D => CL // Right Curly Bracket
    0x00BB => QU // Right-Pointing Double Angle Quotation Mark
    0x2019 => QU // Right Single Quotation Mark
    0x3009 => CL // Right Angle Bracket
    0x300B => CL // Right Double Angle Bracket
    0x300D => CL // Right Corner Bracket
    0x300F => CL // Right White Corner Bracket
    0x3011 => CL // Right Black Lenticular Bracket
    0x3015 => CL // Right Tortoise Shell Bracket
    0x3017 => CL // Right White Lenticular Bracket
    0x3019 => CL // Right White Tortoise Shell Bracket
    0x301B => CL // Right White Square Bracket
    0xFF09 => CP // Fullwidth Right Parenthesis
    0xFF3D => CL // Fullwidth Right Square Bracket
    0xFF5D => CL // Fullwidth Right Curly Bracket

    // Hyphen
    0x002D => HY // Hyphen-Minus
    0x00AD => BA // Soft Hyphen
    0x2010 => BA // Hyphen
    0x2012 => BA // Figure Dash
    0x2013 => BA // En Dash
    0x2014 => BA // Em Dash
    0x2015 => AI // Horizontal Bar (ambiguous)
    0x2024 => IN // One Dot Leader
    0x2025 => IN // Two Dot Leader
    0x2026 => IN // Horizontal Ellipsis

    // Exclamation/Interrogation
    0x0021 => EX // Exclamation Mark
    0x003F => EX // Question Mark
    0xFF01 => EX // Fullwidth Exclamation Mark
    0xFF1F => EX // Fullwidth Question Mark

    // Symbols allowing break after
    0x002F => SY // Solidus
    0x002C => IS // Comma
    0x002E => IS // Full Stop
    0x0030..=0x0039 => NU // ASCII digits
    0x003A => IS // Colon
    0x003B => IS // Semicolon
    0x0600..=0x0605 => NS // Arabic number signs
    0x0E40..=0x0E44 => NS // Thai leading vowels
    0x0EC0..=0x0EC4 => NS // Lao leading vowels
    0x1100..=0x115F => JL // Hangul choseong
    0x1160..=0x11A7 => JV // Hangul jungseong
    0x11A8..=0x11FF => JT // Hangul jongseong
    0x200D => ZWJ // Zero Width Joiner
    0x21D4 => B2 // Left Right Double Arrow
    0x2329 => OP // Left-Pointing Angle Bracket
    0x232A => CL // Right-Pointing Angle Bracket
    0x261D => EB // White Up Pointing Index
    0x270B => EB // Raised Hand
    0x275B => QU // Heavy Single Turned Comma Quotation Mark Ornament
    0x275C => QU // Heavy Single Comma Quotation Mark Ornament
    0x2E3A => BB // Two-Em Dash
    0x2E3B => BB // Three-Em Dash
    0x301C => NS // Wave Dash
    0x30A0 => NS // Katakana-Hiragana Double Hyphen
    0x30FB => NS // Katakana Middle Dot
    0xFE17 => B2 // Presentation Form for Vertical Left White Lenticular Bracket
    0xFE31 => B2 // Presentation Form for Vertical Em Dash
    0xFE32 => B2 // Presentation Form for Vertical En Dash
    0xFF10..=0xFF19 => NU // Fullwidth digits

    // Ideographic (CJK)
    _ if ch >= 0x3000 && ch <= 0x303F => ID // CJK Symbols
    _ if ch >= 0x3040 && ch <= 0x309F => ID // Hiragana
    _ if ch >= 0x30A0 && ch <= 0x30FF => ID // Katakana
    _ if ch >= 0x3100 && ch <= 0x312F => ID // Bopomofo
    _ if ch >= 0x3130 && ch <= 0x318F => ID // Hangul Compatibility Jamo
    _ if ch >= 0x3190 && ch <= 0x319F => ID // Kanbun
    _ if ch >= 0x31A0 && ch <= 0x31BF => ID // Bopomofo Extended
    _ if ch >= 0x31C0 && ch <= 0x31EF => ID // CJK Strokes
    _ if ch >= 0x31F0 && ch <= 0x31FF => ID // Katakana Phonetic Extensions
    _ if ch >= 0x3200 && ch <= 0x32FF => ID // Enclosed CJK Letters and Months
    _ if ch >= 0x3300 && ch <= 0x33FF => ID // CJK Compatibility
    _ if ch >= 0x3400 && ch <= 0x4DBF => ID // CJK Unified Ideographs Extension A
    _ if ch >= 0x4E00 && ch <= 0x9FFF => ID // CJK Unified Ideographs
    _ if ch >= 0xA000 && ch <= 0xA4CF => ID // Yi Syllables
    _ if ch >= 0xAC00 && ch <= 0xD7A3 => hangul_syllable_class(ch)
    _ if ch >= 0xF900 && ch <= 0xFAFF => ID // CJK Compatibility Ideographs
    _ if ch >= 0xFE30 && ch <= 0xFE4F => ID // CJK Compatibility Forms
    _ if ch >= 0xFF65 && ch <= 0xFFDC => ID // Halfwidth Katakana
    _ if ch >= 0x20000 && ch <= 0x2A6DF => ID // CJK Unified Ideographs Extension B
    _ if ch >= 0x2A700 && ch <= 0x2B73F => ID // CJK Unified Ideographs Extension C
    _ if ch >= 0x2B740 && ch <= 0x2B81F => ID // CJK Unified Ideographs Extension D
    _ if ch >= 0x2F800 && ch <= 0x2FA1F => ID // CJK Compatibility Ideographs Supplement

    // Default to AL (Alphabetic)
    _ => AL
  }
}

///|
fn hangul_syllable_class(ch : Int) -> LineBreakClass {
  let syllable = ch - 0xAC00
  if syllable % 28 == 0 {
    H2
  } else {
    H3
  }
}

///|
/// Check if a line break is allowed between two line break classes
pub fn is_line_break_allowed(
  prev_class : LineBreakClass,
  curr_class : LineBreakClass,
) -> Bool {
  // Simplified UAX #14 rules
  match (prev_class, curr_class) {
    // Always break after mandatory breaks
    (BK, _) => true
    (CR, LF) => false
    (CR, _) => true
    (LF, _) => true

    // Keep glue, word joiner, combining marks, and ZWJ sequences intact.
    (_, GL) => false
    (GL, _) => false
    (_, WJ) => false
    (WJ, _) => false
    (_, CM) => false
    (_, ZWJ) => false
    (ZWJ, _) => false

    // Break after spaces
    (SP, _) => true

    // Don't break before closing punctuation
    (_, CL) => false
    (_, CP) => false

    // Don't break after opening punctuation
    (OP, _) => false

    // Break between ideographic characters
    (ID, ID) => true
    (ID, _) => true
    (_, ID) => true

    // Keep Hangul jamo/syllable clusters together.
    (JL, JL) => false
    (JL, JV) => false
    (JL, H2) => false
    (JL, H3) => false
    (JV, JV) => false
    (JV, JT) => false
    (H2, JV) => false
    (H2, JT) => false
    (JT, JT) => false
    (H3, JT) => false

    // Break before classes that explicitly prefer a preceding break.
    (_, BB) => true

    // Don't break within numbers
    (NU, NU) => false
    (NU, IS) => false
    (IS, NU) => false

    // Don't break between alphabetic characters
    (AL, AL) => false
    (AL, NU) => false
    (NU, AL) => false

    // Break after hyphens
    (HY, _) => true
    (BA, _) => true

    // Default: allow break
    _ => true
  }
}
