# Desktop internal portable build

English | [中文](2026-11-08-desktop-internal-portable-design.zh.md)

## Goal

Add a Windows x64 unsigned portable ZIP for isolated internal deployments without changing the existing Desktop release, installer, updater, or public profile behavior.

## Runtime behavior

The portable build uses a separate Desktop profile overlay. It mounts the OpenAI-compatible `llm-pi-ai` provider, leaves its `baseURL` and model catalog editable at runtime, and does not place credentials in the artifact. It disables the official DeepSeek model and account routes, telemetry, Desktop updates, `web_search`, `web_fetch`, and online plugin-management entry points. The normal Desktop profile keeps its current composition and network behavior.

The portable profile does not promise process-wide network isolation. Shell commands, PTC code, MCP servers, and locally installed plugins remain able to open their own connections; deployment firewall policy owns that restriction.

## Artifact behavior

`package:desktop:portable` prepares the existing Windows x64 runtime, performs an unsigned directory build, runs the existing packaged-runtime verification, and archives the complete unpacked Electron directory. It does not produce a release completion record, updater metadata, public publication objects, or a signature. The ZIP is consumed by extraction and direct launch of `DeepSeek Harness.exe`.

## Configuration

The portable route is configured after launch through the existing Models settings. The user supplies an OpenAI-compatible `baseURL`, model identifier, and API key. The route uses `openai-completions`; its endpoint may be changed without rebuilding the ZIP. The portable build keeps the web tool packages out of the active composition rather than silently allowing a fallback to an official endpoint.

## Verification

Focused tests cover portable invocation parsing, archive creation and path safety, portable profile rows, normal-profile preservation, and the absence of release/update metadata. A Windows x64 packaged smoke run remains the acceptance check for direct extraction and launch.
