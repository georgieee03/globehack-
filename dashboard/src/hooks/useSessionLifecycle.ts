"use client";
import { useState, useEffect, useRef } from "react";
import type { BodyRegion, SessionConfig, SessionStatus } from "@/types";
import { sendMqttCommand } from "@/lib/edge-functions";
import { useRealtimeDevice } from "./useRealtimeDevice";

interface UseSessionLifecycleOptions {
  initialStatus?: SessionStatus;
  sessionConfig?: SessionConfig;
  bodyRegion?: BodyRegion;
  onCompleted?: () => void;
}

export function useSessionLifecycle(
  sessionId: string,
  deviceId: string,
  options: UseSessionLifecycleOptions = {},
) {
  const { deviceStatus } = useRealtimeDevice(deviceId);
  const [sessionStatus, setSessionStatus] = useState<SessionStatus>(
    options.initialStatus ?? "pending",
  );
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [error, setError] = useState<Error | null>(null);
  const [isSimulated, setIsSimulated] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (sessionStatus === "active") {
      timerRef.current = setInterval(() => setElapsedSeconds(s => s + 1), 1000);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [sessionStatus]);

  // Sync with realtime device status
  useEffect(() => {
    if (deviceStatus === "idle" && sessionStatus === "active") {
      setSessionStatus("completed");
      options.onCompleted?.();
    }
  }, [deviceStatus, options, sessionStatus]);

  async function sendCommand(command: "start" | "pause" | "resume" | "stop") {
    setError(null);
    try {
      const result = await sendMqttCommand(
        deviceId,
        command,
        command === "start" ? options.sessionConfig : undefined,
        options.bodyRegion,
      );

      if ("success" in result && result.success === false) {
        throw new Error(result.error ?? "Hydrawav3 command failed");
      }

      setIsSimulated("simulated" in result ? result.simulated : false);
      if (command === "start" || command === "resume") setSessionStatus("active");
      else if (command === "pause") setSessionStatus("paused");
      else if (command === "stop") {
        setSessionStatus("completed");
        options.onCompleted?.();
      }
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)));
    }
  }

  function start() {
    return sendCommand("start");
  }

  function pause() {
    return sendCommand("pause");
  }

  function resume() {
    return sendCommand("resume");
  }

  function stop() {
    return sendCommand("stop");
  }

  return {
    sessionId,
    sessionStatus,
    deviceStatus,
    elapsedSeconds,
    start,
    pause,
    resume,
    stop,
    error,
    isSimulated,
    setSessionStatus,
  };
}
