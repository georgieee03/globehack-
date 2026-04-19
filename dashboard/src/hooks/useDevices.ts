"use client";
import { useState, useEffect } from "react";
import type { DeviceRecord } from "@/types";
import { useInsforge } from "./useInsforge";

export function useDevices() {
  const insforge = useInsforge();
  const [devices, setDevices] = useState<DeviceRecord[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadDevices() {
      setIsLoading(true);
      const { data, error: err } = await insforge
        .from("devices")
        .select("*")
        .order("status", { ascending: true })
        .order("label", { ascending: true });

      if (cancelled) return;

      if (err) setError(new Error(err.message));
      else setDevices((data ?? []) as DeviceRecord[]);
      setIsLoading(false);
    }

    void loadDevices();

    return () => {
      cancelled = true;
    };
  }, [insforge]);

  return { devices, isLoading, error };
}
