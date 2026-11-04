/** Shapes returned by the remote analytics JSON. */

export interface StatsMonth {
  label: string;
  settled: number;
  hit: number;
  hitRate: number;
}

export interface StatsCalibration {
  bucket: string;
  predicted: number;
  actual: number;
  samples: number;
}

export interface StatsOutcome {
  hit: number;
  miss: number;
  void: number;
  superseded: number;
}

export interface StatsConfidence {
  bucket: string;
  count: number;
}

export interface StatsHorizon {
  label: string;
  hitRate: number;
  samples: number;
}

export interface StatsReading {
  date: string;
  sleep: number;
  exercise: number;
  alert: number;
}

export interface StatsSleepBucket {
  label: string;
  hitRate: number;
  samples: number;
}

export interface StatsInteraction {
  alias: string;
  count: number;
}

export interface StatsCoverage {
  date: string;
  recorded: boolean;
}

export interface StatsActivity {
  weekday: number;
  hour: number;
  count: number;
}

export interface StatsMonthDetail {
  month: string;
  calibration: StatsCalibration[];
  outcomes: StatsOutcome;
  confidence: StatsConfidence[];
  horizon: StatsHorizon[];
  readings: StatsReading[];
  sleepBuckets: StatsSleepBucket[];
  interactions: StatsInteraction[];
  coverage: StatsCoverage[];
  activity: StatsActivity[];
}

export interface RemoteStats {
  generatedAt: string;
  range: string;
  months: StatsMonth[];
  calibration: StatsCalibration[];
  outcomes: StatsOutcome;
  confidence: StatsConfidence[];
  horizon: StatsHorizon[];
  readings: StatsReading[];
  sleepBuckets: StatsSleepBucket[];
  interactions: StatsInteraction[];
  coverage: StatsCoverage[];
  activity: StatsActivity[];
  monthly: StatsMonthDetail[];
}

interface RemoteStatsPayload {
  generatedAt?: string;
  range?: string;
  months?: StatsMonth[];
  calibration?: StatsCalibration[];
  outcomes?: StatsOutcome;
  confidence?: StatsConfidence[];
  horizon?: StatsHorizon[];
  readings?: StatsReading[];
  sleepBuckets?: StatsSleepBucket[];
  interactions?: StatsInteraction[];
  coverage?: StatsCoverage[];
  activity?: StatsActivity[];
  monthly?: StatsMonthDetail[];
}

function needArray(value: Object | undefined, name: string): void {
  if (!Array.isArray(value)) {
    throw new Error(`invalid stats payload: ${name}`);
  }
}

/** Parses the remote payload; empty arrays are valid, missing sections are not. */
export function parseRemoteStats(body: string): RemoteStats {
  const payload = JSON.parse(body) as RemoteStatsPayload;
  needArray(payload.months, 'months');
  needArray(payload.calibration, 'calibration');
  needArray(payload.confidence, 'confidence');
  needArray(payload.horizon, 'horizon');
  needArray(payload.readings, 'readings');
  needArray(payload.sleepBuckets, 'sleepBuckets');
  needArray(payload.interactions, 'interactions');
  needArray(payload.coverage, 'coverage');
  needArray(payload.activity, 'activity');
  needArray(payload.monthly, 'monthly');
  if (payload.outcomes === undefined) {
    throw new Error('invalid stats payload: outcomes');
  }
  return {
    generatedAt: typeof payload.generatedAt === 'string' ? payload.generatedAt : '',
    range: typeof payload.range === 'string' ? payload.range : '',
    months: payload.months as StatsMonth[],
    calibration: payload.calibration as StatsCalibration[],
    outcomes: payload.outcomes as StatsOutcome,
    confidence: payload.confidence as StatsConfidence[],
    horizon: payload.horizon as StatsHorizon[],
    readings: payload.readings as StatsReading[],
    sleepBuckets: payload.sleepBuckets as StatsSleepBucket[],
    interactions: payload.interactions as StatsInteraction[],
    coverage: payload.coverage as StatsCoverage[],
    activity: payload.activity as StatsActivity[],
    monthly: payload.monthly as StatsMonthDetail[]
  };
}
