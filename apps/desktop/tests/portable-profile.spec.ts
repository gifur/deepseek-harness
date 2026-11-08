import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { load } from 'js-yaml'
import { afterEach, expect, it } from 'vitest'
import { PORTABLE_PROFILE_PATCH_FILENAME, resolvePortableProfilePatch } from '../src/portable-profile.ts'

const roots: string[] = []

afterEach(async () => {
  await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true })))
})

it('selects only the packaged portable profile marker', async () => {
  const resources = await mkdtemp(join(tmpdir(), 'dsh-portable-profile-'))
  roots.push(resources)
  expect(resolvePortableProfilePatch(resources)).toBeUndefined()
  await writeFile(join(resources, PORTABLE_PROFILE_PATCH_FILENAME), '- id: tool-web\n  disabled: true\n')
  expect(resolvePortableProfilePatch(resources)).toBe(join(resources, PORTABLE_PROFILE_PATCH_FILENAME))
})

it('keeps the portable profile free of official endpoints and web tools while allowing offline plugins', async () => {
  const resources = await mkdtemp(join(tmpdir(), 'dsh-portable-profile-'))
  roots.push(resources)
  const patchPath = join(resources, PORTABLE_PROFILE_PATCH_FILENAME)
  await mkdir(resources, { recursive: true })
  await writeFile(patchPath, await import('node:fs/promises').then(fs => fs.readFile(
    join(import.meta.dirname, '..', 'resources', PORTABLE_PROFILE_PATCH_FILENAME), 'utf8')))
  const rows = load(await import('node:fs/promises').then(fs => fs.readFile(patchPath, 'utf8'))) as Array<Record<string, unknown>>
  const disabled = new Set(rows.filter(row => row.disabled === true).map(row => row.id))
  expect([...disabled]).toEqual(expect.arrayContaining([
    'deepseek-account', 'llm-deepseek', 'llm-deepseek-account', 'session-telemetry-otel',
    'desktop-product-telemetry', 'product-analytics', 'tool-web', 'web-search-deepseek',
    'web-deepseek-api', 'web-fetch-http', 'tool-plugin-manager', 'ui-settings-plugin-inventory',
  ]))
  expect(disabled).not.toContain('web')
  expect(disabled).not.toContain('plugin-manager')
  expect(disabled).not.toContain('ui-plugin-manager')
  expect(disabled).not.toContain('plugin-inventory')
  expect(rows.find(row => row.id === 'plugin-manager')).toMatchObject({ config: { offline: true } })
  expect(rows.find(row => row.id === 'ui-plugin-manager')).toMatchObject({ config: { registryProbeEnabled: false } })
  expect(JSON.stringify(rows)).not.toMatch(/api\.deepseek\.com|DEEPSEEK_API_KEY|baseURL|models:/u)
})
