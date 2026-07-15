///|
test "doctor compares numeric toolchain versions without lexical ordering" {
  inspect(
    numeric_version_text(first_numeric_version("Gradle 9.6.1").unwrap()),
    content="9.6.1",
  )
  inspect(numeric_version_at_least([9, 10], [9, 6, 1]), content="true")
  inspect(numeric_version_at_least([9, 6], [9, 6, 1]), content="false")
  inspect(numeric_version_at_least([15, 4], [15, 4]), content="true")
  inspect(numeric_version_at_least([15, 3, 9], [15, 4]), content="false")
}

///|
test "doctor parses Java and Swift version output from stable markers" {
  inspect(
    java_major_version("openjdk version \"17.0.12\"") == Some(17),
    content="true",
  )
  inspect(
    java_major_version("java version \"1.8.0_402\"") == Some(8),
    content="true",
  )
  let swift = detected_version(
    "swift-driver version: 1.127.15 Apple Swift version 6.2.4", "Apple Swift version",
  )
  inspect(numeric_version_text(swift.unwrap()), content="6.2.4")
}

///|
test "doctor reads pinned NDK and Gradle wrapper versions" {
  let ndk = property_version(
    "Pkg.Desc = Android NDK\nPkg.Revision = 28.2.13676358\n", "Pkg.Revision",
  )
  inspect(numeric_version_text(ndk.unwrap()), content="28.2.13676358")
  inspect(
    numeric_version_has_prefix(ndk.unwrap(), [28, 2, 13676358]),
    content="true",
  )
  let wrapper = gradle_wrapper_version(
    "distributionUrl=https\\://services.gradle.org/distributions/gradle-9.6.1-bin.zip\n",
  )
  inspect(numeric_version_text(wrapper.unwrap()), content="9.6.1")
}

///|
test "doctor reads Gradle wrapper metadata without running the wrapper" {
  let root = test_temp_path("doctor-gradle-wrapper")
  remove_tree(root)
  match mkdir_p(join_path(root, "gradle/wrapper")) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(
    join_path(root, "gradle/wrapper/gradle-wrapper.properties"),
    "distributionUrl=https\\://services.gradle.org/distributions/gradle-9.6.1-bin.zip\n",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write Gradle wrapper fixture")
    }
  }
  let current = gradle_version_floor(
    root,
    join_path(root, "gradlew"),
    detect_host_platform(),
  )
  @fs.write_string_to_file(
    join_path(root, "gradle/wrapper/gradle-wrapper.properties"),
    "distributionUrl=https\\://services.gradle.org/distributions/gradle-9.6-bin.zip\n",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not update Gradle wrapper fixture")
    }
  }
  let old = gradle_version_floor(
    root,
    join_path(root, "gradlew"),
    detect_host_platform(),
  )
  remove_tree(root)
  inspect(
    current is Some(Ok(version)) && version.contains("9.6.1"),
    content="true",
  )
  inspect(
    old is Some(Err(message)) && message.contains("below"),
    content="true",
  )
}

///|
test "doctor reads the repository wrapper declaration without downloading" {
  let root = test_temp_path("doctor-gradle-bootstrap")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let wrapper = join_path(root, "gradlew")
  @fs.write_string_to_file(
    wrapper, "gradle_version=\"${MOUI_GRADLE_VERSION:-9.6.1}\"\n",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write Gradle bootstrap fixture")
    }
  }
  let result = gradle_version_floor(root, wrapper, detect_host_platform())
  remove_tree(root)
  inspect(
    result is Some(Ok(version)) && version.contains("wrapper declaration"),
    content="true",
  )
}

///|
test "doctor parses HarmonyOS SDK metadata from the DevEco envelope" {
  let metadata = harmony_sdk_metadata_text(
    (
      #|{
      #|  "meta": { "version": "1.0.0" },
      #|  "data": {
      #|    "apiVersion": "21",
      #|    "platformVersion": "6.0.1"
      #|  }
      #|}
    ),
  )
  inspect(
    metadata is Ok((api, model)) && api == 21 && model == "6.0.1",
    content="true",
  )
  inspect(
    harmony_sdk_metadata_text("{ \"apiVersion\": \"20\" }") is Err(_),
    content="true",
  )
}

///|
fn doctor_harmony_mobile_fixture(compatible : Int) -> String {
  (
    {
      "harmonyos": {
        "compatibleSdkVersion": compatible,
        "shellMode": "managed",
      },
    } : Json).stringify()
}

///|
fn doctor_harmony_profile_fixture(target : String) -> String {
  (
    {
      "app": {
        "products": [
          { "targetSdkVersion": target, "compatibleSdkVersion": "6.0.0(20)" },
        ],
      },
    } : Json).stringify()
}

///|
test "doctor freezes the HarmonyOS compatible target and model contract" {
  let valid = harmony_project_contract_text(
    doctor_harmony_mobile_fixture(20),
    doctor_harmony_profile_fixture("6.0.1(21)"),
    "{ \"modelVersion\": \"6.0.1\" }",
  )
  inspect(
    valid == Ok("compatibleApi=20 targetApi=21 model=6.0.1"),
    content="true",
  )
  inspect(
    harmony_project_contract_text(
      doctor_harmony_mobile_fixture(21),
      doctor_harmony_profile_fixture("6.0.1(21)"),
      "{ \"modelVersion\": \"6.0.1\" }",
    )
    is Err(_),
    content="true",
  )
  inspect(
    harmony_project_contract_text(
      doctor_harmony_mobile_fixture(20),
      doctor_harmony_profile_fixture("6.0.0(20)"),
      "{ \"modelVersion\": \"6.0.1\" }",
    )
    is Err(_),
    content="true",
  )
  inspect(
    harmony_project_contract_text(
      doctor_harmony_mobile_fixture(20),
      doctor_harmony_profile_fixture("6.0.1(21)"),
      "{ \"modelVersion\": \"6.0.0\" }",
    )
    is Err(_),
    content="true",
  )
}

///|
test "doctor native probe captures tool output without a shell" {
  let host = detect_host_platform()
  let moon = find_executable("moon", host).unwrap()
  let probe = run_doctor_probe(moon, DoubleDashVersion)
  inspect(probe.status, content="0")
  inspect(probe.output != "", content="true")
  match find_executable("pkg-config", host) {
    Some(path) => {
      let packages = run_doctor_probe(path, WaylandPackages)
      inspect(packages.status == 0 || packages.status == 1, content="true")
    }
    None => ()
  }
}

///|
test "doctor resolves the selected Xcode developer directory" {
  let host = detect_host_platform()
  match find_executable("xcode-select", host) {
    Some(path) => {
      let probe = run_doctor_probe(path, XcodeDeveloperPath)
      inspect(probe.status, content="0")
      inspect(probe.output.contains("Developer"), content="true")
    }
    None => ()
  }
}
