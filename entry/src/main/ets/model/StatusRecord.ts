/**
 * 状态记录（StatusRecord）。
 * 状态监测面板的数据源：睡眠、运动、凌晨报警；生理读数优先展示。
 */
export interface StatusRecord {
  id: string;
  /** 日期，格式 YYYY-MM-DD */
  date: string;
  /** 睡眠时长（小时） */
  sleepHours: number;
  /** 运动次数 */
  exerciseCount: number;
  /** 凌晨报警记录数（01:00 后触发） */
  alertCount: number;
  note: string;
}
