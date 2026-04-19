"use client";
import { useState, useEffect } from "react";
import type { DeviceStatus } from "@/types";
import { useSupabase } from "./useSupabase";

export function useRealtimeDevice(deviceId: string) {
  const supabase = useSupabase();
  const [deviceStatus, setDeviceStatus] = useState<DeviceStatus>("idle");
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());

  useEffect(() => {
    if (!deviceId) return;

    const channel = supabase
      .channel(`device-${deviceId}`)
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "devices", filter: `id=eq.${deviceId}` }, (payload) => {
        setDeviceStatus((payload.new as { status: DeviceStatus }).status);
        setLastUpdated(new Date());
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [deviceId, supabase]);

  return { deviceStatus, lastUpdated };
}
