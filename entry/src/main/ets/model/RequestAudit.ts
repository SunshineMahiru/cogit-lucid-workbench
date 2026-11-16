/** One outbound model request, recorded without any material text. */
export interface RequestAudit {
  id: string;
  provider: string;
  host: string;
  materialIds: string[];
  levels: string[];
  chars: number;
  confirmed: boolean;
  fellBack: boolean;
  /** Items the author removed from the confirmation sheet; text is never stored */
  removedCount: number;
  createdAt: number;
}