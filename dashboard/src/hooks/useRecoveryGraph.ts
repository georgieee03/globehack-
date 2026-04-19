"use client";
import { useState, useEffect } from "react";
import type { BodyRegion, RecoveryGraphPoint } from "@/types";
import { fetchRecoveryGraph } from "@/lib/edge-functions";

export function useRecoveryGraph(clientId: string, bodyRegion: BodyRegion, limit = 30) {
  const [dataPoints, setDataPoints] = useState<RecoveryGraphPoint[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!clientId || !bodyRegion) return;
    setIsLoading(true);
    fetchRecoveryGraph(clientId, bodyRegion, limit)
      .then((data) => setDataPoints(data.dataPoints))
      .catch(err => setError(err instanceof Error ? err : new Error(String(err))))
      .finally(() => setIsLoading(false));
  }, [clientId, bodyRegion, limit]);

  return { dataPoints, isLoading, error };
}
