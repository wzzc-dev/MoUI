///|
test "cli_version_from_manifest parses the version line" {
  let manifest = (
    #|name = "wzzc-dev/moui_cli"
    #|
    #|version = "0.1.9"
    #|
    #|description = "Standalone project generator and environment doctor for MoUI"
  ).to_string()
  inspect(cli_version_from_manifest(manifest), content="0.1.9")
}

///|
test "cli_version_from_manifest falls back without a version line" {
  let manifest = (
    #|name = "wzzc-dev/moui_cli"
    #|
    #|readme = "README.md"
  ).to_string()
  inspect(cli_version_from_manifest(manifest), content="0.0.0")
}

///|
test "embedded module manifest carries a parseable version" {
  inspect(cli_version().has_prefix("0."), content="true")
}
