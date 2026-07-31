///|
/// Walk modifier wrappers until a node reports the requested role.
fn find_semantics_role(
  view : @core.View[Unit],
  role : @core.SemanticsRole,
) -> @core.ViewSemanticsInfo? {
  let info = view.semantics()
  if info.role == Some(role) {
    Some(info)
  } else {
    for child in view.children() {
      match find_semantics_role(child, role) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
/// Walk modifier wrappers until a node reports a non-empty description.
fn find_semantics_description(view : @core.View[Unit]) -> String? {
  let info = view.semantics()
  match info.description {
    Some(description) if description != "" => return Some(description)
    _ => ()
  }
  for child in view.children() {
    match find_semantics_description(child) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
/// Walk modifier wrappers until a node reports required=true.
fn find_semantics_required(view : @core.View[Unit]) -> Bool {
  let info = view.semantics()
  if info.required is Some(true) {
    true
  } else {
    for child in view.children() {
      if find_semantics_required(child) {
        return true
      }
    }
    false
  }
}

///|
/// Walk modifier wrappers until a node reports invalid=true.
fn find_semantics_invalid(view : @core.View[Unit]) -> Bool {
  let info = view.semantics()
  if info.invalid is Some(true) {
    true
  } else {
    for child in view.children() {
      if find_semantics_invalid(child) {
        return true
      }
    }
    false
  }
}

///|
test "form field semantics mark required and invalid state" {
  let field : @core.View[Unit] = form_field(
    label="Email",
    child=@text.text("input"),
    error="Email required",
    required=true,
  )
  guard find_semantics_role(field, @core.SemanticsRole::FormField)
    is Some(role_info) else {
    fail("expected FormField semantics role wrapper")
  }
  assert_true(role_info.role == Some(@core.SemanticsRole::FormField))
  assert_true(find_semantics_required(field))
  assert_true(find_semantics_invalid(field))
  guard find_semantics_description(field) is Some(description) else {
    fail("expected form field description")
  }
  inspect(description, content="Email required")
  assert_true(
    field.identity().kind.contains("AccessibilityLabel") ||
    field.identity().kind.contains("Modified"),
  )
  guard field.semantics().label is Some(field_label) else {
    fail("expected form field accessibility label")
  }
  assert_true(field_label.contains("Email"))
}

///|
test "form field without error stays valid when required" {
  let field : @core.View[Unit] = form_field(
    label="Name",
    child=@text.text("input"),
    helper="Visible name",
    required=true,
  )
  guard find_semantics_role(field, @core.SemanticsRole::FormField) is Some(_) else {
    fail("expected FormField semantics role wrapper")
  }
  assert_true(find_semantics_required(field))
  assert_false(find_semantics_invalid(field))
  guard find_semantics_description(field) is Some(description) else {
    fail("expected form field helper description")
  }
  inspect(description, content="Visible name")
}
