"use client";
import { useState, useEffect } from "react";
import type { RecoveryMap } from "@/types";
import { fetchRecoveryMap } from "@/lib/edge-functions";

export function useRecoveryMap(clientId: string, assessmentId: string) {
  const [recoveryMap, setRecoveryMap] = useState<RecoveryMap | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!clientId || !assessmentId) return;
    setIsLoading(true);
    fetchRecoveryMap(clientId, assessmentId)
      .then((data) => setRecoveryMap(data.recoveryMap))
      .catch(err => setError(err instanceof Error ? err : new Error(String(err))))
      .finally(() => setIsLoading(false));
  }, [clientId, assessmentId]);

  return { recoveryMap, isLoading, error };
}
