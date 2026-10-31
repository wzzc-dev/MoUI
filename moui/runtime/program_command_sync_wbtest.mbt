///|
/// D1 (plan hot-path-invalidation-boilerplate-convergence): an unchanged
/// derived command list reuses the installed map — `sync` returns `None` and
/// no new closures are built.
test "program command sync reuses the map when the command set is unchanged" {
  let sync : ProgramCommandSync[Int32] = ProgramCommandSync::new()
  let dispatched : Array[Int32] = []
  let commands = () => {
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(intent=@core.Copy, label="Copy"),
        message=1,
      ),
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(intent=@core.Paste, label="Paste"),
        message=2,
      ),
    ]
  }
  let first = sync.sync(commands(), fn(message : Int32) {
    dispatched.push(message)
  })
  assert_true(first is Some(_))
  // Same commands re-derived (fresh array, fresh messages): map reused.
  let second = sync.sync(commands(), fn(message : Int32) {
    dispatched.push(message)
  })
  assert_true(second is None)
}

///|
/// D1 correctness with model-dependent messages: a reused map dispatches the
/// message from the latest derivation, not the one captured at build time.
test "program command sync dispatches the latest model-derived message" {
  let sync : ProgramCommandSync[Int32] = ProgramCommandSync::new()
  let dispatched : Array[Int32] = []
  // Build with message=0; re-derive with the same command but message=7.
  let first = sync.sync(
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(intent=@core.Undo, label="Undo"),
        message=0,
      ),
    ],
    fn(message : Int32) { dispatched.push(message) },
  )
  let map = match first {
    Some(map) => map
    None => fail("expected initial map build")
  }
  ignore(
    sync.sync(
      [
        @core.ProgramCommand::new(
          command=@core.ActionCommand::new(intent=@core.Undo, label="Undo"),
          message=7,
        ),
      ],
      fn(message : Int32) { dispatched.push(message) },
    ),
  )
  assert_true(dispatched.is_empty())
  assert_true(
    map.dispatch_command(
      @core.ActionCommand::new(intent=@core.Undo, label="Undo"),
    ),
  )
  assert_eq(dispatched, [7])
}

///|
/// A changed command set (enabled flag flipped) rebuilds the map.
test "program command sync rebuilds when the command set changes" {
  let sync : ProgramCommandSync[Int32] = ProgramCommandSync::new()
  let dispatched : Array[Int32] = []
  let enabled = sync.sync(
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(intent=@core.Copy, label="Copy"),
        message=1,
      ),
    ],
    fn(message : Int32) { dispatched.push(message) },
  )
  assert_true(enabled is Some(_))
  let disabled = sync.sync(
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=@core.Copy,
          label="Copy",
          enabled=false,
        ),
        message=1,
      ),
    ],
    fn(message : Int32) { dispatched.push(message) },
  )
  assert_true(disabled is Some(_))
}
