# Install plugins offline in the portable Desktop

English | [中文](portable-offline-plugins.zh.md)

Use this guide to move a DSH plugin from GitHub to the internal Windows portable Desktop without giving the target computer internet access. The preparation computer may access GitHub; the target computer installs only from an absolute local directory or a local `.tgz` or `.tar.gz` file.

## Before you start

The target computer needs an extracted [internal Windows portable Desktop](../../../apps/desktop/packaging/README.md#internal-windows-portable-zip). The plugin must be compatible with that DSH version and operating system.

An installable plugin root has a `package.json` that declares `dsh.bundle.patch`, the declared patch file, and every built JavaScript entry named by `main` or `exports`. Source-only TypeScript without its `lib/` output is not ready to install. A plain library without the bundle declaration is not an enableable DSH plugin.

For a reliable offline transfer, the plugin archive must contain every runtime dependency. A dependency may instead already exist in the target computer's pnpm store, but that is machine-specific and is not a portable distribution method. Ask the plugin author for an offline-ready release asset when the package has dependencies or native modules.

The portable Desktop accepts these sources:

| Source on the target computer | Can install directly | Requirement |
| --- | --- | --- |
| Absolute plugin directory | Yes | `package.json` is directly inside this directory. |
| Local `.tgz` or `.tar.gz` | Yes | It is an npm tarball containing the complete plugin. |
| GitHub Release `.tgz` or `.tar.gz` asset | Yes, after copying it to the target | Prefer an asset whose checksum the author publishes. |
| GitHub **Source code (zip)** or another `.zip` | No | Extract it, then select the actual plugin directory or create a `.tgz` on the preparation computer. |
| npm package name, Git URL, or HTTP(S) URL | No | The portable plugin manager rejects remote sources and does not fall back to a registry. |

Renaming `.zip` to `.tgz` does not convert it. The formats use different archive layouts and compression.

## Get the plugin from GitHub

Prefer a plugin author's prebuilt offline tarball under **Releases → Assets**. Download the matching version and any published SHA-256 file. Do not choose GitHub's automatically generated **Source code (zip)** when a prebuilt tarball is available.

When only source is available, open the repository's **Code** menu and choose **Download ZIP**, then extract it on the preparation computer. In a single-plugin repository, the extracted repository root may be the plugin root. In a monorepo, follow the plugin README or the repository's `package.json` `repository.directory` field to find the package subdirectory. The repository root is not installable merely because it contains plugins deeper in the tree.

Check the selected directory in PowerShell:

```powershell
$pluginRoot = 'D:\OfflinePlugins\example-plugin'
$manifest = Get-Content -Raw (Join-Path $pluginRoot 'package.json') | ConvertFrom-Json
$manifest.name
$manifest.version
$manifest.dsh.bundle.patch
Test-Path (Join-Path $pluginRoot $manifest.dsh.bundle.patch)
```

The final command must print `True`. Also confirm that the files named by `main` or `exports` exist. If the repository requires a build, follow its trusted build instructions on the preparation computer; do not expect the offline target to download build dependencies.

You may transfer the complete directory as-is. To make one npm tarball, install the repository's required build tools on the preparation computer, change to the plugin root, and run:

```powershell
pnpm pack --pack-destination D:\OfflinePlugins\transfer
```

Review the printed **Tarball Contents** before transferring the result. A successful `pnpm pack` does not prove that separately declared dependencies were embedded; the plugin author must intentionally produce an offline-ready package.

If the author publishes a checksum, verify the downloaded or packed file before moving it across the isolation boundary:

```powershell
Get-FileHash -Algorithm SHA256 D:\OfflinePlugins\transfer\example-plugin-1.0.0.tgz
```

## Reproducible GitHub example

This case uses the [`@local/my-decoration` sample plugin](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/preset/agent-preset/skills/cordis-plugin-development/templates/decoration) in the DeepSeek Harness repository. It is a minimal prebuilt bundle with no separately declared runtime dependencies.

On the preparation computer, download the repository with **Code → Download ZIP**, extract it, and select this plugin root:

```text
D:\OfflinePlugins\deepseek-harness-master\packages\preset\agent-preset\skills\cordis-plugin-development\templates\decoration
```

Run the PowerShell checks from the previous section. They report the name `@local/my-decoration`, version `1.0.0`, patch `./cordis.patch.yml`, and an existing patch file. From that directory, package it:

```powershell
pnpm pack --pack-destination D:\OfflinePlugins\transfer
```

The command creates `D:\OfflinePlugins\transfer\local-my-decoration-1.0.0.tgz`. The verified package contains `package.json`, `cordis.patch.yml`, `index.js`, `client.js`, its icon, and locale files. Installing that tarball with pnpm offline mode resolved one package, downloaded zero packages, installed version `1.0.0`, and selected its bundle. Installing the equivalent absolute directory also succeeded. Packing the same files as `.zip` failed with `ERR_PNPM_NOT_PACKAGE_DIRECTORY`, and adding an unbundled dependency made the offline install fail with `ERR_PNPM_NO_OFFLINE_META`.

This sample exists to verify the transfer and installation path. Use only plugins whose purpose and source your organization has reviewed.

## Install on the offline computer

1. Copy the plugin directory or tarball to a stable local path such as `D:\OfflinePlugins`. Do not install from removable media that will be disconnected immediately when the profile records a linked directory.
2. Start `DeepSeek Harness.exe` from the extracted portable Desktop.
3. Select **Plugins** in the sidebar, choose **Add plugin**, then choose **Install third-party plugin**.
4. Enter the absolute local directory or tarball path. For the verified case, use `D:\OfflinePlugins\transfer\local-my-decoration-1.0.0.tgz`.
5. Review the detected package name, version, and description, then choose **Install**.
6. Choose **Enable now** after installation. If the result says a restart is required, exit the Desktop completely and start it again.
7. Reopen **Plugins** and confirm that the package is listed, enabled, and free of a load error.

Keep the transferred file until the installation and restart check are complete. The plugin page cannot query GitHub or a registry for repairs or updates in the portable profile.

## Handle installation failures

**The path is not a package directory.** A `.zip` was selected, the path points one level above or below the plugin root, or `package.json` is missing. Extract the ZIP and select the directory that directly contains the plugin's `package.json`, or create a `.tgz` on the preparation computer.

**The package is not a bundle.** Its `package.json` does not declare `dsh.bundle.patch`, or the referenced patch is absent. Obtain a DSH bundle from the author; a normal npm library cannot be enabled as a plugin.

**Offline metadata or a dependency is missing.** The tarball declares a dependency that is neither embedded nor already cached on the target. Rebuild the offline package on the preparation computer with its runtime dependencies included. The portable Desktop intentionally does not contact npm to repair it.

**A built entry is missing.** A GitHub Source ZIP often contains TypeScript source but not published `lib/` files. Build and pack it on the preparation computer according to the plugin's README, or use a prebuilt Release asset.

**A lifecycle script needs approval.** Approval permits the package to execute code as the signed-in operating-system user, outside the agent sandbox. Approve only reviewed code. Approval does not provide network access or missing dependencies, so a script that expects to download files still fails offline.

**The plugin is incompatible or cannot load.** Check its `engines.dsh`, supported operating systems, built exports, and peer dependency ranges against the portable Desktop version. Remove the failed package and obtain a compatible build rather than editing its manifest on the target computer.

## Security and network scope

Installing code from a local file does not make that code trustworthy. Review the GitHub repository, pin the intended release, verify published checksums, and retain an internal copy of the exact artifact that was approved.

The portable profile prevents the plugin manager from accessing registries, Git hosts, remote tarballs, and version services. It does not sandbox an installed plugin's Host code or lifecycle scripts and does not provide process-level network isolation. Use the internal network firewall to enforce egress policy.

## Further exploration

- [Package and install a plugin](../develop/basic/publish.md) explains bundle manifests, build outputs, Git sources, and tarballs for plugin authors.
- [Plugin manager reference](../../../packages/boot/plugin-manager/README.md#use-this-package) defines offline source validation and dependency handling.
- [Portable Desktop packaging](../../../apps/desktop/packaging/README.md#internal-windows-portable-zip) defines which online capabilities the internal build disables.
