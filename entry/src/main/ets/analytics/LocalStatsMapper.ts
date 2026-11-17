import { common } from '@kit.AbilityKit';
import { DbHelper } from '../db/DbHelper';
import { EvidenceItemDao } from '../db/dao/EvidenceItemDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { EvidenceItem, EvidenceSource } from '../model/EvidenceItem';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { Prediction } from '../model/Prediction';
import { isBinaryOutcome, outcomeFromLegacy, PredictionOutcome } from '../model/PredictionOutcome';
import { PredictionStatus } from '../model/PredictionStatus';
import { Relation } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { hasEnoughSamples, SAMPLE_FLOOR } from '../analysis/metrics/SampleFloor';
import { hitRatePercent } from '../analysis/metrics/Rates';
import { buildPredictionStats, PredictionStats } from '../prediction/PredictionStats';

/** One row behind the local judgement dashboard, built only from existing tables. */
export interface LocalStatsInput {
  predictions: Prediction[];
  materials: ExperienceMaterial[];
  relations: Relation[];
  evidence: EvidenceItem[];
}

/** One band of a rate, with the sample size it rests on. */
export interface StatBucket {
  label: string;
  total: number;
  hits: number;
  hitRate: number;
  /** True when total reaches SAMPLE_FLOOR. */
  enough: boolean;
  /** Midpoint of the confidence band, used as the chart x value; 0 elsewhere. */
  mid: number;
}

/** One month of binary settled predictions. */
export interface MonthlyRatePoint {
  month: string;
  label: string;
  settled: number;
  hitRate: number;
}

/** Confidence calibration over binary settled predictions. */
export interface CalibrationView {
  settled: number;
  brierScore: number;
  buckets: StatBucket[];
  verdict: string;
}

/** Confidence-band accuracy, with the density of each band kept visible. */
export interface ConfidenceView {
  buckets: StatBucket[];
  verdict: string;
}

/** Accuracy split by how far ahead the prediction was written. */
export interface HorizonView {
  buckets: StatBucket[];
  verdict: string;
}

/** Interpretation characters against scene and feeling characters, by month. */
export interface RatioPoint {
  month: string;
  label: string;
  interpretationChars: number;
  sceneFeelingChars: number;
  /** interpretationChars / max(1, sceneFeelingChars). */
  ratio: number;
}

export interface RatioView {
  points: RatioPoint[];
  verdict: string;
}

export interface EvidenceCount {
  source: EvidenceSource;
  count: number;
  percent: number;
}

export interface EvidenceView {
  rows: EvidenceCount[];
  total: number;
  verdict: string;
}

export interface CorrectionView {
  corrected: number;
  responded: number;
  pending: number;
  rate: number;
  verdict: string;
}

export interface RevisionView {
  revised: number;
  termOnly: number;
  substantive: number;
  /** termOnly / revised, 0-100. */
  rate: number;
  verdict: string;
}

/** Everything the dashboard renders, computed locally in one pass. */
export interface LocalStatsReport {
  /** True when at least one non-sealed local record exists. */
  hasRecords: boolean;
  settled: number;
  binarySettled: number;
  hitRate: number;
  months: MonthlyRatePoint[];
  calibration: CalibrationView;
  confidence: ConfidenceView;
  horizon: HorizonView;
  interpretation: RatioView;
  evidence: EvidenceView;
  correction: CorrectionView;
  revision: RevisionView;
}

const DAY_MS = 24 * 60 * 60 * 1000;
const MATERIAL_SAMPLE_LIMIT = 2000;
const CONFIDENCE_MIDS: number[] = [24.5, 59.5, 77, 92.5];
const HORIZON_LABELS: string[] = ['≤7 天', '8–30 天', '31–90 天', '>90 天'];
const EVIDENCE_ORDER: EvidenceSource[] = ['practice', 'other_person', 'body', 'time', 'book', 'public'];
const EVIDENCE_LABELS: Record<string, string> = {
  practice: '现场与行动',
  other_person: '他者叙述',
  body: '身体反馈',
  time: '长期结果',
  book: '书本理论',
  public: '公共资料'
};

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function monthKeyOf(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}`;
}

function monthLabelOf(month: string): string {
  const parts = month.split('-');
  return parts.length >= 2 ? `${Number(parts[1])}月` : month;
}

function dayNumber(dateText: string): number {
  const parts = dateText.split('-');
  if (parts.length < 3) {
    return 0;
  }
  return Math.floor(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) / DAY_MS);
}

function createdDayNumber(timestamp: number): number {
  const date = new Date(timestamp);
  return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DAY_MS);
}

/** Stored outcome, or the hit flag for records settled before outcomes existed. */
function effectiveOutcome(prediction: Prediction): PredictionOutcome {
  const stored = prediction.outcome ?? '';
  return stored.length > 0 ? stored : outcomeFromLegacy(prediction.hit);
}

/** Binary settled rows that are not sealed and whose outcome agrees with the hit flag. */
function binarySettledRows(predictions: Prediction[]): Prediction[] {
  const rows: Prediction[] = [];
  for (const prediction of predictions) {
    if (prediction.status !== PredictionStatus.SETTLED || prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    const outcome = effectiveOutcome(prediction);
    if (!isBinaryOutcome(outcome)) {
      continue;
    }
    if (prediction.hit !== (outcome === 'hold')) {
      continue;
    }
    rows.push(prediction);
  }
  return rows;
}

function toStatBucket(label: string, total: number, hits: number, mid: number): StatBucket {
  return {
    label: label,
    total: total,
    hits: hits,
    hitRate: hitRatePercent(hits, total),
    enough: hasEnoughSamples(total),
    mid: mid
  };
}

function buildCalibrationView(stats: PredictionStats): CalibrationView {
  const buckets: StatBucket[] = [];
  for (let index = 0; index < stats.calibration.buckets.length; index += 1) {
    const bucket = stats.calibration.buckets[index];
    const mid = index < CONFIDENCE_MIDS.length ? CONFIDENCE_MIDS[index] : 0;
    buckets.push(toStatBucket(bucket.label, bucket.total, bucket.hits, mid));
  }
  let weightedGap = 0;
  let samples = 0;
  for (const bucket of buckets) {
    if (bucket.total === 0) {
      continue;
    }
    weightedGap += bucket.total * (bucket.hitRate - bucket.mid);
    samples += bucket.total;
  }
  let verdict = `样本不足 ${SAMPLE_FLOOR} 条，暂不判断是否过度自信`;
  if (stats.calibration.settled >= SAMPLE_FLOOR && samples > 0) {
    const gap = weightedGap / samples;
    if (gap <= -8) {
      verdict = '高置信分档的实际命中率低于声称的信心，偏自信';
    } else if (gap >= 8) {
      verdict = '高置信分档的实际命中率高于声称的信心，偏保守';
    } else {
      verdict = '各置信分档的实际命中率与声称信心大致贴合';
    }
  }
  return {
    settled: stats.calibration.settled,
    brierScore: stats.calibration.brierScore,
    buckets: buckets,
    verdict: verdict
  };
}

function buildHorizonView(predictions: Prediction[]): HorizonView {
  const totals: number[] = [0, 0, 0, 0];
  const hits: number[] = [0, 0, 0, 0];
  for (const prediction of binarySettledRows(predictions)) {
    if (prediction.settlementDate.length < 10) {
      continue;
    }
    const days = dayNumber(prediction.settlementDate) - createdDayNumber(prediction.createdAt);
    let index = 0;
    if (days > 90) {
      index = 3;
    } else if (days > 30) {
      index = 2;
    } else if (days > 7) {
      index = 1;
    }
    totals[index] += 1;
    if (effectiveOutcome(prediction) === 'hold') {
      hits[index] += 1;
    }
  }
  const buckets: StatBucket[] = [];
  let total = 0;
  for (let index = 0; index < HORIZON_LABELS.length; index += 1) {
    buckets.push(toStatBucket(HORIZON_LABELS[index], totals[index], hits[index], 0));
    total += totals[index];
  }
  let verdict = `样本不足 ${SAMPLE_FLOOR} 条，暂不比较不同期限`;
  if (total >= SAMPLE_FLOOR) {
    const enough = buckets.filter((bucket: StatBucket) => bucket.enough);
    if (enough.length < 2) {
      verdict = '只有短期分档样本充足，暂不比较不同期限';
    } else {
      const first = enough[0];
      const last = enough[enough.length - 1];
      if (last.hitRate <= first.hitRate - 10) {
        verdict = '期限越长命中率越低，长期判断更容易失准';
      } else if (last.hitRate >= first.hitRate + 10) {
        verdict = '长期分档的命中率高于短期分档';
      } else {
        verdict = '期限长短与命中率没有明显差别';
      }
    }
  }
  return { buckets: buckets, verdict: verdict };
}

function buildQualitativeVerdict(buckets: StatBucket[]): string {
  const enough = buckets.filter((bucket: StatBucket) => bucket.enough);
  if (enough.length === 0) {
    return `各置信分档都不足 ${SAMPLE_FLOOR} 条，只保留样本量`;
  }
  const top = enough[enough.length - 1];
  const bottom = enough[0];
  if (top.hitRate <= bottom.hitRate - 10) {
    return '高置信分档没有带来更高的命中率';
  }
  if (top.hitRate >= bottom.hitRate + 10) {
    return '高置信分档的命中率明显高于低置信分档';
  }
  return '置信高低与命中率的关系不明显';
}

function buildInterpretationView(materials: ExperienceMaterial[]): RatioView {
  const months: string[] = [];
  const interpretation: number[] = [];
  const sceneFeeling: number[] = [];
  for (const material of materials) {
    if (material.level === SecurityLevel.SEALED) {
      continue;
    }
    const kind = material.kind;
    if (kind !== 'scene' && kind !== 'feeling' && kind !== 'interpretation') {
      continue;
    }
    const month = monthKeyOf(material.observedAt);
    let index = months.indexOf(month);
    if (index < 0) {
      months.push(month);
      interpretation.push(0);
      sceneFeeling.push(0);
      index = months.length - 1;
    }
    const chars = material.text.trim().length;
    if (kind === 'interpretation') {
      interpretation[index] += chars;
    } else {
      sceneFeeling[index] += chars;
    }
  }
  const allPoints: RatioPoint[] = [];
  for (let index = 0; index < months.length; index += 1) {
    if (interpretation[index] === 0 && sceneFeeling[index] === 0) {
      continue;
    }
    allPoints.push({
      month: months[index],
      label: monthLabelOf(months[index]),
      interpretationChars: interpretation[index],
      sceneFeelingChars: sceneFeeling[index],
      ratio: interpretation[index] / Math.max(1, sceneFeeling[index])
    });
  }
  allPoints.sort((left: RatioPoint, right: RatioPoint) =>
    left.month < right.month ? -1 : (left.month > right.month ? 1 : 0));
  const points = allPoints.length > 6 ? allPoints.slice(allPoints.length - 6) : allPoints;
  let verdict = '还没有现场、感受或解释材料，暂不判断解释比例';
  if (points.length > 0) {
    const latest = points[points.length - 1];
    if (points.length >= 2) {
      const first = points[0];
      if (latest.ratio <= first.ratio - 0.3) {
        verdict = '解释字数相对现场感受在下降';
      } else if (latest.ratio >= first.ratio + 0.3) {
        verdict = '解释字数相对现场感受在上升';
      } else if (latest.ratio >= 1.5) {
        verdict = '解释字数仍明显多于现场与感受';
      } else {
        verdict = '解释与现场感受大致相当';
      }
    } else if (latest.ratio >= 1.5) {
      verdict = '解释字数明显多于现场与感受';
    } else if (latest.ratio >= 1) {
      verdict = '解释与现场感受大致相当';
    } else {
      verdict = '现场与感受多于解释';
    }
  }
  return { points: points, verdict: verdict };
}

function buildEvidenceView(evidence: EvidenceItem[]): EvidenceView {
  const counts: Map<string, number> = new Map<string, number>();
  let total = 0;
  for (const item of evidence) {
    if (item.level === SecurityLevel.SEALED) {
      continue;
    }
    const current = counts.get(item.sourceType) ?? 0;
    counts.set(item.sourceType, current + 1);
    total += 1;
  }
  const rows: EvidenceCount[] = [];
  let topSource: EvidenceSource = EVIDENCE_ORDER[0];
  let topCount = 0;
  for (const source of EVIDENCE_ORDER) {
    const count = counts.get(source) ?? 0;
    rows.push({
      source: source,
      count: count,
      percent: total === 0 ? 0 : Math.round(count / total * 100)
    });
    if (count > topCount) {
      topCount = count;
      topSource = source;
    }
  }
  let verdict = '还没有证据记录，暂不判断证据来源';
  if (total > 0) {
    if (topCount / total >= 0.5) {
      verdict = `证据集中在${EVIDENCE_LABELS[topSource]}，其他来源较少`;
    } else {
      verdict = '六类证据来源分布较均衡';
    }
  }
  return { rows: rows, total: total, verdict: verdict };
}

/** A correction counts as answered once an own observation is logged after it. */
function correctionAnswered(relation: Relation): boolean {
  const text = (relation.correction ?? '').trim();
  if (text.length === 0) {
    return false;
  }
  const correctionAt = relation.correctionAt ?? 0;
  for (const log of relation.interactionLog) {
    if (log.timestamp > correctionAt && (log.source ?? 'observation') === 'observation') {
      return true;
    }
  }
  return false;
}

function buildCorrectionView(relations: Relation[]): CorrectionView {
  let corrected = 0;
  let responded = 0;
  for (const relation of relations) {
    if (relation.level === SecurityLevel.SEALED) {
      continue;
    }
    if ((relation.correction ?? '').trim().length === 0) {
      continue;
    }
    corrected += 1;
    if (correctionAnswered(relation)) {
      responded += 1;
    }
  }
  const pending = corrected - responded;
  const rate = hitRatePercent(responded, corrected);
  let verdict = '还没有他者纠正记录，暂不判断回应情况';
  if (corrected > 0) {
    if (rate >= 60) {
      verdict = '多数他者纠正已经得到回应';
    } else if (rate < 40) {
      verdict = '多数他者纠正还没有得到回应';
    } else {
      verdict = '回应与未回应各占一部分';
    }
  }
  return { corrected: corrected, responded: responded, pending: pending, rate: rate, verdict: verdict };
}

function buildRevisionView(predictions: Prediction[]): RevisionView {
  let revised = 0;
  let termOnly = 0;
  for (const prediction of predictions) {
    if (prediction.level === SecurityLevel.SEALED || prediction.version <= 1) {
      continue;
    }
    revised += 1;
    if ((prediction.explanatoryGain ?? '').trim().length === 0) {
      termOnly += 1;
    }
  }
  const substantive = revised - termOnly;
  const rate = hitRatePercent(termOnly, revised);
  let verdict = '还没有修订记录，暂不判断重建质量';
  if (revised > 0) {
    if (rate >= 50) {
      verdict = '修订多为术语增加，未形成新的解释力';
    } else {
      verdict = '多数修订带来了实质重建';
    }
  }
  return { revised: revised, termOnly: termOnly, substantive: substantive, rate: rate, verdict: verdict };
}

/** Builds the whole dashboard from one read-only snapshot. */
export function buildLocalStats(input: LocalStatsInput): LocalStatsReport {
  const stats = buildPredictionStats(input.predictions);
  const months: MonthlyRatePoint[] = [];
  for (const month of stats.months) {
    months.push({ month: month.month, label: month.label, settled: month.settled, hitRate: month.hitRate });
  }
  const calibration = buildCalibrationView(stats);
  const confidence: ConfidenceView = {
    buckets: calibration.buckets,
    verdict: buildQualitativeVerdict(calibration.buckets)
  };
  const analyzablePredictions = input.predictions.filter(
    (prediction: Prediction) => prediction.level !== SecurityLevel.SEALED);
  const analyzableRelations = input.relations.filter(
    (relation: Relation) => relation.level !== SecurityLevel.SEALED);
  const analyzableEvidence = input.evidence.filter(
    (item: EvidenceItem) => item.level !== SecurityLevel.SEALED);
  const hasRecords = analyzablePredictions.length > 0 || input.materials.length > 0 ||
    analyzableRelations.length > 0 || analyzableEvidence.length > 0;
  return {
    hasRecords: hasRecords,
    settled: stats.settled,
    binarySettled: stats.hits + stats.misses,
    hitRate: stats.hitRate,
    months: months,
    calibration: calibration,
    confidence: confidence,
    horizon: buildHorizonView(input.predictions),
    interpretation: buildInterpretationView(input.materials),
    evidence: buildEvidenceView(input.evidence),
    correction: buildCorrectionView(input.relations),
    revision: buildRevisionView(input.predictions)
  };
}

/** Reads the existing tables once and builds the report; never writes. */
export async function loadLocalStats(context: common.Context): Promise<LocalStatsReport> {
  const store = await DbHelper.init(context);
  const predictions = await new PredictionDao(store).queryAll();
  const materials = await new ExperienceMaterialDao(store).queryRecentVisible(MATERIAL_SAMPLE_LIMIT);
  const relations = await new RelationDao(store).queryAll();
  const evidence = await new EvidenceItemDao(store).queryAll();
  return buildLocalStats({
    predictions: predictions,
    materials: materials,
    relations: relations,
    evidence: evidence
  });
}