import { ReviewPeriod } from '../model/ReviewPeriod';
import { API_BASE_URL, API_TIMEOUT_MS, reviewPromptsUrlForBase } from './ApiConfig';
import { HttpClient } from './HttpClient';
import { ReviewPrompt, parseReviewPrompts } from './ReviewPrompt';
import { ReviewPromptRepository } from './ReviewPromptRepository';

/** Fetches review prompts from the configured mock server. */
export class HttpReviewPromptRepository implements ReviewPromptRepository {
  private client: HttpClient;
  private baseUrl: string;

  constructor(client: HttpClient = new HttpClient(), baseUrl: string = API_BASE_URL) {
    this.client = client;
    this.baseUrl = baseUrl;
  }

  async fetch(period: ReviewPeriod): Promise<ReviewPrompt[]> {
    const body = await this.client.getJson(reviewPromptsUrlForBase(this.baseUrl, period), API_TIMEOUT_MS);
    return parseReviewPrompts(body);
  }
}
