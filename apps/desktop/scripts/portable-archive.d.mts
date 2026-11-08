/** Validated paths used to create the internal Windows portable archive. */
export function resolvePortableArchive(source: string, archive: string): {
  readonly source: string
  readonly archive: string
  readonly cwd: string
  readonly entries: readonly ['.']
}

/** Archive one validated `win-unpacked` directory, replacing only its destination ZIP. */
export function createPortableArchive(source: string, archive: string): Promise<void>
