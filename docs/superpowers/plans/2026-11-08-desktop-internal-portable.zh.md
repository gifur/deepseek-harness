# Desktop 内网便携版实现计划

[English](2026-11-08-desktop-internal-portable.md) | 中文

> **面向代理式实现者：** 按任务执行本计划时，必须使用 `superpowers:executing-plans` 子技能。

**目标：** 增加未签名的 Windows x64 便携 ZIP，并提供运行时可编辑的 OpenAI 兼容模型路由，同时保持现有 Desktop profile 和发布流程不变。

**架构：** 在现有 Desktop target 脚本中加入显式便携模式，固定准备 `win-x64`，构建未签名解包应用，执行现有 smoke 检查，再归档完整目录。在 Desktop profile 初始化时仅为便携构建加载 profile overlay；默认 profile 和现有签名／未签名安装包命令不变。

**技术栈：** TypeScript、Electron Builder、Node.js、Cordis YAML profile patch、Vitest。

**设计说明：** `docs/superpowers/specs/2026-11-08-desktop-internal-portable-design.md`

## 全局约束

- 普通 Desktop 构建和 profile 的行为保持不变。
- 便携产物仅支持 Windows x64、未签名、可直接启动，并且不参与公开更新发布。
- 便携模型配置可在运行时编辑，使用 `openai-completions`；产物不包含 endpoint、模型 ID 或密钥。
- 便携组合禁用官方模型／账号路由、遥测、更新、`web_search`、`web_fetch` 和在线插件管理入口。
- Shell、PTC、MCP 和本地插件不受进程级网络隔离；出网限制由部署防火墙负责。

---

### 任务 1：通过测试固定便携调用与归档行为

**文件：**
- 修改：`apps/desktop/tests/package-target.spec.ts`
- 新建：`apps/desktop/tests/portable-archive.spec.ts`
- 修改：`apps/desktop/scripts/package-target.ts`

**接口：**
- 增加经校验的 `portable` 调用标志，使其隐含未签名目录打包并拒绝非 Windows target。
- 增加明确接收源与目标路径的归档 helper；拒绝不安全的归档条目，并且绝不归档构建父目录。

- [ ] 为 `--portable`、其隐含标志、target 拒绝条件和归档路径校验编写失败测试。
- [ ] 运行聚焦测试，确认它们因模式／helper 尚不存在而失败。
- [ ] 使用现有 target 路径和 Windows `tar.exe`／7-Zip 工具实现最小调用与归档 helper。
- [ ] 重跑聚焦测试直到通过。

### 任务 2：增加便携打包命令，并与发布流程隔离

**文件：**
- 修改：`apps/desktop/package.json`
- 修改：`package.json`
- 修改：`apps/desktop/scripts/package-target.ts`
- 修改：`apps/desktop/tests/package-target-stages.spec.ts`
- 修改：`apps/desktop/tests/desktop-publication-preflight.spec.ts`

**接口：**
- 在应用根目录增加 `package:portable`，在仓库根目录增加 `package:desktop:portable` 命令。
- 便携构建经过现有准备与 smoke 阶段，然后将 `win-unpacked` 归档到便携产物目录。
- 确保便携运行不会写入 `win-x64-release.json`、更新 YAML、blockmap 或上传计划输入。

- [ ] 为便携环境选择、目录构建参数、归档输出和不生成发布记录编写失败阶段测试。
- [ ] 运行聚焦测试并观察失败。
- [ ] 增加命令和阶段分支，不更改签名／未签名安装包分支。
- [ ] 运行聚焦测试及现有 package-target 测试。

### 任务 3：增加仅便携版使用的 profile overlay

**文件：**
- 修改：`apps/desktop/src/project-manager.ts`
- 修改：`apps/desktop/src/host-process.ts`
- 新建：`apps/desktop/src/portable-profile.ts`
- 修改：`apps/desktop/tests/development-project.spec.ts`
- 新建：`apps/desktop/tests/portable-profile.spec.ts`

**接口：**
- 仅当已打包启动器收到便携构建 marker 时选择 overlay；普通开发版与已打包 Desktop 仍使用当前 `WEB_PROFILE` bundles 和 patch 行为。
- overlay 保留 `llm-pi-ai` 模型行供运行时配置，并禁用官方／账号路由、遥测、更新、Web 工具和在线插件管理 UI／工具。

- [ ] 编写组合测试，对比普通与便携的行 ID／配置。
- [ ] 运行测试并确认便携 overlay 行为尚不存在。
- [ ] 实现类型化便携 profile patch 加载器，并经现有 Host 启动路径传入 patch 文件。
- [ ] 运行便携 profile、project-manager 和 Host startup 测试。

### 任务 4：验证 ZIP 内容并记录内网流程

**文件：**
- 新建：`apps/desktop/tests/portable-package-content.spec.ts`
- 修改：`apps/desktop/packaging/README.md`
- 修改：`apps/desktop/packaging/README.zh.md`
- 修改：`apps/desktop/README.md`
- 修改：`apps/desktop/README.zh.md`

**接口：**
- 验证归档包含 Electron 可执行文件、资源、打包运行时，且不含源码检出目录或凭据。
- 在两种语言文档中记录命令、输出位置、直接启动行为、运行时模型配置、禁用的 Web 工具和防火墙限制。

- [ ] 编写内容测试，验证可执行文件、资源完整性和密钥排除。
- [ ] 使用 fixture 归档运行测试并观察失败。
- [ ] 实现内容校验器和文档更新。
- [ ] 运行 Desktop 聚焦测试、文档配对检查和 `git diff --check`。

### 任务 5：最终验证

- [ ] 运行 Desktop 打包／profile／归档聚焦测试文件。
- [ ] 运行 `pnpm run build:artifacts`。
- [ ] 在 artifacts 构建完成后运行 `pnpm run build:check`。
- [ ] 运行相关文档检查并检查完整 diff。
- [ ] 在 Windows x64 上执行便携命令，并在干净目录中解压和启动 ZIP。
