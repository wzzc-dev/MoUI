///|
/// Command-line document opening: building the program with an initial
/// document path must open it through the same `OpenRecentDocument`
/// message the recent-files menu uses, and building it without a path
/// must not request any document open.

///|
fn program_init_open_requests(path : String?) -> Array[String] {
  let (_, effect) = MarkdownEditorApp::new()
    .program(initial_document_path=path)
    .runtime_init()
  let effects = match effect {
    @moui.Effect::Batch(effects) => effects
    effect => [effect]
  }
  let requests : Array[String] = []
  for effect in effects {
    match effect {
      @moui.Effect::Send(OpenRecentDocument(opened)) => requests.push(opened)
      _ => ()
    }
  }
  requests
}

///|
test "program init: initial document path opens through OpenRecentDocument" {
  let path = "/tmp/program-init-document.md"
  let requests = program_init_open_requests(Some(path))
  assert_true(requests.length() == 1)
  assert_true(requests[0] == path)
}

///|
test "program init: empty or absent path opens nothing" {
  assert_true(program_init_open_requests(None).is_empty())
  assert_true(program_init_open_requests(Some("")).is_empty())
}
