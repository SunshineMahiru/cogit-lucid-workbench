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
  createdAt: number;
}