import { EvidenceItem, EvidenceSource } from '../model/EvidenceItem';
import { ExperienceMaterial, MaterialKind } from '../model/ExperienceMaterial';
import { Prediction } from '../model/Prediction';
import { PredictionOutcome } from '../model/PredictionOutcome';
import { PredictionStatus } from '../model/PredictionStatus';
import { Relation } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';

/** Synthetic dashboard samples; every row is invented and carries no real record. */

const DAY_MS = 24 * 60 * 60 * 1000;
const DEMO_YEAR = 2026;
const DEMO_MONTHS: number[] = [5, 6, 7, 8, 9, 10];
const DEMO_CONFIDENCES: number[] = [35, 45, 55, 62, 72, 78, 85, 90, 95];
const DEMO_HIT_COUNTS: number[] = [1, 2, 3, 4, 4, 5, 5, 6, 6];
const DEMO_LEADS: number[] = [5, 18, 45];
const DEMO_JUDGMENTS: string[] = [
  '本月按计划完成三次复盘',
  '本周有两天在二十三点前入睡',
  '这次沟通后双方把边界写在明处',
  '本月的运动安排能维持每周两次',
  '这个方案在月底前得到确认',
  '下一次反馈会先说清事实再给评价',
  '这周留出了两个不安排事情的晚上',
  '本月的阅读计划能完成一半以上',
  '这次调整后白天的精力有回升'
];

const DEMO_RATIOS: number[] = [1.9, 1.7, 1.5, 1.2, 0.9, 0.6];
const SCENE_CHARS = 120;
const FEELING_CHARS = 60;

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function dateText(year: number, month: number, day: number): string {
  return `${year}-${pad2(month + 1)}-${pad2(day)}`;
}

function dayStart(year: number, month: number, day: number): number {
  return Date.UTC(year, month, day);
}

function repeatedText(prefix: string, chars: number): string {
  let text = prefix;
  while (text.length < chars) {
    text += prefix;
  }
  return text.slice(0, chars);
}

function buildPrediction(monthIndex: number, confidenceIndex: number): Prediction {
  const month = DEMO_MONTHS[monthIndex];
  const confidence = DEMO_CONFIDENCES[confidenceIndex];
  const hit = (monthIndex + confidenceIndex) % 6 < DEMO_HIT_COUNTS[confidenceIndex];
  const day = 10 + confidenceIndex;
  const leadDays = DEMO_LEADS[confidenceIndex % DEMO_LEADS.length];
  const id = `dm_pr_${monthIndex}_${confidenceIndex}`;
  const revised = monthIndex === 3 && (confidenceIndex === 1 || confidenceIndex === 2 ||
    confidenceIndex === 5 || confidenceIndex === 6);
  const gain = monthIndex === 3 && (confidenceIndex === 2 || confidenceIndex === 6) ?
    '新的口径把周末与工作日分开，能解释原先被平均掉的差异' : '';
  const outcome: PredictionOutcome = hit ? 'hold' : 'fail';
  return {
    id: id,
    target: '示例主题',
    judgment: DEMO_JUDGMENTS[confidenceIndex % DEMO_JUDGMENTS.length],
    confidence: confidence,
    reason: '示例理由：此前同类调整有过效果',
    settlementDate: dateText(DEMO_YEAR, month, day),
    status: PredictionStatus.SETTLED,
    actualResult: hit ? '达到预先写下的标准' : '未达到预先写下的标准',
    hit: hit,
    version: revised ? 2 : 1,
    outcome: outcome,
    revisionReason: revised ? '把判定口径写得更可核对' : '',
    invalidated: revised ? '原先的粗略口径' : '',
    preserved: revised ? '期限与主题不变' : '',
    repositioned: revised ? '判定标准改为可核对的数量' : '',
    explanatoryGain: gain,
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: dayStart(DEMO_YEAR, month, day) - leadDays * DAY_MS + 9 * 60 * 60 * 1000
  };
}

const settledPredictions: Prediction[] = [];
for (let monthIndex = 0; monthIndex < DEMO_MONTHS.length; monthIndex += 1) {
  for (let confidenceIndex = 0; confidenceIndex < DEMO_CONFIDENCES.length; confidenceIndex += 1) {
    settledPredictions.push(buildPrediction(monthIndex, confidenceIndex));
  }
}

const extraPredictions: Prediction[] = [
  {
    id: 'dm_pr_pending_1',
    target: '示例主题',
    judgment: '下个月能保持每周三次记录',
    confidence: 65,
    reason: '示例理由：入口已经固定',
    settlementDate: '2026-12-20',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    outcome: '',
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: dayStart(2026, 11, 2)
  },
  {
    id: 'dm_pr_pending_2',
    target: '示例主题',
    judgment: '这个方案会在月底前得到确认',
    confidence: 55,
    reason: '示例理由：流程已经走完一半',
    settlementDate: '2026-12-28',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    outcome: '',
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: dayStart(2026, 11, 6)
  },
  {
    id: 'dm_pr_partial_1',
    target: '示例主题',
    judgment: '这个月的调整能同时改善睡眠与精力',
    confidence: 70,
    reason: '示例理由：两项指标此前同向变化',
    settlementDate: '2026-11-25',
    status: PredictionStatus.SETTLED,
    actualResult: '睡眠改善，精力变化不明显',
    hit: null,
    version: 1,
    outcome: 'partial',
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: dayStart(2026, 11, 1)
  },
  {
    id: 'dm_pr_undecidable_1',
    target: '示例主题',
    judgment: '对方是否认可这次调整无法从现有材料判断',
    confidence: null,
    reason: '示例理由：缺少对方自己的说法',
    settlementDate: '2026-11-26',
    status: PredictionStatus.SETTLED,
    actualResult: '材料不足，无法判断',
    hit: null,
    version: 1,
    outcome: 'undecidable',
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: dayStart(2026, 11, 3)
  }
];

/** Settled and pending predictions used when no local record exists. */
export const DEMO_STATS_PREDICTIONS: Prediction[] = settledPredictions.concat(extraPredictions);

function buildMaterial(id: string, eventId: string, kind: MaterialKind, text: string,
  observedAt: number): ExperienceMaterial {
  return {
    id: id,
    eventId: eventId,
    kind: kind,
    form: 'first_person',
    text: text,
    observedAt: observedAt,
    source: 'direct',
    sourceStance: '',
    interactionSource: '',
    claimEvidence: '',
    level: SecurityLevel.LOCAL_ONLY,
    revisionOf: '',
    deleted: false,
    createdAt: observedAt + 60 * 1000
  };
}

const materials: ExperienceMaterial[] = [];
for (let monthIndex = 0; monthIndex < DEMO_MONTHS.length; monthIndex += 1) {
  const month = DEMO_MONTHS[monthIndex];
  const eventId = `dm_ev_${monthIndex}`;
  const observedAt = dayStart(DEMO_YEAR, month, 12) + 9 * 60 * 60 * 1000;
  const interpretationChars = Math.round((SCENE_CHARS + FEELING_CHARS) * DEMO_RATIOS[monthIndex]);
  materials.push(buildMaterial(`dm_mt_${monthIndex}_scene`, eventId, 'scene',
    repeatedText('现场：当时看到的动作与对话顺序。', SCENE_CHARS), observedAt));
  materials.push(buildMaterial(`dm_mt_${monthIndex}_feeling`, eventId, 'feeling',
    repeatedText('感受：身体紧了一下，随后慢慢松开。', FEELING_CHARS), observedAt + 60000));
  materials.push(buildMaterial(`dm_mt_${monthIndex}_interpretation`, eventId, 'interpretation',
    repeatedText('解释：我推断这是对节奏失去掌控后的反应。', interpretationChars), observedAt + 120000));
}

/** Scene, feeling and interpretation samples for the interpretation-ratio trend. */
export const DEMO_STATS_MATERIALS: ExperienceMaterial[] = materials;

const CORRECTION_TIME = dayStart(2026, 10, 6) + 20 * 60 * 60 * 1000;

/** Relations with four corrections, three of them answered by an own observation. */
export const DEMO_STATS_RELATIONS: Relation[] = [
  {
    id: 'dm_rl_1',
    name: '示例·甲',
    trustLevel: TrustLevel.SINCERE,
    interactionLog: [
      { timestamp: CORRECTION_TIME + DAY_MS, content: '我把当时的经过重新说了一遍。', source: 'observation' }
    ],
    rawMaterialTest: false,
    forbidAnalysis: false,
    correction: '对方说我把一次迟到理解成不重视，其实那天路上出了状况。',
    correctionAt: CORRECTION_TIME,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  },
  {
    id: 'dm_rl_2',
    name: '示例·乙',
    trustLevel: TrustLevel.FRIENDLY,
    interactionLog: [
      { timestamp: CORRECTION_TIME + 2 * DAY_MS, content: '会后把自己的理解复述给对方确认。', source: 'observation' }
    ],
    rawMaterialTest: false,
    forbidAnalysis: false,
    correction: '对方提醒我把反馈当成评价，其实只是希望把边界写清楚。',
    correctionAt: CORRECTION_TIME + 1000,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  },
  {
    id: 'dm_rl_3',
    name: '示例·丙',
    trustLevel: TrustLevel.TRANSPARENT,
    interactionLog: [
      { timestamp: CORRECTION_TIME - 2 * DAY_MS, content: '一次关于安排的对话。', source: 'observation' }
    ],
    rawMaterialTest: true,
    forbidAnalysis: false,
    correction: '对方说我的安排没有考虑到他的时间，希望下次提前说。',
    correctionAt: CORRECTION_TIME + 2000,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  },
  {
    id: 'dm_rl_4',
    name: '示例·丁',
    trustLevel: TrustLevel.SINCERE,
    interactionLog: [
      { timestamp: CORRECTION_TIME + 3 * DAY_MS, content: '把新边界写进了下一次的约定。', source: 'observation' }
    ],
    rawMaterialTest: false,
    forbidAnalysis: false,
    correction: '对方纠正了我对那次沉默的解读，说当时只是在想事情。',
    correctionAt: CORRECTION_TIME + 3000,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  },
  {
    id: 'dm_rl_5',
    name: '示例·戊',
    trustLevel: TrustLevel.FRIENDLY,
    interactionLog: [
      { timestamp: CORRECTION_TIME + 4 * DAY_MS, content: '一次普通的进度同步。', source: 'observation' }
    ],
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  }
];

const EVIDENCE_SEEDS: EvidenceSource[] = [
  'practice', 'practice', 'practice', 'practice', 'practice', 'practice',
  'practice', 'practice', 'practice', 'practice', 'practice', 'practice',
  'other_person', 'other_person', 'other_person', 'other_person',
  'body', 'body', 'body',
  'time', 'time',
  'book',
  'public'
];

const evidence: EvidenceItem[] = [];
for (let index = 0; index < EVIDENCE_SEEDS.length; index += 1) {
  evidence.push({
    id: `dm_evd_${index}`,
    targetType: 'prediction',
    targetId: `dm_pr_${index % DEMO_CONFIDENCES.length}_${index % DEMO_MONTHS.length}`,
    sourceType: EVIDENCE_SEEDS[index],
    note: '示例证据',
    effect: 'supports',
    level: SecurityLevel.LOCAL_ONLY,
    zone: 0,
    createdAt: dayStart(2026, 9, 10) + index * 60 * 60 * 1000
  });
}

/** Evidence rows skewed to practice so the distribution card has something to judge. */
export const DEMO_STATS_EVIDENCE: EvidenceItem[] = evidence;