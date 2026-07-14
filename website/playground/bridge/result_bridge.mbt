///|
let compile_result_buffer : Ref[Array[Char]] = Ref([])

///|
let compile_result_dispatch : Ref[((String) -> Unit)?] = Ref(None)

///|
let project_load_buffer : Ref[Array[Char]] = Ref([])

///|
let project_load_dispatch : Ref[((String) -> Unit)?] = Ref(None)

///|
pub fn start_compile(
  revision : Int,
  request : String,
  dispatch : (String) -> Unit,
) -> Unit {
  compile_result_dispatch.val = Some(dispatch)
  request_compile(revision, request)
}

///|
pub fn begin_compile_result() -> Unit {
  compile_result_buffer.val = []
}

///|
pub fn append_compile_result_char(character : Char) -> Unit {
  compile_result_buffer.val.push(character)
}

///|
pub fn finish_compile_result() -> Unit {
  let result = String::from_array(compile_result_buffer.val)
  compile_result_buffer.val = []
  match compile_result_dispatch.val {
    Some(dispatch) => {
      compile_result_dispatch.val = None
      dispatch(result)
    }
    None => ()
  }
}

///|
pub fn register_project_dispatch(dispatch : (String) -> Unit) -> Unit {
  project_load_dispatch.val = Some(dispatch)
}

///|
pub fn begin_project_load() -> Unit {
  project_load_buffer.val = []
}

///|
pub fn append_project_load_char(character : Char) -> Unit {
  project_load_buffer.val.push(character)
}

///|
pub fn finish_project_load() -> Unit {
  let project = String::from_array(project_load_buffer.val)
  project_load_buffer.val = []
  match project_load_dispatch.val {
    Some(dispatch) => dispatch(project)
    None => ()
  }
}
