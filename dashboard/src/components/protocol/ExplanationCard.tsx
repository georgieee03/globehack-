"use client";

export function ExplanationCard({
  explanation,
  isFallback,
}: {
  explanation: string;
  isFallback: boolean;
}) {
  return (
    <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Why this protocol
          </p>
          <h3 className="mt-1 text-xl font-semibold text-slate-950">Plain-language explanation</h3>
        </div>
        <span className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
          {isFallback ? "Template fallback" : "LLM generated"}
        </span>
      </div>
      <p className="mt-4 text-sm leading-7 text-slate-700">{explanation}</p>
    </section>
  );
}
