///|
#derive(Eq, Debug, ToJson)
pub(all) enum FormFieldStatus {
  Normal
  Required
  Validating
  Invalid
  Disabled
  ReadOnly
}

///|
pub extend FormFieldStatus with Debug::{to_repr}

///|
pub extend FormFieldStatus with Eq::{not_equal, equal}

///|
pub extend FormFieldStatus with ToJson::{to_json}

///|
pub fn FormFieldStatus::to_string(self : FormFieldStatus) -> String {
  match self {
    Normal => "normal"
    Required => "required"
    Validating => "validating"
    Invalid => "invalid"
    Disabled => "disabled"
    ReadOnly => "read_only"
  }
}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum FormFieldLayout {
  Vertical
  Horizontal
}

///|
pub extend FormFieldLayout with Debug::{to_repr}

///|
pub extend FormFieldLayout with Eq::{not_equal, equal}

///|
pub extend FormFieldLayout with ToJson::{to_json}

///|
pub fn FormFieldLayout::to_string(self : FormFieldLayout) -> String {
  match self {
    Vertical => "vertical"
    Horizontal => "horizontal"
  }
}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum FormValidationDisplay {
  Always
  OnInvalid
  Hidden
}

///|
pub extend FormValidationDisplay with Debug::{to_repr}

///|
pub extend FormValidationDisplay with Eq::{not_equal, equal}

///|
pub extend FormValidationDisplay with ToJson::{to_json}

///|
pub fn FormValidationDisplay::to_string(self : FormValidationDisplay) -> String {
  match self {
    Always => "always"
    OnInvalid => "on_invalid"
    Hidden => "hidden"
  }
}

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
  { label, control, }
}
