import { API_BASE_URL } from './ApiConfig';
import { HttpClient } from './HttpClient';
import { LlmClient, LlmRequest, LlmResponse } from '../analysis/llm/LlmClient';

interface MockResponse {
  model?: string;
  content?: string;
}

/** L1: calls the repo-local mock LLM endpoint; no external data leaves the machine. */
export class LocalMockLlmClient implements LlmClient {
  private client: HttpClient;
  private baseUrl: string;

  constructor(client: HttpClient = new HttpClient(), baseUrl: string = API_BASE_URL) {
    this.client = client;
    this.baseUrl = baseUrl;
  }

  async complete(request: LlmRequest): Promise<LlmResponse> {
    const body = await this.client.postJson(
      `${this.baseUrl}/llm/complete`,
      JSON.stringify(request),
      8000,
      { 'Content-Type': 'application/json' }
    );
    const parsed = JSON.parse(body) as MockResponse;
    if (typeof parsed.content !== 'string' || parsed.content.length === 0) {
      throw new Error('empty mock response');
    }
    return {
      model: typeof parsed.model === 'string' ? parsed.model : request.model,
      content: parsed.content
    };
  }
}
