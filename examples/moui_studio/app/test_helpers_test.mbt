///|
/// 测试包共享助手：按**链下标**选中积木。
///
/// 生产代码有两条选中路径——位置命中（`BlocksCanvasTap` 经
/// `blocks_hit_index`）与路径寻址（`select_block_by_path`，用于运行跳转、
/// 插入后定位）。`Msg::SelectBlock`（按链下标）**没有生产者**，已删除——
/// 它是被 `scripts/validate-dead-messages.mjs` 抓出的死消息之一。
/// 测试改走与生产一致的路径寻址，因此需要一个「下标 → 路径」的薄适配。
///
/// 放在单独文件：`*_test.mbt` 同属一个测试包，重复定义会互相冲突。
fn select_block_index(model : @app.Model, index : Int) -> @app.Model {
  let chain = @app.block_chain_of(model)
  if index < 0 || index >= chain.length() {
    return model
  }
  @app.select_block_by_path(model, chain[index].path)
}
