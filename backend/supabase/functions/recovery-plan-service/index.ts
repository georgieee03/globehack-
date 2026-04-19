import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  type AuthenticatedUserContext,
  HttpError,
  requireAuthenticatedUser,
  requireRole,
} from "../_shared/supabase-client.ts";
import type { BodyRegion } from "../_shared/safe-envelope.ts";
import { parseQuickPoseAssessment } from "../recovery-intelligence/scan-contract.ts";
import {
  deriveRefreshReason,
  generateRecoveryPlanDraft,
  safetyPauseReason,
  weeklyTargetCount,
} from "./generator.ts";
import type {
  AssessmentSnapshot,
  CompletionStatus,
  RecoveryPlanDraft,
  RecoveryGoal,
  RecoveryPlanCompletionLogRow,
  RecoveryPlanItemRow,
  RecoveryPlanProgressSummary,
  RecoveryPlanRow,
  RecoverySignalSnapshot,
  RecoverySignalType,
  ExerciseVideoRow,
  ExerciseRecommendationRuleRow,
  ExerciseRecommendationRuleItemRow,
  SymptomResponse,
} from "./types.ts";

interface ActionRequest {
  action: "fetch_active_plan" | "list_plan_history" | "refresh_if_needed" | "log_completion";
  assessment_id?: string | null;
  force_refresh?: boolean;
  refresh_reason?: string | null;
  plan_item_id?: string | null;
  status?: CompletionStatus;
  tolerance_rating?: number | null;
  difficulty_rating?: number | null;
  symptom_response?: SymptomResponse | null;
  notes?: string | null;
}

function asBodyRegion(value: unknown): BodyRegion | null {
  return typeof value === "string" ? value as BodyRegion : null;
}

function asRecoverySignalType(value: unknown): RecoverySignalType | null {
  switch (value) {
  case "stiffness":
  case "soreness":
  case "tightness":
  case "restriction":
  case "guarding":
    return value;
  default:
    return null;
  }
}

function parseRecoverySignals(value: unknown): RecoverySignalSnapshot[] {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return [];
  }

  const entries = Object.entries(value as Record<string, unknown>);
  const signals: RecoverySignalSnapshot[] = [];

  for (const [region, rawValue] of entries) {
    const typedRegion = asBodyRegion(region);
    if (!typedRegion || !rawValue || typeof rawValue !== "object" || Array.isArray(rawValue)) {
      continue;
    }

    const signalType = asRecoverySignalType((rawValue as Record<string, unknown>).type);
    if (!signalType) {
      continue;
    }

    const severityValue = (rawValue as Record<string, unknown>).severity;
    const severity = typeof severityValue === "number"
      ? severityValue
      : Number(severityValue ?? 0);

    signals.push({
      region: typedRegion,
      type: signalType,
      severity: Number.isFinite(severity) ? severity : 0,
      trigger: typeof (rawValue as Record<string, unknown>).trigger === "string"
        ? String((rawValue as Record<string, unknown>).trigger)
        : "general",
      notes: typeof (rawValue as Record<string, unknown>).notes === "string"
        ? String((rawValue as Record<string, unknown>).notes)
        : null,
    });
  }

  return signals;
}

function parseAssessmentSnapshot(row: Record<string, unknown> | null): AssessmentSnapshot | null {
  if (!row) {
    return null;
  }

  const quickPoseAssessment = parseQuickPoseAssessment(row.quickpose_data);
  const rawRecoveryMap = row.recovery_map as Record<string, unknown> | null;
  const highlightedRegions = Array.isArray(rawRecoveryMap?.highlightedRegions)
    ? rawRecoveryMap!.highlightedRegions.flatMap((rawRegion) => {
        if (!rawRegion || typeof rawRegion !== "object" || Array.isArray(rawRegion)) {
          return [];
        }

        const region = asBodyRegion((rawRegion as Record<string, unknown>).region);
        const signalType = asRecoverySignalType((rawRegion as Record<string, unknown>).signalType);
        const severityValue = (rawRegion as Record<string, unknown>).severity;
        const severity = typeof severityValue === "number"
          ? severityValue
          : Number(severityValue ?? 0);

        if (!region || !signalType || !Number.isFinite(severity)) {
          return [];
        }

        return [{
          region,
          severity,
          signalType,
        }];
      })
    : [];

  return {
    id: typeof row.id === "string" ? row.id : null,
    assessmentType: typeof row.assessment_type === "string" ? row.assessment_type : null,
    createdAt: typeof row.created_at === "string" ? row.created_at : null,
    bodyZones: Array.isArray(row.body_zones)
      ? row.body_zones.flatMap((region) => asBodyRegion(region)).filter(Boolean) as BodyRegion[]
      : [],
    recoveryGoal: typeof row.recovery_goal === "string" ? row.recovery_goal as RecoveryGoal : null,
    romValues: quickPoseAssessment?.aggregate_rom_values ?? (row.rom_values as Record<string, number> ?? {}),
    asymmetryScores: quickPoseAssessment?.aggregate_asymmetry_scores ?? (row.asymmetry_scores as Record<string, number> ?? {}),
    movementQualityScores: quickPoseAssessment?.aggregate_movement_quality_scores ?? (row.movement_quality_scores as Record<string, number> ?? {}),
    highlightedRegions,
  };
}

function normalizePlanItem(row: Record<string, unknown>): RecoveryPlanItemRow {
  return row as unknown as RecoveryPlanItemRow;
}

function normalizeCompletionLog(row: Record<string, unknown>): RecoveryPlanCompletionLogRow {
  return row as unknown as RecoveryPlanCompletionLogRow;
}

function computeProgressSummary(
  plan: RecoveryPlanRow,
  items: RecoveryPlanItemRow[],
  logs: RecoveryPlanCompletionLogRow[],
): RecoveryPlanProgressSummary {
  const since = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const completedThisWeek = logs.filter((log) =>
    log.status === "completed" &&
    log.completed_at != null &&
    new Date(log.completed_at).valueOf() >= since
  ).length;
  const assignedThisWeek = items.reduce((sum, item) => sum + weeklyTargetCount(item.cadence), 0);
  const requiredItems = items.filter((item) => item.item_role === "required").length;
  const optionalItems = items.filter((item) => item.item_role === "optional_support").length;
  const completionRate = assignedThisWeek > 0 ? Math.min(1, completedThisWeek / assignedThisWeek) : 0;
  const latestCompletion = logs
    .map((log) => log.completed_at ?? log.created_at)
    .filter((value): value is string => Boolean(value))
    .sort()
    .at(-1) ?? null;

  return {
    completed_this_week: completedThisWeek,
    assigned_this_week: assignedThisWeek,
    total_items: items.length,
    required_items: requiredItems,
    optional_items: optionalItems,
    completion_rate: completionRate,
    latest_completion_at: latestCompletion,
    paused_for_safety: plan.status === "paused_for_safety",
  };
}

function shapeVideoFromItem(item: RecoveryPlanItemRow) {
  return {
    id: item.exercise_video_id,
    source_slug: item.source_slug,
    source_domain: item.source_domain,
    canonical_url: item.canonical_url,
    thumbnail_url: item.thumbnail_url,
    playback_mode: item.playback_mode,
    content_host: item.content_host,
    title: item.title,
    creator_name: item.creator_name,
    creator_credentials: item.creator_credentials,
    source_quality_tier: item.source_quality_tier,
    language: item.language,
    duration_sec: item.duration_sec,
    body_regions: item.body_regions,
    symptom_tags: item.symptom_tags,
    movement_tags: item.movement_tags,
    goal_tags: item.goal_tags,
    equipment_tags: item.equipment_tags,
    activity_trigger_tags: item.activity_trigger_tags,
    level: item.level,
    contraindication_tags: item.contraindication_tags,
    practitioner_notes: item.practitioner_notes,
    hydrawav_pairing: item.hydrawav_pairing,
    quality_score: item.quality_score,
    confidence_score: item.confidence_score,
    human_review_status: item.human_review_status,
    last_reviewed_at: item.last_reviewed_at,
  };
}

async function resolveClientProfileIdForUser(
  supabase: AuthenticatedUserContext["supabase"],
  userId: string,
  clinicId: string,
) {
  const { data: clientProfile, error } = await supabase
    .from("client_profiles")
    .select("id")
    .eq("user_id", userId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load client profile for authenticated user", {
      detail: error.message,
    });
  }

  if (!clientProfile?.id) {
    throw new HttpError(403, "This client account does not have a client profile in the current clinic");
  }

  return clientProfile.id as string;
}

async function fetchClientProfileInput(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
  clinicId: string,
) {
  const { data, error } = await supabase
    .from("client_profiles")
    .select("primary_regions, recovery_signals, goals, activity_context")
    .eq("id", clientId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error || !data) {
    throw new HttpError(404, "Client profile not found", {
      detail: error?.message,
    });
  }

  return {
    primaryRegions: Array.isArray(data.primary_regions)
      ? data.primary_regions.flatMap((value: unknown) => asBodyRegion(value)).filter(Boolean) as BodyRegion[]
      : [],
    recoverySignals: parseRecoverySignals(data.recovery_signals),
    goals: Array.isArray(data.goals) ? data.goals as RecoveryGoal[] : [],
    activityContext: typeof data.activity_context === "string" ? data.activity_context : null,
  };
}

async function fetchAssessmentForPlan(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
  clinicId: string,
  assessmentId?: string | null,
) {
  if (assessmentId) {
    const { data, error } = await supabase
      .from("assessments")
      .select("*")
      .eq("id", assessmentId)
      .eq("client_id", clientId)
      .eq("clinic_id", clinicId)
      .maybeSingle();

    if (error) {
      throw new HttpError(500, "Failed to load source assessment", {
        detail: error.message,
      });
    }

    return parseAssessmentSnapshot(data as Record<string, unknown> | null);
  }

  const { data, error } = await supabase
    .from("assessments")
    .select("*")
    .eq("client_id", clientId)
    .eq("clinic_id", clinicId)
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    throw new HttpError(500, "Failed to load the latest assessment", {
      detail: error.message,
    });
  }

  return parseAssessmentSnapshot(((data ?? [])[0] ?? null) as Record<string, unknown> | null);
}

async function fetchCatalog(
  supabase: AuthenticatedUserContext["supabase"],
) {
  const [videoResult, ruleResult, ruleItemResult] = await Promise.all([
    supabase.from("exercise_videos").select("*").eq("human_review_status", "approved"),
    supabase.from("exercise_recommendation_rules").select("*").eq("human_review_status", "approved"),
    supabase.from("exercise_recommendation_rule_items").select("*").order("sort_order", { ascending: true }),
  ]);

  if (videoResult.error || ruleResult.error || ruleItemResult.error) {
    throw new HttpError(500, "Failed to load the recovery-plan catalog", {
      video: videoResult.error?.message,
      rules: ruleResult.error?.message,
      ruleItems: ruleItemResult.error?.message,
    });
  }

  return {
    videos: (videoResult.data ?? []) as ExerciseVideoRow[],
    rules: (ruleResult.data ?? []) as ExerciseRecommendationRuleRow[],
    ruleItems: (ruleItemResult.data ?? []) as ExerciseRecommendationRuleItemRow[],
  };
}

async function fetchCurrentPlan(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
) {
  const { data, error } = await supabase
    .from("recovery_plans")
    .select("*")
    .eq("client_id", clientId)
    .in("status", ["active", "paused_for_safety"])
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    throw new HttpError(500, "Failed to load the current recovery plan", {
      detail: error.message,
    });
  }

  return ((data ?? [])[0] ?? null) as RecoveryPlanRow | null;
}

async function fetchPlanItems(
  supabase: AuthenticatedUserContext["supabase"],
  planId: string,
) {
  const { data, error } = await supabase
    .from("recovery_plan_items")
    .select("*")
    .eq("plan_id", planId)
    .order("position", { ascending: true });

  if (error) {
    throw new HttpError(500, "Failed to load recovery-plan items", {
      detail: error.message,
    });
  }

  return (data ?? []).map((row) => normalizePlanItem(row as Record<string, unknown>));
}

async function fetchPlanLogs(
  supabase: AuthenticatedUserContext["supabase"],
  planId: string,
  limit = 20,
) {
  const { data, error } = await supabase
    .from("recovery_plan_completion_logs")
    .select("*")
    .eq("plan_id", planId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new HttpError(500, "Failed to load recovery-plan completion logs", {
      detail: error.message,
    });
  }

  return (data ?? []).map((row) => normalizeCompletionLog(row as Record<string, unknown>));
}

async function shapePlan(
  supabase: AuthenticatedUserContext["supabase"],
  plan: RecoveryPlanRow | null,
) {
  if (!plan) {
    return null;
  }

  const [items, logs] = await Promise.all([
    fetchPlanItems(supabase, plan.id),
    fetchPlanLogs(supabase, plan.id),
  ]);

  const progress = computeProgressSummary(plan, items, logs);

  return {
    id: plan.id,
    client_id: plan.client_id,
    clinic_id: plan.clinic_id,
    status: plan.status,
    refresh_reason: plan.refresh_reason,
    source_assessment_id: plan.source_assessment_id,
    summary: plan.summary,
    activity_context: plan.activity_context,
    primary_regions: plan.generation_context.primary_regions,
    recovery_signals: plan.generation_context.recovery_signals,
    goals: plan.generation_context.goals,
    safety_pause_reason: plan.safety_pause_reason,
    paused_for_safety_at: plan.paused_for_safety_at,
    created_at: plan.created_at,
    updated_at: plan.updated_at,
    items: items.map((item) => ({
      id: item.id,
      plan_id: item.plan_id,
      position: item.position,
      item_role: item.item_role,
      region: item.region,
      symptom: item.symptom,
      cadence: item.cadence,
      weekly_target_count: item.weekly_target_count,
      rationale: item.rationale,
      display_notes: item.display_notes,
      hydrawav_pairing: item.hydrawav_pairing,
      video: shapeVideoFromItem(item),
    })),
    recent_completion_logs: logs,
    progress,
  };
}

async function fetchPlanHistory(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
) {
  const { data, error } = await supabase
    .from("recovery_plans")
    .select("*")
    .eq("client_id", clientId)
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) {
    throw new HttpError(500, "Failed to load recovery-plan history", {
      detail: error.message,
    });
  }

  const plans = (data ?? []) as RecoveryPlanRow[];
  if (plans.length === 0) {
    return [];
  }

  const planIds = plans.map((plan) => plan.id);
  const [itemResult, logResult] = await Promise.all([
    supabase.from("recovery_plan_items").select("plan_id").in("plan_id", planIds),
    supabase.from("recovery_plan_completion_logs").select("plan_id, status").in("plan_id", planIds),
  ]);

  if (itemResult.error || logResult.error) {
    throw new HttpError(500, "Failed to summarize recovery-plan history", {
      items: itemResult.error?.message,
      logs: logResult.error?.message,
    });
  }

  const itemCounts = new Map<string, number>();
  for (const row of itemResult.data ?? []) {
    const planId = String((row as Record<string, unknown>).plan_id ?? "");
    itemCounts.set(planId, (itemCounts.get(planId) ?? 0) + 1);
  }

  const completionCounts = new Map<string, number>();
  for (const row of logResult.data ?? []) {
    const planId = String((row as Record<string, unknown>).plan_id ?? "");
    const status = String((row as Record<string, unknown>).status ?? "");
    if (status === "completed") {
      completionCounts.set(planId, (completionCounts.get(planId) ?? 0) + 1);
    }
  }

  return plans.map((plan) => {
    const itemCount = itemCounts.get(plan.id) ?? 0;
    const completedCount = completionCounts.get(plan.id) ?? 0;
    return {
      id: plan.id,
      status: plan.status,
      refresh_reason: plan.refresh_reason,
      source_assessment_id: plan.source_assessment_id,
      summary: plan.summary,
      created_at: plan.created_at,
      updated_at: plan.updated_at,
      superseded_at: plan.superseded_at,
      completion_rate: itemCount > 0 ? Math.min(1, completedCount / itemCount) : 0,
      item_count: itemCount,
    };
  });
}

async function insertPlanDraft(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
  clinicId: string,
  sourceAssessmentId: string | null,
  activityContext: string | null,
  draft: RecoveryPlanDraft,
  previousPlan: RecoveryPlanRow | null,
) {
  const { data: planRows, error: planInsertError } = await supabase
    .from("recovery_plans")
    .insert({
      client_id: clientId,
      clinic_id: clinicId,
      source_assessment_id: sourceAssessmentId,
      status: "active",
      refresh_reason: draft.refreshReason,
      summary: draft.summary,
      activity_context: activityContext,
      generation_context: draft.generationContext,
    })
    .select()
    .limit(1);

  if (planInsertError || !planRows?.[0]) {
    throw new HttpError(500, "Failed to create the recovery plan", {
      detail: planInsertError?.message,
    });
  }

  const plan = planRows[0] as RecoveryPlanRow;

  const itemRows = draft.items.map((item) => ({
    plan_id: plan.id,
    exercise_video_id: item.exercise_video_id,
    position: item.position,
    item_role: item.item_role,
    region: item.region,
    symptom: item.symptom,
    cadence: item.cadence,
    weekly_target_count: item.weekly_target_count,
    rationale: item.rationale,
    display_notes: item.display_notes,
    hydrawav_pairing: item.hydrawav_pairing,
    source_slug: item.source_slug,
    source_domain: item.source_domain,
    title: item.title,
    canonical_url: item.canonical_url,
    thumbnail_url: item.thumbnail_url,
    playback_mode: item.playback_mode,
    content_host: item.content_host,
    creator_name: item.creator_name,
    creator_credentials: item.creator_credentials,
    source_quality_tier: item.source_quality_tier,
    language: item.language,
    duration_sec: item.duration_sec,
    level: item.level,
    body_regions: item.body_regions,
    symptom_tags: item.symptom_tags,
    movement_tags: item.movement_tags,
    goal_tags: item.goal_tags,
    equipment_tags: item.equipment_tags,
    activity_trigger_tags: item.activity_trigger_tags,
    contraindication_tags: item.contraindication_tags,
    practitioner_notes: item.practitioner_notes,
    quality_score: item.quality_score,
    confidence_score: item.confidence_score,
    human_review_status: item.human_review_status,
    last_reviewed_at: item.last_reviewed_at,
  }));

  const { error: itemInsertError } = await supabase
    .from("recovery_plan_items")
    .insert(itemRows);

  if (itemInsertError) {
    throw new HttpError(500, "Failed to create recovery-plan items", {
      detail: itemInsertError.message,
    });
  }

  if (previousPlan) {
    const { error: supersedeError } = await supabase
      .from("recovery_plans")
      .update({
        status: "superseded",
        superseded_at: new Date().toISOString(),
        superseded_by_plan_id: plan.id,
      })
      .eq("id", previousPlan.id);

    if (supersedeError) {
      throw new HttpError(500, "Failed to supersede the previous recovery plan", {
        detail: supersedeError.message,
      });
    }
  }

  return plan;
}

async function handleFetchActivePlan(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
) {
  const currentPlan = await fetchCurrentPlan(supabase, clientId);
  const shaped = await shapePlan(supabase, currentPlan);
  return { success: true, data: { plan: shaped } };
}

async function handleListPlanHistory(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
) {
  const history = await fetchPlanHistory(supabase, clientId);
  return { success: true, data: { history } };
}

async function handleRefreshIfNeeded(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
  clinicId: string,
  body: ActionRequest,
) {
  const [profileInput, currentPlan, catalog] = await Promise.all([
    fetchClientProfileInput(supabase, clientId, clinicId),
    fetchCurrentPlan(supabase, clientId),
    fetchCatalog(supabase),
  ]);

  if (currentPlan?.status === "paused_for_safety") {
    return {
      success: true,
      data: {
        refreshed: false,
        reason: "no_change",
        plan: await shapePlan(supabase, currentPlan),
      },
    };
  }

  const assessment = await fetchAssessmentForPlan(supabase, clientId, clinicId, body.assessment_id);
  if (!assessment && !currentPlan) {
    return {
      success: true,
      data: {
        refreshed: false,
        reason: "no_plan_available",
        plan: null,
      },
    };
  }

  const input = {
    primaryRegions: profileInput.primaryRegions,
    recoverySignals: profileInput.recoverySignals,
    goals: profileInput.goals,
    activityContext: profileInput.activityContext,
    assessment,
  };

  const previousContext = currentPlan?.generation_context ?? null;
  const reason = deriveRefreshReason(input, previousContext, currentPlan?.created_at ?? null, Boolean(body.force_refresh));
  if (!reason) {
    return {
      success: true,
      data: {
        refreshed: false,
        reason: "no_change",
        plan: await shapePlan(supabase, currentPlan),
      },
    };
  }

  const draft = generateRecoveryPlanDraft(input, catalog.videos, catalog.rules, catalog.ruleItems, reason);
  if (!draft) {
    return {
      success: true,
      data: {
        refreshed: false,
        reason: "no_plan_available",
        plan: currentPlan ? await shapePlan(supabase, currentPlan) : null,
      },
    };
  }

  const insertedPlan = await insertPlanDraft(
    supabase,
    clientId,
    clinicId,
    assessment?.id ?? null,
    profileInput.activityContext,
    draft,
    currentPlan,
  );

  return {
    success: true,
    data: {
      refreshed: true,
      reason,
      plan: await shapePlan(supabase, insertedPlan),
    },
  };
}

async function handleLogCompletion(
  supabase: AuthenticatedUserContext["supabase"],
  clientId: string,
  body: ActionRequest,
) {
  if (!body.plan_item_id || !body.status) {
    throw new HttpError(400, "plan_item_id and status are required for log_completion");
  }

  const { data: itemRow, error: itemError } = await supabase
    .from("recovery_plan_items")
    .select("id, plan_id")
    .eq("id", body.plan_item_id)
    .maybeSingle();

  if (itemError || !itemRow?.id || !itemRow.plan_id) {
    throw new HttpError(404, "Recovery-plan item not found", {
      detail: itemError?.message,
    });
  }

  const { data: planRow, error: planError } = await supabase
    .from("recovery_plans")
    .select("*")
    .eq("id", itemRow.plan_id)
    .eq("client_id", clientId)
    .maybeSingle();

  if (planError || !planRow?.id) {
    throw new HttpError(404, "Recovery plan not found for this client", {
      detail: planError?.message,
    });
  }

  const now = new Date().toISOString();
  const logPayload = {
    plan_id: itemRow.plan_id,
    plan_item_id: itemRow.id,
    status: body.status,
    tolerance_rating: body.tolerance_rating ?? null,
    difficulty_rating: body.difficulty_rating ?? null,
    symptom_response: body.symptom_response ?? null,
    notes: body.notes?.trim() || null,
    started_at: body.status === "started" ? now : null,
    completed_at: body.status === "completed" ? now : null,
  };

  const { data: insertedRows, error: insertError } = await supabase
    .from("recovery_plan_completion_logs")
    .insert(logPayload)
    .select()
    .limit(1);

  if (insertError || !insertedRows?.[0]) {
    throw new HttpError(500, "Failed to log recovery-plan completion", {
      detail: insertError?.message,
    });
  }

  const pauseReason = safetyPauseReason(body.status, body.symptom_response ?? null, body.notes ?? null);
  let shapedPlan: Awaited<ReturnType<typeof shapePlan>>;

  if (pauseReason) {
    const { data: pausedRows, error: pauseError } = await supabase
      .from("recovery_plans")
      .update({
        status: "paused_for_safety",
        safety_pause_reason: pauseReason,
        paused_for_safety_at: now,
      })
      .eq("id", planRow.id)
      .select()
      .limit(1);

    if (pauseError || !pausedRows?.[0]) {
      throw new HttpError(500, "Failed to pause the recovery plan for safety", {
        detail: pauseError?.message,
      });
    }

    shapedPlan = await shapePlan(supabase, pausedRows[0] as RecoveryPlanRow);
  } else {
    shapedPlan = await shapePlan(supabase, planRow as RecoveryPlanRow);
  }

  return {
    success: true,
    data: {
      log: normalizeCompletionLog(insertedRows[0] as Record<string, unknown>),
      plan: shapedPlan,
    },
  };
}

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "POST") {
    return methodNotAllowed(request);
  }

  try {
    const context = await requireAuthenticatedUser(request);
    requireRole(context, "client");

    const clientId = await resolveClientProfileIdForUser(context.supabase, context.user.id, context.clinicId);
    const body = await request.json() as ActionRequest;

    switch (body.action) {
    case "fetch_active_plan":
      return jsonResponse(request, await handleFetchActivePlan(context.supabase, clientId));
    case "list_plan_history":
      return jsonResponse(request, await handleListPlanHistory(context.supabase, clientId));
    case "refresh_if_needed":
      return jsonResponse(request, await handleRefreshIfNeeded(context.supabase, clientId, context.clinicId, body));
    case "log_completion":
      return jsonResponse(request, await handleLogCompletion(context.supabase, clientId, body));
    default:
      return errorResponse(request, 400, "Unsupported recovery-plan action", { action: body.action });
    }
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(request, error.status, error.message, error.details);
    }

    return errorResponse(request, 500, "Unexpected recovery-plan failure", {
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});
