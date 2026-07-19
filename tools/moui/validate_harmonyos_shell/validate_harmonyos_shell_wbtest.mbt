///|
test "root requires XComponent managed shell tokens" {
  let findings = validate_root_text(
    "MoUIRoot.ets", "export struct Root { libraryname: 'other' }",
  )
  debug_inspect(findings.length() >= 2, content="true")
  debug_inspect(
    findings.any(item => item.hint.contains("XComponent")),
    content="true",
  )
}

///|
test "template rejects ArkTS surface/pointer paths" {
  let findings = validate_template_text(
    "Index.ets", "this.controller.onTouch(() => {})",
  )
  debug_inspect(findings.length(), content="1")
  debug_inspect(findings[0].path, content="\"Index.ets\"")
  debug_inspect(findings[0].hint.contains(".onTouch"), content="true")
}

///|
test "bridge requires native XComponent callbacks and forbids JS attach" {
  let missing = validate_bridge_text("bridge.cpp", "int unused = 0;")
  debug_inspect(missing.length() >= 2, content="true")
  let forbidden = validate_bridge_text(
    "bridge.cpp",
    (
      #|OH_NativeXComponent_RegisterCallback(comp, &cb);
      #|// source=native-xcomponent
      #|napi_attach_surface(env, info);
      #|
    ),
  )
  debug_inspect(forbidden.length(), content="1")
  debug_inspect(
    forbidden[0].hint.contains("napi_attach_surface"),
    content="true",
  )
}

///|
test "clean root and bridge produce no findings" {
  let root =
    #|libraryname: 'moui_embedding_harmonyos'
    #|XComponent({ id: 'moui' })
    #|displaySync(() => {})
    #|
  let bridge =
    #|OH_NativeXComponent_RegisterCallback(component, &callbacks);
    #|// source=native-xcomponent for diagnostics
    #|
  debug_inspect(validate_root_text("root.ets", root).length(), content="0")
  debug_inspect(
    validate_bridge_text("bridge.cpp", bridge).length(),
    content="0",
  )
  debug_inspect(validate_template_text("root.ets", root).length(), content="0")
}
