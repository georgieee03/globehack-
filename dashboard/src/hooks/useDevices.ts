"use client";
import { useState, useEffect } from "react";
import type { DeviceRecord } from "@/types";
import { useSupabase } from "./useSupabase";

export function useDevices() {
  const supabase = useSupabase();
  const [devices, setDevices] = useState<DeviceRecord[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadDevices() {
      setIsLoading(true);
      const { data, error: err } = await supabase
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
  }, [supabase]);

  return { devices, isLoading, error };
}
