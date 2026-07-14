///|
test "playground compile request contains both controlled files" {
  let request = CompileRequest::new(Model::new())
  inspect(request.files.length(), content="2")
  inspect(request.files[0].path, content="main.mbt")
  inspect(request.files[1].path, content="moon.pkg")
  inspect(request.lesson_id, content="01-hello-world")
}
