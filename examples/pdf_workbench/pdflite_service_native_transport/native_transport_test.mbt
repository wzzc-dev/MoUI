///|
test "pdflite native transport config labels helper command" {
  let config = PdfWorkbenchPdfliteNativeTransportConfig::executable(
    path="/tmp/pdflite-helper",
    args=["--jsonl"],
    cwd="/tmp",
  )
  inspect(config.command, content="/tmp/pdflite-helper")
  inspect(config.args.length(), content="1")
  inspect(config.args[0], content="--jsonl")
  inspect(config.cwd, content="/tmp")
  inspect(config.command_label(), content="/tmp/pdflite-helper --jsonl")
}

///|
test "pdflite native transport parses helper env values" {
  inspect(
    pdf_workbench_pdflite_default_helper_path(),
    content="_build/native/debug/build/examples/pdf_workbench/pdflite_service_cli/pdflite_service_cli.exe",
  )
  let env_config = PdfWorkbenchPdfliteNativeTransportEnvConfig::new(
    helper_path=" /tmp/pdflite-helper ",
    helper_args=" --jsonl  --fixture ",
    helper_cwd=" /tmp/work ",
  )
  match env_config.transport_config() {
    Some(config) => {
      inspect(config.command, content="/tmp/pdflite-helper")
      inspect(config.args.length(), content="2")
      inspect(config.args[0], content="--jsonl")
      inspect(config.args[1], content="--fixture")
      inspect(config.cwd, content="/tmp/work")
    }
    None => fail("expected helper config from env config")
  }
  match
    PdfWorkbenchPdfliteNativeTransportEnvConfig::new(helper_path=" AUTO ").transport_config() {
    Some(config) => {
      inspect(
        config.command,
        content=pdf_workbench_pdflite_default_helper_path(),
      )
      inspect(config.args.length(), content="0")
    }
    None => fail("expected auto helper config")
  }
  match
    PdfWorkbenchPdfliteNativeTransportConfig::from_env_values(
      Some("/tmp/pdflite-helper"),
      args_value=" --jsonl  --fixture ",
      cwd=" /tmp/work ",
    ) {
    Some(config) => {
      inspect(config.command, content="/tmp/pdflite-helper")
      inspect(config.args.length(), content="2")
      inspect(config.args[0], content="--jsonl")
      inspect(config.args[1], content="--fixture")
      inspect(config.cwd, content="/tmp/work")
      inspect(
        config.command_label(),
        content="/tmp/pdflite-helper --jsonl --fixture",
      )
    }
    None => fail("expected helper config")
  }
  match
    PdfWorkbenchPdfliteNativeTransportConfig::from_env_values(
      Some("  "),
      args_value="--jsonl",
    ) {
    Some(_) => fail("expected empty helper path to be ignored")
    None => ()
  }
  match
    PdfWorkbenchPdfliteNativeTransportConfig::from_env_values(Some("auto")) {
    Some(config) =>
      inspect(
        config.command,
        content=pdf_workbench_pdflite_default_helper_path(),
      )
    None => fail("expected auto helper config")
  }
}

///|
test "pdflite native transport parses JSON helper args" {
  let args = pdf_workbench_pdflite_helper_args(
    "[\"--jsonl\",\"--profile\",\"fixture mode\"]",
  )
  inspect(args.length(), content="3")
  inspect(args[0], content="--jsonl")
  inspect(args[1], content="--profile")
  inspect(args[2], content="fixture mode")
  let fallback = pdf_workbench_pdflite_helper_args("[bad json")
  inspect(fallback.length(), content="2")
  inspect(fallback[0], content="[bad")
  inspect(fallback[1], content="json")
}

///|
#cfg(all(target="native", not(platform="windows")))
test "pdflite native transport loads document summary through jsonl helper" {
  let bytes = @app.pdf_workbench_minimum_pdf_bytes()
  let response = (
    {
      "type": "loaded",
      "path": "/tmp/native.pdf",
      "byteLength": bytes.length(),
      "pageCount": 2,
      "selectedPage": 1,
      "extractedText": "alpha page beta page",
      "metadataSummary": "PDF 1.4; parser=pdflite fixture",
      "metadataTitle": "Native Transport",
      "outlineSummary": "Outline fixture",
      "annotationSummary": "Annotation fixture",
      "writebackAvailable": true,
      "unsupportedEntries": ["fixture diagnostic"],
      "pageSummaries": [
        {
          "pageNumber": 1,
          "textPreview": "alpha page",
          "contentDiagnostic": "page 1 ok",
        },
        {
          "pageNumber": 2,
          "textPreview": "beta page",
          "contentDiagnostic": "page 2 ok",
        },
      ],
    } : Json).stringify()
  let config = PdfWorkbenchPdfliteNativeTransportConfig::shell(
    script="if IFS= read -r line; then printf '%s\\n' '" + response + "'; fi",
  )
  let services = config.document_services()
  match services.load_document("/tmp/native.pdf", bytes) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => {
      inspect(document.path, content="/tmp/native.pdf")
      inspect(document.original_bytes.length(), content="\{bytes.length()}")
      inspect(document.page_count, content="2")
      inspect(document.selected_page, content="1")
      inspect(document.metadata_title, content="Native Transport")
      inspect(document.outline_summary, content="Outline fixture")
      inspect(document.annotation_summary, content="Annotation fixture")
      assert_true(document.writeback_available)
      inspect(document.page_summaries.length(), content="2")
      inspect(document.page_summaries[1].text_preview, content="beta page")
    }
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
test "pdflite native transport writes document through jsonl helper" {
  let bytes = @app.pdf_workbench_minimum_pdf_bytes()
  let output = b"%PDF-1.4\n%written by fixture\n"
  let response = (
    {
      "type": "writeback_ready",
      "bytesBase64": @protocol.pdf_workbench_pdflite_protocol_encode_bytes(
        output,
      ),
      "byteLength": output.length(),
      "diagnostics": ["fixture writeback applied"],
    } : Json).stringify()
  let config = PdfWorkbenchPdfliteNativeTransportConfig::shell(
    script="if IFS= read -r line; then printf '%s\\n' '" + response + "'; fi",
  )
  let services = config.document_services()
  let document = match
    @app.PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/native.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="editable",
      dirty=false,
      writeback_available=true,
    ) {
    @app.PdfWorkbenchLoadResult::Loaded(document) =>
      document.with_edit(@app.PdfWorkbenchEdit::StampText(1, "REVIEWED"))
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  match services.writeback_document(document) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      written,
      diagnostics
    ) => {
      inspect(written.length(), content="\{output.length()}")
      inspect(diagnostics.length(), content="1")
      inspect(diagnostics[0], content="fixture writeback applied")
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
test "pdflite native transport surfaces helper failure" {
  let config = PdfWorkbenchPdfliteNativeTransportConfig::shell(
    script=(
      #|if IFS= read -r line; then
      #|  printf 'fixture exploded\n' >&2
      #|  exit 7
      #|fi
    ),
  )
  let services = config.document_services()
  match
    services.load_document(
      "/tmp/native.pdf",
      @app.pdf_workbench_minimum_pdf_bytes(),
    ) {
    @app.PdfWorkbenchLoadResult::Loaded(_) =>
      fail("expected failed helper load")
    @app.PdfWorkbenchLoadResult::Failed(reason) => {
      assert_true(reason.contains("exited with code 7"))
      assert_true(reason.contains("fixture exploded"))
    }
  }
}
