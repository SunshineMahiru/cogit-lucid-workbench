import { fileIo } from '@kit.CoreFileKit';

/**
 * Copies a file between the sandbox and a document URI.
 * The picker hands out document URIs, and passing one straight to fileIo.copyFile
 * produces an empty file without raising, so both ends are opened first and the
 * descriptors are copied instead of the paths.
 */
export async function copyBetween(source: string, destination: string): Promise<void> {
  const from = await fileIo.open(source, fileIo.OpenMode.READ_ONLY);
  try {
    const to = await fileIo.open(destination,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.copyFile(from.fd, to.fd);
    } finally {
      await fileIo.close(to);
    }
  } finally {
    await fileIo.close(from);
  }
}
