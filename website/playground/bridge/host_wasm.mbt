///|
extern "wasm" fn begin_compile_request(revision : Int) -> Int = "moui_playground" "begin_compile_request"

///|
extern "wasm" fn append_compile_char(handle : Int, character : Char) -> Unit = "moui_playground" "append_compile_char"

///|
extern "wasm" fn finish_compile_request(handle : Int) -> Unit = "moui_playground" "finish_compile_request"

///|
extern "wasm" fn begin_share_request() -> Int = "moui_playground" "begin_share_request"

///|
extern "wasm" fn append_share_char(handle : Int, character : Char) -> Unit = "moui_playground" "append_share_char"

///|
extern "wasm" fn finish_share_request(handle : Int) -> Unit = "moui_playground" "finish_share_request"

///|
extern "wasm" fn begin_example_request() -> Int = "moui_playground" "begin_example_request"

///|
extern "wasm" fn append_example_char(handle : Int, character : Char) -> Unit = "moui_playground" "append_example_char"

///|
extern "wasm" fn finish_example_request(handle : Int) -> Unit = "moui_playground" "finish_example_request"

///|
pub fn request_compile(revision : Int, request : String) -> Unit {
  let handle = begin_compile_request(revision)
  for character in request {
    append_compile_char(handle, character)
  }
  finish_compile_request(handle)
}

///|
pub fn request_share(request : String) -> Unit {
  let handle = begin_share_request()
  for character in request {
    append_share_char(handle, character)
  }
  finish_share_request(handle)
}

///|
pub fn request_example(id : String) -> Unit {
  let handle = begin_example_request()
  for character in id {
    append_example_char(handle, character)
  }
  finish_example_request(handle)
}
