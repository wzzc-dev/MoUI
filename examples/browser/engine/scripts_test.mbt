///|
test "extract scripts skips external src" {
  let html = "<script>console.log(1)</script><p>x</p><script src='a.js'></script><script>var y = 2</script>"
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="2")
  inspect(scripts[0].contains("console.log(1)"), content="true")
  inspect(scripts[1].contains("var y = 2"), content="true")
}

///|
test "js engine executes scripts and captures console" {
  let engine = JsEngine::new()
  let result = engine.run_scripts([
    "console.log(1 + 2)", "var x = 40; console.log(x + 2)",
  ])
  inspect(result.outputs.length(), content="2")
  inspect(result.outputs[0], content="3")
  inspect(result.outputs[1], content="42")
  inspect(result.errors.length(), content="0")
}

///|
test "script errors are captured non-fatally" {
  let engine = JsEngine::new()
  let result = engine.run_scripts([
    "throw new Error('boom')", "console.log('after')",
  ])
  inspect(result.errors.length(), content="1")
  inspect(result.outputs.length(), content="1")
  inspect(result.outputs[0], content="after")
}

///|
test "missing dom global reports error" {
  let engine = JsEngine::new()
  let result = engine.run_scripts(["__moui_no_such_global__.x"])
  inspect(result.errors.length(), content="1")
}

///|
test "engine state persists across page loads" {
  let engine = JsEngine::new()
  let first = engine.run_scripts(["var counter = 1"])
  inspect(first.errors.length(), content="0")
  let second = engine.run_scripts(["counter += 1; console.log(counter)"])
  inspect(second.outputs[0], content="2")
}
