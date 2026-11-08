/** Create the ZIP consumed by the internal Windows portable distribution. */

import { execFile } from 'node:child_process'
import { lstat, mkdir, rename, rm } from 'node:fs/promises'
import { dirname, isAbsolute, relative } from 'node:path'
import { promisify } from 'node:util'

const run = promisify(execFile)

/**
 * Resolve the archive command without including the build parent directory.
 * @param {string} source - Absolute unpacked Electron directory.
 * @param {string} archive - Absolute destination ZIP path outside `source`.
 * @returns {{ source: string, archive: string, cwd: string, entries: ['.'] }} Validated paths and root entry.
 */
export function resolvePortableArchive(source, archive) {
  if (!isAbsolute(source) || !isAbsolute(archive)) {
    throw new Error('desktop package: portable archive paths must be absolute')
  }
  const sourceName = source.replace(/[\\/]$/u, '').split(/[\\/]/u).at(-1)
  if (sourceName !== 'win-unpacked') {
    throw new Error('desktop package: portable archive source must be win-unpacked')
  }
  if (!archive.toLowerCase().endsWith('.zip')) {
    throw new Error('desktop package: portable archive must be a ZIP')
  }
  const fromSource = relative(source, archive)
  if (fromSource === '' || (!fromSource.startsWith('..') && !isAbsolute(fromSource))) {
    throw new Error('desktop package: portable archive cannot be inside the source directory')
  }
  return { source, archive, cwd: source, entries: ['.'] }
}

/**
 * Archive one validated `win-unpacked` directory, replacing only its destination ZIP.
 * @param source - Absolute unpacked Electron directory.
 * @param archive - Absolute destination ZIP path outside `source`.
 * @returns Resolves after the system tar utility writes the archive.
 */
export async function createPortableArchive(source, archive) {
  const paths = resolvePortableArchive(source, archive)
  const sourceStat = await lstat(paths.source)
  if (!sourceStat.isDirectory() || sourceStat.isSymbolicLink()) {
    throw new Error('desktop package: portable archive source must be a real directory')
  }
  await mkdir(dirname(paths.archive), { recursive: true })
  const temporary = `${paths.archive.slice(0, -4)}.${process.pid}.tmp.zip`
  const executable = process.platform === 'win32' ? 'tar.exe' : 'tar'
  try {
    await rm(temporary, { force: true })
    await run(executable, ['-a', '-c', '-f', temporary, '-C', paths.cwd, ...paths.entries], { windowsHide: true })
    await rename(temporary, paths.archive)
  } catch (error) {
    await rm(temporary, { force: true })
    throw error
  }
}

if (import.meta.main) {
  const [, , source, archive] = process.argv
  if (source === undefined || archive === undefined) {
    throw new Error('desktop package: portable archive needs a source directory and destination ZIP')
  }
  await createPortableArchive(source, archive)
}
