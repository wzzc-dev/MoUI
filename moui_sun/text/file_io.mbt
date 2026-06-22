///|
/// File I/O utilities for reading font files
/// Uses moonbitlang/x/fs package

///|
/// Read a file into Bytes
pub fn read_file(path : String) -> Bytes raise @fs.IOError {
  @fs.read_file_to_bytes(path)
}

///|
/// Check if a file exists
pub fn file_exists(path : String) -> Bool {
  @fs.path_exists(path)
}

///|
/// Write bytes to a file
pub fn write_file(path : String, data : Bytes) -> Unit raise @fs.IOError {
  @fs.write_bytes_to_file(path, data)
}
