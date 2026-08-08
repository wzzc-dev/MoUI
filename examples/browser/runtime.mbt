///|
pub fn runtime(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.program(environment=environment),
    width=1000.0,
    height=760.0,
  )
}
