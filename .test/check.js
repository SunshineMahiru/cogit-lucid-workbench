'use strict';

const assert = require('assert');

const { NoteTemplateId } = require('./out2/note/NoteTemplateId');
const { DbStatus, appHealth, isDatabaseUnsupported } = require('./out2/app/AppHealth');
const { NoteFieldKey } = require('./out2/note/NoteFieldKey');
const { NOTE_TEMPLATES, findNoteTemplate } = require('./out2/note/templates');
const { formatHitRate, formatNoteCount, hitRateCaption } = require('./out2/model/HomeModel');
const {
  predictionHitText,
  predictionStatusLabel,
  predictionStatusText,
  summarizePredictions,
  toPredictionDetail,
  toPredictionListItems
} = require('./out2/prediction/PredictionListMapper');
const { rangeFor } = require('./out2/review/ReviewRange');
const { budgetAllows, estimateCostYuan, monthKey } = require('./out2/settings/LlmBudget');
const { defaultAppSettings, sanitizeAppSettings } = require('./out2/settings/AppSettings');
const { consumeJsonIssues, parseInteractionLog, parseStringArray } = require('./out2/db/SafeJson');
const {
  addDaysToDate,
  formatClock,
  formatDate,
  formatDateTime,
  formatMonthDayTime,
  isSameDay
} = require('./out2/analysis/time/DateTime');
const { hitRatePercent, buildPredictionMetrics, countReviewWindow } = require('./out2/analysis');
const {
  filterRelationItems,
  toRelationDetail,
  toRelationListItems,
  trustLevelText
} = require('./out2/relation/RelationListMapper');
const { ThresholdReadingRules } = require('./out2/analysis/status/ThresholdReadingRules');
const { parseReviewPrompts } = require('./out2/network/ReviewPrompt');
const { BasicTrustPolicy } = require('./out2/analysis/trust/BasicTrustPolicy');
const { buildPredictionStats } = require('./out2/prediction/PredictionStats');
const {
  toReviewHistoryItem,
  toReviewDetailView
} = require('./out2/review/ReviewHistory');
const {
  validatePredictionDraft,
  hasPredictionErrors,
  todayDateString,
  dateAfterDays
} = require('./out2/prediction/PredictionValidation');
const {
  buildStatusOverview,
  summarizeStatus,
  toStatusDayRows
} = require('./out2/status/StatusMapper');
const { createNoteDraft, createFreeformNoteDraft } = require('./out2/note/NoteDraftFactory');
const { mergeDraftEntries } = require('./out2/note/NoteDraftMerger');
const { readNoteEntry } = require('./out2/note/NoteDraft');
const { validateNoteDraft } = require('./out2/note/NoteValidation');
const { composeNoteContent, deriveNoteTitle, NOTE_TITLE_MAX_LENGTH } = require('./out2/note/NoteContentComposer');
const { buildDecisionFromNote, splitDecisionOptions } = require('./out2/note/NoteDecisionComposer');
const { toNoteListItem, toNoteListItems, formatNoteTime, NOTE_SUMMARY_MAX_LENGTH } = require('./out2/note/NoteListMapper');
const { securityLevelText } = require('./out2/note/NoteDetail');
const { planLegacyPredictionMerges } = require('./out2/prediction/PredictionLegacyMigration');
const { mergeWeeklyDraft } = require('./out2/review/ReviewDraftMerge');

let passed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed += 1;
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
}

function relation(overrides) {
  return Object.assign({
    id: 'rl_1',
    name: '朋友 A',
    trustLevel: 'sincere',
    interactionLog: [],
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: 'local_only',
    notes: ''
  }, overrides);
}

function prediction(overrides) {
  return Object.assign({
    id: 'pr_1',
    target: '本周作息',
    judgment: '日均睡眠 7 小时',
    confidence: 70,
    reason: '已调整',
    settlementDate: '2026-11-01',
    status: 'pending',
    actualResult: '',
    hit: null,
    version: 1,
    createdAt: 1
  }, overrides);
}

function fill(draft, key, value) {
  for (const entry of draft.entries) {
    if (entry.key === key) {
      entry.value = value;
      return;
    }
  }
  throw new Error(`missing entry ${key}`);
}

function event(overrides) {
  return Object.assign(
    {
      id: 'ev_test_1',
      title: '标题',
      content: '内容',
      type: '情绪',
      timestamp: Date.now(),
      tags: ['情绪'],
      level: 'local_only',
      relatedDecisionIds: [],
      relatedRelationIds: []
    },
    overrides
  );
}

test('四类模板按顺序注册', () => {
  assert.strictEqual(NOTE_TEMPLATES.length, 4);
  assert.deepStrictEqual(
    NOTE_TEMPLATES.map((template) => template.id),
    [NoteTemplateId.DECISION, NoteTemplateId.INTERPERSONAL, NoteTemplateId.EMOTION, NoteTemplateId.BODY]
  );
  assert.deepStrictEqual(
    NOTE_TEMPLATES.map((template) => template.label),
    ['决策', '人际', '情绪', '身体']
  );
});

test('每个模板都有字段、必填项与默认标签', () => {
  for (const template of NOTE_TEMPLATES) {
    assert.ok(template.fields.length > 0, `${template.id} has no fields`);
    assert.ok(template.fields.some((field) => field.required), `${template.id} has no required field`);
    assert.ok(template.defaultTags.length > 0, `${template.id} has no default tag`);
    assert.ok(template.hint.length > 0, `${template.id} has no hint`);
  }
});

test('只有决策模板会额外生成决策实体', () => {
  assert.strictEqual(findNoteTemplate(NoteTemplateId.DECISION).createsDecision, true);
  for (const id of [NoteTemplateId.INTERPERSONAL, NoteTemplateId.EMOTION, NoteTemplateId.BODY]) {
    assert.strictEqual(findNoteTemplate(id).createsDecision, false);
  }
});

test('未知模板 id 直接抛错', () => {
  assert.throws(() => findNoteTemplate('missing'), /Unknown note template/);
});

test('决策草稿按模板字段初始化', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  assert.strictEqual(draft.templateId, NoteTemplateId.DECISION);
  assert.strictEqual(draft.entries.length, 4);
  assert.deepStrictEqual(draft.entries.map((entry) => entry.key), [
    NoteFieldKey.BACKGROUND,
    NoteFieldKey.OPTIONS,
    NoteFieldKey.CHOICE,
    NoteFieldKey.EXPECTED_OUTCOME
  ]);
  assert.ok(draft.entries.every((entry) => entry.value === ''));
  assert.deepStrictEqual(draft.tags, ['决策']);
  assert.strictEqual(draft.level, 'local_only');
  assert.ok(draft.timestamp > 0);
});

test('自由速记草稿没有模板字段', () => {
  const draft = createFreeformNoteDraft();
  assert.strictEqual(draft.templateId, null);
  assert.deepStrictEqual(draft.entries, []);
  assert.deepStrictEqual(draft.tags, []);
  assert.strictEqual(createNoteDraft(null).templateId, null);
});

test('读不到的回答返回空串', () => {
  const draft = createNoteDraft(NoteTemplateId.EMOTION);
  assert.strictEqual(readNoteEntry(draft, NoteFieldKey.EMOTION), '');
  assert.strictEqual(readNoteEntry(createFreeformNoteDraft(), NoteFieldKey.TRIGGER), '');
});

test('空决策草稿只报必填项错误', () => {
  const result = validateNoteDraft(createNoteDraft(NoteTemplateId.DECISION));
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.errors.length, 1);
  assert.strictEqual(result.errors[0].key, NoteFieldKey.BACKGROUND);
  assert.strictEqual(result.errors[0].message, '背景不能为空');
});

test('填了背景即可保存决策草稿', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '最近精力不足');
  assert.deepStrictEqual(validateNoteDraft(draft), { valid: true, errors: [] });
});

test('情绪草稿缺触发时报错，填了触发即可', () => {
  const draft = createNoteDraft(NoteTemplateId.EMOTION);
  assert.strictEqual(validateNoteDraft(draft).errors[0].key, NoteFieldKey.TRIGGER);
  fill(draft, NoteFieldKey.TRIGGER, '临时改期');
  assert.strictEqual(validateNoteDraft(draft).valid, true);
});

test('自由速记必须有正文', () => {
  const draft = createFreeformNoteDraft();
  assert.strictEqual(validateNoteDraft(draft).errors[0].message, '内容不能为空');
  draft.content = '  ';
  assert.strictEqual(validateNoteDraft(draft).valid, false);
  draft.content = '随手记一条';
  assert.strictEqual(validateNoteDraft(draft).valid, true);
});

test('正文按字段标签拼接并跳过空项', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '连续几天精力不足');
  fill(draft, NoteFieldKey.OPTIONS, '早起\n减少晚间安排');
  draft.content = '先记一笔';
  const content = composeNoteContent(draft);
  assert.strictEqual(
    content,
    '先记一笔\n背景：连续几天精力不足\n选项：早起\n减少晚间安排'
  );
  assert.strictEqual(composeNoteContent(createFreeformNoteDraft()), '');
});

test('标题优先取显式标题', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '背景内容');
  draft.title = '  自定义标题  ';
  assert.strictEqual(deriveNoteTitle(draft), '自定义标题');
});

test('标题取自正文首行', () => {
  const draft = createFreeformNoteDraft();
  draft.content = '\n  第一行内容  \n第二行';
  assert.strictEqual(deriveNoteTitle(draft), '第一行内容');
});

test('正文为空时标题取首个回答', () => {
  const draft = createNoteDraft(NoteTemplateId.INTERPERSONAL);
  fill(draft, NoteFieldKey.INTERACTION, '和朋友聊了近期节奏');
  assert.strictEqual(deriveNoteTitle(draft), '和朋友聊了近期节奏');
});

test('超长标题截断并加省略号', () => {
  const draft = createFreeformNoteDraft();
  draft.content = '一'.repeat(NOTE_TITLE_MAX_LENGTH + 10);
  const title = deriveNoteTitle(draft);
  assert.strictEqual(title.length, NOTE_TITLE_MAX_LENGTH + 1);
  assert.ok(title.endsWith('…'));
});

test('完全空白的草稿有兜底标题', () => {
  assert.strictEqual(deriveNoteTitle(createFreeformNoteDraft()), '未命名速记');
});

test('选项按行、顿号、逗号拆分并去重', () => {
  assert.deepStrictEqual(splitDecisionOptions('早起\n减少晚间安排、早起，保持现状'), [
    '早起',
    '减少晚间安排',
    '保持现状'
  ]);
  assert.deepStrictEqual(splitDecisionOptions('   \n  '), []);
  assert.deepStrictEqual(splitDecisionOptions('只有一个'), ['只有一个']);
});

test('决策草稿生成关联的决策实体', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '精力不足');
  fill(draft, NoteFieldKey.OPTIONS, '早起\n减少晚间安排');
  fill(draft, NoteFieldKey.CHOICE, '减少晚间安排');
  fill(draft, NoteFieldKey.EXPECTED_OUTCOME, '睡眠回升');
  const decision = buildDecisionFromNote(draft, 'ev_1');
  assert.ok(decision !== null);
  assert.strictEqual(decision.background, '精力不足');
  assert.deepStrictEqual(decision.options, ['早起', '减少晚间安排']);
  assert.strictEqual(decision.choice, '减少晚间安排');
  assert.strictEqual(decision.expectedOutcome, '睡眠回升');
  assert.deepStrictEqual(decision.relatedEventIds, ['ev_1']);
  assert.strictEqual(decision.level, 'local_only');
  assert.strictEqual(decision.reviewed, false);
  assert.strictEqual(decision.timestamp, draft.timestamp);
  assert.ok(decision.id.length > 0);
});

test('非决策模板不生成决策实体', () => {
  assert.strictEqual(buildDecisionFromNote(createNoteDraft(NoteTemplateId.EMOTION), 'ev_1'), null);
  assert.strictEqual(buildDecisionFromNote(createFreeformNoteDraft(), 'ev_1'), null);
});

test('列表时间：当天只显示时分，跨天带日期', () => {
  const sameDay = new Date(2026, 9, 26, 9, 5).getTime();
  const now = new Date(2026, 9, 26, 20, 0).getTime();
  assert.strictEqual(formatNoteTime(sameDay, now), '09:05');
  const earlier = new Date(2026, 9, 25, 9, 5).getTime();
  assert.strictEqual(formatNoteTime(earlier, now), '10-25 09:05');
  const lastYear = new Date(2025, 0, 3, 18, 30).getTime();
  assert.strictEqual(formatNoteTime(lastYear, now), '01-03 18:30');
});

test('日期时间模块：同日与跨日的时钟文本', () => {
  const sameDay = new Date(2026, 9, 26, 9, 5).getTime();
  const now = new Date(2026, 9, 26, 20, 0).getTime();
  const earlier = new Date(2026, 9, 25, 9, 5).getTime();
  assert.strictEqual(formatClock(sameDay), '09:05');
  assert.strictEqual(formatMonthDayTime(sameDay), '10-26 09:05');
  assert.strictEqual(formatMonthDayTime(earlier), '10-25 09:05');
  assert.strictEqual(isSameDay(sameDay, now), true);
  assert.strictEqual(isSameDay(earlier, now), false);
});

test('日期时间模块：YYYY-MM-DD 与 YYYY-MM-DD HH:mm', () => {
  const timestamp = new Date(2026, 0, 3, 8, 7).getTime();
  assert.strictEqual(formatDate(timestamp), '2026-01-03');
  assert.strictEqual(formatDateTime(timestamp), '2026-01-03 08:07');
});

test('日期时间模块：加天数跨越月末', () => {
  const now = new Date(2026, 0, 28, 12, 0).getTime();
  assert.strictEqual(addDaysToDate(now, 7), '2026-02-04');
  assert.strictEqual(addDaysToDate(now, 0), '2026-01-28');
});

test('命中率百分比：零样本为 0，其余四舍五入', () => {
  assert.strictEqual(hitRatePercent(0, 0), 0);
  assert.strictEqual(hitRatePercent(1, 3), 33);
  assert.strictEqual(hitRatePercent(2, 3), 67);
  assert.strictEqual(buildPredictionMetrics([], 6).hitRate, 0);
});

test('预测聚合：月度分组与未知月份', () => {
  const metrics = buildPredictionMetrics([
    { confidence: 70, hit: true, month: '2026-09' },
    { confidence: 60, hit: false, month: '2026-09' },
    { confidence: 80, hit: true, month: '2026-10' },
    { confidence: 50, hit: true, month: '未知' }
  ], 6);
  assert.strictEqual(metrics.settled, 4);
  assert.strictEqual(metrics.hits, 3);
  assert.strictEqual(metrics.misses, 1);
  assert.strictEqual(metrics.hitRate, 75);
  assert.deepStrictEqual(metrics.months.map((month) => month.month), ['2026-09', '2026-10', '未知']);
  assert.deepStrictEqual(metrics.months[0], { month: '2026-09', settled: 2, hits: 1, hitRate: 50 });
});

test('预测聚合：monthLimit 保留最近的月份', () => {
  const samples = [];
  for (let index = 1; index <= 6; index += 1) {
    samples.push({ confidence: 60, hit: true, month: `2026-0${index}` });
  }
  const metrics = buildPredictionMetrics(samples, 3);
  assert.deepStrictEqual(metrics.months.map((month) => month.month), ['2026-04', '2026-05', '2026-06']);
  assert.strictEqual(metrics.settled, 6);
  assert.strictEqual(metrics.hitRate, 100);
});

test('预测聚合：校准结果沿用置信度分档', () => {
  const metrics = buildPredictionMetrics([
    { confidence: 70, hit: true, month: '2026-09' },
    { confidence: 60, hit: false, month: '2026-09' },
    { confidence: 80, hit: true, month: '2026-10' }
  ], 6);
  assert.strictEqual(metrics.calibration.settled, 3);
  assert.strictEqual(metrics.calibration.hits, 2);
  assert.strictEqual(metrics.calibration.hitRate, 67);
  assert.strictEqual(metrics.calibration.brierScore, 0.1633);
  assert.strictEqual(metrics.calibration.buckets.length, 4);
  assert.deepStrictEqual(metrics.calibration.buckets[1], { label: '50–69%', total: 1, hits: 0, hitRate: 0 });
  assert.deepStrictEqual(metrics.calibration.buckets[2], { label: '70–84%', total: 2, hits: 2, hitRate: 100 });
});

test('复盘窗口：速记与决策按半开区间统计', () => {
  const start = new Date(2026, 9, 26).getTime();
  const end = new Date(2026, 10, 2).getTime();
  const counts = countReviewWindow(
    [event({ timestamp: start }), event({ timestamp: end }), event({ timestamp: start - 1 })],
    [{ timestamp: start + 1 }, { timestamp: end }, { timestamp: start - 1 }],
    [],
    start,
    end
  );
  assert.strictEqual(counts.noteCount, 1);
  assert.strictEqual(counts.decisionCount, 1);
  assert.strictEqual(counts.settledPredictions, 0);
  assert.strictEqual(counts.hitRate, 0);
});

test('复盘窗口：待结算不按窗口过滤，已结算按创建时间', () => {
  const start = new Date(2026, 9, 26).getTime();
  const end = new Date(2026, 10, 2).getTime();
  const counts = countReviewWindow(
    [],
    [],
    [
      prediction({ id: 'p_old_pending', status: 'pending', createdAt: 1 }),
      prediction({ id: 'p_hit', status: 'settled', hit: true, createdAt: start + 100 }),
      prediction({ id: 'p_miss', status: 'settled', hit: false, createdAt: start + 200 }),
      prediction({ id: 'p_out', status: 'settled', hit: true, createdAt: end })
    ],
    start,
    end
  );
  assert.strictEqual(counts.pendingPredictions, 1);
  assert.strictEqual(counts.settledPredictions, 2);
  assert.strictEqual(counts.hits, 1);
  assert.strictEqual(counts.hitRate, 50);
});

test('密级文案覆盖三档', () => {
  assert.strictEqual(securityLevelText('analyzable'), '可分析');
  assert.strictEqual(securityLevelText('sealed'), '已封存');
  assert.strictEqual(securityLevelText('local_only'), '仅本地');
});

test('旧预测迁移只合并连续版本，重复版本不合并', () => {
  assert.deepStrictEqual(planLegacyPredictionMerges([
    { id: 'p2', target: '作息', version: 2, rootId: 'p2', createdAt: 2 },
    { id: 'p1', target: '作息', version: 1, rootId: 'p1', createdAt: 1 }
  ]), [{ rootId: 'p1', ids: ['p1', 'p2'] }]);

  assert.deepStrictEqual(planLegacyPredictionMerges([
    { id: 'q1', target: '阅读', version: 1, rootId: 'q1', createdAt: 1 },
    { id: 'q1b', target: '阅读', version: 1, rootId: 'q1b', createdAt: 2 },
    { id: 'q2', target: '阅读', version: 2, rootId: 'q2', createdAt: 3 }
  ]), []);
});

test('周草稿合并：空草稿直接采用事实', () => {
  const draft = mergeWeeklyDraft(null, '本周有三天晚睡', 'plan_1', 'node_1');
  assert.strictEqual(draft.facts, '本周有三天晚睡');
  assert.strictEqual(draft.interpretation, '');
  assert.deepStrictEqual(draft.anchorIds, []);
  assert.strictEqual(draft.planId, 'plan_1');
  assert.strictEqual(draft.planNodeId, 'node_1');
});

test('周草稿合并：空白事实被替换，重复事实不追加，追加时用空行分隔', () => {
  const blank = mergeWeeklyDraft(
    { facts: '   ', interpretation: '', contradiction: '', action: '', anchorIds: [] },
    '新的观察', '', ''
  );
  assert.strictEqual(blank.facts, '新的观察');

  const repeated = mergeWeeklyDraft(
    { facts: '已有事实', interpretation: '', contradiction: '', action: '', anchorIds: [] },
    '已有事实', 'plan_1', 'node_1'
  );
  assert.strictEqual(repeated.facts, '已有事实');

  const appended = mergeWeeklyDraft(
    { facts: '已有事实', interpretation: '', contradiction: '', action: '', anchorIds: [] },
    '补充事实', 'plan_1', 'node_1'
  );
  assert.strictEqual(appended.facts, '已有事实\n\n补充事实');
  assert.strictEqual(appended.planId, 'plan_1');
});

test('列表行压缩正文并限制摘要长度', () => {
  const now = new Date(2026, 9, 26, 20, 0).getTime();
  const timestamp = new Date(2026, 9, 26, 8, 0).getTime();
  const item = toNoteListItem(event({ content: '  第一行\n\n 第二行   ', timestamp }), now);
  assert.strictEqual(item.summary, '第一行 第二行');
  assert.strictEqual(item.timeLabel, '08:00');
  assert.strictEqual(item.title, '标题');
  assert.strictEqual(item.type, '情绪');
  assert.strictEqual(item.level, 'local_only');
  assert.notStrictEqual(item.tags, undefined);

  const longItem = toNoteListItem(event({ content: '字'.repeat(60) }), now);
  assert.strictEqual(longItem.summary.length, NOTE_SUMMARY_MAX_LENGTH + 1);
  assert.ok(longItem.summary.endsWith('…'));
});

test('列表标签是副本，改动不污染原事件', () => {
  const source = event({ tags: ['情绪', '复盘'] });
  const item = toNoteListItem(source);
  item.tags.push('新增');
  assert.deepStrictEqual(source.tags, ['情绪', '复盘']);
});

test('批量投影保持查询顺序', () => {
  const items = toNoteListItems([event({ id: 'a' }), event({ id: 'b' })].map((e, index) =>
    Object.assign(e, { timestamp: 1000 + index })
  ));
  assert.deepStrictEqual(items.map((item) => item.id), ['a', 'b']);
});

test('切换模板保留同名字段', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '精力不足');
  fill(draft, NoteFieldKey.CHOICE, '减少晚间安排');
  draft.content = '先记一句';
  draft.tags.push('自定义');
  const merged = mergeDraftEntries(draft, NoteTemplateId.DECISION);
  assert.strictEqual(readNoteEntry(merged, NoteFieldKey.BACKGROUND), '精力不足');
  assert.strictEqual(readNoteEntry(merged, NoteFieldKey.CHOICE), '减少晚间安排');
  assert.strictEqual(merged.content, '先记一句');
  assert.deepStrictEqual(merged.tags, ['决策']);
  assert.notStrictEqual(merged, draft);
});

test('切换到字段不重叠的模板会清空答案并重置标签', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '精力不足');
  const merged = mergeDraftEntries(draft, NoteTemplateId.EMOTION);
  assert.strictEqual(merged.templateId, NoteTemplateId.EMOTION);
  assert.strictEqual(merged.entries.length, 3);
  assert.ok(merged.entries.every((entry) => entry.value === ''));
  assert.deepStrictEqual(merged.tags, ['情绪']);
});

test('切换到自由模式清空模板字段与标签', () => {
  const draft = createNoteDraft(NoteTemplateId.BODY);
  fill(draft, NoteFieldKey.BODY_SIGNAL, '早起头沉');
  draft.content = '正文保留';
  const merged = mergeDraftEntries(draft, null);
  assert.strictEqual(merged.templateId, null);
  assert.deepStrictEqual(merged.entries, []);
  assert.deepStrictEqual(merged.tags, []);
  assert.strictEqual(merged.content, '正文保留');
});

test('没有已结算预测时命中率显示占位符', () => {
  assert.strictEqual(formatHitRate(0, 0), '—');
  assert.strictEqual(formatHitRate(67, 3), '67%');
  assert.strictEqual(hitRateCaption(0), '命中率');
  assert.strictEqual(hitRateCaption(3), '命中率 · 3 条');
});

test('速记卡联动今日与总数', () => {
  assert.strictEqual(formatNoteCount(3, 12), '今日 3 · 共 12');
  assert.strictEqual(formatNoteCount(0, 0), '今日 0 · 共 0');
});

test('预测列表排序：待结算在前按到期日，已结算按创建时间倒序', () => {
  const rows = toPredictionListItems([
    prediction({ id: 'settled_old', status: 'settled', hit: true, createdAt: 3 }),
    prediction({ id: 'pending_late', settlementDate: '2026-11-01', createdAt: 2 }),
    prediction({ id: 'settled_new', status: 'settled', hit: false, createdAt: 4 }),
    prediction({ id: 'pending_soon', settlementDate: '2026-10-30', createdAt: 1 })
  ]);
  assert.deepStrictEqual(rows.map((row) => row.id), [
    'pending_soon',
    'pending_late',
    'settled_new',
    'settled_old'
  ]);
});

test('预测摘要统计待结算、已结算与命中率', () => {
  const summary = summarizePredictions([
    prediction({ status: 'pending' }),
    prediction({ status: 'pending' }),
    prediction({ status: 'settled', hit: true }),
    prediction({ status: 'settled', hit: false })
  ]);
  assert.deepStrictEqual(summary, { total: 4, pending: 2, settled: 2, hits: 1, hitRate: 50 });
  assert.deepStrictEqual(summarizePredictions([]), { total: 0, pending: 0, settled: 0, hits: 0, hitRate: 0 });
});

test('预测标签区分待结算、命中与未命中', () => {
  assert.strictEqual(predictionStatusLabel({ status: 'pending', hit: null }), '待结算');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: true }), '命中');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: false }), '未命中');
  assert.strictEqual(predictionStatusText('pending', null), '待结算');
  assert.strictEqual(predictionStatusText('settled', true), '命中');
  assert.strictEqual(predictionHitText(null), '未结算');
  assert.strictEqual(predictionHitText(false), '未命中');
});

test('预测详情投影带创建时间与版本', () => {
  const detail = toPredictionDetail(prediction({
    reason: '记录理由',
    version: 2,
    createdAt: new Date(2026, 9, 27, 9, 5).getTime()
  }));
  assert.strictEqual(detail.createdAtLabel, '2026-10-27 09:05');
  assert.strictEqual(detail.reason, '记录理由');
  assert.strictEqual(detail.version, 2);
  assert.strictEqual(detail.target, '本周作息');
});

test('周复盘范围从周一到下周一', () => {
  const range = rangeFor('week', new Date(2026, 9, 27, 15, 0).getTime());
  const start = new Date(range.start);
  assert.strictEqual(start.getDay(), 1);
  assert.strictEqual(start.getDate(), 26);
  assert.strictEqual(range.label, '2026-10-26 ~ 2026-11-01');
});

test('周日仍归属上一个周一', () => {
  const range = rangeFor('week', new Date(2026, 10, 1, 12, 0).getTime());
  assert.strictEqual(range.label, '2026-10-26 ~ 2026-11-01');
});

test('月复盘范围覆盖整月', () => {
  const range = rangeFor('month', new Date(2026, 9, 27).getTime());
  const start = new Date(range.start);
  assert.strictEqual(start.getDate(), 1);
  assert.strictEqual(range.label, '2026-10-01 ~ 2026-10-31');
});

test('关系按信任层级与最近互动排序', () => {
  const items = toRelationListItems([
    relation({ id: 'friendly', trustLevel: 'friendly', interactionLog: [{ timestamp: 300, content: 'a' }] }),
    relation({ id: 'transparent', trustLevel: 'transparent', interactionLog: [{ timestamp: 100, content: 'b' }] }),
    relation({ id: 'sincere_new', trustLevel: 'sincere', interactionLog: [{ timestamp: 400, content: 'c' }] }),
    relation({ id: 'sincere_old', trustLevel: 'sincere', interactionLog: [{ timestamp: 200, content: 'd' }] })
  ]);
  assert.deepStrictEqual(items.map((item) => item.id), [
    'transparent',
    'sincere_new',
    'sincere_old',
    'friendly'
  ]);
  assert.strictEqual(items[0].interactionCount, 1);
  assert.ok(items[0].lastInteractionLabel.includes('1970'));
});

test('关系筛选与详情日志倒序', () => {
  const list = toRelationListItems([
    relation({ id: 'a', trustLevel: 'sincere' }),
    relation({ id: 'b', trustLevel: 'friendly' })
  ]);
  assert.strictEqual(filterRelationItems(list, 'sincere').length, 1);
  assert.strictEqual(filterRelationItems(list, null).length, 2);

  const detail = toRelationDetail(relation({
    interactionLog: [{ timestamp: 100, content: '旧' }, { timestamp: 300, content: '新' }]
  }));
  assert.deepStrictEqual(detail.interactionLog.map((log) => log.content), ['新', '旧']);

  assert.strictEqual(trustLevelText('friendly'), '友好');
  assert.strictEqual(trustLevelText('sincere'), '真诚');
  assert.strictEqual(trustLevelText('transparent'), '透明');
});

test('读数阈值覆盖睡眠、运动与报警', () => {
  const rules = new ThresholdReadingRules();
  const flags = rules.evaluate({
    date: '2026-10-27',
    sleepHours: 5.8,
    exerciseCount: 0,
    alertCount: 2
  });
  assert.deepStrictEqual(flags.map((flag) => flag.code), ['sleep_low', 'exercise_none', 'alert_high']);
  assert.strictEqual(rules.evaluate({
    date: '2026-10-27',
    sleepHours: 6.6,
    exerciseCount: 1,
    alertCount: 0
  }).length, 0);
});

test('状态按日期倒序并汇总平均值与标记天数', () => {
  const rules = new ThresholdReadingRules();
  const records = [
    { id: 'a', date: '2026-10-25', sleepHours: 6, exerciseCount: 0, alertCount: 1, note: '' },
    { id: 'b', date: '2026-10-27', sleepHours: 8, exerciseCount: 2, alertCount: 0, note: '' }
  ];
  const rows = toStatusDayRows(records, rules);
  assert.deepStrictEqual(rows.map((row) => row.date), ['2026-10-27', '2026-10-25']);

  const summary = summarizeStatus(rows);
  assert.strictEqual(summary.days, 2);
  assert.strictEqual(summary.averageSleep, 7);
  assert.strictEqual(summary.totalExercise, 2);
  assert.strictEqual(summary.totalAlerts, 1);
  assert.strictEqual(summary.flaggedDays, 1);

  const overview = buildStatusOverview(records, rules, 1);
  assert.strictEqual(overview.latest.date, '2026-10-27');
  assert.strictEqual(overview.recent.length, 1);
});

test('复盘提示解析：正常、空列表与坏数据', () => {
  const prompts = parseReviewPrompts(JSON.stringify({
    prompts: [{ id: 'p1', text: '哪件事最消耗你？', category: 'energy' }]
  }));
  assert.strictEqual(prompts.length, 1);
  assert.strictEqual(prompts[0].text, '哪件事最消耗你？');

  assert.deepStrictEqual(parseReviewPrompts(JSON.stringify({ prompts: [] })), []);

  assert.throws(() => parseReviewPrompts(JSON.stringify({ items: [] })));
  assert.throws(() => parseReviewPrompts(JSON.stringify({
    prompts: [{ id: 'p1', text: '   ', category: 'energy' }]
  })));
  assert.throws(() => parseReviewPrompts('not json'));
});

test('预测统计按结算月份分组并过滤待结算', () => {
  const predictions = [
    prediction({ id: 'a', status: 'settled', hit: true, settlementDate: '2026-08-15' }),
    prediction({ id: 'b', status: 'settled', hit: false, settlementDate: '2026-08-28' }),
    prediction({ id: 'c', status: 'settled', hit: true, settlementDate: '2026-09-10' }),
    prediction({ id: 'd', status: 'pending', hit: null, settlementDate: '2026-10-01' }),
    prediction({ id: 'e', status: 'settled', hit: true, settlementDate: '2026-10-20' })
  ];
  const stats = buildPredictionStats(predictions);
  assert.strictEqual(stats.settled, 4);
  assert.strictEqual(stats.hits, 3);
  assert.strictEqual(stats.misses, 1);
  assert.strictEqual(stats.hitRate, 75);
  assert.deepStrictEqual(stats.months.map((point) => point.label), ['8月', '9月', '10月']);
  assert.deepStrictEqual(stats.months.map((point) => point.hitRate), [50, 100, 100]);

  const limited = buildPredictionStats(predictions, 2);
  assert.deepStrictEqual(limited.months.map((point) => point.month), ['2026-09', '2026-10']);
  assert.strictEqual(limited.settled, 4);
});

test('已结算但缺命中结果按未命中计', () => {
  const stats = buildPredictionStats([
    prediction({ id: 'a', status: 'settled', hit: null, settlementDate: '2026-10-25' })
  ]);
  assert.strictEqual(stats.settled, 1);
  assert.strictEqual(stats.hits, 0);
  assert.strictEqual(stats.misses, 1);
  assert.strictEqual(stats.hitRate, 0);
});

test('预测草稿校验覆盖必填、置信度与日期', () => {
  const now = new Date(2026, 9, 27, 12, 0).getTime();
  const valid = {
    target: '本周作息',
    judgment: '本周日均睡眠达到 7 小时',
    confidence: 70,
    reason: '',
    settlementDate: '2026-10-30'
  };
  assert.strictEqual(hasPredictionErrors(validatePredictionDraft(valid, now)), false);

  const invalid = validatePredictionDraft({
    target: '   ',
    judgment: '',
    confidence: 0,
    reason: '',
    settlementDate: '2026-10-20'
  }, now);
  assert.ok(invalid.target.length > 0);
  assert.ok(invalid.judgment.length > 0);
  assert.ok(invalid.confidence.length > 0);
  assert.ok(invalid.settlementDate.length > 0);

  assert.strictEqual(todayDateString(now), '2026-10-27');
  assert.strictEqual(dateAfterDays(now, 7), '2026-11-03');
});

test('复盘历史投影保留锚点顺序并标注周月', () => {
  const result = {
    id: 'rv_1',
    period: 'week',
    rangeLabel: '10-21 ~ 10-27',
    facts: '事实',
    interpretation: '解释',
    contradiction: '矛盾',
    action: '行动',
    anchorIds: ['a2', 'a1', 'missing'],
    createdAt: new Date(2026, 9, 27, 20, 5).getTime()
  };
  const item = toReviewHistoryItem(result);
  assert.strictEqual(item.periodLabel, '周复盘');
  assert.strictEqual(item.anchorCount, 3);
  assert.ok(item.createdAtLabel.startsWith('2026-10-27'));

  const anchors = [
    { id: 'a1', text: '锚点一', source: '来源一', order: 1 },
    { id: 'a2', text: '锚点二', source: '来源二', order: 2 }
  ];
  const detail = toReviewDetailView(result, anchors);
  assert.deepStrictEqual(detail.anchors.map((anchor) => anchor.id), ['a2', 'a1']);
  assert.strictEqual(detail.periodLabel, '周复盘');
});

test('信任策略按层级与标记决定是否做动机分析', () => {
  const policy = new BasicTrustPolicy();
  assert.strictEqual(policy.decide({ trustLevel: 'friendly', rawMaterialTest: true, forbidAnalysis: false }).allowMotiveAnalysis, false);
  assert.strictEqual(policy.decide({ trustLevel: 'sincere', rawMaterialTest: false, forbidAnalysis: false }).allowMotiveAnalysis, false);
  assert.strictEqual(policy.decide({ trustLevel: 'sincere', rawMaterialTest: true, forbidAnalysis: false }).allowMotiveAnalysis, true);
  assert.strictEqual(policy.decide({ trustLevel: 'transparent', rawMaterialTest: true, forbidAnalysis: false }).allowMotiveAnalysis, true);
  assert.strictEqual(policy.decide({ trustLevel: 'transparent', rawMaterialTest: true, forbidAnalysis: true }).allowMotiveAnalysis, false);
});

test('数据库状态与能力缺失码', () => {
  assert.strictEqual(appHealth.current(), DbStatus.CHECKING);
  appHealth.markFailed('open failed');
  assert.strictEqual(appHealth.current(), DbStatus.FAILED);
  assert.strictEqual(appHealth.message(), 'open failed');
  appHealth.markReady();
  assert.strictEqual(appHealth.current(), DbStatus.READY);
  assert.strictEqual(appHealth.message(), '');
  assert.strictEqual(isDatabaseUnsupported(801), true);
  assert.strictEqual(isDatabaseUnsupported(14800011), false);
  appHealth.reset();
  assert.strictEqual(appHealth.current(), DbStatus.CHECKING);
});

test('清空数据覆盖全部表', () => {
  const { DB_TABLES, DB_TABLES_CHILD_FIRST } = require('./out2/db/DbConstants');
  const declared = Object.values(DB_TABLES).slice().sort();
  const cleared = DB_TABLES_CHILD_FIRST.slice().sort();
  assert.deepStrictEqual(cleared, declared);
  // 子表排在父表前面，将来加外键也不会因为删除顺序失败。
  assert.ok(DB_TABLES_CHILD_FIRST.indexOf(DB_TABLES.PLAN_LINK) <
    DB_TABLES_CHILD_FIRST.indexOf(DB_TABLES.PLAN));
});

test('导出保留窗口', () => {
  const { expiredExports } = require('./out2/export/ExportRetention');
  const names = [];
  for (let day = 1; day <= 12; day += 1) {
    names.push(`cogit-export-202601${String(day).padStart(2, '0')}-0900.md`);
  }
  names.push('notes.txt', 'archive.md');
  const latest = 'cogit-export-20260112-0900.md';
  // 除最新一份外还有 11 份，保留窗口 10 份，应删掉最早的两份。
  assert.deepStrictEqual(expiredExports(names, latest), [
    'cogit-export-20260101-0900.md',
    'cogit-export-20260102-0900.md'
  ]);
  // 窗口大于现有份数时不做删除。
  assert.deepStrictEqual(expiredExports(names, latest, 20), []);
  // 自定义窗口按同样规则计算。
  assert.strictEqual(expiredExports(names, latest, 3).length, 9);
});

test('成本估算按千字符计价并保留四位', () => {
  assert.strictEqual(estimateCostYuan(1000, 0), 0.002);
  assert.strictEqual(estimateCostYuan(0, 1000), 0.002);
  assert.strictEqual(estimateCostYuan(500, 500), 0.002);
  assert.strictEqual(estimateCostYuan(333, 0), 0.0007);
  assert.strictEqual(estimateCostYuan(0, 0), 0);
});

test('成本估算把负数按零处理', () => {
  assert.strictEqual(estimateCostYuan(-500, 1000), 0.002);
  assert.strictEqual(estimateCostYuan(-500, -500), 0);
});

test('预算判定在正好用满时放行', () => {
  assert.strictEqual(budgetAllows(10, 9.99, 0.01), true);
  assert.strictEqual(budgetAllows(10, 9.99, 0.02), false);
});

test('预算为零时不放行任何调用', () => {
  assert.strictEqual(budgetAllows(0, 0, 0), false);
  assert.strictEqual(budgetAllows(0, 0, 0.0001), false);
});

test('月度键按本地月份补零', () => {
  assert.strictEqual(monthKey(new Date(2026, 0, 15).getTime()), '2026-01');
  assert.strictEqual(monthKey(new Date(2026, 11, 31, 23, 59).getTime()), '2026-12');
});

test('未知档位按旧开关回落到模板或本地模拟', () => {
  const off = sanitizeAppSettings(Object.assign(defaultAppSettings(), {
    llmProvider: 'bogus',
    llmEnabled: false
  }));
  assert.strictEqual(off.llmProvider, 'template');
  assert.strictEqual(off.llmEnabled, false);
  const on = sanitizeAppSettings(Object.assign(defaultAppSettings(), {
    llmProvider: 'bogus',
    llmEnabled: true
  }));
  assert.strictEqual(on.llmProvider, 'mock');
  assert.strictEqual(on.llmEnabled, true);
});

test('预算取整后夹在零到上限之间', () => {
  const base = defaultAppSettings();
  assert.strictEqual(sanitizeAppSettings(Object.assign(base, { llmMonthlyBudget: 29.9 })).llmMonthlyBudget, 29);
  assert.strictEqual(sanitizeAppSettings(Object.assign(base, { llmMonthlyBudget: -8 })).llmMonthlyBudget, 0);
  assert.strictEqual(sanitizeAppSettings(Object.assign(base, { llmMonthlyBudget: 8000 })).llmMonthlyBudget, 500);
  assert.strictEqual(sanitizeAppSettings(Object.assign(base, { llmMonthlyBudget: Number.NaN })).llmMonthlyBudget, 30);
});

test('空地址与空模型回落默认值', () => {
  const cleaned = sanitizeAppSettings(Object.assign(defaultAppSettings(), {
    llmBaseUrl: '   ',
    llmModel: '  '
  }));
  assert.strictEqual(cleaned.llmBaseUrl, 'http://localhost:4523/v1');
  assert.strictEqual(cleaned.llmModel, 'glm-4.7-flash');
});

test('非法密级回落为仅本地', () => {
  const cleaned = sanitizeAppSettings(Object.assign(defaultAppSettings(), { defaultLevel: 'whatever' }));
  assert.strictEqual(cleaned.defaultLevel, 'local_only');
});

test('字符串数组解析跳过坏元素并计数', () => {
  consumeJsonIssues();
  assert.deepStrictEqual(parseStringArray('["a","b"]'), ['a', 'b']);
  assert.strictEqual(consumeJsonIssues(), 0);
  assert.deepStrictEqual(parseStringArray('["a",1,null]'), ['a']);
  assert.strictEqual(consumeJsonIssues(), 2);
});

test('空列不算异常，损坏与非数组各记一次', () => {
  consumeJsonIssues();
  assert.deepStrictEqual(parseStringArray('   '), []);
  assert.strictEqual(consumeJsonIssues(), 0);
  assert.deepStrictEqual(parseStringArray('not json'), []);
  assert.strictEqual(consumeJsonIssues(), 1);
  assert.deepStrictEqual(parseStringArray('{"a":1}'), []);
  assert.strictEqual(consumeJsonIssues(), 1);
});

test('互动记录只保留字段齐全的条目', () => {
  consumeJsonIssues();
  const ok = parseInteractionLog('[{"timestamp":1,"content":"x"}]');
  assert.strictEqual(ok.length, 1);
  assert.strictEqual(ok[0].content, 'x');
  const mixed = parseInteractionLog('[{"timestamp":1,"content":"x"},{"timestamp":2},{"content":"y"}]');
  assert.strictEqual(mixed.length, 1);
  assert.strictEqual(consumeJsonIssues(), 2);
});

if (failures.length > 0) {
  console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(`PASSED ${passed} / ${passed}`);
