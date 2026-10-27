import { BasicTrustPolicy } from '../analysis/trust/BasicTrustPolicy';
import { TrustDecision } from '../analysis/trust/TrustPolicy';
import { RelationDetail } from './RelationListItem';

/** Applies the trust policy to a relation detail projection. */
export function relationTrustDecision(detail: RelationDetail): TrustDecision {
  const policy = new BasicTrustPolicy();
  return policy.decide({
    trustLevel: detail.trustLevel,
    rawMaterialTest: detail.rawMaterialTest,
    forbidAnalysis: detail.forbidAnalysis
  });
}
