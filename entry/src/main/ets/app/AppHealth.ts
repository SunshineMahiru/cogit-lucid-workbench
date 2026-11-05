/** Startup state of the on-device database, read by the home page. */
export enum DbStatus {
  CHECKING = 'checking',
  READY = 'ready',
  FAILED = 'failed'
}

/** Capability-missing code reported where relationalStore is not available, e.g. the Previewer. */
export const DB_UNSUPPORTED_CODE = 801;

/** True when the platform has no relationalStore at all; such runs fall back to demo data. */
export function isDatabaseUnsupported(code: number): boolean {
  return code === DB_UNSUPPORTED_CODE;
}

class AppHealthStore {
  private status: DbStatus = DbStatus.CHECKING;
  private detail: string = '';

  markReady(): void {
    this.status = DbStatus.READY;
    this.detail = '';
  }

  markFailed(detail: string): void {
    this.status = DbStatus.FAILED;
    this.detail = detail;
  }

  reset(): void {
    this.status = DbStatus.CHECKING;
    this.detail = '';
  }

  current(): DbStatus {
    return this.status;
  }

  message(): string {
    return this.detail;
  }
}

/** Shared across the ability and the pages; not reactive, pages keep their own mirror. */
export const appHealth = new AppHealthStore();
