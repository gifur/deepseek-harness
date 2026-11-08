---
kind: upgrade-guide
description: "DeepSeek Session Log 上传现在需要显式选择加入，不再默认发送日志。"
---

# DeepSeek Session Log 上传默认关闭

[English](guide.md) | 中文

## 变更

`session-log-deepseek.enabled` 的默认值从 `true` 改为 `false`。未设置该配置键的新旧 profile 不再向 DeepSeek 官方模型 API 请求添加 `dsh_session_log`，包括经已配置网关发送的请求。已显式保存的 `true` 或 `false` 值保持原有行为。OpenTelemetry 反馈上传是独立功能，本次不变。

## 迁移

1. 如需保持 Session Log 上传关闭，无需执行任何操作。
2. 如需继续上传，请开启**设置 → 通用 → 在使用官方模型 API 时上传 Session Log**，或将以下配置项添加到 profile 的 `cordis.patch.yml`：

   ```yaml
   - id: session-log-deepseek
     config:
       enabled: true
   ```

3. 重启 profile 后在 Web 中确认设置。开关关闭时，官方模型 API 请求正文省略 `dsh_session_log`；开关开启时，下一个请求包含尚未确认接收的 Session Log 后缀。
