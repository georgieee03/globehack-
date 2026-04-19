export type AssessmentType =
  | "intake"
  | "pre_session"
  | "follow_up"
  | "reassessment";

export interface AssessmentRecord {
  id: string;
  client_id: string;
  clinic_id: string;
  practitioner_id: string | null;
  assessment_type: AssessmentType;
  quickpose_data: Record<string, unknown> | null;
  rom_values: Record<string, number> | null;
  asymmetry_scores: Record<string, number> | null;
  movement_quality_scores: Record<string, number> | null;
  gait_metrics: Record<string, number> | null;
  heart_rate: number | null;
  breath_rate: number | null;
  hrv_rmssd: number | null;
  body_zones: Record<string, unknown> | null;
  recovery_goal: string | null;
  subjective_baseline: Record<string, unknown> | null;
  recovery_map: Record<string, unknown> | null;
  recovery_graph_delta: Record<string, unknown> | null;
  created_at: string;
}
