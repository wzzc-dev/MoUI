///|
test "shell Host Wire v1 parses revisioned PlatformView events" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "sessionGeneration": 7,
    #|  "response": {
    #|    "kind": "platform-view",
    #|    "revision": 3,
    #|    "viewKind": "camera.preview",
    #|    "id": "preview",
    #|    "event": {
    #|      "name": "ready",
    #|      "value": "yes",
    #|      "detail": "",
    #|      "flag": true
    #|    }
    #|  }
    #|}
  match parse_embedder_host_response_envelope_json(text) {
    Some(
      {
        schema_version: 1,
        session_generation: 7,
        response: EmbeddingHostResponse::PlatformView(
          3,
          "camera.preview",
          "preview",
          @core.PlatformViewEvent::Named(
            name="ready",
            value="yes",
            detail="",
            flag=true
          )
        ),
      }
    ) => ()
    _ => fail("expected a revisioned PlatformView response")
  }
}

///|
test "shell Host Wire v1 parses PlatformChannel completion request ids" {
  let text =
    #|{"schemaVersion":1,"sessionGeneration":9,"response":{"kind":"platform-channel","requestId":12,"status":"error","payload":"denied"}}
  match parse_embedder_host_response_envelope_json(text) {
    Some(
      {
        schema_version: 1,
        session_generation: 9,
        response: EmbeddingHostResponse::PlatformChannel(
          { value: 12 },
          @host.PlatformChannelResponse::Error("denied")
        ),
      }
    ) => ()
    _ => fail("expected a PlatformChannel error completion")
  }
}

///|
test "shell Host Wire v1 fails closed on malformed control messages" {
  for
    text in [
      "not-json", "{\"schemaVersion\":2,\"sessionGeneration\":1,\"response\":{\"kind\":\"platform-channel\",\"requestId\":1,\"status\":\"ok\",\"payload\":\"\"}}",
      "{\"schemaVersion\":1,\"sessionGeneration\":0,\"response\":{\"kind\":\"platform-channel\",\"requestId\":1,\"status\":\"ok\",\"payload\":\"\"}}",
      "{\"schemaVersion\":1,\"sessionGeneration\":1,\"response\":{\"kind\":\"platform-view\",\"revision\":0,\"viewKind\":\"camera.preview\",\"id\":\"preview\",\"event\":{\"name\":\"ready\",\"value\":\"\",\"detail\":\"\",\"flag\":true}}}",
      "{\"schemaVersion\":1,\"sessionGeneration\":1,\"response\":{\"kind\":\"platform-channel\",\"requestId\":1,\"status\":\"unknown\",\"payload\":\"\"}}",
    ] {
    assert_true(parse_embedder_host_response_envelope_json(text) is None)
  }
}
