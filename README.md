# HydraScan

**A practitioner-first recovery intelligence layer for the Hydrawav3 ecosystem.**

HydraScan captures client movement and recovery signals with QuickPose, converts them into a live **Recovery Graph**, recommends a personalized Hydrawav3 session, launches that session on a real **Hydrawav3Pro** device through the **MQTT Control API**, and tracks outcomes across visits so recovery becomes continuous instead of isolated.

## Overview

Hydrawav3 is built around a fast, hands-off wellness session, but the larger recovery workflow around that session is still fragmented. HydraScan closes that gap with an integrated software layer that helps practitioners understand the body before the session, personalize the protocol during the session, and continue the recovery journey after the visit.

HydraScan is designed for the exact practitioner environments Hydrawav3 serves:
- Physical therapy
- Chiropractic care
- Sports performance and recovery
- Wellness centers and recovery studios

## Core Value

HydraScan turns a 9-minute Hydrawav3 session into a persistent recovery intelligence loop.

Instead of relying on intuition alone, practitioners get a structured, fast, and defensible workflow built around:
- movement capture
- recovery signal mapping
- protocol recommendation
- real device orchestration
- post-session learning and continuity

## What HydraScan Does

### 1. Rapid intake and assessment
Clients sign in, complete a lightweight recovery intake, highlight target body zones, and perform guided movement capture through QuickPose.

HydraScan uses this input to generate a **60-second Recovery Map** that surfaces:
- affected regions
- movement asymmetries
- range-of-motion signals
- recovery goals
- recent context from session history and wearables

### 2. Personalized session recommendation
HydraScan converts assessment data into a practitioner-ready protocol recommendation, including:
- Sun/Moon pad placement guidance
- modality mix
- intensity
- sequence
- duration
- confidence and rationale

### 3. Real Hydrawav3 device control
Approved recommendations are translated into a typed session configuration and sent to a target Hydrawav3Pro unit through the official MQTT publish workflow.

HydraScan supports the full session lifecycle:
- launch
- pause
- resume
- stop
- event logging

### 4. Outcomes and continuity
After the session, HydraScan captures client and practitioner feedback, records re-test values, updates the Recovery Graph, and improves the next recommendation.

This creates continuity between visits instead of treating each session as an isolated event.

## How It Works

HydraScan is structured around the Hydrawav3 flywheel:

### Know
The client completes intake and guided movement capture. HydraScan fuses QuickPose-derived pose, joint angle, ROM, and asymmetry data with recovery signals, wearables, and profile history to generate a Recovery Map.

### Act
The practitioner reviews the recommendation, adjusts parameters if needed, selects a device, and launches a session on real Hydrawav3 hardware.

### Learn
HydraScan stores session outcomes against the exact configuration that ran, updates progress trends, and strengthens future recommendations over time.

## User Experience

### Client app
The client experience is designed to be fast, clear, and low-friction:
- secure sign-in
- guided intake
- camera-based movement capture
- body-zone highlighting
- post-session feedback
- follow-up recovery prompts
- ongoing progress visibility

### Practitioner console
The practitioner experience is designed for real clinic flow:
- 60-second Recovery Map review
- protocol approval in under two minutes
- device selection and launch
- live session lifecycle controls
- post-session re-test logging
- outcomes and trend views

### Clinic administration
HydraScan also supports clinic-level operations:
- role-based access
- device registry management
- workspace visibility
- outcome trends across clients
- session performance insights

## Platform Fit

HydraScan is not a generic movement app. It is built specifically as a native software layer for Hydrawav3.

It aligns directly with the Hydrawav3 recovery loop:
- **Before the session:** faster understanding of the body
- **During the session:** smarter personalization and device-ready protocol output
- **After the session:** continuity, outcomes tracking, and learning

## Technology

### QuickPose movement layer
HydraScan uses QuickPose as its movement intelligence engine for on-device pose and motion analysis.

QuickPose capabilities used in HydraScan include:
- 33-point full-body pose detection
- range of motion analysis
- joint angle analysis
- raw pose output
- feedback overlays
- on-device processing

### QuickPose frameworks
HydraScan is designed around the QuickPose iOS module stack:
- `QuickPoseCore`
- `QuickPoseMP-full`
- `QuickPoseCamera`
- `QuickPoseSwiftUI`

### Hydrawav3 session layer
HydraScan integrates with the Hydrawav3Pro MQTT Control API for:
- authentication
- session configuration publishing
- device targeting by MAC address
- lifecycle commands

### Application stack
- SwiftUI client experience
- iPad or web-based practitioner console
- multi-tenant backend
- typed recovery and session models
- secure role-based access

## Product Principles

HydraScan is built around a few non-negotiable principles:
- **Practitioner-first** — supports the practitioner rather than replacing them
- **Clinic-compatible** — fits real throughput and decision-time constraints
- **Personalized** — adapts to the individual instead of relying on static templates
- **Integrated** — plugs directly into the Hydrawav3 ecosystem
- **Wellness-positioned** — focused on recovery, mobility, and performance support

## Who It Serves

HydraScan is designed for:
- physical therapists
- chiropractors
- sports trainers
- wellness centers
- recovery studios
- medspa and premium recovery environments

## Why It Matters

Hydrawav3 already delivers a differentiated in-clinic session. HydraScan expands that value into a complete recovery workflow.

That means:
- less guesswork before protocol selection
- stronger consistency across sessions
- better visibility into outcomes
- more continuity between visits
- a more defensible software layer around the device ecosystem

## Project Statement

HydraScan transforms Hydrawav3 from a powerful session delivery tool into a connected recovery operating layer.

## Disclaimer

HydraScan is positioned as a **wellness and recovery support platform**. It is intended to support practitioner workflows, movement insight, and recovery continuity. It is not a medical diagnosis system and is not designed to replace practitioner judgment.
