///|
/// 三个内置模板的项目 JSON（镜像 `fixtures/*.moblocks.json`）。
/// 磁盘副本是给人核对与 M2 项目加载器用的；此处常量让欢迎页/面板可在无文件
/// 系统权限的环境里直接加载。codec 往返测试保证两处一旦同步就一致。

///|
/// 对话机器人（AI 提案的完整同款图）：以提案 JSON 为体，套上项目信封。
fn template_chatbot_json() -> String {
  let graph_json = fake_model_completion("template").stringify()
  "{\"metadata\":{\"id\":\"chatbot\",\"name\":\"对话机器人\",\"revision\":1},\"format\":\"moblocks.project\",\"graph\":\{graph_json},\"policy\":{\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false,\"require_confirmation\":true},\"template_origin\":\"chatbot\",\"version\":1,\"viewport\":{\"x\":0.0,\"y\":0.0,\"zoom\":1.0}}"
}

///|
/// 本地文档分析助手。
fn template_doc_assistant_json() -> String {
  "{\"metadata\":{\"id\":\"doc-assistant\",\"name\":\"本地文档分析助手\",\"revision\":1},\"format\":\"moblocks.project\",\"graph\":{\"next_id\":10,\"nodes\":[{\"id\":1,\"kind\":\"AppStart\",\"title\":\"应用启动\",\"x\":60.0,\"y\":60.0,\"config\":[]},{\"id\":2,\"kind\":\"UserPrompt\",\"title\":\"用户提问\",\"x\":280.0,\"y\":60.0,\"config\":[]},{\"id\":3,\"kind\":\"ConversationMemory\",\"title\":\"会话记忆\",\"x\":500.0,\"y\":60.0,\"config\":[]},{\"id\":4,\"kind\":\"PromptTemplate\",\"title\":\"分析模板\",\"x\":720.0,\"y\":60.0,\"config\":[]},{\"id\":5,\"kind\":\"ParseJson\",\"title\":\"确认信封解析\",\"x\":940.0,\"y\":60.0,\"config\":[]},{\"id\":6,\"kind\":\"UserConfirmation\",\"title\":\"外发确认\",\"x\":1160.0,\"y\":60.0,\"config\":[]},{\"id\":7,\"kind\":\"StructuredModelCall\",\"title\":\"结构化分析\",\"x\":1380.0,\"y\":60.0,\"config\":[]},{\"id\":8,\"kind\":\"ShowTable\",\"title\":\"分析结果表\",\"x\":1600.0,\"y\":60.0,\"config\":[]},{\"id\":9,\"kind\":\"FileSelected\",\"title\":\"选择文档\",\"x\":280.0,\"y\":200.0,\"config\":[]}],\"edges\":[[1,\"flow\",2,\"trigger\"],[2,\"flow\",9,\"trigger\"],[9,\"flow\",3,\"trigger\"],[3,\"flow\",4,\"trigger\"],[4,\"flow\",5,\"trigger\"],[5,\"flow\",6,\"trigger\"],[6,\"flow\",7,\"trigger\"],[7,\"flow\",8,\"trigger\"],[2,\"prompt\",4,\"topic\"],[2,\"message\",3,\"append\"],[3,\"history\",7,\"context\"],[4,\"rendered\",5,\"text\"],[5,\"value\",6,\"action\"],[6,\"approved\",7,\"approved\"],[7,\"result\",8,\"data\"]]},\"policy\":{\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false,\"require_confirmation\":true},\"template_origin\":\"doc-assistant\",\"version\":1,\"viewport\":{\"x\":0.0,\"y\":0.0,\"zoom\":1.0}}"
}

///|
/// CSV 分析助手。
fn template_csv_assistant_json() -> String {
  "{\"metadata\":{\"id\":\"csv-assistant\",\"name\":\"CSV 分析助手\",\"revision\":1},\"format\":\"moblocks.project\",\"graph\":{\"next_id\":9,\"nodes\":[{\"id\":1,\"kind\":\"AppStart\",\"title\":\"应用启动\",\"x\":60.0,\"y\":60.0,\"config\":[]},{\"id\":2,\"kind\":\"UserPrompt\",\"title\":\"用户提问\",\"x\":280.0,\"y\":60.0,\"config\":[]},{\"id\":3,\"kind\":\"FileSelected\",\"title\":\"选择 CSV\",\"x\":500.0,\"y\":60.0,\"config\":[]},{\"id\":4,\"kind\":\"ForEach\",\"title\":\"有限遍历\",\"x\":720.0,\"y\":60.0,\"config\":[[\"limit\",\"20\"]]},{\"id\":5,\"kind\":\"StructuredModelCall\",\"title\":\"逐行结构化\",\"x\":940.0,\"y\":60.0,\"config\":[]},{\"id\":6,\"kind\":\"UserConfirmation\",\"title\":\"外发确认\",\"x\":1160.0,\"y\":60.0,\"config\":[]},{\"id\":7,\"kind\":\"ShowTable\",\"title\":\"汇总表\",\"x\":1380.0,\"y\":60.0,\"config\":[]},{\"id\":8,\"kind\":\"PromptTemplate\",\"title\":\"汇总模板\",\"x\":1380.0,\"y\":200.0,\"config\":[]}],\"edges\":[[1,\"flow\",2,\"trigger\"],[2,\"flow\",3,\"trigger\"],[3,\"flow\",4,\"trigger\"],[4,\"flow\",6,\"trigger\"],[6,\"flow\",5,\"trigger\"],[5,\"flow\",7,\"trigger\"],[2,\"prompt\",8,\"topic\"],[8,\"rendered\",5,\"prompt\"],[6,\"approved\",5,\"approved\"],[5,\"result\",7,\"data\"]]},\"policy\":{\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false,\"require_confirmation\":true},\"template_origin\":\"csv-assistant\",\"version\":1,\"viewport\":{\"x\":0.0,\"y\":0.0,\"zoom\":1.0}}"
}
