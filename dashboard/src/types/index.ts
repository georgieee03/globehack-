// Re-export types from shared package for dashboard use
export type {
  BodyRegion,
  RecoveryGoal,
  RecoverySignalType,
  PadPlacement,
  ModalityMix,
  SessionOutcomeScore,
  HistoryResult,
  ClampingEntry,
  ConfigBuilderInput,
  ConfigBuilderOutput,
} from "@hydrascan/shared";

export type {
  RecoveryMap,
  HighlightedRegion,
  WearableContext,
  PriorSessionSummary,
} from "@hydrascan/shared";

export type {
  RecoveryScoreInput,
  RecoveryScoreResult,
  RecoveryGraphPoint,
} from "@hydrascan/shared";

export type {
  LlmExplanationRequest,
  LlmExplanationResponse,
} from "@hydrascan/shared";

export type {
  SessionConfig,
  MqttCommandRequest,
  MqttCommandResponse,
  SessionStatus,
  DeviceStatus,
  DeviceRecord,
  SessionRecord,
  ClientProfileRecord,
  AssessmentRecord,
} from "@hydrascan/shared";

export type {
  SafeEnvelope,
  SafeEnvelopeOverride,
  SafeEnvelopeValidationResult,
  SafeEnvelopeViolation,
} from "@hydrascan/shared";
