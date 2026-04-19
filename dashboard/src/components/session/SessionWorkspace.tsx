"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import type {
  AssessmentRecord,
  BodyRegion,
  ClientProfileRecord,
  DeviceRecord,
  RecoveryMap,
  SessionConfig,
  SessionRecord,
  SessionStatus,
  SafeEnvelopeViolation,
} from "@hydrascan/shared";
import { validateSafeEnvelope } from "@hydrascan/shared";
import { useInsforge } from "@/hooks/useInsforge";
import { useRealtimeDevice } from "@/hooks/useRealtimeDevice";
import { recommend, sendMqttCommand } from "@/lib/edge-functions";
import { formatBodyRegion, formatConfidence, formatRecoveryScore } from "@/lib/formatters";
import { DeviceList } from "@/components/device/DeviceList";
import { SessionStatusDisplay } from "./SessionStatusDisplay";
import { ElapsedTimer } from "./ElapsedTimer";
import { SimulationBadge } from "./SimulationBadge";
import { LifecycleControls } from "./LifecycleControls";

interface RecommendationPayload {
  sessionConfig: SessionConfig;
  recoveryMap: RecoveryMap;
  recoveryScore: number;
  confidence: number;
  explanation: string;
  adjustments: string[];
}

interface SessionWorkspaceProps {
  clientId: string;
}

function isSessionStatus(value: unknown): value is SessionStatus {
  return value === "pending" || value === "active" || value === "paused" || value === "completed" || value === "cancelled" || value === "error";
}

function summaryFromConfig(sessionConfig: SessionConfig | null) {
  if (!sessionConfig) return "No session configuration is loaded yet.";

  return [
    `${sessionConfig.edgeCycleDuration}-minute cycles`,
    `hot PWM ${sessionConfig.pwmValues.hot.join(" / ")}`,
    `cold PWM ${sessionConfig.pwmValues.cold.join(" / ")}`,
    `${sessionConfig.vibMin}-${sessionConfig.vibMax} vibration`,
    sessionConfig.led === 1 ? "LED on" : "LED off",
  ].join(" | ");
}

function formatTimestamp(timestamp: Date | string | null) {
  if (!timestamp) return null;
  const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleString();
}

export function SessionWorkspace({ clientId }: SessionWorkspaceProps) {
  const insforge = useInsforge();
  const router = useRouter();
  const searchParams = useSearchParams();
  const activeSessionId = searchParams.get("sessionId");
  const isRetestMode = searchParams.get("mode") === "retest";

  const [clientProfile, setClientProfile] = useState<ClientProfileRecord | null>(null);
  const [latestAssessment, setLatestAssessment] = useState<AssessmentRecord | null>(null);
  const [recommendation, setRecommendation] = useState<RecommendationPayload | null>(null);
  const [devices, setDevices] = useState<DeviceRecord[]>([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string | null>(null);
  const [activeSession, setActiveSession] = useState<SessionRecord | null>(null);
  const [loading, setLoading] = useState(true);
  const [launching, setLaunching] = useState(false);
  const [workingCommand, setWorkingCommand] = useState<"pause" | "resume" | "stop" | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [validationViolations, setValidationViolations] = useState<SafeEnvelopeViolation[]>([]);
  const [simulation, setSimulation] = useState(false);
  const previousDeviceStatus = useRef<string | null>(null);

  const showLiveControls = activeSession?.status === "active" || activeSession?.status === "paused";
  const currentSessionForControls = showLiveControls ? activeSession : null;
  const currentDeviceId = currentSessionForControls?.device_id ?? selectedDeviceId ?? "";
  const { deviceStatus, lastUpdated } = useRealtimeDevice(currentDeviceId);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      setErrorMessage(null);

      const [{ data: profile, error: profileError }, { data: assessment, error: assessmentError }] = await Promise.all([
        insforge.from("client_profiles").select("*").eq("id", clientId).maybeSingle(),
        insforge.from("assessments").select("*").eq("client_id", clientId).order("created_at", { ascending: false }).limit(1).maybeSingle(),
      ]);

      if (cancelled) return;

      if (profileError) {
        setErrorMessage(profileError.message);
        setLoading(false);
        return;
      }

      if (assessmentError) {
        setErrorMessage(assessmentError.message);
        setLoading(false);
        return;
      }

      setClientProfile(profile as ClientProfileRecord | null);
      setLatestAssessment(assessment as AssessmentRecord | null);

      const clinicId = (profile as ClientProfileRecord | null)?.clinic_id;

      if (clinicId) {
        const { data: deviceRows, error: deviceError } = await insforge
          .from("devices")
          .select("*")
          .eq("clinic_id", clinicId)
          .order("label", { ascending: true });

        if (!cancelled) {
          if (deviceError) {
            setErrorMessage(deviceError.message);
          } else {
            setDevices((deviceRows ?? []) as DeviceRecord[]);
          }
        }
      }

      if (assessment) {
        const result = (await recommend(clientId, assessment.id)) as { data?: RecommendationPayload };
        if (!cancelled) {
          setRecommendation(result.data ?? null);
        }
      }

      if (activeSessionId) {
        const { data: sessionRow, error: sessionError } = await insforge.from("sessions").select("*").eq("id", activeSessionId).maybeSingle();
        if (!cancelled) {
          if (sessionError) {
            setErrorMessage(sessionError.message);
          } else {
            setActiveSession(sessionRow as SessionRecord | null);
          }
        }
      } else {
        const { data: sessionRow, error: sessionError } = await insforge
          .from("sessions")
          .select("*")
          .eq("client_id", clientId)
          .in("status", ["active", "paused"])
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (!cancelled) {
          if (sessionError) {
            setErrorMessage(sessionError.message);
          } else {
            setActiveSession(sessionRow as SessionRecord | null);
          }
        }
      }

      if (!cancelled) {
        setLoading(false);
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, [activeSessionId, clientId, isRetestMode, insforge]);

  useEffect(() => {
    if (!devices.length) return;
    if (selectedDeviceId) return;
    const firstIdle = devices.find((device) => device.status === "idle");
    if (firstIdle) {
      setSelectedDeviceId(firstIdle.id);
    }
  }, [devices, selectedDeviceId]);

  useEffect(() => {
    if (!currentDeviceId) return;

    const previousStatus = previousDeviceStatus.current;
    const liveSession = currentSessionForControls;
    if (liveSession?.status === "active" && previousStatus && previousStatus !== "idle" && deviceStatus === "idle") {
      void (async () => {
        await insforge
          .from("sessions")
          .update({ status: "completed", completed_at: new Date().toISOString() })
          .eq("id", liveSession.id);

        await insforge
          .from("devices")
          .update({ status: "idle" })
          .eq("id", liveSession.device_id);

        router.replace(`/clients/${clientId}/post-session?sessionId=${liveSession.id}`);
      })();
    }

    previousDeviceStatus.current = deviceStatus;
  }, [clientId, currentDeviceId, currentSessionForControls, deviceStatus, router, insforge]);

  async function launchSession() {
    setLaunching(true);
    setErrorMessage(null);
    setValidationViolations([]);

    try {
      if (!recommendation || !latestAssessment || !clientProfile) {
        throw new Error("Load the recommendation before launching the session.");
      }

      const selectedDevice = devices.find((device) => device.id === selectedDeviceId);
      if (!selectedDevice) {
        throw new Error("Select an idle Hydrawav3 device.");
      }
      if (selectedDevice.status !== "idle") {
        throw new Error("Only idle devices can be selected.");
      }

      const region = recommendation.recoveryMap?.highlightedRegions?.[0]?.region as BodyRegion | undefined;
      const sessionConfig: SessionConfig = {
        ...recommendation.sessionConfig,
        mac: selectedDevice.device_mac,
        playCmd: 1,
      };

      const validation = validateSafeEnvelope(sessionConfig, region);
      if (!validation.valid) {
        setValidationViolations(validation.violations);
        throw new Error("The recommended configuration needs attention before launch.");
      }

      const mqttResponse = (await sendMqttCommand(selectedDevice.id, "start", sessionConfig, region)) as {
        success?: boolean;
        simulated?: boolean;
        error?: string;
      };

      if (mqttResponse?.error || mqttResponse?.success === false) {
        throw new Error(mqttResponse.error ?? "Hydrawav3 rejected the launch request.");
      }

      setSimulation(Boolean(mqttResponse?.simulated));

      const { data: userResult } = await insforge.auth.getUser();
      const practitionerId = userResult.user?.id ?? "";

      const { data: insertedSession, error: insertError } = await insforge
        .from("sessions")
        .insert({
          client_id: clientId,
          clinic_id: clientProfile.clinic_id,
          practitioner_id: practitionerId,
          device_id: selectedDevice.id,
          assessment_id: latestAssessment.id,
          session_config: sessionConfig,
          recommended_config: recommendation.sessionConfig,
          practitioner_edits: null,
          recommendation_rationale: recommendation.explanation,
          confidence_score: recommendation.confidence,
          status: "active",
          started_at: new Date().toISOString(),
        })
        .select("*")
        .single();

      if (insertError) {
        throw new Error(insertError.message);
      }

      setActiveSession(insertedSession as SessionRecord);
      setSelectedDeviceId(selectedDevice.id);
      router.replace(`/clients/${clientId}/session?sessionId=${(insertedSession as SessionRecord).id}`);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Unable to launch the session.");
    } finally {
      setLaunching(false);
    }
  }

  async function updateSessionAndDevice(
    nextStatus: "paused" | "active" | "completed",
    deviceNextStatus: DeviceRecord["status"],
    command: "pause" | "resume" | "stop",
  ) {
    const session = currentSessionForControls;
    if (!session) return;
    setWorkingCommand(command);
    setErrorMessage(null);

    try {
      const region = recommendation?.recoveryMap?.highlightedRegions?.[0]?.region as BodyRegion | undefined;
      const currentSessionConfig = session.session_config as unknown as SessionConfig;
      const response = (await sendMqttCommand(session.device_id, command, currentSessionConfig, region)) as {
        success?: boolean;
        simulated?: boolean;
        error?: string;
      };

      if (response?.error || response?.success === false) {
        throw new Error(response.error ?? "Hydrawav3 did not accept the command.");
      }

      setSimulation(Boolean(response?.simulated));

      const payload: Record<string, unknown> = { status: nextStatus };
      if (nextStatus === "completed") {
        payload.completed_at = new Date().toISOString();
      }

      await insforge.from("sessions").update(payload).eq("id", session.id);
      await insforge.from("devices").update({ status: deviceNextStatus }).eq("id", session.device_id);

      setActiveSession((current) => (current ? { ...current, status: nextStatus, completed_at: nextStatus === "completed" ? new Date().toISOString() : current.completed_at } : current));

      if (nextStatus === "completed") {
        router.push(`/clients/${clientId}/post-session?sessionId=${session.id}`);
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "The Hydrawav3 command failed.");
    } finally {
      setWorkingCommand(null);
    }
  }

  const deviceLabel = currentSessionForControls
    ? devices.find((device) => device.id === currentSessionForControls.device_id)?.label ?? "Selected Hydrawav3"
    : selectedDeviceId
      ? devices.find((device) => device.id === selectedDeviceId)?.label ?? "Selected Hydrawav3"
      : "";

  const recommendationSummary = summaryFromConfig(recommendation?.sessionConfig ?? null);
  const primaryRegion = recommendation?.recoveryMap?.highlightedRegions?.[0]?.region;

  if (loading) {
    return (
      <div className="space-y-4">
        <div className="h-24 animate-pulse rounded-3xl bg-slate-100" />
        <div className="h-48 animate-pulse rounded-3xl bg-slate-100" />
        <div className="h-80 animate-pulse rounded-3xl bg-slate-100" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="rounded-[2rem] border border-slate-200 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800 p-6 text-white shadow-xl">
        <p className="text-xs uppercase tracking-[0.28em] text-slate-300">Hydrawav3 session workflow</p>
        <h1 className="mt-3 text-3xl font-semibold">Client session control</h1>
        <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-300">
          {isRetestMode
            ? "QuickPose re-test mode is ready for the primary regions from the completed session."
            : "Review the recommended protocol, choose an idle Hydrawav3 device, and launch the session in a few steps."}
        </p>
      </div>

      {errorMessage ? (
        <div className="rounded-3xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">
          {errorMessage}
        </div>
      ) : null}

      {validationViolations.length > 0 ? (
        <div className="rounded-3xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
          <p className="font-semibold">Safe envelope review</p>
          <ul className="mt-3 space-y-2">
            {validationViolations.map((violation) => (
              <li key={violation.parameter} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl bg-white px-3 py-2">
                <span className="font-medium">{violation.parameter}</span>
                <span>{violation.actual} is outside the allowed range {violation.min} to {violation.max}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <SessionStatusDisplay
        status={isSessionStatus(currentSessionForControls?.status) ? currentSessionForControls.status : "pending"}
        deviceLabel={deviceLabel}
        lastUpdated={formatTimestamp(lastUpdated)}
        isRetestMode={isRetestMode}
        elapsedDisplay={<ElapsedTimer startedAt={currentSessionForControls?.started_at ?? null} status={isSessionStatus(currentSessionForControls?.status) ? currentSessionForControls.status : "pending"} />}
      />

      <div className="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-4">
          <section className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="text-lg font-semibold text-slate-950">Recommendation summary</h2>
                <p className="mt-1 text-sm text-slate-600">
                  Confidence {recommendation ? formatConfidence(recommendation.confidence) : "n/a"} | Recovery score {recommendation ? formatRecoveryScore(recommendation.recoveryScore) : "n/a"}
                </p>
              </div>
              <SimulationBadge isSimulation={simulation} />
            </div>

            <p className="mt-4 text-sm leading-6 text-slate-700">
              {recommendation?.explanation ?? "No recommendation has been generated yet."}
            </p>
            <p className="mt-3 text-sm text-slate-600">{recommendationSummary}</p>

            <div className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
              <div className="rounded-2xl bg-slate-50 p-4">
                <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Primary region</p>
                <p className="mt-1 font-semibold text-slate-950">{primaryRegion ? formatBodyRegion(primaryRegion) : "Not available"}</p>
              </div>
              <div className="rounded-2xl bg-slate-50 p-4">
                <p className="text-xs uppercase tracking-[0.18em] text-slate-500">History adjustments</p>
                <p className="mt-1 font-semibold text-slate-950">{recommendation?.adjustments?.length ? recommendation.adjustments.length : 0} applied</p>
              </div>
            </div>
          </section>

          {!showLiveControls ? (
            <section className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-lg font-semibold text-slate-950">Idle Hydrawav3 devices</h2>
                  <p className="mt-1 text-sm text-slate-600">Only idle devices can be selected for launch.</p>
                </div>
                <p className="text-sm text-slate-500">{devices.filter((device) => device.status === "idle").length} available</p>
              </div>

              <div className="mt-4">
                <DeviceList
                  devices={devices}
                  selectedDeviceId={selectedDeviceId}
                  onSelectDevice={(device) => setSelectedDeviceId(device.id)}
                />
              </div>

              <div className="mt-5 flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => void launchSession()}
                  disabled={launching || !recommendation || !selectedDeviceId}
                  className="rounded-full bg-slate-950 px-5 py-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {launching ? "Launching..." : "Launch Hydrawav3 session"}
                </button>
                <p className="text-sm text-slate-500">No more than three steps from selection to start.</p>
              </div>
            </section>
          ) : null}
        </div>

        <aside className="space-y-4">
          <div className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
            <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Client</p>
            <h3 className="mt-2 text-xl font-semibold text-slate-950">{clientProfile?.notes ? "Practitioner context loaded" : "Client context"}</h3>
            <p className="mt-2 text-sm text-slate-600">
              {isRetestMode
                ? "The re-test will focus on the session's primary body regions."
                : "Assessment, recovery map, and configuration data are ready for the review workflow."}
            </p>
          </div>

          {currentSessionForControls ? (
            <LifecycleControls
              status={isSessionStatus(currentSessionForControls.status) ? currentSessionForControls.status : "pending"}
              isWorking={workingCommand !== null}
              errorMessage={errorMessage}
              onPause={() => void updateSessionAndDevice("paused", "paused", "pause")}
              onResume={() => void updateSessionAndDevice("active", "in_session", "resume")}
              onStop={() => void updateSessionAndDevice("completed", "idle", "stop")}
            />
          ) : null}

          {isRetestMode ? (
            <div className="rounded-3xl border border-amber-200 bg-amber-50 p-5 text-sm text-amber-900">
              <p className="font-semibold">Re-test capture ready</p>
              <p className="mt-2 leading-6">
                Target regions: {recommendation?.recoveryMap?.highlightedRegions?.length ? recommendation.recoveryMap.highlightedRegions.map((region) => formatBodyRegion(region.region)).join(", ") : "primary regions from the last session"}.
              </p>
            </div>
          ) : null}
        </aside>
      </div>
    </div>
  );
}
