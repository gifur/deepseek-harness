# Desktop 内网便携版

[English](2026-11-08-desktop-internal-portable-design.md) | 中文

## 目标

为隔离的内网部署增加 Windows x64 未签名便携 ZIP，不改变现有 Desktop 发布、安装包、更新器、公开 profile 的行为。

## 运行时行为

便携构建使用单独的 Desktop profile overlay。它挂载 OpenAI 兼容的 `llm-pi-ai` provider，在运行时允许编辑 `baseURL` 和模型目录，并且不在产物中放置凭据。它禁用官方 DeepSeek 模型与账号路由、遥测、Desktop 更新、`web_search`、`web_fetch` 和在线插件管理入口。普通 Desktop profile 保持当前组合与网络行为。

便携 profile 不承诺进程级网络隔离。Shell 命令、PTC 代码、MCP server 和本地安装的插件仍可自行建立连接；部署防火墙策略负责限制这些连接。

## 产物行为

`package:desktop:portable` 准备现有 Windows x64 运行时，构建未签名目录版应用，运行现有已打包运行时验证，并归档完整的 Electron 解包目录。它不会生成发布完成记录、更新器元数据、公开发布对象或签名。ZIP 解压后可直接启动 `DeepSeek Harness.exe`。

## 配置

启动后通过现有 Models 设置配置便携路由。用户提供 OpenAI 兼容的 `baseURL`、模型 ID 和 API key。该路由使用 `openai-completions`；无需重建 ZIP 即可更改 endpoint。便携构建将 Web 工具包从有效组合中禁用，不会悄悄回退到官方 endpoint。

## 验证

聚焦测试覆盖便携调用参数解析、归档创建与路径安全、便携 profile 行、普通 profile 保持不变，以及不生成发布／更新元数据。Windows x64 已打包 smoke 测试仍是直接解压与启动的验收检查。
