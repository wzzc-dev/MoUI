// Native DevTools transport: loopback TCP + NDJSON. The listener and client
// are non-blocking; the runtime samples `poll` at the DevTools cadence, so no
// background thread ever touches runtime state.

///|
#borrow(buf)
extern "C" fn devtools_read(fd : Int32, buf : Bytes, len : Int32) -> Int32 = "moui_devtools_read"

///|
#borrow(buf)
extern "C" fn devtools_write(fd : Int32, buf : Bytes, len : Int32) -> Int32 = "moui_devtools_write"

///|
extern "C" fn devtools_listen(port : Int32) -> Int32 = "moui_devtools_listen"

///|
extern "C" fn devtools_port(fd : Int32) -> Int32 = "moui_devtools_port"

///|
extern "C" fn devtools_accept(fd : Int32) -> Int32 = "moui_devtools_accept"

///|
extern "C" fn devtools_connect(port : Int32) -> Int32 = "moui_devtools_connect"

///|
extern "C" fn devtools_close(fd : Int32) = "moui_devtools_close"

///|
/// One-client-at-a-time read-only DevTools server. A second client replaces
/// the first only after the first disconnects or errors.
pub struct DevtoolsSocketServer {
  priv listener : Int32
  priv port : Int32
  priv client : Ref[Int32]
  priv pending : Ref[String]
  priv publisher : @publish.DevtoolsPublisher
}

///|
pub fn DevtoolsSocketServer::start(
  publisher : @publish.DevtoolsPublisher,
  port~ : Int32 = 0,
) -> DevtoolsSocketServer? {
  let listener = devtools_listen(port)
  if listener < 0 {
    return None
  }
  Some({
    listener,
    port: devtools_port(listener),
    client: Ref(-1),
    pending: Ref(""),
    publisher,
  })
}

///|
pub fn DevtoolsSocketServer::port(self : DevtoolsSocketServer) -> Int32 {
  self.port
}

///|
fn DevtoolsSocketServer::write_response(
  self : DevtoolsSocketServer,
  response : String,
) -> Unit {
  let payload = response + "\n"
  let bytes = @utf8.encode(payload[:], bom=false)
  let mut offset = 0
  while offset < bytes.length() {
    let chunk = bytes[offset:bytes.length()].to_owned()
    let written = devtools_write(self.client.val, chunk, chunk.length())
    if written <= 0 {
      return
    }
    offset += written
  }
}

///|
fn DevtoolsSocketServer::handle_line(
  self : DevtoolsSocketServer,
  line : String,
) -> Unit {
  let trimmed = line.trim().to_owned()
  if trimmed == "" {
    return
  }
  self.write_response(self.publisher.respond(trimmed))
}

///|
/// Accept a pending client and process every complete request line. Called
/// from the runtime sample hook; never blocks.
pub fn DevtoolsSocketServer::poll(self : DevtoolsSocketServer) -> Unit {
  if self.client.val < 0 {
    let client = devtools_accept(self.listener)
    if client >= 0 {
      self.client.val = client
    }
  }
  if self.client.val < 0 {
    return
  }
  let buffer = Bytes::make(4096, b'\x00')
  let read_len = devtools_read(self.client.val, buffer, 4096)
  if read_len < 0 {
    devtools_close(self.client.val)
    self.client.val = -1
    self.pending.val = ""
    return
  }
  if read_len == 0 {
    return
  }
  let chunk = @utf8.decode_lossy(buffer[:read_len], ignore_bom=true)
  let text = self.pending.val + chunk
  let lines = text.split("\n").to_array()
  let mut rest = ""
  for index, line in lines {
    if index == lines.length() - 1 {
      rest = line.to_owned()
    } else {
      self.handle_line(line.to_owned())
    }
  }
  self.pending.val = rest
}

///|
/// Send one request to a running DevTools server and return its response line.
pub fn request(port : Int32, request_method~ : String = "all") -> String? {
  let fd = devtools_connect(port)
  if fd < 0 {
    return None
  }
  let payload = "{\"id\":1,\"method\":\"" + request_method + "\"}\n"
  let bytes = @utf8.encode(payload[:], bom=false)
  let mut offset = 0
  while offset < bytes.length() {
    let chunk = bytes[offset:bytes.length()].to_owned()
    let written = devtools_write(fd, chunk, chunk.length())
    if written <= 0 {
      devtools_close(fd)
      return None
    }
    offset += written
  }
  let buffer = Bytes::make(65536, b'\x00')
  let mut text = ""
  let mut done = false
  while !done {
    let read_len = devtools_read(fd, buffer, 65536)
    if read_len <= 0 {
      done = true
    } else {
      text += @utf8.decode_lossy(buffer[:read_len], ignore_bom=true)
      if text.contains("\n") {
        done = true
      }
    }
  }
  devtools_close(fd)
  if text == "" {
    None
  } else {
    Some(text.trim().to_owned())
  }
}

///|
/// Port file path from `MOUI_DEVTOOLS_PORT_FILE`; `moui dev --inspect` sets it.
pub fn devtools_port_file_path() -> String? {
  match @env.get_env_var("MOUI_DEVTOOLS_PORT_FILE") {
    Some(path) => if path != "" { Some(path) } else { None }
    None => None
  }
}

///|
/// Install a loopback socket publisher. If the platform cannot open a socket
/// (Windows v1), fall back to the file publisher when a path is supplied.
pub fn install_devtools_socket(
  runtime : @runtime.AppRuntime,
  port_file~ : String,
  file_path~ : String? = None,
) -> Unit {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(Some(runtime))
  let publisher = @publish.DevtoolsPublisher::new(
    path="",
    snapshot=() => {
      match runtime_ref.val {
        Some(value) => Some(value.inspector_snapshot())
        None => None
      }
    },
    trace=() => None,
    diagnostics=() => [],
  )
  match DevtoolsSocketServer::start(publisher) {
    Some(server) => {
      let port_text = server.port().to_string()
      @fs.write_bytes_to_file(port_file, @utf8.encode(port_text[:], bom=false)) catch {
        _ => ()
      }
      runtime.set_devtools_sample_observer(Some(() => server.poll()))
    }
    None =>
      match file_path {
        Some(path) => @publish.install_devtools_publisher(runtime, path~)
        None => ()
      }
  }
}
