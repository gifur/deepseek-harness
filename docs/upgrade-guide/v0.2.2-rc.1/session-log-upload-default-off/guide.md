---
kind: upgrade-guide
description: "DeepSeek Session-log upload now requires explicit opt-in instead of sending logs by default."
---

# DeepSeek Session-log upload defaults off

English | [中文](guide.zh.md)

## Change

The `session-log-deepseek.enabled` default changes from `true` to `false`. New and existing profiles that do not set this key no longer add `dsh_session_log` to official DeepSeek model API requests, including requests routed through a configured gateway. An explicitly saved `true` or `false` value keeps its existing behavior. OpenTelemetry feedback upload is separate and unchanged.

## Migration

1. No action is required to keep Session-log upload off.
2. To continue uploading, turn on **Settings → General → Upload Session Log when using the official model API**, or add this row to the profile's `cordis.patch.yml`:

   ```yaml
   - id: session-log-deepseek
     config:
       enabled: true
   ```

3. Confirm the setting in Web after restarting the profile. With the switch off, official model API request bodies omit `dsh_session_log`; with it on, the next request includes the unaccepted Session-log suffix.
