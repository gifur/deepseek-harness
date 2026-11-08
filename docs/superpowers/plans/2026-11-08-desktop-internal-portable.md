# Desktop internal portable build Implementation Plan

English | [中文](2026-11-08-desktop-internal-portable.zh.md)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an unsigned Windows x64 portable ZIP with a runtime-editable OpenAI-compatible model route while preserving the normal Desktop profile and release pipeline.

**Architecture:** Extend the existing Desktop target script with an explicit portable mode that always prepares `win-x64`, builds an unpacked unsigned application, validates it with the existing smoke checks, and archives the complete directory. Add a portable-only profile overlay at Desktop profile initialization time; the default profile and current signed/unsigned installer commands remain unchanged.

**Tech Stack:** TypeScript, Electron Builder, Node.js filesystem/archive APIs, Cordis YAML profile patches, Vitest.

**Spec:** `docs/superpowers/specs/2026-11-08-desktop-internal-portable-design.md`

## Global Constraints

- The normal Desktop build and profile must remain behaviorally unchanged.
- Portable output is Windows x64, unsigned, direct-launchable, and not part of public updater publication.
- Portable model configuration is runtime-editable and uses `openai-completions`; no endpoint, model ID, or secret is embedded.
- Portable composition disables official model/account routes, telemetry, updates, `web_search`, `web_fetch`, and online plugin-management entry points.
- Shell, PTC, MCP, and local plugins are not process-wide network isolation; deployment firewall rules remain responsible for egress control.

---

### Task 1: Lock portable invocation and archive behavior with tests

**Files:**
- Modify: `apps/desktop/tests/package-target.spec.ts`
- Create: `apps/desktop/tests/portable-archive.spec.ts`
- Modify: `apps/desktop/scripts/package-target.ts`

**Interfaces:**
- Add a validated `portable` invocation flag that implies unsigned directory packaging and rejects non-Windows targets.
- Add a small archive helper with explicit source and destination paths; reject unsafe archive entries and never archive the parent build tree.

- [ ] Write failing tests for `--portable`, its implied flags, target rejection, and archive path validation.
- [ ] Run the focused tests and observe failures caused by the missing mode/helper.
- [ ] Implement the minimal invocation and archive helpers using existing target paths and Windows `tar.exe`/7-Zip tooling.
- [ ] Run the focused tests until they pass.

### Task 2: Add the portable package command and keep release publication separate

**Files:**
- Modify: `apps/desktop/package.json`
- Modify: `package.json`
- Modify: `apps/desktop/scripts/package-target.ts`
- Modify: `apps/desktop/tests/package-target-stages.spec.ts`
- Modify: `apps/desktop/tests/desktop-publication-preflight.spec.ts`

**Interfaces:**
- Add `package:portable` at the app root and `package:desktop:portable` at the repository root.
- Route portable builds through the existing preparation and smoke stages, then archive `win-unpacked` into a portable artifact directory.
- Ensure portable runs never write `win-x64-release.json`, update YAML, blockmaps, or upload-plan inputs.

- [ ] Write failing stage tests for portable environment selection, directory build arguments, archive output, and absent release record.
- [ ] Run the focused tests and observe failures.
- [ ] Implement the command and stage branch without changing signed/unsigned installer branches.
- [ ] Run the focused tests and the existing package-target suite.

### Task 3: Add a portable-only profile overlay

**Files:**
- Modify: `apps/desktop/src/project-manager.ts`
- Modify: `apps/desktop/src/host-process.ts`
- Create: `apps/desktop/src/portable-profile.ts`
- Modify: `apps/desktop/tests/development-project.spec.ts`
- Create: `apps/desktop/tests/portable-profile.spec.ts`

**Interfaces:**
- Select the overlay only when the packaged launcher receives the portable build marker; ordinary development and packaged Desktop launches keep the current `WEB_PROFILE` bundles and patch behavior.
- Overlay the model rows with a dormant, runtime-configurable `openai-completions` route and disable official/account rows, telemetry, update behavior, web tools, and online plugin-management UI/tools.

- [ ] Write failing composition tests that compare ordinary and portable row IDs/configuration.
- [ ] Run those tests and observe the missing portable overlay behavior.
- [ ] Implement a typed portable-profile patch loader and pass its patch file/overlay through the existing Host launch path.
- [ ] Run portable-profile, project-manager, and Host startup tests.

### Task 4: Validate packaged ZIP contents and document the internal workflow

**Files:**
- Create: `apps/desktop/tests/portable-package-content.spec.ts`
- Modify: `apps/desktop/packaging/README.md`
- Modify: `apps/desktop/packaging/README.zh.md`
- Modify: `apps/desktop/README.md`
- Modify: `apps/desktop/README.zh.md`

**Interfaces:**
- Validate that the archive contains the Electron executable, resources, bundled runtime, and no source checkout or credentials.
- Document the command, output location, direct-launch behavior, runtime model configuration, disabled web tools, and firewall limitation in both language pairs.

- [ ] Write failing content tests for executable presence, resource completeness, and secret exclusion.
- [ ] Run them against a fixture archive and observe failures.
- [ ] Implement the content validator and documentation updates.
- [ ] Run focused Desktop tests, documentation pairing checks, and `git diff --check`.

### Task 5: Run final verification

- [ ] Run the focused Desktop package/profile/archive test files.
- [ ] Run `pnpm run build:artifacts`.
- [ ] Run `pnpm run build:check` after the artifact build.
- [ ] Run the relevant documentation checks and inspect the complete diff.
- [ ] On Windows x64, run the portable command and extract/launch the produced ZIP in a clean directory.
