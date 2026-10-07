# Plan: MoUI Studio 可视化属性 v2——对齐易语言属性窗

- **Status**: active（P1 纯层 + P2 渲染/检查器已落地；全套 4850/4850 绿。P3 form.mbt 往返待做）
- **Goal**: 控件属性可调（字号/加粗/颜色/对齐/可见/禁用 + TextField 三件），
  设计画布、运行预览与导出应用一致渲染；旧文件无损加载。
- **Non-goals**: 锚定/自动布局;数据绑定;控件新种类。

## 设计（已核实锚点）

| 面 | 锚点 |
|---|---|
| IR Control 只有 text+x/y/w/h+items | `domain/ir/ir.mbt:112` |
| 控件→视图唯一出口（设计舞台+运行舞台共用） | `app/workspace.mbt:167` → `app/views.mbt:386 form_widget` |
| codec 控件编解码（encode_control/decode_control） | `domain/codec/codec.mbt:63/413` |
| 检查器属性编辑先例（语义点选 + 字面量补丁） | `app/ide_context.mbt`、`app/update_shell.mbt SelectSemanticNode` |
| 导出应用渲染 = 生成 form.mbt 子集（M4 往返门） | `services/form_designer/parse.mbt`、`services/export/moonbit_codegen.mbt` |
| views 组件支持 theme/typography 逐控件覆盖;foreground/背景容器可用 | `moui/views/pkg.generated.mbti:378/384`、`@core.TypographyScale` |

## 属性集（v1，typed struct + 默认值）

`ControlProps { font_size:Int(0=默认), bold:Bool, text_color/back_color/align:String(空=默认), visible:Bool(默认true), disabled:Bool, multiline/placeholder/password:TextField 三件 }`

解码缺字段 = 默认值（旧 .studio.json 兼容不迁移）；编码默认属性省略。

## Milestones

### P1 纯层（完成，2026-10-07）
- [x] IR ControlProps + Control.props + is_default
- [x] codec encode（默认省略）/decode（缺字段默认）+ 兼容测试
- [x] 59 处 Control 构造点清扫（struct-update 字面量除外）

### P2 渲染链（完成，2026-10-07）
- [x] form_widget 应用属性：字号（TypographyScale 覆盖，仅定制时传主题
      ——默认沿用环境主题避免打回 IDE 暗色）/加粗/前景色（foreground
      修饰器）/背景色（background_brush）/对齐/可见（空视图占位保配对）/
      禁用（Button 去点击、TextField 去 on_input）
- [x] 检查器属性面板：字号数值、加粗开关、文字/背景颜色（#RRGGBB）、
      对齐三胶囊、显示/禁用开关 → SetControlPropText/ToggleControlProp
      （走撤销点，与文本编辑同纪律）
- [x] 渲染测试：字号 20 进 DrawText、visible=false 不渲染

### P3 持久链（进行中）
- [ ] form.mbt 子集语法扩展（属性字面量参数）+ 解析往返门
      `parse(render(m)) == m`
- [ ] moonbit_codegen 把属性写进生成的 form.mbt / 视图构造
- [ ] 导出应用渲染一致（kernel 同步再生）

## 验收
- 设置字号/颜色后设计画布与运行预览一致；旧文件无损加载；
  属性经 form.mbt 往返不丢；两轨差分全绿。

## 边界声明
- 主题切换（亮/暗）与断点属 G7.4 独立切片（设计重：30 个对比度调校的
  ide_* 色板函数需重新推导亮色档，见 docs/moui-studio.md 观感节）。
