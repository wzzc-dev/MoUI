///|
/// 清理临时目录（上一次运行可能留下的文件）。
fn clean_config_dir(dir : String) -> Unit {
  @x/fs.remove_file("\{dir}/config.json") catch {
    _ => ()
  }
  @x/fs.remove_dir(dir) catch {
    _ => ()
  }
}

///|
test "load_provider_config 解析完整配置" {
  let dir = "momao_config_tmp"
  let path = "\{dir}/config.json"
  clean_config_dir(dir)
  @x/fs.create_dir(dir) catch {
    _ => ()
  }
  let content = "{\"provider\":{\"endpoint\":\"https://api.stepfun.com/step_plan/v1\",\"model\":\"step-5-preview\",\"api_key\":\"secret-key\"}}"
  @x/fs.write_string_to_file(path, content) catch {
    _ => fail("测试配置应可写入")
  }
  match @provider_native.load_provider_config(path) {
    Some(config) => {
      assert_eq(config.endpoint, "https://api.stepfun.com/step_plan/v1")
      assert_eq(config.model, "step-5-preview")
      assert_eq(config.api_key, "secret-key")
    }
    None => fail("完整配置应解析成功")
  }
  clean_config_dir(dir)
}

///|
test "load_provider_config 拒绝残缺、非法与缺失" {
  let dir = "momao_config_tmp"
  let path = "\{dir}/config.json"
  clean_config_dir(dir)
  @x/fs.create_dir(dir) catch {
    _ => ()
  }
  // 缺 api_key
  @x/fs.write_string_to_file(
    path, "{\"provider\":{\"endpoint\":\"e\",\"model\":\"m\"}}",
  ) catch {
    _ => ()
  }
  match @provider_native.load_provider_config(path) {
    Some(_) => fail("缺 api_key 必须返回 None")
    None => ()
  }
  // 非法 JSON
  @x/fs.write_string_to_file(path, "not json") catch {
    _ => ()
  }
  match @provider_native.load_provider_config(path) {
    Some(_) => fail("非法 JSON 必须返回 None")
    None => ()
  }
  // endpoint 非字符串
  @x/fs.write_string_to_file(
    path, "{\"provider\":{\"endpoint\":1,\"model\":\"m\",\"api_key\":\"k\"}}",
  ) catch {
    _ => ()
  }
  match @provider_native.load_provider_config(path) {
    Some(_) => fail("endpoint 非字符串必须返回 None")
    None => ()
  }
  // 不存在的文件（空目录下的不同文件名）
  match @provider_native.load_provider_config("\{dir}/missing.json") {
    Some(_) => fail("缺失文件必须返回 None")
    None => ()
  }
  clean_config_dir(dir)
}

///|
/// live smoke：配置存在时真实请求一次阶跃星辰（消耗少量 key 配额）；
/// 配置缺失（本地/CI 未填 .config.json）静默跳过——验收语义是
/// 「配置存在时可跑通」，不是「无凭据也必须联网」。
/// 路径按 moon 工具的实际 cwd 候选解析：module 根（moon test，探针实测
/// cwd = examples/momao/）与仓库根（moon run）各一个。
async test "live smoke (skips without .config.json)" {
  let config = match @provider_native.load_provider_config(".config.json") {
    Some(config) => Some(config)
    None => @provider_native.load_provider_config("examples/momao/.config.json")
  }
  match config {
    None => ()
    Some(config) =>
      match
        @provider_native.provider_live_completion(
          config, "只回复一个词：ok",
        ) {
        Ok(content) => assert_true(content.length() > 0)
        Err(reason) => fail("live smoke 失败：\{reason}")
      }
  }
}
