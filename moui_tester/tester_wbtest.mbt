///|
test "tester result labels pass fail steps" {
  inspect(
    TesterStepResult::pass(name="first-frame", detail="commands=4").label(),
    content="first-frame: passed; commands=4",
  )
  inspect(
    TesterStepResult::fail(name="ime", detail="focus=false").label(),
    content="ime: failed; focus=false",
  )
}
