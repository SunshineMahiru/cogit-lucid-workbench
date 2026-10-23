import { SecurityLevel } from './SecurityLevel';

/** Records a decision: background, options, choice and expected outcome. */
export interface Decision {
  id: string;
  title: string;
  /** Decision background */
  background: string;
  /** Candidate options */
  options: string[];
  /** Final choice */
  choice: string;
  /** Expected outcome */
  expectedOutcome: string;
  /** Decision timestamp in milliseconds */
  timestamp: number;
  relatedEventIds: string[];
  relatedRelationIds: string[];
  /** Security level, defaults to LOCAL_ONLY */
  level: SecurityLevel;
  /** Whether the review is done */
  reviewed: boolean;
}
