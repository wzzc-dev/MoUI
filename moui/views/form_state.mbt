///|
pub(all) enum FormFieldStatus {
  Normal
  Required
  Validating
  Invalid
  Disabled
  ReadOnly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FormFieldLayout {
  Vertical
  Horizontal
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FormValidationDisplay {
  Always
  OnInvalid
  Hidden
} derive(Eq, Debug, ToJson)

///|
pub struct BaselineFormRow[Msg] {
  label : @core.View[Msg]
  control : @core.View[Msg]
}

///|
pub fn[Msg] BaselineFormRow::new(
  label~ : @core.View[Msg],
  control~ : @core.View[Msg],
) -> BaselineFormRow[Msg] {
  { label, control }
}
