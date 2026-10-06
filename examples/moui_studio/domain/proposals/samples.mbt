///|
/// 内置教学样例：三个完整应用域（点名册 / 口算训练营 / 班级小卖部）
/// + 最小组件。样例同时充当假模型模板与 IDE 模板库。
/// 每个 handler 都带双语 note（可读性契约的活样板）。

///|
/// 最小组件：按钮改标签。
pub fn sample_hello() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.WindowSpec::{
      title: "问候",
      width: 640,
      height: 480,
      timer_interval: 0,
    },
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Label,
        name: "显示",
        text: "",
        x: 260,
        y: 160,
        width: 220,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.Button,
        name: "按钮",
        text: "点我",
        x: 260,
        y: 220,
        width: 100,
        height: 32,
        items: [],
      },
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "点击按钮后在标签上显示问候语",
        note_en: "show a greeting on the label when clicked",
        body: [
          @ir.Call("set_text", [
            @ir.Var("显示"),
            @ir.StrLit("你好，MoUI Studio！"),
          ]),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
/// 点名册：随机抽一位同学（随机数 + 列表框取行）。
pub fn sample_roll_call() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.WindowSpec::{
      title: "班级点名册",
      width: 640,
      height: 480,
      timer_interval: 0,
    },
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Label,
        name: "结果",
        text: "点击按钮开始点名",
        x: 20,
        y: 20,
        width: 300,
        height: 36,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.ListBox,
        name: "名单",
        text: "",
        x: 360,
        y: 20,
        width: 160,
        height: 150,
        items: ["张三", "李四", "王五", "赵六", "钱七"],
      },
      @ir.Control::{
        id: 3,
        kind: @ir.Button,
        name: "点名按钮",
        text: "随机点名",
        x: 20,
        y: 320,
        width: 120,
        height: 36,
        items: [],
      },
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "点名按钮",
        event: @ir.OnClick,
        note_zh: "按名单行数取随机序号，把对应同学显示到结果标签",
        note_en: "pick a random row index and show that student on the result label",
        body: [
          @ir.Declare("人数", @ir.Call("row_count", [@ir.Var("名单")])),
          @ir.Declare("序号", @ir.Call("random", [@ir.Var("人数")])),
          @ir.Call("set_text", [
            @ir.Var("结果"),
            @ir.Call("row_at", [@ir.Var("名单"), @ir.Var("序号")]),
          ]),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
/// 口算训练营：随机出题 + 批改（分支教学样本）。
pub fn sample_drill() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.WindowSpec::{
      title: "口算训练营",
      width: 640,
      height: 480,
      timer_interval: 0,
    },
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Label,
        name: "题目",
        text: "点击「出一新题」开始",
        x: 20,
        y: 20,
        width: 320,
        height: 36,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.TextField,
        name: "答案框",
        text: "",
        x: 20,
        y: 70,
        width: 140,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 3,
        kind: @ir.Button,
        name: "出题按钮",
        text: "出一新题",
        x: 180,
        y: 70,
        width: 110,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 4,
        kind: @ir.Button,
        name: "批改按钮",
        text: "批改",
        x: 20,
        y: 120,
        width: 90,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 5,
        kind: @ir.Label,
        name: "判定",
        text: "",
        x: 130,
        y: 120,
        width: 220,
        height: 32,
        items: [],
      },
    ],
    variables: [
      @ir.Variable::{ name: "第一个数", init: "0", },
      @ir.Variable::{ name: "第二个数", init: "0", },
    ],
    handlers: [
      @ir.Handler::{
        control_name: "出题按钮",
        event: @ir.OnClick,
        note_zh: "随机出两个 20 以内的数，拼成加法题目并清空答案框",
        note_en: "roll two numbers under 20, render an addition problem, clear the answer",
        body: [
          @ir.Assign("第一个数", @ir.Call("random", [@ir.IntLit(20)])),
          @ir.Assign("第二个数", @ir.Call("random", [@ir.IntLit(20)])),
          @ir.Call("set_text", [
            @ir.Var("题目"),
            @ir.Binary(
              @ir.Add,
              @ir.Binary(
                @ir.Add,
                @ir.Call("to_text", [@ir.Var("第一个数")]),
                @ir.StrLit(" + "),
              ),
              @ir.Binary(
                @ir.Add,
                @ir.Call("to_text", [@ir.Var("第二个数")]),
                @ir.StrLit(" = ?"),
              ),
            ),
          ]),
          @ir.Call("set_text", [@ir.Var("答案框"), @ir.StrLit("")]),
        ],
      },
      @ir.Handler::{
        control_name: "批改按钮",
        event: @ir.OnClick,
        note_zh: "比较答案框数值与两数之和，判定标签显示对错",
        note_en: "compare the answer box with the sum and show right or wrong",
        body: [
          @ir.If(
            @ir.Binary(
              @ir.Eq,
              @ir.Call("get_number", [@ir.Var("答案框")]),
              @ir.Binary(
                @ir.Add,
                @ir.Var("第一个数"),
                @ir.Var("第二个数"),
              ),
            ),
            [
              @ir.Call("set_text", [
                @ir.Var("判定"),
                @ir.StrLit("答对了！"),
              ]),
            ],
            [],
            [@ir.Call("set_text", [@ir.Var("判定"), @ir.StrLit("再想想")])],
          ),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
/// 班级小卖部：表格商品 + 营业额 + 提交数据闸门（安全叙事样本）。
pub fn sample_store() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.WindowSpec::{
      title: "班级小卖部",
      width: 640,
      height: 480,
      timer_interval: 0,
    },
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Table,
        name: "商品表",
        text: "",
        x: 20,
        y: 20,
        width: 240,
        height: 130,
        items: ["铅笔 1元", "橡皮 2元", "笔记本 5元"],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.Label,
        name: "营业额标签",
        text: "营业额：0",
        x: 20,
        y: 170,
        width: 240,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 3,
        kind: @ir.Button,
        name: "卖铅笔",
        text: "卖一支铅笔",
        x: 20,
        y: 210,
        width: 130,
        height: 34,
        items: [],
      },
      @ir.Control::{
        id: 4,
        kind: @ir.Button,
        name: "记账",
        text: "提交营业额",
        x: 170,
        y: 210,
        width: 130,
        height: 34,
        items: [],
      },
    ],
    variables: [@ir.Variable::{ name: "营业额", init: "0", }],
    handlers: [
      @ir.Handler::{
        control_name: "卖铅笔",
        event: @ir.OnClick,
        note_zh: "每卖一支铅笔营业额加一，并刷新营业额标签",
        note_en: "add one to revenue per pencil sold and refresh the label",
        body: [
          @ir.Assign(
            "营业额",
            @ir.Binary(@ir.Add, @ir.Var("营业额"), @ir.IntLit(1)),
          ),
          @ir.Call("set_text", [
            @ir.Var("营业额标签"),
            @ir.Binary(
              @ir.Add,
              @ir.StrLit("营业额："),
              @ir.Call("to_text", [@ir.Var("营业额")]),
            ),
          ]),
        ],
      },
      @ir.Handler::{
        control_name: "记账",
        event: @ir.OnClick,
        note_zh: "把营业额提交到班级账本；提交前程序会停下等用户确认",
        note_en: "submit revenue to the class ledger; the program pauses for confirmation",
        body: [
          @ir.Call("submit_data", [
            @ir.Var("营业额"),
            @ir.StrLit("班级账本"),
          ]),
          @ir.Call("message_box", [@ir.StrLit("已提交，等待老师确认")]),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
/// 全部内置样例（IDE 模板库按顺序展示）。
pub fn all_samples() -> Array[@ir.StudioProgram] {
  [sample_hello(), sample_roll_call(), sample_drill(), sample_store()]
}

///|
/// 从程序构造「全量构建」提案（假模型与测试共用）。
pub fn proposal_from_program(
  program : @ir.StudioProgram,
  summary_zh : String,
  summary_en : String,
) -> ProposalV1 {
  ProposalV1::{
    version: PROPOSAL_VERSION,
    summary_zh,
    summary_en,
    window: Some(program.window),
    controls_add: program.controls,
    controls_update: [],
    controls_remove: [],
    variables_add: program.variables,
    variables_update: [],
    variables_remove: [],
    handlers_add: program.handlers,
    handlers_update: [],
    handlers_remove: [],
    open_handler: None,
  }
}
