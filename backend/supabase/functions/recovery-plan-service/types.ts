import type { BodyRegion } from "../_shared/safe-envelope.ts";

export type RecoveryGoal =
  | "mobility"
  | "warm_up"
  | "recovery"
  | "relaxation"
  | "performance_prep";

export type RecoverySignalType =
  | "stiffness"
  | "soreness"
  | "tightness"
  | "restriction"
  | "guarding";

export type ExerciseSymptom =
  | RecoverySignalType
  | "post_activity_discomfort";

export type ActivityTrigger =
  | "morning"
  | "after_running"
  | "after_lifting"
  | "post_travel"
  | "post_training"
  | "evening"
  | "general";

export type ContentHost = "youtube" | "professional_platform";

export type ApprovedExerciseSource =
  | "hinge_health"
  | "ask_doctor_jo"
  | "hospital_for_special_surgery";

export type PlaybackMode =
  | "in_app_browser"
  | "embedded_web"
  | "external_browser";

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

export interface RecoverySignalSnapshot {
  region: BodyRegion;
  type: RecoverySignalType;
  severity: number;
  trigger: ActivityTrigger | string;
  notes?: string | null;
}

export interface HighlightedRegionSnapshot {
  region: BodyRegion;
  severity: number;
  signalType: RecoverySignalType;
}

export interface AssessmentSnapshot {
  id: string | null;
  assessmentType: string | null;
  createdAt: string | null;
  bodyZones: BodyRegion[];
  recoveryGoal: RecoveryGoal | null;
  romValues: Record<string, number>;
  asymmetryScores: Record<string, number>;
  movementQualityScores: Record<string, number>;
  highlightedRegions: HighlightedRegionSnapshot[];
}

export interface ExerciseVideoRow {
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
  source_quality_tier: string;
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

export interface ExerciseRecommendationRuleRow {
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

export interface ExerciseRecommendationRuleItemRow {
  id: string;
  rule_id: string;
  exercise_video_id: string;
  sort_order: number;
  display_note: string | null;
}

export interface RecoveryPlanGenerationInput {
  primaryRegions: BodyRegion[];
  recoverySignals: RecoverySignalSnapshot[];
  goals: RecoveryGoal[];
  activityContext: string | null;
  assessment: AssessmentSnapshot | null;
}

export interface RecoveryPlanGenerationContext {
  primary_regions: BodyRegion[];
  recovery_signals: RecoverySignalSnapshot[];
  goals: RecoveryGoal[];
  activity_context: string | null;
  assessment_metrics: {
    rom_values: Record<string, number>;
    asymmetry_scores: Record<string, number>;
    movement_quality_scores: Record<string, number>;
  };
  highlighted_regions: HighlightedRegionSnapshot[];
}

export interface GeneratedPlanItem {
  position: number;
  item_role: RecoveryPlanItemRole;
  region: BodyRegion;
  symptom: ExerciseSymptom;
  cadence: PlanCadence;
  weekly_target_count: number;
  rationale: string;
  display_notes: string | null;
  hydrawav_pairing: HydrawavPairing;
  exercise_video_id: string;
  source_slug: ApprovedExerciseSource;
  source_domain: string;
  title: string;
  canonical_url: string;
  thumbnail_url: string | null;
  playback_mode: PlaybackMode;
  content_host: ContentHost;
  creator_name: string;
  creator_credentials: string;
  source_quality_tier: string;
  language: string;
  duration_sec: number | null;
  level: string | null;
  body_regions: BodyRegion[];
  symptom_tags: ExerciseSymptom[];
  movement_tags: string[];
  goal_tags: RecoveryGoal[];
  equipment_tags: string[];
  activity_trigger_tags: ActivityTrigger[];
  contraindication_tags: string[];
  practitioner_notes: string | null;
  quality_score: number;
  confidence_score: number;
  human_review_status: ReviewStatus;
  last_reviewed_at: string | null;
}

export interface RecoveryPlanDraft {
  summary: string;
  refreshReason: PlanRefreshReason;
  generationContext: RecoveryPlanGenerationContext;
  items: GeneratedPlanItem[];
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

export interface RecoveryPlanRow {
  id: string;
  client_id: string;
  clinic_id: string;
  source_assessment_id: string | null;
  status: PlanStatus;
  refresh_reason: PlanRefreshReason;
  summary: string;
  activity_context: string | null;
  generation_context: RecoveryPlanGenerationContext;
  safety_pause_reason: string | null;
  paused_for_safety_at: string | null;
  superseded_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RecoveryPlanItemRow {
  id: string;
  plan_id: string;
  exercise_video_id: string;
  position: number;
  item_role: RecoveryPlanItemRole;
  region: BodyRegion;
  symptom: ExerciseSymptom;
  cadence: PlanCadence;
  weekly_target_count: number;
  rationale: string;
  display_notes: string | null;
  hydrawav_pairing: HydrawavPairing;
  source_slug: ApprovedExerciseSource;
  source_domain: string;
  title: string;
  canonical_url: string;
  thumbnail_url: string | null;
  playback_mode: PlaybackMode;
  content_host: ContentHost;
  creator_name: string;
  creator_credentials: string;
  source_quality_tier: string;
  language: string;
  duration_sec: number | null;
  level: string | null;
  body_regions: BodyRegion[];
  symptom_tags: ExerciseSymptom[];
  movement_tags: string[];
  goal_tags: RecoveryGoal[];
  equipment_tags: string[];
  activity_trigger_tags: ActivityTrigger[];
  contraindication_tags: string[];
  practitioner_notes: string | null;
  quality_score: number;
  confidence_score: number;
  human_review_status: ReviewStatus;
  last_reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RecoveryPlanCompletionLogRow {
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
