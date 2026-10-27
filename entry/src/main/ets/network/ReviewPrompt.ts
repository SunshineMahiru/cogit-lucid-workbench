/** One prompt returned by the mock review endpoint. */
export interface ReviewPrompt {
  id: string;
  text: string;
  category: string;
}

interface PromptPayload {
  prompts?: ReviewPrompt[];
}

/**
 * Parses and validates the prompt payload.
 * Throws on malformed data; an empty prompts array is a valid empty state.
 */
export function parseReviewPrompts(body: string): ReviewPrompt[] {
  const payload = JSON.parse(body) as PromptPayload;
  if (!Array.isArray(payload.prompts)) {
    throw new Error('invalid prompt payload');
  }
  const prompts: ReviewPrompt[] = [];
  for (const item of payload.prompts) {
    if (typeof item.id !== 'string' || typeof item.text !== 'string' ||
      typeof item.category !== 'string' || item.text.trim().length === 0) {
      throw new Error('invalid prompt item');
    }
    prompts.push({ id: item.id, text: item.text, category: item.category });
  }
  return prompts;
}
