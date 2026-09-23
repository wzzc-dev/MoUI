///|
/// Field-keyed form action: one message variant can cover every text,
/// toggle, and selection field on a form when the app keys fields by name.
///
/// The app declares `enum FormMsg { Field(String, FieldAction); Submit }`
/// and handles all field edits in a single `Field(name, action)` arm,
/// instead of one `*Changed` variant per field. `name` reuses the
/// `FormFieldState.name` / `FormValidationSummary.first_invalid_id` string
/// key. `Toggle` stores its state as the strings `"true"` / `"false"`
/// because `FormFieldState` values are strings; app models that keep real
/// `Bool`s match on the action directly instead of going through
/// `FormFieldState`.
pub(all) enum FieldAction {
  Text(String)
  Toggle(Bool)
  Select(String)
} derive(Eq, Debug, ToJson)

///|
/// Apply a keyed action to this field, producing the updated field state.
pub fn FormFieldState::apply_action(
  self : FormFieldState,
  action : FieldAction,
) -> FormFieldState {
  match action {
    FieldAction::Text(value) => self.with_value(value)
    FieldAction::Toggle(enabled) =>
      self.with_value(if enabled { "true" } else { "false" })
    FieldAction::Select(value) => self.with_value(value)
  }
}

///|
/// Apply a keyed action to the field with the given `name`. Unknown names
/// leave the array unchanged, so stale dispatches from removed fields are
/// inert.
pub fn update_named_field(
  fields : Array[FormFieldState],
  name : String,
  action : FieldAction,
) -> Array[FormFieldState] {
  fields.map(field =>
    if field.name == name { field.apply_action(action) } else { field }
  )
}
