# fixtures

MoBlocks Studio 的离线 fixtures。MoonBit 测试环境没有同步文件读 API，因此：

- `chatbot_proposal.json`：与 `app/ai_generation.mbt` 的 `fake_model_completion()` 内嵌内容一致（proposal v2 镜像），供人工核对与 M2 项目加载器复用。
- `demo_project.moblocks.json`：与 `app/project_codec.mbt` 的 `encode_project()` 输出同格式（示例项目镜像），坐标为 AI 自动布局结果（每层 220px、行距 110px）。

两处镜像在 M2/M3 接入 services（project_store / model_provider）后改为从磁盘读取，届时将新增解码 fixture 的测试。
