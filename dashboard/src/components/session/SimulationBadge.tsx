"use client";

interface SimulationBadgeProps {
  isSimulation: boolean;
}

export function SimulationBadge({ isSimulation }: SimulationBadgeProps) {
  if (!isSimulation) {
    return (
      <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-emerald-800">
        Live Hydrawav3
      </span>
    );
  }

  return (
    <span className="rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-amber-800">
      Simulation mode
    </span>
  );
}
