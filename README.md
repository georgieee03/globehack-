# HydraScan Backend Foundation

HydraScan is a practitioner-first recovery intelligence platform for the Hydrawav3 ecosystem. This repository is set up as a Turborepo monorepo so the backend, shared contracts, and downstream app teams can move in parallel without drifting on schema, payload, or auth assumptions.

## Workspace Layout

```text
.
|-- backend/           # Supabase project, SQL migrations, Edge Functions
|-- shared/            # Shared TypeScript contracts and validation utilities
|-- docs/              # Build spec and supporting documents
|-- package.json       # Root workspace + Turbo scripts
|-- turbo.json         # Task graph
`-- tsconfig.json      # Shared TypeScript defaults
```

## Why This Structure

- `shared/` is the source of truth for backend payload shapes such as `SessionConfig`, `BodyRegion`, `DeviceStatus`, and wellness guardrails.
- `backend/` owns the multi-tenant Supabase data layer, Row Level Security policies, onboarding helpers, and Hydrawav3 integration points.
- The iOS app mirrors these backend contracts in Swift, so keeping `shared/` stable is the easiest way to prevent drift between the assessment pipeline and the backend foundation.

## Quick Start

1. Install Node.js 20+ and `pnpm`.
2. Copy `.env.example` to `.env` and fill in the required values.
3. Install workspace dependencies with `pnpm install`.
4. Run `pnpm typecheck` to validate the shared package.
5. Use the Supabase CLI from `backend/` to start local services and apply migrations.

## Environment Variables

The root `.env.example` lists the required backend variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `HYDRAWAV_API_BASE_URL`
- `LLM_API_KEY`

`HYDRAWAV_API_BASE_URL=simulation` enables first-class simulation mode so backend and iOS teams can exercise the full session-control flow before live Hydrawav3 credentials are available.

## Supabase and Auth Notes

- Supabase Auth is the primary identity layer.
- Email magic link is the default sign-in path.
- Apple Sign-In must also be enabled for iOS compatibility.
- Edge Functions read environment configuration through `Deno.env.get()`.

## Team Branch Strategy

Use `main` as the integration branch and keep each spec area isolated on its owner branch until it is ready to merge:

- `allu-dev`: backend foundation, Supabase schema, auth, MQTT proxy
- `kaush-dev`: iOS assessment pipeline and client app
- `sri-dev`: recovery intelligence engine and practitioner dashboard
- `geo-dev`: outcomes analytics, admin metrics, and final integration

Keep cross-cutting contract changes visible:

1. Update `shared/` first when a payload or enum changes.
2. Call out any schema or auth changes in the PR description so iOS and dashboard work can adjust quickly.
3. Preserve wellness language throughout code, docs, responses, and seeded data.

## Integration Notes for iOS

The iOS team depends on the backend foundation for:

- Supabase email magic link and Apple Sign-In support
- `client_profiles` storage for intake, body zones, recovery signals, goals, and wearable context
- `assessments` uploads that store QuickPose results, ROM, asymmetry, movement quality, optional vitals, and generated recovery maps
- `daily_checkins`, `outcomes`, and `recovery_graph` queries for continuity features and recovery score views
- `devices`, `sessions`, and the Hydrawav MQTT proxy for practitioner-controlled session launch and lifecycle updates

If a backend change affects any of those touchpoints, keep the JSON shapes and enum values aligned with the iOS spec before merging.

## Commands

- `pnpm build`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm test`

## Current Foundation Goal

This spec focuses on the production-shaped foundation the rest of the hackathon build depends on:

- multi-tenant clinic isolation
- role-aware access control
- typed Hydrawav session payloads
- safe envelope validation
- simulation-first device control
- audit logging for device commands
