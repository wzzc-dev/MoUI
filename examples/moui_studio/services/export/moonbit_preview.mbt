///|
/// 毕业通道：程序 IR → 真正参与编译的 MoonBit 源码预览。
///
/// 预览文本由 `moonbit_codegen.generate_source` 产出——与导出 bundle
/// 里 `app/generated_handlers.mbt` 是同一个函数、同一份字节。预览即产物，
/// 不允许出现「展示用的假代码」旁路（这是编译即验收的核心约束）。
/// 程序唯一事实来源仍是 `.studio.json` IR；生成结果逐字节确定。

///|
/// 程序 → 可读且可编译的 MoonBit 源码（= 导出 bundle 的实际产物）。
pub fn moonbit_preview(program : @ir.StudioProgram) -> String {
  generate_source(program).source
}

///|
/// 预览源码 + 语句路径到源码行号的映射（编译诊断用）。
pub fn moonbit_preview_with_lines(
  program : @ir.StudioProgram,
) -> GeneratedSource {
  generate_source(program)
}
