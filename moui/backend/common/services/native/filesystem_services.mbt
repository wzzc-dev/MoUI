///|
pub fn dispatch_text_file(
  request : @host.HostTextFileRequest,
) -> @host.HostServiceResponse {
  match request {
    ReadText(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return Unavailable("file read failed")
        }
        TextFileContent(path, @utf8.decode_lossy(bytes[:], ignore_bom=true))
      } else {
        Unavailable("file does not exist")
      }
    WriteText(path, text) => {
      let bytes = @utf8.encode(text[:], bom=false)
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return Unavailable("file write failed")
      }
      TextFileWritten(path)
    }
  }
}

///|
pub fn dispatch_binary_file(
  request : @host.HostBinaryFileRequest,
) -> @host.HostServiceResponse {
  match request {
    ReadBytes(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return Unavailable("file read failed")
        }
        BinaryFileContent(path, bytes)
      } else {
        Unavailable("file does not exist")
      }
    WriteBytes(path, bytes) => {
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return Unavailable("file write failed")
      }
      BinaryFileWritten(path)
    }
  }
}

///|
pub fn dispatch_list_directory(path : String) -> @host.HostServiceResponse {
  let names : ArrayView[String] = @fs.read_dir(path) catch { _ => [] }
  let entries : Array[@host.HostDirectoryEntry] = []
  for name in names {
    if name.has_prefix(".") {
      continue
    }
    let child_path = path + "/" + name
    let is_directory : Bool = @fs.is_dir(child_path) catch { _ => false }
    entries.push(
      @host.HostDirectoryEntry::new(name~, path=child_path, is_directory~),
    )
  }
  DirectoryListing(path, entries)
}

///|
/// 删除文件(资源管理器 M0-6b)。`@fs.remove_file` 对目录会失败——目录
/// 删除不在本协议内(工程树删除按文件粒度,逐个确认)。
pub fn dispatch_delete_file(path : String) -> @host.HostServiceResponse {
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      _ => return Unavailable("file delete failed")
    }
    FileDeleted(path)
  } else {
    Unavailable("file does not exist")
  }
}
