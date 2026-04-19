"use client";
import { useState, useEffect } from "react";
import { fetchRecoveryScore } from "@/lib/edge-functions";

export function useRecoveryScore(clientId: string) {
  const [score, setScore] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!clientId) return;
    setIsLoading(true);
    fetchRecoveryScore(clientId)
      .then((data) => setScore(data.score))
      .catch(err => setError(err instanceof Error ? err : new Error(String(err))))
      .finally(() => setIsLoading(false));
  }, [clientId]);

  return { score, isLoading, error };
}
