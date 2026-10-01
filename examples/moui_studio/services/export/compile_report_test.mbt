///|
/// 用真实 `moon check` 输出样本锁死诊断解析（样本取自实测输出，含中文路径
/// 与 Unicode 边框；解析不得依赖 ASCII 装饰线）。
test "parse_moon_diagnostics 解析错误与警告" {
  let output =
    #|Error: [4014]
    #|   ╭─[ /private/tmp/x/src/main.mbt:2:17 ]
    #|   │
    #| 2 │   let x : Int = "not an int"
    #|   │                 ──────┬─────  
    #|   │                       ╰─────── Expr Type Mismatch
    #|        has type : String
    #|        wanted   : Int
    #|───╯
    #|Warning: [0002]
    #|   ╭─[ /private/tmp/x/src/main.mbt:3:7 ]
    #|   │
    #| 3 │   let unused = 3
    #|   │       ───┬──  
    #|   │          ╰──── Warning (unused_value): Unused variable 'unused'
    #|───╯
    #|Failed with 1 warnings, 1 errors.
    #|
  let diagnostics = @export.parse_moon_diagnostics(output)
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].severity, "error")
  assert_eq(diagnostics[0].code, "4014")
  assert_eq(diagnostics[0].file, "/private/tmp/x/src/main.mbt")
  assert_eq(diagnostics[0].line, 2)
  assert_eq(diagnostics[0].column, 17)
  debug_inspect(
    diagnostics[0].text.contains("Expr Type Mismatch"),
    content="true",
  )
  debug_inspect(diagnostics[0].text.contains("wanted"), content="true")
  assert_eq(diagnostics[1].severity, "warning")
  assert_eq(diagnostics[1].code, "0002")
  assert_eq(diagnostics[1].line, 3)
}

///|
test "parse_moon_diagnostics 对无诊断输出返回空数组" {
  let diagnostics = @export.parse_moon_diagnostics(
    "Finished. moon: ran 3 tasks\n",
  )
  assert_eq(diagnostics.length(), 0)
}

///|
test "CompileReport 错误筛选只返回 error" {
  let report : @export.CompileReport = {
    ok: false,
    exit_code: 255,
    target: "native",
    source_path: "app/generated_handlers.mbt",
    output: "",
    diagnostics: [
      @export.CompileDiagnostic::{
        severity: "warning",
        code: "0002",
        file: "a.mbt",
        line: 1,
        column: 1,
        text: "warn",
      },
      @export.CompileDiagnostic::{
        severity: "error",
        code: "4014",
        file: "a.mbt",
        line: 2,
        column: 3,
        text: "boom",
      },
    ],
    artifacts: [],
    work_root: "/tmp/x",
  }
  assert_eq(report.errors().length(), 1)
  match report.first_error() {
    Some(first) => {
      assert_eq(first.code, "4014")
      assert_eq(first.line, 2)
    }
    None => fail("应能取到首条错误")
  }
}
