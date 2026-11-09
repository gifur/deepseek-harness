---
name: dsh-offline-plugin-packaging
description: Use when an npm cache, downloaded package tree, or extracted release must become a self-contained DSH plugin tarball for offline Desktop or profile installation.
---

# Package DSH Plugins Offline

Use this skill when a package came from `npm install`, an npm cache export, a downloaded tarball, or a monorepo extraction and must be transferred to an offline DSH Desktop. The output is a local `.tgz`/`.tar.gz` whose package root is a DSH bundle and whose runtime dependencies are included when they are available.

## Required Workflow

1. **Find and classify the package.** If the supplied directory has no top-level `package.json`, search for candidate manifests and require exactly one candidate unless the caller supplies `-PackageRoot`. Read the manifest; do not infer package identity from the directory name. It is installable as a DSH bundle only when:
   - `dsh.bundle.patch` is present and every referenced patch file exists;
   - `main` and every local runtime path in `exports` exist as built JavaScript files;
   - `name` and `version` are present.
   A normal library or a plain Cordis plugin is not converted into a profile bundle. Stop with the missing requirement.

2. **Check dependencies.** Bundle `dependencies` and available `optionalDependencies` from nearby `node_modules` trees. Preserve each dependency's installed nested `node_modules` graph instead of flattening packages that may have incompatible versions; fail for a missing direct required dependency. Peer dependencies are supplied by DSH and must remain peers; do not copy DSH core, React, or other peer packages into the tarball merely to hide an incompatible target. Native modules require an author-provided release or a separately verified Windows-compatible artifact.

3. **Create and validate the archive.** Run the helper from the repository root:

   ```powershell
   pwsh -File .agents/skills/dsh-offline-plugin-packaging/scripts/pack-dsh-offline-plugin.ps1 `
     -SourceRoot D:\Temp\NPMDownloadCache\dsh-context `
     -PackageRoot D:\Temp\NPMDownloadCache\dsh-context\download-work\node_modules\dsh-context `
     -OutputDirectory D:\OfflinePlugins\transfer
   ```

   The helper copies a clean staging tree, adds resolved runtime packages to `bundledDependencies`, runs `npm pack --ignore-scripts`, checks the tarball for `package.json`, each bundle patch, each runtime entry, and each bundled dependency's `package.json`, and prints a SHA-256 hash. It does not modify the source tree. Treat a missing dependency, missing built entry, absent patch, or missing tarball member as a hard failure.

4. **Verify on the receiving computer.** Copy only the produced tarball (or the validated package directory) to a stable local path. Keep the tarball until installation and restart checks finish. The portable Desktop accepts absolute local directories and local `.tgz`/`.tar.gz`; it rejects package names, Git URLs, HTTP(S) URLs, and ZIP files. Its offline manager uses `pnpm add --offline`, so a dependency not in the tarball must already be in the target pnpm store; do not claim portability from an npm cache alone.

5. **Install when the current environment is DSH.** The helper detects a `dsh` executable or the repository root manifest (`@deepseek-ai/dsh-root` with a `dsh` script). Without a profile, print the tarball path and let the caller choose the profile. With `-Profile <name>`, print the exact local install command. Execute it only when the caller explicitly passes `-Install`:

   ```powershell
   pwsh -File .agents/skills/dsh-offline-plugin-packaging/scripts/pack-dsh-offline-plugin.ps1 `
     -SourceRoot D:\Temp\NPMDownloadCache\dsh-context `
     -PackageRoot D:\Temp\NPMDownloadCache\dsh-context\download-work\node_modules\dsh-context `
     -OutputDirectory D:\OfflinePlugins\transfer `
     -Profile web -Install
   ```

   For portable Desktop, use the UI's Plugins → Add plugin → Install third-party plugin flow and enter the tarball's absolute path. For a CLI profile, the equivalent is `dsh plugin --profile <name> add <absolute-tarball-path>`; use `--offline` only when that CLI accepts it and the target profile is configured for offline installs.

## Decision Table

| Finding | Action |
| --- | --- |
| No `package.json` at the selected root | Select the actual package directory or pass `-PackageRoot`. |
| No `dsh.bundle.patch` or patch file | Stop; request a DSH bundle from the author. |
| Missing `main`/`exports` build output | Stop; obtain or build a release artifact on the connected machine. |
| Missing required runtime dependency | Stop and obtain the dependency or author-provided offline package. |
| Only peer dependency is missing | Check the target DSH version; do not bundle the peer automatically. |
| Tarball lacks a checked member | Discard it and fix staging before transfer. |
| DSH is not detected | Produce and validate the tarball, but do not run installation. |

## Common Mistakes

- Passing the npm cache root instead of the directory containing the plugin's `package.json`.
- Packing the original package without `bundledDependencies`; npm then omits `node_modules` and offline pnpm reports `ERR_PNPM_NO_OFFLINE_META`.
- Treating `package-lock.json`, npm cache entries, or `offline-package.cmd` as plugin contents. They are not runtime package files.
- Copying peer dependencies into the archive and masking an incompatible DSH target.
- Renaming a ZIP to `.tgz`; ZIP and npm tarball layouts are different.
- Installing from a removable path that the profile will no longer be able to read.

## Verification Output

Report the package name/version, selected package root, tarball path, bundled runtime dependencies, SHA-256, DSH/profile detection, and whether installation was executed. If any check was skipped, state the exact reason; a successful `npm pack` alone is not evidence of offline readiness.
