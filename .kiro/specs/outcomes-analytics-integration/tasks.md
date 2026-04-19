# Implementation Plan: Outcomes, Analytics & Integration

## Overview

This plan implements the Post-Session Outcomes & Learning Loop (Phase 7), Analytics, Admin & Clinic Intelligence (Phase 8), and Final Integration, Polish & Demo Prep (Phase 9). The backend consists of Supabase Edge Functions for outcome recording, analytics, and export. The frontend adds analytics, admin, and demo routes to the existing Practitioner Dashboard. All code is TypeScript.

## Tasks

- [x] 1. Database migrations and indexes
  - [x] 1.1 Create analytics views migration
    - Create `backend/supabase/migrations/00014_create_analytics_views.sql` with views: `clinic_metrics_v`, `practitioner_metrics_v`, `device_utilization_v`, `protocol_effectiveness_v`, `client_retention_v`
    - All views include `clinic_id` for RLS filtering
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 10.1, 10.2, 10.3_

  - [x] 1.2 Create performance indexes migration
    - Create `backend/supabase/migrations/00015_create_performance_indexes.sql` with indexes on `outcomes(session_id, recorded_by)`, `recovery_graph(client_id, body_region, recorded_at DESC)`, `sessions(clinic_id, status)`, `sessions(practitioner_id, status)`, plus JSONB indexes for protocol queries
    - _Requirements: 17.2, 17.3_

  - [x] 1.3 Create trend columns migration
    - Create `backend/supabase/migrations/00016_add_trend_columns.sql` adding `trend_classification`, `needs_attention`, and `next_visit_signal` columns to `client_profiles`
    - _Requirements: 6.3, 6.4, 7.5_

- [x] 2. Outcome Recorder Edge Function
  - [x] 2.1 Implement outcome validation and storage
    - Create `backend/supabase/functions/outcome-recorder/index.ts`
    - Accept POST with OutcomeRequest body
    - Validate stiffness_before/after are integers 0-10, soreness_after is integer 0-10, repeat_intent is "yes"/"maybe"/"no"
    - Check for duplicate client outcome on same session (reject with 409)
    - Verify session has non-null session_config
    - Insert outcome record with recorded_by and session_id
    - If rom_after provided, compute rom_delta from pre-session assessment ROM values
    - Return 401 for unauthenticated, 404 for missing session
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 3.1, 3.4_

  - [x] 2.2 Implement Recovery Graph update on outcome
    - After outcome storage, insert recovery_graph points:
      - stiffness_after → metric_type "stiffness", source "session_outcome"
      - soreness_after → metric_type "soreness", source "session_outcome"
      - Each rom_after value → metric_type "rom_{joint_name}", source "session_outcome"
    - Set body_region from session's target region in SessionConfig
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 2.3 Implement Recovery Score recomputation
    - After graph update, call computeRecoveryScore (from Spec 3's recovery-intelligence)
    - Insert new score into recovery_graph with metric_type "recovery_score", body_region "general"
    - Clamp score to 0-100
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 2.4 Implement trend analysis
    - Query last 3 outcomes for the client
    - Compute trend: "improving" (stiffness decreasing >1), "plateau" (change ≤1), "regressing" (stiffness increasing >1), "insufficient_data" (<3 sessions)
    - Store trend_classification on client_profiles
    - Set needs_attention=true on plateau detection
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 2.5 Implement next-visit signal generation
    - Compute next_visit_signal based on Recovery Score + trend:
      - Score <40 + regressing → priority, 1-2 days
      - Score 40-70 + plateau → soon, 3-5 days
      - Score >70 + improving → routine, 7-14 days
    - Store next_visit_signal JSONB on client_profiles
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 2.6 Write property tests for outcome recorder
    - **Property 1: Outcome validation bounds (stiffness/soreness 0-10)**
    - **Property 2: Duplicate client outcome rejection**
    - **Property 3: Recovery Graph point insertion on outcome**
    - **Property 4: Recovery Score clamping (0-100)**
    - **Property 5: Trend classification correctness**
    - **Property 6: Next-visit signal urgency mapping**
    - **Validates: Requirements 1.3, 2.3, 2.4, 4.1, 4.2, 5.3, 6.1, 6.2, 7.2, 7.3, 7.4**

- [ ] 3. Checkpoint — Outcome recording pipeline
  - Verify outcome submission → graph update → score recomputation → trend → signal works end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Outcome-to-SessionConfig linkage (Learning Loop)
  - [x] 4.1 Implement learning loop query functions
    - Create query function to find outcomes by SessionConfig parameters (body region, recovery goal, intensity range)
    - Create query function to return prior session outcomes with associated SessionConfig for a client, ordered by completion date descending
    - Ensure session_id FK on every outcome provides direct join to session_config, recommended_config, and practitioner_edits
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 5. Clinic Analytics Edge Function
  - [x] 5.1 Implement aggregate metrics action
    - Create `backend/supabase/functions/clinic-analytics/index.ts` with action-based routing
    - `aggregate` action: query clinic_metrics_v for total sessions, avg improvement, device utilization, client retention within configurable date range (default 30 days)
    - All queries scoped by authenticated admin's clinic_id via RLS
    - Return within 2 seconds
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 21.1_

  - [x] 5.2 Implement per-practitioner metrics action
    - `practitioner` action: query practitioner_metrics_v for total sessions, avg sessions/day, avg outcome score, client count per practitioner
    - Compute avg outcome score as mean of (stiffness_before - stiffness_after) / 10
    - Anonymize: return first name or initials only, not full identifying info
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 5.3 Implement protocol effectiveness action
    - `protocol` action: query protocol_effectiveness_v correlating SessionConfig params with avg outcome scores
    - Rank top 5 configurations by avg outcome score
    - Break down by body region
    - Mark configs with <5 sessions as "limited data", exclude from ranking
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 5.4 Implement device utilization action
    - `device` action: query device_utilization_v for sessions per device, status distribution, maintenance frequency
    - _Requirements: 8.3_

  - [x] 5.5 Implement ROI calculator action
    - `roi` action: compute total estimated revenue, avg revenue per client, estimated client lifetime value, payback period, conversion rate
    - Accept configurable per_session_revenue (default $15) and monthly_subscription_cost
    - Use wellness-appropriate language in all response text
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ]* 5.6 Write property tests for analytics
    - **Property 7: RLS isolation in analytics**
    - **Property 8: Protocol effectiveness limited data threshold**
    - **Property 9: ROI computation consistency**
    - **Validates: Requirements 10.4, 13.2, 13.4, 21.1**

- [x] 6. Export Service Edge Function
  - [x] 6.1 Implement CSV export
    - Create `backend/supabase/functions/export-service/index.ts`
    - Generate CSV with session summary data, aggregate metrics, protocol effectiveness
    - Scope all data by admin's clinic_id via RLS
    - Anonymize client names (initials or anonymized IDs)
    - Generate within 10 seconds for up to 1000 sessions
    - Upload to Supabase Storage, return signed download URL
    - _Requirements: 12.1, 12.3, 12.4, 12.5_

  - [x] 6.2 Implement PDF export
    - Generate PDF with clinic summary header, aggregate metrics, per-practitioner summary, device utilization
    - Scope by RLS, anonymize client names
    - _Requirements: 12.2, 12.3, 12.4_

  - [ ]* 6.3 Write property test for export scoping
    - **Property 10: Export data scoping (all data belongs to requesting admin's clinic)**
    - **Validates: Requirements 12.3**

- [ ] 7. Checkpoint — Backend analytics and export
  - Verify all analytics actions return correct data scoped by clinic
  - Verify exports generate within time limits
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Admin Panel UI
  - [ ] 8.1 Implement clinic settings page
    - Create `dashboard/src/app/admin/settings/page.tsx`
    - Create `dashboard/src/components/admin/ClinicSettings.tsx` with form for clinic name, address, timezone
    - Gate access to admin role only
    - _Requirements: 11.1, 11.5_

  - [ ] 8.2 Implement user management page
    - Create `dashboard/src/app/admin/users/page.tsx`
    - Create `dashboard/src/components/admin/UserManagement.tsx` with invite practitioner by email, remove practitioner (deactivate), list current users
    - Prevent removal of last admin
    - _Requirements: 11.2, 11.3, 11.5, 11.6_

  - [ ] 8.3 Implement device management page
    - Create `dashboard/src/app/admin/devices/page.tsx`
    - Create `dashboard/src/components/admin/DeviceManagement.tsx` with add device (MAC, label, room), edit device, set status to maintenance/offline
    - _Requirements: 11.4, 11.5_

- [ ] 9. Analytics Dashboard UI
  - [ ] 9.1 Implement aggregate metrics view
    - Create `dashboard/src/app/analytics/page.tsx`
    - Create `dashboard/src/components/analytics/AggregateMetrics.tsx` displaying total sessions, avg Recovery Score improvement, active clients
    - Create `dashboard/src/hooks/useAnalytics.ts` for fetching analytics data
    - Load within 2 seconds
    - _Requirements: 8.1, 8.2, 8.4, 8.5, 17.2_

  - [ ] 9.2 Implement practitioner performance view
    - Create `dashboard/src/components/analytics/PractitionerPerformance.tsx` with per-practitioner metrics table
    - Display first name/initials only for anonymization
    - _Requirements: 9.1, 9.2, 9.4_

  - [ ] 9.3 Implement protocol effectiveness view
    - Create `dashboard/src/components/analytics/ProtocolEffectiveness.tsx` with ranked protocol configs and body region breakdown
    - Mark limited data configs
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [ ] 9.4 Implement device utilization view
    - Create `dashboard/src/components/analytics/DeviceUtilization.tsx` with sessions per device, status distribution
    - _Requirements: 8.3_

  - [ ] 9.5 Implement ROI calculator view
    - Create `dashboard/src/components/analytics/ROICalculator.tsx` with configurable per-session revenue, total revenue, LTV, payback period, conversion rate
    - Create `dashboard/src/hooks/useROI.ts`
    - Use wellness language throughout
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ] 9.6 Implement export UI
    - Add export buttons (CSV/PDF) to analytics page
    - Create `dashboard/src/hooks/useExport.ts` for triggering exports and downloading files
    - Show loading indicator during generation
    - _Requirements: 12.1, 12.2, 16.1_

- [ ] 10. UI Polish and Shared Components
  - [ ] 10.1 Create shared UI components
    - Create `dashboard/src/components/shared/LoadingIndicator.tsx` for all network requests
    - Create `dashboard/src/components/shared/ErrorMessage.tsx` with descriptive error + retry button
    - Create `dashboard/src/components/shared/EmptyState.tsx` with guidance messages for empty views
    - Create `dashboard/src/components/shared/SimulationBadge.tsx` for simulation mode indicator
    - _Requirements: 16.1, 16.2, 16.3, 18.2_

  - [ ] 10.2 Apply consistent styling across all screens
    - Ensure consistent color scheme, typography, spacing across outcome, analytics, and admin screens
    - Ensure all interactive elements have accessible labels and meet WCAG 2.1 AA contrast
    - _Requirements: 16.4, 16.5_

- [x] 11. Demo Data and Demo Flow
  - [x] 11.1 Create demo seed data
    - Create `backend/supabase/seed/demo-personas.sql` with 3 client personas (Alex Rivera improving, Jordan Chen plateau, Sam Patel regressing), each with 3-5 sessions, outcomes, and visible Recovery Score trends
    - _Requirements: 15.2_

  - [ ] 11.2 Implement demo flow Edge Function
    - Create `backend/supabase/functions/demo-flow/index.ts` that orchestrates the full Know → Act → Learn cycle: sign-in → intake → assessment → recommendation → device select → session launch → lifecycle → outcome → graph update → score recomputation
    - Verify Recovery Score changes after outcome (learning loop functional)
    - Verify next recommendation reflects recorded outcome (History Scorer incorporates new data)
    - Work in simulation mode with simulated: true flags
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 18.1, 18.3_

  - [ ] 11.3 Create demo script document
    - Create a demo walkthrough script completable in 3 minutes covering: intake (15s), assessment (15s), Recovery Map (20s), protocol + launch (20s), lifecycle (15s), outcome (20s), graph update (15s), analytics (20s)
    - Include simulation badge display
    - Include prepared answers for judge questions
    - _Requirements: 15.1, 15.3, 15.4_

- [x] 12. Wellness Language Audit
  - [x] 12.1 Create wellness audit script
    - Create `scripts/wellness-audit.ts` that scans all user-facing strings in dashboard components, iOS views, seed data, and LLM prompts against `validateWellnessLanguage`
    - Check for forbidden terms: "diagnos", "treat", "cure", "medical device", "clinical", "prescription", "medication", "drug", "heal", "therapy", "patient"
    - Verify "Hydrawav3" (lowercase w) usage
    - Verify outcome labels use wellness terms
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

- [ ] 13. Simulation Mode Verification
  - [ ] 13.1 Verify full demo flow in simulation mode
    - Run demo flow end-to-end with HYDRAWAV_API_BASE_URL set to "simulation"
    - Verify simulation badges displayed on all hardware-interaction screens
    - Verify mqtt_command_log entries have simulated: true
    - Verify switching to live mode requires only env var change
    - _Requirements: 18.1, 18.2, 18.3, 18.4_

- [ ] 14. Judging Rubric Alignment Verification
  - [ ] 14.1 Verify all judging criteria coverage
    - Practitioner Impact (25pts): Recovery Map <60s, recommendation with rationale, outcome visibility
    - Technical Feasibility (20pts): QuickPose, Supabase RLS, MQTT, safe envelope
    - Platform Integration (20pts): JWT auth, MQTT publish, MAC targeting, lifecycle commands
    - Path to Product (20pts): multi-tenant, RLS, typed schemas, learning loop
    - User Experience (15pts): <60s intake, guided capture, clean dashboard, Recovery Score
    - Loop Coverage bonus (+10): Know + Act + Learn all demonstrated
    - Live Data Demo bonus (+5): MQTT session launch (real or simulated)
    - Business Model bonus (+3): pricing, ROI, retention in analytics
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7, 20.8_

- [ ] 15. Final checkpoint — Full integration
  - Verify all 21 requirements are covered
  - Verify end-to-end demo flow works in simulation mode
  - Verify wellness language audit passes
  - Verify analytics load within 2 seconds
  - Verify outcome recording completes within 3 seconds
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breaks
- Property tests validate correctness properties from the design document
- The backend Edge Functions should be implemented first so the dashboard can consume real endpoints
- All code is TypeScript: Deno for Edge Functions, React/Next.js for dashboard
- This spec depends on all three prior specs being functional
