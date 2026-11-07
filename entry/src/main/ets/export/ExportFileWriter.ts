import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { formatFileStamp } from './MarkdownText';
import { EXPORT_FILE_PREFIX, expiredExports } from './ExportRetention';

/** Folder under the app sandbox that holds exported documents. */
export const EXPORT_DIR_NAME = 'exports';

/** Builds a file name from the export time, e.g. cogit-export-20261027-0845.md. */
export function buildExportFileName(timestamp: number): string {
  return `${EXPORT_FILE_PREFIX}-${formatFileStamp(timestamp)}.md`;
}

/** Writes the document into the sandbox export folder and returns its absolute path. */
export async function writeExportFile(context: common.Context, fileName: string, content: string): Promise<string> {
  const directory = `${context.filesDir}/${EXPORT_DIR_NAME}`;
  if (!fileIo.accessSync(directory)) {
    fileIo.mkdirSync(directory, true);
  }
  const filePath = `${directory}/${fileName}`;
  const file = await fileIo.open(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
    fileIo.OpenMode.TRUNC);
  try {
    await fileIo.write(file.fd, content);
  } finally {
    await fileIo.close(file);
  }
  pruneOldExports(directory, fileName);
  return filePath;
}

/** Keeps the newest exports only; file names carry a sortable timestamp. */
function pruneOldExports(directory: string, keepName: string): void {
  try {
    for (const name of expiredExports(fileIo.listFileSync(directory), keepName)) {
      try {
        fileIo.unlinkSync(`${directory}/${name}`);
      } catch (error) {
        // A file shared or pinned elsewhere may refuse deletion; keep it and move on.
      }
    }
  } catch (error) {
    // Directory listing is best-effort; the export itself already succeeded.
  }
}
