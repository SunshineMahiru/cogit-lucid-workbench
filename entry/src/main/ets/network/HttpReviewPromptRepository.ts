import { ReviewPeriod } from '../model/ReviewPeriod';
import { API_TIMEOUT_MS, reviewPromptsUrl } from './ApiConfig';
import { HttpClient } from './HttpClient';
import { ReviewPrompt, parseReviewPrompts } from './ReviewPrompt';
import { ReviewPromptRepository } from './ReviewPromptRepository';

/** Fetches review prompts from the local mock server. */
export class HttpReviewPromptRepository implements ReviewPromptRepository {
  private client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async fetch(period: ReviewPeriod): Promise<ReviewPrompt[]> {
    const body = await this.client.getJson(reviewPromptsUrl(period), API_TIMEOUT_MS);
    return parseReviewPrompts(body);
  }
}
