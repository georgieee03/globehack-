import { PAD_PLACEMENT_MAP } from "../recovery-intelligence/rules-engine.ts";
import type { BodyRegion } from "../_shared/safe-envelope.ts";
import type {
  ActivityTrigger,
  AssessmentSnapshot,
  CompletionStatus,
  ExerciseRecommendationRuleItemRow,
  ExerciseRecommendationRuleRow,
  ExerciseSymptom,
  ExerciseVideoRow,
  GeneratedPlanItem,
  HydrawavPairing,
  PlanCadence,
  PlanRefreshReason,
  RecoveryGoal,
  RecoveryPlanDraft,
  RecoveryPlanGenerationContext,
  RecoveryPlanGenerationInput,
  RecoverySignalSnapshot,
  RecoverySignalType,
  SymptomResponse,
} from "./types.ts";

const POST_ACTIVITY_TRIGGERS = new Set<ActivityTrigger>([
  "after_running",
  "after_lifting",
  "post_training",
]);

const BILATERAL_REGION_MAP: Partial<Record<BodyRegion, BodyRegion>> = {
  right_shoulder: "left_shoulder",
  left_shoulder: "right_shoulder",
  right_hip: "left_hip",
  left_hip: "right_hip",
  right_knee: "left_knee",
  left_knee: "right_knee",
  right_calf: "left_calf",
  left_calf: "right_calf",
  right_arm: "left_arm",
  left_arm: "right_arm",
  right_foot: "left_foot",
  left_foot: "right_foot",
};

const RELATED_SYMPTOMS: Record<ExerciseSymptom, ExerciseSymptom[]> = {
  stiffness: ["tightness", "restriction", "post_activity_discomfort"],
  soreness: ["post_activity_discomfort", "guarding"],
  tightness: ["stiffness", "restriction", "post_activity_discomfort"],
  restriction: ["tightness", "stiffness", "guarding"],
  guarding: ["tightness", "stiffness", "soreness"],
  post_activity_discomfort: ["soreness", "tightness", "stiffness"],
};

const ASSESSMENT_DELTA_THRESHOLDS = {
  rom: 10,
  asymmetry: 15,
  movementQualityPoints: 15,
};

interface Candidate {
  video: ExerciseVideoRow;
  signal: RecoverySignalSnapshot;
  matchType: "exact_rule" | "exact_tag" | "mirrored" | "related" | "goal_fallback";
  rule: ExerciseRecommendationRuleRow | null;
  displayNote: string | null;
  rankingScore: number;
}

function normalizeTrigger(trigger: string | null | undefined): ActivityTrigger {
  switch (trigger) {
  case "morning":
  case "after_running":
  case "after_lifting":
  case "post_travel":
  case "post_training":
  case "evening":
    return trigger;
  default:
    return "general";
  }
}

function normalizeGoal(goals: RecoveryGoal[]): RecoveryGoal {
  return goals[0] ?? "recovery";
}

function normalizeSignalSeverity(value: number): number {
  return Math.max(1, Math.min(10, Math.round(value)));
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values)).sort();
}

function setEqual(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  const a = [...left].sort();
  const b = [...right].sort();
  return a.every((value, index) => value === b[index]);
}

function signalMap(signals: RecoverySignalSnapshot[]): Map<string, RecoverySignalSnapshot> {
  return new Map(signals.map((signal) => [signal.region, signal]));
}

function normalizeMetricDelta(value: number): number {
  if (Math.abs(value) <= 1) {
    return Math.abs(value * 100);
  }

  return Math.abs(value);
}

function hasAssessmentDelta(
  current: AssessmentSnapshot | null,
  previous: RecoveryPlanGenerationContext | null,
): boolean {
  if (!current || !previous) return false;

  for (const [key, value] of Object.entries(current.romValues)) {
    const previousValue = previous.assessment_metrics.rom_values[key];
    if (previousValue != null && Math.abs(value - previousValue) >= ASSESSMENT_DELTA_THRESHOLDS.rom) {
      return true;
    }
  }

  for (const [key, value] of Object.entries(current.asymmetryScores)) {
    const previousValue = previous.assessment_metrics.asymmetry_scores[key];
    if (previousValue != null && normalizeMetricDelta(value - previousValue) >= ASSESSMENT_DELTA_THRESHOLDS.asymmetry) {
      return true;
    }
  }

  for (const [key, value] of Object.entries(current.movementQualityScores)) {
    const previousValue = previous.assessment_metrics.movement_quality_scores[key];
    if (previousValue != null && normalizeMetricDelta(value - previousValue) >= ASSESSMENT_DELTA_THRESHOLDS.movementQualityPoints) {
      return true;
    }
  }

  return false;
}

export function deriveRefreshReason(
  input: RecoveryPlanGenerationInput,
  previousContext: RecoveryPlanGenerationContext | null,
  previousCreatedAt: string | null,
  forceRefresh: boolean,
): PlanRefreshReason | null {
  if (forceRefresh) {
    return "manual_refresh";
  }

  if (!previousContext || !previousCreatedAt) {
    return "initial_intake";
  }

  const previousDate = new Date(previousCreatedAt);
  if (!Number.isNaN(previousDate.valueOf())) {
    const ageMs = Date.now() - previousDate.valueOf();
    if (ageMs >= 14 * 24 * 60 * 60 * 1000) {
      return "stale_plan";
    }
  }

  if (!setEqual(input.primaryRegions, previousContext.primary_regions)) {
    return "signal_change";
  }

  if (!setEqual(input.goals, previousContext.goals)) {
    return "goal_change";
  }

  const currentSignals = signalMap(input.recoverySignals);
  const previousSignals = signalMap(previousContext.recovery_signals);

  if (currentSignals.size !== previousSignals.size) {
    return "signal_change";
  }

  for (const [region, signal] of currentSignals.entries()) {
    const previousSignal = previousSignals.get(region);
    if (!previousSignal) {
      return "signal_change";
    }

    if (signal.type !== previousSignal.type) {
      return "signal_change";
    }

    if (Math.abs(normalizeSignalSeverity(signal.severity) - normalizeSignalSeverity(previousSignal.severity)) >= 2) {
      return "signal_change";
    }
  }

  if ((input.activityContext ?? "").trim() !== (previousContext.activity_context ?? "").trim()) {
    return "signal_change";
  }

  if (hasAssessmentDelta(input.assessment, previousContext)) {
    return "assessment_change";
  }

  return null;
}

function severitySort(left: RecoverySignalSnapshot, right: RecoverySignalSnapshot): number {
  return normalizeSignalSeverity(right.severity) - normalizeSignalSeverity(left.severity);
}

function buildSignalContexts(input: RecoveryPlanGenerationInput): RecoverySignalSnapshot[] {
  if (input.recoverySignals.length > 0) {
    return [...input.recoverySignals].sort(severitySort);
  }

  if (input.assessment?.highlightedRegions?.length) {
    return [...input.assessment.highlightedRegions]
      .sort((left, right) => right.severity - left.severity)
      .map((region) => ({
        region: region.region,
        type: region.signalType,
        severity: region.severity,
        trigger: "general",
        notes: null,
      }));
  }

  return input.primaryRegions.map((region) => ({
    region,
    type: "stiffness",
    severity: 4,
    trigger: "general",
    notes: null,
  }));
}

function symptomCandidates(signal: RecoverySignalSnapshot): ExerciseSymptom[] {
  const normalizedTrigger = normalizeTrigger(signal.trigger);
  const candidates: ExerciseSymptom[] = [signal.type];

  if (POST_ACTIVITY_TRIGGERS.has(normalizedTrigger)) {
    candidates.push("post_activity_discomfort");
  }

  candidates.push(...RELATED_SYMPTOMS[signal.type]);
  return uniqueStrings(candidates) as ExerciseSymptom[];
}

function cadenceForTrigger(trigger: string): PlanCadence {
  switch (normalizeTrigger(trigger)) {
  case "morning":
    return "morning";
  case "evening":
    return "evening";
  case "after_running":
  case "after_lifting":
  case "post_training":
    return "post_activity";
  case "post_travel":
  case "general":
  default:
    return "daily";
  }
}

export function weeklyTargetCount(cadence: PlanCadence): number {
  switch (cadence) {
  case "post_activity":
    return 3;
  case "daily":
  case "morning":
  case "evening":
  default:
    return 7;
  }
}

function defaultIntensity(goal: RecoveryGoal): string {
  switch (goal) {
  case "warm_up":
      return "gentle_to_moderate";
  case "performance_prep":
      return "moderate";
  case "relaxation":
      return "gentle";
  case "mobility":
  case "recovery":
  default:
      return "gentle_to_moderate";
  }
}

function defaultDuration(goal: RecoveryGoal): number {
  switch (goal) {
  case "warm_up":
    return 7;
  case "performance_prep":
    return 7;
  case "relaxation":
    return 5;
  case "mobility":
  case "recovery":
  default:
    return 9;
  }
}

function buildFallbackPairing(region: BodyRegion, goal: RecoveryGoal, note?: string | null): HydrawavPairing {
  const padPlacement = PAD_PLACEMENT_MAP[region];
  return {
    sun_pad: padPlacement.sunRegion,
    moon_pad: padPlacement.moonRegion,
    intensity: defaultIntensity(goal),
    duration_min: defaultDuration(goal),
    practitioner_note: note ?? padPlacement.rationale,
  };
}

function scoreEvidenceTier(value: string): number {
  switch (value) {
  case "direct":
    return 100;
  case "mirrored":
    return 70;
  case "schema_supported":
    return 45;
  case "derived":
  default:
    return 30;
  }
}

function scoreMatchType(value: Candidate["matchType"]): number {
  switch (value) {
  case "exact_rule":
    return 1000;
  case "exact_tag":
    return 850;
  case "mirrored":
    return 650;
  case "related":
    return 500;
  case "goal_fallback":
  default:
    return 250;
  }
}

function scoreGoalFit(video: ExerciseVideoRow, goals: RecoveryGoal[]): number {
  if (goals.length === 0) return 0;
  return video.goal_tags.some((goal) => goals.includes(goal)) ? 50 : 0;
}

function scoreRuleGoalFit(rule: ExerciseRecommendationRuleRow | null, goals: RecoveryGoal[]): number {
  if (!rule || goals.length === 0 || rule.goal_tags.length === 0) return 0;
  return rule.goal_tags.some((goal) => goals.includes(goal)) ? 35 : 0;
}

function scoreTriggerFit(video: ExerciseVideoRow, trigger: string): number {
  const normalized = normalizeTrigger(trigger);
  if (normalized === "general") return 0;
  return video.activity_trigger_tags.includes(normalized) ? 25 : 0;
}

function scoreRuleTriggerFit(rule: ExerciseRecommendationRuleRow | null, trigger: string): number {
  if (!rule) return 0;
  const normalized = normalizeTrigger(trigger);
  if (normalized === "general" || rule.activity_trigger_tags.length === 0) return 0;
  return rule.activity_trigger_tags.includes(normalized) ? 20 : 0;
}

function createCandidate(
  video: ExerciseVideoRow,
  signal: RecoverySignalSnapshot,
  matchType: Candidate["matchType"],
  rule: ExerciseRecommendationRuleRow | null,
  displayNote: string | null,
  goals: RecoveryGoal[],
): Candidate {
  const score = scoreMatchType(matchType)
    + scoreEvidenceTier(rule?.evidence_tier ?? "derived")
    + normalizeSignalSeverity(signal.severity) * 12
    + scoreGoalFit(video, goals)
    + scoreRuleGoalFit(rule, goals)
    + scoreTriggerFit(video, signal.trigger)
    + scoreRuleTriggerFit(rule, signal.trigger)
    + Math.round(video.confidence_score * 100)
    + Math.round((rule?.confidence_score ?? 0) * 50);

  return {
    video,
    signal,
    matchType,
    rule,
    displayNote,
    rankingScore: score,
  };
}

function hasMeaningfulMovementOverlap(existingTags: string[], candidateTags: string[]): boolean {
  const intersection = candidateTags.filter((tag) => existingTags.includes(tag));
  return intersection.length >= 2;
}

function chooseCandidates(
  input: RecoveryPlanGenerationInput,
  videos: ExerciseVideoRow[],
  rules: ExerciseRecommendationRuleRow[],
  ruleItems: ExerciseRecommendationRuleItemRow[],
): Candidate[] {
  const approvedVideos = videos.filter((video) => video.human_review_status === "approved");
  const approvedRules = rules.filter((rule) => rule.human_review_status === "approved");
  const videoById = new Map(approvedVideos.map((video) => [video.id, video]));
  const ruleItemsByRule = new Map<string, ExerciseRecommendationRuleItemRow[]>();

  for (const item of ruleItems) {
    const bucket = ruleItemsByRule.get(item.rule_id) ?? [];
    bucket.push(item);
    ruleItemsByRule.set(item.rule_id, bucket);
  }

  const candidates: Candidate[] = [];
  const signalContexts = buildSignalContexts(input);
  const goals = input.goals.length > 0 ? input.goals : [input.assessment?.recoveryGoal ?? "recovery"];

  for (const signal of signalContexts) {
    const region = signal.region;
    const exactSymptom = signal.type;
    const regionMirror = BILATERAL_REGION_MAP[region];
    const allSymptoms = symptomCandidates(signal);

    const exactRule = approvedRules.find((rule) => rule.region === region && rule.symptom === exactSymptom);
    if (exactRule) {
      const items = [...(ruleItemsByRule.get(exactRule.id) ?? [])].sort((left, right) => left.sort_order - right.sort_order);
      for (const item of items) {
        const video = videoById.get(item.exercise_video_id);
        if (!video) continue;
        candidates.push(createCandidate(video, signal, "exact_rule", exactRule, item.display_note, goals));
      }
    }

    for (const video of approvedVideos.filter((video) =>
      video.body_regions.includes(region) &&
      video.symptom_tags.includes(exactSymptom)
    )) {
      candidates.push(createCandidate(video, signal, "exact_tag", exactRule ?? null, null, goals));
    }

    if (regionMirror) {
      for (const video of approvedVideos.filter((video) =>
        video.body_regions.includes(regionMirror) &&
        video.symptom_tags.includes(exactSymptom)
      )) {
        candidates.push(createCandidate(video, signal, "mirrored", null, "Mirror the movement on the opposite side when needed.", goals));
      }
    }

    for (const symptom of allSymptoms.filter((value) => value !== exactSymptom && value !== "post_activity_discomfort")) {
      for (const video of approvedVideos.filter((video) =>
        video.body_regions.includes(region) &&
        video.symptom_tags.includes(symptom)
      )) {
        candidates.push(createCandidate(video, signal, "related", null, null, goals));
      }
    }

    if (allSymptoms.includes("post_activity_discomfort")) {
      const rule = approvedRules.find((candidate) => candidate.region === region && candidate.symptom === "post_activity_discomfort");
      if (rule) {
        const items = [...(ruleItemsByRule.get(rule.id) ?? [])].sort((left, right) => left.sort_order - right.sort_order);
        for (const item of items) {
          const video = videoById.get(item.exercise_video_id);
          if (!video) continue;
          candidates.push(createCandidate(video, signal, "related", rule, item.display_note, goals));
        }
      }
    }

    for (const video of approvedVideos.filter((video) =>
      (video.body_regions.includes(region) || (regionMirror ? video.body_regions.includes(regionMirror) : false)) &&
      video.goal_tags.some((goal) => goals.includes(goal))
    )) {
      candidates.push(createCandidate(video, signal, "goal_fallback", null, null, goals));
    }
  }

  candidates.sort((left, right) => right.rankingScore - left.rankingScore);

  const selected: Candidate[] = [];
  const usedUrls = new Set<string>();
  const selectedMovementTags: string[][] = [];

  for (const candidate of candidates) {
    if (usedUrls.has(candidate.video.canonical_url)) {
      continue;
    }

    if (selectedMovementTags.some((tags) => hasMeaningfulMovementOverlap(tags, candidate.video.movement_tags))) {
      continue;
    }

    selected.push(candidate);
    usedUrls.add(candidate.video.canonical_url);
    selectedMovementTags.push(candidate.video.movement_tags);

    if (selected.length >= 5) {
      break;
    }
  }

  return selected;
}

function itemRationale(candidate: Candidate): string {
  const symptom = candidate.signal.type.replaceAll("_", " ");
  const region = candidate.signal.region.replaceAll("_", " ");

  switch (candidate.matchType) {
  case "exact_rule":
  case "exact_tag":
    return `Chosen for ${region} ${symptom} based on your current recovery signals.`;
  case "mirrored":
    return `Chosen as the closest opposite-side match for ${region} ${symptom}.`;
  case "related":
    return `Chosen as a related movement option for ${region} ${symptom}.`;
  case "goal_fallback":
  default:
    return `Chosen as a safe ${normalizeGoal([candidate.video.goal_tags[0] ?? "recovery"]).replaceAll("_", " ")} movement option for your current plan.`;
  }
}

function buildSummary(input: RecoveryPlanGenerationInput, items: GeneratedPlanItem[]): string {
  const primaryRegion = input.primaryRegions[0] ?? input.recoverySignals[0]?.region ?? input.assessment?.bodyZones[0] ?? "lower_back";
  const topSignal = buildSignalContexts(input)[0];
  const goal = normalizeGoal(input.goals);
  const base = `Built from ${primaryRegion.replaceAll("_", " ")} and your ${goal.replaceAll("_", " ")} goal.`;

  if (topSignal) {
    return `${base} Prioritizes ${topSignal.type.replaceAll("_", " ")} with ${items.length} guided movement item${items.length == 1 ? "" : "s"}.`;
  }

  return `${base} Prioritizes ${items.length} approved movement item${items.length == 1 ? "" : "s"} from the HydraScan recovery library.`;
}

export function buildGenerationContext(input: RecoveryPlanGenerationInput): RecoveryPlanGenerationContext {
  return {
    primary_regions: input.primaryRegions,
    recovery_signals: buildSignalContexts(input),
    goals: input.goals,
    activity_context: input.activityContext,
    assessment_metrics: {
      rom_values: input.assessment?.romValues ?? {},
      asymmetry_scores: input.assessment?.asymmetryScores ?? {},
      movement_quality_scores: input.assessment?.movementQualityScores ?? {},
    },
    highlighted_regions: input.assessment?.highlightedRegions ?? [],
  };
}

export function generateRecoveryPlanDraft(
  input: RecoveryPlanGenerationInput,
  videos: ExerciseVideoRow[],
  rules: ExerciseRecommendationRuleRow[],
  ruleItems: ExerciseRecommendationRuleItemRow[],
  refreshReason: PlanRefreshReason,
): RecoveryPlanDraft | null {
  const candidates = chooseCandidates(input, videos, rules, ruleItems);
  if (candidates.length == 0) {
    return null;
  }

  const goal = normalizeGoal(input.goals);
  const items: GeneratedPlanItem[] = candidates.map((candidate, index) => {
    const cadence = cadenceForTrigger(candidate.signal.trigger);
    const pairing = candidate.rule?.hydrawav_pairing
      ?? candidate.video.hydrawav_pairing
      ?? buildFallbackPairing(candidate.signal.region, goal, candidate.rule?.practitioner_note ?? candidate.video.practitioner_notes);

    return {
      position: index + 1,
      item_role: index < 3 ? "required" : "optional_support",
      region: candidate.signal.region,
      symptom: candidate.matchType === "related" && POST_ACTIVITY_TRIGGERS.has(normalizeTrigger(candidate.signal.trigger))
        ? "post_activity_discomfort"
        : candidate.signal.type,
      cadence,
      weekly_target_count: weeklyTargetCount(cadence),
      rationale: itemRationale(candidate),
      display_notes: candidate.displayNote ?? candidate.rule?.practitioner_note ?? candidate.video.practitioner_notes,
      hydrawav_pairing: pairing,
      exercise_video_id: candidate.video.id,
      source_slug: candidate.video.source_slug,
      source_domain: candidate.video.source_domain,
      title: candidate.video.title,
      canonical_url: candidate.video.canonical_url,
      thumbnail_url: candidate.video.thumbnail_url,
      playback_mode: candidate.video.playback_mode,
      content_host: candidate.video.content_host,
      creator_name: candidate.video.creator_name,
      creator_credentials: candidate.video.creator_credentials,
      source_quality_tier: candidate.video.source_quality_tier,
      language: candidate.video.language,
      duration_sec: candidate.video.duration_sec,
      level: candidate.video.level,
      body_regions: candidate.video.body_regions,
      symptom_tags: candidate.video.symptom_tags,
      movement_tags: candidate.video.movement_tags,
      goal_tags: candidate.video.goal_tags,
      equipment_tags: candidate.video.equipment_tags,
      activity_trigger_tags: candidate.video.activity_trigger_tags,
      contraindication_tags: candidate.video.contraindication_tags,
      practitioner_notes: candidate.video.practitioner_notes,
      quality_score: candidate.video.quality_score,
      confidence_score: candidate.video.confidence_score,
      human_review_status: candidate.video.human_review_status,
      last_reviewed_at: candidate.video.last_reviewed_at,
    };
  });

  return {
    summary: buildSummary(input, items),
    refreshReason,
    generationContext: buildGenerationContext(input),
    items,
  };
}

export function safetyPauseReason(
  status: CompletionStatus,
  symptomResponse: SymptomResponse | null,
  notes: string | null,
): string | null {
  if (status === "stopped") {
    return "The plan was paused because you stopped an exercise early. Review the safety guidance before continuing.";
  }

  if (symptomResponse !== "worse" || !notes) {
    return null;
  }

  const normalized = notes.toLowerCase();
  const redFlags = [
    "sharp pain",
    "dizziness",
    "numbness",
    "weakness",
    "swelling",
    "recent trauma",
    "post-op",
    "post op",
  ];

  const matched = redFlags.find((flag) => normalized.includes(flag));
  if (!matched) {
    return null;
  }

  return `The plan was paused because your note mentioned ${matched}. Please contact your clinic before continuing.`;
}
