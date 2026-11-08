# 在便携版 Desktop 中离线安装插件

[English](portable-offline-plugins.md) | 中文

本指南说明如何把 DSH 插件从 GitHub 转移到内网 Windows 便携版 Desktop，目标电脑全程不需要访问互联网。准备电脑可以访问 GitHub；目标电脑只能从绝对本地目录或本地 `.tgz`、`.tar.gz` 文件安装。

## 开始前的要求

目标电脑需要已经解压[内网 Windows 便携版 Desktop](../../../apps/desktop/packaging/README.zh.md#internal-windows-portable-zip)。插件必须兼容该 DSH 版本和操作系统。

可安装的插件根目录应当直接包含 `package.json`，其中声明 `dsh.bundle.patch`；目录中还要有声明的 patch 文件，以及 `main` 或 `exports` 指向的全部已构建 JavaScript 入口。只有 TypeScript 源码而缺少 `lib/` 输出的目录不能直接安装。没有 bundle 声明的普通库也不能作为 DSH 插件启用。

要可靠地离线转移，插件压缩包必须携带全部运行时依赖。依赖也可以碰巧已经存在于目标电脑的 pnpm store，但这种状态因机器而异，不能作为便携分发方案。插件包含依赖或原生模块时，应当向插件作者索取离线就绪的 Release 产物。

便携版 Desktop 接受以下来源：

| 目标电脑上的来源 | 能否直接安装 | 要求 |
| --- | --- | --- |
| 插件绝对目录 | 可以 | `package.json` 直接位于该目录下。 |
| 本地 `.tgz` 或 `.tar.gz` | 可以 | 它是包含完整插件的 npm tarball。 |
| GitHub Release 的 `.tgz` 或 `.tar.gz` Asset | 复制到目标电脑后可以 | 优先使用作者同时发布校验值的文件。 |
| GitHub **Source code (zip)** 或其他 `.zip` | 不可以 | 先解压，再选择实际插件目录，或者在准备电脑上生成 `.tgz`。 |
| npm 包名、Git URL 或 HTTP(S) URL | 不可以 | 便携版插件管理器拒绝远程来源，也不会回退访问 registry。 |

把 `.zip` 重命名为 `.tgz` 不能完成转换，两者使用不同的归档布局和压缩格式。

## 从 GitHub 获取插件

优先选择插件作者在 **Releases → Assets** 中提供的预构建离线 tarball，下载匹配的版本及其公开的 SHA-256 文件。存在预构建 tarball 时，不要选择 GitHub 自动生成的 **Source code (zip)**。

只有源码时，在仓库的 **Code** 菜单中选择 **Download ZIP**，然后在准备电脑上解压。对于单插件仓库，解压后的仓库根目录可能就是插件根目录；对于 monorepo，应当按照插件 README 或仓库 `package.json` 中的 `repository.directory` 字段找到包的子目录。仓库根目录下面包含插件，并不意味着这个根目录本身可以安装。

在 PowerShell 中检查所选目录：

```powershell
$pluginRoot = 'D:\OfflinePlugins\example-plugin'
$manifest = Get-Content -Raw (Join-Path $pluginRoot 'package.json') | ConvertFrom-Json
$manifest.name
$manifest.version
$manifest.dsh.bundle.patch
Test-Path (Join-Path $pluginRoot $manifest.dsh.bundle.patch)
```

最后一条命令必须输出 `True`。同时确认 `main` 或 `exports` 指向的文件都存在。如果仓库要求构建，请在准备电脑上按照可信的构建说明完成构建；不要期望离线目标电脑下载构建依赖。

可以直接转移完整目录。要制成一个 npm tarball，请先在准备电脑上安装该仓库要求的构建工具，进入插件根目录并运行：

```powershell
pnpm pack --pack-destination D:\OfflinePlugins\transfer
```

转移前检查命令打印的 **Tarball Contents**。`pnpm pack` 成功并不代表另行声明的依赖已经被打入包中；插件作者必须有意制作离线就绪包。

如果作者提供校验值，请在跨越隔离边界转移文件前校验下载文件或打包文件：

```powershell
Get-FileHash -Algorithm SHA256 D:\OfflinePlugins\transfer\example-plugin-1.0.0.tgz
```

## 可复现的 GitHub 案例

本案例使用 DeepSeek Harness 仓库中的 [`@local/my-decoration` 示例插件](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/preset/agent-preset/skills/cordis-plugin-development/templates/decoration)。它是一个最小的预构建 bundle，没有另行声明的运行时依赖。

在准备电脑上通过 **Code → Download ZIP** 下载仓库并解压，然后选择以下插件根目录：

```text
D:\OfflinePlugins\deepseek-harness-master\packages\preset\agent-preset\skills\cordis-plugin-development\templates\decoration
```

执行上一节中的 PowerShell 检查。结果应当显示名称 `@local/my-decoration`、版本 `1.0.0`、patch `./cordis.patch.yml`，并确认 patch 文件存在。在该目录中打包：

```powershell
pnpm pack --pack-destination D:\OfflinePlugins\transfer
```

命令会生成 `D:\OfflinePlugins\transfer\local-my-decoration-1.0.0.tgz`。经过验证的包包含 `package.json`、`cordis.patch.yml`、`index.js`、`client.js`、图标和语言文件。以 pnpm 离线模式安装该 tarball 时，解析了一个包、下载了零个包，安装版本为 `1.0.0`，并选中了它的 bundle；安装等价的绝对目录也成功。把同一组文件打成 `.zip` 会以 `ERR_PNPM_NOT_PACKAGE_DIRECTORY` 失败；人为加入一个未随包携带的依赖后，离线安装会以 `ERR_PNPM_NO_OFFLINE_META` 失败。

该示例只用于验证转移和安装路径。实际使用时，只安装经过所在组织审查其用途和源码的插件。

## 在离线电脑上安装

1. 把插件目录或 tarball 复制到 `D:\OfflinePlugins` 等稳定的本地路径。profile 会记录链接目录，因此不要从安装后立即拔出的移动介质安装目录。
2. 从解压后的便携版 Desktop 中启动 `DeepSeek Harness.exe`。
3. 在侧边栏选择**插件**，依次选择**添加插件**和**安装第三方插件**。
4. 输入绝对本地目录或 tarball 路径。验证案例使用 `D:\OfflinePlugins\transfer\local-my-decoration-1.0.0.tgz`。
5. 检查识别出的包名、版本和描述，然后选择**安装**。
6. 安装后选择**立即启用**。如果结果提示需要重启，请完全退出 Desktop 后重新启动。
7. 再次打开**插件**，确认该包已经列出、开关打开，并且没有加载错误。

在完成安装和重启检查前保留转移文件。便携 profile 中的插件页面不能向 GitHub 或 registry 查询修复文件或更新。

## 处理安装失败

**该路径不是包目录。** 选择了 `.zip`，路径位于插件根目录的上一级或下一级，或者缺少 `package.json`。解压 ZIP 后选择直接包含插件 `package.json` 的目录，或者在准备电脑上生成 `.tgz`。

**该包不是 bundle。** `package.json` 没有声明 `dsh.bundle.patch`，或者引用的 patch 不存在。请向作者索取 DSH bundle；普通 npm 库不能作为插件启用。

**缺少离线元数据或依赖。** tarball 声明的依赖既没有嵌入包中，也没有缓存到目标电脑。请在准备电脑上重新制作包含运行时依赖的离线包。便携版 Desktop 不会为了修复它而访问 npm。

**缺少已构建入口。** GitHub Source ZIP 通常包含 TypeScript 源码，却不包含发布时才生成的 `lib/` 文件。请按照插件 README 在准备电脑上构建并打包，或者改用预构建 Release Asset。

**生命周期脚本需要批准。** 批准意味着允许该包以当前操作系统用户身份、在 agent 沙箱之外执行代码。只批准经过审查的代码。批准不会提供网络或缺失依赖，因此需要下载文件的脚本仍会在离线环境中失败。

**插件不兼容或无法加载。** 对照便携版 Desktop 版本检查插件的 `engines.dsh`、支持的操作系统、已构建 exports 和 peer 依赖范围。应当移除失败包并取得兼容构建，不要在目标电脑上修改其 manifest。

## 安全与网络范围

从本地文件安装代码不代表代码可信。应当审查 GitHub 仓库、固定预期 Release、核对公开校验值，并在内网保留实际获批产物的副本。

便携 profile 会阻止插件管理器访问 registry、Git 主机、远程 tarball 和版本服务，但不会隔离已安装插件的 Host 代码或生命周期脚本，也不提供进程级网络隔离。请用内网防火墙落实外连策略。

## 延伸阅读

- [打包与安装插件](../develop/basic/publish.zh.md)面向插件作者说明 bundle manifest、构建产物、Git 来源和 tarball。
- [插件管理器参考](../../../packages/boot/plugin-manager/README.zh.md#use-this-package)定义离线来源校验和依赖处理。
- [便携版 Desktop 打包](../../../apps/desktop/packaging/README.zh.md#internal-windows-portable-zip)定义内网构建禁用的在线能力。
