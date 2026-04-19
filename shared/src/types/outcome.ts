export type OutcomeActor = "client" | "practitioner";

export type TriStateChoice = "yes" | "maybe" | "no";

export type RepeatIntent = "yes" | "maybe" | "no" | "no_try_different";

export interface OutcomeRecord {
  id: string;
  session_id: string;
  client_id: string;
  clinic_id: string;
  recorded_by: OutcomeActor;
  recorded_by_user_id: string;
  stiffness_before: number | null;
  stiffness_after: number | null;
  soreness_before: number | null;
  soreness_after: number | null;
  mobility_improved: TriStateChoice | null;
  session_effective: TriStateChoice | null;
  readiness_improved: TriStateChoice | null;
  repeat_intent: RepeatIntent | null;
  rom_after: Record<string, number> | null;
  rom_delta: Record<string, number> | null;
  client_notes: string | null;
  practitioner_notes: string | null;
  created_at: string;
  updated_at?: string;
}
