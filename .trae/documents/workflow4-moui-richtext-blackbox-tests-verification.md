# Workflow 4: moui_richtext 黑盒测试验证计划

## 摘要

Workflow 4 要求为 `moui_richtext` 包补稳定黑盒测试。经探索确认，**所有 5 个测试文件已创建/扩展完毕**，共新增 82 个测试用例（远超 30+ 目标）。本计划仅需执行最终验证命令确认全部通过，并输出简明中文总结。

## 当前状态分析

通过 `Glob` 和 `Read` 已确认以下文件存在且包含完整测试：

| 文件 | 状态 | 测试数 | 覆盖能力 |
|------|------|--------|----------|
| `moui_richtext/rich_text_document_test.mbt` | 新建 | 22 | RichTextDocument::plain（按 `\n` 切分、空串、单行、尾换行）、RichTextDocument::new、RichTextBlock::new 默认值、RichTextRun::new 默认值、markdown_document 解析（heading/paragraph/无序列表/任务列表/有序列表/引用/` ``` ` 代码块/`~~~` 代码块/水平线/表格/front matter）、source_range/content_range 子集不变量、visual_text 行为、结构体字段可访问性 |
| `moui_richtext/editor_commands_test.mbt` | 新建 | 16 | Bold 包裹/解包对称性、Italic/Code/Strikethrough 包裹+解包、Heading(1)/BulletList/TaskList/OrderedList/Quote 块变换、Paragraph 剥离 heading 标记、HorizontalRule 替换行、markdown_editor_inline_marker 返回值、markdown_editor_range_has_inline_marker 检测、markdown_editor_inline_marker_pair_at_caret、命令结果光标边界 |
| `moui_richtext/editor_input_transforms_test.mbt` | 新建 | 15 | `(`/`[`/`{`/`` ` `` 配对且光标置内、选区包裹（`(`/`*`/`**`）、普通字符返回 None、代码块内返回 None、跳过闭合分隔符、Tab 缩进（两空格前缀）、段中空格返回 None、markdown_editor_indent_lines 两空格前缀、markdown_editor_outdent_lines 无缩进返回 None、markdown_editor_insert_hard_break |
| `moui_richtext/editor_session_test.mbt` | 扩展 | 20（7 原有 + 13 新增） | MarkdownDocumentSession::new 解析块/元数据、apply 不可变性、相同 source 返回同一 session、MarkdownEditTransaction::from_sources 前后缀 diff（插入/替换/删除）、默认光标在新 source 末尾、显式 caret/selection 保留、estimated_content_height 正值、source_offset_y 单调递增、replace_source、fingerprint 跨两次解析稳定、snapshot 一致性、rich_text source_mode 单块等宽 |
| `moui_richtext/editor_source_mapping_test.mbt` | 新建 | 16 | markdown_editor_format、format_for_selection 触及标记时揭示/未触及时不揭示、format_for_writing_mode focus_mode 暗淡非活跃块/关闭时不暗淡、MarkdownEditorSnapshot::parse/parse_with_font、markdown_editor_active_selection（折叠/None/非折叠）、markdown_editor_active_block_label（heading/paragraph）、markdown_editor_preview_text（空/短/长截断）、markdown_block_to_rich_text heading 转换 |

**新增测试总计：82 个**（22 + 16 + 15 + 13 + 16）

### 原有测试（不属于本任务范围）
- `editor_session_test.mbt` 中 7 个原有测试（session 元数据、稳定 id、dirty 窗口、fence 全局上下文、layout cache、rich_text window 渲染/滚动）
- `code_highlight_test.mbt` 中 13 个测试
- `rich_text_editor_helpers.mbt` 中 2 个内联测试

### 关键技术发现
1. **缩进使用两空格**：`markdown_editor_indent_segment` 添加 `"  "`（两空格）前缀，不是 tab 字符。测试断言使用 `"  line"` 和 `caret=6`。
2. **MarkdownEditReason 不实现 Show**：该枚举仅 derive `Eq, ToJson, @debug.Debug`，无 `Show`，因此不能用 `inspect(txn.reason, ...)`。改用 `assert_true(txn.reason == CommandEdit)`。
3. **所有测试均为黑盒**：仅使用 `pkg.generated.mbti` 中确认的公共符号，未暴露任何私有符号。
4. **无场景因 API 不足跳过**：所有计划覆盖的场景均通过公共 API 实现。

## 提议变更

**无需代码变更。** 所有测试文件已就位。仅执行以下验证步骤：

### 步骤 1：类型检查
```sh
moon check moui_richtext --target native
```
预期：通过，无错误。

### 步骤 2：运行测试
```sh
moon test moui_richtext --target native
```
预期：全部通过（总计约 104 个测试，含原有 22 个 + 新增 82 个）。

### 步骤 3：格式化
```sh
moon fmt
```
预期：成功，无格式问题。

### 步骤 4（可选）：公共 API 表面检查
```sh
moon info
```
预期：`pkg.generated.mbti` 无变化（因为只新增测试文件，未改公共 API）。

## 假设与决策

1. **假设**：测试文件内容已正确编写（基于 Read 确认），所有断言使用公共 API。
2. **决策**：不修改任何源代码文件，仅运行验证命令。
3. **决策**：如验证发现失败，将根据错误信息最小修复测试断言（不暴露私有符号、不修改源码）。
4. **决策**：最终总结用中文输出（遵循 user_rules "对话使用中文"）。

## 验证步骤

执行上述步骤 1-3，确认：
- `moon check moui_richtext --target native` 无错误
- `moon test moui_richtext --target native` 全部通过
- `moon fmt` 成功

验证通过后，向用户输出中文简明总结，包含：
- 新建/扩展了哪些测试文件
- 每个文件多少个测试
- 覆盖了哪些能力
- 哪些场景因 API 不足跳过（预计：无）
- 所有验证命令结果
