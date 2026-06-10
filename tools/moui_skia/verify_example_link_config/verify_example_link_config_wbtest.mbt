///|
test "counts build variables" {
  inspect(
    count_occurrences(
      "MOUI_SKIA_CC_LINK_FLAGS other MOUI_SKIA_CC_LINK_FLAGS", "MOUI_SKIA_CC_LINK_FLAGS",
    ),
    content="2",
  )
}

///|
test "detects forbidden provider cache tokens" {
  inspect(contains_provider_cache_token(".skia-cache/release"), content="true")
  inspect(contains_provider_cache_token("package/out/static"), content="true")
  inspect(contains_provider_cache_token("m123-abcdef123456"), content="true")
  inspect(
    contains_provider_cache_token("normal build variable"),
    content="false",
  )
}

///|
test "compacts expected link variable" {
  let pkg =
    #|options(
    #|  link: {
    #|    "native": {
    #|      "cc-link-flags": "${build.MOUI_SKIA_CC_LINK_FLAGS}",
    #|    },
    #|  },
    #|)
    #|
  inspect(
    compact_whitespace(pkg).contains(
      expected_link_variable("MOUI_SKIA_CC_LINK_FLAGS"),
    ),
    content="true",
  )
}
