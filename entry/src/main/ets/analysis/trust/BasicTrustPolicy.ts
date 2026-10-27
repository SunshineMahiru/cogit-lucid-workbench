import { TrustLevel } from '../../model/TrustLevel';
import { TrustDecision, TrustPolicy, TrustSubject } from './TrustPolicy';

/** Deterministic trust rules: friendly never, sincere only after raw material, transparent unless blocked. */
export class BasicTrustPolicy implements TrustPolicy {
  decide(subject: TrustSubject): TrustDecision {
    if (subject.forbidAnalysis) {
      return { allowMotiveAnalysis: false, reason: '该关系标记为禁分析，只做事实描述' };
    }
    if (subject.trustLevel === TrustLevel.FRIENDLY) {
      return { allowMotiveAnalysis: false, reason: '友好层级不做动机分析' };
    }
    if (subject.trustLevel === TrustLevel.SINCERE) {
      return subject.rawMaterialTest ?
        { allowMotiveAnalysis: true, reason: '真诚层级且通过未加工材料测试' } :
        { allowMotiveAnalysis: false, reason: '真诚层级尚未通过未加工材料测试' };
    }
    return { allowMotiveAnalysis: true, reason: '透明层级允许动机分析' };
  }
}
