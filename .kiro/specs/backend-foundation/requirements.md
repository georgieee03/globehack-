# Requirements Document — Backend Foundation

## Introduction

This document defines the requirements for HydraScan's backend foundation, covering the project scaffold and environment setup (Phase 0), identity/auth/multi-tenant backend (Phase 1), and device registry with Hydrawav3 MQTT integration (Phase 2). This is Spec 1 of 4 for the HydraScan project, owned by Allu on the `allu-dev` branch. All other specs depend on this foundational backend being in place.

HydraScan is a practitioner-first recovery intelligence platform for the Hydrawav3 ecosystem. The backend foundation provides the monorepo structure, Supabase-backed multi-tenant data layer with Row Level Security, JWT authentication, user role management, device registry, and the MQTT proxy that bridges HydraScan to real HydraWav3Pro hardware.

## Glossary

- **Backend_Foundation**: The combined monorepo scaffold, Supabase backend, auth system, multi-tenant data layer, device registry, and MQTT proxy that all other HydraScan specs depend on.
- **Monorepo**: A single Git repository containing the backend, shared types, and configuration for the HydraScan project, managed with Turborepo or Nx.
- **Supabase**: The backend-as-a-service platform providing PostgreSQL, Row Level Security, JWT Auth, Edge Functions, Realtime subscriptions, and Storage.
- **RLS (Row Level Security)**: PostgreSQL policies that restrict data access at the database level, ensuring users can only access data within their own clinic workspace.
- **Clinic_Workspace**: A tenant boundary in HydraScan. Each clinic is an isolated workspace with its own users, devices, client profiles, and session data.
- **User_Role**: One of three roles assigned to each user: `client` (receives recovery sessions), `practitioner` (manages sessions and reviews recovery data), or `admin` (manages clinic settings and devices).
- **Edge_Function**: A Supabase serverless function (Deno/TypeScript) that runs server-side logic such as the MQTT proxy, safe envelope validation, and auth flows.
- **Device_Registry**: A table and API managing HydraWav3Pro devices within a clinic, tracking MAC address, room assignment, practitioner assignment, and lifecycle status.
- **Device_Status**: The lifecycle state of a device: `idle`, `in_session`, `paused`, `maintenance`, or `offline`.
- **MQTT_Proxy**: A Supabase Edge Function that authenticates with the Hydrawav3 API and publishes commands to the `HydraWav3Pro/config` topic on behalf of the clinic.
- **SessionConfig**: A TypeScript interface defining the full MQTT payload schema for starting a Hydrawav3 session, including MAC address, cycle choreography, modality sequences, thermal intensity, vibration ranges, and play command.
- **Safe_Envelope**: A set of min/max range constraints for all SessionConfig parameters that prevent unsafe values from being sent to the device.
- **PlayCmd**: An integer command value sent in the MQTT payload: 1 (Start), 2 (Pause), 3 (Stop), 4 (Resume).
- **Hydrawav3_API**: The external REST API providing JWT authentication (`/api/v1/auth/login`) and MQTT publishing (`/api/v1/mqtt/publish`) for HydraWav3Pro device control.
- **Shared_Types_Package**: A TypeScript package in the monorepo containing type definitions (SessionConfig, SafeEnvelope, BodyRegion, etc.) shared between backend functions and frontend consumers.
- **Client_Profile**: A database record containing a client's recovery signals, goals, activity context, sensitivities, and wearable data, scoped to a specific clinic.

## Requirements

### Requirement 1: Monorepo Scaffold and Project Structure

**User Story:** As a developer on the HydraScan team, I want a well-organized monorepo with clear directory structure and build tooling, so that all four team members can work in parallel on separate branches without conflicts.

#### Acceptance Criteria

1. THE Monorepo SHALL contain separate directories for `backend/` (Supabase project), `shared/` (TypeScript types and constants), and `docs/` (documentation).
2. THE Monorepo SHALL use Turborepo or Nx as the build orchestration tool with a root `package.json` defining workspace packages.
3. THE Shared_Types_Package SHALL export TypeScript type definitions including SessionConfig, SafeEnvelope, BodyRegion, UserRole, DeviceStatus, and SessionStatus.
4. THE Monorepo SHALL include a root `README.md` with setup instructions, environment variable requirements, and branch strategy for the four-person team.

### Requirement 2: Supabase Project Initialization and Database Schema

**User Story:** As a backend developer, I want the Supabase project initialized with all core tables and migrations, so that the data layer is ready for auth, profiles, devices, and sessions.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL initialize a Supabase project in the `backend/supabase/` directory with a valid `config.toml`.
2. THE Backend_Foundation SHALL create SQL migration files for the following tables: `clinics`, `users`, `devices`, `client_profiles`, `assessments`, `sessions`, `outcomes`, `recovery_graph`, and `daily_checkins`.
3. WHEN migrations are applied, THE Backend_Foundation SHALL create all tables with the column definitions, constraints, and check constraints specified in the build spec data model (Section 6.1).
4. THE Backend_Foundation SHALL create a `clinic_hw_tokens` table to store Hydrawav3 API JWT tokens scoped to each clinic.
5. THE Backend_Foundation SHALL create an `mqtt_command_log` table to store an audit trail of every MQTT command sent, including clinic_id, device_id, command type, payload, response status, and timestamp.
6. THE Backend_Foundation SHALL provide seed SQL files that populate mock data for at least two clinics, multiple users across all three roles, at least two devices, and sample client profiles.

### Requirement 3: Environment Configuration and Secrets Management

**User Story:** As a developer, I want a clear environment configuration setup with documented variables, so that each team member can configure their local environment and the backend can access required secrets.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL use a `.env` file pattern with a `.env.example` template listing all required environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `HYDRAWAV_API_BASE_URL`, and `LLM_API_KEY`.
2. THE Backend_Foundation SHALL include `.env` in the `.gitignore` file to prevent secrets from being committed.
3. WHEN an Edge_Function starts, THE Edge_Function SHALL read configuration from environment variables using `Deno.env.get()`.

### Requirement 4: Supabase Authentication with JWT

**User Story:** As a user (client, practitioner, or admin), I want to authenticate using email magic link or social providers, so that I can securely access HydraScan features scoped to my clinic.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL configure Supabase Auth with email (magic link) as the primary authentication provider.
2. WHEN a user authenticates successfully, THE Backend_Foundation SHALL issue a Supabase JWT session token that includes the user's `id` as `auth.uid()`.
3. WHEN an unauthenticated request is made to a protected Edge_Function, THE Edge_Function SHALL return HTTP 401 with an error message.
4. THE Backend_Foundation SHALL support Apple Sign-In as an additional authentication provider for iOS compatibility.

### Requirement 5: Multi-Tenant Clinic Workspaces

**User Story:** As a clinic administrator, I want my clinic's data to be completely isolated from other clinics, so that there is no cross-clinic data leakage.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL associate every user record with exactly one `clinic_id` foreign key referencing the `clinics` table.
2. THE Backend_Foundation SHALL enable Row Level Security on all data tables: `users`, `devices`, `client_profiles`, `assessments`, `sessions`, `outcomes`, `recovery_graph`, and `daily_checkins`.
3. WHEN a user queries any RLS-enabled table, THE RLS_Policy SHALL filter results to only rows matching the authenticated user's `clinic_id`.
4. WHEN a user attempts to insert a row with a `clinic_id` different from their own, THE RLS_Policy SHALL reject the insert operation.
5. THE Backend_Foundation SHALL verify clinic isolation by seeding two separate clinics and confirming that a user in Clinic A cannot read, update, or delete data belonging to Clinic B.

### Requirement 6: User Roles and Role-Based Access

**User Story:** As a system, I want to enforce role-based access control for clients, practitioners, and admins, so that each user type can only perform actions appropriate to their role.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL enforce a `role` column on the `users` table with a CHECK constraint limiting values to `client`, `practitioner`, and `admin`.
2. WHEN a user with role `client` queries the `client_profiles` table, THE RLS_Policy SHALL return only the profile belonging to that client.
3. WHEN a user with role `practitioner` queries the `client_profiles` table, THE RLS_Policy SHALL return all client profiles within the practitioner's clinic.
4. WHEN a user with role `admin` performs device registry operations, THE Backend_Foundation SHALL allow create, update, and delete operations on devices within the admin's clinic.
5. WHEN a user with role `client` attempts to modify the `devices` table, THE RLS_Policy SHALL reject the operation.

### Requirement 7: User Registration and Onboarding

**User Story:** As a new user, I want to register and be assigned to a clinic with the correct role, so that I can start using HydraScan immediately after authentication.

#### Acceptance Criteria

1. WHEN a new client authenticates for the first time, THE Backend_Foundation SHALL create a `users` record with role `client` and associate the user with a clinic via a clinic invite code or direct assignment.
2. WHEN a new client user is created, THE Backend_Foundation SHALL also create a corresponding `client_profiles` record with default empty recovery signals and goals.
3. WHEN a new practitioner is invited by an admin, THE Backend_Foundation SHALL create a `users` record with role `practitioner` linked to the admin's clinic.
4. WHEN an admin creates a new clinic, THE Backend_Foundation SHALL create both a `clinics` record and a `users` record with role `admin` for the creating user.

### Requirement 8: Client Profiles with Recovery Context

**User Story:** As a practitioner, I want each client to have a profile containing recovery signals, goals, and wearable context, so that I can make informed session decisions.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL store client profiles with JSONB fields for `primary_regions` (array of BodyRegion values), `recovery_signals` (region-keyed signal objects with type, severity 1-10, and trigger), and `goals` (array of RecoveryGoal values).
2. WHEN a client updates their profile, THE Backend_Foundation SHALL update the `updated_at` timestamp.
3. THE Backend_Foundation SHALL store optional wearable context fields: `wearable_hrv`, `wearable_strain`, `wearable_sleep_score`, and `wearable_last_sync`.
4. WHEN a practitioner queries a client profile, THE Backend_Foundation SHALL return the full profile including recovery signals, goals, activity context, and latest wearable data.

### Requirement 9: Device Registry Management

**User Story:** As a clinic admin, I want to register, update, and manage HydraWav3Pro devices in my clinic, so that practitioners can select available devices for sessions.

#### Acceptance Criteria

1. THE Device_Registry SHALL store each device with: `device_mac` (MAC address string), `label` (human-readable name), `room` (optional room identifier), `assigned_practitioner` (optional user reference), and `status` (lifecycle state).
2. THE Device_Registry SHALL enforce a unique constraint on `(clinic_id, device_mac)` to prevent duplicate device registrations within a clinic.
3. WHEN an admin creates a new device, THE Device_Registry SHALL set the initial status to `idle`.
4. WHEN a practitioner queries the Device_Registry, THE Device_Registry SHALL return all devices in the practitioner's clinic with their current status.
5. THE Device_Registry SHALL enforce that `status` values are limited to: `idle`, `in_session`, `paused`, `maintenance`, and `offline`.

### Requirement 10: Device Lifecycle State Machine

**User Story:** As a system, I want device status to accurately reflect the device's current state through a defined state machine, so that practitioners always see correct availability.

#### Acceptance Criteria

1. WHEN a Start command (playCmd 1) is sent successfully, THE Device_Registry SHALL transition the device status from `idle` to `in_session`.
2. WHEN a Pause command (playCmd 2) is sent successfully, THE Device_Registry SHALL transition the device status from `in_session` to `paused`.
3. WHEN a Resume command (playCmd 4) is sent successfully, THE Device_Registry SHALL transition the device status from `paused` to `in_session`.
4. WHEN a Stop command (playCmd 3) is sent successfully, THE Device_Registry SHALL transition the device status from `in_session` or `paused` to `idle`.
5. WHEN an admin sets a device to maintenance mode, THE Device_Registry SHALL transition the device status to `maintenance` from any prior state.
6. IF a command targets a device whose current status does not permit that transition, THEN THE MQTT_Proxy SHALL reject the command with a descriptive error.

### Requirement 11: Hydrawav3 API Authentication Proxy

**User Story:** As a backend system, I want to authenticate with the Hydrawav3 API and securely store tokens, so that the MQTT proxy can publish commands on behalf of the clinic.

#### Acceptance Criteria

1. THE MQTT_Proxy SHALL authenticate with the Hydrawav3 API by sending a POST request to `/api/v1/auth/login` with username, password, and `rememberMe: true`.
2. WHEN authentication succeeds, THE MQTT_Proxy SHALL store the `JWT_ACCESS_TOKEN` and `JWT_REFRESH_TOKEN` in the `clinic_hw_tokens` table, scoped to the clinic.
3. IF authentication with the Hydrawav3 API fails, THEN THE MQTT_Proxy SHALL return HTTP 401 with a descriptive error message to the caller.
4. WHEN making MQTT publish requests, THE MQTT_Proxy SHALL include the stored access token in the `Authorization` header.

### Requirement 12: MQTT Command Publishing

**User Story:** As a practitioner, I want to send Start, Pause, Resume, and Stop commands to a specific HydraWav3Pro device, so that I can control recovery sessions from the HydraScan interface.

#### Acceptance Criteria

1. THE MQTT_Proxy SHALL publish commands to the Hydrawav3 API endpoint `POST /api/v1/mqtt/publish` with the topic always set to `"HydraWav3Pro/config"`.
2. THE MQTT_Proxy SHALL always send the payload as a stringified JSON string, not as a raw JSON object.
3. WHEN a Start command is requested, THE MQTT_Proxy SHALL include the full SessionConfig payload with the target device's MAC address and `playCmd: 1`.
4. WHEN a Pause command is requested, THE MQTT_Proxy SHALL send a payload containing only the target device's MAC address and `playCmd: 2`.
5. WHEN a Stop command is requested, THE MQTT_Proxy SHALL send a payload containing only the target device's MAC address and `playCmd: 3`.
6. WHEN a Resume command is requested, THE MQTT_Proxy SHALL send a payload containing only the target device's MAC address and `playCmd: 4`.
7. THE MQTT_Proxy SHALL target a specific device by including the device's MAC address in the `mac` field of every payload.

### Requirement 13: SessionConfig Type Definition and Validation

**User Story:** As a developer, I want a strongly-typed SessionConfig interface with safe envelope validation, so that only valid and safe configurations are sent to the device.

#### Acceptance Criteria

1. THE Shared_Types_Package SHALL define a `SessionConfig` TypeScript interface matching the Hydrawav3 MQTT payload schema, including fields: `mac`, `sessionCount`, `sessionPause`, `sDelay`, `cycle1`, `cycle5`, `edgeCycleDuration`, `cycleRepetitions`, `cycleDurations`, `cyclePauses`, `pauseIntervals`, `leftFuncs`, `rightFuncs`, `pwmValues`, `playCmd`, `led`, `hotDrop`, `coldDrop`, `vibMin`, `vibMax`, and `totalDuration`.
2. THE Safe_Envelope SHALL define min/max ranges for: `pwmValues.hot` (30-150), `pwmValues.cold` (100-255), `vibMin` (10-50), `vibMax` (100-255), `hotDrop` (1-10), `coldDrop` (1-10), and `edgeCycleDuration` (5-15).
3. WHEN a SessionConfig is submitted for publishing, THE Safe_Envelope SHALL validate every numeric parameter against its defined range before the MQTT_Proxy sends the command.
4. IF any SessionConfig parameter falls outside the Safe_Envelope range, THEN THE Safe_Envelope SHALL reject the configuration and return a list of all violations with the parameter name, actual value, and allowed range.
5. THE Safe_Envelope SHALL support region-specific overrides (e.g., `neck` has a tighter `pwmHotMax` of 100, `lower_back` has `pwmHotMax` of 120) that take precedence over default ranges.

### Requirement 14: MQTT Command Audit Logging

**User Story:** As a clinic admin, I want every MQTT command logged for audit purposes, so that I can review device command history and troubleshoot issues.

#### Acceptance Criteria

1. WHEN any MQTT command is sent (Start, Pause, Resume, or Stop), THE MQTT_Proxy SHALL insert a record into the `mqtt_command_log` table with: `clinic_id`, `device_id`, `command` type, full `payload`, MQTT API response status, and timestamp.
2. WHEN the system is running in simulation mode, THE MQTT_Proxy SHALL log the command with a `simulated: true` flag.
3. IF the MQTT API returns an error response, THEN THE MQTT_Proxy SHALL log the error details alongside the command record.

### Requirement 15: Simulated Device Mode

**User Story:** As a developer, I want the MQTT proxy to work in simulation mode when no Hydrawav3 API credentials are available, so that development and testing can proceed without real hardware.

#### Acceptance Criteria

1. WHEN the `HYDRAWAV_API_BASE_URL` environment variable is not set or is set to `"simulation"`, THE MQTT_Proxy SHALL operate in simulation mode.
2. WHILE in simulation mode, THE MQTT_Proxy SHALL process commands identically to live mode (validate safe envelope, update device status, log commands) but skip the actual HTTP call to the Hydrawav3 API.
3. WHILE in simulation mode, THE MQTT_Proxy SHALL return a success response with a `simulated: true` flag so that consuming clients can display a simulation badge.
4. WHEN switching from simulation mode to live mode, THE MQTT_Proxy SHALL require only a change to the `HYDRAWAV_API_BASE_URL` environment variable with no code changes.

### Requirement 16: API Endpoints for Auth and User Management

**User Story:** As a frontend developer, I want well-defined API endpoints for authentication, user management, and profile operations, so that the iOS and web apps can integrate with the backend.

#### Acceptance Criteria

1. THE Backend_Foundation SHALL expose an Edge_Function endpoint for Hydrawav3 API authentication that accepts username and password and stores the resulting tokens.
2. THE Backend_Foundation SHALL expose Supabase client library access for user registration, login, and session management using the standard Supabase Auth API.
3. THE Backend_Foundation SHALL expose Edge_Function endpoints or direct Supabase table access for CRUD operations on client profiles, scoped by RLS policies.
4. THE Backend_Foundation SHALL expose an Edge_Function endpoint for the MQTT proxy that accepts a command type, device ID, and optional SessionConfig, and returns the command result.

### Requirement 17: Wellness Language Compliance

**User Story:** As a system, I want all API responses and stored text to use wellness-appropriate language, so that HydraScan complies with Hydrawav3 brand guidelines and avoids medical/clinical terminology.

#### Acceptance Criteria

1. THE Shared_Types_Package SHALL export a `FORBIDDEN_TERMS` list and a `PREFERRED_REPLACEMENTS` mapping for wellness language validation.
2. THE Shared_Types_Package SHALL export a `validateWellnessLanguage` function that checks a text string against forbidden terms and returns violations with suggested replacements.
3. THE Backend_Foundation SHALL use the term "client" instead of "patient" in all database column names, API responses, and documentation.
