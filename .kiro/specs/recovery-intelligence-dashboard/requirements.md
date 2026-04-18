# Requirements Document — Recovery Intelligence Dashboard

## Introduction

This document defines the requirements for HydraScan's Recovery Intelligence Engine (Phase 4) and Practitioner Dashboard & Session Workflow (Phase 5). This is Spec 3 of 4 for the HydraScan project, owned by Sri on the `sri-dev` branch.

The Recovery Intelligence Dashboard is the practitioner-facing intelligence and control layer of HydraScan. It takes assessment data (QuickPoseResult: ROM, asymmetry, movement quality), client profile (recovery signals, goals, wearable context), and session history, then outputs a personalized SessionConfig recommendation with a plain-language explanation. The practitioner reviews, optionally edits, selects a device, and launches the session — all within a two-minute interaction window. The dashboard also provides Recovery Map summaries, Recovery Graph time-series tracking, Recovery Score computation, and real-time session lifecycle controls.

This spec depends on the backend-foundation spec (Spec 1) for auth, data layer, device registry, and MQTT proxy. It consumes assessment data produced by the ios-assessment-pipeline spec (Spec 2).

## Glossary

- **Recovery_Intelligence_Engine**: A Supabase Edge Function (TypeScript/Deno) that takes assessment data, client profile, and session history as input and outputs a recommended SessionConfig with confidence score and rationale.
- **Rules_Engine**: The deterministic component of the Recovery_Intelligence_Engine that maps body regions to pad placements, goals to modality modes, and recovery signals to intensity calibration. The Rules_Engine makes all protocol decisions; the LLM does not.
- **History_Scorer**: A sub-component of the Recovery_Intelligence_Engine that queries prior sessions and outcomes for a client, scores each by effectiveness, and adjusts the recommendation based on what worked before.
- **Config_Builder**: A sub-component of the Recovery_Intelligence_Engine that assembles a complete SessionConfig from Rules_Engine output, History_Scorer adjustments, and safe envelope constraints.
- **Recovery_Map**: A structured 60-second practitioner summary containing highlighted body regions with severity, signal type, ROM delta, asymmetry flags, compensation hints, wearable context, prior session outcomes, and a suggested recovery goal.
- **Recovery_Graph**: A time-series data structure in the `recovery_graph` table tracking ROM, asymmetry, stiffness, and Recovery Score per body region per client across visits.
- **Recovery_Score**: A single number (0–100) computed from recent session outcomes, daily check-in data, wearable context, and session adherence, representing the client's recovery trajectory.
- **SessionConfig**: The TypeScript interface defining the full MQTT payload schema for a Hydrawav3 session, including MAC address, cycle choreography, modality sequences, thermal intensity, vibration ranges, and play command.
- **Safe_Envelope**: A set of min/max range constraints for all SessionConfig parameters that prevent unsafe values from being sent to the device, with region-specific overrides.
- **LLM_Explanation_Service**: A Supabase Edge Function that takes structured recovery data and the recommended SessionConfig, then outputs a 2–3 sentence plain-language explanation for the practitioner using wellness-only language.
- **Practitioner_Dashboard**: The practitioner-facing iPad/web application providing client list, client detail, protocol recommendation review, session launch, real-time session control, and post-session workflows.
- **Client_List_View**: The main dashboard screen showing all clients in the practitioner's clinic with their latest Recovery Score and next session status.
- **Client_Detail_View**: The per-client screen showing Recovery Map, Recovery Graph, session history, and assessment data.
- **Protocol_Recommendation_View**: The screen where the practitioner reviews the recommended SessionConfig with its LLM-generated explanation, confidence score, and can approve or edit the protocol.
- **Session_Launch_Workflow**: The sequence where the practitioner selects a device from the registry, reviews or edits the SessionConfig, and launches the session via the MQTT proxy.
- **Pad_Placement**: The recommended Sun (warming, red) and Moon (cooling, blue) pad positions based on the client's target body regions and recovery signals.
- **Modality_Mix**: The combination of thermal modulation, photobiomodulation (LED), and vibro-acoustic stimulation selected based on the client's recovery goal.
- **Intensity_Calibration**: The process of setting PWM values, vibration ranges, and thermal drop values within safe envelope constraints based on the client's sensitivity, history, and target region.
- **Cycle_Choreography**: The generated sequence of cycleRepetitions, cycleDurations, cyclePauses, leftFuncs, rightFuncs, and pwmValues that define the session's modality pattern over time.
- **QuickPoseResult**: The structured output from the iOS assessment pipeline containing landmarks, joint angles, ROM values, asymmetry scores, movement quality scores, and capture timestamp.
- **BodyRegion**: One of 15 body region identifiers (e.g., right_shoulder, lower_back, left_knee, neck) used throughout the system.
- **RecoveryGoal**: One of five goal types: mobility, warm_up, recovery, relaxation, or performance_prep.
- **Supabase_Realtime**: Supabase's WebSocket-based subscription service used to push device status changes and session state updates to the Practitioner_Dashboard in real time.

## Requirements

### Requirement 1: Rules Engine — Body Region to Pad Placement Mapping

**User Story:** As a practitioner, I want the system to recommend Sun and Moon pad placements based on the client's target body regions, so that I get a personalized starting point for pad positioning without guesswork.

#### Acceptance Criteria

1. WHEN an assessment with highlighted body regions is provided, THE Rules_Engine SHALL map each BodyRegion to a recommended Pad_Placement containing sunRegion (warming pad location), moonRegion (cooling pad location), leftFuncs (modality sequence array), rightFuncs (modality sequence array), and a plain-text rationale.
2. THE Rules_Engine SHALL define Pad_Placement mappings for all 15 BodyRegion values: right_shoulder, left_shoulder, right_hip, left_hip, lower_back, upper_back, right_knee, left_knee, neck, right_calf, left_calf, right_arm, left_arm, right_foot, and left_foot.
3. WHEN multiple body regions are highlighted, THE Rules_Engine SHALL select the primary region based on the highest severity recovery signal and use that region's Pad_Placement as the base recommendation.
4. THE Rules_Engine SHALL include a compensation hint in the Pad_Placement rationale when the assessment data indicates asymmetry above 10% in an adjacent body region (e.g., "Likely compensating from lower back" when shoulder asymmetry is high and lower back stiffness is present).

### Requirement 2: Rules Engine — Goal to Modality Mix Configuration

**User Story:** As a practitioner, I want the system to select the right modality mix (thermal, LED, vibration) based on the client's recovery goal, so that the session is tailored to what the client needs today.

#### Acceptance Criteria

1. THE Rules_Engine SHALL define a Modality_Mix configuration for each of the five RecoveryGoal values: mobility, warm_up, recovery, relaxation, and performance_prep.
2. WHEN a RecoveryGoal is provided, THE Rules_Engine SHALL output a Modality_Mix containing edgeCycleDuration (minutes), intensityProfile (gentle, moderate, or intense), pwmHot values (array of three), pwmCold values (array of three), vibMin, vibMax, led toggle (0 or 1), and a plain-text rationale explaining why this mix supports the selected goal.
3. THE Rules_Engine SHALL set edgeCycleDuration to 7 minutes for warm_up and performance_prep goals, and 9 minutes for recovery, mobility, and relaxation goals.
4. THE Rules_Engine SHALL set the led toggle to 1 (photobiomodulation active) for all RecoveryGoal values.

### Requirement 3: Intensity Calibration with Safe Envelope Constraints

**User Story:** As a practitioner, I want all session parameters to stay within safe ranges, with tighter limits for sensitive regions, so that the device operates safely for every client.

#### Acceptance Criteria

1. THE Config_Builder SHALL validate every numeric SessionConfig parameter against the Safe_Envelope before the configuration is presented to the practitioner or sent to the MQTT proxy.
2. THE Safe_Envelope SHALL enforce default ranges: pwmValues.hot (30–150), pwmValues.cold (100–255), vibMin (10–50), vibMax (100–255), hotDrop (1–10), coldDrop (1–10), and edgeCycleDuration (5–15).
3. THE Safe_Envelope SHALL apply region-specific overrides that tighten the default ranges: neck (pwmHotMax: 100, vibMaxCeiling: 180) and lower_back (pwmHotMax: 120, vibMaxCeiling: 200).
4. IF any generated SessionConfig parameter falls outside the Safe_Envelope range, THEN THE Config_Builder SHALL clamp the value to the nearest boundary and log the clamping action with the parameter name, original value, and clamped value.
5. WHEN the client profile contains a sensitivity flag (e.g., "first_time" or "heat_sensitive"), THE Config_Builder SHALL reduce pwmHot values by 20% from the goal-mode default before applying safe envelope validation.

### Requirement 4: History-Based Recommendation Adjustment

**User Story:** As a practitioner, I want the system to learn from prior sessions and adjust recommendations based on what worked for this specific client, so that protocols improve over time rather than being one-size-fits-all.

#### Acceptance Criteria

1. WHEN generating a recommendation, THE History_Scorer SHALL query the last five completed sessions for the client from the `sessions` table, ordered by completion date descending.
2. THE History_Scorer SHALL score each prior session on a 0.0–1.0 scale based on outcome data: mobility_improved (+0.3), session_effective (+0.3), stiffness reduction (+0.2), and repeat_intent "yes" (+0.2).
3. THE History_Scorer SHALL compute a confidence score from 0.0 (no prior sessions) to 1.0 (five or more completed sessions), calculated as `min(1.0, sessionCount * 0.2)`.
4. WHEN the History_Scorer finds a prior session with an outcome score above 0.7, THE Recovery_Intelligence_Engine SHALL bias the new recommendation toward that session's configuration parameters.
5. WHEN the client has zero prior sessions, THE History_Scorer SHALL return a confidence of 0.0 and the Recovery_Intelligence_Engine SHALL use the default goal-mode configuration with no history adjustments.

### Requirement 5: Cycle Choreography Generation

**User Story:** As a system, I want the Recovery Intelligence Engine to generate complete cycle choreography arrays, so that the SessionConfig sent to the device contains valid cycleRepetitions, cycleDurations, cyclePauses, leftFuncs, rightFuncs, and pwmValues.

#### Acceptance Criteria

1. THE Config_Builder SHALL generate a complete SessionConfig containing all required MQTT payload fields: mac, sessionCount, sessionPause, sDelay, cycle1, cycle5, edgeCycleDuration, cycleRepetitions (array), cycleDurations (array), cyclePauses (array), pauseIntervals (array), leftFuncs (array of ModalityFunc), rightFuncs (array of ModalityFunc), pwmValues (object with hot and cold arrays), playCmd, led, hotDrop, coldDrop, vibMin, vibMax, and totalDuration.
2. THE Config_Builder SHALL compute totalDuration in seconds from the cycle choreography parameters (cycleRepetitions, cycleDurations, cyclePauses, and sessionPause).
3. THE Config_Builder SHALL set leftFuncs and rightFuncs arrays based on the Pad_Placement output from the Rules_Engine, ensuring Sun pad (warming) and Moon pad (cooling) alternate correctly across cycles.
4. THE Config_Builder SHALL set pwmValues.hot and pwmValues.cold as three-element arrays, with values derived from the Modality_Mix and adjusted by the History_Scorer and Intensity_Calibration.

### Requirement 6: Recovery Map Generation

**User Story:** As a practitioner, I want a 60-second Recovery Map summary when I open a client's profile, so that I can quickly understand the client's current recovery state, key regions of concern, and relevant context.

#### Acceptance Criteria

1. WHEN a practitioner opens a client's detail view, THE Recovery_Intelligence_Engine SHALL generate a Recovery_Map within 5 seconds.
2. THE Recovery_Map SHALL contain: highlighted regions (each with severity 1–10, signal type, ROM delta compared to the previous assessment, asymmetry flag as boolean, and optional compensation hint), wearable context (HRV, strain, sleep score, last sync timestamp), prior sessions (date, config summary, outcome rating for the last three sessions), a suggested RecoveryGoal, and a generation timestamp.
3. WHEN the current assessment shows a ROM decrease of more than 5 degrees compared to the previous assessment for a joint, THE Recovery_Map SHALL flag that region with a ROM delta value and mark the trend as declining.
4. WHEN the asymmetry score for a bilateral joint pair exceeds 10%, THE Recovery_Map SHALL set the asymmetry flag to true for that region.
5. THE Recovery_Map SHALL be stored in the Assessment record `recovery_map` JSONB field for retrieval by the Practitioner_Dashboard.

### Requirement 7: Recovery Graph — Time-Series Tracking

**User Story:** As a practitioner, I want to see a client's recovery data over time per body region, so that I can identify trends, track progress, and make informed decisions about future sessions.

#### Acceptance Criteria

1. WHEN a session outcome is recorded, THE Recovery_Intelligence_Engine SHALL insert data points into the `recovery_graph` table for each measured metric: stiffness, ROM values, asymmetry scores, and Recovery Score.
2. THE Recovery_Graph SHALL store each data point with: client_id, body_region, metric_type (e.g., "rom_flexion", "stiffness", "asymmetry", "recovery_score"), numeric value, source (assessment, session_outcome, daily_checkin, or wearable), source_id, and recorded_at timestamp.
3. WHEN the Practitioner_Dashboard requests Recovery Graph data, THE Recovery_Intelligence_Engine SHALL return time-series data points for a specified client and body region, ordered by recorded_at descending, with a configurable limit (default 30 data points).
4. WHEN a daily check-in is submitted by the client, THE Recovery_Intelligence_Engine SHALL insert a recovery_graph data point for overall feeling and target region status.

### Requirement 8: Recovery Score Computation

**User Story:** As a practitioner, I want each client to have a Recovery Score (0–100) that summarizes their recovery trajectory, so that I can quickly assess who needs attention and track progress across my client base.

#### Acceptance Criteria

1. THE Recovery_Intelligence_Engine SHALL compute a Recovery_Score starting from a baseline of 50, adjusted by four factors: outcome trend (up to ±20 points), check-in trend (up to ±10 points), wearable context (up to ±10 points), and session adherence (up to +10 points).
2. WHEN computing the outcome trend factor, THE Recovery_Intelligence_Engine SHALL average the stiffness reduction ratio across recent outcomes, where each outcome contributes `(stiffness_before - stiffness_after) / 10 * 20` points.
3. WHEN computing the check-in trend factor, THE Recovery_Intelligence_Engine SHALL average the overall_feeling values from recent daily check-ins and apply `(averageFeeling - 3) * 5` points, where 3 is the neutral baseline.
4. THE Recovery_Intelligence_Engine SHALL clamp the final Recovery_Score to the range 0–100.
5. WHEN a session outcome or daily check-in is recorded, THE Recovery_Intelligence_Engine SHALL recompute the client's Recovery_Score and insert the new value into the `recovery_graph` table with metric_type "recovery_score".

### Requirement 9: LLM Explanation Service

**User Story:** As a practitioner, I want a plain-language explanation of why a specific protocol was recommended, so that I understand the reasoning and can make an informed decision to approve or modify it.

#### Acceptance Criteria

1. WHEN the Recovery_Intelligence_Engine generates a SessionConfig recommendation, THE LLM_Explanation_Service SHALL produce a 2–3 sentence plain-language explanation describing why this protocol was recommended for this client.
2. THE LLM_Explanation_Service SHALL receive structured input containing: target region, recovery goal, ROM values, asymmetry scores, prior session count, best prior outcome score, confidence percentage, and the recommended SessionConfig parameters (duration, thermal PWM, vibration range, LED status).
3. THE LLM_Explanation_Service SHALL use wellness-only language in all generated text: "supports" instead of "treats," "recovery" and "wellness" instead of "clinical" or "medical," and "movement insights" instead of "clinical findings."
4. THE LLM_Explanation_Service SHALL reference specific data points from the client's assessment in the explanation (e.g., ROM values, asymmetry percentages, outcome trends) to show WHY the recommendation was made.
5. THE LLM_Explanation_Service SHALL NOT make protocol decisions — the explanation SHALL describe the decision already made by the Rules_Engine and History_Scorer.
6. IF the LLM API call fails or times out, THEN THE LLM_Explanation_Service SHALL return a fallback explanation generated from a template using the structured input data, without blocking the recommendation workflow.

### Requirement 10: Practitioner Client List View

**User Story:** As a practitioner, I want to see all my clinic's clients in a list with their latest Recovery Score and session status, so that I can quickly identify who needs attention and manage my daily workflow.

#### Acceptance Criteria

1. WHEN a practitioner opens the Practitioner_Dashboard, THE Client_List_View SHALL display all clients in the practitioner's clinic, fetched from the `client_profiles` table scoped by the practitioner's clinic_id via RLS.
2. THE Client_List_View SHALL display for each client: full name, latest Recovery_Score (0–100), primary body regions, most recent session date, and next session status (e.g., "Assessment ready," "Awaiting session," "In session").
3. THE Client_List_View SHALL sort clients by most recent activity by default, with an option to sort by Recovery Score (ascending, to surface clients who need the most attention).
4. WHEN a practitioner taps a client row, THE Practitioner_Dashboard SHALL navigate to the Client_Detail_View for that client.

### Requirement 11: Client Detail View — Recovery Map and Graph Display

**User Story:** As a practitioner, I want to see a client's Recovery Map, Recovery Graph, session history, and assessment data on a single detail screen, so that I have full context before making session decisions.

#### Acceptance Criteria

1. WHEN the practitioner opens a Client_Detail_View, THE Practitioner_Dashboard SHALL display the client's Recovery_Map with a body avatar showing highlighted regions, severity indicators, ROM deltas, and asymmetry flags.
2. THE Client_Detail_View SHALL display the Recovery_Graph as a time-series chart showing ROM, asymmetry, and Recovery Score trends per body region over the client's visit history.
3. THE Client_Detail_View SHALL display the client's wearable context (HRV, strain, sleep score, last sync) when available, and omit the wearable section when no wearable data exists.
4. THE Client_Detail_View SHALL display the last three session summaries with date, configuration summary, and outcome rating.
5. THE Client_Detail_View SHALL display the recommended SessionConfig with its LLM-generated explanation, confidence score, and action buttons to approve or edit the protocol.

### Requirement 12: Protocol Recommendation Review and Editing

**User Story:** As a practitioner, I want to review the recommended SessionConfig, see why it was recommended, and optionally edit parameters within safe ranges before launching a session, so that I maintain control over every session while benefiting from intelligent defaults.

#### Acceptance Criteria

1. THE Protocol_Recommendation_View SHALL display the recommended SessionConfig parameters: recovery goal, session duration, Sun pad placement, Moon pad placement, thermal intensity (hot and cold PWM), vibration range (min and max), LED status, and cycle choreography summary.
2. THE Protocol_Recommendation_View SHALL display the LLM-generated explanation text and the confidence score as a percentage.
3. WHEN the practitioner taps "Edit Protocol," THE Practitioner_Dashboard SHALL present a protocol editor with constrained sliders and controls for each editable parameter.
4. THE protocol editor SHALL enforce Safe_Envelope constraints on all sliders: the practitioner SHALL NOT be able to set any parameter outside the safe range for the target body region.
5. WHEN the practitioner modifies any parameter, THE Practitioner_Dashboard SHALL store the original recommended_config and the practitioner's edits in the `sessions` table fields `recommended_config` and `practitioner_edits`.
6. WHEN the practitioner approves the protocol (with or without edits), THE Practitioner_Dashboard SHALL proceed to the Session_Launch_Workflow.

### Requirement 13: Device Selection for Session Launch

**User Story:** As a practitioner, I want to select an available device from my clinic's registry before launching a session, so that the session targets the correct HydraWav3Pro device.

#### Acceptance Criteria

1. WHEN the practitioner proceeds to launch a session, THE Practitioner_Dashboard SHALL display all devices in the practitioner's clinic from the `devices` table, showing device label, room assignment, MAC address, and current status.
2. THE Practitioner_Dashboard SHALL visually distinguish device statuses: idle (available, selectable), in_session (occupied, not selectable), paused (occupied, not selectable), maintenance (unavailable), and offline (unavailable).
3. THE Practitioner_Dashboard SHALL allow the practitioner to select only devices with status "idle."
4. WHEN the practitioner selects a device and taps "Launch Session," THE Practitioner_Dashboard SHALL set the SessionConfig `mac` field to the selected device's MAC address and invoke the MQTT proxy Edge Function.

### Requirement 14: Session Launch via MQTT Proxy

**User Story:** As a practitioner, I want to launch a Hydrawav3 session by pressing a single button after reviewing the protocol and selecting a device, so that the session starts on the real device with minimal friction.

#### Acceptance Criteria

1. WHEN the practitioner launches a session, THE Practitioner_Dashboard SHALL send the complete SessionConfig with playCmd set to 1 (Start) to the MQTT proxy Edge Function.
2. THE MQTT proxy SHALL validate the SessionConfig against the Safe_Envelope before publishing to the Hydrawav3 API.
3. IF Safe_Envelope validation fails, THEN THE Practitioner_Dashboard SHALL display the list of violations with parameter names, actual values, and allowed ranges, and SHALL NOT send the command to the device.
4. WHEN the MQTT proxy successfully publishes the Start command, THE Practitioner_Dashboard SHALL create a session record in the `sessions` table with status "active," store the session_config, recommended_config, practitioner_edits, and recommendation_rationale, and navigate to the real-time session view.
5. IF the MQTT proxy returns an error, THEN THE Practitioner_Dashboard SHALL display the error message and allow the practitioner to retry.

### Requirement 15: Real-Time Session Status Display

**User Story:** As a practitioner, I want to see the real-time status of an active session (idle, in_session, paused) on my dashboard, so that I know what the device is doing at all times.

#### Acceptance Criteria

1. WHEN a session is active, THE Practitioner_Dashboard SHALL subscribe to Supabase_Realtime on the `devices` table filtered by the session's device_id, and update the displayed device status within 2 seconds of a status change.
2. THE Practitioner_Dashboard SHALL display the current session status (active, paused), an elapsed time counter, the device label, and a simulation badge when the MQTT proxy is operating in simulation mode.
3. WHEN the device status changes from "in_session" to "idle" (session completed externally), THE Practitioner_Dashboard SHALL update the session record status to "completed" and navigate to the post-session workflow.

### Requirement 16: Session Lifecycle Controls

**User Story:** As a practitioner, I want Start, Pause, Resume, and Stop buttons during an active session, so that I can control the Hydrawav3 device in real time from the dashboard.

#### Acceptance Criteria

1. WHILE a session has status "active," THE Practitioner_Dashboard SHALL display Pause and Stop buttons.
2. WHILE a session has status "paused," THE Practitioner_Dashboard SHALL display Resume and Stop buttons.
3. WHEN the practitioner taps Pause, THE Practitioner_Dashboard SHALL send a command with playCmd 2 to the MQTT proxy and update the session status to "paused" and the device status to "paused."
4. WHEN the practitioner taps Resume, THE Practitioner_Dashboard SHALL send a command with playCmd 4 to the MQTT proxy and update the session status to "active" and the device status to "in_session."
5. WHEN the practitioner taps Stop, THE Practitioner_Dashboard SHALL send a command with playCmd 3 to the MQTT proxy, update the session status to "completed," update the device status to "idle," record the completed_at timestamp, and navigate to the post-session workflow.
6. IF a lifecycle command fails, THEN THE Practitioner_Dashboard SHALL display an error message and retain the current session state without changing the status.

### Requirement 17: Post-Session Re-Test Workflow

**User Story:** As a practitioner, I want to trigger a quick re-assessment after a session to compare pre and post ROM values, so that I can objectively measure the session's immediate impact.

#### Acceptance Criteria

1. WHEN a session completes, THE Practitioner_Dashboard SHALL offer a "Re-Test" option that navigates the client to a shortened QuickPose capture flow targeting only the session's primary body regions.
2. WHEN the re-test assessment completes, THE Practitioner_Dashboard SHALL display a side-by-side comparison of pre-session and post-session ROM values, asymmetry scores, and movement quality scores.
3. THE Practitioner_Dashboard SHALL compute and display ROM deltas (post minus pre) for each measured joint, with positive deltas highlighted as improvements.
4. THE Practitioner_Dashboard SHALL store the re-test values in the session record `retest_values` JSONB field.

### Requirement 18: Practitioner Session Notes

**User Story:** As a practitioner, I want to add free-text notes to each session, so that I can record observations, adjustments, and follow-up plans.

#### Acceptance Criteria

1. THE Practitioner_Dashboard SHALL provide a text input field for practitioner notes on the session detail screen and the post-session workflow screen.
2. WHEN the practitioner enters notes and saves, THE Practitioner_Dashboard SHALL store the text in the `sessions` table `practitioner_notes` field.
3. THE Practitioner_Dashboard SHALL display prior session notes in the Client_Detail_View session history section.

### Requirement 19: Two-Minute Interaction Constraint

**User Story:** As a clinic operator managing 60–80 clients per day, I want every practitioner decision point in the dashboard to complete within two minutes, so that the system fits into a high-volume clinic workflow.

#### Acceptance Criteria

1. THE Practitioner_Dashboard SHALL render the Client_Detail_View (Recovery Map, recommendation, and action buttons) within 5 seconds of the practitioner tapping a client row.
2. THE Protocol_Recommendation_View SHALL present the recommended SessionConfig with explanation and approve/edit actions in a single scrollable screen, requiring no more than two taps to approve and launch with defaults.
3. THE Session_Launch_Workflow SHALL require no more than three steps from client selection to session start: (1) review recommendation, (2) select device, (3) launch.
4. THE Practitioner_Dashboard SHALL pre-load the recommended SessionConfig and device list so that the practitioner does not wait for loading states between steps.

### Requirement 20: Recommendation Transparency — Show WHY, Not Just WHAT

**User Story:** As a practitioner, I want to understand why a specific protocol was recommended, including which data points drove the decision, so that I trust the system and can make informed overrides.

#### Acceptance Criteria

1. THE Protocol_Recommendation_View SHALL display the confidence score as a percentage alongside the recommended SessionConfig.
2. THE Protocol_Recommendation_View SHALL display the LLM-generated explanation that references specific client data points (ROM values, asymmetry percentages, prior outcome scores, wearable context).
3. WHEN the confidence score is below 50%, THE Protocol_Recommendation_View SHALL display a notice indicating limited history data and encouraging the practitioner to review the recommendation carefully.
4. THE Protocol_Recommendation_View SHALL display the History_Scorer adjustments as a list of plain-text statements (e.g., "Reduced intensity based on last 2 sessions," "No prior sessions — using default protocol for this goal").

### Requirement 21: Personalization Over Templates

**User Story:** As a practitioner, I want the system to adapt recommendations to each individual client based on their unique assessment data, history, and context, so that no two clients with different profiles receive identical protocols.

#### Acceptance Criteria

1. WHEN two clients have different recovery signals (different regions, severities, or signal types), THE Recovery_Intelligence_Engine SHALL produce different Pad_Placement recommendations for each client.
2. WHEN two clients have the same recovery goal but different session histories, THE Recovery_Intelligence_Engine SHALL produce different intensity calibrations based on each client's History_Scorer output.
3. WHEN a client has wearable context indicating low HRV (below 30ms) or poor sleep (below 50/100), THE Recovery_Intelligence_Engine SHALL reduce vibration intensity by 15% from the goal-mode default.
4. THE Recovery_Intelligence_Engine SHALL include the client's name, target regions, and specific data values in the LLM explanation prompt so that the generated explanation is personalized to the individual client.

### Requirement 22: Wellness Language Compliance in Dashboard and Engine

**User Story:** As a system, I want all practitioner-facing text, LLM-generated explanations, and API responses to use wellness-appropriate language, so that HydraScan complies with Hydrawav3 brand guidelines.

#### Acceptance Criteria

1. THE Practitioner_Dashboard SHALL use the term "client" instead of "patient" in all user-facing text, labels, and navigation elements.
2. THE Practitioner_Dashboard SHALL use wellness terms ("supports," "recovery," "mobility," "wellness indicators") and avoid clinical terms ("treats," "diagnoses," "clinical findings," "medical results") in all displayed text.
3. THE LLM_Explanation_Service SHALL include explicit instructions in the LLM prompt to use only wellness/recovery language and to avoid medical/clinical terminology.
4. THE Practitioner_Dashboard SHALL refer to the device as "Hydrawav3" (lowercase w) in all user-facing text.

### Requirement 23: Recovery Intelligence Engine Edge Function API

**User Story:** As a frontend developer, I want well-defined Edge Function endpoints for the recovery intelligence engine, so that the Practitioner Dashboard can request recommendations, Recovery Maps, Recovery Scores, and explanations via standard HTTP calls.

#### Acceptance Criteria

1. THE Recovery_Intelligence_Engine SHALL expose a Supabase Edge Function endpoint that accepts a client_id and assessment_id, and returns a recommended SessionConfig, Recovery_Map, confidence score, and LLM explanation.
2. THE Recovery_Intelligence_Engine SHALL expose a Supabase Edge Function endpoint that accepts a client_id and returns the current Recovery_Score.
3. THE Recovery_Intelligence_Engine SHALL expose a Supabase Edge Function endpoint that accepts a client_id, body_region, and optional limit, and returns Recovery_Graph time-series data points.
4. WHEN an unauthenticated request is made to any Recovery_Intelligence_Engine endpoint, THE Edge Function SHALL return HTTP 401 with an error message.
5. WHEN a request references a client_id outside the authenticated user's clinic, THE Edge Function SHALL return HTTP 403 with an error message.

### Requirement 24: SessionConfig Serialization and Round-Trip Integrity

**User Story:** As a system, I want SessionConfig objects to serialize to JSON strings correctly for the MQTT API, and to deserialize back without data loss, so that the exact configuration sent to the device can be reconstructed from stored records.

#### Acceptance Criteria

1. THE Config_Builder SHALL serialize the SessionConfig to a JSON string for the MQTT payload, with all quotes properly escaped as required by the Hydrawav3 API.
2. THE Practitioner_Dashboard SHALL store the complete SessionConfig as a JSONB object in the `sessions` table `session_config` field.
3. FOR ALL valid SessionConfig objects, serializing to JSON then deserializing back SHALL produce an equivalent SessionConfig object (round-trip property).
4. THE Config_Builder SHALL produce a SessionConfig serializer and a SessionConfig deserializer that are used consistently across the engine and dashboard.
