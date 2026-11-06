///|
test "program state persistence defaults to none and round-trips" {
  let program : @core.Program[Int32, Unit] = @core.Program::simple(
    init=1,
    update=(model, _delta) => model,
    view=_model => abort("view is not evaluated by this test"),
  )
  inspect(program.runtime_state_persistence() is Some(_), content="false")
  let persisted = program.with_state_persistence(save=model => "v:\{model}", load=payload => {
    if payload == "v:3" {
      Some(3)
    } else {
      None
    }
  })
  match persisted.runtime_state_persistence() {
    Some(persistence) => {
      inspect(persistence.save(3), content="v:3")
      inspect(persistence.load("v:3") is Some(_), content="true")
      inspect(persistence.load("other") is Some(_), content="false")
    }
    None => fail("expected persistence after with_state_persistence")
  }
}

///|
test "program state transport invokes its closures" {
  let store : Array[String] = []
  let transport = @core.ProgramStateTransport::new(
    read=() => if store.is_empty() { None } else { Some(store[0]) },
    write=payload => {
      store.clear()
      store.push(payload)
    },
  )
  inspect(transport.read() is Some(_), content="false")
  transport.write("payload")
  match transport.read() {
    Some(payload) => inspect(payload, content="payload")
    None => fail("expected stored payload")
  }
}
