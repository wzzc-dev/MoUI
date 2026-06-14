///|
pub struct ChoiceItem {
  id : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ChipVariant {
  Filled
  Outline
  Soft
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SegmentedControlSize {
  Compact
  Regular
} derive(Eq, Debug, ToJson)
