"use client";

import { formatConfidence } from "@/lib/formatters";

export function ConfidenceBadge({ confidence }: { confidence: number }) {
  const tone =
    confidence >= 0.7
      ? "border-emerald-200 bg-emerald-50 text-emerald-800"
      : confidence >= 0.5
        ? "border-amber-200 bg-amber-50 text-amber-800"
        : "border-rose-200 bg-rose-50 text-rose-800";

  return (
    <span className={`rounded-full border px-3 py-1 text-sm font-semibold ${tone}`}>
      Confidence {formatConfidence(confidence)}
    </span>
  );
}
