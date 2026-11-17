'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

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
  parseMaterialIds,
  buildRows,
  mergeExisting
} = require('./out2/review/ReviewMaterialSnapshot');
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
const { sanitizeObservationRule } = require('./out2/analysis/status/ObservationRule');
const {
  isReadingUnknown,
  setReadingUnknown,
  unknownReadingText,
  unknownList
} = require('./out2/analysis/status/ReadingPresence');
const { toCapacityJudgment, capacityText, isCapacityJudgment } = require('./out2/model/CapacityJudgment');
const {
  parseStatusRevisions,
  stringifyStatusRevisions,
  statusRevisionOf
} = require('./out2/status/StatusRevisions');
const {
  contrastRatio,
  worstCaseContrastRatio,
  contrastHint,
  compositeOver,
  MIN_BODY_CONTRAST
} = require('./out2/theme/Contrast');
const { parseReviewPrompts } = require('./out2/network/ReviewPrompt');
const {
  disclosureBoundaryOf
} = require('./out2/relation/DisclosureBoundary');
const {
  normalizeInteractionLog,
  visibleInExport,
  allowedInContext,
  toInteractionSource,
  toCitationScope,
  sourceText,
  citationText,
  SOURCE_OPTIONS,
  CITATION_OPTIONS
} = require('./out2/relation/InteractionSource');
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
const { NoteDepth, readNoteEntry } = require('./out2/note/NoteDraft');
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
  assert.strictEqual(draft.entries.length, 6);
  assert.deepStrictEqual(draft.entries.map((entry) => entry.key), [
    NoteFieldKey.BACKGROUND,
    NoteFieldKey.DONE_ALREADY,
    NoteFieldKey.KNOWN_CONDITIONS,
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

test('快速档只校验正文，跳过模板必填', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  draft.depth = NoteDepth.QUICK;
  draft.content = '一句现场';
  assert.deepStrictEqual(validateNoteDraft(draft), { valid: true, errors: [] });
  draft.depth = NoteDepth.NORMAL;
  assert.strictEqual(validateNoteDraft(draft).valid, false);
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

test('决策草稿把已有行动与已知条件写入决策', () => {
  const draft = createNoteDraft(NoteTemplateId.DECISION);
  fill(draft, NoteFieldKey.BACKGROUND, '精力不足');
  fill(draft, NoteFieldKey.DONE_ALREADY, '  提前睡了两晚  ');
  fill(draft, NoteFieldKey.KNOWN_CONDITIONS, '  本周没有加班  ');
  const decision = buildDecisionFromNote(draft, 'ev_1');
  assert.ok(decision !== null);
  assert.strictEqual(decision.done, '提前睡了两晚');
  assert.strictEqual(decision.knownConditions, '本周没有加班');

  const empty = buildDecisionFromNote(createNoteDraft(NoteTemplateId.DECISION), 'ev_2');
  assert.ok(empty !== null);
  assert.strictEqual(empty.done, '');
  assert.strictEqual(empty.knownConditions, '');
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
  assert.deepStrictEqual(summary,
    { total: 4, pending: 2, settled: 2, nonBinarySettled: 0, hits: 1, hitRate: 50 });
  assert.deepStrictEqual(summarizePredictions([]),
    { total: 0, pending: 0, settled: 0, nonBinarySettled: 0, hits: 0, hitRate: 0 });
});

test('非二值结算不进二值分母，单列为已结算非二值', () => {
  const summary = summarizePredictions([
    prediction({ id: 'a', status: 'settled', outcome: 'hold', hit: true }),
    prediction({ id: 'b', status: 'settled', outcome: 'fail', hit: false }),
    prediction({ id: 'c', status: 'settled', outcome: 'partial', hit: null }),
    prediction({ id: 'd', status: 'settled', outcome: 'insufficient', hit: null }),
    prediction({ id: 'e', status: 'settled', outcome: 'undecidable', hit: null })
  ]);
  assert.strictEqual(summary.settled, 2);
  assert.strictEqual(summary.nonBinarySettled, 3);
  assert.strictEqual(summary.hits, 1);
  assert.strictEqual(summary.hitRate, 50);
});

test('旧记录缺 outcome 时标签与分母按 hit 回退', () => {
  const summary = summarizePredictions([
    prediction({ id: 'a', status: 'settled', hit: true }),
    prediction({ id: 'b', status: 'settled', hit: false }),
    prediction({ id: 'c', status: 'settled', hit: null })
  ]);
  assert.strictEqual(summary.settled, 2);
  assert.strictEqual(summary.nonBinarySettled, 0);
  assert.strictEqual(summary.hitRate, 50);
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: true }), '成立');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: false }), '未成立');
  assert.strictEqual(predictionStatusText('settled', 'hold'), '成立');
  assert.strictEqual(predictionHitText('fail'), '未成立');
});

test('预测标签按五档结算结果输出', () => {
  assert.strictEqual(predictionStatusLabel({ status: 'pending', hit: null, outcome: '' }), '待结算');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: true, outcome: 'hold' }), '成立');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: false, outcome: 'fail' }), '未成立');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: null, outcome: 'partial' }), '部分成立');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: null, outcome: 'insufficient' }), '证据不足');
  assert.strictEqual(predictionStatusLabel({ status: 'settled', hit: null, outcome: 'undecidable' }), '无法判断');
  assert.strictEqual(predictionStatusText('pending', ''), '待结算');
  assert.strictEqual(predictionStatusText('settled', 'partial'), '部分成立');
  assert.notStrictEqual(predictionStatusText('settled', 'partial'), '未命中');
  assert.strictEqual(predictionHitText('insufficient'), '证据不足');
  assert.notStrictEqual(predictionHitText('undecidable'), '未结算');
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

test('关系按待回应、纠正时间与最近互动排序', () => {
  const items = toRelationListItems([
    relation({ id: 'friendly', trustLevel: 'friendly', interactionLog: [{ timestamp: 300, content: 'a' }] }),
    relation({ id: 'transparent', trustLevel: 'transparent', interactionLog: [{ timestamp: 100, content: 'b' }] }),
    relation({ id: 'sincere_new', trustLevel: 'sincere', interactionLog: [{ timestamp: 400, content: 'c' }] }),
    relation({ id: 'sincere_old', trustLevel: 'sincere', interactionLog: [{ timestamp: 200, content: 'd' }] }),
    relation({
      id: 'pending', trustLevel: 'friendly',
      interactionLog: [{ timestamp: 50, content: 'e' }],
      correction: '对方纠正了我的理解', correctionAt: 60
    })
  ]);
  assert.deepStrictEqual(items.map((item) => item.id), [
    'pending',
    'sincere_new',
    'friendly',
    'sincere_old',
    'transparent'
  ]);
  assert.strictEqual(items[0].pendingCorrections, 1);
  assert.strictEqual(items[0].latestCorrectionExcerpt, '对方纠正了我的理解');
  assert.strictEqual(items[0].interactionCount, 1);
  assert.ok(items[0].lastInteractionLabel.includes('1970'));

  const answered = toRelationListItems([relation({
    id: 'answered',
    interactionLog: [{ timestamp: 70, content: '我的观察', source: 'observation' }],
    correction: '对方纠正了我的理解', correctionAt: 60
  })]);
  assert.strictEqual(answered[0].pendingCorrections, 0);
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

test('未记录的读数不参与平均，也不触发提示', () => {
  const rules = new ThresholdReadingRules();
  const records = [
    {
      id: 'a',
      date: '2026-10-25',
      sleepHours: 0,
      exerciseCount: 0,
      alertCount: 0,
      note: '',
      unknownReadings: 'sleep,exercise,alert'
    },
    { id: 'b', date: '2026-10-26', sleepHours: 8, exerciseCount: 2, alertCount: 0, note: '' }
  ];
  const rows = toStatusDayRows(records, rules);
  assert.strictEqual(rows[1].flags.length, 0);
  assert.strictEqual(unknownReadingText(rows[1].unknownReadings), '睡眠、运动、凌晨报警未记录');

  const summary = summarizeStatus(rows);
  assert.strictEqual(summary.days, 2);
  assert.strictEqual(summary.sleepDays, 1);
  assert.strictEqual(summary.averageSleep, 8);
  assert.strictEqual(summary.totalExercise, 2);
  assert.strictEqual(summary.totalAlerts, 0);
  assert.strictEqual(summary.unknownDays, 1);
});

test('个人观察阈值与关闭提示生效', () => {
  const custom = new ThresholdReadingRules(sanitizeObservationRule({
    sleepMinHours: 7.5,
    alertWarnCount: 3,
    hintsEnabled: true
  }));
  const flags = custom.evaluate({ date: '2026-10-27', sleepHours: 7, exerciseCount: 1, alertCount: 2 });
  assert.deepStrictEqual(flags.map((flag) => flag.code), ['sleep_low']);

  const muted = new ThresholdReadingRules(sanitizeObservationRule({
    sleepMinHours: 6.5,
    alertWarnCount: 1,
    hintsEnabled: false
  }));
  assert.strictEqual(muted.evaluate({
    date: '2026-10-27',
    sleepHours: 4,
    exerciseCount: 0,
    alertCount: 4
  }).length, 0);

  const clamped = sanitizeObservationRule({ sleepMinHours: 99, alertWarnCount: 0, hintsEnabled: true });
  assert.strictEqual(clamped.sleepMinHours, 10);
  assert.strictEqual(clamped.alertWarnCount, 1);
});

test('未知读数标记可增删并保持顺序', () => {
  let marker = '';
  marker = setReadingUnknown(marker, 'alert', true);
  marker = setReadingUnknown(marker, 'sleep', true);
  assert.strictEqual(marker, 'sleep,alert');
  assert.deepStrictEqual(unknownList(marker), ['sleep', 'alert']);
  assert.strictEqual(isReadingUnknown(marker, 'exercise'), false);
  marker = setReadingUnknown(marker, 'sleep', false);
  assert.strictEqual(marker, 'alert');
  assert.strictEqual(unknownReadingText(marker), '凌晨报警未记录');
  assert.strictEqual(unknownReadingText(''), '');
});

test('更正保留原读数并可读回', () => {
  const revisions = [];
  revisions.push(statusRevisionOf(1763200000000, 5.5, 0, 2, '前一天补记', 'limited'));
  const stored = stringifyStatusRevisions(revisions);
  const parsed = parseStatusRevisions(stored);
  assert.strictEqual(parsed.length, 1);
  assert.strictEqual(parsed[0].at, 1763200000000);
  assert.strictEqual(parsed[0].sleepHours, 5.5);
  assert.strictEqual(parsed[0].capacity, 'limited');
  assert.strictEqual(parsed[0].note, '前一天补记');

  assert.deepStrictEqual(parseStatusRevisions(''), []);
  assert.deepStrictEqual(parseStatusRevisions('not json'), []);
  assert.deepStrictEqual(parseStatusRevisions('[{"sleepHours":6}]'), []);
});

test('承受判断只接受四个选项', () => {
  assert.strictEqual(isCapacityJudgment('pause'), true);
  assert.strictEqual(isCapacityJudgment('healthy'), false);
  assert.strictEqual(toCapacityJudgment('healthy'), '');
  assert.strictEqual(capacityText('bearable'), '可以承受');
  assert.strictEqual(capacityText('limited'), '需要限量');
  assert.strictEqual(capacityText('pause'), '需要暂停');
  assert.strictEqual(capacityText('unknown'), '无法判断');
  assert.strictEqual(capacityText(''), '未填写');
});

test('背景浓淡按最差情况给出对比度提示', () => {
  assert.ok(Math.abs(contrastRatio('#000000', '#FFFFFF') - 21) < 0.1);
  assert.strictEqual(compositeOver('#FFFFFF', '#000000', 1), '#FFFFFF');

  const lightSafe = worstCaseContrastRatio('#444441', '#F5F6F8', 0.9);
  assert.ok(lightSafe >= MIN_BODY_CONTRAST);
  assert.ok(contrastHint('#444441', '#F5F6F8', 0.9).indexOf('满足') >= 0);

  const darkSafe = worstCaseContrastRatio('#D5D8DC', '#121417', 0.9);
  assert.ok(darkSafe >= MIN_BODY_CONTRAST);

  const weak = worstCaseContrastRatio('#444441', '#F5F6F8', 0.05);
  assert.ok(weak < MIN_BODY_CONTRAST);
  assert.ok(contrastHint('#444441', '#F5F6F8', 0.05).indexOf('建议调淡') >= 0);
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

test('已结算但缺命中结果只进总数，不进二值统计', () => {
  const stats = buildPredictionStats([
    prediction({ id: 'a', status: 'settled', hit: null, settlementDate: '2026-10-25' })
  ]);
  assert.strictEqual(stats.settled, 1);
  assert.strictEqual(stats.hits, 0);
  assert.strictEqual(stats.misses, 0);
  assert.strictEqual(stats.hitRate, 0);
  assert.strictEqual(stats.excluded, 0);
});

test('统计分母只收二值结果，outcome 与 hit 冲突的行计入排除', () => {
  const stats = buildPredictionStats([
    prediction({ id: 'a', status: 'settled', outcome: 'hold', hit: true, settlementDate: '2026-10-01' }),
    prediction({ id: 'b', status: 'settled', outcome: 'fail', hit: false, settlementDate: '2026-10-02' }),
    prediction({ id: 'c', status: 'settled', outcome: 'partial', hit: null, settlementDate: '2026-10-03' }),
    prediction({ id: 'd', status: 'settled', outcome: 'partial', hit: true, settlementDate: '2026-10-04' }),
    prediction({ id: 'e', status: 'settled', outcome: 'hold', hit: null, settlementDate: '2026-10-05' })
  ]);
  assert.strictEqual(stats.settled, 5);
  assert.strictEqual(stats.hits, 1);
  assert.strictEqual(stats.misses, 1);
  assert.strictEqual(stats.hitRate, 50);
  assert.strictEqual(stats.excluded, 2);
  assert.strictEqual(stats.outcomes.partial, 1);
  assert.deepStrictEqual(stats.months.map((point) => point.settled), [2]);
});

test('预测草稿校验覆盖必填、置信度与日期', () => {
  const now = new Date(2026, 9, 27, 12, 0).getTime();
  const valid = {
    target: '本周作息',
    judgment: '本周日均睡眠达到 7 小时',
    confidence: 70,
    reason: '',
    falsification: '若日均睡眠低于 6 小时',
    settlementDate: '2026-10-30'
  };
  assert.strictEqual(hasPredictionErrors(validatePredictionDraft(valid, now)), false);

  const invalid = validatePredictionDraft({
    target: '   ',
    judgment: '',
    confidence: -1,
    reason: '',
    falsification: '',
    settlementDate: '2026-10-20'
  }, now);
  assert.ok(invalid.target.length > 0);
  assert.ok(invalid.judgment.length > 0);
  assert.ok(invalid.confidence.length > 0);
  assert.ok(invalid.settlementDate.length > 0);
  assert.ok(invalid.falsification.length > 0);

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

test('披露层级只说明可分享范围，不授予动机分析', () => {
  const friendly = disclosureBoundaryOf('friendly', false);
  assert.ok(friendly.shareable.indexOf('默认只留在本机') >= 0);
  assert.ok(friendly.rule.indexOf('不推断') >= 0);
  assert.strictEqual(friendly.rule.indexOf('允许'), -1);

  const transparent = disclosureBoundaryOf('transparent', false);
  assert.ok(transparent.shareable.indexOf('共同承担') >= 0);
  assert.strictEqual(transparent.tierText, '透明');

  const blocked = disclosureBoundaryOf('transparent', true);
  assert.ok(blocked.rule.indexOf('已禁止') >= 0);
});

test('互动来源与引用范围默认为观察、仅本机、不进上下文', () => {
  assert.deepStrictEqual(SOURCE_OPTIONS, ['observation', 'stated', 'joint', 'inference']);
  assert.deepStrictEqual(CITATION_OPTIONS, ['hidden', 'paraphrase', 'quote']);
  assert.strictEqual(sourceText('stated'), '对方明确陈述');
  assert.strictEqual(citationText('paraphrase'), '可转述');
  assert.strictEqual(toInteractionSource('unknown'), 'observation');
  assert.strictEqual(toCitationScope('unknown'), 'hidden');

  const normalized = normalizeInteractionLog({ timestamp: 1, content: '他说不用等' });
  assert.strictEqual(normalized.source, 'observation');
  assert.strictEqual(normalized.citation, 'hidden');
  assert.strictEqual(normalized.allowContext, false);
  assert.strictEqual(allowedInContext(normalized), false);
});

test('对方陈述默认不进导出，提高范围后才出现', () => {
  const statement = { timestamp: 1, content: '他说那天只是累了', source: 'stated', citation: 'hidden', allowContext: false };
  assert.strictEqual(visibleInExport(statement), false);
  assert.strictEqual(visibleInExport({ timestamp: 1, content: '我看到的', source: 'observation' }), true);
  assert.strictEqual(visibleInExport({
    timestamp: 1,
    content: '他说那天只是累了',
    source: 'stated',
    citation: 'paraphrase',
    allowContext: false
  }), true);
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

test('样本下限统一为十，五档结果分别计数', () => {
  const { SAMPLE_FLOOR, hasEnoughSamples } = require('./out2/analysis/metrics/SampleFloor');
  assert.strictEqual(SAMPLE_FLOOR, 10);
  assert.strictEqual(hasEnoughSamples(9), false);
  assert.strictEqual(hasEnoughSamples(10), true);

  const stats = buildPredictionStats([
    prediction({ id: 'a', status: 'settled', hit: true, settlementDate: '2026-10-20' }),
    prediction({ id: 'b', status: 'settled', hit: null, settlementDate: '2026-10-21' })
  ]);
  assert.strictEqual(stats.outcomes.hold, 1);
  assert.strictEqual(stats.outcomes.fail, 0);
  assert.strictEqual(stats.settled, 2);
  assert.strictEqual(stats.hits, 1);
});

test('五档结果：旧命中映射为成立与未成立，其余单列', () => {
  const { outcomeFromLegacy, isBinaryOutcome, isNonBinaryOutcome, NO_OUTCOME } =
    require('./out2/model/PredictionOutcome');
  assert.strictEqual(outcomeFromLegacy(true), 'hold');
  assert.strictEqual(outcomeFromLegacy(false), 'fail');
  assert.strictEqual(outcomeFromLegacy(null), NO_OUTCOME);
  assert.strictEqual(isBinaryOutcome('hold'), true);
  assert.strictEqual(isBinaryOutcome('partial'), false);
  assert.strictEqual(isNonBinaryOutcome('partial'), true);
  assert.strictEqual(isNonBinaryOutcome('insufficient'), true);
  assert.strictEqual(isNonBinaryOutcome('undecidable'), true);
  assert.strictEqual(isNonBinaryOutcome('fail'), false);
});

test('复盘六区：空内容合法，旧记录读不到 payload', () => {
  const { emptyReviewPayload, hasAnyZone } = require('./out2/model/ReviewPayload');
  const { parseReviewPayload, consumeJsonIssues } = require('./out2/db/SafeJson');
  const blank = emptyReviewPayload();
  assert.strictEqual(hasAnyZone(blank), false);
  assert.strictEqual(hasAnyZone(Object.assign({}, blank, { scene: '只写了现场' })), true);
  assert.strictEqual(parseReviewPayload(''), undefined);
  const parsed = parseReviewPayload('{"scene":"现场","model":"模型","relation":"","evidence":"","cost":"","revision":""}');
  assert.strictEqual(parsed.scene, '现场');
  assert.strictEqual(parsed.model, '模型');
  assert.strictEqual(parsed.cost, '');
  consumeJsonIssues();
  assert.strictEqual(parseReviewPayload('{坏数据'), undefined);
  assert.strictEqual(consumeJsonIssues(), 1);
});

test('复盘材料编号随 payload 保存并按原顺序读回', () => {
  const { emptyReviewPayload } = require('./out2/model/ReviewPayload');
  const { parseReviewPayload } = require('./out2/db/SafeJson');
  const payload = emptyReviewPayload();
  payload.materialIds = ['mt_2', 'mt_1'];
  const readBack = parseReviewPayload(JSON.stringify(payload));
  assert.deepStrictEqual(readBack.materialIds, ['mt_2', 'mt_1']);
  assert.deepStrictEqual(emptyReviewPayload().materialIds, []);
  const legacy = parseReviewPayload('{"scene":"现场","model":"","relation":"","evidence":"","cost":"","revision":""}');
  assert.deepStrictEqual(legacy.materialIds, []);
  const broken = parseReviewPayload('{"materialIds":[1,"mt_1"]}');
  assert.deepStrictEqual(broken.materialIds, []);
});

test('备份按行导出时排除封存与已删除行，恢复时保住本机封存', () => {
  const { isSealedRow, isDeletedRow, deleteSqlFor } = require('./out2/settings/BackupRows');
  assert.strictEqual(isSealedRow({ id: 'ev_1', level: 'sealed' }), true);
  assert.strictEqual(isSealedRow({ id: 'ev_2', level: 'local_only' }), false);
  assert.strictEqual(isSealedRow({ id: 'au_1', provider: 'model' }), false);
  assert.strictEqual(isDeletedRow({ id: 'ev_3', deleted: '1' }), true);
  assert.strictEqual(isDeletedRow({ id: 'ev_4', deleted: '0' }), false);
  assert.strictEqual(isDeletedRow({ id: 'ev_5' }), false);
  assert.strictEqual(isDeletedRow({ id: 'ev_6', deleted: null }), false);
  assert.strictEqual(deleteSqlFor('event', true), "DELETE FROM event WHERE level <> 'sealed'");
  assert.strictEqual(deleteSqlFor('plan_link', false), 'DELETE FROM plan_link');
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

test('复盘快照复制可引用材料的正文与来源', () => {
  const rows = buildRows('rv_1', 1000, ['mt_1'], (id) => (id === 'mt_1' ? {
    id: 'mt_1',
    text: '原文',
    source: 'direct',
    level: 'analyzable',
    deleted: false
  } : null));
  assert.strictEqual(rows.length, 1);
  assert.strictEqual(rows[0].reviewId, 'rv_1');
  assert.strictEqual(rows[0].textSnapshot, '原文');
  assert.strictEqual(rows[0].sourceSnapshot, 'direct');
  assert.strictEqual(rows[0].levelSnapshot, 'analyzable');
  assert.strictEqual(rows[0].snapshotMissing, false);
  assert.strictEqual(rows[0].zone, 0);
  assert.strictEqual(rows[0].citedAt, 1000);
});

test('已删除、封存与缺失材料只留空快照', () => {
  const rows = buildRows('rv_1', 1000, ['mt_del', 'mt_seal', 'mt_gone'], (id) => {
    if (id === 'mt_del') {
      return { id: 'mt_del', text: '已删除正文', source: 'direct', level: 'local_only', deleted: true };
    }
    if (id === 'mt_seal') {
      return { id: 'mt_seal', text: '封存正文', source: 'direct', level: 'sealed', deleted: false };
    }
    return null;
  });
  assert.strictEqual(rows.length, 3);
  assert.strictEqual(rows[0].textSnapshot, '');
  assert.strictEqual(rows[0].levelSnapshot, 'local_only');
  assert.strictEqual(rows[0].snapshotMissing, true);
  assert.strictEqual(rows[1].textSnapshot, '');
  assert.strictEqual(rows[1].levelSnapshot, 'sealed');
  assert.strictEqual(rows[1].snapshotMissing, true);
  assert.strictEqual(rows[2].textSnapshot, '');
  assert.strictEqual(rows[2].levelSnapshot, 'local_only');
  assert.strictEqual(rows[2].snapshotMissing, true);
});

test('重复编号只生成一行并跳过已有快照', () => {
  assert.deepStrictEqual(parseMaterialIds({ materialIds: ['mt_2', 'mt_1', 'mt_2', 3] }), ['mt_2', 'mt_1']);
  assert.deepStrictEqual(parseMaterialIds(undefined), []);
  assert.deepStrictEqual(parseMaterialIds({ materialIds: 'mt_1' }), []);
  const rows = buildRows('rv_1', 1000, ['mt_1', 'mt_2', 'mt_1'], () => null);
  assert.deepStrictEqual(rows.map((row) => row.materialId), ['mt_1', 'mt_2']);
  const pending = mergeExisting(rows, ['mt_1']);
  assert.strictEqual(pending.length, 1);
  assert.strictEqual(pending[0].materialId, 'mt_2');
});

const SCHEMA_FILE = path.resolve(__dirname, '../entry/src/main/ets/db/schemas.ts');
const DB_CONFIG_FILE = path.resolve(__dirname, '../entry/src/main/ets/db/DbConfig.ts');

function createTableBlock(source, tableConstant) {
  const marker = 'CREATE TABLE IF NOT EXISTS ${DB_TABLES.' + tableConstant + '} (';
  const start = source.indexOf(marker);
  assert.ok(start >= 0, `缺少建表语句 ${tableConstant}`);
  const end = source.indexOf(')`,', start);
  assert.ok(end > start, `建表语句未闭合 ${tableConstant}`);
  return source.substring(start, end);
}

test('建表语句包含迁移新增的列', () => {
  const source = fs.readFileSync(SCHEMA_FILE, 'utf8');
  const expectations = [
    { table: 'EVENT', columns: ['revision_of', 'version'] },
    { table: 'DECISION', columns: ['done', 'known_conditions'] },
    { table: 'EXPERIENCE_MATERIAL', columns: ['interaction_source'] },
    { table: 'EVIDENCE_ITEM', columns: ['zone'] },
    { table: 'REVIEW_MATERIAL', columns: ['kind_snapshot'] }
  ];
  for (const expectation of expectations) {
    const block = createTableBlock(source, expectation.table);
    for (const column of expectation.columns) {
      assert.ok(block.includes(column), `${expectation.table} 建表语句缺少列 ${column}`);
    }
  }
});

test('首页以今日议程聚合五类对象', () => {
  const source = fs.readFileSync('entry/src/main/ets/views/DashboardView.ets', 'utf8');
  const mapper = fs.readFileSync('entry/src/main/ets/home/AgendaMapper.ts', 'utf8');
  const agenda = fs.readFileSync('entry/src/main/ets/views/dashboard/AgendaCard.ets', 'utf8');
  const home = fs.readFileSync('entry/src/main/ets/pages/HomePage.ets', 'utf8');
  assert.ok(source.includes('AgendaCard'));
  assert.ok(source.includes('buildAgenda'));
  assert.strictEqual(source.includes('home_todo_quiet'), false);
  assert.strictEqual(source.includes('ModuleGridCard'), false);
  assert.ok(agenda.includes('今日实践台'));
  for (const kind of ['PLAN_NODE', 'PREDICTION_SETTLE', 'RELATION_REPLY', 'PREDICTION_OPEN', 'NOTE_TODAY']) {
    assert.ok(mapper.includes(kind), `议程缺少来源 ${kind}`);
  }
  assert.ok(home.includes('bottomNav'));
  assert.ok(home.includes('ROUTES.PLAN'));
});

test('首页读数可关闭且复盘提示可忽略', () => {
  const dashboard = fs.readFileSync('entry/src/main/ets/views/DashboardView.ets', 'utf8');
  assert.ok(dashboard.includes('home_readings_toggle'));
  assert.ok(dashboard.includes('readingsVisible'));
  assert.ok(dashboard.includes('promptVisible'));
  const prompt = fs.readFileSync('entry/src/main/ets/components/ReviewPromptPanel.ets', 'utf8');
  assert.ok(prompt.includes('onDismiss'));
});

test('身份区头像缩到 48', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/ProfileHeader.ets', 'utf8');
  assert.ok(source.includes('this.avatar(48)'));
});

test('关系页不再出现未加工测试', () => {
  const edit = fs.readFileSync('entry/src/main/ets/pages/RelationEditPage.ets', 'utf8');
  const detail = fs.readFileSync('entry/src/main/ets/pages/RelationDetailPage.ets', 'utf8');
  assert.strictEqual(edit.includes('rawMaterialTest'), false);
  assert.strictEqual(edit.includes('未加工'), false);
  assert.strictEqual(detail.includes('未加工'), false);
});

test('计划图显示四类清单计数', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/PlanDetailPage.ets', 'utf8');
  assert.ok(source.includes('plan_disposition_counts'));
  assert.ok(source.includes('完成 ${this.totalDone()}'));
  assert.ok(source.includes('暂停 ${this.totalPaused()}'));
  assert.ok(source.includes('舍弃 ${this.totalDiscarded()}'));
});

test('计划图标注样本范围', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/PlanDetailPage.ets', 'utf8');
  assert.ok(source.includes('plan_sample_note'));
  assert.ok(source.includes('个周节点的清单记录'));
});

test('复盘历史支持周期筛选', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/ReviewHistoryPage.ets', 'utf8');
  assert.ok(source.includes('history_period_week'));
  assert.ok(source.includes('history_period_month'));
  assert.ok(source.includes("this.periodChip('week'"));
});

test('分享前有内容预览', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/SettingsPage.ets', 'utf8');
  assert.ok(source.includes('公共副本预览'));
  assert.ok(source.includes('继续分享'));
  assert.ok(source.includes('分享后文件会离开本机'));
});

test('涉及他人时要求关系与分析边界', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/ReviewAgentPanel.ets', 'utf8');
  assert.ok(source.includes('agent_relation_toggle'));
  assert.ok(source.includes('agent_relation_id'));
  assert.ok(source.includes('agent_relation_boundary'));
  assert.ok(source.includes('不会调用模型'));
});

test('首屏以书写主卡承载汇总', () => {
  const home = fs.readFileSync('entry/src/main/ets/pages/HomePage.ets', 'utf8');
  const dashboard = fs.readFileSync('entry/src/main/ets/views/DashboardView.ets', 'utf8');
  assert.ok(dashboard.includes('home_write_hero'));
  assert.ok(dashboard.includes('home_capture_input'));
  assert.strictEqual(home.includes('总速记'), false);
  assert.strictEqual(dashboard.includes('总速记'), false);
});

test('关系材料接线到禁分析与关系前置', () => {
  const form = fs.readFileSync('entry/src/main/ets/components/ReviewForm.ets', 'utf8');
  const panel = fs.readFileSync('entry/src/main/ets/components/ReviewAgentPanel.ets', 'utf8');
  assert.ok(form.includes('relationForbidsAnalysis: this.relationForbids()'));
  assert.ok(form.includes('relationInvolvedByMaterial: this.hasRelationMaterial()'));
  assert.ok(form.includes('maxLevel: this.relationMaxLevel()'));
  assert.ok(panel.includes('agent_relation_forced'));
  assert.ok(panel.includes('由引用关系材料带入'));
});

test('审计接线写入编号密级与剔除数', () => {
  const agent = fs.readFileSync('entry/src/main/ets/review/ReviewAgent.ts', 'utf8');
  const panel = fs.readFileSync('entry/src/main/ets/components/ReviewAgentPanel.ets', 'utf8');
  assert.ok(agent.includes('materialIds: meta.materialIds'));
  assert.ok(agent.includes('removedCount: meta.removedCount'));
  assert.ok(panel.includes('removedCount: Math.max(0, this.confirmInitialCount - this.confirmItems.length)'));
});

test('安全副本可逐份删除并提示恢复后果', () => {
  const settings = fs.readFileSync('entry/src/main/ets/pages/SettingsPage.ets', 'utf8');
  const inventory = fs.readFileSync('entry/src/main/ets/settings/BackupInventory.ts', 'utf8');
  assert.ok(settings.includes('confirmDeleteCopy'));
  assert.ok(settings.includes('恢复旧备份？'));
  assert.ok(settings.includes('可能带回已删除的记录'));
  assert.ok(inventory.includes('static async deleteOne'));
});

test('首页不再计算连续记录天数', () => {
  const home = fs.readFileSync('entry/src/main/ets/pages/HomePage.ets', 'utf8');
  const data = fs.readFileSync('entry/src/main/ets/data/HomeDataService.ts', 'utf8');
  const preview = fs.readFileSync('entry/src/main/ets/preview/PreviewStore.ts', 'utf8');
  assert.strictEqual(home.includes('streakDays'), false);
  assert.strictEqual(data.includes('streakDays'), false);
  assert.strictEqual(preview.includes('streakDays'), false);
});

test('公共分享副本默认剥离锚点理由', () => {
  const service = fs.readFileSync('entry/src/main/ets/export/ExportService.ts', 'utf8');
  const settings = fs.readFileSync('entry/src/main/ets/pages/SettingsPage.ets', 'utf8');
  assert.ok(service.includes('stripPublicShareLines'));
  assert.ok(service.includes("'锚点理由：'"));
  assert.ok(service.includes("'（对方陈述仅保存在本机）'"));
  assert.ok(settings.includes('公共副本预览'));
  assert.ok(settings.includes('分享公共副本'));
});

test('历史筛选与统计口径已接线', () => {
  const history = fs.readFileSync('entry/src/main/ets/pages/ReviewHistoryPage.ets', 'utf8');
  const analytics = fs.readFileSync('entry/src/main/ets/pages/AnalyticsPage.ets', 'utf8');
  assert.ok(history.includes('history_material_with'));
  assert.ok(history.includes('history_evidence_without'));
  assert.ok(history.includes('item.materialCount ?? 0'));
  assert.ok(analytics.includes('未记录按缺失留空'));
});

test('请求清单显示编号且候选可改写', () => {
  const sheet = fs.readFileSync('entry/src/main/ets/components/RequestConfirmSheet.ets', 'utf8');
  const panel = fs.readFileSync('entry/src/main/ets/components/ReviewAgentPanel.ets', 'utf8');
  assert.ok(sheet.includes('编号 ${item.id}'));
  assert.ok(panel.includes('agent_candidate_edit'));
  assert.ok(panel.includes('填入改写'));
  assert.ok(panel.includes('startEdit(candidate)'));
});

test('复盘一等结果与锚点三问已接线', () => {
  const form = fs.readFileSync('entry/src/main/ets/components/ReviewForm.ets', 'utf8');
  assert.ok(form.includes('review_standing_'));
  assert.ok(form.includes('review_anchor_supports_'));
  assert.ok(form.includes("this.updateAnchorField(anchor.id, 'notApplicable', value)"));
  assert.ok(form.includes("if (this.standing !== 'decided' || this.decisionType === null)"));
});

test('数据库版本为 22 且包含新增列', () => {
  const source = fs.readFileSync(DB_CONFIG_FILE, 'utf8');
  assert.ok(/export const DB_VERSION\s*=\s*22;/.test(source), 'DB_VERSION 不是 22');
  const schema = fs.readFileSync(SCHEMA_FILE, 'utf8');
  assert.ok(schema.includes('removed_count INTEGER NOT NULL DEFAULT 0'));
  assert.ok(schema.includes('depth TEXT'));
  assert.ok(schema.includes('time_budget INTEGER'));
  assert.ok(schema.includes('missing TEXT NOT NULL DEFAULT'));
  assert.ok(schema.includes('explanatory_gain TEXT NOT NULL DEFAULT'));
  assert.ok(schema.includes('participation_mode TEXT'));
  assert.ok(schema.includes('beneficiary TEXT NOT NULL DEFAULT'));
  assert.ok(schema.includes('cost_bearer TEXT NOT NULL DEFAULT'));
  assert.ok(schema.includes('claim_evidence TEXT NOT NULL DEFAULT'));
});

if (failures.length > 0) {
  console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(`PASSED ${passed} / ${passed}`);
