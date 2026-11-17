'use strict';

/**
 * 阶段 1 的隐私出口验证：buildAnalysisInput 是唯一允许决定「什么能离开本机」的地方。
 * 这里只测纯逻辑，不碰界面。
 */

const assert = require('assert');

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

function load() {
  const { buildAnalysisInput, filterConfirmedInput } = require('./out2/security/RequestBuilder');
  const { SecurityLevel } = require('./out2/model/SecurityLevel');
  return { buildAnalysisInput, filterConfirmedInput, SecurityLevel };
}

function makeInput(SecurityLevel, factsLevel, interpretationLevel, anchorLevels, relationForbids) {
  return {
    facts: '现场内容',
    interpretation: '解释内容',
    anchors: anchorLevels.map((level, index) => ({
      id: `a${index + 1}`,
      text: `锚点${index + 1}`,
      source: 'self',
      order: index,
      level: level
    })),
    factsLevel: factsLevel,
    interpretationLevel: interpretationLevel,
    relationForbidsAnalysis: relationForbids === true
  };
}

test('模板提供者剔除封存内容，不再原样放行', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.SEALED, SecurityLevel.SEALED, [SecurityLevel.SEALED], false);
  const result = buildAnalysisInput(input, 'template');
  assert.strictEqual(result.input.facts, '');
  assert.strictEqual(result.input.interpretation, '');
  assert.strictEqual(result.input.anchors.length, 0);
  assert.strictEqual(result.dropped.length, 3);
});

test('模板提供者放行仅本地与可分析内容', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.LOCAL_ONLY, SecurityLevel.ANALYZABLE, [SecurityLevel.LOCAL_ONLY, SecurityLevel.SEALED], false);
  const result = buildAnalysisInput(input, 'template');
  assert.strictEqual(result.input.facts, '现场内容');
  assert.strictEqual(result.input.interpretation, '解释内容');
  assert.strictEqual(result.input.anchors.length, 1);
  assert.strictEqual(result.dropped.length, 1);
});

test('禁止分析的关系在模板路径同样整条拦下', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [SecurityLevel.ANALYZABLE], true);
  const result = buildAnalysisInput(input, 'template');
  assert.strictEqual(result.input.facts, '');
  assert.strictEqual(result.input.anchors.length, 0);
  assert.ok(result.dropped.some((item) => item.kind === 'relation'));
});

test('关系未确认时模板保留现场做离线整理但剔除关系上下文', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [SecurityLevel.ANALYZABLE], false);
  input.relationInvolved = true;
  input.relationId = '';
  input.relationBoundary = '';
  const result = buildAnalysisInput(input, 'template');
  assert.strictEqual(result.input.facts, '现场内容');
  assert.strictEqual(result.input.relationInvolved, false);
  assert.strictEqual(result.input.relationId, '');
  assert.ok(result.dropped.some((item) => item.kind === 'relation'));
});

test('本地模拟只放行可分析内容', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.LOCAL_ONLY, [SecurityLevel.ANALYZABLE, SecurityLevel.LOCAL_ONLY], false);
  const result = buildAnalysisInput(input, 'mock');
  assert.strictEqual(result.input.facts, '现场内容');
  assert.strictEqual(result.input.interpretation, '');
  assert.strictEqual(result.input.anchors.length, 1);
  assert.strictEqual(result.dropped.length, 2);
  assert.deepStrictEqual(result.dropped.map((item) => item.kind).sort(), ['anchor', 'interpretation']);
});

test('网络模型同样只放行可分析内容', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.LOCAL_ONLY, SecurityLevel.LOCAL_ONLY, [SecurityLevel.SEALED], false);
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.facts, '');
  assert.strictEqual(result.input.interpretation, '');
  assert.strictEqual(result.input.anchors.length, 0);
  assert.strictEqual(result.dropped.length, 3);
});

test('禁止分析的关系整条拦下，与材料密级无关', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [SecurityLevel.ANALYZABLE], true);
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.facts, '');
  assert.strictEqual(result.input.interpretation, '');
  assert.strictEqual(result.input.anchors.length, 0);
  assert.strictEqual(result.dropped.length, 1);
  assert.strictEqual(result.dropped[0].kind, 'relation');
});

test('锚点缺省密级按仅本地处理', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = {
    facts: '现场',
    interpretation: '解释',
    anchors: [{ id: 'a1', text: '没有密级的锚点', source: 'self', order: 0 }],
    factsLevel: SecurityLevel.ANALYZABLE,
    interpretationLevel: SecurityLevel.ANALYZABLE,
    relationForbidsAnalysis: false
  };
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.anchors.length, 0);
  assert.strictEqual(result.dropped[0].kind, 'anchor');
});

test('被丢弃的条目不带正文', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = {
    facts: 'MARKER_FACT_7f3a',
    interpretation: 'MARKER_INTERP_9c1b',
    anchors: [{ id: 'a1', text: 'MARKER_ANCHOR_2d8e', source: 'self', order: 0, level: SecurityLevel.SEALED }],
    factsLevel: SecurityLevel.SEALED,
    interpretationLevel: SecurityLevel.SEALED,
    relationForbidsAnalysis: false
  };
  const result = buildAnalysisInput(input, 'model');
  const serialized = JSON.stringify(result.dropped);
  assert.ok(!serialized.includes('MARKER_FACT_7f3a'), '丢弃记录里出现了现场正文');
  assert.ok(!serialized.includes('MARKER_INTERP_9c1b'), '丢弃记录里出现了解释正文');
  assert.ok(!serialized.includes('MARKER_ANCHOR_2d8e'), '丢弃记录里出现了锚点正文');
});

test('确认清单只保留选中项', () => {
  const { filterConfirmedInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE,
    [SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE], false);
  const filtered = filterConfirmedInput(input, ['facts', 'anchor:a2']);
  assert.strictEqual(filtered.facts, '现场内容');
  assert.strictEqual(filtered.interpretation, '');
  assert.strictEqual(filtered.anchors.length, 1);
  assert.strictEqual(filtered.anchors[0].id, 'a2');
});

test('清单全部移除后不发送正文', () => {
  const { filterConfirmedInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE,
    [SecurityLevel.ANALYZABLE], false);
  const filtered = filterConfirmedInput(input, []);
  assert.strictEqual(filtered.facts, '');
  assert.strictEqual(filtered.interpretation, '');
  assert.strictEqual(filtered.anchors.length, 0);
});

test('涉及他人未绑定关系时整条拦下', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [], false);
  input.relationInvolved = true;
  input.relationId = '';
  input.relationBoundary = '只讨论我自己的反应';
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.facts, '');
  assert.strictEqual(result.input.interpretation, '');
  assert.strictEqual(result.dropped[0].kind, 'relation');
  assert.ok(result.dropped[0].reason.includes('未绑定关系'));
});

test('涉及他人未写分析边界时整条拦下', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [], false);
  input.relationInvolved = true;
  input.relationId = 'rl_1';
  input.relationBoundary = '';
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.facts, '');
  assert.ok(result.dropped[0].reason.includes('分析边界'));
});

test('关系与分析边界齐备后才放行', () => {
  const { buildAnalysisInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [], false);
  input.relationInvolved = true;
  input.relationId = 'rl_1';
  input.relationBoundary = '只讨论我自己的反应';
  const result = buildAnalysisInput(input, 'model');
  assert.strictEqual(result.input.facts, '现场内容');
  assert.strictEqual(result.input.relationId, 'rl_1');
  assert.strictEqual(result.dropped.length, 0);
});

test('确认清单移除关系项后关系字段清空', () => {
  const { filterConfirmedInput, SecurityLevel } = load();
  const input = makeInput(SecurityLevel, SecurityLevel.ANALYZABLE, SecurityLevel.ANALYZABLE, [], false);
  input.relationInvolved = true;
  input.relationId = 'rl_1';
  input.relationBoundary = '只讨论我自己的反应';
  const filtered = filterConfirmedInput(input, ['facts']);
  assert.strictEqual(filtered.relationId, '');
  assert.strictEqual(filtered.relationBoundary, '');
});

if (failures.length > 0) {
  console.error(`FAILED ${failures.length} / ${passed + failures.length}`);
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(`PASSED ${passed} / ${passed}`);
