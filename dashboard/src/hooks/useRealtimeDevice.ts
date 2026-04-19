"use client";
import { useState, useEffect } from "react";
import type { DeviceStatus } from "@/types";
import { useInsforge } from "./useInsforge";

export function useRealtimeDevice(deviceId: string) {
  const insforge = useInsforge();
  const [deviceStatus, setDeviceStatus] = useState<DeviceStatus>("idle");
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());

  useEffect(() => {
    if (!deviceId) return;

    let cancelled = false;

    async function loadDeviceStatus() {
      const { data, error } = await insforge
        .from("devices")
        .select("status")
        .eq("id", deviceId)
        .maybeSingle();

      if (cancelled || error || !data) {
        return;
      }

      setDeviceStatus((data as { status: DeviceStatus }).status);
      setLastUpdated(new Date());
    }

    void loadDeviceStatus();

    // InsForge realtime channel publishing is not wired for device table updates yet,
    // so we poll the current device row to keep the session UI in sync.
    const intervalId = window.setInterval(() => {
      void loadDeviceStatus();
    }, 2000);

    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
    };
  }, [deviceId, insforge]);

  return { deviceStatus, lastUpdated };
}
