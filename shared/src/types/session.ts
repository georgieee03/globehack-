export type SessionStatus =
  | "pending"
  | "active"
  | "paused"
  | "completed"
  | "cancelled"
  | "error";

export interface SessionRecord {
  id: string;
  client_id: string;
  clinic_id: string;
  practitioner_id: string;
  device_id: string;
  assessment_id: string | null;
  session_config: Record<string, unknown>;
  recommended_config: Record<string, unknown> | null;
  practitioner_edits: Record<string, unknown> | null;
  recommendation_rationale: string | null;
  confidence_score: number | null;
  status: SessionStatus;
  started_at: string | null;
  paused_at: string | null;
  resumed_at: string | null;
  completed_at: string | null;
  total_duration_s: number | null;
  outcome: Record<string, unknown> | null;
  practitioner_notes: string | null;
  retest_values: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
}
