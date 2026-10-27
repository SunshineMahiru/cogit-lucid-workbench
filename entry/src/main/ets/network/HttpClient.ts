import { http } from '@kit.NetworkKit';

/** HTTP failure with the status code kept for diagnostics. */
export class HttpError extends Error {
  readonly statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

/** Minimal JSON-over-HTTP client; one request per instance. */
export class HttpClient {
  async getJson(url: string, timeoutMs: number): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new HttpError(`HTTP ${response.responseCode}`, response.responseCode);
      }
      const body = response.result;
      return typeof body === 'string' ? body : JSON.stringify(body);
    } finally {
      request.destroy();
    }
  }
}
