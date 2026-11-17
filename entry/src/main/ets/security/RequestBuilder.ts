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
  const keepRelation = keepIds.includes('relation');
  return {
    facts: keepIds.includes('facts') ? raw.facts : '',
    interpretation: keepIds.includes('interpretation') ? raw.interpretation : '',
    anchors: anchors,
    factsLevel: raw.factsLevel,
    interpretationLevel: raw.interpretationLevel,
    relationForbidsAnalysis: raw.relationForbidsAnalysis,
    relationInvolved: raw.relationInvolved === true,
    relationId: keepRelation ? (raw.relationId ?? '') : '',
    relationBoundary: keepRelation ? (raw.relationBoundary ?? '') : ''
  };
}

/** The single outbound model request path: decides which material may leave this device. */
export function buildAnalysisInput(raw: ContradictionInput, provider: LlmProvider): BuildResult {
  const dropped: DroppedItem[] = [];
  const allowed = (level: SecurityLevel): boolean =>
    provider === 'template' ? level !== SecurityLevel.SEALED : level === SecurityLevel.ANALYZABLE;
  if (raw.relationForbidsAnalysis === true) {
    dropped.push({ kind: 'relation', reason: '关系已禁止分析' });
    return {
      input: {
        facts: '',
        interpretation: '',
        anchors: [],
        factsLevel: SecurityLevel.LOCAL_ONLY,
        interpretationLevel: SecurityLevel.LOCAL_ONLY,
        relationForbidsAnalysis: true,
        relationInvolved: false,
        relationId: '',
        relationBoundary: ''
      },
      dropped
    };
  }
  if (raw.relationInvolved === true) {
    const relationId = (raw.relationId ?? '').trim();
    const boundary = (raw.relationBoundary ?? '').trim();
    if (relationId.length === 0 || boundary.length === 0) {
      dropped.push({
        kind: 'relation',
        reason: relationId.length === 0 ? '关系材料未绑定关系' : '关系材料未填写分析边界'
      });
      if (provider !== 'template') {
        return {
          input: {
            facts: '',
            interpretation: '',
            anchors: [],
            factsLevel: SecurityLevel.LOCAL_ONLY,
            interpretationLevel: SecurityLevel.LOCAL_ONLY,
            relationForbidsAnalysis: false,
            relationInvolved: true,
            relationId: relationId,
            relationBoundary: ''
          },
          dropped
        };
      }
      // Offline template keeps facts for local organizing but drops the unconfirmed relation context.
      return {
        input: {
          facts: allowed(raw.factsLevel) ? raw.facts : '',
          interpretation: allowed(raw.interpretationLevel) ? raw.interpretation : '',
          anchors: raw.anchors.filter((anchor) => allowed(anchor.level ?? SecurityLevel.LOCAL_ONLY)),
          factsLevel: raw.factsLevel,
          interpretationLevel: raw.interpretationLevel,
          relationForbidsAnalysis: false,
          relationInvolved: false,
          relationId: '',
          relationBoundary: ''
        },
        dropped
      };
    }
  }
  let facts = raw.facts;
  let interpretation = raw.interpretation;
  if (!allowed(raw.factsLevel)) {
    facts = '';
    if (raw.facts.length > 0) {
      dropped.push({ kind: 'facts', reason: provider === 'template' ? '封存内容不进入分析' : '现场内容不是可分析级' });
    }
  }
  if (!allowed(raw.interpretationLevel)) {
    interpretation = '';
    if (raw.interpretation.length > 0) {
      dropped.push({ kind: 'interpretation', reason: provider === 'template' ? '封存内容不进入分析' : '解释内容不是可分析级' });
    }
  }
  const anchors = raw.anchors.filter((anchor) => {
    if (allowed(anchor.level ?? SecurityLevel.LOCAL_ONLY)) {
      return true;
    }
    dropped.push({ kind: 'anchor', id: anchor.id, reason: provider === 'template' ? '封存锚点不进入分析' : '锚点不是可分析级' });
    return false;
  });
  return {
    input: {
      facts: facts,
      interpretation: interpretation,
      anchors: anchors,
      factsLevel: raw.factsLevel,
      interpretationLevel: raw.interpretationLevel,
      relationForbidsAnalysis: false,
      relationInvolved: raw.relationInvolved === true,
      relationId: raw.relationId ?? '',
      relationBoundary: raw.relationBoundary ?? ''
    },
    dropped: dropped
  };
}