///|
/// A CLDR cardinal plural category.
#derive(Eq, Debug)
pub(all) enum PluralCategory {
  Zero
  One
  Two
  Few
  Many
  Other
}

///|
pub extend PluralCategory with Eq::{not_equal, equal}

///|
pub extend PluralCategory with Debug::{to_repr}

///|
/// Returns the catalog key suffix for this category, such as `one` or `other`.
pub fn PluralCategory::key(self : PluralCategory) -> String {
  match self {
    Zero => "zero"
    One => "one"
    Two => "two"
    Few => "few"
    Many => "many"
    Other => "other"
  }
}

///|
/// Selects the CLDR cardinal plural category for an integer count, using the
/// absolute value of the count. Rules follow the CLDR supplemental plural
/// data (https://unicode.org/repos/cldr/trunk/specs/ldml/tr35-numbers.html#Language_Plural_Rules).
/// Fractional and compact-notation operands are out of scope; languages
/// without a dedicated rule use the root `other` category.
pub fn Locale::plural_category(self : Locale, count : Int32) -> PluralCategory {
  let n = count.to_int64()
  let n = if n < 0L { -n } else { n }
  match self.language() {
    "zh" | "ja" | "ko" | "th" | "vi" | "id" => Other
    "en" | "de" | "nl" | "sv" | "da" | "fi" | "no" | "nb" | "tr" | "el" =>
      if n == 1L {
        One
      } else {
        Other
      }
    "fr" | "pt" =>
      if n <= 1L {
        One
      } else if is_exact_million(n) {
        Many
      } else {
        Other
      }
    "es" | "it" =>
      if n == 1L {
        One
      } else if is_exact_million(n) {
        Many
      } else {
        Other
      }
    "ru" | "uk" => east_slavic_plural(n)
    "pl" => polish_plural(n)
    // CLDR `cs` reserves `many` for visible fractions (v != 0), which an
    // integer count never has.
    "cs" => if n == 1L { One } else if n >= 2L && n <= 4L { Few } else { Other }
    "ar" => arabic_plural(n)
    "hi" => if n == 0L || n == 1L { One } else { Other }
    _ => Other
  }
}

///|
// CLDR 42+ adds `many` to fr/pt/es/it for exact millions; the compact-notation
// exponent operand (`e`) does not apply to plain integer counts.
fn is_exact_million(n : Int64) -> Bool {
  n != 0L && n % 1000000L == 0L
}

///|
fn east_slavic_plural(n : Int64) -> PluralCategory {
  let mod10 = n % 10L
  let mod100 = n % 100L
  if mod10 == 1L && mod100 != 11L {
    One
  } else if mod10 >= 2L && mod10 <= 4L && !(mod100 >= 12L && mod100 <= 14L) {
    Few
  } else if mod10 == 0L ||
    (mod10 >= 5L && mod10 <= 9L) ||
    (mod100 >= 11L && mod100 <= 14L) {
    Many
  } else {
    Other
  }
}

///|
fn polish_plural(n : Int64) -> PluralCategory {
  let mod10 = n % 10L
  let mod100 = n % 100L
  if n == 1L {
    One
  } else if mod10 >= 2L && mod10 <= 4L && !(mod100 >= 12L && mod100 <= 14L) {
    Few
  } else if mod10 <= 1L ||
    (mod10 >= 5L && mod10 <= 9L) ||
    (mod100 >= 12L && mod100 <= 14L) {
    // The mod10 <= 1 branch excludes n == 1 above, so 101/201 are `many`.
    Many
  } else {
    Other
  }
}

///|
fn arabic_plural(n : Int64) -> PluralCategory {
  let mod100 = n % 100L
  if n == 0L {
    Zero
  } else if n == 1L {
    One
  } else if n == 2L {
    Two
  } else if mod100 >= 3L && mod100 <= 10L {
    Few
  } else if mod100 >= 11L && mod100 <= 99L {
    Many
  } else {
    Other
  }
}
