import type {
  BodyRegion,
  ClampingEntry,
  LlmExplanationRequest,
  LlmExplanationResponse,
  MqttCommandResponse,
  RecoveryGraphPoint,
  RecoveryMap,
  SessionConfig,
  SafeEnvelopeViolation,
} from "@/types";
import { supabase } from "./supabase-client";

interface ActionEnvelope<T> {
  success: boolean;
  action: string;
  data: T;
}

export interface RecommendResponse {
  sessionConfig: SessionConfig;
  recoveryMap: RecoveryMap;
  recoveryScore: number;
  confidence: number;
  explanation: string;
  adjustments: string[];
  clampingLog: ClampingEntry[];
}

export interface RecoveryScoreResponse {
  score: number;
  computedAt: string;
}

export interface RecoveryGraphResponse {
  dataPoints: RecoveryGraphPoint[];
}

class EdgeFunctionError extends Error {
  details?: unknown;

  constructor(message: string, details?: unknown) {
    super(message);
    this.name = "EdgeFunctionError";
    this.details = details;
  }
}

async function invokeEdgeFunction<TResponse>(
  functionName: string,
  body: Record<string, unknown>,
): Promise<TResponse> {
  const { data, error } = await supabase.functions.invoke(functionName, { body });
  if (error) {
    throw new EdgeFunctionError(error.message, error);
  }
  return data as TResponse;
}

async function invokeAction<TData>(
  body: Record<string, unknown>,
): Promise<TData> {
  const response = await invokeEdgeFunction<ActionEnvelope<TData>>(
    "recovery-intelligence",
    body,
  );

  if (!response?.success) {
    throw new EdgeFunctionError("Recovery Intelligence request failed", response);
  }

  return response.data;
}

export function recommend(clientId: string, assessmentId: string) {
  return invokeAction<RecommendResponse>({
    action: "recommend",
    client_id: clientId,
    assessment_id: assessmentId,
  });
}

export function fetchRecoveryMap(clientId: string, assessmentId: string) {
  return invokeAction<{ recoveryMap: RecoveryMap }>({
    action: "recovery-map",
    client_id: clientId,
    assessment_id: assessmentId,
  });
}

export function fetchRecoveryScore(clientId: string) {
  return invokeAction<RecoveryScoreResponse>({
    action: "recovery-score",
    client_id: clientId,
  });
}

export function fetchRecoveryGraph(
  clientId: string,
  bodyRegion: BodyRegion,
  limit = 30,
) {
  return invokeAction<RecoveryGraphResponse>({
    action: "recovery-graph",
    client_id: clientId,
    body_region: bodyRegion,
    limit,
  });
}

export function sendMqttCommand(
  deviceId: string,
  command: "start" | "pause" | "resume" | "stop",
  sessionConfig?: SessionConfig,
  bodyRegion?: BodyRegion,
) {
  return invokeEdgeFunction<MqttCommandResponse | { error?: string; details?: { violations?: SafeEnvelopeViolation[] } }>(
    "hydrawav-mqtt",
    {
      deviceId,
      command,
      sessionConfig,
      bodyRegion,
    },
  );
}

export function fetchLlmExplanation(input: LlmExplanationRequest) {
  return invokeEdgeFunction<LlmExplanationResponse>(
    "llm-explanation",
    input as unknown as Record<string, unknown>,
  );
}
