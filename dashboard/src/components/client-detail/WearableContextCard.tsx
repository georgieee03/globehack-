"use client";

export function WearableContextCard({
  wearable,
}: {
  wearable: {
    hrv: number;
    strain: number;
    sleepScore: number;
    lastSync: string;
  };
}) {
  return (
    <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
        Wearable context
      </p>
      <h3 className="mt-1 text-xl font-semibold text-slate-950">Recovery support signals</h3>

      <div className="mt-4 grid grid-cols-2 gap-3">
        <div className="rounded-2xl bg-slate-50 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">HRV</p>
          <p className="mt-1 text-lg font-semibold text-slate-950">{wearable.hrv}</p>
        </div>
        <div className="rounded-2xl bg-slate-50 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">Strain</p>
          <p className="mt-1 text-lg font-semibold text-slate-950">{wearable.strain}</p>
        </div>
        <div className="rounded-2xl bg-slate-50 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">Sleep</p>
          <p className="mt-1 text-lg font-semibold text-slate-950">{wearable.sleepScore}/100</p>
        </div>
        <div className="rounded-2xl bg-slate-50 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">Last sync</p>
          <p className="mt-1 text-sm font-medium text-slate-950">
            {new Date(wearable.lastSync).toLocaleString()}
          </p>
        </div>
      </div>

      <p className="mt-4 text-sm leading-6 text-slate-600">
        These signals help tune Hydrawav3 vibration and thermal intensity when the client is
        carrying extra fatigue.
      </p>
    </section>
  );
}
