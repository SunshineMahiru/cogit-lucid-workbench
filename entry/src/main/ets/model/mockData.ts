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
  },
  {
    id: 'pr_demo_3',
    target: '八月作息',
    judgment: '八月日均睡眠达到 7 小时',
    confidence: 80,
    reason: '暑期安排相对稳定',
    settlementDate: '2026-08-15',
    status: PredictionStatus.SETTLED,
    actualResult: '达成',
    hit: true,
    version: 1,
    createdAt: 1755000000000
  },
  {
    id: 'pr_demo_4',
    target: '八月运动',
    judgment: '八月每周运动三次',
    confidence: 65,
    reason: '月初状态较好',
    settlementDate: '2026-08-28',
    status: PredictionStatus.SETTLED,
    actualResult: '未达成',
    hit: false,
    version: 1,
    createdAt: 1755100000000
  },
  {
    id: 'pr_demo_5',
    target: '九月复盘',
    judgment: '九月完成四次周复盘',
    confidence: 70,
    reason: '已固定周日晚间时段',
    settlementDate: '2026-09-10',
    status: PredictionStatus.SETTLED,
    actualResult: '完成四次',
    hit: true,
    version: 1,
    createdAt: 1757000000000
  },
  {
    id: 'pr_demo_6',
    target: '九月阅读',
    judgment: '九月读完两本书',
    confidence: 55,
    reason: '通勤时间可用',
    settlementDate: '2026-09-22',
    status: PredictionStatus.SETTLED,
    actualResult: '读完两本',
    hit: true,
    version: 1,
    createdAt: 1757100000000
  },
  {
    id: 'pr_demo_7',
    target: '十月早睡',
    judgment: '十月二十三点前入睡达到二十天',
    confidence: 75,
    reason: '已减少晚间安排',
    settlementDate: '2026-10-05',
    status: PredictionStatus.SETTLED,
    actualResult: '达成十八天',
    hit: false,
    version: 1,
    createdAt: 1759000000000
  },
  {
    id: 'pr_demo_8',
    target: '十月速记',
    judgment: '十月每天至少一条速记',
    confidence: 60,
    reason: '入口已在首页固定',
    settlementDate: '2026-10-15',
    status: PredictionStatus.SETTLED,
    actualResult: '连续十五天',
    hit: true,
    version: 1,
    createdAt: 1759100000000
  },
  {
    id: 'pr_demo_9',
    target: '十月复盘',
    judgment: '十月完成两次月复盘',
    confidence: 85,
    reason: '复盘页已可用',
    settlementDate: '2026-10-20',
    status: PredictionStatus.SETTLED,
    actualResult: '完成两次',
    hit: true,
    version: 1,
    createdAt: 1759200000000
  },
  {
    id: 'pr_demo_10',
    target: '十一月作息',
    judgment: '十一月日均睡眠达到 7 小时',
    confidence: 55,
    reason: '天气转冷，作息易波动',
    settlementDate: '2026-11-30',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    createdAt: 1761000000000
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
    date: '2026-10-21',
    sleepHours: 7.5,
    exerciseCount: 1,
    alertCount: 0,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_2',
    date: '2026-10-22',
    sleepHours: 6.8,
    exerciseCount: 0,
    alertCount: 1,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_3',
    date: '2026-10-23',
    sleepHours: 6.2,
    exerciseCount: 1,
    alertCount: 2,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_4',
    date: '2026-10-24',
    sleepHours: 7.2,
    exerciseCount: 0,
    alertCount: 0,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_5',
    date: '2026-10-25',
    sleepHours: 5.8,
    exerciseCount: 0,
    alertCount: 3,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_6',
    date: '2026-10-26',
    sleepHours: 7.0,
    exerciseCount: 1,
    alertCount: 1,
    note: '示例状态记录。'
  },
  {
    id: 'st_demo_7',
    date: '2026-10-27',
    sleepHours: 6.6,
    exerciseCount: 1,
    alertCount: 0,
    note: '示例状态记录。'
  }
];
