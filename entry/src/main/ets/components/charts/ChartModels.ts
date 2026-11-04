/** Shared shapes for the remote analytics dashboard. */
export interface ChartPoint {
  label: string;
  value: number;
  note: string;
}

export interface ChartSeries {
  name: string;
  color: number;
  points: ChartPoint[];
}

export interface ChartSlice {
  label: string;
  value: number;
  color: number;
}

export interface HeatCell {
  row: number;
  column: number;
  value: number;
}

export interface HeatmapData {
  rows: string[];
  columns: string[];
  cells: HeatCell[];
  legend: string;
}
