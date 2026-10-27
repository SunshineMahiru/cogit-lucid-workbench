import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { formatFileStamp } from './MarkdownText';

/** Folder under the app sandbox that holds exported documents. */
export const EXPORT_DIR_NAME = 'exports';

/** Prefix of every exported document. */
export const EXPORT_FILE_PREFIX = 'cogit-export';

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
  const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
    fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, content);
  } finally {
    fileIo.closeSync(file);
  }
  return filePath;
}
