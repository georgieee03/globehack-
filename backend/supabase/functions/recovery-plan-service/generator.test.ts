import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  deriveRefreshReason,
  generateRecoveryPlanDraft,
  safetyPauseReason,
} from "./generator.ts";
import type {
  ExerciseRecommendationRuleItemRow,
  ExerciseRecommendationRuleRow,
  ExerciseVideoRow,
  RecoveryPlanGenerationContext,
  RecoveryPlanGenerationInput,
} from "./types.ts";

function makeVideo(overrides: Partial<ExerciseVideoRow> = {}): ExerciseVideoRow {
  return {
    id: "V01",
    source_slug: "hinge_health",
    source_domain: "hingehealth.com",
    canonical_url: "https://example.com/videos/v01",
    thumbnail_url: null,
    playback_mode: "in_app_browser",
    content_host: "youtube",
    title: "Shoulder opener",
    creator_name: "HydraScan Curated",
    creator_credentials: "Licensed PT",
    source_quality_tier: "pt_reviewed_platform",
    language: "en",
    duration_sec: 300,
    body_regions: ["right_shoulder"],
    symptom_tags: ["stiffness"],
    movement_tags: ["shoulder_mobility", "mobility"],
    goal_tags: ["mobility", "recovery"],
    equipment_tags: [],
    activity_trigger_tags: [],
    level: "beginner",
    contraindication_tags: [],
    practitioner_notes: "Stay within a comfortable range.",
    hydrawav_pairing: {
      sun_pad: "right_shoulder",
      moon_pad: "upper_back",
      intensity: "gentle_to_moderate",
      duration_min: 9,
      practitioner_note: "Pair with Hydrawav after the video.",
    },
    quality_score: 0.9,
    confidence_score: 0.95,
    human_review_status: "approved",
    last_reviewed_at: null,
    ...overrides,
  };
}

function makeRule(overrides: Partial<ExerciseRecommendationRuleRow> = {}): ExerciseRecommendationRuleRow {
  return {
    id: "right_shoulder_stiffness",
    region: "right_shoulder",
    symptom: "stiffness",
    evidence_tier: "direct",
    goal_tags: ["mobility"],
    activity_trigger_tags: [],
    hydrawav_pairing: {
      sun_pad: "right_shoulder",
      moon_pad: "upper_back",
      intensity: "gentle_to_moderate",
      duration_min: 9,
      practitioner_note: "Use after upper-body loading.",
    },
    practitioner_note: "Prioritize this after overhead activity.",
    quality_score: 0.9,
    confidence_score: 0.93,
    human_review_status: "approved",
    last_reviewed_at: null,
    ...overrides,
  };
}

function makeInput(overrides: Partial<RecoveryPlanGenerationInput> = {}): RecoveryPlanGenerationInput {
  return {
    primaryRegions: ["right_shoulder"],
    recoverySignals: [{
      region: "right_shoulder",
      type: "stiffness",
      severity: 7,
      trigger: "general",
      notes: null,
    }],
    goals: ["mobility"],
    activityContext: "Upper body training",
    assessment: {
      id: "assessment-1",
      assessmentType: "intake",
      createdAt: "2026-04-19T00:00:00.000Z",
      bodyZones: ["right_shoulder"],
      recoveryGoal: "mobility",
      romValues: { right_shoulder_flexion: 122 },
      asymmetryScores: { shoulder_flexion: 14 },
      movementQualityScores: { shoulder_flexion: 0.72 },
      highlightedRegions: [{
        region: "right_shoulder",
        severity: 7,
        signalType: "stiffness",
      }],
    },
    ...overrides,
  };
}

function makeContext(overrides: Partial<RecoveryPlanGenerationContext> = {}): RecoveryPlanGenerationContext {
  return {
    primary_regions: ["right_shoulder"],
    recovery_signals: [{
      region: "right_shoulder",
      type: "stiffness",
      severity: 5,
      trigger: "general",
      notes: null,
    }],
    goals: ["mobility"],
    activity_context: "Upper body training",
    assessment_metrics: {
      rom_values: { right_shoulder_flexion: 115 },
      asymmetry_scores: { shoulder_flexion: 10 },
      movement_quality_scores: { shoulder_flexion: 0.6 },
    },
    highlighted_regions: [{
      region: "right_shoulder",
      severity: 5,
      signalType: "stiffness",
    }],
    ...overrides,
  };
}

Deno.test("deriveRefreshReason returns initial intake when no previous context exists", () => {
  const reason = deriveRefreshReason(makeInput(), null, null, false);
  assertEquals(reason, "initial_intake");
});

Deno.test("deriveRefreshReason returns assessment change when ROM delta crosses threshold", () => {
  const reason = deriveRefreshReason(
    makeInput({
      assessment: {
        id: "assessment-2",
        assessmentType: "reassessment",
        createdAt: "2026-04-20T00:00:00.000Z",
        bodyZones: ["right_shoulder"],
        recoveryGoal: "mobility",
        romValues: { right_shoulder_flexion: 130 },
        asymmetryScores: { shoulder_flexion: 10 },
        movementQualityScores: { shoulder_flexion: 0.6 },
        highlightedRegions: [],
      },
    }),
    makeContext(),
    "2026-04-19T00:00:00.000Z",
    false,
  );

  assertEquals(reason, "assessment_change");
});

Deno.test("generateRecoveryPlanDraft prefers exact rule matches and produces a required item", () => {
  const exactVideo = makeVideo({
    id: "V01",
    body_regions: ["right_shoulder"],
    symptom_tags: ["stiffness"],
    movement_tags: ["shoulder_mobility", "mobility"],
  });
  const fallbackVideo = makeVideo({
    id: "V02",
    canonical_url: "https://example.com/videos/v02",
    title: "Generic mobility",
    body_regions: ["right_shoulder"],
    symptom_tags: ["tightness"],
    movement_tags: ["mobility", "general_range"],
    confidence_score: 0.5,
  });
  const rule = makeRule();
  const ruleItem: ExerciseRecommendationRuleItemRow = {
    id: "rule-item-1",
    rule_id: rule.id,
    exercise_video_id: exactVideo.id,
    sort_order: 1,
    display_note: "Lead with this exact match.",
  };

  const draft = generateRecoveryPlanDraft(
    makeInput(),
    [fallbackVideo, exactVideo],
    [rule],
    [ruleItem],
    "initial_intake",
  );

  assertExists(draft);
  assertEquals(draft.items[0].exercise_video_id, "V01");
  assertEquals(draft.items[0].item_role, "required");
  assertEquals(draft.items[0].display_notes, "Lead with this exact match.");
});

Deno.test("generateRecoveryPlanDraft falls back to mirrored candidates when the exact side is unavailable", () => {
  const mirroredVideo = makeVideo({
    id: "V03",
    canonical_url: "https://example.com/videos/v03",
    body_regions: ["right_shoulder"],
    symptom_tags: ["stiffness"],
    movement_tags: ["pendulum", "low_load_shoulder_motion"],
  });

  const draft = generateRecoveryPlanDraft(
    makeInput({
      primaryRegions: ["left_shoulder"],
      recoverySignals: [{
        region: "left_shoulder",
        type: "stiffness",
        severity: 6,
        trigger: "general",
        notes: null,
      }],
      assessment: {
        id: "assessment-left-1",
        assessmentType: "intake",
        createdAt: "2026-04-19T00:00:00.000Z",
        bodyZones: ["left_shoulder"],
        recoveryGoal: "mobility",
        romValues: {},
        asymmetryScores: {},
        movementQualityScores: {},
        highlightedRegions: [],
      },
    }),
    [mirroredVideo],
    [],
    [],
    "initial_intake",
  );

  assertExists(draft);
  assertEquals(draft.items[0].region, "left_shoulder");
  assertEquals(draft.items[0].exercise_video_id, "V03");
});

Deno.test("generateRecoveryPlanDraft deduplicates repeated URLs and overlapping movement patterns", () => {
  const directVideo = makeVideo({
    id: "V01",
    canonical_url: "https://example.com/videos/shared",
    movement_tags: ["shoulder_mobility", "mobility"],
  });
  const duplicateUrlVideo = makeVideo({
    id: "V02",
    canonical_url: "https://example.com/videos/shared",
    movement_tags: ["shoulder_mobility", "scapular_control"],
  });
  const overlappingVideo = makeVideo({
    id: "V03",
    canonical_url: "https://example.com/videos/v03",
    movement_tags: ["shoulder_mobility", "mobility", "upper_back_control"],
  });
  const distinctVideo = makeVideo({
    id: "V04",
    canonical_url: "https://example.com/videos/v04",
    movement_tags: ["thoracic_rotation", "posture"],
  });

  const draft = generateRecoveryPlanDraft(
    makeInput(),
    [directVideo, duplicateUrlVideo, overlappingVideo, distinctVideo],
    [],
    [],
    "initial_intake",
  );

  assertExists(draft);
  assertEquals(draft.items.map((item) => item.exercise_video_id), ["V01", "V04"]);
});

Deno.test("safetyPauseReason pauses immediately for stopped status", () => {
  const reason = safetyPauseReason("stopped", null, null);
  assertExists(reason);
});

Deno.test("safetyPauseReason pauses for worse symptoms with red-flag note", () => {
  const reason = safetyPauseReason("completed", "worse", "Sharp pain in the shoulder during the final range.");
  assertExists(reason);
});
