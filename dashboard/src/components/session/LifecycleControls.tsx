"use client";

interface LifecycleControlsProps {
  status: "active" | "paused" | "completed" | "pending" | "cancelled" | "error";
  isWorking?: boolean;
  errorMessage?: string | null;
  onPause: () => void;
  onResume: () => void;
  onStop: () => void;
}

export function LifecycleControls({
  status,
  isWorking = false,
  errorMessage,
  onPause,
  onResume,
  onStop,
}: LifecycleControlsProps) {
  return (
    <section className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-slate-950">Session controls</h3>
          <p className="mt-1 text-sm text-slate-600">Keep the Hydrawav3 session moving with pause, resume, and stop.</p>
        </div>
        <span className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-slate-600">
          {status}
        </span>
      </div>

      {errorMessage ? (
        <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">
          {errorMessage}
        </div>
      ) : null}

      <div className="mt-4 flex flex-wrap gap-3">
        {status === "active" ? (
          <>
            <button
              type="button"
              onClick={onPause}
              disabled={isWorking}
              className="rounded-full bg-slate-950 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              Pause
            </button>
            <button
              type="button"
              onClick={onStop}
              disabled={isWorking}
              className="rounded-full border border-slate-300 px-4 py-2 text-sm font-medium text-slate-900 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Stop
            </button>
          </>
        ) : null}

        {status === "paused" ? (
          <>
            <button
              type="button"
              onClick={onResume}
              disabled={isWorking}
              className="rounded-full bg-slate-950 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              Resume
            </button>
            <button
              type="button"
              onClick={onStop}
              disabled={isWorking}
              className="rounded-full border border-slate-300 px-4 py-2 text-sm font-medium text-slate-900 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Stop
            </button>
          </>
        ) : null}
      </div>
    </section>
  );
}
