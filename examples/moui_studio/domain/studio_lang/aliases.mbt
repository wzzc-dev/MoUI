///|
/// IR 类型别名：studio_lang 内部统一使用短名书写；
/// 规范来源仍是 `examples/moui_studio/domain/ir`（对外以 @ir 为唯一出处）。
/// 构造器仍带 @ir 限定（`@ir.Assign(..)`），与本地 Instr 变体区分。

///|
type Expr = @ir.Expr

///|
type Stmt = @ir.Stmt

///|
type Handler = @ir.Handler

///|
type StudioProgram = @ir.StudioProgram

///|
type BinOp = @ir.BinOp
