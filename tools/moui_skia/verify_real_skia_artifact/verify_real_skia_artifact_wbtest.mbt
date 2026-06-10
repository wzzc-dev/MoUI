///|
let sample_commit = "0123456789abcdef0123456789abcdef01234567"

///|
let sample_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
fn sample_paths() -> ArtifactPaths {
  {
    log_dir: "/artifact",
    preflight_log: "/artifact/linux-real-skia-smoke-preflight.log",
    wrapper_log: "/artifact/linux-real-skia-smoke.log",
    native_log: "/artifact/linux-native-smoke-output.log",
    acceptance_log: "/artifact/linux-real-skia-acceptance.log",
    build_log: "/artifact/linux-skia-build.log",
  }
}

///|
fn sample_status_text() -> String {
  "{\n" +
  "  \"native_smoke_capabilities\": [\n" +
  "    { \"id\": \"surface.descriptor\", \"marker\": \"native smoke surface descriptor backend\" },\n" +
  "    { \"id\": \"text.resource-plan\", \"marker\": \"native smoke text run resource plan count\" }\n" +
  "  ],\n" +
  "  \"native_smoke_expected_values\": [\n" +
  "    { \"marker\": \"native smoke text run resource plan count\", \"value\": \"3\" }\n" +
  "  ]\n" +
  "}\n"
}

///|
fn sample_native_text() -> String {
  "native smoke surface descriptor backend\n" +
  "raster\n" +
  "native smoke text run resource plan count\n" +
  "3\n" +
  "moui_skia native smoke test passed\n"
}

///|
fn sample_provider_lock_text(sha256 : String) -> String {
  "{\n" +
  "  \"providers\": {\n" +
  "    \"release\": {\n" +
  "      \"owner\": \"wzzc-dev\",\n" +
  "      \"repo\": \"skia\",\n" +
  "      \"tag\": \"dev-test\",\n" +
  "      \"release_url\": \"https://example.invalid/skia/releases/dev-test\",\n" +
  "      \"commit\": \"" +
  sample_commit +
  "\",\n" +
  "      \"assets\": {\n" +
  "        \"linux\": {\n" +
  "          \"Release\": {\n" +
  "            \"x64\": {\n" +
  "              \"static\": {\n" +
  "                \"name\": \"Skia-test-linux-Release-x64.zip\",\n" +
  "                \"sha256\": \"" +
  sha256 +
  "\"\n" +
  "              }\n" +
  "            }\n" +
  "          }\n" +
  "        }\n" +
  "      }\n" +
  "    }\n" +
  "  }\n" +
  "}\n"
}

///|
fn sample_wrapper_text() -> String {
  "skia_provider=release\n" +
  "skia_link_mode=static\n" +
  "release_owner=wzzc-dev\n" +
  "release_repo=skia\n" +
  "release_tag=dev-test\n" +
  "release_url=https://example.invalid/skia/releases/dev-test\n" +
  "skia_commit=" +
  sample_commit +
  "\n" +
  "skia_package=Skia-test-linux-Release-x64.zip\n" +
  "skia_package_sha256=" +
  sample_sha256 +
  "\n" +
  "skia_include=/opt/skia/include\n" +
  "skia_lib_dir=/opt/skia/lib\n" +
  "skia_lib=skia\n" +
  "stub_cc_flags=-I/opt/skia/include\n" +
  "cc_link_flags=-L/opt/skia/lib -lskia\n" +
  "library=/opt/skia/lib/libskia.a\n"
}

///|
fn sample_acceptance_text() -> String {
  "smoke_status=0\n" +
  "native_smoke_marker=passed\n" +
  "native_pkg_restore=passed\n" +
  "skia_provider=release\n" +
  "skia_link_mode=static\n" +
  "release_owner=wzzc-dev\n" +
  "release_repo=skia\n" +
  "release_tag=dev-test\n" +
  "release_url=https://example.invalid/skia/releases/dev-test\n" +
  "skia_commit=" +
  sample_commit +
  "\n" +
  "skia_package=Skia-test-linux-Release-x64.zip\n" +
  "skia_package_sha256=" +
  sample_sha256 +
  "\n" +
  "preflight_log=/artifact/linux-real-skia-smoke-preflight.log\n" +
  "wrapper_log=/artifact/linux-real-skia-smoke.log\n" +
  "native_log=/artifact/linux-native-smoke-output.log\n" +
  "acceptance_log=/artifact/linux-real-skia-acceptance.log\n"
}

///|
fn sample_texts() -> ArtifactTexts {
  {
    wrapper_text: sample_wrapper_text(),
    native_text: sample_native_text(),
    acceptance_text: sample_acceptance_text(),
    build_text: None,
    status_text: sample_status_text(),
    provider_lock_text: sample_provider_lock_text(sample_sha256),
  }
}

///|
test "accepts valid release artifact logs" {
  match verify_artifact_texts("linux", true, sample_paths(), sample_texts()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "rejects dry-run wrapper logs" {
  let texts = sample_texts()
  let result = verify_artifact_texts("linux", true, sample_paths(), {
    ..texts,
    wrapper_text: sample_wrapper_text() + "\ndry_run=true\n",
  })
  inspect(
    match result {
      Err(message) => message.contains("dry-run")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects mismatched acceptance log references" {
  let texts = sample_texts()
  let result = verify_artifact_texts("linux", true, sample_paths(), {
    ..texts,
    acceptance_text: sample_acceptance_text().replace(
      old="native_log=/artifact/linux-native-smoke-output.log",
      new="native_log=/artifact/other-native-smoke-output.log",
    ),
  })
  inspect(
    match result {
      Err(message) =>
        message.contains("does not reference expected artifact log")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects provider lock sha mismatches" {
  let texts = sample_texts()
  let result = verify_artifact_texts("linux", true, sample_paths(), {
    ..texts,
    provider_lock_text: sample_provider_lock_text(
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    ),
  })
  inspect(
    match result {
      Err(message) => message.contains("SHA256 mismatch")
      Ok(_) => false
    },
    content="true",
  )
}
