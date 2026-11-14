/** Helpers for readings the author could not or did not measure. */

/** The three numeric readings a status day can carry. */
export type ReadingField = 'sleep' | 'exercise' | 'alert';

const ALL_FIELDS: ReadingField[] = ['sleep', 'exercise', 'alert'];

const FIELD_LABELS: Record<string, string> = {
  sleep: '睡眠',
  exercise: '运动',
  alert: '凌晨报警'
};

/** Parses the stored comma-separated marker into known field names. */
export function unknownList(value: string): ReadingField[] {
  const fields: ReadingField[] = [];
  for (const part of value.split(',')) {
    const name = part.trim();
    for (const field of ALL_FIELDS) {
      if (name === field) {
        fields.push(field);
      }
    }
  }
  return fields;
}

/** Reports whether one reading is marked unknown. */
export function isReadingUnknown(value: string, field: ReadingField): boolean {
  return unknownList(value).indexOf(field) >= 0;
}

/** Returns the marker with one field added or removed. */
export function setReadingUnknown(value: string, field: ReadingField, unknown: boolean): string {
  const kept: ReadingField[] = unknownList(value).filter((item: ReadingField) => item !== field);
  if (unknown) {
    kept.push(field);
  }
  const ordered: string[] = [];
  for (const candidate of ALL_FIELDS) {
    if (kept.indexOf(candidate) >= 0) {
      ordered.push(candidate);
    }
  }
  return ordered.join(',');
}

/** Describes the unknown readings for the panel, or an empty string when all are known. */
export function unknownReadingText(value: string): string {
  const fields = unknownList(value);
  if (fields.length === 0) {
    return '';
  }
  const labels: string[] = [];
  for (const field of fields) {
    labels.push(FIELD_LABELS[field]);
  }
  return `${labels.join('、')}未记录`;
}

/** Returns the label of one reading field. */
export function readingFieldText(field: ReadingField): string {
  return FIELD_LABELS[field];
}
