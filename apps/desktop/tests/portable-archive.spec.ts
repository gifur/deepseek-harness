import { execFile as execFileCallback } from 'node:child_process'
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { promisify } from 'node:util'
import { afterEach, expect, it } from 'vitest'
import { createPortableArchive } from '../scripts/portable-archive.mjs'

const execFile = promisify(execFileCallback)
const roots: string[] = []

afterEach(async () => {
  await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true })))
})

it('archives only the unpacked application contents and overwrites its target', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-portable-archive-'))
  roots.push(root)
  const source = join(root, 'win-unpacked')
  const archive = join(root, 'portable', 'dsh.zip')
  await mkdir(join(source, 'resources'), { recursive: true })
  await writeFile(join(root, 'outside.txt'), 'must not be archived')
  await writeFile(join(source, 'DeepSeek Harness.exe'), 'electron')
  await writeFile(join(source, 'resources', 'app.asar'), 'application')
  await mkdir(join(root, 'portable'), { recursive: true })
  await writeFile(archive, 'stale output')

  await createPortableArchive(source, archive)

  const { stdout } = await execFile(process.platform === 'win32' ? 'tar.exe' : 'tar', ['-tf', archive])
  expect(stdout.replaceAll('\\', '/')).toContain('DeepSeek Harness.exe')
  expect(stdout.replaceAll('\\', '/')).toContain('resources/app.asar')
  expect(stdout).not.toContain('outside.txt')
  await expect(readFile(archive, 'utf8')).resolves.not.toBe('stale output')
})

it('rejects a non-application source and archives placed beneath that source', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-portable-archive-'))
  roots.push(root)
  const source = join(root, 'win-unpacked')
  await mkdir(source)
  await expect(createPortableArchive(join(root, 'build'), join(root, 'out.zip'))).rejects.toThrow(/win-unpacked/u)
  await expect(createPortableArchive(source, join(source, 'out.zip'))).rejects.toThrow(/inside the source/u)
})
