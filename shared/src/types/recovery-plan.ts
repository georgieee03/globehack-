import type { ActivityTrigger, BodyRegion, RecoveryGoal, RecoverySignal, RecoverySignalType } from "./client-profile.js";

export type ExerciseSymptom =
  | RecoverySignalType
  | "post_activity_discomfort";

export type ContentHost = "youtube" | "professional_platform";

export type ApprovedExerciseSource =
  | "hinge_health"
  | "ask_doctor_jo"
  | "hospital_for_special_surgery";

export type PlaybackMode =
  | "in_app_browser"
  | "embedded_web"
  | "external_browser";

export type SourceQualityTier =
  | "academic_medical"
  | "pt_reviewed_platform"
  | "licensed_pt_creator"
  | "fitness_educator";

export type ReviewStatus =
  | "pending_review"
  | "approved"
  | "rejected"
  | "archived";

export type EvidenceTier =
  | "direct"
  | "mirrored"
  | "schema_supported"
  | "derived";

export type PlanStatus =
  | "active"
  | "superseded"
  | "paused_for_safety"
  | "completed"
  | "archived";

export type PlanRefreshReason =
  | "initial_intake"
  | "goal_change"
  | "signal_change"
  | "assessment_change"
  | "stale_plan"
  | "manual_refresh";

export type PlanCadence =
  | "daily"
  | "post_activity"
  | "morning"
  | "evening";

export type RecoveryPlanItemRole = "required" | "optional_support";

export type CompletionStatus =
  | "started"
  | "completed"
  | "skipped"
  | "stopped";

export type SymptomResponse = "better" | "same" | "worse";

export interface HydrawavPairing {
  sun_pad: string;
  moon_pad: string;
  intensity: string;
  duration_min: number;
  practitioner_note?: string | null;
}

export interface ExerciseVideo {
  id: string;
  source_slug: ApprovedExerciseSource;
  source_domain: string;
  canonical_url: string;
  thumbnail_url: string | null;
  playback_mode: PlaybackMode;
  content_host: ContentHost;
  title: string;
  creator_name: string;
  creator_credentials: string;
  source_quality_tier: SourceQualityTier;
  language: string;
  duration_sec: number | null;
  body_regions: BodyRegion[];
  symptom_tags: ExerciseSymptom[];
  movement_tags: string[];
  goal_tags: RecoveryGoal[];
  equipment_tags: string[];
  activity_trigger_tags: ActivityTrigger[];
  level: string | null;
  contraindication_tags: string[];
  practitioner_notes: string | null;
  hydrawav_pairing: HydrawavPairing | null;
  quality_score: number;
  confidence_score: number;
  human_review_status: ReviewStatus;
  last_reviewed_at: string | null;
}

export interface ExerciseRecommendationRuleItem {
  id: string;
  rule_id: string;
  exercise_video_id: string;
  sort_order: number;
  display_note: string | null;
}

export interface ExerciseRecommendationRule {
  id: string;
  region: BodyRegion;
  symptom: ExerciseSymptom;
  evidence_tier: EvidenceTier;
  goal_tags: RecoveryGoal[];
  activity_trigger_tags: ActivityTrigger[];
  hydrawav_pairing: HydrawavPairing | null;
  practitioner_note: string | null;
  quality_score: number;
  confidence_score: number;
  human_review_status: ReviewStatus;
  last_reviewed_at: string | null;
}

export interface RecoveryPlanProgressSummary {
  completed_this_week: number;
  assigned_this_week: number;
  total_items: number;
  required_items: number;
  optional_items: number;
  completion_rate: number;
  latest_completion_at: string | null;
  paused_for_safety: boolean;
}

export interface RecoveryPlanCompletionLog {
  id: string;
  plan_id: string;
  plan_item_id: string;
  status: CompletionStatus;
  tolerance_rating: number | null;
  difficulty_rating: number | null;
  symptom_response: SymptomResponse | null;
  notes: string | null;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RecoveryPlanItem {
  id: string;
  plan_id: string;
  position: number;
  item_role: RecoveryPlanItemRole;
  region: BodyRegion;
  symptom: ExerciseSymptom;
  cadence: PlanCadence;
  weekly_target_count: number;
  rationale: string;
  display_notes: string | null;
  hydrawav_pairing: HydrawavPairing;
  video: ExerciseVideo;
}

export interface RecoveryPlan {
  id: string;
  client_id: string;
  clinic_id: string;
  status: PlanStatus;
  refresh_reason: PlanRefreshReason;
  source_assessment_id: string | null;
  summary: string;
  activity_context: string | null;
  primary_regions: BodyRegion[];
  recovery_signals: RecoverySignal[];
  goals: RecoveryGoal[];
  safety_pause_reason: string | null;
  paused_for_safety_at: string | null;
  created_at: string;
  updated_at: string;
  items: RecoveryPlanItem[];
  recent_completion_logs: RecoveryPlanCompletionLog[];
  progress: RecoveryPlanProgressSummary;
}

export interface RecoveryPlanHistoryEntry {
  id: string;
  status: PlanStatus;
  refresh_reason: PlanRefreshReason;
  source_assessment_id: string | null;
  summary: string;
  created_at: string;
  updated_at: string;
  superseded_at: string | null;
  completion_rate: number;
  item_count: number;
}

export interface RecoveryPlanRefreshResult {
  refreshed: boolean;
  reason: PlanRefreshReason | "no_change" | "no_plan_available";
  plan: RecoveryPlan | null;
}
