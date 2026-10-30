import { ReviewPeriod } from '../model/ReviewPeriod';
import { API_BASE_URL, API_TIMEOUT_MS, reviewPromptsUrlForBase, reviewPromptsUrls } from './ApiConfig';
import { HttpClient } from './HttpClient';
import { ReviewPrompt, parseReviewPrompts } from './ReviewPrompt';
import { ReviewPromptRepository } from './ReviewPromptRepository';

/** Fetches review prompts from the local mock server, trying the configured host and fallback. */
export class HttpReviewPromptRepository implements ReviewPromptRepository {
  private client: HttpClient;
  private baseUrl: string;

  constructor(client: HttpClient = new HttpClient(), baseUrl: string = API_BASE_URL) {
    this.client = client;
    this.baseUrl = baseUrl;
  }

  async fetch(period: ReviewPeriod): Promise<ReviewPrompt[]> {
    const urls: string[] = [reviewPromptsUrlForBase(this.baseUrl, period)];
    for (const fallback of reviewPromptsUrls(period)) {
      if (!urls.includes(fallback)) {
        urls.push(fallback);
      }
    }
    for (const url of urls) {
      try {
        const body = await this.client.getJson(url, API_TIMEOUT_MS);
        return parseReviewPrompts(body);
      } catch (error) {
      }
    }
    throw new Error('review prompt endpoint unavailable');
  }
}
