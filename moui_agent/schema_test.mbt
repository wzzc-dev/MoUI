///|
test "schema: DispatchResult ToJson round-trips accepted" {
  let r = DispatchResult::{ accepted: true, reason: None }
  let json = r.to_json()
  guard json is Json::Object(fields) else { fail("expected object") }
  // fields is a Map[String, Json]; check the "accepted" entry.
  match fields.get("accepted") {
    Some(Json::True) => ()
    _ => fail("expected accepted == true")
  }
}

///|
test "schema: DispatchResult ToJson includes reason when present" {
  let r = DispatchResult::{ accepted: false, reason: Some("nope") }
  let json = r.to_json()
  let str = (json : Json).stringify()
  if !str.contains("nope") {
    fail("expected serialized result to contain reason; got \{str}")
  }
}

///|
test "schema: EventSource serializes as a string tag" {
  let ev = AgentEvent::{
    sequence: 7,
    source: EventSource::Agent,
    event: @core.AppEvent::CloseRequested,
  }
  let str = (ev.to_json() : Json).stringify()
  // The source variant should appear in the JSON.
  if !str.contains("Agent") {
    fail("expected source tag in JSON; got \{str}")
  }
  if !str.contains("\"sequence\"") {
    fail("expected sequence field; got \{str}")
  }
}

///|
test "schema: command_intent_from_json decodes known intents" {
  // Build Json values via ToJson (String implements ToJson), avoiding the
  // read-only Json::String constructor and @json.parse catch control flow.
  match command_intent_from_json("Activate".to_json()) {
    Some(@core.CommandIntent::Activate) => ()
    _ => fail("expected Activate")
  }
  match command_intent_from_json("Submit".to_json()) {
    Some(@core.CommandIntent::Submit) => ()
    _ => fail("expected Submit")
  }
  match command_intent_from_json("Paste".to_json()) {
    Some(@core.CommandIntent::Paste) => ()
    _ => fail("expected Paste")
  }
}

///|
test "schema: command_intent_from_json rejects unknown / non-string" {
  if command_intent_from_json("Nope".to_json()) is Some(_) {
    fail("expected unknown intent to be rejected")
  }
  if command_intent_from_json(true.to_json()) is Some(_) {
    fail("expected non-string to be rejected")
  }
  // null via a nullable value's to_json.
  let n : Int? = None
  if command_intent_from_json(n.to_json()) is Some(_) {
    fail("expected null to be rejected")
  }
}

///|
test "schema: SemanticsSnapshot carries node_count and depth" {
  // Build a minimal semantics node to wrap.
  let leaf : @core.SemanticsNode = {
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Text,
    level: None,
    url: "",
    label: "hi",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
  }
  let snap = SemanticsSnapshot::{ root: leaf, node_count: 1, depth: 1 }
  let str = (snap.to_json() : Json).stringify()
  if !str.contains("\"node_count\"") {
    fail("expected node_count field; got \{str}")
  }
  if !str.contains("\"depth\"") {
    fail("expected depth field; got \{str}")
  }
  if !str.contains("hi") {
    fail("expected wrapped node label; got \{str}")
  }
}
