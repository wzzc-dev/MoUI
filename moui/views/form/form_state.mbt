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
pub(all) enum FormFieldLayout {
  Vertical
  Horizontal
} derive(Eq, Debug, ToJson)

///|
pub fn FormFieldLayout::to_string(self : FormFieldLayout) -> String {
  match self {
    Vertical => "vertical"
    Horizontal => "horizontal"
  }
}

///|
pub(all) enum FormValidationDisplay {
  Always
  OnInvalid
  Hidden
} derive(Eq, Debug, ToJson)

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
  { label, control }
}
