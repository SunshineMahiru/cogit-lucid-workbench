import { LlmClient, LlmRequest, LlmResponse } from '../analysis/llm/LlmClient';

/**
 * L3 placeholder. Xiaoyi is an agent platform, not a raw inference API:
 * the app can only pull up a published agent via Agent Framework Kit, which
 * is absent from the current SDK. Kept here so the seam and the reason are explicit.
 */
export class XiaoyiAgentClient implements LlmClient {
  async complete(request: LlmRequest): Promise<LlmResponse> {
    throw new Error('Xiaoyi agent client unavailable: requires Agent Framework Kit and a published agent');
  }
}
