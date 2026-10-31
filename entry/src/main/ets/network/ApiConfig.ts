/**
 * Base URL for the local mock server.
 * Emulator and Previewer reach it through localhost plus hdc port forwarding;
 * a real device must point the setting at its own host.
 */
export const API_BASE_URL = 'http://localhost:4523';

/** Request timeout in milliseconds. */
export const API_TIMEOUT_MS = 5000;

/** Builds the review prompt endpoint for one base URL. */
export function reviewPromptsUrlForBase(baseUrl: string, period: string): string {
  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, baseUrl.length - 1) : baseUrl;
  return `${base}/review-prompts?period=${encodeURIComponent(period)}`;
}

/** Builds the review prompt endpoint for the default local mock server. */
export function reviewPromptsUrl(period: string): string {
  return reviewPromptsUrlForBase(API_BASE_URL, period);
}
