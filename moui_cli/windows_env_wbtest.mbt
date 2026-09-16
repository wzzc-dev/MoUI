// White-box tests for MSVC environment derivation (pure functions only;
// vswhere/vcvarsall discovery requires a Windows host).

///|
test "parse_env_output_handles_crlf_and_skips_invalid" {
  let entries = parse_env_output(
    "PATH=C:\\MSVC;C:\\Windows\r\n=zombie\r\nNOEQUALS\r\nEMPTY=\r\nCL=/utf-8\r\n",
  )
  inspect(entries.length(), content="3")
  let mut path_value = ""
  let mut cl_value = ""
  let mut empty_count = 0
  for entry in entries {
    match entry {
      ("PATH", value) => path_value = value
      ("CL", value) => cl_value = value
      ("EMPTY", _) => empty_count += 1
      _ => ()
    }
  }
  inspect(path_value, content="C:\\MSVC;C:\\Windows")
  inspect(cl_value, content="/utf-8")
  inspect(empty_count, content="1")
}

///|
test "apply_env_overrides_sets_and_prepends" {
  let base : Array[(String, String)] = [
    ("PATH", "C:\\Windows"),
    ("CC", "old-cl.exe"),
    ("LIB", "sdk.lib"),
  ]
  let merged = apply_env_overrides(base, [
    SetEnv("CC", "cl.exe"),
    PrependPath("PATH", "C:\\moui\\bin"),
    PrependPath("PATH", "C:\\moui\\bin"),
    PrependPath("LIB", "C:\\vcpkg\\lib"),
    SetEnv("NEW", "value"),
  ])
  let mut cc = ""
  let mut path = ""
  let mut lib = ""
  let mut new_key = ""
  for entry in merged {
    match entry {
      ("CC", value) => cc = value
      ("PATH", value) => path = value
      ("LIB", value) => lib = value
      ("NEW", value) => new_key = value
      _ => ()
    }
  }
  inspect(cc, content="cl.exe")
  // Re-prepending the same front entry must not duplicate it.
  inspect(path, content="C:\\moui\\bin;C:\\Windows")
  inspect(lib, content="C:\\vcpkg\\lib;sdk.lib")
  inspect(new_key, content="value")
}

///|
test "msvc_build_overrides_matches_ps1_flags" {
  let overrides = msvc_build_overrides(
    Some("C:/vcpkg/installed/x64-windows"),
    Some("C:/vcpkg/installed/x64-windows/lib/zlib.lib"),
  ).unwrap()
  let mut cl = ""
  let mut link = ""
  for flag in overrides {
    match flag {
      SetEnv("CL", value) => cl = value
      SetEnv("LINK", value) => link = value
      _ => ()
    }
  }
  inspect(
    cl,
    content="/DNOMINMAX /experimental:c11atomics /utf-8 /wd4005 /DMOONBIT_FFI_EXPORT=",
  )
  inspect(
    link,
    content="comdlg32.lib shell32.lib advapi32.lib ole32.lib user32.lib gdi32.lib dwrite.lib d2d1.lib C:/vcpkg/installed/x64-windows/lib/zlib.lib /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup",
  )
}

///|
test "msvc_build_overrides_requires_zlib" {
  let result = msvc_build_overrides(None, None)
  match result {
    Ok(_) => fail("expected zlib requirement error")
    Err(message) => assert_true(message.contains("zlib"))
  }
}
