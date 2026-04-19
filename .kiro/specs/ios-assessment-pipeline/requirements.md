# Requirements Document — iOS Assessment Pipeline

## Introduction

This document defines the requirements for HydraScan's iOS assessment pipeline, covering the QuickPose Assessment Pipeline (Phase 3) and the Client iOS App for intake, capture, and continuity (Phase 6). This is Spec 2 of 4 for the HydraScan project, owned by Kaush on the `kaush-dev` branch.

The iOS assessment pipeline is the client-facing half of HydraScan. It handles authentication, rapid intake (body zone selection, recovery signals, goals), guided movement capture using QuickPose on-device pose estimation, optional rPPG vitals capture, post-session feedback, daily check-ins, Recovery Score display, and continuity/gamification features. All pose computation runs on-device via QuickPose SDK. The pipeline depends on the backend-foundation spec (Spec 1) for auth, data layer, and API endpoints.

## Glossary

- **iOS_App**: The HydraScan SwiftUI client application running on iPhone, providing intake, capture, feedback, and continuity features.
- **QuickPose_Pipeline**: The on-device pose estimation pipeline using QuickPose SDK modules (QuickPoseCore, QuickPoseMP, QuickPoseCamera, QuickPoseSwiftUI) to capture landmarks, compute joint angles, ROM, asymmetry, and movement quality.
- **QuickPose_SDK**: The QuickPose iOS SDK providing 33-point full-body skeleton detection built on MediaPipe, installed via Swift Package Manager. Modules include QuickPoseCore, QuickPoseMP-full, QuickPoseCamera, and QuickPoseSwiftUI.
- **QuickPoseBasicView**: A SwiftUI component from QuickPoseSwiftUI that integrates camera capture with real-time pose overlay in a single view.
- **Landmark**: One of 33 body keypoints detected by QuickPose, each with x, y, z coordinates and a visibility confidence score.
- **Joint_Angle**: An angle in degrees computed from three Landmark positions using vector trigonometry (dot product of vectors from the vertex to each adjacent joint).
- **ROM (Range of Motion)**: The maximum angular displacement measured at a joint during a guided movement, expressed in degrees.
- **Asymmetry_Score**: A percentage difference between left and right side ROM or joint angle measurements, computed as `abs(right - left) / average(right, left) * 100`.
- **Movement_Quality_Score**: A normalized score (0.0 to 1.0) comparing a client's movement pattern against reference data from the UI-PRMD dataset.
- **QuickPoseResult**: A structured output object containing landmarks (33 points), joint angles, ROM values, asymmetry scores, movement quality scores, and optional gait metrics.
- **Capture_Step**: One of seven guided movements in the default assessment sequence (standing front, standing side, shoulder flexion, squat, hip hinge, single-leg balance right, single-leg balance left).
- **Assessment**: A database record containing the full QuickPoseResult data, ROM values, asymmetry scores, movement quality scores, vitals, body zones, recovery goal, and computed Recovery Map for a single capture session.
- **Intake_Flow**: The rapid client onboarding sequence consisting of body zone selection, recovery signal entry, goal selection, and activity context, designed to complete in under 60 seconds.
- **Body_Zone**: A tappable region on the body map silhouette corresponding to a BodyRegion value (e.g., right_shoulder, lower_back, left_knee, neck).
- **Recovery_Signal**: A per-region signal object containing signal type (stiffness, soreness, tightness, restriction, guarding), severity (1–10), and activity trigger.
- **Recovery_Goal**: One of five goal types: mobility, warm_up, recovery, relaxation, or performance_prep.
- **Body_Map_Canvas**: An interactive 2D body silhouette view with tappable overlay zones that highlight when selected.
- **rPPG (Remote Photoplethysmography)**: A technique for estimating heart rate from subtle skin color changes in face video, processed entirely on-device.
- **Consent_Flow**: An explicit user consent screen that must be presented and accepted before the iOS_App activates the front-facing camera for rPPG face video capture.
- **Recovery_Score**: A single number (0–100) computed from recent session outcomes, daily check-in data, wearable context, and session adherence, representing the client's recovery trajectory.
- **Daily_Check_In**: A between-visit feedback entry where the client reports overall feeling (1–5), target region status, and recent activity.
- **Continuity_Features**: Between-visit engagement features including recovery streaks, progress visualization, and gamification elements (XP, levels, visual before/after).
- **Wearable_Sync**: Optional i/Users/sri/Documents/globehack-/.kiro/specs/backend-foundationntegration with Apple Watch data (HRV, strain, sleep score) via HealthKit.
- **Supabase_Client**: The Supabase Swift client library used for authentication, database operations, and real-time subscriptions from the iOS_App.

## Requirements

### Requirement 1: QuickPose SDK Integration and Camera Setup

**User Story:** As an iOS developer, I want the QuickPose SDK properly integrated with camera permissions and real-time pose overlay, so that the app can capture and visualize body landmarks on-device.

#### Acceptance Criteria

1. THE iOS_App SHALL import QuickPoseCore, QuickPoseMP-full, QuickPoseCamera, and QuickPoseSwiftUI modules via Swift Package Manager.
2. WHEN the client opens the capture screen, THE iOS_App SHALL request camera permission and display the rear-facing camera feed with a real-time skeleton overlay using QuickPoseBasicView.
3. THE QuickPose_Pipeline SHALL detect 33 body landmarks per frame, each with x, y, z coordinates and a visibility confidence score.
4. THE QuickPose_Pipeline SHALL perform all pose estimation inference on-device with no cloud dependency.
5. IF camera permission is denied, THEN THE iOS_App SHALL display a message explaining that camera access is required for movement capture and provide a button to open device Settings.

### Requirement 2: Guided Assessment Capture Flow

**User Story:** As a client, I want to be guided through a sequence of movements with clear instructions and visual feedback, so that the app can capture my movement data accurately and quickly.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL guide the client through a default sequence of seven Capture_Steps: standing front view (5s), standing side view (5s), shoulder flexion (10s), squat (10s), hip hinge (8s), single-leg balance right (10s), and single-leg balance left (10s).
2. WHEN a Capture_Step begins, THE iOS_App SHALL display the step title, a plain-language instruction for the movement, and a progress indicator showing the current step out of seven.
3. WHEN a Capture_Step is active, THE iOS_App SHALL display a countdown timer showing remaining seconds for that step.
4. WHEN a Capture_Step completes, THE QuickPose_Pipeline SHALL automatically advance to the next step and update the QuickPose features for the new movement.
5. THE QuickPose_Pipeline SHALL complete the full seven-step assessment sequence in under 60 seconds of total capture time.
6. WHEN all seven Capture_Steps are complete, THE iOS_App SHALL compile the captured data into a single Assessment and navigate to the results summary.

### Requirement 3: Joint Angle Computation from Landmarks

**User Story:** As a system, I want joint angles computed from the 33 detected landmarks using vector trigonometry, so that ROM and asymmetry can be derived from raw pose data.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL compute Joint_Angle values in degrees using the dot product formula applied to vectors from the vertex landmark to each adjacent landmark.
2. THE QuickPose_Pipeline SHALL compute joint angles for the following joints: right shoulder, left shoulder, right hip, left hip, right knee, left knee, right ankle, left ankle, and spine (thoracic and lumbar segments).
3. WHEN computing a Joint_Angle, THE QuickPose_Pipeline SHALL clamp the cosine value to the range [-1, 1] before applying the arccosine function to prevent NaN results from floating-point imprecision.
4. THE QuickPose_Pipeline SHALL aggregate landmark samples over the full duration of each Capture_Step and compute the maximum angle (for flexion movements) or minimum angle (for extension movements) as the representative value.

### Requirement 4: Range of Motion Measurement

**User Story:** As a practitioner reviewing assessment data, I want ROM values measured for key joints, so that I can see objective mobility data for each client.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL measure ROM for the following joints: shoulder flexion (left and right), hip flexion (left and right), knee flexion (left and right), ankle dorsiflexion (left and right), and spinal flexion.
2. WHEN measuring shoulder flexion ROM, THE QuickPose_Pipeline SHALL compute the angle between the upper arm vector (shoulder to elbow) and the torso vector (shoulder to hip).
3. WHEN measuring knee flexion ROM, THE QuickPose_Pipeline SHALL compute the angle between the thigh vector (hip to knee) and the shin vector (knee to ankle).
4. WHEN measuring hip flexion ROM, THE QuickPose_Pipeline SHALL compute the angle between the torso vector (shoulder to hip) and the thigh vector (hip to knee).
5. THE QuickPose_Pipeline SHALL output ROM values in degrees as part of the QuickPoseResult `romValues` dictionary, keyed by joint name and side (e.g., "right_shoulder_flexion", "left_knee_flexion").

### Requirement 5: Asymmetry Detection

**User Story:** As a practitioner, I want to see bilateral asymmetry scores comparing left and right sides, so that I can identify imbalances that inform session planning.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL compute Asymmetry_Score values for all bilateral joint pairs: shoulder flexion, hip flexion, and knee flexion.
2. THE QuickPose_Pipeline SHALL compute each Asymmetry_Score as `abs(right_value - left_value) / ((right_value + left_value) / 2) * 100`, expressed as a percentage.
3. WHEN both left and right ROM values for a joint pair are zero, THE QuickPose_Pipeline SHALL set the Asymmetry_Score for that pair to zero rather than producing a division-by-zero error.
4. THE QuickPose_Pipeline SHALL include Asymmetry_Score values in the QuickPoseResult `asymmetryScores` dictionary, keyed by joint name (e.g., "shoulder_flexion", "knee_flexion").

### Requirement 6: Movement Quality Scoring

**User Story:** As a practitioner, I want movement quality scores that compare the client's form against reference data, so that I can assess functional movement patterns objectively.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL compute Movement_Quality_Score values for squat and hip hinge movements by comparing the client's joint angle trajectories against reference patterns from the UI-PRMD dataset.
2. THE QuickPose_Pipeline SHALL normalize Movement_Quality_Score values to a range of 0.0 (poor form) to 1.0 (reference-quality form).
3. WHEN computing movement quality for the squat Capture_Step, THE QuickPose_Pipeline SHALL evaluate knee tracking (valgus/varus), trunk lean angle, squat depth (hip-to-knee angle), and ankle mobility.
4. WHEN computing movement quality for the hip hinge Capture_Step, THE QuickPose_Pipeline SHALL evaluate hamstring flexibility (hip angle), lumbar flexion (spine angle), and knee bend control.
5. THE QuickPose_Pipeline SHALL include Movement_Quality_Score values in the QuickPoseResult `movementQuality` dictionary, keyed by movement name (e.g., "squat", "hip_hinge").

### Requirement 7: Structured QuickPoseResult Output

**User Story:** As a system, I want all pose computation results packaged into a single structured QuickPoseResult object, so that downstream consumers (assessment upload, Recovery Map) receive a consistent data format.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL produce a QuickPoseResult containing: landmarks (array of 33 points with x, y, z, visibility), jointAngles (dictionary of joint name to angle in degrees), romValues (dictionary of joint name to ROM in degrees), asymmetryScores (dictionary of joint pair to percentage), movementQuality (dictionary of movement name to score 0.0–1.0), and capturedAt (ISO 8601 timestamp).
2. WHEN all seven Capture_Steps are complete, THE QuickPose_Pipeline SHALL merge per-step results into a single consolidated QuickPoseResult for the full assessment.
3. THE QuickPoseResult SHALL be serializable to JSON for upload to the Supabase `assessments` table `quickpose_data` column.
4. FOR ALL valid QuickPoseResult objects, serializing to JSON then deserializing back SHALL produce an equivalent QuickPoseResult object (round-trip property).

### Requirement 8: Rep Counting During Guided Movements

**User Story:** As a client performing guided movements, I want the app to count my repetitions in real time, so that I complete the correct number of reps for each exercise and the system captures per-rep data.

#### Acceptance Criteria

1. WHEN a Capture_Step involves a repetitive movement (squat, hip hinge), THE QuickPose_Pipeline SHALL use QuickPose rep counting to detect and count completed repetitions in real time.
2. THE iOS_App SHALL display the current rep count on screen during the active Capture_Step.
3. THE QuickPose_Pipeline SHALL record per-rep joint angle data (peak and trough values) for each counted repetition.
4. WHEN the target rep count for a Capture_Step is reached, THE iOS_App SHALL provide visual and haptic feedback indicating the step is complete.

### Requirement 9: Recovery Map Generation from Assessment Data

**User Story:** As a practitioner, I want a Recovery Map generated from the client's assessment data, intake signals, wearable context, and session history, so that I can see a 60-second summary of the client's recovery state.

#### Acceptance Criteria

1. WHEN an Assessment is completed and uploaded, THE iOS_App SHALL generate a Recovery Map combining the QuickPoseResult data with the client's intake signals, wearable context, and prior session history.
2. THE Recovery Map SHALL contain: highlighted regions (each with severity, signal type, ROM delta compared to last assessment, asymmetry flag, and optional compensation hint), wearable context (HRV, strain, sleep score, last sync), prior sessions (date, config summary, outcome rating), a suggested Recovery_Goal, and a generation timestamp.
3. THE iOS_App SHALL store the Recovery Map in the Assessment record `recovery_map` JSONB field.
4. THE Recovery Map SHALL be viewable by the practitioner within 60 seconds of the client completing the assessment.

### Requirement 10: Assessment Upload to Backend

**User Story:** As a client, I want my assessment data uploaded to the backend after capture completes, so that my practitioner can review it and the system can generate recommendations.

#### Acceptance Criteria

1. WHEN the guided capture flow completes, THE iOS_App SHALL create an Assessment record in the Supabase `assessments` table containing the QuickPoseResult data, ROM values, asymmetry scores, movement quality scores, body zones, recovery goal, and subjective baseline.
2. THE iOS_App SHALL set the `assessment_type` field to "intake" for first-visit assessments and "pre_session" for subsequent assessments.
3. IF the upload to Supabase fails due to a network error, THEN THE iOS_App SHALL cache the Assessment locally and retry the upload when connectivity is restored.
4. WHEN the Assessment is uploaded successfully, THE iOS_App SHALL display a confirmation and navigate to the results summary screen.

### Requirement 11: Authentication with Sign in with Apple and Email Magic Link

**User Story:** As a client, I want to sign in using Apple Sign-In or an email magic link, so that I can securely access my recovery data without managing passwords.

#### Acceptance Criteria

1. THE iOS_App SHALL present a login screen with two authentication options: Sign in with Apple and email magic link.
2. WHEN the client taps Sign in with Apple, THE iOS_App SHALL initiate the Apple Sign-In flow using Supabase Auth and create or retrieve the user session.
3. WHEN the client enters an email address and taps the magic link button, THE iOS_App SHALL trigger a Supabase Auth magic link email and display a message instructing the client to check their email.
4. WHEN the client opens the magic link from their email, THE iOS_App SHALL complete the authentication flow and navigate to the main client screen.
5. WHEN authentication succeeds, THE Supabase_Client SHALL store the JWT session token for subsequent authenticated API requests.
6. IF authentication fails, THEN THE iOS_App SHALL display a descriptive error message and allow the client to retry.

### Requirement 12: Rapid Intake Flow

**User Story:** As a client, I want to complete a rapid intake in under 60 seconds by selecting body zones, rating discomfort, choosing goals, and noting activity context, so that my practitioner has the information needed to personalize my session.

#### Acceptance Criteria

1. THE Intake_Flow SHALL present four sequential steps: body zone selection, per-region recovery signal entry, recovery goal selection, and activity context input.
2. THE Intake_Flow SHALL complete in under 60 seconds of total client interaction time.
3. WHEN the client completes the Intake_Flow, THE iOS_App SHALL save the intake data to the `client_profiles` table, updating `primary_regions`, `recovery_signals`, `goals`, and `activity_context` fields.
4. WHEN the client completes the Intake_Flow, THE iOS_App SHALL navigate to the QuickPose guided capture screen.

### Requirement 13: Body Zone Selection via Interactive Body Map

**User Story:** As a client, I want to tap on a body silhouette to highlight the regions where I need support, so that I can quickly communicate my areas of concern.

#### Acceptance Criteria

1. THE Body_Map_Canvas SHALL display a 2D body silhouette image with tappable overlay zones corresponding to BodyRegion values: right_shoulder, left_shoulder, lower_back, upper_back, right_hip, left_hip, right_knee, left_knee, neck, right_calf, left_calf, right_arm, left_arm, right_foot, and left_foot.
2. WHEN the client taps a Body_Zone, THE Body_Map_Canvas SHALL toggle the selection state and visually highlight the selected zone with a colored overlay.
3. WHEN the client taps a previously selected Body_Zone, THE Body_Map_Canvas SHALL deselect the zone and remove the highlight.
4. THE Body_Map_Canvas SHALL allow the client to select multiple Body_Zones simultaneously.
5. THE Body_Map_Canvas SHALL display the count of currently selected zones.

### Requirement 14: Recovery Signal Entry Per Region

**User Story:** As a client, I want to rate the type and severity of discomfort for each selected body zone, so that the system captures detailed recovery signals.

#### Acceptance Criteria

1. WHEN the client has selected one or more Body_Zones, THE iOS_App SHALL present a Recovery_Signal entry form for each selected region.
2. THE Recovery_Signal entry form SHALL allow the client to select a signal type from: stiffness, soreness, tightness, restriction, and guarding.
3. THE Recovery_Signal entry form SHALL allow the client to set a severity value on a 1–10 scale using a slider or stepper control.
4. THE Recovery_Signal entry form SHALL allow the client to select an activity trigger from: morning, after_running, after_lifting, post_travel, post_training, evening, and general.
5. THE iOS_App SHALL store each Recovery_Signal as a structured object with region, type, severity, and trigger fields.

### Requirement 15: Recovery Goal Selection

**User Story:** As a client, I want to select my recovery goal for today's session, so that the system can tailor the assessment and session recommendation.

#### Acceptance Criteria

1. THE iOS_App SHALL present five Recovery_Goal options: mobility, warm-up, recovery, relaxation, and performance prep.
2. THE iOS_App SHALL display each Recovery_Goal with a descriptive label using wellness-appropriate language.
3. WHEN the client selects a Recovery_Goal, THE iOS_App SHALL store the selection in the client profile `goals` field.
4. THE iOS_App SHALL allow the client to select exactly one primary Recovery_Goal per intake session.

### Requirement 16: Activity Context Input

**User Story:** As a client, I want to note what I have been doing recently, so that the practitioner has context about my current physical state.

#### Acceptance Criteria

1. THE iOS_App SHALL present an activity context input allowing the client to describe recent activity via a text field or predefined option selection.
2. THE iOS_App SHALL store the activity context value in the `client_profiles` table `activity_context` field.

### Requirement 17: Optional Wearable Data Sync

**User Story:** As a client who uses an Apple Watch, I want to optionally sync my HRV, strain, and sleep data, so that the system has additional recovery context.

#### Acceptance Criteria

1. THE iOS_App SHALL present an optional wearable sync step during intake that requests HealthKit authorization for heart rate variability, activity energy, and sleep analysis data.
2. WHEN the client authorizes HealthKit access, THE iOS_App SHALL read the most recent HRV value, strain estimate, and sleep score from HealthKit.
3. WHEN wearable data is synced, THE iOS_App SHALL update the `client_profiles` table fields: `wearable_hrv`, `wearable_strain`, `wearable_sleep_score`, and `wearable_last_sync`.
4. IF the client declines HealthKit authorization, THEN THE iOS_App SHALL proceed with the intake flow without wearable data and leave the wearable fields as null.

### Requirement 18: Consent Flow for Face Video (rPPG)

**User Story:** As a client, I want to explicitly consent before the app uses my front-facing camera for face video, so that my privacy is respected and I understand how the data is used.

#### Acceptance Criteria

1. WHEN the iOS_App is about to activate the front-facing camera for rPPG capture, THE Consent_Flow SHALL present a dedicated consent screen explaining that face video will be used to estimate heart rate.
2. THE Consent_Flow SHALL clearly state that face video is processed entirely on-device and is not stored as raw video or transmitted to any server.
3. THE Consent_Flow SHALL require the client to tap an explicit "I Consent" button before the front-facing camera activates.
4. IF the client declines consent, THEN THE iOS_App SHALL skip the rPPG capture step and proceed to the next step in the flow without face video data.
5. THE iOS_App SHALL store the consent decision (granted or declined) with a timestamp for audit purposes.

### Requirement 19: Optional rPPG Vitals Capture

**User Story:** As a client who has consented to face video, I want the app to estimate my heart rate from the front-facing camera, so that the system has additional vitals context for my recovery profile.

#### Acceptance Criteria

1. WHEN the client has granted consent via the Consent_Flow, THE iOS_App SHALL activate the front-facing camera and capture 15–30 seconds of face video for rPPG analysis.
2. THE iOS_App SHALL process the face video entirely on-device to extract a heart rate estimate using skin color change analysis (rPPG).
3. THE iOS_App SHALL display the estimated heart rate value to the client after processing completes.
4. THE iOS_App SHALL store the heart rate estimate in the Assessment record `heart_rate` field.
5. THE iOS_App SHALL discard the raw face video frames after processing and retain only the computed heart rate value.
6. IF the rPPG analysis produces a low-confidence result (due to poor lighting or excessive motion), THEN THE iOS_App SHALL display a message indicating the reading could not be completed and allow the client to retry or skip.

### Requirement 20: Post-Session Feedback Collection

**User Story:** As a client, I want to provide feedback after my Hydrawav3 session, so that the system can track my outcomes and improve future recommendations.

#### Acceptance Criteria

1. WHEN a Hydrawav3 session completes, THE iOS_App SHALL present a post-session feedback screen.
2. THE iOS_App SHALL collect stiffness-after rating (0–10 scale), soreness-after rating (0–10 scale), mobility improvement (yes/no/maybe), session effectiveness (yes/no/maybe), repeat intent (yes/maybe/no-try-different), and optional free-text notes.
3. WHEN the client submits feedback, THE iOS_App SHALL create an Outcome record in the Supabase `outcomes` table with `recorded_by` set to "client".
4. WHEN the client submits feedback, THE iOS_App SHALL navigate to the Recovery Score display screen.

### Requirement 21: Recovery Score Display

**User Story:** As a client, I want to see my Recovery Score on my home screen with visual progress, so that I can track my recovery trajectory between visits.

#### Acceptance Criteria

1. THE iOS_App SHALL display the client's current Recovery_Score (0–100) prominently on the client home screen.
2. THE iOS_App SHALL display a visual progress indicator (circular gauge, trend line, or equivalent) showing the Recovery_Score trajectory over the last 30 days.
3. WHEN the Recovery_Score changes (after a session outcome or daily check-in), THE iOS_App SHALL update the displayed score and progress visualization.
4. THE iOS_App SHALL fetch the Recovery_Score from the backend `recovery_graph` table, filtered by the client's ID and the "recovery_score" metric type.

### Requirement 22: Daily Check-In Flow

**User Story:** As a client between visits, I want to complete a quick daily check-in reporting how I feel, so that the system tracks my recovery between sessions.

#### Acceptance Criteria

1. THE iOS_App SHALL present a daily check-in screen accessible from the client home screen.
2. THE Daily_Check_In SHALL collect: overall feeling (1–5 emoji scale), target region status for regions from the last session, and a free-text activity description.
3. WHEN the client submits a Daily_Check_In, THE iOS_App SHALL create a record in the Supabase `daily_checkins` table with `checkin_type` set to "daily".
4. WHEN the client submits a Daily_Check_In, THE iOS_App SHALL trigger a Recovery_Score recalculation by the backend.

### Requirement 23: Continuity and Gamification Features

**User Story:** As a client, I want to see recovery streaks, XP, levels, and visual before/after comparisons, so that I stay motivated and engaged with my recovery journey.

#### Acceptance Criteria

1. THE iOS_App SHALL track and display a recovery streak counter showing the number of consecutive days the client has completed a Daily_Check_In or attended a session.
2. THE iOS_App SHALL award experience points (XP) for completing sessions, submitting check-ins, and maintaining streaks.
3. THE iOS_App SHALL display the client's current level derived from accumulated XP, with level thresholds visible to the client.
4. THE iOS_App SHALL provide a visual before/after comparison showing ROM values and asymmetry scores from the first assessment versus the most recent assessment.
5. WHEN the client's streak is broken (no check-in or session for a calendar day), THE iOS_App SHALL reset the streak counter to zero and display an encouraging message to restart.

### Requirement 24: Client Home Screen and Navigation Structure

**User Story:** As a client, I want a clear home screen with tab-based navigation, so that I can easily access intake, capture, check-ins, recovery score, and profile features.

#### Acceptance Criteria

1. THE iOS_App SHALL present a tab-based navigation structure with tabs for: Home (Recovery Score and quick actions), Capture (intake and QuickPose flow), Check-In (daily check-in), and Profile (settings and history).
2. THE iOS_App SHALL display the client's name, current Recovery_Score, streak count, and XP level on the Home tab.
3. WHEN the client is not authenticated, THE iOS_App SHALL display the login screen and prevent access to any other tab.
4. WHEN the client has an active session in progress, THE iOS_App SHALL display a persistent banner on the Home tab showing session status.

### Requirement 25: Wellness Language Compliance

**User Story:** As a system, I want all client-facing text in the iOS app to use wellness-appropriate language, so that HydraScan complies with Hydrawav3 brand guidelines.

#### Acceptance Criteria

1. THE iOS_App SHALL use the term "client" instead of "patient" in all user-facing text, labels, and navigation elements.
2. THE iOS_App SHALL use wellness terms ("supports," "recovery," "mobility," "wellness indicators") and avoid clinical terms ("treats," "diagnoses," "clinical findings," "medical results") in all user-facing text.
3. THE iOS_App SHALL use "recovery signals" instead of "symptoms" and "movement insights" instead of "clinical findings" in all assessment-related screens.
4. THE iOS_App SHALL refer to the device as "Hydrawav3" (lowercase w) in all user-facing text.

### Requirement 26: Offline Resilience for Pose Computation

**User Story:** As a client in a clinic with unreliable Wi-Fi, I want the movement capture and pose computation to work without an internet connection, so that the assessment is not interrupted by connectivity issues.

#### Acceptance Criteria

1. THE QuickPose_Pipeline SHALL perform all pose estimation, joint angle computation, ROM measurement, asymmetry detection, and movement quality scoring without requiring a network connection.
2. WHILE the device has no network connectivity, THE iOS_App SHALL allow the client to complete the full guided capture flow and view results locally.
3. WHEN network connectivity is restored after an offline capture, THE iOS_App SHALL upload the cached Assessment to the backend.
