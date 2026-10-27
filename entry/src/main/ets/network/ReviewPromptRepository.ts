import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewPrompt } from './ReviewPrompt';

/** Contract for fetching review prompts; a fake implementation can replace it in tests. */
export interface ReviewPromptRepository {
  fetch(period: ReviewPeriod): Promise<ReviewPrompt[]>;
}
