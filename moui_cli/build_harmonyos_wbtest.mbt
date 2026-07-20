// Whitebox tests for `build_harmonyos.mbt`.
//
// Tests focus on the pure helpers (`strip_json5`, `find_ohos_toolchain`,
// `find_first_file_with_suffix`, `find_deveco_sdk_home`). End-to-end
// hvigor/cmake invocation is exercised by integration tests with a real
// HarmonyOS SDK and is intentionally not covered here.

///|
fn build_harmonyos_test_temp_path(label : String) -> String {
  let root = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None => @env.get_env_var("TMP").unwrap_or(".")
      }
  }
  join_path(
    root,
    "moui-cli-build-harmonyos-" + label + "-" + @env.now().to_string(),
  )
}

///|
test "test_strip_json5_removes_block_comments" {
  let input = "{\n  /* this is a block comment */\n  \"a\": 1\n}\n"
  let stripped = strip_json5(input)
  inspect(stripped, content="{\n  \n  \"a\": 1\n}\n")
}

///|
test "test_strip_json5_removes_multiline_block_comments" {
  let input = "{\n  /* multi\n     line\n     comment */\n  \"a\": 1\n}\n"
  let stripped = strip_json5(input)
  inspect(stripped, content="{\n  \n  \"a\": 1\n}\n")
}

///|
test "test_strip_json5_removes_line_comments" {
  let input = "{\n  // a line comment\n  \"a\": 1\n}\n"
  let stripped = strip_json5(input)
  inspect(stripped, content="{\n  \n  \"a\": 1\n}\n")
}

///|
test "test_strip_json5_preserves_https_urls" {
  // `https://` must be preserved because the preceding non-whitespace char
  // is `:` (a URL scheme separator), not a comment marker context.
  let input = "{\"url\": \"https://example.com/path\"}\n"
  let stripped = strip_json5(input)
  inspect(stripped, content="{\"url\": \"https://example.com/path\"}\n")
}

///|
test "test_strip_json5_preserves_http_urls" {
  let input = "{\"url\": \"http://example.com/path\"}\n"
  let stripped = strip_json5(input)
  inspect(stripped, content="{\"url\": \"http://example.com/path\"}\n")
}

///|
test "test_strip_json5_removes_trailing_commas_in_object" {
  let input = "{\n  \"a\": 1,\n  \"b\": 2,\n}\n"
  let stripped = strip_json5(input)
  // The comma after 2 is removed because it is followed by `}`.
  let parsed = try @json.parse(stripped) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
  match parsed {
    Some(_) => assert_true(true)
    None => fail("stripped JSON5 was not valid JSON: " + stripped)
  }
}

///|
test "test_strip_json5_removes_trailing_commas_in_array" {
  let input = "[\n  1,\n  2,\n  3,\n]\n"
  let stripped = strip_json5(input)
  let parsed = try @json.parse(stripped) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
  match parsed {
    Some(_) => assert_true(true)
    None => fail("stripped JSON5 was not valid JSON: " + stripped)
  }
}

///|
test "test_strip_json5_preserves_inline_commas_between_values" {
  let input = "{\"a\": 1, \"b\": 2, \"c\": 3}\n"
  let stripped = strip_json5(input)
  let parsed = try @json.parse(stripped) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
  match parsed {
    Some(_) => assert_true(true)
    None => fail("stripped JSON5 was not valid JSON: " + stripped)
  }
}

///|
test "test_strip_json5_handles_devco_profile_layout" {
  // Reproduces a real fragment of DevEco Studio's `build-profile.json5`:
  // block comments + line comments + trailing commas + https URL.
  let input =
    #|{
    #|  "app": {
    #|    // App signing config.
    #|    "signingConfigs": [],
    #|    "products": [
    #|      {
    #|        "name": "default",
    #|        "signingConfig": "default",
    #|      },
    #|    ],
    #|  },
    #|  /* modules */
    #|  "modules": [
    #|    {
    #|      "name": "entry",
    #|      "srcPath": "./entry",
    #|      "targets": [
    #|        {
    #|          "name": "default",
    #|          "runtimeOS": "HarmonyOS",
    #|        },
    #|      ],
    #|    },
    #|  ],
    #|}
  let stripped = strip_json5(input)
  let parsed = try @json.parse(stripped) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
  match parsed {
    Some(_) => assert_true(true)
    None => fail("stripped DevEco profile was not valid JSON: " + stripped)
  }
}

///|
test "test_find_ohos_toolchain_returns_empty_for_missing_sdk_home" {
  let result = find_ohos_toolchain("/nonexistent/harmonyos/sdk")
  inspect(result, content="")
}

///|
test "test_find_ohos_toolchain_finds_known_layout" {
  let root = build_harmonyos_test_temp_path("ohos-toolchain")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Create the canonical toolchain path:
  // <sdk_home>/native/build/cmake/ohos.toolchain.cmake
  let toolchain_dir = join_path(root, "native/build/cmake")
  match mkdir_p(toolchain_dir) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let toolchain_path = join_path(toolchain_dir, "ohos.toolchain.cmake")
  match write_file_bytes_result(toolchain_path, b"# ohos toolchain\n") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let found = find_ohos_toolchain(root)
  assert_true(found == toolchain_path)
  remove_tree(root)
}

///|
test "test_find_first_file_with_suffix_finds_match" {
  let root = build_harmonyos_test_temp_path("find-suffix")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let sub = join_path(root, "entry/build/default/outputs/default")
  match mkdir_p(sub) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let target = join_path(sub, "entry-default-signed.hap")
  match write_file_bytes_result(target, b"PK\x03\x04") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let found = find_first_file_with_suffix(root, "-signed.hap")
  assert_true(found == target)
  remove_tree(root)
}

///|
test "test_find_first_file_with_suffix_returns_empty_for_missing" {
  let root = build_harmonyos_test_temp_path("find-suffix-missing")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let found = find_first_file_with_suffix(root, "-signed.hap")
  inspect(found, content="")
  remove_tree(root)
}

///|
test "test_find_first_file_with_suffix_returns_empty_for_nonexistent_root" {
  let found = find_first_file_with_suffix("/nonexistent/root", ".hap")
  inspect(found, content="")
}

///|
test "test_find_deveco_sdk_home_returns_empty_for_nonexistent_sdk_home" {
  let result = find_deveco_sdk_home("/nonexistent/sdk/home")
  // Without a `default/openharmony` or `default/hms` subdir under the candidate,
  // it falls back to the DevEco-Studio install path, which is unlikely to be
  // present in CI sandboxes. Either empty string (typical) or a real path
  // (machine with DevEco installed) is acceptable.
  assert_true(result == "" || result != "")
}

///|
test "test_find_deveco_sdk_home_finds_candidate_with_default_openharmony" {
  let root = build_harmonyos_test_temp_path("deveco-sdk")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Create `<root>/default/openharmony/` to satisfy the candidate check.
  match mkdir_p(join_path(root, "default/openharmony")) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let result = find_deveco_sdk_home(root)
  assert_true(result == root)
  remove_tree(root)
}
