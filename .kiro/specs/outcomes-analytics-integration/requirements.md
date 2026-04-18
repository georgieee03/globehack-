# Requirements Document — Outcomes, Analytics & Integration

## Introduction

This document defines the requirements for HydraScan's Post-Session Outcomes & Learning Loop (Phase 7), Analytics, Admin & Clinic Intelligence (Phase 8), and Final Integration, Polish & Demo Prep (Phase 9). This is Spec 4 of 4 for the HydraScan project, owned by Geo on the `geo-dev` branch.

The outcomes-analytics-integration spec closes the Know → Act → Learn flywheel by capturing post-session outcomes from both clients and practitioners, feeding those outcomes back into the Recovery Graph and Recovery Score, enabling the learning loop that makes each session smarter than the last. It then layers clinic-wide analytics, admin management, protocol effectiveness insights, and business model visibility on top of the outcome data. Finally, it handles end-to-end integration testing, UI polish, demo preparation, and judging rubric alignment across all four specs.

This spec depends on all three prior specs: backend-foundation (Spec 1) for auth, data layer, RLS, and MQTT proxy; ios-assessment-pipeline (Spec 2) for client capture, intake, and feedback UI; and recovery-intelligence-dashboard (Spec 3) for the intelligence engine, Recovery Score computation, Recovery Graph tracking, and practitioner dashboard.

## Glossary

- **Outcome**: A database record in the `outcomes` table capturing subjective and objective post-session data (stiffness before/after, soreness before/after, mobility improvement, session effectiveness, repeat intent, ROM after values, and free-text notes), linked to a specific session and recorded by either a client or a practitioner.
- **Learning_Loop**: The feedback mechanism where recorded Outcomes are linked to the exact SessionConfig that ran, enabling the Recovery_Intelligence_Engine to correlate what was done with what happened and improve future recommendations.
- **Recovery_Graph**: A time-series data structure in the `recovery_graph` table tracking ROM, asymmetry, stiffness, and Recovery Score per body region per client across visits.
- **Recovery_Score**: A single number (0–100) computed from recent session outcomes, daily check-in data, wearable context, and session adherence, representing the client's recovery trajectory.
- **Outcome_Trend_Analyzer**: A Supabase Edge Function that analyzes outcome patterns across sessions for a client, detecting improvement, plateau, or regression trends.
- **Plateau_Detection**: A sub-component of the Outcome_Trend_Analyzer that flags clients whose stiffness or Recovery Score has not meaningfully changed across three or more consecutive sessions.
- **Next_Visit_Signal**: A computed indicator derived from outcome trends that identifies when a client should return for their next session, based on recovery trajectory and adherence patterns.
- **Clinic_Analytics_Dashboard**: The admin-facing analytics view showing aggregate clinic metrics, device utilization, practitioner performance, client retention, and protocol effectiveness.
- **Protocol_Effectiveness**: A metric computed by correlating SessionConfig parameters with outcome scores across sessions, identifying which configuration patterns produce the best results for specific body regions and recovery goals.
- **Device_Utilization**: Analytics tracking sessions per device, uptime percentage, maintenance frequency, and room-level usage patterns.
- **Client_Retention**: A metric tracking client return rates, check-in adherence, streak data, and engagement patterns over time.
- **Admin_Panel**: The clinic administration interface for managing clinic settings, inviting or removing practitioners, managing devices, and viewing clinic-wide analytics.
- **Export_Service**: A Supabase Edge Function that generates CSV or PDF reports from clinic analytics data, scoped by RLS to the requesting admin's clinic.
- **ROI_Calculator**: A business model component that computes return on investment metrics: revenue per session, client lifetime value indicators, and payback period estimates.
- **Demo_Flow**: The end-to-end demonstration sequence covering the complete Know → Act → Learn cycle with real or simulated device interaction.
- **Simulation_Mode**: The operating mode where the MQTT proxy processes commands identically to live mode but skips the actual HTTP call to the Hydrawav3 API, returning responses with a `simulated: true` flag.
- **Wellness_Language_Audit**: A verification pass ensuring all user-facing text across the entire application complies with Hydrawav3 brand guidelines, using wellness-only terminology.
- **SessionConfig**: The TypeScript interface defining the full MQTT payload schema for a Hydrawav3 session, including MAC address, cycle choreography, modality sequences, thermal intensity, vibration ranges, and play command.
- **RLS (Row Level Security)**: PostgreSQL policies that restrict data access at the database level, ensuring users can only access data within their own clinic workspace.
- **Clinic_Workspace**: A tenant boundary in HydraScan where each clinic is an isolated workspace with its own users, devices, client profiles, and session data.

## Requirements

### Requirement 1: Practitioner Outcome Recording

**User Story:** As a practitioner, I want to record post-session outcomes including stiffness before/after, mobility improvement, session effectiveness, repeat intent, and free-text notes, so that the system can track what happened and improve future recommendations.

#### Acceptance Criteria

1. WHEN a session completes, THE Outcome_Trend_Analyzer SHALL accept a practitioner outcome submission containing: stiffness_before (0–10 integer), stiffness_after (0–10 integer), mobility_improved (boolean), session_effective (boolean), repeat_intent ("yes", "maybe", or "no"), and practitioner_notes (free text).
2. WHEN a practitioner submits an outcome, THE Outcome_Trend_Analyzer SHALL create a record in the `outcomes` table with `recorded_by` set to "practitioner" and `session_id` linking to the completed session.
3. THE Outcome_Trend_Analyzer SHALL validate that stiffness_before and stiffness_after values are integers between 0 and 10 inclusive.
4. THE Outcome_Trend_Analyzer SHALL validate that repeat_intent is one of the allowed values: "yes", "maybe", or "no".
5. WHEN a practitioner submits re-test ROM values alongside the outcome, THE Outcome_Trend_Analyzer SHALL store the ROM values in the outcome record `rom_after` JSONB field and compute `rom_delta` as the difference from the pre-session assessment ROM values.

### Requirement 2: Client Outcome Recording

**User Story:** As a client, I want to record how I feel after my Hydrawav3 session including stiffness, soreness, mobility improvement, session effectiveness, and repeat intent, so that my recovery data is tracked over time.

#### Acceptance Criteria

1. WHEN a session completes, THE Outcome_Trend_Analyzer SHALL accept a client outcome submission containing: stiffness_after (0–10 integer), soreness_after (0–10 integer), mobility_improved (boolean or null for "maybe"), session_effective (boolean or null for "maybe"), repeat_intent ("yes", "maybe", or "no"), and client_notes (free text).
2. WHEN a client submits an outcome, THE Outcome_Trend_Analyzer SHALL create a record in the `outcomes` table with `recorded_by` set to "client" and `session_id` linking to the completed session.
3. THE Outcome_Trend_Analyzer SHALL validate that stiffness_after and soreness_after values are integers between 0 and 10 inclusive.
4. IF a client submits an outcome for a session that already has a client-recorded outcome, THEN THE Outcome_Trend_Analyzer SHALL reject the duplicate submission and return a descriptive error.

### Requirement 3: Outcome-to-SessionConfig Linkage (Learning Loop)

**User Story:** As a system, I want every outcome record linked to the exact SessionConfig that ran during the session, so that the Recovery Intelligence Engine can correlate protocol parameters with results and improve future recommendations.

#### Acceptance Criteria

1. WHEN an outcome is recorded, THE Outcome_Trend_Analyzer SHALL verify that the referenced session record contains a non-null `session_config` JSONB field storing the exact SessionConfig that was sent to the device.
2. THE Learning_Loop SHALL enable querying outcomes by SessionConfig parameters, allowing the Recovery_Intelligence_Engine to find all outcomes for sessions that used a specific body region, recovery goal, or intensity range.
3. WHEN the Recovery_Intelligence_Engine generates a new recommendation, THE Learning_Loop SHALL provide the engine with prior session outcomes and their associated SessionConfig parameters for the same client, ordered by session completion date descending.
4. THE Learning_Loop SHALL store the `session_id` foreign key on every outcome record, ensuring a direct join path from outcome data to the session's `session_config`, `recommended_config`, and `practitioner_edits` fields.

### Requirement 4: Recovery Graph Update on Outcome Recording

**User Story:** As a system, I want the Recovery Graph updated with new data points whenever an outcome is recorded, so that the client's recovery trajectory reflects the latest session results.

#### Acceptance Criteria

1. WHEN an outcome with stiffness_before and stiffness_after values is recorded, THE Outcome_Trend_Analyzer SHALL insert a data point into the `recovery_graph` table with metric_type "stiffness", the stiffness_after value, source "session_outcome", and the session_id as source_id.
2. WHEN an outcome with rom_after values is recorded, THE Outcome_Trend_Analyzer SHALL insert a data point into the `recovery_graph` table for each ROM measurement with the appropriate body_region, metric_type (e.g., "rom_right_shoulder_flexion"), the ROM value, source "session_outcome", and the session_id as source_id.
3. WHEN an outcome with soreness_after is recorded, THE Outcome_Trend_Analyzer SHALL insert a data point into the `recovery_graph` table with metric_type "soreness", the soreness_after value, source "session_outcome", and the session_id as source_id.
4. THE Outcome_Trend_Analyzer SHALL set the body_region field on each recovery_graph data point based on the session's target region extracted from the SessionConfig.

### Requirement 5: Recovery Score Recalculation on New Outcomes

**User Story:** As a system, I want the Recovery Score recomputed whenever a new outcome is recorded, so that the client's score always reflects their latest recovery trajectory.

#### Acceptance Criteria

1. WHEN an outcome is recorded, THE Outcome_Trend_Analyzer SHALL trigger a Recovery Score recomputation for the client associated with the session.
2. THE Outcome_Trend_Analyzer SHALL compute the Recovery Score starting from a baseline of 50, adjusted by: outcome trend (up to ±20 points based on stiffness reduction ratio across recent outcomes), check-in trend (up to ±10 points based on average daily check-in feeling), wearable context (up to ±10 points based on HRV and sleep data), and session adherence (up to +10 points based on session frequency).
3. THE Outcome_Trend_Analyzer SHALL clamp the final Recovery Score to the range 0–100.
4. WHEN the Recovery Score is recomputed, THE Outcome_Trend_Analyzer SHALL insert the new score into the `recovery_graph` table with metric_type "recovery_score", body_region "general", source "session_outcome", and the session_id as source_id.

### Requirement 6: Outcome Trend Analysis

**User Story:** As a practitioner, I want the system to analyze outcome trends across sessions for each client, so that I can see whether a client is improving, plateauing, or regressing.

#### Acceptance Criteria

1. THE Outcome_Trend_Analyzer SHALL compute a trend classification for each client and body region as one of: "improving" (stiffness decreasing or ROM increasing across the last three sessions), "plateau" (stiffness or ROM change of 1 point or less across the last three sessions), or "regressing" (stiffness increasing or ROM decreasing across the last three sessions).
2. WHEN a client has fewer than three completed sessions, THE Outcome_Trend_Analyzer SHALL classify the trend as "insufficient_data" and skip trend analysis.
3. THE Outcome_Trend_Analyzer SHALL store the trend classification in a queryable format so that the Practitioner Dashboard can display trend indicators per client.
4. WHEN a plateau is detected for a client and body region, THE Outcome_Trend_Analyzer SHALL flag the client for practitioner review by setting a "needs_attention" indicator on the client profile.

### Requirement 7: Next-Visit Signal Generation

**User Story:** As a practitioner, I want the system to identify when a client should return for their next session based on outcome trends and recovery trajectory, so that I can proactively manage my client schedule.

#### Acceptance Criteria

1. WHEN an outcome is recorded, THE Outcome_Trend_Analyzer SHALL compute a next_visit_signal for the client containing: recommended_return_days (integer), urgency ("routine", "soon", or "priority"), and a plain-text rationale.
2. WHEN the client's Recovery Score is below 40 and the trend is "regressing", THE Outcome_Trend_Analyzer SHALL set the urgency to "priority" and recommended_return_days to 1–2.
3. WHEN the client's Recovery Score is between 40 and 70 and the trend is "plateau", THE Outcome_Trend_Analyzer SHALL set the urgency to "soon" and recommended_return_days to 3–5.
4. WHEN the client's Recovery Score is above 70 and the trend is "improving", THE Outcome_Trend_Analyzer SHALL set the urgency to "routine" and recommended_return_days to 7–14.
5. THE Outcome_Trend_Analyzer SHALL store the next_visit_signal so that the Practitioner Dashboard Client_List_View can display return recommendations.

### Requirement 8: Clinic-Wide Aggregate Analytics

**User Story:** As a clinic admin, I want to see aggregate metrics for my entire clinic including total sessions, average Recovery Score improvement, device utilization, and client retention, so that I can understand clinic performance and make operational decisions.

#### Acceptance Criteria

1. THE Clinic_Analytics_Dashboard SHALL display total sessions completed within a configurable date range (default: last 30 days), filtered by the admin's clinic_id via RLS.
2. THE Clinic_Analytics_Dashboard SHALL display average Recovery Score improvement computed as the mean difference between the first and most recent Recovery Score for all active clients in the clinic.
3. THE Clinic_Analytics_Dashboard SHALL display device utilization metrics: sessions per device, percentage of time each device is in "in_session" status versus "idle", and devices currently in "maintenance" or "offline" status.
4. THE Clinic_Analytics_Dashboard SHALL display client retention metrics: percentage of clients who returned for a second session within 30 days, average sessions per client, and total active clients (at least one session in the last 30 days).
5. THE Clinic_Analytics_Dashboard SHALL load all aggregate metrics within 2 seconds.

### Requirement 9: Per-Practitioner Performance Metrics

**User Story:** As a clinic admin, I want to see performance metrics for each practitioner in my clinic, so that I can identify coaching opportunities and recognize high performers.

#### Acceptance Criteria

1. THE Clinic_Analytics_Dashboard SHALL display per-practitioner metrics: total sessions conducted, average sessions per day, average outcome score (computed from stiffness reduction and session effectiveness), and client count.
2. THE Clinic_Analytics_Dashboard SHALL compute the average outcome score for each practitioner as the mean of `(stiffness_before - stiffness_after) / 10` across all outcomes for sessions conducted by that practitioner.
3. THE Clinic_Analytics_Dashboard SHALL respect RLS so that admins can only view practitioner metrics within their own clinic.
4. THE Clinic_Analytics_Dashboard SHALL anonymize practitioner comparison data by displaying practitioner initials or first names only, not full identifying information, in comparison views.

### Requirement 10: Protocol Effectiveness Analytics

**User Story:** As a clinic admin, I want to see which SessionConfig patterns produce the best outcomes, so that the clinic can identify effective protocols and share best practices across practitioners.

#### Acceptance Criteria

1. THE Clinic_Analytics_Dashboard SHALL display protocol effectiveness metrics by correlating SessionConfig parameters (recovery goal, target body region, thermal intensity range, vibration range, session duration) with average outcome scores.
2. THE Clinic_Analytics_Dashboard SHALL rank protocol configurations by average outcome score, showing the top five most effective configurations for the clinic.
3. THE Clinic_Analytics_Dashboard SHALL display protocol effectiveness broken down by body region, showing which configurations work best for each target area.
4. WHEN fewer than five sessions have used a specific protocol configuration, THE Clinic_Analytics_Dashboard SHALL mark that configuration as "limited data" and exclude the configuration from ranking.

### Requirement 11: Admin Panel — Clinic Settings and User Management

**User Story:** As a clinic admin, I want to manage clinic settings, invite or remove practitioners, and manage devices from an admin panel, so that I can operate my clinic efficiently within HydraScan.

#### Acceptance Criteria

1. THE Admin_Panel SHALL allow admins to update clinic settings: clinic name, address, and timezone.
2. THE Admin_Panel SHALL allow admins to invite new practitioners by email, creating a user record with role "practitioner" linked to the admin's clinic.
3. THE Admin_Panel SHALL allow admins to remove practitioners from the clinic by deactivating their user record.
4. THE Admin_Panel SHALL allow admins to manage devices: add new devices (MAC address, label, room assignment), edit device details, and set device status to "maintenance" or "offline".
5. THE Admin_Panel SHALL enforce RLS so that admins can only manage users and devices within their own clinic.
6. WHEN an admin attempts to remove the last admin user from a clinic, THE Admin_Panel SHALL reject the operation and display a message indicating that at least one admin must remain.

### Requirement 12: Export Capabilities — CSV and PDF Reports

**User Story:** As a clinic admin, I want to export clinic analytics data as CSV or PDF reports, so that I can share performance data with stakeholders and maintain records outside of HydraScan.

#### Acceptance Criteria

1. THE Export_Service SHALL generate CSV exports containing: session summary data (date, client identifier, practitioner, device, duration, outcome score), aggregate metrics (total sessions, average improvement, retention rate), and protocol effectiveness data.
2. THE Export_Service SHALL generate PDF reports containing: a clinic summary header (clinic name, date range, total sessions), aggregate metrics with visual charts, per-practitioner performance summary, and device utilization summary.
3. THE Export_Service SHALL scope all exported data to the requesting admin's clinic via RLS, ensuring no cross-clinic data leakage.
4. THE Export_Service SHALL anonymize client names in exports by using client initials or anonymized identifiers rather than full names.
5. WHEN an export is requested, THE Export_Service SHALL generate the file within 10 seconds for clinics with up to 1000 sessions in the date range.

### Requirement 13: Business Model Insights and ROI Visibility

**User Story:** As a clinic admin, I want to see business model insights including revenue per session, client lifetime value indicators, and ROI estimates, so that I can understand the financial impact of HydraScan on my clinic.

#### Acceptance Criteria

1. THE Clinic_Analytics_Dashboard SHALL display a configurable per-session revenue value (default: $15) that the admin can adjust to match their clinic's pricing.
2. THE ROI_Calculator SHALL compute and display: total estimated revenue (sessions × per-session value), average revenue per client (total revenue / unique clients), and estimated client lifetime value (average revenue per client × average retention months).
3. THE ROI_Calculator SHALL display a payback period estimate: "At current session volume, HydraScan pays for itself in X days" based on a configurable monthly subscription cost.
4. THE ROI_Calculator SHALL display a conversion metric: percentage of clients who returned for a second session after their first HydraScan-guided session.
5. THE Clinic_Analytics_Dashboard SHALL display all business model insights using wellness-appropriate language, avoiding clinical or medical terminology.

### Requirement 14: End-to-End Integration Testing

**User Story:** As a developer, I want a comprehensive end-to-end integration test that validates the complete Know → Act → Learn cycle across all four specs, so that the demo flow works reliably.

#### Acceptance Criteria

1. THE Demo_Flow SHALL execute the following sequence without manual intervention between steps: client sign-in, intake completion (body zones, signals, goal), QuickPose capture (or simulated assessment data), assessment upload, practitioner Recovery Map review, protocol recommendation display, device selection, session launch via MQTT proxy, session lifecycle control (pause/resume/stop), client outcome recording, practitioner outcome recording, Recovery Graph update, and Recovery Score recomputation.
2. WHEN running in Simulation_Mode, THE Demo_Flow SHALL complete the full sequence using simulated device responses with `simulated: true` flags displayed in the UI.
3. THE Demo_Flow SHALL verify that the Recovery Score changes after outcome recording, confirming the learning loop is functional.
4. THE Demo_Flow SHALL verify that the next recommendation for the same client reflects the recorded outcome data, confirming that the History_Scorer incorporates new outcomes.

### Requirement 15: Demo Script and Walkthrough Preparation

**User Story:** As a team member presenting at GlobeHack, I want a rehearsed demo script covering the complete Know → Act → Learn cycle in under 5 minutes, so that the presentation is polished and hits all judging criteria.

#### Acceptance Criteria

1. THE Demo_Flow SHALL be completable within a 3-minute live walkthrough covering: intake (15 seconds), assessment (15 seconds), Recovery Map review (20 seconds), protocol recommendation and launch (20 seconds), session lifecycle (15 seconds), outcome recording (20 seconds), Recovery Graph update (15 seconds), and analytics overview (20 seconds).
2. THE Demo_Flow SHALL include pre-seeded demo data for at least three client personas with 3–5 sessions each, showing visible Recovery Score trends and outcome history.
3. THE Demo_Flow SHALL display a simulation badge when operating without real Hydrawav3 hardware, clearly indicating simulated mode to judges.
4. THE Demo_Flow SHALL include prepared answers for anticipated judge questions covering: device integration approach, wellness language compliance, personalization mechanism, offline resilience, pricing model, and production path.

### Requirement 16: UI Polish — Consistent Styling and State Handling

**User Story:** As a user (client, practitioner, or admin), I want consistent styling, loading states, error handling, and empty states across the entire application, so that the experience feels polished and professional.

#### Acceptance Criteria

1. THE Outcome_Trend_Analyzer frontend components SHALL display loading indicators during all network requests (outcome submission, analytics data fetching, export generation).
2. IF an API request fails, THEN THE frontend SHALL display a descriptive error message with a retry option, without crashing or showing raw error data.
3. WHEN a dashboard view has no data (new clinic, no sessions yet), THE frontend SHALL display an informative empty state message with guidance on next steps (e.g., "No sessions recorded yet. Launch your first session from the practitioner dashboard.").
4. THE frontend SHALL use a consistent color scheme, typography, and spacing across all outcome recording, analytics, and admin screens.
5. THE frontend SHALL ensure all interactive elements (buttons, sliders, inputs) have accessible labels and meet WCAG 2.1 AA contrast requirements.

### Requirement 17: Performance Optimization

**User Story:** As a practitioner or admin, I want analytics dashboards and outcome recording to respond quickly, so that the system fits into a high-volume clinic workflow without delays.

#### Acceptance Criteria

1. WHEN a practitioner submits an outcome, THE Outcome_Trend_Analyzer SHALL process the submission (validate, store, update Recovery Graph, recompute Recovery Score) and return a success response within 3 seconds.
2. THE Clinic_Analytics_Dashboard SHALL render aggregate metrics within 2 seconds of the admin navigating to the analytics view.
3. THE Clinic_Analytics_Dashboard SHALL use database indexes on `recovery_graph(client_id, body_region, recorded_at)` and `outcomes(session_id, recorded_by)` to ensure query performance.
4. WHEN the Practitioner Dashboard subscribes to real-time session status updates via Supabase Realtime, THE subscription SHALL deliver status changes within 2 seconds of the database update.

### Requirement 18: Simulation Mode Verification

**User Story:** As a developer preparing for the demo, I want the full demo flow to work without real Hydrawav3 hardware, so that the presentation is reliable regardless of device availability.

#### Acceptance Criteria

1. WHILE the system is operating in Simulation_Mode, THE Demo_Flow SHALL complete the full Know → Act → Learn cycle identically to live mode, with the MQTT proxy returning simulated success responses.
2. WHILE in Simulation_Mode, THE frontend SHALL display a visible simulation badge on all screens that would normally interact with real hardware (session launch, session lifecycle controls, device status).
3. WHILE in Simulation_Mode, THE MQTT proxy SHALL log all commands to the `mqtt_command_log` table with `simulated: true`, enabling audit of the simulated demo flow.
4. WHEN switching from Simulation_Mode to live mode, THE system SHALL require only a change to the `HYDRAWAV_API_BASE_URL` environment variable with no code changes.

### Requirement 19: Wellness Language Audit

**User Story:** As a system, I want all user-facing text across the entire application verified against Hydrawav3 brand guidelines, so that HydraScan uses wellness-only terminology and avoids medical or clinical language.

#### Acceptance Criteria

1. THE Wellness_Language_Audit SHALL verify that no user-facing text contains forbidden terms: "diagnos", "treat", "cure", "medical device", "clinical", "prescription", "medication", "drug", "heal", "therapy", or "patient".
2. THE Wellness_Language_Audit SHALL verify that all outcome-related labels use wellness terms: "recovery signals" instead of "symptoms", "movement insights" instead of "clinical findings", "session guidance" instead of "treatment prescription".
3. THE Wellness_Language_Audit SHALL verify that the device is referred to as "Hydrawav3" (lowercase w) in all user-facing text.
4. THE Wellness_Language_Audit SHALL verify that all LLM-generated explanation text passes the `validateWellnessLanguage` function from the Shared_Types_Package before being displayed to users.

### Requirement 20: Judging Rubric Alignment

**User Story:** As a hackathon team, I want the final integrated product to demonstrably cover all judging criteria and bonus categories, so that the presentation maximizes the scoring potential.

#### Acceptance Criteria

1. THE Demo_Flow SHALL demonstrate Practitioner Impact (25 points) by showing: Recovery Map loading within 60 seconds, protocol recommendation with rationale, and outcome visibility across sessions.
2. THE Demo_Flow SHALL demonstrate Technical Feasibility (20 points) by showing: on-device QuickPose capture, Supabase backend with RLS, real MQTT API integration with typed SessionConfig, and safe envelope enforcement.
3. THE Demo_Flow SHALL demonstrate Platform Integration (20 points) by showing: JWT authentication with the Hydrawav3 API, MQTT publish with correct payload format, device targeting by MAC address, and session lifecycle commands.
4. THE Demo_Flow SHALL demonstrate Path to Product (20 points) by showing: multi-tenant auth, RLS isolation, typed schemas, safe envelope enforcement, and the learning loop improving recommendations over time.
5. THE Demo_Flow SHALL demonstrate User Experience (15 points) by showing: sub-60-second intake, guided capture, clean practitioner console, Recovery Score visualization, and consistent UI polish.
6. THE Demo_Flow SHALL demonstrate Loop Coverage bonus (+10 points) by showing all three flywheel stages: Know (assessment), Act (session launch), and Learn (outcomes feeding back into recommendations).
7. THE Demo_Flow SHALL demonstrate Live Data Demo bonus (+5 points) by showing a working session launch via the MQTT API with real or clearly badged simulated device interaction.
8. THE Demo_Flow SHALL demonstrate Business Model bonus (+3 points) by showing per-session pricing, ROI calculator, and client retention metrics in the analytics dashboard.

### Requirement 21: Cross-Clinic Data Isolation in Analytics

**User Story:** As a system, I want all analytics queries and exports to respect Row Level Security, so that no clinic can see another clinic's data in any analytics view or exported report.

#### Acceptance Criteria

1. THE Clinic_Analytics_Dashboard SHALL filter all analytics queries by the authenticated admin's clinic_id, enforced at the database level via RLS policies.
2. THE Export_Service SHALL include only data from the requesting admin's clinic in all CSV and PDF exports, enforced at the database level via RLS policies.
3. WHEN a practitioner views their own performance metrics, THE Clinic_Analytics_Dashboard SHALL show only metrics from sessions within the practitioner's clinic.
4. THE Clinic_Analytics_Dashboard SHALL verify clinic isolation by confirming that an admin in Clinic A cannot view aggregate metrics, practitioner performance, device utilization, or client retention data belonging to Clinic B.
