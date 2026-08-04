///|
pub(all) struct FileDialogOptions {
  title : String
  filters : Array[String]
  default_name : String?
}

///|
pub(all) struct DirectoryEntry {
  name : String
  path : String
  is_directory : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct FileServices {
  open_file_fn : (FileDialogOptions) -> ServiceTask[String]
  save_file_fn : (FileDialogOptions) -> ServiceTask[String]
  pick_directory_fn : (FileDialogOptions) -> ServiceTask[String]
  read_text_fn : (String) -> ServiceTask[String]
  write_text_fn : (String, String) -> ServiceTask[Unit]
  read_bytes_fn : (String) -> ServiceTask[Bytes]
  write_bytes_fn : (String, Bytes) -> ServiceTask[Unit]
  list_directory_fn : (String) -> ServiceTask[Array[DirectoryEntry]]
}

///|
pub fn FileDialogOptions::new(
  title? : String = "",
  filters? : Array[String] = [],
  default_name? : String? = None,
) -> FileDialogOptions {
  { title, filters, default_name }
}

///|
pub fn FileServices::new(
  open_file? : (FileDialogOptions) -> ServiceTask[String] = _options => {
    unavailable_task("file:open", "file open")
  },
  save_file? : (FileDialogOptions) -> ServiceTask[String] = _options => {
    unavailable_task("file:save", "file save")
  },
  pick_directory? : (FileDialogOptions) -> ServiceTask[String] = _options => {
    unavailable_task("file:pick-directory", "directory picker")
  },
  read_text? : (String) -> ServiceTask[String] = _path => {
    unavailable_task("file:read-text", "text file read")
  },
  write_text? : (String, String) -> ServiceTask[Unit] = (_path, _text) => {
    unavailable_task("file:write-text", "text file write")
  },
  read_bytes? : (String) -> ServiceTask[Bytes] = _path => {
    unavailable_task("file:read-bytes", "binary file read")
  },
  write_bytes? : (String, Bytes) -> ServiceTask[Unit] = (_path, _bytes) => {
    unavailable_task("file:write-bytes", "binary file write")
  },
  list_directory? : (String) -> ServiceTask[Array[DirectoryEntry]] = _path => {
    unavailable_task("file:list-directory", "directory listing")
  },
) -> FileServices {
  {
    open_file_fn: open_file,
    save_file_fn: save_file,
    pick_directory_fn: pick_directory,
    read_text_fn: read_text,
    write_text_fn: write_text,
    read_bytes_fn: read_bytes,
    write_bytes_fn: write_bytes,
    list_directory_fn: list_directory,
  }
}

///|
pub fn FileServices::unavailable() -> FileServices {
  FileServices::new()
}

///|
pub fn FileServices::open_file(
  self : FileServices,
  options? : FileDialogOptions = FileDialogOptions::new(),
) -> ServiceTask[String] {
  (self.open_file_fn)(options)
}

///|
pub fn FileServices::save_file(
  self : FileServices,
  options? : FileDialogOptions = FileDialogOptions::new(),
) -> ServiceTask[String] {
  (self.save_file_fn)(options)
}

///|
pub fn FileServices::pick_directory(
  self : FileServices,
  options? : FileDialogOptions = FileDialogOptions::new(),
) -> ServiceTask[String] {
  (self.pick_directory_fn)(options)
}

///|
pub fn FileServices::read_text(
  self : FileServices,
  path : String,
) -> ServiceTask[String] {
  (self.read_text_fn)(path)
}

///|
pub fn FileServices::write_text(
  self : FileServices,
  path : String,
  text : String,
) -> ServiceTask[Unit] {
  (self.write_text_fn)(path, text)
}

///|
pub fn FileServices::read_bytes(
  self : FileServices,
  path : String,
) -> ServiceTask[Bytes] {
  (self.read_bytes_fn)(path)
}

///|
pub fn FileServices::write_bytes(
  self : FileServices,
  path : String,
  bytes : Bytes,
) -> ServiceTask[Unit] {
  (self.write_bytes_fn)(path, bytes)
}

///|
pub fn FileServices::list_directory(
  self : FileServices,
  path : String,
) -> ServiceTask[Array[DirectoryEntry]] {
  (self.list_directory_fn)(path)
}
