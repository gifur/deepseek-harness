/** Resolve the profile overlay carried only by an internal portable Desktop build. */

import { statSync } from 'node:fs'
import { isAbsolute, join } from 'node:path'

/** Resource filename used to identify a portable Desktop payload. */
export const PORTABLE_PROFILE_PATCH_FILENAME = 'portable-profile.patch.yml'

/**
 * Find the portable profile overlay in a packaged resources directory.
 * @param resourcesDirectory - Electron's packaged resources directory.
 * @returns The marker path when it is a regular file, otherwise undefined.
 */
export function resolvePortableProfilePatch(resourcesDirectory: string): string | undefined {
  if (!isAbsolute(resourcesDirectory)) return undefined
  const path = join(resourcesDirectory, PORTABLE_PROFILE_PATCH_FILENAME)
  try {
    return statSync(path).isFile() ? path : undefined
  } catch {
    return undefined
  }
}
