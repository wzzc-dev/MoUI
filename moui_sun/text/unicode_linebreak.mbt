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
    LineBreakClass::BK => "BK"
    LineBreakClass::CR => "CR"
    LineBreakClass::LF => "LF"
    LineBreakClass::SP => "SP"
    LineBreakClass::OP => "OP"
    LineBreakClass::CL => "CL"
    LineBreakClass::QU => "QU"
    LineBreakClass::GL => "GL"
    LineBreakClass::NS => "NS"
    LineBreakClass::EX => "EX"
    LineBreakClass::SY => "SY"
    LineBreakClass::IS => "IS"
    LineBreakClass::NU => "NU"
    LineBreakClass::AL => "AL"
    LineBreakClass::ID => "ID"
    LineBreakClass::IN => "IN"
    LineBreakClass::HY => "HY"
    LineBreakClass::BA => "BA"
    LineBreakClass::BB => "BB"
    LineBreakClass::B2 => "B2"
    LineBreakClass::ZW => "ZW"
    LineBreakClass::CM => "CM"
    LineBreakClass::WJ => "WJ"
    LineBreakClass::H2 => "H2"
    LineBreakClass::H3 => "H3"
    LineBreakClass::JL => "JL"
    LineBreakClass::JT => "JT"
    LineBreakClass::JV => "JV"
    LineBreakClass::CP => "CP"
    LineBreakClass::RI => "RI"
    LineBreakClass::EB => "EB"
    LineBreakClass::EModifier => "EModifier"
    LineBreakClass::ZWJ => "ZWJ"
    LineBreakClass::AI => "AI"
    LineBreakClass::Unknown => "Unknown"
  }
}

///|
/// Get line break class for a character
pub fn get_line_break_class(ch : Int) -> LineBreakClass {
  // Basic implementation - can be extended with full Unicode data
  match ch {
    _ if ch < 0 || ch > 0x10FFFF => LineBreakClass::Unknown

    // Line break mandatory
    0x000A => LineBreakClass::LF // Line Feed
    0x000D => LineBreakClass::CR // Carriage Return
    0x000B => LineBreakClass::BK // Vertical Tab
    0x000C => LineBreakClass::BK // Form Feed
    0x0085 => LineBreakClass::BK // Next Line
    0x2028 => LineBreakClass::BK // Line Separator
    0x2029 => LineBreakClass::BK // Paragraph Separator

    // Space
    0x0020 => LineBreakClass::SP // Space
    0x00A0 => LineBreakClass::GL // No-Break Space
    0x2000 => LineBreakClass::BA // En Quad
    0x2001 => LineBreakClass::BA // Em Quad
    0x2002 => LineBreakClass::BA // En Space
    0x2003 => LineBreakClass::BA // Em Space
    0x2004 => LineBreakClass::BA // Three-Per-Em Space
    0x2005 => LineBreakClass::BA // Four-Per-Em Space
    0x2006 => LineBreakClass::BA // Six-Per-Em Space
    0x2007 => LineBreakClass::GL // Figure Space
    0x2008 => LineBreakClass::BA // Punctuation Space
    0x2009 => LineBreakClass::BA // Thin Space
    0x200A => LineBreakClass::BA // Hair Space
    0x200B => LineBreakClass::ZW // Zero Width Space
    0x0300..=0x036F => LineBreakClass::CM // Combining Diacritical Marks
    0x1F1E6..=0x1F1FF => LineBreakClass::RI // Regional Indicator Symbols
    0x1F3FB..=0x1F3FF => LineBreakClass::EModifier // Emoji modifiers
    0x2060 => LineBreakClass::WJ // Word Joiner
    0xFEFF => LineBreakClass::WJ // Zero Width No-Break Space

    // Opening Punctuation
    0x0028 => LineBreakClass::OP // Left Parenthesis
    0x005B => LineBreakClass::OP // Left Square Bracket
    0x007B => LineBreakClass::OP // Left Curly Bracket
    0x00AB => LineBreakClass::QU // Left-Pointing Double Angle Quotation Mark
    0x2018 => LineBreakClass::QU // Left Single Quotation Mark
    0x201C => LineBreakClass::QU // Left Double Quotation Mark
    0x201D => LineBreakClass::QU // Right Double Quotation Mark
    0x2039 => LineBreakClass::QU // Single Left-Pointing Angle Quotation Mark
    0x3008 => LineBreakClass::OP // Left Angle Bracket
    0x300A => LineBreakClass::OP // Left Double Angle Bracket
    0x300C => LineBreakClass::OP // Left Corner Bracket
    0x300E => LineBreakClass::OP // Left White Corner Bracket
    0x3010 => LineBreakClass::OP // Left Black Lenticular Bracket
    0x3014 => LineBreakClass::OP // Left Tortoise Shell Bracket
    0x3016 => LineBreakClass::OP // Left White Lenticular Bracket
    0x3018 => LineBreakClass::OP // Left White Tortoise Shell Bracket
    0x301A => LineBreakClass::OP // Left White Square Bracket
    0xFF08 => LineBreakClass::OP // Fullwidth Left Parenthesis
    0xFF3B => LineBreakClass::OP // Fullwidth Left Square Bracket
    0xFF5B => LineBreakClass::OP // Fullwidth Left Curly Bracket

    // Closing Punctuation
    0x0029 => LineBreakClass::CP // Right Parenthesis
    0x005D => LineBreakClass::CL // Right Square Bracket
    0x007D => LineBreakClass::CL // Right Curly Bracket
    0x00BB => LineBreakClass::QU // Right-Pointing Double Angle Quotation Mark
    0x2019 => LineBreakClass::QU // Right Single Quotation Mark
    0x3009 => LineBreakClass::CL // Right Angle Bracket
    0x300B => LineBreakClass::CL // Right Double Angle Bracket
    0x300D => LineBreakClass::CL // Right Corner Bracket
    0x300F => LineBreakClass::CL // Right White Corner Bracket
    0x3011 => LineBreakClass::CL // Right Black Lenticular Bracket
    0x3015 => LineBreakClass::CL // Right Tortoise Shell Bracket
    0x3017 => LineBreakClass::CL // Right White Lenticular Bracket
    0x3019 => LineBreakClass::CL // Right White Tortoise Shell Bracket
    0x301B => LineBreakClass::CL // Right White Square Bracket
    0xFF09 => LineBreakClass::CP // Fullwidth Right Parenthesis
    0xFF3D => LineBreakClass::CL // Fullwidth Right Square Bracket
    0xFF5D => LineBreakClass::CL // Fullwidth Right Curly Bracket

    // Hyphen
    0x002D => LineBreakClass::HY // Hyphen-Minus
    0x00AD => LineBreakClass::BA // Soft Hyphen
    0x2010 => LineBreakClass::BA // Hyphen
    0x2012 => LineBreakClass::BA // Figure Dash
    0x2013 => LineBreakClass::BA // En Dash
    0x2014 => LineBreakClass::BA // Em Dash
    0x2015 => LineBreakClass::AI // Horizontal Bar (ambiguous)
    0x2024 => LineBreakClass::IN // One Dot Leader
    0x2025 => LineBreakClass::IN // Two Dot Leader
    0x2026 => LineBreakClass::IN // Horizontal Ellipsis

    // Exclamation/Interrogation
    0x0021 => LineBreakClass::EX // Exclamation Mark
    0x003F => LineBreakClass::EX // Question Mark
    0xFF01 => LineBreakClass::EX // Fullwidth Exclamation Mark
    0xFF1F => LineBreakClass::EX // Fullwidth Question Mark

    // Symbols allowing break after
    0x002F => LineBreakClass::SY // Solidus
    0x002C => LineBreakClass::IS // Comma
    0x002E => LineBreakClass::IS // Full Stop
    0x0030..=0x0039 => LineBreakClass::NU // ASCII digits
    0x003A => LineBreakClass::IS // Colon
    0x003B => LineBreakClass::IS // Semicolon
    0x0600..=0x0605 => LineBreakClass::NS // Arabic number signs
    0x0E40..=0x0E44 => LineBreakClass::NS // Thai leading vowels
    0x0EC0..=0x0EC4 => LineBreakClass::NS // Lao leading vowels
    0x1100..=0x115F => LineBreakClass::JL // Hangul choseong
    0x1160..=0x11A7 => LineBreakClass::JV // Hangul jungseong
    0x11A8..=0x11FF => LineBreakClass::JT // Hangul jongseong
    0x200D => LineBreakClass::ZWJ // Zero Width Joiner
    0x21D4 => LineBreakClass::B2 // Left Right Double Arrow
    0x2329 => LineBreakClass::OP // Left-Pointing Angle Bracket
    0x232A => LineBreakClass::CL // Right-Pointing Angle Bracket
    0x261D => LineBreakClass::EB // White Up Pointing Index
    0x270B => LineBreakClass::EB // Raised Hand
    0x275B => LineBreakClass::QU // Heavy Single Turned Comma Quotation Mark Ornament
    0x275C => LineBreakClass::QU // Heavy Single Comma Quotation Mark Ornament
    0x2E3A => LineBreakClass::BB // Two-Em Dash
    0x2E3B => LineBreakClass::BB // Three-Em Dash
    0x301C => LineBreakClass::NS // Wave Dash
    0x30A0 => LineBreakClass::NS // Katakana-Hiragana Double Hyphen
    0x30FB => LineBreakClass::NS // Katakana Middle Dot
    0xFE17 => LineBreakClass::B2 // Presentation Form for Vertical Left White Lenticular Bracket
    0xFE31 => LineBreakClass::B2 // Presentation Form for Vertical Em Dash
    0xFE32 => LineBreakClass::B2 // Presentation Form for Vertical En Dash
    0xFF10..=0xFF19 => LineBreakClass::NU // Fullwidth digits

    // Ideographic (CJK)
    _ if ch >= 0x3000 && ch <= 0x303F => LineBreakClass::ID // CJK Symbols
    _ if ch >= 0x3040 && ch <= 0x309F => LineBreakClass::ID // Hiragana
    _ if ch >= 0x30A0 && ch <= 0x30FF => LineBreakClass::ID // Katakana
    _ if ch >= 0x3100 && ch <= 0x312F => LineBreakClass::ID // Bopomofo
    _ if ch >= 0x3130 && ch <= 0x318F => LineBreakClass::ID // Hangul Compatibility Jamo
    _ if ch >= 0x3190 && ch <= 0x319F => LineBreakClass::ID // Kanbun
    _ if ch >= 0x31A0 && ch <= 0x31BF => LineBreakClass::ID // Bopomofo Extended
    _ if ch >= 0x31C0 && ch <= 0x31EF => LineBreakClass::ID // CJK Strokes
    _ if ch >= 0x31F0 && ch <= 0x31FF => LineBreakClass::ID // Katakana Phonetic Extensions
    _ if ch >= 0x3200 && ch <= 0x32FF => LineBreakClass::ID // Enclosed CJK Letters and Months
    _ if ch >= 0x3300 && ch <= 0x33FF => LineBreakClass::ID // CJK Compatibility
    _ if ch >= 0x3400 && ch <= 0x4DBF => LineBreakClass::ID // CJK Unified Ideographs Extension A
    _ if ch >= 0x4E00 && ch <= 0x9FFF => LineBreakClass::ID // CJK Unified Ideographs
    _ if ch >= 0xA000 && ch <= 0xA4CF => LineBreakClass::ID // Yi Syllables
    _ if ch >= 0xAC00 && ch <= 0xD7A3 => hangul_syllable_class(ch)
    _ if ch >= 0xF900 && ch <= 0xFAFF => LineBreakClass::ID // CJK Compatibility Ideographs
    _ if ch >= 0xFE30 && ch <= 0xFE4F => LineBreakClass::ID // CJK Compatibility Forms
    _ if ch >= 0xFF65 && ch <= 0xFFDC => LineBreakClass::ID // Halfwidth Katakana
    _ if ch >= 0x20000 && ch <= 0x2A6DF => LineBreakClass::ID // CJK Unified Ideographs Extension B
    _ if ch >= 0x2A700 && ch <= 0x2B73F => LineBreakClass::ID // CJK Unified Ideographs Extension C
    _ if ch >= 0x2B740 && ch <= 0x2B81F => LineBreakClass::ID // CJK Unified Ideographs Extension D
    _ if ch >= 0x2F800 && ch <= 0x2FA1F => LineBreakClass::ID // CJK Compatibility Ideographs Supplement

    // Default to AL (Alphabetic)
    _ => LineBreakClass::AL
  }
}

///|
fn hangul_syllable_class(ch : Int) -> LineBreakClass {
  let syllable = ch - 0xAC00
  if syllable % 28 == 0 {
    LineBreakClass::H2
  } else {
    LineBreakClass::H3
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
    (LineBreakClass::BK, _) => true
    (LineBreakClass::CR, LineBreakClass::LF) => false
    (LineBreakClass::CR, _) => true
    (LineBreakClass::LF, _) => true

    // Keep glue, word joiner, combining marks, and ZWJ sequences intact.
    (_, LineBreakClass::GL) => false
    (LineBreakClass::GL, _) => false
    (_, LineBreakClass::WJ) => false
    (LineBreakClass::WJ, _) => false
    (_, LineBreakClass::CM) => false
    (_, LineBreakClass::ZWJ) => false
    (LineBreakClass::ZWJ, _) => false

    // Break after spaces
    (LineBreakClass::SP, _) => true

    // Don't break before closing punctuation
    (_, LineBreakClass::CL) => false
    (_, LineBreakClass::CP) => false

    // Don't break after opening punctuation
    (LineBreakClass::OP, _) => false

    // Break between ideographic characters
    (LineBreakClass::ID, LineBreakClass::ID) => true
    (LineBreakClass::ID, _) => true
    (_, LineBreakClass::ID) => true

    // Keep Hangul jamo/syllable clusters together.
    (LineBreakClass::JL, LineBreakClass::JL) => false
    (LineBreakClass::JL, LineBreakClass::JV) => false
    (LineBreakClass::JL, LineBreakClass::H2) => false
    (LineBreakClass::JL, LineBreakClass::H3) => false
    (LineBreakClass::JV, LineBreakClass::JV) => false
    (LineBreakClass::JV, LineBreakClass::JT) => false
    (LineBreakClass::H2, LineBreakClass::JV) => false
    (LineBreakClass::H2, LineBreakClass::JT) => false
    (LineBreakClass::JT, LineBreakClass::JT) => false
    (LineBreakClass::H3, LineBreakClass::JT) => false

    // Break before classes that explicitly prefer a preceding break.
    (_, LineBreakClass::BB) => true

    // Don't break within numbers
    (LineBreakClass::NU, LineBreakClass::NU) => false
    (LineBreakClass::NU, LineBreakClass::IS) => false
    (LineBreakClass::IS, LineBreakClass::NU) => false

    // Don't break between alphabetic characters
    (LineBreakClass::AL, LineBreakClass::AL) => false
    (LineBreakClass::AL, LineBreakClass::NU) => false
    (LineBreakClass::NU, LineBreakClass::AL) => false

    // Break after hyphens
    (LineBreakClass::HY, _) => true
    (LineBreakClass::BA, _) => true

    // Default: allow break
    _ => true
  }
}
