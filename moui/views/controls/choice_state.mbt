///|
pub struct ChoiceItem {
  id : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub extend ChoiceItem with Debug::{to_repr}

///|
pub extend ChoiceItem with Eq::{not_equal, equal}

///|
pub extend ChoiceItem with ToJson::{to_json}

// ChipVariant and SegmentedControlSize moved to style/ sub-package.
