# Implementation Plan: iOS Assessment Pipeline

## Overview

This plan implements the HydraScan iOS client application and on-device QuickPose assessment pipeline. The app is a SwiftUI application using MVVM architecture that handles authentication, rapid intake, guided movement capture with real-time pose estimation, joint angle computation, ROM measurement, asymmetry detection, movement quality scoring, optional rPPG vitals capture, post-session feedback, daily check-ins, Recovery Score display, and continuity/gamification features. All pose computation runs on-device via the QuickPose SDK. The app communicates with the Supabase backend (from backend-foundation spec) for auth, data persistence, and real-time subscriptions.

## Tasks

- [ ] 1. Set up iOS project structure, dependencies, and core models
  - [ ] 1.1 Create Xcode project scaffold and directory structure
    - Create the `ios/HydraScan/` directory structure with `App/`, `Models/`, `ViewModels/`, `Views/`, `Services/`, `Computation/`, and `Utils/` folders
    - Create `HydraScanApp.swift` as the app entry point with environment object setup
    - Create `ContentView.swift` as the root view with auth gate and tab bar navigation
    - Add Swift Package Manager dependencies: QuickPoseCore, QuickPoseMP-full, QuickPoseCamera, QuickPoseSwiftUI, supabase-swift
    - _Requirements: 1.1, 1.2, 24.1_

  - [ ] 1.2 Define core enum types and shared constants
    - Create `Models/User.swift` with `UserRole` enum (client, practitioner, admin)
    - Create `Utils/Constants.swift` with app-wide constants (Supabase URL, capture step durations, level thresholds, XP rewards)
    - Create `Utils/WellnessLanguage.swift` with a string mapping utility that enforces wellness-appropriate terminology ("client" not "patient", "recovery signals" not "symptoms", "movement insights" not "clinical findings", "Hydrawav3" lowercase w)
    - Create `Utils/Extensions.swift` with common Swift extensions (Date formatting, SIMD3 helpers)
    - _Requirements: 25.1, 25.2, 25.3, 25.4_

  - [ ] 1.3 Define data model types for client profile and intake
    - Create `Models/ClientProfile.swift` with `BodyRegion` enum (15 regions, CaseIterable, Codable), `RecoveryGoal` enum with `displayLabel` computed property, `RecoverySignalType` enum, `ActivityTrigger` enum, and `RecoverySignal` struct
    - Ensure `RecoveryGoal.displayLabel` uses wellness language ("Improve Mobility", "Support Recovery", etc.)
    - _Requirements: 12.1, 13.1, 14.1, 14.2, 14.4, 15.1, 15.2, 16.1_

  - [ ] 1.4 Define QuickPoseResult, Landmark, and assessment data models
    - Create `Models/QuickPoseResult.swift` with `Landmark` struct (x, y, z, visibility), `QuickPoseResult` struct (landmarks, jointAngles, romValues, asymmetryScores, movementQuality, gaitMetrics, capturedAt), and nested `GaitMetrics` struct
    - Ensure all types conform to `Codable` for JSON serialization
    - Create `Models/Assessment.swift` with `Assessment` struct (id, clientId, clinicId, assessmentType, quickposeData, romValues, asymmetryScores, movementQualityScores, heartRate, bodyZones, recoveryGoal, recoveryMap, createdAt) and `AssessmentType` enum
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 10.1, 10.2_

  - [ ] 1.5 Define RecoveryMap, Outcome, DailyCheckin, and GamificationState models
    - Create `Models/RecoveryMap.swift` with `RecoveryMap` struct containing `HighlightedRegion` (region, severity, signalType, romDelta, asymmetryFlag, compensationHint), `WearableContext` (hrv, strain, sleepScore, lastSync), `PriorSessionSummary`, and `suggestedGoal`
    - Create `Models/Outcome.swift` with `Outcome` struct (stiffnessAfter, sorenessAfter, mobilityImproved, sessionEffective, repeatIntent, clientNotes, recordedBy)
    - Create `Models/DailyCheckin.swift` with `DailyCheckin` struct (overallFeeling 1–5, targetRegions, activitySinceLast, checkinType)
    - Create `Models/RecoveryScore.swift` with recovery score data type
    - Create `Models/GamificationState.swift` with `GamificationState` struct (xp, level, streakDays, lastActivityDate) and static `levelThresholds` and `xpRewards` dictionaries
    - _Requirements: 9.1, 9.2, 20.2, 22.2, 23.1, 23.2, 23.3_

- [ ] 2. Implement service layer protocols and authentication
  - [ ] 2.1 Create SupabaseService with protocol and implementation
    - Create `Services/SupabaseService.swift` with `SupabaseServiceProtocol` defining methods for: `fetchClientProfile`, `updateClientProfile`, `createAssessment`, `fetchAssessments`, `fetchLatestAssessment`, `createOutcome`, `createCheckin`, `fetchRecentCheckins`, `fetchRecoveryScore`, `fetchRecoveryTrend`
    - Implement the concrete `SupabaseService` class using the `supabase-swift` SDK, initializing with Supabase URL and anon key from Constants
    - _Requirements: 10.1, 10.2, 12.3, 20.3, 22.3, 21.4_

  - [ ] 2.2 Implement AuthService with Apple Sign-In and magic link
    - Create `Services/AuthService.swift` with `AuthServiceProtocol` defining: `signInWithApple`, `signInWithEmail`, `verifyMagicLink`, `signOut`, `refreshSession`, `currentUser`, `isAuthenticated`
    - Implement Apple Sign-In flow using `ASAuthorizationAppleIDCredential` and Supabase Auth
    - Implement email magic link flow: trigger magic link email via Supabase Auth, handle deep link callback to complete auth
    - Store JWT session token via Supabase client for authenticated API requests
    - Handle auth failure with descriptive error messages
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

  - [ ] 2.3 Implement AuthViewModel and auth views
    - Create `ViewModels/AuthViewModel.swift` as an `ObservableObject` wrapping `AuthService`, exposing `isAuthenticated`, `errorMessage`, and methods for `signInWithApple()`, `sendMagicLink(email:)`, `handleMagicLinkCallback(url:)`
    - Create `Views/Auth/LoginView.swift` with Sign in with Apple button and email magic link input field
    - Create `Views/Auth/OnboardingView.swift` for first-time user onboarding
    - Wire auth gate in `ContentView.swift` so unauthenticated users see `LoginView` and cannot access other tabs
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.6, 24.3_

- [ ] 3. Checkpoint - Verify project structure and auth flow
  - Ensure all model types compile and conform to Codable
  - Ensure auth flow compiles with Supabase integration
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Implement on-device computation components
  - [ ] 4.1 Implement JointAngleCalculator
    - Create `Computation/JointAngleCalculator.swift` with static `computeAngle(a:vertex:c:)` method using dot product formula with SIMD3 vectors
    - Clamp cosine value to [-1, 1] before `acos()` to prevent NaN from floating-point imprecision
    - Define static `jointDefinitions` dictionary mapping joint names to landmark index triples: right/left shoulder flexion, right/left hip flexion, right/left knee flexion, right/left ankle dorsiflexion, spine flexion
    - Return angle in degrees
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 4.2 Write property test for JointAngleCalculator
    - **Property: Joint angle clamping — for any three landmarks, `computeAngle` always returns a value in [0, 180] degrees and never returns NaN**
    - **Validates: Requirements 3.1, 3.3**

  - [ ] 4.3 Implement ROMCalculator
    - Create `Computation/ROMCalculator.swift` with static `computeROM(frames:joints:useMax:)` method
    - Aggregate joint angles across all accumulated landmark frames for a capture step
    - Return maximum angle for flexion movements (`useMax: true`) or minimum angle for extension movements (`useMax: false`)
    - Output ROM values keyed by joint name (e.g., "right_shoulder_flexion", "left_knee_flexion")
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 3.4_

  - [ ]* 4.4 Write property test for ROMCalculator
    - **Property: ROM bounds — for any non-empty array of landmark frames, each ROM value is in [0, 180] degrees and ROM(max) >= any individual frame angle for that joint**
    - **Validates: Requirements 4.1, 4.5**

  - [ ] 4.5 Implement AsymmetryCalculator
    - Create `Computation/AsymmetryCalculator.swift` with static `bilateralPairs` array and `computeAsymmetry(romValues:)` method
    - Compute asymmetry as `abs(right - left) / ((right + left) / 2) * 100` for shoulder, hip, and knee flexion pairs
    - Return 0 when both left and right values are zero (avoid division by zero)
    - Output keyed by joint pair name (e.g., "shoulder_flexion", "knee_flexion")
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ]* 4.6 Write property test for AsymmetryCalculator
    - **Property: Asymmetry symmetry — `asymmetry(right, left) == asymmetry(left, right)` for all non-negative inputs, and asymmetry is 0 when right == left**
    - **Property: Asymmetry zero-safe — when both right and left are 0, asymmetry returns 0 (no division by zero)**
    - **Validates: Requirements 5.2, 5.3**

  - [ ] 4.7 Implement MovementQualityScorer
    - Create `Computation/MovementQualityScorer.swift` with `SquatReference` and `HipHingeReference` structs containing reference angle ranges from UI-PRMD dataset
    - Implement `scoreSquat(frames:)` evaluating knee tracking (valgus/varus), trunk lean angle, squat depth (hip-to-knee angle), and ankle mobility against reference ranges
    - Implement `scoreHipHinge(frames:)` evaluating hamstring flexibility (hip angle), lumbar flexion (spine angle), and knee bend control
    - Normalize all scores to 0.0–1.0 range
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ] 4.8 Implement RepCounter
    - Create `Computation/RepCounter.swift` that uses QuickPose rep counting to detect completed repetitions during squat and hip hinge capture steps
    - Record per-rep joint angle data (peak and trough values) for each counted repetition
    - _Requirements: 8.1, 8.3_

- [ ] 5. Implement QuickPose SDK integration and capture pipeline
  - [ ] 5.1 Create QuickPoseService with camera setup and pipeline control
    - Create `Services/QuickPoseService.swift` with `QuickPoseServiceProtocol` defining: `startPipeline`, `stopPipeline`, `getCurrentLandmarks`, `accumulateLandmarks`, `computeJointAngles`, `computeROM`, `computeAsymmetry`, `computeMovementQuality`, `getRepCount`
    - Implement camera permission request and rear-facing camera feed initialization
    - Integrate `QuickPoseBasicView` for real-time skeleton overlay with 33-point landmark detection
    - Ensure all pose estimation runs on-device with no cloud dependency
    - Handle camera permission denial: display message explaining camera is required and provide button to open device Settings
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 26.1_

  - [ ] 5.2 Define CaptureStep enum and step configuration
    - Create `CaptureStep` enum with seven cases: standingFront, standingSide, shoulderFlexion, squat, hipHinge, balanceRight, balanceLeft
    - Define `title`, `instruction` (plain-language), `duration` (5s/5s/10s/10s/8s/10s/10s), `isRepetitive`, and `targetJoints` computed properties for each step
    - Total capture time: 58 seconds (under 60s requirement)
    - _Requirements: 2.1, 2.2, 2.5_

  - [ ] 5.3 Implement CaptureViewModel with guided flow orchestration
    - Create `ViewModels/CaptureViewModel.swift` as an `ObservableObject` managing the 7-step capture flow
    - Track `currentStep`, `remainingSeconds`, `repCount`, `isCapturing`, and accumulated landmark frames per step
    - On each step: start countdown timer, accumulate landmarks from QuickPoseService, compute joint angles and ROM when step completes, auto-advance to next step
    - For repetitive steps (squat, hip hinge): display rep count, provide visual and haptic feedback when target rep count is reached
    - After all 7 steps: compute asymmetry scores, compute movement quality scores, merge per-step results into a single `QuickPoseResult`, build `Assessment` record
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 7.1, 7.2, 8.1, 8.2, 8.4_

  - [ ] 5.4 Create QuickPoseCaptureView with real-time UI
    - Create `Views/Client/QuickPoseCaptureView.swift` displaying the camera feed with skeleton overlay via `QuickPoseBasicView`
    - Show step title, plain-language instruction, and progress indicator (current step out of 7)
    - Show countdown timer with remaining seconds for the active step
    - Show rep count overlay for repetitive movements (squat, hip hinge)
    - Use `StepProgressIndicator` shared component for step progress
    - _Requirements: 2.2, 2.3, 8.2_

  - [ ]* 5.5 Write property test for QuickPoseResult serialization round-trip
    - **Property: Round-trip consistency — for any valid QuickPoseResult, encoding to JSON then decoding back produces an equivalent object**
    - **Validates: Requirements 7.3, 7.4**

- [ ] 6. Checkpoint - Verify computation and capture pipeline
  - Ensure JointAngleCalculator, ROMCalculator, AsymmetryCalculator, and MovementQualityScorer compile and produce valid outputs
  - Ensure CaptureViewModel orchestrates the 7-step flow correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Implement intake flow (body map, signals, goals, activity context)
  - [ ] 7.1 Implement IntakeViewModel
    - Create `ViewModels/IntakeViewModel.swift` as an `ObservableObject` managing the 4-step intake flow: body zone selection → recovery signal entry → goal selection → activity context
    - Track `selectedRegions` (Set<BodyRegion>), `recoverySignals` ([RecoverySignal]), `recoveryGoal` (RecoveryGoal?), `activityContext` (String)
    - On intake completion: save to `client_profiles` table via SupabaseService (update `primary_regions`, `recovery_signals`, `goals`, `activity_context`), then navigate to capture screen
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [ ] 7.2 Create BodyMapCanvas and BodyMapView
    - Create `Views/Shared/BodyMapCanvas.swift` with a 2D body silhouette image and tappable overlay zones for all 15 BodyRegion values using normalized CGRect coordinates
    - Implement tap-to-toggle selection with colored overlay highlight for selected zones
    - Display count of currently selected zones
    - Allow multi-select of body zones
    - Create `Views/Client/BodyMapView.swift` wrapping BodyMapCanvas with navigation controls
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ] 7.3 Create SignalEntryView for per-region recovery signals
    - Create `Views/Client/SignalEntryView.swift` presenting a form for each selected body zone
    - Include signal type picker (stiffness, soreness, tightness, restriction, guarding)
    - Include severity slider/stepper (1–10 scale)
    - Include activity trigger picker (morning, after_running, after_lifting, post_travel, post_training, evening, general)
    - Store each signal as a structured `RecoverySignal` object
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [ ] 7.4 Create GoalPickerView and ActivityContextView
    - Create `Views/Client/GoalPickerView.swift` displaying five RecoveryGoal options with descriptive wellness-language labels, allowing exactly one selection
    - Create `Views/Client/ActivityContextView.swift` with a text field and/or predefined option selection for recent activity context
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 16.1, 16.2_

  - [ ] 7.5 Create IntakeView to wire the 4-step intake flow
    - Create `Views/Client/IntakeView.swift` as a navigation container that sequences BodyMapView → SignalEntryView → GoalPickerView → ActivityContextView
    - On completion, navigate to QuickPose capture screen
    - _Requirements: 12.1, 12.4_

- [ ] 8. Implement optional wearable sync and rPPG consent/capture
  - [ ] 8.1 Implement HealthKitService for wearable data sync
    - Create `Services/HealthKitService.swift` with `HealthKitServiceProtocol` defining: `requestAuthorization`, `fetchLatestHRV`, `fetchLatestStrain`, `fetchLatestSleepScore`
    - Request HealthKit authorization for heart rate variability, activity energy, and sleep analysis
    - Read most recent HRV, strain estimate, and sleep score from HealthKit
    - Update `client_profiles` table fields: `wearable_hrv`, `wearable_strain`, `wearable_sleep_score`, `wearable_last_sync`
    - If client declines authorization, proceed without wearable data (leave fields null)
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

  - [ ] 8.2 Implement consent flow and rPPG vitals capture
    - Create `Views/Client/ConsentView.swift` with dedicated consent screen explaining face video is used for heart rate estimation, processed on-device, not stored or transmitted
    - Require explicit "I Consent" button tap before activating front-facing camera
    - If declined, skip rPPG step and proceed to next step
    - Store consent decision (granted/declined) with timestamp as `ConsentRecord`
    - Create `Services/rPPGService.swift` implementing on-device rPPG analysis from 15–30 seconds of front-facing camera face video
    - Create `Views/Client/rPPGCaptureView.swift` displaying camera feed during capture and estimated heart rate after processing
    - Discard raw face video frames after processing, retain only computed heart rate
    - Handle low-confidence results: display message and allow retry or skip
    - Store heart rate in Assessment record `heart_rate` field
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 19.1, 19.2, 19.3, 19.4, 19.5, 19.6_

- [ ] 9. Implement assessment upload, offline cache, and Recovery Map
  - [ ] 9.1 Implement OfflineCacheService with SwiftData
    - Create `Services/OfflineCacheService.swift` with `OfflineCacheServiceProtocol` defining: `cacheAssessment`, `getCachedAssessments`, `syncCachedAssessments`, `clearSyncedAssessments`, `hasPendingUploads`
    - Create `CachedAssessment` SwiftData model storing encoded Assessment JSON, creation date, and sync status
    - Implement sync logic: when connectivity is restored, upload all cached assessments and mark as synced
    - _Requirements: 10.3, 26.2, 26.3_

  - [ ] 9.2 Implement assessment upload flow in CaptureViewModel
    - After capture completes, create Assessment record in Supabase `assessments` table with QuickPoseResult data, ROM values, asymmetry scores, movement quality scores, body zones, recovery goal, and subjective baseline
    - Set `assessment_type` to "intake" for first-visit or "pre_session" for subsequent assessments
    - If upload fails due to network error, cache locally via OfflineCacheService and retry when connectivity is restored
    - On successful upload, display confirmation and navigate to results summary
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [ ] 9.3 Implement Recovery Map generation
    - Add Recovery Map generation logic to CaptureViewModel (or a dedicated RecoveryMapService)
    - Combine QuickPoseResult data with intake signals, wearable context, and prior session history
    - Populate highlighted regions with severity, signal type, ROM delta vs last assessment, asymmetry flag, and optional compensation hint
    - Include wearable context (HRV, strain, sleep score, last sync) and prior sessions (date, config summary, outcome rating)
    - Suggest a Recovery_Goal based on the combined data
    - Store Recovery Map in Assessment record `recovery_map` JSONB field
    - Ensure Recovery Map is viewable within 60 seconds of assessment completion
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [ ] 9.4 Create ResultsSummaryView
    - Create `Views/Client/ResultsSummaryView.swift` displaying the assessment results: ROM values, asymmetry scores, movement quality scores, and Recovery Map summary
    - Use wellness-appropriate language throughout
    - _Requirements: 2.6, 10.4, 25.1, 25.2, 25.3_

- [ ] 10. Checkpoint - Verify capture-to-upload pipeline
  - Ensure full flow works: intake → capture → computation → assessment upload (or offline cache)
  - Ensure Recovery Map is generated and stored correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Implement post-session feedback and daily check-in
  - [ ] 11.1 Implement FeedbackViewModel and PostSessionView
    - Create `ViewModels/FeedbackViewModel.swift` as an `ObservableObject` managing post-session feedback collection
    - Create `Views/Client/PostSessionView.swift` collecting: stiffness-after (0–10), soreness-after (0–10), mobility improvement (yes/no/maybe), session effectiveness (yes/no/maybe), repeat intent (yes/maybe/no-try-different), and optional free-text notes
    - On submit: create Outcome record in Supabase `outcomes` table with `recorded_by` set to "client"
    - Navigate to Recovery Score display after submission
    - _Requirements: 20.1, 20.2, 20.3, 20.4_

  - [ ] 11.2 Implement daily check-in flow
    - Create `Views/Client/CheckInView.swift` with daily check-in form collecting: overall feeling (1–5 emoji scale via `EmojiScalePicker`), target region status for regions from last session, and free-text activity description
    - On submit: create record in Supabase `daily_checkins` table with `checkin_type` set to "daily"
    - Trigger Recovery_Score recalculation by the backend after submission
    - _Requirements: 22.1, 22.2, 22.3, 22.4_

  - [ ]* 11.3 Write unit tests for FeedbackViewModel and check-in submission
    - Test that Outcome record is created with correct `recorded_by` value
    - Test that DailyCheckin record has correct `checkin_type`
    - Test emoji scale maps to correct 1–5 integer values
    - _Requirements: 20.3, 22.3_

- [ ] 12. Implement Recovery Score display and home screen
  - [ ] 12.1 Implement HomeViewModel with Recovery Score and gamification
    - Create `ViewModels/HomeViewModel.swift` as an `ObservableObject` fetching and exposing: current Recovery_Score (0–100), 30-day recovery trend data, streak count, XP, level, client name, and active session status
    - Fetch Recovery_Score from `recovery_graph` table filtered by client ID and "recovery_score" metric type
    - Update displayed score when it changes (after session outcome or daily check-in)
    - _Requirements: 21.1, 21.3, 21.4, 23.1, 23.2, 23.3, 24.2_

  - [ ] 12.2 Create Recovery Score display views
    - Create `Views/Shared/RecoveryScoreGauge.swift` as a circular gauge component displaying the 0–100 score
    - Create `Views/Shared/TrendLineChart.swift` showing the Recovery_Score trajectory over the last 30 days
    - Create `Views/Client/RecoveryScoreView.swift` composing the gauge and trend chart
    - _Requirements: 21.1, 21.2_

  - [ ] 12.3 Implement GamificationService and continuity features
    - Create `Services/GamificationService.swift` tracking XP, levels, and streaks
    - Award XP for: session completed (50), check-in submitted (20), 7-day streak (100), 30-day streak (500), first assessment (75)
    - Compute level from accumulated XP using `levelThresholds`
    - Track consecutive days with check-in or session for streak counter
    - Reset streak to zero when a calendar day is missed, display encouraging restart message
    - _Requirements: 23.1, 23.2, 23.3, 23.5_

  - [ ] 12.4 Create gamification and before/after views
    - Create `Views/Client/StreakView.swift` displaying streak counter, XP, and current level with visible thresholds
    - Create `Views/Client/BeforeAfterView.swift` showing visual comparison of ROM values and asymmetry scores from first assessment vs most recent assessment
    - _Requirements: 23.1, 23.3, 23.4_

- [ ] 13. Implement tab navigation and client home screen
  - [ ] 13.1 Wire tab-based navigation structure
    - Update `ContentView.swift` with `TabView` containing four tabs: Home (Recovery Score and quick actions), Capture (intake and QuickPose flow), Check-In (daily check-in), Profile (settings and history)
    - Display client name, current Recovery_Score, streak count, and XP level on the Home tab
    - Show persistent banner on Home tab when client has an active session in progress
    - Ensure unauthenticated users see LoginView and cannot access any tab
    - _Requirements: 24.1, 24.2, 24.3, 24.4_

  - [ ] 13.2 Create shared UI components
    - Create `Views/Shared/StepProgressIndicator.swift` for capture step progress display
    - Create `Views/Shared/EmojiScalePicker.swift` for 1–5 emoji scale input in daily check-ins
    - Ensure all shared components use wellness-appropriate language
    - _Requirements: 2.2, 22.2, 25.1, 25.2_

- [ ] 14. Implement offline resilience and sync
  - [ ] 14.1 Wire offline detection and sync across the app
    - Add network reachability monitoring to detect online/offline state
    - Ensure QuickPose pipeline, joint angle computation, ROM measurement, asymmetry detection, and movement quality scoring all work without network
    - Allow full guided capture flow and local results viewing while offline
    - When connectivity is restored, automatically sync cached assessments via OfflineCacheService
    - _Requirements: 26.1, 26.2, 26.3_

- [ ] 15. Final checkpoint - Full integration verification
  - Ensure complete flow works end-to-end: auth → intake → capture → computation → upload → feedback → Recovery Score → check-in → gamification
  - Verify offline capture and sync works correctly
  - Verify all 26 requirements are covered by the implementation
  - Verify wellness language compliance across all user-facing screens
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breaks
- Property tests validate computation correctness (joint angle clamping, ROM bounds, asymmetry symmetry, serialization round-trip)
- Unit tests validate specific examples and edge cases
- The implementation language is Swift throughout (SwiftUI for views, MVVM architecture)
- All pose computation runs on-device via QuickPose SDK — no cloud dependency for capture
- The app depends on the backend-foundation spec (Spec 1) for Supabase tables, auth, and RLS policies
