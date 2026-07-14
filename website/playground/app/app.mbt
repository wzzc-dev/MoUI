///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::new_with_environment(
    init=() => {
      let load_effect = @moui.Effect::run(
        key="playground:load-project",
        label="Load Playground project",
        run=dispatch => {
          @playground_bridge.register_project_dispatch(value => {
            dispatch(LoadProject(value))
          })
        },
      )
      (Model::new(), load_effect)
    },
    update=update_with_effect,
    view~,
  )
}

///|
fn update_with_effect(
  model : Model,
  message : Msg,
) -> (Model, @moui.Effect[Msg]) {
  let next = update(model, message)
  match message {
    Run => {
      let request = CompileRequest::new(next).to_json_line()
      (
        next,
        @moui.Effect::run(
          key="playground:compile:" + next.revision.to_string(),
          label="Compile Playground project",
          run=dispatch => {
            @playground_bridge.start_compile(next.revision, request, result => {
              let parsed = @json.parse(result) catch {
                _ => return dispatch(CompilerStatus("Invalid compiler result"))
              }
              let decoded : CompileResult = @json.from_json(parsed) catch {
                _ => return dispatch(CompilerStatus("Invalid compiler result"))
              }
              dispatch(CompileFinished(decoded))
            })
          },
        ),
      )
    }
    Share => {
      let project = PlaygroundProject::new(next).to_json_line()
      (
        next,
        @moui.Effect::run(
          key="playground:share",
          label="Create Playground share link",
          run=_dispatch => @playground_bridge.request_share(project),
        ),
      )
    }
    SelectExample(id) =>
      (
        next,
        @moui.Effect::run(
          key="playground:example:" + id,
          label="Load Playground example",
          run=_dispatch => @playground_bridge.request_example(id),
        ),
      )
    _ => (next, @moui.Effect::none())
  }
}
