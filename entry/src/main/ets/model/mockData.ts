import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';
import { Event } from './Event';
import { Decision } from './Decision';
import { Relation } from './Relation';
import { Prediction } from './Prediction';
import { PredictionStatus } from './PredictionStatus';
import { Anchor } from './Anchor';
import { StatusRecord } from './StatusRecord';

/**
 * Synthetic sample data (fully sanitized).
 * For page and feature demos; contains no real names, records or anchor text.
 */

export const MOCK_EVENTS: Event[] = [
  {
    id: 'ev_demo_1',
    title: '示例事件：一次长谈',
    content: '与一位朋友就近期状态做了一次长谈，聊到了节奏与精力。',
    type: '人际',
    timestamp: 1760000000000,
    tags: ['人际', '复盘'],
    level: SecurityLevel.LOCAL_ONLY,
    relatedDecisionIds: ['dc_demo_1'],
    relatedRelationIds: ['rl_demo_1']
  }
];

export const MOCK_DECISIONS: Decision[] = [
  {
    id: 'dc_demo_1',
    title: '示例决策：调整每日节奏',
    background: '连续几天感到精力不足，想调整作息安排。',
    options: ['早起一小时', '保持现状', '减少晚间安排'],
    choice: '减少晚间安排',
    expectedOutcome: '睡眠时长回升，白天精力改善',
    timestamp: 1760000100000,
    relatedEventIds: ['ev_demo_1'],
    relatedRelationIds: [],
    level: SecurityLevel.LOCAL_ONLY,
    reviewed: false
  }
];

export const MOCK_RELATIONS: Relation[] = [
  {
    id: 'rl_demo_1',
    name: '朋友 A',
    trustLevel: TrustLevel.SINCERE,
    interactionLog: [
      { timestamp: 1760000000000, content: '一次关于近期状态的长谈。' }
    ],
    rawMaterialTest: true,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: '示例关系，用于演示信任分层。'
  },
  {
    id: 'rl_demo_2',
    name: '同事 B',
    trustLevel: TrustLevel.FRIENDLY,
    interactionLog: [
      { timestamp: 1759900000000, content: '项目协作中的一次交接。' },
      { timestamp: 1759950000000, content: '会后同步了进度。' }
    ],
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: '示例关系，仅用于演示友好层级。'
  },
  {
    id: 'rl_demo_3',
    name: '家人 C',
    trustLevel: TrustLevel.TRANSPARENT,
    interactionLog: [
      { timestamp: 1759800000000, content: '聊到最近的作息调整。' }
    ],
    rawMaterialTest: true,
    forbidAnalysis: true,
    level: SecurityLevel.LOCAL_ONLY,
    notes: '示例关系，演示「禁分析」标记。'
  }
];

export const MOCK_PREDICTIONS: Prediction[] = [
  {
    id: 'pr_demo_1',
    target: '本周作息',
    judgment: '本周日均睡眠达到 7 小时',
    confidence: 70,
    reason: '已调整晚间安排，历史同类调整有效',
    settlementDate: '2026-10-31',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    createdAt: 1760000200000
  },
  {
    id: 'pr_demo_2',
    target: '连续速记',
    judgment: '连续七天每天至少两条速记',
    confidence: 60,
    reason: '速记入口已固定，成本低',
    settlementDate: '2026-10-30',
    status: PredictionStatus.SETTLED,
    actualResult: '达成五天',
    hit: false,
    version: 1,
    createdAt: 1760000300000
  }
];

export const MOCK_ANCHORS: Anchor[] = [
  {
    id: 'an_demo_1',
    text: '先记录，再读懂自己。',
    source: '示例锚点（合成）',
    order: 1
  },
  {
    id: 'an_demo_2',
    text: '把判断写下来，让它接受检验。',
    source: '示例锚点（合成）',
    order: 2
  }
];

export const MOCK_STATUS_RECORDS: StatusRecord[] = [
  {
    id: 'st_demo_1',
    date: '2026-10-23',
    sleepHours: 7.5,
    exerciseCount: 1,
    alertCount: 0,
    note: '示例状态记录。'
  }
];
