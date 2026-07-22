///|
fn mobile_config_test_text() -> String {
  (
    {
      "schemaVersion": 1,
      "id": "counter",
      "displayName": "Counter",
      "artifactName": "counter",
      "appPackage": "app",
      "android": { "applicationId": "dev.example.counter", "minSdk": 23 },
      "ios": {
        "bundleId": "dev.example.counter",
        "productName": "Counter",
        "deploymentTarget": "15.0",
      },
    } : Json).stringify(indent=2) +
  "\n"
}

///|
test "mobile config reads window-hosted metadata" {
  let root = test_temp_path("mobile-config")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(
    join_path(root, "moui.mobile.json"),
    mobile_config_test_text(),
  ) catch {
    _ => fail("could not write mobile config fixture")
  }
  let app = match read_mobile_app(root) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(app.id, content="counter")
  inspect(app.display_name, content="Counter")
  match app.android {
    Some(android) =>
      inspect(android.application_id, content="dev.example.counter")
    None => fail("missing Android config")
  }
  match app.ios {
    Some(ios) => inspect(ios.deployment_target, content="15.0")
    None => fail("missing iOS config")
  }
  remove_tree(root)
}

///|
test "mobile config rejects unknown fields" {
  let text = mobile_config_test_text().replace_all(
    old="\"appPackage\": \"app\",",
    new="\"appPackage\": \"app\",\n  \"unexpected\": true,",
  )
  let root = test_temp_path("mobile-config-retired")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(join_path(root, "moui.mobile.json"), text) catch {
    _ => fail("could not write mobile config fixture")
  }
  inspect(read_mobile_app(root) is Err(_), content="true")
  remove_tree(root)
}
