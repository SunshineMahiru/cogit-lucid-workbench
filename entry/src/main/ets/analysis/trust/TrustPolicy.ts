import { TrustLevel } from '../../model/TrustLevel';

/** Minimal relation data the trust policy needs. */
export interface TrustSubject {
  trustLevel: TrustLevel;
  rawMaterialTest: boolean;
  forbidAnalysis: boolean;
}

/** Whether motive analysis is allowed, plus the reason shown to the user. */
export interface TrustDecision {
  allowMotiveAnalysis: boolean;
  reason: string;
}

/**
 * Contract for the trust tier rules.
 * The implementation lands in 6.4 with the relation graph work.
 */
export interface TrustPolicy {
  decide(subject: TrustSubject): TrustDecision;
}
