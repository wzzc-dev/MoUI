///|
pub(all) struct FormFieldState {
  name : String
  label : String
  value : @core.State[String]
  rules : Array[FormValidationRule]
}

///|
pub(all) struct FormValidationResult {
  valid : Bool
  errors : Array[FormFieldError]
  summary : FormValidationSummary
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FormFieldError {
  name : String
  message : String
} derive(Eq, Debug, ToJson)

///|
struct FormValidationRule {
  validate : (String) -> String?
}

///|
pub(all) struct FormValidationSummary {
  valid : Bool
  errors : Array[FormFieldError]
  first_invalid_id : String?
} derive(Eq, Debug, ToJson)

///|
struct FormController {
  fields : Array[FormFieldState]
}

///|
pub fn FormFieldState::new(
  name~ : String,
  initial? : String = "",
  label? : String = "",
  validator? : (String) -> String? = _value => None,
  rules? : Array[FormValidationRule] = [],
) -> FormFieldState {
  let collected = rules.copy()
  collected.push(FormValidationRule::from_validator(validator))
  { name, label, value: @core.State::new(initial), rules: collected }
}

///|
pub fn FormFieldState::binding(self : FormFieldState) -> @core.Binding[String] {
  self.value.binding()
}

///|
pub fn FormFieldState::validate(self : FormFieldState) -> FormFieldError? {
  let value = self.value.get()
  for rule in self.rules {
    match (rule.validate)(value) {
      Some(message) => return Some({ name: self.name, message })
      None => ()
    }
  }
  None
}

///|
pub fn validate_form(fields : Array[FormFieldState]) -> FormValidationResult {
  let summary = FormValidationSummary::from_fields(fields)
  { valid: summary.valid, errors: summary.errors, summary }
}

///|
pub fn FormValidationRule::new(
  message~ : String,
  validate~ : (String) -> Bool,
) -> FormValidationRule {
  { validate: value => if validate(value) { None } else { Some(message) } }
}

///|
pub fn FormValidationRule::required(
  message? : String = "Required",
) -> FormValidationRule {
  FormValidationRule::new(message~, validate=value => value != "")
}

///|
pub fn FormValidationRule::from_validator(
  validator : (String) -> String?,
) -> FormValidationRule {
  { validate: validator }
}

///|
pub fn FormValidationSummary::from_fields(
  fields : Array[FormFieldState],
) -> FormValidationSummary {
  let errors : Array[FormFieldError] = []
  for field in fields {
    match field.validate() {
      Some(error) => errors.push(error)
      None => ()
    }
  }
  FormValidationSummary::from_errors(errors)
}

///|
pub fn FormValidationSummary::from_errors(
  errors : Array[FormFieldError],
) -> FormValidationSummary {
  {
    valid: errors.length() == 0,
    errors,
    first_invalid_id: if errors.length() == 0 {
      None
    } else {
      Some(errors[0].name)
    },
  }
}

///|
pub fn FormController::new(fields~ : Array[FormFieldState]) -> FormController {
  { fields, }
}

///|
pub fn FormController::validate(self : FormController) -> FormValidationSummary {
  FormValidationSummary::from_fields(self.fields)
}

///|
pub fn FormController::field_error(
  self : FormController,
  name : String,
) -> String {
  let summary = self.validate()
  for error in summary.errors {
    if error.name == name {
      return error.message
    }
  }
  ""
}

///|
pub fn required_field(message? : String = "Required") -> (String) -> String? {
  value => if value == "" { Some(message) } else { None }
}
