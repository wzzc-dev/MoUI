///|
pub(all) struct TesterStepResult {
  name : String
  passed : Bool
  detail : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RuntimeSmokeSnapshot {
  title : String
  draw_command_count : Int
  focused_text_input : Bool
  text_input_text : String
  inspector : @runtime.InspectorSnapshot
} derive(Eq, Debug, ToJson)

///|
pub fn TesterStepResult::pass(
  name~ : String,
  detail? : String = "",
) -> TesterStepResult {
  { name, passed: true, detail }
}

///|
pub fn TesterStepResult::fail(
  name~ : String,
  detail? : String = "",
) -> TesterStepResult {
  { name, passed: false, detail }
}

///|
pub fn TesterStepResult::label(self : TesterStepResult) -> String {
  let status = if self.passed { "passed" } else { "failed" }
  if self.detail == "" {
    "\{self.name}: \{status}"
  } else {
    "\{self.name}: \{status}; \{self.detail}"
  }
}

///|
pub fn runtime_smoke_snapshot(
  title~ : String,
  runtime : @runtime.AppRuntime,
) -> RuntimeSmokeSnapshot {
  ignore(runtime.draw_commands())
  let input = runtime.focused_text_input()
  {
    title,
    draw_command_count: runtime.draw_commands().length(),
    focused_text_input: input.focused,
    text_input_text: input.text,
    inspector: runtime.inspector_snapshot(),
  }
}

///|
pub fn first_frame_step(
  title~ : String,
  runtime : @runtime.AppRuntime,
) -> TesterStepResult {
  let snapshot = runtime_smoke_snapshot(title~, runtime)
  if snapshot.draw_command_count > 0 {
    TesterStepResult::pass(
      name="first-frame",
      detail="commands=\{snapshot.draw_command_count}",
    )
  } else {
    TesterStepResult::fail(name="first-frame", detail="blank draw command list")
  }
}
