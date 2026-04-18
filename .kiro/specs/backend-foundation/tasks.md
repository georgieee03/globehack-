# Implementation Plan: Backend Foundation

## Overview

This plan implements the HydraScan backend foundation as a Turborepo monorepo with a Supabase backend, shared TypeScript types package, JWT authentication, multi-tenant RLS policies, device registry with lifecycle state machine, MQTT command proxy (with simulation mode), safe envelope validation, audit logging, and wellness language compliance. Tasks are ordered so each step builds on the previous, with checkpoints at logical breaks.

## Tasks

- [ ] 1. Initialize monorepo scaffold and project structure
  - [ ] 1.1 Create root Turborepo configuration and workspace setup
    - Create root `package.json` with `workspaces: ["backend", "shared"]` and devDependencies for `turbo` and `typescript`
    - Create `turbo.json` with pipeline config for `build`, `typecheck`, `test`, and `lint`
    - Create root `tsconfig.json` base config
    - Create `.gitignore` with entries for `.env`, `node_modules`, `.supabase`, `dist`
    - Create `.env.example` with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `HYDRAWAV_API_BASE_URL`, `LLM_API_KEY`
    - Create root `README.md` with setup instructions, environment variable requirements, and branch strategy for the four-person team
    - _Requirements: 1.1, 1.2, 1.4, 3.1, 3.2_

  - [ ] 1.2 Create shared TypeScript types package structure
    - Create `shared/package.json` with name `@hydrascan/shared` and TypeScript build config
    - Create `shared/tsconfig.json` with strict mode and declaration output
    - Create `shared/src/index.ts` as the barrel re-export file
    - Create directory structure: `shared/src/types/`, `shared/src/constants/`, `shared/src/validation/`
    - _Requirements: 1.3_

  - [ ] 1.3 Create backend Supabase project structure
    - Create `backend/package.json` with Supabase CLI dependency
    - Create `backend/supabase/config.toml` with project configuration
    - Create directory structure: `backend/supabase/migrations/`, `backend/supabase/functions/`, `backend/supabase/seed/`
    - Create `backend/supabase/functions/_shared/` directory for shared Edge Function utilities
    - _Requirements: 2.1_

- [ ] 2. Implement shared TypeScript type definitions
  - [ ] 2.1 Define core enum types and user types
    - Create `shared/src/types/user.ts` with `UserRole` type (`client | practitioner | admin`)
    - Create `shared/src/types/device.ts` with `DeviceStatus` type (`idle | in_session | paused | maintenance | offline`)
    - Create `shared/src/types/session.ts` with `SessionStatus` type (`pending | active | paused | completed | cancelled | error`)
    - Create `shared/src/types/assessment.ts` with `AssessmentType` type (`intake | pre_session | follow_up | reassessment`)
    - _Requirements: 1.3, 6.1_

  - [ ] 2.2 Define BodyRegion, RecoverySignal, and ClientProfile types
    - Create `shared/src/types/client-profile.ts` with `BodyRegion` union type (15 regions), `RecoveryGoal`, `RecoverySignalType`, and `RecoverySignal` interface
    - _Requirements: 1.3, 8.1_

  - [ ] 2.3 Define SessionConfig and related types
    - Create `shared/src/types/session-config.ts` with `ModalityFunc`, `PlayCmd`, and `SessionConfig` interface matching the full Hydrawav3 MQTT payload schema (mac, sessionCount, sessionPause, sDelay, cycle1, cycle5, edgeCycleDuration, cycleRepetitions, cycleDurations, cyclePauses, pauseIntervals, leftFuncs, rightFuncs, pwmValues, playCmd, led, hotDrop, coldDrop, vibMin, vibMax, totalDuration)
    - _Requirements: 13.1_

  - [ ] 2.4 Define SafeEnvelope types and constants
    - Create `shared/src/types/safe-envelope.ts` with `SafeEnvelope` interface and `SafeEnvelopeViolation` interface
    - Create `shared/src/constants/safe-ranges.ts` with `SAFE_ENVELOPES` record containing `_default` ranges and region-specific overrides for `neck` and `lower_back`
    - _Requirements: 13.2, 13.5_

  - [ ] 2.5 Define wellness language constants
    - Create `shared/src/constants/language-guardrails.ts` with `FORBIDDEN_TERMS` list and `PREFERRED_REPLACEMENTS` mapping
    - Create `shared/src/constants/body-regions.ts` with BodyRegion enum values
    - _Requirements: 17.1, 17.3_

  - [ ] 2.6 Update barrel export file
    - Update `shared/src/index.ts` to re-export all types, constants, and validation functions
    - _Requirements: 1.3_

- [ ] 3. Implement shared validation functions
  - [ ] 3.1 Implement safe envelope validator
    - Create `shared/src/validation/safe-envelope.ts` with `validateSafeEnvelope(config: SessionConfig, region?: BodyRegion)` function
    - Merge `_default` envelope with region-specific overrides when a region is provided
    - Validate all numeric parameters (pwmValues.hot, pwmValues.cold, vibMin, vibMax, hotDrop, coldDrop, edgeCycleDuration) against min/max ranges
    - Return `{ valid: boolean; violations: SafeEnvelopeViolation[] }` with all violations, not just the first
    - _Requirements: 13.2, 13.3, 13.4, 13.5_

  - [ ]* 3.2 Write property tests for safe envelope validation
    - **Property 1: Any SessionConfig with all parameters within safe ranges must pass validation**
    - **Property 2: Any SessionConfig with at least one parameter outside safe ranges must fail with a non-empty violations array**
    - **Property 3: Region-specific overrides must take precedence over default ranges (e.g., neck pwmHotMax=100 vs default 150)**
    - **Validates: Requirements 13.2, 13.3, 13.4, 13.5**

  - [ ] 3.3 Implement device state transition validator
    - Create `shared/src/validation/device-state.ts` with `isValidTransition(currentStatus: DeviceStatus, command)` function
    - Encode the full state machine: idle→start→in_session, in_session→pause→paused, paused→resume→in_session, in_session/paused→stop→idle, any→maintenance→maintenance
    - Return boolean indicating whether the transition is valid
    - Also export `getNextStatus(currentStatus: DeviceStatus, command)` returning the new status or null if invalid
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ]* 3.4 Write property tests for device state transitions
    - **Property 4: For every valid (status, command) pair in the transition table, isValidTransition returns true and getNextStatus returns a non-null DeviceStatus**
    - **Property 5: For every invalid (status, command) pair, isValidTransition returns false and getNextStatus returns null**
    - **Property 6: Applying a valid transition and then its inverse (e.g., start then stop, pause then resume) returns to the original state**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**

  - [ ] 3.5 Implement wellness language validator
    - Create `shared/src/validation/wellness-language.ts` with `validateWellnessLanguage(text: string)` function
    - Scan text against `FORBIDDEN_TERMS` and return violations with term, replacement, and position
    - _Requirements: 17.1, 17.2_

  - [ ]* 3.6 Write unit tests for wellness language validator
    - Test detection of forbidden terms in various positions
    - Test that clean text passes validation
    - Test replacement suggestions are correct
    - _Requirements: 17.2_

- [ ] 4. Checkpoint — Shared package validation
  - Ensure all tests pass, ask the user if questions arise.
  - Verify `shared` package builds successfully with `turbo build`
  - Verify all type exports are accessible from `@hydrascan/shared`

- [ ] 5. Create Supabase database migrations
  - [ ] 5.1 Create clinics and users table migrations
    - Create `backend/supabase/migrations/00001_create_clinics.sql` with UUID PK, name, address, timezone, timestamps
    - Create `backend/supabase/migrations/00002_create_users.sql` with UUID PK, clinic_id FK, role CHECK constraint (`client`, `practitioner`, `admin`), email UNIQUE, full_name, phone, date_of_birth, auth_provider, avatar_url, timestamps
    - _Requirements: 2.2, 2.3, 5.1, 6.1_

  - [ ] 5.2 Create devices table migration
    - Create `backend/supabase/migrations/00003_create_devices.sql` with UUID PK, clinic_id FK, device_mac, label, room, assigned_practitioner FK, status CHECK constraint (`idle`, `in_session`, `paused`, `maintenance`, `offline`), last_session_id, firmware, timestamps, UNIQUE(clinic_id, device_mac)
    - _Requirements: 2.2, 9.1, 9.2, 9.5_

  - [ ] 5.3 Create client_profiles table migration
    - Create `backend/supabase/migrations/00004_create_client_profiles.sql` with UUID PK, user_id FK UNIQUE, clinic_id FK, primary_regions JSONB, recovery_signals JSONB, goals TEXT[], activity_context, sensitivities, notes, wearable fields, timestamps
    - _Requirements: 2.2, 8.1, 8.3_

  - [ ] 5.4 Create assessments, sessions, and outcomes table migrations
    - Create `backend/supabase/migrations/00005_create_assessments.sql` with all assessment fields including JSONB columns for quickpose_data, rom_values, asymmetry_scores, etc.
    - Create `backend/supabase/migrations/00006_create_sessions.sql` with session_config JSONB, status CHECK, timing fields, outcome JSONB
    - Create `backend/supabase/migrations/00007_create_outcomes.sql` with before/after scores, CHECK constraints for 0-10 ranges, rom_after JSONB
    - _Requirements: 2.2, 2.3_

  - [ ] 5.5 Create recovery_graph and daily_checkins table migrations
    - Create `backend/supabase/migrations/00008_create_recovery_graph.sql` with composite index on (client_id, body_region, recorded_at DESC)
    - Create `backend/supabase/migrations/00009_create_daily_checkins.sql` with checkin_type CHECK constraint, overall_feeling CHECK 1-5
    - _Requirements: 2.2, 2.3_

  - [ ] 5.6 Create clinic_hw_tokens and mqtt_command_log table migrations
    - Create `backend/supabase/migrations/00010_create_clinic_hw_tokens.sql` with clinic_id FK UNIQUE, access_token, refresh_token, timestamps
    - Create `backend/supabase/migrations/00011_create_mqtt_command_log.sql` with clinic_id FK, device_id FK, command, payload JSONB, mqtt_response_status, error_details, simulated BOOLEAN, timestamp
    - _Requirements: 2.4, 2.5, 14.1_

- [ ] 6. Create RLS policies for multi-tenant isolation
  - [ ] 6.1 Enable RLS and create clinic-scoped SELECT policies
    - Create `backend/supabase/migrations/00012_create_rls_policies.sql`
    - Enable RLS on all data tables: users, devices, client_profiles, assessments, sessions, outcomes, recovery_graph, daily_checkins, clinic_hw_tokens, mqtt_command_log
    - Create SELECT policies filtering by `clinic_id = (SELECT clinic_id FROM users WHERE id = auth.uid())`
    - _Requirements: 5.2, 5.3_

  - [ ] 6.2 Create role-differentiated RLS policies
    - Create client-specific policies: client sees own profile only, client sees own assessments/sessions/outcomes/checkins only
    - Create practitioner policies: practitioner sees all clinic profiles, can create/update assessments and sessions
    - Create admin policies: admin can CRUD devices, manage users, access clinic_hw_tokens
    - Reject client attempts to modify devices table
    - _Requirements: 5.3, 5.4, 6.2, 6.3, 6.4, 6.5_

  - [ ] 6.3 Create INSERT/UPDATE/DELETE RLS policies
    - INSERT policies: admin-only for users and devices, practitioner for assessments/sessions, client for own outcomes/checkins
    - UPDATE policies: own record for users, admin+practitioner for device status, client for own profile
    - DELETE policies: admin-only where applicable
    - _Requirements: 5.4, 6.4, 6.5_

  - [ ]* 6.4 Write property tests for RLS clinic isolation
    - **Property 7: For any two users in different clinics, a query by User A on any RLS-enabled table never returns rows with User B's clinic_id**
    - **Property 8: For any user with role=client, a query on client_profiles returns at most 1 row (their own)**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 6.2, 6.3**

- [ ] 7. Create seed data
  - [ ] 7.1 Create comprehensive seed SQL file
    - Create `backend/supabase/seed/seed.sql` with mock data for:
      - At least 2 clinics (e.g., "Phoenix Recovery Center", "Scottsdale Wellness Studio")
      - Multiple users across all 3 roles per clinic (at least 1 admin, 2 practitioners, 3 clients per clinic)
      - At least 2 devices per clinic with different statuses
      - Sample client profiles with recovery signals, goals, and wearable data
      - Sample assessments, sessions, and outcomes for testing
    - _Requirements: 2.6, 5.5_

- [ ] 8. Checkpoint — Database layer validation
  - Ensure all migrations apply cleanly in order
  - Verify seed data loads without constraint violations
  - Verify RLS policies are active on all tables
  - Ask the user if questions arise.

- [ ] 9. Implement Edge Function shared utilities
  - [ ] 9.1 Create CORS handler utility
    - Create `backend/supabase/functions/_shared/cors.ts` with CORS headers for Edge Functions
    - Handle OPTIONS preflight requests
    - _Requirements: 16.1, 16.4_

  - [ ] 9.2 Create Supabase client utility
    - Create `backend/supabase/functions/_shared/supabase-client.ts`
    - Create helper to initialize Supabase client with service role key from `Deno.env.get()`
    - Create helper to extract and verify user JWT from Authorization header
    - _Requirements: 3.3, 4.2, 4.3_

  - [ ] 9.3 Create safe envelope Edge Function utility
    - Create `backend/supabase/functions/_shared/safe-envelope.ts`
    - Import or re-implement `validateSafeEnvelope` for Deno runtime compatibility
    - _Requirements: 13.3_

- [ ] 10. Implement hydrawav-auth Edge Function
  - [ ] 10.1 Create hydrawav-auth endpoint
    - Create `backend/supabase/functions/hydrawav-auth/index.ts`
    - Accept POST with `{ username, password }` body
    - Verify caller is an admin for their clinic via Supabase JWT → users table lookup
    - POST to `{HYDRAWAV_API_BASE_URL}/api/v1/auth/login` with `{ username, password, rememberMe: true }`
    - On success: upsert `clinic_hw_tokens` with access and refresh tokens scoped to the admin's clinic
    - On failure: return HTTP 401 with descriptive error message
    - Return HTTP 401 for unauthenticated requests
    - _Requirements: 4.3, 11.1, 11.2, 11.3, 16.1_

  - [ ]* 10.2 Write unit tests for hydrawav-auth
    - Test successful authentication flow with mocked Hydrawav3 API
    - Test failure when non-admin user calls the endpoint
    - Test failure when Hydrawav3 API returns error
    - Test unauthenticated request returns 401
    - _Requirements: 11.1, 11.2, 11.3_

- [ ] 11. Implement hydrawav-mqtt Edge Function
  - [ ] 11.1 Create hydrawav-mqtt endpoint with command routing
    - Create `backend/supabase/functions/hydrawav-mqtt/index.ts`
    - Accept POST with `{ deviceId, command, sessionConfig?, bodyRegion? }` body
    - Extract `clinic_id` from authenticated user's JWT
    - Fetch device record (MAC, current status) and clinic HW token from DB
    - Route to appropriate handler based on command type (start, pause, resume, stop)
    - Return HTTP 401 for unauthenticated requests
    - _Requirements: 4.3, 12.1, 12.7, 16.4_

  - [ ] 11.2 Implement state transition validation in MQTT handler
    - Validate command against device's current status using `isValidTransition`
    - Return HTTP 409 with descriptive error for invalid transitions
    - _Requirements: 10.6_

  - [ ] 11.3 Implement safe envelope validation for Start commands
    - For `start` commands: validate SessionConfig against safe envelope with optional region overrides
    - Return HTTP 400 with all violations if SessionConfig is outside safe envelope
    - _Requirements: 13.3, 13.4_

  - [ ] 11.4 Implement MQTT payload construction and publishing
    - For `start`: build full SessionConfig payload with device MAC and `playCmd: 1`
    - For `pause`: build minimal payload with MAC and `playCmd: 2`
    - For `stop`: build minimal payload with MAC and `playCmd: 3`
    - For `resume`: build minimal payload with MAC and `playCmd: 4`
    - Always stringify payload as JSON string for the Hydrawav3 API
    - POST to `/api/v1/mqtt/publish` with `{ topic: "HydraWav3Pro/config", payload: JSON.stringify(payload) }`
    - Include stored access token in Authorization header
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 11.4_

  - [ ] 11.5 Implement simulation mode
    - Check `HYDRAWAV_API_BASE_URL` env var: if not set or set to `"simulation"`, operate in simulation mode
    - In simulation mode: skip HTTP call to Hydrawav3 API, process everything else identically
    - Return `{ success: true, simulated: true }` in simulation mode
    - Log commands with `simulated: true` flag
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

  - [ ] 11.6 Implement device status update and audit logging
    - After successful command (live or simulated): update device status in registry using `getNextStatus`
    - Insert audit log record into `mqtt_command_log` with clinic_id, device_id, command, payload, response status, simulated flag
    - Log error details if MQTT API returns an error
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 14.1, 14.2, 14.3_

  - [ ]* 11.7 Write unit tests for hydrawav-mqtt
    - Test start command with valid SessionConfig in simulation mode
    - Test pause/resume/stop commands update device status correctly
    - Test invalid state transition returns 409
    - Test safe envelope violation returns 400 with violations array
    - Test audit log record is created for each command
    - Test simulation mode flag is set correctly
    - _Requirements: 12.1, 12.3, 12.4, 12.5, 12.6, 10.6, 13.4, 14.1, 14.2, 15.2_

- [ ] 12. Checkpoint — Edge Functions validation
  - Ensure all tests pass, ask the user if questions arise.
  - Verify hydrawav-auth and hydrawav-mqtt Edge Functions deploy without errors
  - Verify simulation mode works end-to-end

- [ ] 13. Implement SessionConfig serialization and round-trip validation
  - [ ] 13.1 Create SessionConfig builder/serializer utility
    - Create utility function to build a valid SessionConfig from session parameters
    - Create serializer that produces the exact JSON string format expected by the Hydrawav3 API
    - Ensure round-trip: `JSON.parse(JSON.stringify(config))` produces an identical SessionConfig
    - _Requirements: 12.2, 13.1_

  - [ ]* 13.2 Write property tests for SessionConfig serialization round-trip
    - **Property 9: For any valid SessionConfig, serializing to JSON and deserializing back produces an identical object**
    - **Property 10: For any valid SessionConfig, the serialized payload always contains the `mac` field and `playCmd` field**
    - **Validates: Requirements 12.2, 13.1**

- [ ] 14. Wire authentication and user management flows
  - [ ] 14.1 Configure Supabase Auth providers
    - Configure email magic link as primary auth provider in Supabase config
    - Configure Apple Sign-In as additional provider for iOS compatibility
    - _Requirements: 4.1, 4.4_

  - [ ] 14.2 Implement user registration and onboarding logic
    - Create database trigger or Edge Function for new user onboarding
    - On new client auth: create `users` record with role `client` and associated clinic
    - On new client: auto-create `client_profiles` record with default empty recovery signals and goals
    - On practitioner invite: create `users` record with role `practitioner` linked to admin's clinic
    - On admin creating clinic: create both `clinics` record and `users` record with role `admin`
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [ ]* 14.3 Write unit tests for user registration flows
    - Test new client gets users record + client_profiles record
    - Test practitioner invite creates correct role and clinic association
    - Test admin clinic creation creates both records
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 15. Implement client profile CRUD operations
  - [ ] 15.1 Expose client profile operations via Supabase client access
    - Ensure client_profiles table is accessible via Supabase client library with RLS enforcement
    - Verify client can update own profile (recovery_signals, goals, wearable data) and `updated_at` is auto-updated
    - Verify practitioner can read all clinic profiles with full data including recovery signals, goals, activity context, and wearable data
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 16.3_

- [ ] 16. Final integration and wiring
  - [ ] 16.1 Verify end-to-end MQTT command flow in simulation mode
    - Wire all components together: auth → device lookup → state validation → safe envelope → payload build → simulation → status update → audit log
    - Verify the complete request flow from authenticated user to simulated command response
    - _Requirements: 12.1, 15.1, 15.2, 15.3_

  - [ ] 16.2 Verify multi-tenant isolation end-to-end
    - Using seed data with two clinics, verify that a user in Clinic A cannot read, update, or delete data belonging to Clinic B across all RLS-enabled tables
    - _Requirements: 5.5_

  - [ ]* 16.3 Write integration tests for end-to-end flows
    - Test full MQTT start command flow: auth → validate → publish → log
    - Test cross-clinic isolation with two authenticated users
    - Test device lifecycle: idle → start → pause → resume → stop → idle
    - _Requirements: 5.5, 10.1, 10.2, 10.3, 10.4, 12.1, 15.2_

- [ ] 17. Final checkpoint — Full backend foundation validation
  - Ensure all tests pass, ask the user if questions arise.
  - Verify all 17 requirements are covered by implementation
  - Verify shared package exports all required types and validation functions
  - Verify all Edge Functions are deployable

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breaks
- Property tests validate universal correctness properties (safe envelope ranges, state machine transitions, serialization round-trips, RLS isolation)
- Unit tests validate specific examples and edge cases
- The implementation language is TypeScript throughout (Deno for Edge Functions, Node/TS for shared package)
- Simulation mode is first-class: all development can proceed without Hydrawav3 hardware
