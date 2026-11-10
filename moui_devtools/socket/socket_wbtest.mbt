///|
test "loopback socket round-trips one request" {
  let listener = devtools_listen(0)
  if listener < 0 {
    // Windows v1 intentionally reports socket-unavailable; the file transport
    // remains the fallback.
    return
  }
  let port = devtools_port(listener)
  if port <= 0 {
    fail("listener did not expose a port")
  }
  let client = devtools_connect(port)
  if client < 0 {
    fail("client could not connect to the loopback listener")
  }
  let mut server_client = -1
  for _ in 0..<1000 {
    server_client = devtools_accept(listener)
    if server_client >= 0 {
      break
    }
  }
  if server_client < 0 {
    fail("server could not accept the loopback client")
  }
  let request_bytes = @utf8.encode("{\"method\":\"ping\"}\n", bom=false)
  let _ = devtools_write(client, request_bytes, request_bytes.length())
  let buffer = Bytes::make(4096, b'\x00')
  let mut request_len = 0
  for _ in 0..<1000 {
    let read_len = devtools_read(server_client, buffer, 4096)
    if read_len > 0 {
      request_len = read_len
      break
    }
  }
  assert_true(request_len > 0)
  let request = @utf8.decode_lossy(buffer[:request_len], ignore_bom=true)
  assert_true(request.contains("ping"))
  let response_bytes = @utf8.encode("{\"ok\":true}\n", bom=false)
  let _ = devtools_write(server_client, response_bytes, response_bytes.length())
  let mut response_len = 0
  for _ in 0..<1000 {
    let read_len = devtools_read(client, buffer, 4096)
    if read_len > 0 {
      response_len = read_len
      break
    }
  }
  assert_true(response_len > 0)
  let response = @utf8.decode_lossy(buffer[:response_len], ignore_bom=true)
  assert_true(response.contains("\"ok\":true"))
  devtools_close(client)
  devtools_close(server_client)
  devtools_close(listener)
}
