/**
 * Base URL for the local mock server.
 * Previewer: keep 127.0.0.1. Emulator: replace with the host LAN IP.
 */
export const API_BASE_URL = 'http://127.0.0.1:4523';

/** Request timeout in milliseconds. */
export const API_TIMEOUT_MS = 5000;

/** Builds the review prompt endpoint for one period. */
export function reviewPromptsUrl(period: string): string {
  return `${API_BASE_URL}/review-prompts?period=${encodeURIComponent(period)}`;
}
