import { HttpClient } from './HttpClient';
import { LlmClient, LlmRequest, LlmResponse } from '../analysis/llm/LlmClient';

interface ChatMessage {
  content?: string;
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatResponse {
  model?: string;
  choices?: ChatChoice[];
}

/** L2: OpenAI-compatible chat completions; key is optional for local endpoints. */
export class OpenAiCompatibleClient implements LlmClient {
  private client: HttpClient;
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string, apiKey: string, client: HttpClient = new HttpClient()) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, baseUrl.length - 1) : baseUrl;
    this.apiKey = apiKey;
    this.client = client;
  }

  async complete(request: LlmRequest): Promise<LlmResponse> {
    const headers: Object = {
      'Content-Type': 'application/json',
      'Authorization': this.apiKey.length > 0 ? `Bearer ${this.apiKey}` : ''
    };
    const body = await this.client.postJson(
      `${this.baseUrl}/chat/completions`,
      JSON.stringify({
        model: request.model,
        messages: request.messages,
        temperature: request.temperature
      }),
      20000,
      headers
    );
    const parsed = JSON.parse(body) as ChatResponse;
    if (parsed.choices === undefined || parsed.choices.length === 0 ||
      parsed.choices[0].message === undefined ||
      typeof parsed.choices[0].message?.content !== 'string') {
      throw new Error('invalid chat response');
    }
    return {
      model: typeof parsed.model === 'string' ? parsed.model : request.model,
      content: parsed.choices[0].message?.content as string
    };
  }
}
