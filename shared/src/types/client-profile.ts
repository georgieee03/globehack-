export type BodyRegion =
  | "right_shoulder"
  | "left_shoulder"
  | "right_hip"
  | "left_hip"
  | "lower_back"
  | "upper_back"
  | "right_knee"
  | "left_knee"
  | "neck"
  | "right_calf"
  | "left_calf"
  | "right_arm"
  | "left_arm"
  | "right_foot"
  | "left_foot";

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

export type ActivityTrigger =
  | "morning"
  | "after_running"
  | "after_lifting"
  | "post_travel"
  | "post_training"
  | "evening"
  | "general";

export interface RecoverySignal {
  region: BodyRegion;
  type: RecoverySignalType;
  severity: number;
  trigger: ActivityTrigger | string;
  notes?: string;
}

export interface RecoverySignalValue {
  type: RecoverySignalType;
  severity: number;
  trigger: ActivityTrigger | string;
  notes?: string;
}

export type RecoverySignalsByRegion = Partial<Record<BodyRegion, RecoverySignalValue>>;

export interface ClientProfileRecord {
  id: string;
  user_id: string;
  clinic_id: string;
  primary_regions: BodyRegion[];
  recovery_signals: RecoverySignalsByRegion;
  goals: RecoveryGoal[];
  activity_context: string | null;
  sensitivities: string[];
  notes: string | null;
  wearable_hrv: number | null;
  wearable_strain: number | null;
  wearable_sleep_score: number | null;
  wearable_last_sync: string | null;
  created_at: string;
  updated_at: string;
}
