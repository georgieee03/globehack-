# Implementation Plan: Recovery Intelligence Dashboard

## Overview

This plan implements the Recovery Intelligence Engine (Phase 4) and Practitioner Dashboard (Phase 5) for HydraScan. The backend consists of Supabase Edge Functions (TypeScript/Deno) covering the Rules Engine, History Scorer, Config Builder, Recovery Map, Recovery Graph, Recovery Score, and LLM Explanation Service. The frontend is a React/Next.js Practitioner Dashboard with client management, protocol review, device selection, session lifecycle controls, and post-session workflows. All code uses TypeScript throughout.

## Tasks

- [ ] 1. Shared types and constants
  - [ ] 1.1 Create shared Recovery Intelligence types
    - Create `shared/src/types/recovery-intelligence.ts` with BodyRegion, RecoveryGoal, RecoverySignalType, RecoverySignal, PadPlacement, ModalityMix, SessionOutcomeScore, HistoryResult, ClampingEntry, ConfigBuilderInput, and ConfigBuilderOutput types
    - Create `shared/src/types/recovery-map.ts` with RecoveryMap, HighlightedRegion, WearableContext, and PriorSessionSummary types
    - Create `shared/src/types/recovery-score.ts` with RecoveryScoreInput, RecoveryScoreResult, and RecoveryGraphPoint types
    - Create `shared/src/types/llm-explanation.ts` with LlmExplanationRequest and LlmExplanationResponse types
    - _Requirements: 1.1, 2.1, 5.1, 6.2, 7.2, 8.1, 9.2, 24.3_

  - [ ] 1.2 Create pad placement lookup table
    - Create `shared/src/constants/pad-placement-map.ts` with PAD_PLACEMENT_MAP containing all 15 BodyRegion entries, each with sunRegion, moonRegion, leftFuncs, rightFuncs, and rationale
    - _Requirements: 1.1, 1.2_

  - [ ] 1.3 Create modality mix lookup table
    - Create `shared/src/constants/modality-mix-map.ts` with MODALITY_MIX_MAP containing all 5 RecoveryGoal entries (mobility, warm_up, recovery, relaxation, performance_prep) with edgeCycleDuration, intensityProfile, pwmHot, pwmCold, vibMin, vibMax, led, and rationale
    - Ensure edgeCycleDuration is 7 for warm_up and performance_prep, 9 for recovery, mobility, and relaxation
    - Ensure led is 1 for all goals
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 1.4 Create adjacent regions graph and bilateral pairs
    - Create `shared/src/constants/adjacent-regions.ts` with ADJACENT_REGIONS mapping each BodyRegion to its adjacent regions
    - Create `shared/src/constants/bilateral-pairs.ts` with bilateral joint pair definitions (e.g., right_shoulder/left_shoulder)
    - _Requirements: 1.4, 6.4_

- [ ] 2. Rules Engine implementation
  - [ ] 2.1 Implement selectPrimaryRegion function
    - Create `backend/supabase/functions/recovery-intelligence/rules-engine.ts`
    - Implement `selectPrimaryRegion` that selects the region with the highest severity from highlighted regions; use stable sort (first region wins on tie)
    - _Requirements: 1.3_

  - [ ]* 2.2 Write property test: Primary region selection by highest severity
    - **Property 2: Primary region selection by highest severity**
    - **Validates: Requirements 1.3**

  - [ ] 2.3 Implement mapBodyRegionToPadPlacement function
    - Implement `mapBodyRegionToPadPlacement` that looks up the PadPlacement from PAD_PLACEMENT_MAP for the given primary region
    - Append a compensation hint to the rationale when any adjacent region (per ADJACENT_REGIONS) has asymmetry > 10%
    - _Requirements: 1.1, 1.2, 1.4_

  - [ ]* 2.4 Write property test: Pad Placement output completeness
    - **Property 1: Pad Placement output completeness**
    - **Validates: Requirements 1.1**

  - [ ]* 2.5 Write property test: Compensation hint presence based on asymmetry threshold
    - **Property 3: Compensation hint presence based on asymmetry threshold**
    - **Validates: Requirements 1.4**

  - [ ] 2.6 Implement mapGoalToModalityMix function
    - Implement `mapGoalToModalityMix` that looks up the ModalityMix from MODALITY_MIX_MAP for the given RecoveryGoal
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ]* 2.7 Write property test: Different recovery signals produce different pad placements
    - **Property 22: Different recovery signals produce different pad placements**
    - **Validates: Requirements 21.1**

- [ ] 3. History Scorer implementation
  - [ ] 3.1 Implement scoreSession function
    - Create `backend/supabase/functions/recovery-intelligence/history-scorer.ts`
    - Implement `scoreSession` that scores a single session outcome on a 0.0–1.0 scale: mobility_improved (+0.3), session_effective (+0.3), stiffness_reduction_ratio * 0.2, repeat_intent "yes" (+0.2), clamped to [0.0, 1.0]
    - _Requirements: 4.2_

  - [ ]* 3.2 Write property test: Session outcome scoring formula
    - **Property 6: Session outcome scoring formula**
    - **Validates: Requirements 4.2**

  - [ ] 3.3 Implement computeConfidence function
    - Implement `computeConfidence` that returns `min(1.0, sessionCount * 0.2)`, always in [0.0, 1.0]
    - _Requirements: 4.3_

  - [ ]* 3.4 Write property test: Confidence score formula
    - **Property 7: Confidence score formula**
    - **Validates: Requirements 4.3**

  - [ ] 3.5 Implement scoreHistory function
    - Implement `scoreHistory` that queries the last 5 completed sessions for a client, scores each via `scoreSession`, computes confidence, identifies the best prior config (if score > 0.7), and returns HistoryResult with plain-text adjustment descriptions
    - When client has zero prior sessions, return confidence 0.0 and no history adjustments
    - _Requirements: 4.1, 4.3, 4.4, 4.5_

- [ ] 4. Config Builder implementation
  - [ ] 4.1 Implement buildConfig function
    - Create `backend/supabase/functions/recovery-intelligence/config-builder.ts`
    - Implement the full pipeline: start with ModalityMix defaults → apply sensitivity reduction (20% pwmHot reduction for "first_time" or "heat_sensitive") → apply wearable reduction (15% vib reduction if HRV < 30 or sleepScore < 50) → apply history bias (30% blend toward bestConfig if score > 0.7) → generate cycle choreography → compute totalDuration → validate and clamp against safe envelope with region-specific overrides for neck and lower_back
    - Return ConfigBuilderOutput with sessionConfig and clampingLog
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 21.3_

  - [ ]* 4.2 Write property test: Safe envelope clamping
    - **Property 4: Safe envelope clamping**
    - **Validates: Requirements 3.1, 3.4**

  - [ ]* 4.3 Write property test: Sensitivity flag reduces pwmHot by 20%
    - **Property 5: Sensitivity flag reduces pwmHot by 20%**
    - **Validates: Requirements 3.5**

  - [ ]* 4.4 Write property test: History biasing toward high-scoring prior session
    - **Property 8: History biasing toward high-scoring prior session**
    - **Validates: Requirements 4.4**

  - [ ] 4.5 Implement generateChoreography function
    - Implement `generateChoreography` that produces cycleRepetitions, cycleDurations, cyclePauses, pauseIntervals, leftFuncs, and rightFuncs arrays based on edgeCycleDuration and PadPlacement
    - Default: 3 cycles, cyclePauses [30, 30, 0], leftFuncs/rightFuncs from PadPlacement alternating per cycle
    - _Requirements: 5.1, 5.3_

  - [ ]* 4.6 Write property test: leftFuncs/rightFuncs alternation from PadPlacement
    - **Property 11: leftFuncs/rightFuncs alternation from PadPlacement**
    - **Validates: Requirements 5.3**

  - [ ] 4.7 Implement computeTotalDuration function
    - Implement `computeTotalDuration` that computes sum of (cycleRepetitions[i] * cycleDurations[i]) + sum of cyclePauses + sessionPause
    - _Requirements: 5.2_

  - [ ]* 4.8 Write property test: Total duration computation
    - **Property 10: Total duration computation**
    - **Validates: Requirements 5.2**

  - [ ]* 4.9 Write property test: Config Builder output completeness and structure
    - **Property 9: Config Builder output completeness and structure**
    - **Validates: Requirements 5.1, 5.4**

  - [ ]* 4.10 Write property test: Low HRV or poor sleep reduces vibration intensity
    - **Property 23: Low HRV or poor sleep reduces vibration intensity**
    - **Validates: Requirements 21.3**

  - [ ] 4.11 Implement serializeSessionConfig and deserializeSessionConfig
    - Implement `serializeSessionConfig` that serializes SessionConfig to JSON string with proper quote escaping for the Hydrawav3 MQTT API
    - Implement `deserializeSessionConfig` that deserializes JSON string back to SessionConfig
    - _Requirements: 24.1, 24.3, 24.4_

  - [ ]* 4.12 Write property test: SessionConfig serialization round-trip
    - **Property 24: SessionConfig serialization round-trip**
    - **Validates: Requirements 24.3**

  - [ ] 4.13 Implement clampToSafeEnvelope function
    - Implement `clampToSafeEnvelope` that validates and clamps all numeric SessionConfig parameters against safe envelope ranges (default + region-specific overrides for neck and lower_back)
    - Log each clamping action with parameter name, original value, and clamped value
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 5. Checkpoint — Rules Engine, History Scorer, and Config Builder
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Recovery Map Generator
  - [ ] 6.1 Implement generateRecoveryMap function
    - Create `backend/supabase/functions/recovery-intelligence/recovery-map.ts`
    - Implement the full pipeline: extract highlighted regions from assessment → compute ROM delta vs previous assessment → flag regions with ROM decrease > 5° as declining → flag bilateral asymmetry > 10% → add compensation hints for adjacent regions → attach wearable context → fetch last 3 session summaries → suggest RecoveryGoal based on dominant signal type and severity
    - Store the generated RecoveryMap in the assessment record `recovery_map` JSONB field
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 6.2 Write property test: Recovery Map structural completeness
    - **Property 12: Recovery Map structural completeness**
    - **Validates: Requirements 6.2**

  - [ ]* 6.3 Write property test: ROM decrease flagging
    - **Property 13: ROM decrease flagging**
    - **Validates: Requirements 6.3**

  - [ ]* 6.4 Write property test: Asymmetry flag threshold
    - **Property 14: Asymmetry flag threshold**
    - **Validates: Requirements 6.4**

- [ ] 7. Recovery Score Calculator
  - [ ] 7.1 Implement computeRecoveryScore function
    - Create `backend/supabase/functions/recovery-intelligence/recovery-score.ts`
    - Implement computation from baseline 50: outcome trend (±20), check-in trend (±10), wearable adjustment (±10), adherence bonus (0–10), clamped to [0, 100]
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ]* 7.2 Write property test: Recovery Score computation with clamping
    - **Property 15: Recovery Score computation with clamping**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4**

- [ ] 8. Recovery Graph data layer
  - [ ] 8.1 Implement Recovery Graph insertion and query functions
    - Create `backend/supabase/functions/recovery-intelligence/recovery-graph.ts`
    - Implement `insertRecoveryGraphPoints` that inserts data points (client_id, body_region, metric_type, value, source, source_id, recorded_at) into the `recovery_graph` table when a session outcome is recorded
    - Implement `insertCheckinGraphPoints` that inserts data points when a daily check-in is submitted
    - Implement `queryRecoveryGraph` that returns time-series data points for a client and body region, ordered by recorded_at descending, with configurable limit (default 30)
    - Implement Recovery Score recomputation trigger: when an outcome or check-in is recorded, recompute the client's Recovery Score and insert the new value into recovery_graph with metric_type "recovery_score"
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.5_

- [ ] 9. LLM Explanation Service
  - [ ] 9.1 Implement LLM prompt builder
    - Create `backend/supabase/functions/llm-explanation/prompt-builder.ts`
    - Build the LLM prompt with system message (wellness-only language instructions, forbidden terms), client context (name, target regions, ROM/asymmetry values), recommendation context (goal, duration, thermal/vibration settings), history context (prior session count, best outcome score, confidence), and instruction to explain in 2–3 sentences
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ] 9.2 Implement fallback template explanation generator
    - Create `backend/supabase/functions/llm-explanation/fallback-template.ts`
    - Implement `generateFallbackExplanation` using the template pattern with confidence-based statements (≥70%, 50–69%, <50%)
    - _Requirements: 9.6_

  - [ ] 9.3 Implement LLM Explanation Edge Function
    - Create `backend/supabase/functions/llm-explanation/index.ts`
    - Implement the Edge Function entry point: call LLM API with 3-second timeout, fall back to template on failure/timeout, return LlmExplanationResponse with isFallback flag
    - _Requirements: 9.1, 9.6_

  - [ ]* 9.4 Write property test: Wellness language validation
    - **Property 16: Wellness language validation**
    - **Validates: Requirements 9.3, 22.2**

- [ ] 10. Recovery Intelligence Edge Function (action router)
  - [ ] 10.1 Implement the recovery-intelligence Edge Function entry point
    - Create `backend/supabase/functions/recovery-intelligence/index.ts`
    - Implement action-based routing for `recommend`, `recovery-map`, `recovery-score`, and `recovery-graph` actions
    - Validate JWT authentication; return 401 for unauthenticated requests
    - Validate clinic scoping via RLS; return 403 for cross-clinic requests
    - Return 400 for invalid action parameter
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5_

  - [ ] 10.2 Implement the `recommend` action handler
    - Wire together: fetch assessment + client profile → Rules Engine (selectPrimaryRegion, mapBodyRegionToPadPlacement, mapGoalToModalityMix) → History Scorer (scoreHistory) → Config Builder (buildConfig) → Recovery Map (generateRecoveryMap) → Recovery Score (computeRecoveryScore) → LLM Explanation → return RecommendResponse
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 8.5, 9.1, 23.1_

  - [ ] 10.3 Implement the `recovery-map`, `recovery-score`, and `recovery-graph` action handlers
    - `recovery-map`: fetch assessment + client profile, generate and return RecoveryMap
    - `recovery-score`: compute and return current Recovery Score for client
    - `recovery-graph`: query and return time-series data points for client + body region with configurable limit
    - _Requirements: 6.1, 7.3, 8.4, 23.2, 23.3_

- [ ] 11. Checkpoint — Backend Edge Functions complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Dashboard project setup and shared infrastructure
  - [ ] 12.1 Initialize the Next.js dashboard project
    - Create `dashboard/` directory with Next.js app router, TypeScript, and Tailwind CSS
    - Set up `package.json`, `tsconfig.json`, and project configuration
    - Create `dashboard/src/app/layout.tsx` with root layout and navigation
    - Create `dashboard/src/app/page.tsx` that redirects to `/clients`
    - _Requirements: 10.1, 19.1_

  - [ ] 12.2 Create Supabase client and Edge Function wrappers
    - Create `dashboard/src/lib/supabase-client.ts` with Supabase client initialization
    - Create `dashboard/src/lib/edge-functions.ts` with typed wrappers for all Edge Function calls (recommend, recovery-map, recovery-score, recovery-graph, llm-explanation, MQTT proxy)
    - Create `dashboard/src/types/index.ts` re-exporting types from shared package
    - _Requirements: 23.1, 23.2, 23.3_

  - [ ] 12.3 Create core React hooks
    - Create `dashboard/src/hooks/useSupabase.ts` for Supabase client access
    - Create `dashboard/src/hooks/useRecommendation.ts` for fetching recommendations
    - Create `dashboard/src/hooks/useRecoveryMap.ts` for fetching Recovery Maps
    - Create `dashboard/src/hooks/useRecoveryGraph.ts` for fetching Recovery Graph data
    - Create `dashboard/src/hooks/useRecoveryScore.ts` for fetching Recovery Scores
    - Create `dashboard/src/hooks/useDevices.ts` for fetching device list
    - Create `dashboard/src/hooks/useRealtimeDevice.ts` for Supabase Realtime device status subscription
    - Create `dashboard/src/hooks/useSessionLifecycle.ts` for session lifecycle controls (pause, resume, stop) and elapsed time tracking
    - _Requirements: 15.1, 16.1, 16.2, 19.4_

- [ ] 13. Client List View
  - [ ] 13.1 Implement Client List page and components
    - Create `dashboard/src/app/clients/page.tsx` as the Client List View
    - Create `dashboard/src/components/client-list/ClientListTable.tsx` displaying all clients in the practitioner's clinic (scoped by clinic_id via RLS)
    - Create `dashboard/src/components/client-list/ClientRow.tsx` showing full name, latest Recovery Score (0–100), primary body regions, most recent session date, and next session status
    - Create `dashboard/src/components/client-list/SortControls.tsx` with default sort by most recent activity and option to sort by Recovery Score ascending
    - Navigate to Client Detail View on row tap
    - Use wellness language: "client" not "patient" throughout
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 22.1, 22.2_

  - [ ]* 13.2 Write property test: Client list sorting
    - **Property 17: Client list sorting**
    - **Validates: Requirements 10.3**

- [ ] 14. Client Detail View
  - [ ] 14.1 Implement Client Detail page
    - Create `dashboard/src/app/clients/[clientId]/page.tsx` as the Client Detail View
    - Render within 5 seconds of navigation using pre-fetched data
    - _Requirements: 11.1, 19.1_

  - [ ] 14.2 Implement Recovery Map display with body avatar
    - Create `dashboard/src/components/client-detail/RecoveryMapDisplay.tsx` displaying highlighted regions with severity indicators, ROM deltas, and asymmetry flags
    - Create `dashboard/src/components/client-detail/BodyAvatar.tsx` showing a body avatar with highlighted regions
    - _Requirements: 11.1_

  - [ ] 14.3 Implement Recovery Graph chart
    - Create `dashboard/src/components/client-detail/RecoveryGraphChart.tsx` displaying time-series chart with ROM, asymmetry, and Recovery Score trends per body region
    - Load async after initial render to meet performance constraints
    - _Requirements: 11.2_

  - [ ] 14.4 Implement wearable context and session history
    - Create `dashboard/src/components/client-detail/WearableContextCard.tsx` displaying HRV, strain, sleep score, and last sync; omit section when no wearable data exists
    - Create `dashboard/src/components/client-detail/SessionHistoryList.tsx` displaying last 3 session summaries with date, config summary, outcome rating, and practitioner notes
    - _Requirements: 11.3, 11.4, 18.3_

  - [ ] 14.5 Display recommended SessionConfig with explanation
    - Display the recommended SessionConfig, LLM-generated explanation, confidence score, and action buttons (Approve / Edit Protocol) on the Client Detail View
    - _Requirements: 11.5, 20.1, 20.2_

- [ ] 15. Protocol Recommendation Review and Editing
  - [ ] 15.1 Implement Protocol Recommendation View
    - Create `dashboard/src/app/clients/[clientId]/protocol/page.tsx`
    - Create `dashboard/src/components/protocol/ProtocolCard.tsx` displaying recovery goal, session duration, Sun/Moon pad placement, thermal intensity, vibration range, LED status, and cycle choreography summary
    - Create `dashboard/src/components/protocol/ExplanationCard.tsx` displaying LLM-generated explanation text
    - Create `dashboard/src/components/protocol/ConfidenceBadge.tsx` displaying confidence score as percentage; show low-confidence notice when below 50%
    - Display History Scorer adjustments as plain-text statements
    - Present all on a single scrollable screen requiring no more than two taps to approve and launch
    - _Requirements: 12.1, 12.2, 19.2, 20.1, 20.2, 20.3, 20.4_

  - [ ]* 15.2 Write property test: Low confidence notice threshold
    - **Property 21: Low confidence notice threshold**
    - **Validates: Requirements 20.3**

  - [ ] 15.3 Implement Protocol Editor with constrained sliders
    - Create `dashboard/src/components/protocol/ProtocolEditor.tsx` with editable parameters
    - Create `dashboard/src/components/protocol/ConstrainedSlider.tsx` with min/max from safe envelope (region-adjusted), step, unit, and recommended value marker
    - Enforce safe envelope constraints on all sliders so practitioners cannot set values outside safe ranges
    - Store original recommended_config and practitioner_edits in the sessions table
    - On approve (with or without edits), proceed to Session Launch Workflow
    - _Requirements: 12.3, 12.4, 12.5, 12.6_

- [ ] 16. Device Selection and Session Launch
  - [ ] 16.1 Implement Device Selection
    - Create `dashboard/src/components/device/DeviceList.tsx` displaying all devices in the practitioner's clinic with label, room, MAC address, and status
    - Create `dashboard/src/components/device/DeviceCard.tsx` with visual status distinction: idle (available, selectable), in_session (occupied), paused (occupied), maintenance (unavailable), offline (unavailable)
    - Allow selection of only idle devices
    - _Requirements: 13.1, 13.2, 13.3_

  - [ ]* 16.2 Write property test: Only idle devices selectable
    - **Property 18: Only idle devices selectable**
    - **Validates: Requirements 13.3**

  - [ ] 16.3 Implement Session Launch workflow
    - On device selection + "Launch Session" tap: set SessionConfig mac field to selected device MAC, send complete SessionConfig with playCmd=1 to MQTT proxy Edge Function
    - If safe envelope validation fails, display violations with parameter names, actual values, and allowed ranges; do not send to device
    - On success: create session record with status "active", store session_config, recommended_config, practitioner_edits, recommendation_rationale; navigate to active session view
    - On MQTT error: display error message and allow retry
    - Ensure no more than 3 steps from client selection to session start
    - _Requirements: 13.4, 14.1, 14.2, 14.3, 14.4, 14.5, 19.3_

- [ ] 17. Real-Time Session Controls
  - [ ] 17.1 Implement Active Session View
    - Create `dashboard/src/app/clients/[clientId]/session/page.tsx`
    - Create `dashboard/src/components/session/SessionStatusDisplay.tsx` showing current session status (active/paused), elapsed time counter, device label
    - Create `dashboard/src/components/session/ElapsedTimer.tsx` with real-time elapsed time counter
    - Create `dashboard/src/components/session/SimulationBadge.tsx` displayed when MQTT proxy is in simulation mode
    - Subscribe to Supabase Realtime on the devices table filtered by device_id; update displayed status within 2 seconds of change
    - When device status changes from "in_session" to "idle" externally, update session to "completed" and navigate to post-session
    - _Requirements: 15.1, 15.2, 15.3_

  - [ ] 17.2 Implement Lifecycle Controls
    - Create `dashboard/src/components/session/LifecycleControls.tsx` with conditional button rendering based on session status
    - Active status: show Pause (playCmd=2) and Stop (playCmd=3) buttons
    - Paused status: show Resume (playCmd=4) and Stop (playCmd=3) buttons
    - Pause: send playCmd=2 to MQTT proxy, update session to "paused", device to "paused"
    - Resume: send playCmd=4 to MQTT proxy, update session to "active", device to "in_session"
    - Stop: send playCmd=3 to MQTT proxy, update session to "completed", device to "idle", record completed_at, navigate to post-session
    - On lifecycle command failure: display error message, retain current session state
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6_

  - [ ]* 17.3 Write property test: Lifecycle buttons by session status
    - **Property 19: Lifecycle buttons by session status**
    - **Validates: Requirements 16.1, 16.2**

- [ ] 18. Checkpoint — Dashboard core views and session lifecycle
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 19. Post-Session Workflow
  - [ ] 19.1 Implement Post-Session page and Re-Test workflow
    - Create `dashboard/src/app/clients/[clientId]/post-session/page.tsx`
    - Offer "Re-Test" option that navigates to a shortened QuickPose capture flow targeting only the session's primary body regions
    - _Requirements: 17.1_

  - [ ] 19.2 Implement Re-Test Comparison display
    - Create `dashboard/src/components/post-session/RetestComparison.tsx` with side-by-side pre/post ROM, asymmetry, and movement quality comparison
    - Create `dashboard/src/components/post-session/RomDeltaTable.tsx` computing ROM deltas (post - pre) for each joint; highlight positive deltas as improvements
    - Store re-test values in the session record `retest_values` JSONB field
    - _Requirements: 17.2, 17.3, 17.4_

  - [ ]* 19.3 Write property test: ROM delta computation
    - **Property 20: ROM delta computation**
    - **Validates: Requirements 17.3**

  - [ ] 19.4 Implement Session Notes
    - Create `dashboard/src/components/post-session/SessionNotesEditor.tsx` with text input for practitioner notes
    - Save notes to the sessions table `practitioner_notes` field
    - Display prior session notes in the Client Detail View session history section
    - _Requirements: 18.1, 18.2, 18.3_

- [ ] 20. Wellness language compliance and display formatting
  - [ ] 20.1 Implement wellness language utilities and dashboard text compliance
    - Create `dashboard/src/lib/formatters.ts` with display formatting utilities
    - Implement a wellness language validator/replacer that flags forbidden clinical terms ("patient", "treats", "diagnoses", "clinical findings", "medical results") and provides wellness replacements ("client", "supports", "movement insights", etc.)
    - Audit all dashboard user-facing text to use "client" instead of "patient", wellness terms throughout, and "Hydrawav3" (lowercase w) for device references
    - _Requirements: 22.1, 22.2, 22.3, 22.4_

- [ ] 21. Pre-loading and performance optimization
  - [ ] 21.1 Implement pre-loading strategy for two-minute workflow
    - Pre-fetch recommendation, device list, and Recovery Map when client list loads
    - Ensure Client Detail View renders within 5 seconds of client row tap
    - Pre-load recommended SessionConfig and device list so practitioner does not wait between steps
    - Implement skeleton loading for Client List rows and progressive rendering
    - Implement optimistic UI update for session launch ("Launching..." immediately, rollback on error)
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

- [ ] 22. Final checkpoint — Full integration
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests validate universal correctness properties from the design document using fast-check
- Unit tests validate specific examples and edge cases
- The backend (Edge Functions) is implemented first so the dashboard can consume real endpoints
- All code is TypeScript: Deno for Edge Functions, React/Next.js for the dashboard
