'use strict';

const assert = require('assert');
const Module = require('module');

class FakePredicates {
  constructor(table) {
    this.table = table;
    this.filters = [];
    this.orderField = null;
    this.limit = -1;
  }

  equalTo(field, value) {
    this.filters.push({ field: field, value: value });
    return this;
  }

  orderByAsc(field) {
    this.orderField = field;
    this.orderDesc = false;
    return this;
  }

  orderByDesc(field) {
    this.orderField = field;
    this.orderDesc = true;
    return this;
  }

  limitAs(value) {
    this.limit = value;
    return this;
  }
}

class FakeResultSet {
  constructor(rows) {
    this.rows = rows;
    this.index = -1;
    this.columns = rows.length > 0 ? Object.keys(rows[0]) : [];
  }

  goToNextRow() {
    this.index += 1;
    return this.index < this.rows.length;
  }

  getColumnIndex(name) {
    const index = this.columns.indexOf(name);
    if (index < 0) {
      throw new Error(`missing column ${name}`);
    }
    return index;
  }

  getString(index) {
    const value = this.rows[this.index][this.columns[index]];
    return value === null || value === undefined ? '' : String(value);
  }

  getLong(index) {
    return Number(this.rows[this.index][this.columns[index]]);
  }

  getDouble(index) {
    return Number(this.rows[this.index][this.columns[index]]);
  }

  isColumnNull(index) {
    const value = this.rows[this.index][this.columns[index]];
    return value === null || value === undefined;
  }

  close() {
    this.rows = [];
  }
}

class FakeStore {
  constructor() {
    this.tables = new Map();
  }

  rows(table) {
    if (!this.tables.has(table)) {
      this.tables.set(table, []);
    }
    return this.tables.get(table);
  }

  async insert(table, values) {
    this.rows(table).push(Object.assign({}, values));
    return this.rows(table).length;
  }

  async query(predicates) {
    let rows = this.rows(predicates.table).slice();
    for (const filter of predicates.filters) {
      rows = rows.filter((row) => row[filter.field] === filter.value);
    }
    if (predicates.orderField !== null) {
      const field = predicates.orderField;
      const desc = predicates.orderDesc !== false;
      rows.sort((left, right) => {
        const a = left[field];
        const b = right[field];
        if (a === b) {
          return 0;
        }
        return (a < b ? -1 : 1) * (desc ? -1 : 1);
      });
    }
    if (predicates.limit >= 0) {
      rows = rows.slice(0, predicates.limit);
    }
    return new FakeResultSet(rows);
  }

  async querySql() {
    return new FakeResultSet([]);
  }

  async executeSql() {
  }

  beginTransaction() {
  }

  commit() {
  }

  rollBack() {
  }
}

const store = new FakeStore();
const fileSystem = {
  dirs: new Set(),
  files: new Map(),
  fdToPath: new Map(),
  nextFd: 1
};
const fileIo = {
  OpenMode: { CREATE: 64, READ_WRITE: 2, TRUNC: 512 },
  accessSync(path) {
    return fileSystem.dirs.has(path) || fileSystem.files.has(path);
  },
  mkdirSync(path) {
    fileSystem.dirs.add(path);
  },
  openSync(path) {
    const fd = fileSystem.nextFd;
    fileSystem.nextFd += 1;
    fileSystem.fdToPath.set(fd, path);
    if (!fileSystem.files.has(path)) {
      fileSystem.files.set(path, '');
    }
    return { fd: fd };
  },
  writeSync(fd, content) {
    fileSystem.files.set(fileSystem.fdToPath.get(fd), content);
    return content.length;
  },
  closeSync() {
  },
  async open(path, mode) {
    return fileIo.openSync(path);
  },
  async write(fd, content) {
    return fileIo.writeSync(fd, content);
  },
  async close(file) {
    fileIo.closeSync();
  }
};

const preferenceData = new Map();
let flushCount = 0;
const preferences = {
  async get(key, defValue) {
    return preferenceData.has(key) ? preferenceData.get(key) : defValue;
  },
  async put(key, value) {
    preferenceData.set(key, value);
  },
  async flush() {
    flushCount += 1;
  }
};

const fakeArkData = {
  relationalStore: {
    RdbPredicates: FakePredicates,
    SecurityLevel: { S1: 1 },
    getRdbStore: async () => store
  },
  preferences: {
    getPreferences: async () => preferences
  }
};
const fakeCoreFileKit = { fileIo: fileIo };
const fakeAssetStoreKit = {
  asset: {
    add: async () => {
    },
    query: async () => [],
    remove: async () => {
    },
    Tag: { SECRET: 'SECRET', ALIAS: 'ALIAS', ACCESSIBILITY: 'ACCESSIBILITY' },
    Accessibility: { DEVICE_UNLOCKED: 1 }
  }
};

const originalLoad = Module._load;
const fakePerformanceKit = {
  hilog: {
    debug: () => {
    },
    info: () => {
    },
    warn: () => {
    },
    error: () => {
    }
  }
};
Module._load = function (request, parent, isMain) {
  if (request === '@kit.ArkData') {
    return fakeArkData;
  }
  if (request === '@kit.PerformanceAnalysisKit') {
    return fakePerformanceKit;
  }
  if (request === '@kit.CoreFileKit') {
    return fakeCoreFileKit;
  }
  if (request === '@kit.AssetStoreKit') {
    return fakeAssetStoreKit;
  }
  if (request === '@kit.ArkTS') {
    return { util: { TextEncoder: class { encodeInto() { return { read: 0, written: 0 }; } },
      TextDecoder: { create: () => ({ decodeToString: () => '' }) } } };
  }
  return originalLoad.call(this, request, parent, isMain);
};

const {
  ExportService,
  buildExportFileName,
  countExportBundle,
  formatConfidence,
  formatExportDate,
  formatExportTime,
  formatFileStamp,
  hitLabel,
  inlineList,
  inlineText,
  isExportable,
  predictionStatusLabel,
  prepareExportBundle,
  renderExportDocument,
  securityLevelLabel,
  totalExportRecords,
  trustLevelLabel,
  writeExportFile,
  yesNoLabel
} = require('./out2/export');
const {
  DEFAULT_SETTINGS,
  LlmSpendStore,
  MAX_MONTHLY_BUDGET,
  SettingsStore,
  budgetAllows,
  defaultAppSettings,
  estimateCostYuan,
  monthKey,
  sanitizeAppSettings
} = require('./out2/settings');

let passed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed += 1;
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
}

const NOW = new Date(2026, 9, 27, 8, 5).getTime();
const EARLIER = new Date(2026, 9, 26, 21, 30).getTime();

function event(overrides) {
  return Object.assign({
    id: 'ev_1',
    title: '一次长谈',
    content: '和朋友聊了节奏。\n第二段。',
    type: '人际',
    timestamp: NOW,
    tags: ['人际', '复盘'],
    level: 'local_only',
    relatedDecisionIds: [],
    relatedRelationIds: []
  }, overrides);
}

function decision(overrides) {
  return Object.assign({
    id: 'dc_1',
    title: '调整每日节奏',
    background: '精力不足',
    options: ['A', 'B'],
    choice: 'B',
    expectedOutcome: '睡眠回升',
    timestamp: NOW,
    relatedEventIds: ['ev_1'],
    relatedRelationIds: [],
    level: 'local_only',
    reviewed: false
  }, overrides);
}

function relation(overrides) {
  return Object.assign({
    id: 'rl_1',
    name: '朋友 A',
    trustLevel: 'sincere',
    interactionLog: [{ timestamp: NOW, content: '聊了节奏' }],
    rawMaterialTest: true,
    forbidAnalysis: false,
    level: 'local_only',
    notes: '示例关系'
  }, overrides);
}

function prediction(overrides) {
  return Object.assign({
    id: 'pr_1',
    target: '本周作息',
    judgment: '日均睡眠 7 小时',
    confidence: 70,
    reason: '已调整晚间安排',
    settlementDate: '2026-10-31',
    status: 'settled',
    actualResult: '达成',
    hit: true,
    version: 1,
    root_id: 'pr_1',
    level: 'local_only',
    createdAt: NOW
  }, overrides);
}

function anchor(id, order, text) {
  return { id: id, text: text, source: '示例锚点', order: order };
}

function statusRecord(date, overrides) {
  return Object.assign({
    id: `st_${date}`,
    date: date,
    sleepHours: 7.5,
    exerciseCount: 1,
    alertCount: 0,
    note: '示例状态'
  }, overrides);
}

function bundle(overrides) {
  return Object.assign({
    events: [event()],
    decisions: [decision()],
    relations: [relation()],
    predictions: [prediction()],
    anchors: [anchor('an_1', 1, '第一条')],
    statusRecords: [statusRecord('2026-10-23')],
    reviews: [],
    exportedAt: NOW
  }, overrides);
}

function emptyBundle() {
  return {
    events: [],
    decisions: [],
    relations: [],
    predictions: [],
    anchors: [],
    statusRecords: [],
    reviews: [],
    exportedAt: NOW
  };
}

async function main() {
  await test('时间与文件名格式化', () => {
    assert.strictEqual(formatExportTime(NOW), '2026-10-27 08:05');
    assert.strictEqual(formatExportDate(NOW), '2026-10-27');
    assert.strictEqual(formatFileStamp(NOW), '20261027-0805');
    assert.strictEqual(buildExportFileName(NOW), 'cogit-export-20261027-0805.md');
  });

  await test('单行文本压缩空白并兜底', () => {
    assert.strictEqual(inlineText('  a\n b  '), 'a b');
    assert.strictEqual(inlineText('   '), '—');
    assert.strictEqual(inlineList(['a', ' ', 'b']), 'a、b');
    assert.strictEqual(inlineList([]), '—');
  });

  await test('枚举标签与数值格式化', () => {
    assert.strictEqual(securityLevelLabel('analyzable'), '可分析');
    assert.strictEqual(securityLevelLabel('local_only'), '仅本地');
    assert.strictEqual(securityLevelLabel('sealed'), '已封存');
    assert.strictEqual(trustLevelLabel('friendly'), '友善');
    assert.strictEqual(trustLevelLabel('sincere'), '真诚');
    assert.strictEqual(trustLevelLabel('transparent'), '透明');
    assert.strictEqual(predictionStatusLabel('pending'), '待结算');
    assert.strictEqual(predictionStatusLabel('settled'), '已结算');
    assert.strictEqual(hitLabel(null), '未结算');
    assert.strictEqual(hitLabel(true), '命中');
    assert.strictEqual(hitLabel(false), '未命中');
    assert.strictEqual(formatConfidence(73.6), '74%');
    assert.strictEqual(formatConfidence(-5), '0%');
    assert.strictEqual(formatConfidence(140), '100%');
    assert.strictEqual(yesNoLabel(true), '是');
    assert.strictEqual(yesNoLabel(false), '否');
  });

  await test('封存记录不进入导出', () => {
    assert.strictEqual(isExportable('local_only'), true);
    assert.strictEqual(isExportable('analyzable'), true);
    assert.strictEqual(isExportable('sealed'), false);
    const prepared = prepareExportBundle(bundle({
      events: [event({ level: 'sealed', title: '封存事件' }), event()],
      decisions: [decision({ level: 'sealed' }), decision()],
      relations: [relation({ level: 'sealed' }), relation()]
    }));
    assert.deepStrictEqual(prepared.events.map((item) => item.level), ['local_only']);
    assert.strictEqual(prepared.decisions.length, 1);
    assert.strictEqual(prepared.relations.length, 1);
  });

  await test('各分区按阅读顺序排序且不修改入参', () => {
    const input = bundle({
      events: [event({ id: 'old', timestamp: EARLIER }), event({ id: 'new', timestamp: NOW })],
      decisions: [decision({ id: 'dc_old', timestamp: EARLIER }), decision({ id: 'dc_new', timestamp: NOW })],
      predictions: [prediction({ id: 'pr_old', createdAt: EARLIER }), prediction({ id: 'pr_new', createdAt: NOW })],
      anchors: [anchor('an_2', 2, '第二条'), anchor('an_1', 1, '第一条')],
      statusRecords: [statusRecord('2026-10-23'), statusRecord('2026-10-24')]
    });
    const prepared = prepareExportBundle(input);
    assert.deepStrictEqual(prepared.events.map((item) => item.id), ['new', 'old']);
    assert.deepStrictEqual(prepared.decisions.map((item) => item.id), ['dc_new', 'dc_old']);
    assert.deepStrictEqual(prepared.predictions.map((item) => item.id), ['pr_new', 'pr_old']);
    assert.deepStrictEqual(prepared.anchors.map((item) => item.id), ['an_1', 'an_2']);
    assert.deepStrictEqual(prepared.statusRecords.map((item) => item.date), ['2026-10-24', '2026-10-23']);
    assert.deepStrictEqual(input.events.map((item) => item.id), ['old', 'new']);
  });

  await test('记录计数与总数', () => {
    const counts = countExportBundle(bundle({
      predictions: [prediction(), prediction({ id: 'pr_2' })],
      anchors: [anchor('an_1', 1, 'a'), anchor('an_2', 2, 'b')],
      statusRecords: [statusRecord('2026-10-23'), statusRecord('2026-10-24')]
    }));
    assert.deepStrictEqual(counts, {
      events: 1,
      decisions: 1,
      relations: 1,
      predictions: 2,
      anchors: 2,
      statusRecords: 2,
      reviews: 0,
      plans: 0
    });
    assert.strictEqual(totalExportRecords(counts), 9);
  });

  await test('计划关联指向封存记录时只输出占位文字', () => {
    const plan = {
      id: 'pl_1', title: '本周计划', goal: '', startDate: '2026-11-02',
      status: 'active', isPrimary: true, level: 'local_only', createdAt: NOW
    };
    const node = {
      id: 'pn_1', planId: 'pl_1', weekIndex: 1, startDate: '2026-11-02',
      endDate: '2026-11-08', status: 'open'
    };
    const links = [
      {
        id: 'lk_1', planId: 'pl_1', nodeId: 'pn_1', module: 'note',
        targetId: 'ev_sealed', label: '封存事件', createdAt: NOW
      },
      {
        id: 'lk_2', planId: 'pl_1', nodeId: 'pn_1', module: 'note',
        targetId: 'ev_1', label: '一次长谈', createdAt: NOW
      }
    ];
    const prepared = prepareExportBundle(bundle({
      events: [event({ id: 'ev_sealed', title: '封存事件', level: 'sealed' }), event()],
      plans: [{ plan: plan, nodes: [node], items: [], links: links }]
    }));
    const markdown = renderExportDocument(prepared);
    assert.ok(markdown.includes('已封存记录'));
    assert.strictEqual(markdown.includes('封存事件'), false);
    assert.ok(markdown.includes('一次长谈'));
  });

  await test('预算按字符估算并按月记账', async () => {
    assert.strictEqual(estimateCostYuan(1000, 1000), 0.004);
    assert.strictEqual(budgetAllows(1, 0.99, 0.02), false);
    assert.strictEqual(budgetAllows(1, 0.5, 0.4), true);
    assert.strictEqual(budgetAllows(0, 0, 0), false);
    assert.strictEqual(monthKey(new Date(2026, 9, 27).getTime()), '2026-10');

    preferenceData.clear();
    const now = new Date(2026, 9, 27, 12, 0).getTime();
    const store = await LlmSpendStore.open({ filesDir: '/root' });
    assert.strictEqual((await store.load(now)).spentYuan, 0);
    await store.record(1.2345, now);
    assert.strictEqual((await store.load(now)).spentYuan, 1.2345);
    assert.strictEqual(await store.canAfford(1.5, 0.3, now), false);
    assert.strictEqual(await store.canAfford(2, 0.5, now), true);
    assert.strictEqual((await store.load(new Date(2026, 10, 2).getTime())).spentYuan, 0);
  });

  await test('复盘结果写入 Markdown 并解析锚点', () => {
    const markdown = renderExportDocument(bundle({
      reviews: [{
        id: 'rv_1',
        period: 'week',
        rangeLabel: '10-21 ~ 10-27',
        facts: '本周晚睡三天',
        interpretation: '最近状态差',
        contradiction: '解释没有引用日期',
        action: '十点后不安排任务',
        anchorIds: ['an_1'],
        createdAt: NOW
      }]
    }));
    assert.ok(markdown.includes('## 复盘'));
    assert.ok(markdown.includes('### 周复盘 · 10-21 ~ 10-27'));
    assert.ok(markdown.includes('本周晚睡三天'));
    assert.ok(markdown.includes('第一条'));
    assert.ok(markdown.includes('十点后不安排任务'));
  });

  await test('文档头部列出时间、总数与密级说明', () => {
    const markdown = renderExportDocument(bundle());
    assert.ok(markdown.startsWith('# 元认知外化工作台 · 数据导出'));
    assert.ok(markdown.includes('- 导出时间：2026-10-27 08:05'));
    assert.ok(markdown.includes('- 记录总数：6（事件 1 · 决策 1 · 关系 1 · 预测 1 · 锚点 1 · 状态 1 · 复盘 0 · 计划 0）'));
    assert.ok(markdown.includes('已封存'));
    assert.ok(markdown.endsWith('\n'));
  });

  await test('六个分区按固定顺序输出', () => {
    const markdown = renderExportDocument(bundle());
    const order = ['## 事件', '## 决策', '## 关系', '## 预测', '## 价值锚点', '## 状态记录'];
    let cursor = -1;
    for (const heading of order) {
      const index = markdown.indexOf(heading);
      assert.ok(index > cursor, `${heading} 顺序错误`);
      cursor = index;
    }
  });

  await test('空数据只输出头部', () => {
    const markdown = renderExportDocument(emptyBundle());
    assert.ok(markdown.includes('- 记录总数：0'));
    assert.strictEqual(markdown.includes('## 事件'), false);
    assert.strictEqual(markdown.includes('## 状态记录'), false);
    assert.ok(markdown.endsWith('\n'));
  });

  await test('事件与决策字段完整', () => {
    const markdown = renderExportDocument(bundle());
    assert.ok(markdown.includes('### 一次长谈'));
    assert.ok(markdown.includes('- 类型：人际'));
    assert.ok(markdown.includes('- 标签：人际、复盘'));
    assert.ok(markdown.includes('- 密级：仅本地'));
    assert.ok(markdown.includes('第二段。'));
    assert.ok(markdown.includes('- 选项：A、B'));
    assert.ok(markdown.includes('- 状态：未复盘'));
  });

  await test('关系与预测字段完整，空值有兜底', () => {
    const markdown = renderExportDocument(bundle({
      relations: [relation({ interactionLog: [] })],
      predictions: [prediction({ hit: null, status: 'pending', actualResult: '' })]
    }));
    assert.ok(markdown.includes('- 信任分层：真诚'));
    assert.ok(markdown.includes('- 未加工材料测试：是'));
    assert.ok(markdown.includes('- 禁止动机分析：否'));
    assert.ok(markdown.includes('- 互动记录：—'));
    assert.ok(markdown.includes('- 命中：未结算'));
    assert.ok(markdown.includes('- 实际结果：—'));
    assert.ok(markdown.includes('- 置信度：70%'));
  });

  await test('锚点按 order 编号，状态按日期倒序', () => {
    const markdown = renderExportDocument(prepareExportBundle(bundle({
      anchors: [anchor('an_2', 2, '第二条'), anchor('an_1', 1, '第一条')],
      statusRecords: [statusRecord('2026-10-23'), statusRecord('2026-10-24')]
    })));
    assert.ok(markdown.includes('1. 第一条 —— 示例锚点'));
    assert.ok(markdown.includes('2. 第二条 —— 示例锚点'));
    const first = markdown.indexOf('- 2026-10-24');
    const second = markdown.indexOf('- 2026-10-23');
    assert.ok(first > 0 && second > first);
    assert.ok(markdown.includes('睡眠 7.5 小时'));
  });

  await test('默认设置是副本且不可被外部改写', () => {
    const settings = defaultAppSettings();
    settings.llmMonthlyBudget = 999;
    assert.strictEqual(DEFAULT_SETTINGS.llmMonthlyBudget, 30);
    assert.strictEqual(defaultAppSettings().llmMonthlyBudget, 30);
  });

  await test('设置值越界时被夹回合法范围', () => {
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmMonthlyBudget: -5 })).llmMonthlyBudget, 0);
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmMonthlyBudget: 999 })).llmMonthlyBudget, MAX_MONTHLY_BUDGET);
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmMonthlyBudget: 12.7 })).llmMonthlyBudget, 12);
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmModel: '   ' })).llmModel, DEFAULT_SETTINGS.llmModel);
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { defaultLevel: 'bogus' })).defaultLevel, 'local_only');
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmProvider: 'bogus', llmEnabled: true })).llmProvider, 'mock');
    assert.strictEqual(sanitizeAppSettings(Object.assign(defaultAppSettings(), { llmProvider: 'bogus', llmEnabled: false })).llmProvider, 'template');
  });

  await test('设置未写入时读到默认值', async () => {
    preferenceData.clear();
    const store = await SettingsStore.open({ filesDir: '/root' });
    const settings = await store.load();
    assert.deepStrictEqual(settings, DEFAULT_SETTINGS);
  });

  await test('旧版仅 llmEnabled 的设置迁移为本地模拟', async () => {
    preferenceData.clear();
    preferenceData.set('llm_enabled', true);
    const store = await SettingsStore.open({ filesDir: '/root' });
    const settings = await store.load();
    assert.strictEqual(settings.llmProvider, 'mock');
    assert.strictEqual(settings.llmEnabled, true);
  });

  await test('设置保存后能读回，并写入磁盘', async () => {
    preferenceData.clear();
    flushCount = 0;
    const store = await SettingsStore.open({ filesDir: '/root' });
    await store.save({
      llmEnabled: true,
      llmModel: '  deepseek-v4-flash ',
      llmMonthlyBudget: 999,
      defaultLevel: 'analyzable'
    });
    assert.strictEqual(flushCount, 1);
    const loaded = await store.load();
    assert.deepStrictEqual(loaded, {
      llmEnabled: true,
      llmProvider: 'mock',
      llmBaseUrl: 'http://localhost:4523/v1',
      llmApiKey: '',
      llmModel: 'deepseek-v4-flash',
      llmMonthlyBudget: MAX_MONTHLY_BUDGET,
      defaultLevel: 'analyzable'
    });
  });

  await test('非法密级保存后回落到仅本地', async () => {
    preferenceData.clear();
    const store = await SettingsStore.open({ filesDir: '/root' });
    await store.save({ llmEnabled: false, llmModel: 'x', llmMonthlyBudget: 10, defaultLevel: 'bogus' });
    assert.strictEqual((await store.load()).defaultLevel, 'local_only');
  });

  await test('导出文件写入沙箱目录', async () => {
    fileSystem.dirs.clear();
    fileSystem.files.clear();
    const path = await writeExportFile({ filesDir: '/root' }, 'demo.md', '# 标题');
    assert.strictEqual(path, '/root/exports/demo.md');
    assert.strictEqual(fileSystem.dirs.has('/root/exports'), true);
    assert.strictEqual(fileSystem.files.get('/root/exports/demo.md'), '# 标题');
  });

  await test('服务导出包含数据、跳过封存并写入文件', async () => {
    store.tables = new Map();
    fileSystem.dirs.clear();
    fileSystem.files.clear();
    store.rows('event').push(
      {
        id: 'ev_1', title: '一次长谈', content: '和朋友聊了节奏。\n第二段。', type: '人际',
        timestamp: NOW, tags: JSON.stringify(['人际']), level: 'local_only',
        related_decision_ids: JSON.stringify(['dc_1']), related_relation_ids: '[]'
      },
      {
        id: 'ev_sealed', title: '封存事件', content: '不导出', type: '情绪',
        timestamp: EARLIER, tags: '[]', level: 'sealed',
        related_decision_ids: '[]', related_relation_ids: '[]'
      }
    );
    store.rows('decision').push({
      id: 'dc_1', title: '调整每日节奏', background: '精力不足', options: JSON.stringify(['A', 'B']),
      choice: 'B', expected_outcome: '睡眠回升', timestamp: NOW, related_event_ids: JSON.stringify(['ev_1']),
      related_relation_ids: '[]', level: 'local_only', reviewed: 0
    });
    store.rows('relation').push({
      id: 'rl_1', name: '朋友 A', trust_level: 'sincere',
      interaction_log: JSON.stringify([{ timestamp: NOW, content: '聊了节奏' }]),
      raw_material_test: 1, forbid_analysis: 0, level: 'local_only', notes: '示例关系', deleted: 0
    });
    store.rows('prediction').push(
      {
        id: 'pr_1', target: '本周作息', judgment: '日均睡眠 7 小时', confidence: 70, reason: '已调整',
        settlement_date: '2026-10-31', status: 'settled', actual_result: '达成', hit: 1, version: 1,
        root_id: 'pr_1', created_at: NOW, level: 'local_only'
      },
      {
        id: 'pr_2', target: '连续速记', judgment: '七天不断', confidence: 60, reason: '成本低',
        settlement_date: '2026-10-30', status: 'pending', actual_result: '', hit: null, version: 1,
        root_id: 'pr_2', created_at: EARLIER, level: 'local_only'
      }
    );
    store.rows('anchor').push(
      { id: 'an_2', text: '第二条', source: '示例锚点', sort_order: 2, level: 'local_only' },
      { id: 'an_1', text: '第一条', source: '示例锚点', sort_order: 1, level: 'local_only' }
    );
    store.rows('status_record').push(
      { id: 'st_1', date: '2026-10-23', sleep_hours: 7.5, exercise_count: 1, alert_count: 0, note: '示例',
        level: 'local_only', deleted: 0 },
      { id: 'st_2', date: '2026-10-24', sleep_hours: 6.5, exercise_count: 0, alert_count: 1, note: '',
        level: 'local_only', deleted: 0 }
    );

    const service = await ExportService.open({ filesDir: '/root' });
    const markdown = await service.buildMarkdown(NOW);
    assert.strictEqual(markdown.includes('封存事件'), false);
    assert.ok(markdown.includes('## 事件'));
    assert.ok(markdown.includes('- 记录总数：9'));
    assert.ok(markdown.indexOf('1. 第一条') < markdown.indexOf('2. 第二条'));

    const result = await service.exportMarkdown({ filesDir: '/root' }, NOW);
    assert.strictEqual(result.fileName, 'cogit-export-20261027-0805.md');
    assert.strictEqual(result.filePath, '/root/exports/cogit-export-20261027-0805.md');
    assert.strictEqual(result.charCount, markdown.length);
    assert.strictEqual(result.counts.events, 1, 'events');
    assert.strictEqual(result.counts.predictions, 2, 'predictions');
    assert.strictEqual(fileSystem.files.get(result.filePath), markdown, 'file');

    const again = await service.exportMarkdown({ filesDir: '/root' }, NOW);
    assert.strictEqual(again.filePath, result.filePath);
    const exported = [...fileSystem.files.keys()].filter((path) => path.startsWith('/root/exports/'));
    assert.deepStrictEqual(exported, [result.filePath], 'exports');
  });

  if (failures.length > 0) {
    console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
    for (const failure of failures) {
      console.error(`  - ${failure}`);
    }
    process.exit(1);
  }
  console.log(`PASSED ${passed} / ${passed}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
