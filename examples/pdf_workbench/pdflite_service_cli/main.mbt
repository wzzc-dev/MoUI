///|
async fn main {
  let handler = @pdflite_adapter.service_handler()
  while @stdio.stdin.read_until("\n") is Some(line) {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      let response = match
        @protocol.PdfWorkbenchPdfliteServiceRequest::from_json_line(trimmed) {
        Some(request) => handler.handle_request(request)
        None =>
          @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
            "pdflite service received malformed request",
          )
      }
      @stdio.stdout.write(response.to_json_line() + "\n")
    }
  }
}
