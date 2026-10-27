import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';

/** Placeholder used when a field carries no value. */
export const EMPTY_FIELD = '—';

/** Formats a timestamp as YYYY-MM-DD HH:mm in local time. */
export function formatExportTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ` +
    `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/** Formats a timestamp as YYYY-MM-DD in local time. */
export function formatExportDate(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** Formats a timestamp as YYYYMMDD-HHmm, suitable for file names. */
export function formatFileStamp(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}${pad2(date.getMonth() + 1)}${pad2(date.getDate())}-` +
    `${pad2(date.getHours())}${pad2(date.getMinutes())}`;
}

/** Collapses whitespace so a value keeps a Markdown metadata line intact. */
export function inlineText(value: string): string {
  const text = value.replace(/\s+/g, ' ').trim();
  return text.length > 0 ? text : EMPTY_FIELD;
}

/** Joins non-empty values for one metadata line. */
export function inlineList(values: string[]): string {
  const parts: string[] = [];
  for (const value of values) {
    const text = value.trim();
    if (text.length > 0) {
      parts.push(text);
    }
  }
  return parts.length > 0 ? parts.join('、') : EMPTY_FIELD;
}

/** Chinese label for a security level. */
export function securityLevelLabel(level: SecurityLevel): string {
  if (level === SecurityLevel.ANALYZABLE) {
    return '可分析';
  }
  if (level === SecurityLevel.SEALED) {
    return '已封存';
  }
  return '仅本地';
}

/** Chinese label for a trust tier. */
export function trustLevelLabel(level: TrustLevel): string {
  if (level === TrustLevel.SINCERE) {
    return '真诚';
  }
  if (level === TrustLevel.TRANSPARENT) {
    return '透明';
  }
  return '友善';
}

/** Chinese label for a prediction status. */
export function predictionStatusLabel(status: PredictionStatus): string {
  return status === PredictionStatus.SETTLED ? '已结算' : '待结算';
}

/** Chinese label for the settled hit flag. */
export function hitLabel(hit: boolean | null): string {
  if (hit === null) {
    return '未结算';
  }
  return hit ? '命中' : '未命中';
}

/** Formats a confidence value, clamped to the 0-100 range. */
export function formatConfidence(confidence: number): string {
  const value = Math.min(Math.max(Math.round(confidence), 0), 100);
  return `${value}%`;
}

/** Formats a boolean as a yes/no label. */
export function yesNoLabel(value: boolean): string {
  return value ? '是' : '否';
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
