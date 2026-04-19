export type CheckinType = "daily" | "post_activity" | "pre_visit";

export interface DailyCheckinRecord {
  id: string;
  client_id: string;
  clinic_id: string;
  checkin_type: CheckinType;
  overall_feeling: number;
  target_regions: Array<Record<string, unknown>>;
  activity_since_last: string | null;
  recovery_score: number | null;
  created_at: string;
  updated_at?: string;
}
