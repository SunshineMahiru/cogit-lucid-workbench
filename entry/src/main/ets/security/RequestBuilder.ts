import { SecurityLevel } from '../model/SecurityLevel';
import { LlmProvider } from '../settings/AppSettings';
import { ContradictionInput } from '../analysis/contradiction/ContradictionAnalyzer';

export type DroppedKind = 'facts' | 'interpretation' | 'anchor' | 'relation';

export interface DroppedItem {
  kind: DroppedKind;
  id?: string;
  reason: string;
}

export interface BuildResult {
  input: ContradictionInput;
  dropped: DroppedItem[];
}

/** Keeps only the items the user left in the confirmation sheet. */
export function filterConfirmedInput(raw: ContradictionInput, keepIds: string[]): ContradictionInput {
  const anchors = raw.anchors.filter((anchor) => keepIds.includes(`anchor:${anchor.id}`));
  return {
    facts: keepIds.includes('facts') ? raw.facts : '',
    interpretation: keepIds.includes('interpretation') ? raw.interpretation : '',
    anchors: anchors,
    factsLevel: raw.factsLevel,
    interpretationLevel: raw.interpretationLevel,
    relationForbidsAnalysis: raw.relationForbidsAnalysis
  };
}

/** The single outbound model request path: decides which material may leave this device. */
export function buildAnalysisInput(raw: ContradictionInput, provider: LlmProvider): BuildResult {
  const dropped: DroppedItem[] = [];
  if (provider === 'template') {
    return { input: raw, dropped };
  }
  if (raw.relationForbidsAnalysis === true) {
    dropped.push({ kind: 'relation', reason: '关系已禁止分析' });
    return {
      input: {
        facts: '',
        interpretation: '',
        anchors: [],
        factsLevel: SecurityLevel.LOCAL_ONLY,
        interpretationLevel: SecurityLevel.LOCAL_ONLY,
        relationForbidsAnalysis: true
      },
      dropped
    };
  }
  let facts = raw.facts;
  let interpretation = raw.interpretation;
  if (raw.factsLevel !== SecurityLevel.ANALYZABLE) {
    facts = '';
    if (raw.facts.length > 0) {
      dropped.push({ kind: 'facts', reason: '现场内容不是可分析级' });
    }
  }
  if (raw.interpretationLevel !== SecurityLevel.ANALYZABLE) {
    interpretation = '';
    if (raw.interpretation.length > 0) {
      dropped.push({ kind: 'interpretation', reason: '解释内容不是可分析级' });
    }
  }
  const anchors = raw.anchors.filter((anchor) => {
    if (anchor.level === SecurityLevel.ANALYZABLE) {
      return true;
    }
    dropped.push({ kind: 'anchor', id: anchor.id, reason: '锚点不是可分析级' });
    return false;
  });
  return {
    input: {
      facts: facts,
      interpretation: interpretation,
      anchors: anchors,
      factsLevel: raw.factsLevel,
      interpretationLevel: raw.interpretationLevel,
      relationForbidsAnalysis: false
    },
    dropped: dropped
  };
}