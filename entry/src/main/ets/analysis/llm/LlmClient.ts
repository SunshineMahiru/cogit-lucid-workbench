export type LlmRole = 'system' | 'user' | 'assistant';

export interface LlmMessage {
  role: LlmRole;
  content: string;
}

export interface LlmRequest {
  model: string;
  messages: LlmMessage[];
  temperature: number;
}

export interface LlmResponse {
  model: string;
  content: string;
}

/**
 * Adapter boundary for any LLM provider.
 * No implementation is committed yet; the template analyzer stays the default,
 * and the network-backed client arrives in 6.2 behind this interface.
 */
export interface LlmClient {
  complete(request: LlmRequest): Promise<LlmResponse>;
}
