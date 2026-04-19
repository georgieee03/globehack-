# HydraScan

**HydraScan is a native iOS recovery companion for the Hydrawav ecosystem.**

It helps a client move from **guided intake and live movement capture** to a structured **recovery summary**, a continuity-aware **recovery score**, and an auto-surfaced **recovery plan** built from a curated, safety-reviewed exercise video catalog.

This repo now reflects a real product workflow rather than a demo shell:
- live QuickPose-based onboarding capture
- real Supabase-backed auth and persistence
- structured assessment and recovery intelligence
- daily check-ins and post-session outcomes
- a redesigned dark-first Hydrawav3-matched UI system
- a new recovery-plan subsystem with instructional videos and completion logging

## Why We Built It

Hydrawav sessions can be fast and effective, but the software experience around recovery is often fragmented. People may know they feel tight, sore, or limited, but they usually do not get a clear bridge from:
- what they reported
- what their movement scan showed
- what changed over time
- what they should do next

HydraScan was built to close that gap.

The goal was to create an experience that feels:
- clinically grounded
- visually premium
- fast enough for real-world use
- useful before, during, and after a recovery session

## What The Product Does Today

### 1. Client authentication and onboarding
HydraScan supports a real client app flow with Supabase-backed authentication, onboarding, clinic association, and session restore.

The app keeps a typed client session context with:
- auth user identity
- app user identity
- clinic identity
- role
- `client_profiles.id`

### 2. Guided 7-step onboarding scan
The client completes a fixed onboarding capture flow powered by QuickPose. The intake scan now runs as a true seven-step sequence:
- Standing Front
- Standing Side
- Shoulder Flexion
- Squat
- Hip Hinge
- Right Single-Leg Balance
- Left Single-Leg Balance

The app captures live camera input, overlays real joint tracking, computes step-level metrics, and persists structured scan output instead of flattening everything into a single summary blob too early.

### 3. Recovery summary and continuity
After capture, HydraScan builds a session report with:
- range of motion
- asymmetry
- movement quality
- pose-by-pose findings
- recovery-map context

The app also supports:
- daily check-ins
- post-session feedback
- recovery score rendering
- session-awareness from the backend
- before/after continuity views

### 4. Auto-surfaced recovery plans
HydraScan now includes a recovery-plan subsystem that turns:
- primary body regions
- recovery signals
- goals
- activity context
- latest assessment findings
- recovery-map highlights

into a patient-facing plan built from a curated, reviewed video catalog.

The current implementation supports:
- versioned recovery plans
- ordered plan items
- required and optional items
- video metadata and delivery links
- manual completion logging
- started / completed / skipped / stopped states
- safety pausing for red-flag responses

### 5. Premium mobile UI
The client app was fully redesigned to match the Hydrawav3 visual language:
- dark-first shell
- warm ivory secondary surfaces
- editorial serif + clean sans typography
- premium cards, capsules, telemetry modules, and branded launch treatment
- integrated HydraScan logo asset across the app

## Highlights

- **Live movement capture** with QuickPose camera overlays on device
- **Structured step-level assessments** instead of a shallow aggregate-only scan
- **Recovery intelligence backend** built on typed shared contracts
- **Curated recovery plans** with instructional exercise videos
- **Manual adherence logging** separated cleanly from Hydrawav treatment sessions
- **Client-first mobile experience** with a cohesive submission-ready UI

## Submission Story

### Inspiration
We were inspired by the gap between “I scanned my movement” and “I know what to do next.”

Most recovery tools either stop at data capture or jump straight into generic content. We wanted HydraScan to feel like a real recovery companion: capture live movement, interpret it clearly, and translate it into the next best action in a way that feels supportive, premium, and grounded in real client context.

### How we built it
HydraScan is built as a multi-part system:
- a native SwiftUI iOS app in `HydraScan/`
- shared TypeScript contracts in `shared/`
- Supabase migrations and Edge Functions in `backend/`
- a workspace structure managed with `pnpm` and Turbo

The iOS app uses QuickPose for live capture and Supabase for auth, data access, edge functions, and realtime updates. The backend owns the business logic for recovery intelligence, outcomes, check-ins, and now recovery-plan generation.

### What we learned
The biggest technical lesson was that **step-level scan data matters**.

We originally had a system that could save scan results, but not all onboarding steps were being used with the level of detail HydraScan needed. We learned that if pose data is flattened too early, you lose the ability to reason clearly about posture, hinge quality, squat mechanics, and left/right balance separately.

We also learned how much product quality depends on:
- honest completeness states
- careful client/backend contracts
- robust mobile runtime behavior
- strong design consistency

### Challenges we faced
- Migrating from a demo shell to a real client app without breaking working flows
- Moving QuickPose from a debug verification surface into the main capture experience
- Diagnosing and fixing repeated post-scan result crashes on device
- Preserving rich onboarding scan payloads while keeping result rendering stable
- Repairing Supabase migration history drift during live deployment
- Designing a recovery-plan feature that uses reviewed content and respects safety constraints

## UI / UX Overhaul

One of the major upgrades in this repo is the complete UI redesign.

The app now uses a branded design system built around:
- a dark Hydrawav3-inspired shell
- subtle gradient depth
- premium cards and metric modules
- consistent branded CTA styles
- branded launch screen
- integrated HydraScan PNG logo treatment

This redesign was not just cosmetic. It also improved:
- hierarchy across scan results
- intake clarity
- body-map usability
- recovery-plan readability
- trust and polish for a submission/demo setting

## Architecture

### iOS app
Located in `HydraScan/`

Key areas:
- `App/` — app shell and navigation
- `Design/` — theme, tokens, reusable branded UI components
- `Models/` — typed Swift models for users, assessments, recovery plans, outcomes, scores
- `Services/` — Supabase access, auth, cache, QuickPose helpers
- `ViewModels/` — app flow and state management
- `Views/` — auth, capture, check-in, results, profile, recovery plan
- `Computation/` — posture, asymmetry, squat, hinge, balance, and scan assembly logic

### Shared contracts
Located in `shared/`

This package provides shared TypeScript types for:
- users
- client profiles
- assessments
- QuickPose payloads
- recovery maps and scores
- sessions
- outcomes
- recovery plans

### Supabase backend
Located in `backend/`

Important function areas:
- `recovery-intelligence/` — recovery map, score, graph, rules, scan contract parsing
- `recovery-plan-service/` — plan generation, fetch, history, completion logging
- `checkin-recorder/` — check-in persistence and continuity updates
- `outcome-recorder/` — outcome submission and post-session processing
- `claim-clinic-invite/` — onboarding / clinic-claim flow
- `hydrawav-mqtt/` and `hydrawav-auth/` — ecosystem integration scaffolding for Hydrawav device workflows

## Repo structure

```text
HydraScan/   Native iOS client app
backend/     Supabase migrations and Edge Functions
shared/      Shared TypeScript types and constants
dashboard/   Dashboard workspace scaffold / future admin surface
docs/        Supporting docs
scripts/     Utility scripts
```

## Core Features

### Live capture and analysis
- QuickPose-based live camera capture
- seven-step onboarding scan
- step-level posture, hinge, squat, and balance outputs
- aggregate ROM, asymmetry, movement quality, and gait-style metrics

### Recovery intelligence
- recovery-map generation
- recovery-score generation
- continuity graph support
- typed scan contract between iOS and backend

### Client continuity features
- daily check-ins
- post-session feedback
- real session awareness from backend state
- assessment history and summary reporting

### Recovery plan system
- reviewed video catalog
- recommendation rules by region / symptom / goal / trigger
- versioned plans
- required and optional items
- item-level logging and safety pause behavior

## Tech Stack

### iOS
- SwiftUI
- Combine
- QuickPoseCore
- QuickPoseMP-full
- QuickPoseSwiftUI
- AVFoundation
- Supabase Swift

### Backend / shared
- TypeScript
- Supabase Edge Functions
- Supabase Postgres + RLS
- shared type package for cross-surface contracts
- pnpm workspaces
- Turbo

## Local Development

### Prerequisites
- Xcode 17+
- iOS 17 simulator or physical iPhone for QuickPose testing
- Node.js + `pnpm`
- Supabase CLI
- QuickPose SDK key
- Supabase project credentials

### Install workspace dependencies

```bash
pnpm install
```

### Useful workspace commands

```bash
pnpm build
pnpm typecheck
pnpm test
```

### iOS configuration

The iOS app reads local secrets from:

`HydraScan/HydraScan/Config/LocalSecrets.xcconfig`

Example:

```xcconfig
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
QUICKPOSE_SDK_KEY = your-quickpose-sdk-key

HYDRASCAN_ENABLE_DEMO_QA_BUTTON = NO
DEV_QA_EMAIL =
DEV_QA_PASSWORD =
```

Then open the Xcode project:

```text
HydraScan/HydraScan.xcodeproj
```

and run the `HydraScan` scheme.

### Backend local workflows

From `backend/`:

```bash
npx supabase start
npx supabase functions serve
npx supabase db reset
```

### Deployment notes

This repo currently relies on Supabase migrations plus Edge Function deployment.

Recent feature work added:
- recovery-plan catalog schema
- recommendation rules
- recovery-plan service
- richer onboarding scan contract

Deployment typically involves:
- pushing migrations
- deploying updated functions
- verifying remote migration history is in sync

## What Is In Scope Right Now

HydraScan is currently strongest as a **client-facing iOS app plus recovery backend**.

Implemented and demoable:
- client auth and onboarding
- seven-step live scan
- recovery summary
- recovery score / check-ins / outcomes
- recovery plans with video items and completion logging
- polished Hydrawav-style mobile UI

Not the primary shipped surface today:
- full practitioner authoring UI
- full admin/catalog management UI
- a production-ready web dashboard experience

The repo contains broader ecosystem hooks and future-facing backend work, but the current submission centers on the native client experience.

## Why This Matters

HydraScan makes recovery software feel more continuous and actionable.

Instead of a disconnected experience, the user can:
1. complete a guided scan
2. see what the scan found
3. understand how they are trending
4. get a curated plan of what to do next
5. log completion and build continuity over time

That creates a much stronger feedback loop than isolated scan results or isolated exercise links.

## Disclaimer

HydraScan is positioned as a **wellness and recovery support platform**. It is intended to support movement insight, recovery continuity, and guided exercise planning. It is not a diagnostic system and is not a replacement for licensed clinical judgment.
