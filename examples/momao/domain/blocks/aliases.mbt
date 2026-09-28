///|
/// IR 类型别名：blocks 内部统一用短名书写（规范出处仍是 @ir）。
/// `Call` 在 Stmt 与 Expr 中同名，匹配时须写 `@ir.Stmt::Call` 消歧。

///|
type Stmt = @ir.Stmt

///|
type Expr = @ir.Expr
