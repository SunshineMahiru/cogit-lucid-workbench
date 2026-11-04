import { HttpClient } from './HttpClient';
import { RemoteStats, parseRemoteStats } from './RemoteStats';

const GITEE_BASE = 'https://gitee.com/theangelnextdoor/cogit-lucid-workbench/raw/main/docs/mock';
const GITHUB_BASE = 'https://raw.githubusercontent.com/SunshineMahiru/cogit-lucid-workbench/main/docs/mock';
const TIMEOUT_MS = 6000;

export type StatsRange = '6m' | '12m';

/** Loads analytics JSON from Gitee first, then GitHub; throws only after both fail. */
export class RemoteStatsRepository {
  private client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async fetch(range: StatsRange): Promise<RemoteStats> {
    const suffix = `/stats-${range}.json?t=${Date.now()}`;
    const urls: string[] = [`${GITEE_BASE}${suffix}`, `${GITHUB_BASE}${suffix}`];
    let lastMessage = 'stats unavailable';
    for (const url of urls) {
      try {
        const body = await this.client.getJson(url, TIMEOUT_MS);
        return parseRemoteStats(body);
      } catch (error) {
        lastMessage = error instanceof Error ? error.message : 'stats unavailable';
      }
    }
    throw new Error(lastMessage);
  }
}
