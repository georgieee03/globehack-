"use client";
import { useEffect, useState } from "react";
import { recommend, type RecommendResponse } from "@/lib/edge-functions";

export function useRecommendation(clientId: string, assessmentId: string) {
  const [recommendation, setRecommendation] = useState<RecommendResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  async function refetch() {
    if (!clientId || !assessmentId) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await recommend(clientId, assessmentId);
      setRecommendation(data);
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void refetch();
  }, [clientId, assessmentId]);

  return { recommendation, isLoading, error, refetch };
}
