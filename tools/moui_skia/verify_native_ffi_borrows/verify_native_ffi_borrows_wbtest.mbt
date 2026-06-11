///|
test "accepts borrowed non primitive and unannotated primitive params" {
  let block =
    #|#borrow(canvas, text)
    #|extern "C" fn native_canvas_draw_text(
    #|  canvas : CanvasHandle,
    #|  x : Float,
    #|  text : Bytes,
    #|) -> Unit = "native_canvas_draw_text"
    #|
  match check_block(block, "native/canvas_native.mbt") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "rejects missing non primitive annotation" {
  let block =
    #|extern "C" fn native_canvas_draw_text(
    #|  canvas : CanvasHandle,
    #|  x : Float,
    #|) -> Unit = "native_canvas_draw_text"
    #|
  inspect(
    match check_block(block, "native/canvas_native.mbt") {
      Err(message) => message.contains("missing #borrow/#owned")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects primitive annotation" {
  let block =
    #|#borrow(canvas, x)
    #|extern "C" fn native_canvas_translate(
    #|  canvas : CanvasHandle,
    #|  x : Float,
    #|)
    #|
  inspect(
    match check_block(block, "native/canvas_native.mbt") {
      Err(message) => message.contains("annotates primitive parameter")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects unknown annotation" {
  let block =
    #|#borrow(canvas, missing)
    #|extern "C" fn native_canvas_save(canvas : CanvasHandle) -> Int
    #|
  inspect(
    match check_block(block, "native/canvas_native.mbt") {
      Err(message) => message.contains("annotates unknown parameter")
      Ok(_) => false
    },
    content="true",
  )
}
