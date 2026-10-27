/** Draft captured before a prediction is committed. */
export interface PredictionDraft {
  target: string;
  judgment: string;
  confidence: number;
  reason: string;
  /** YYYY-MM-DD */
  settlementDate: string;
}

/** Field-level messages; empty strings mean valid. */
export interface PredictionDraftErrors {
  target: string;
  judgment: string;
  confidence: string;
  settlementDate: string;
}

export const MAX_TARGET_LENGTH = 40;
export const MAX_JUDGMENT_LENGTH = 80;
export const MAX_REASON_LENGTH = 120;

/** Validates the draft against the commit rules; dates compare as YYYY-MM-DD strings. */
export function validatePredictionDraft(draft: PredictionDraft, now: number = Date.now()): PredictionDraftErrors {
  const target = draft.target.trim();
  const judgment = draft.judgment.trim();
  const settlementDate = draft.settlementDate.trim();
  const errors: PredictionDraftErrors = {
    target: '',
    judgment: '',
    confidence: '',
    settlementDate: ''
  };

  if (target.length === 0) {
    errors.target = '请填写预测对象';
  } else if (target.length > MAX_TARGET_LENGTH) {
    errors.target = `最多 ${MAX_TARGET_LENGTH} 个字`;
  }

  if (judgment.length === 0) {
    errors.judgment = '请填写可检验的判断';
  } else if (judgment.length > MAX_JUDGMENT_LENGTH) {
    errors.judgment = `最多 ${MAX_JUDGMENT_LENGTH} 个字`;
  }

  if (!Number.isFinite(draft.confidence) || draft.confidence < 1 || draft.confidence > 100) {
    errors.confidence = '置信度需在 1–100 之间';
  }

  if (!isValidDate(settlementDate)) {
    errors.settlementDate = '日期格式应为 YYYY-MM-DD';
  } else if (settlementDate < todayDateString(now)) {
    errors.settlementDate = '结算日不能早于今天';
  }

  return errors;
}

/** True when at least one field has an error. */
export function hasPredictionErrors(errors: PredictionDraftErrors): boolean {
  return errors.target.length > 0 || errors.judgment.length > 0 ||
    errors.confidence.length > 0 || errors.settlementDate.length > 0;
}

/** Today as YYYY-MM-DD in local time. */
export function todayDateString(now: number = Date.now()): string {
  const date = new Date(now);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** Date string N days after now, used by the quick deadline chips. */
export function dateAfterDays(now: number, days: number): string {
  const date = new Date(now);
  date.setDate(date.getDate() + days);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function isValidDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const parts = value.split('-');
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
