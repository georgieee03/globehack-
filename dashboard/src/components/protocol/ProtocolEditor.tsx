"use client";

import { resolveSafeEnvelope } from "@hydrascan/shared";
import type { BodyRegion, SessionConfig } from "@hydrascan/shared";
import { ConstrainedSlider } from "./ConstrainedSlider";

function asTuple(values: number[]): [number, number, number] {
  return [values[0] ?? 0, values[1] ?? 0, values[2] ?? 0];
}

function updateTuple(values: [number, number, number], index: number, nextValue: number) {
  return asTuple(values.map((value, currentIndex) => (currentIndex === index ? nextValue : value)));
}

export function ProtocolEditor({
  value,
  recommended,
  bodyRegion,
  onChange,
}: {
  value: SessionConfig;
  recommended: SessionConfig;
  bodyRegion: BodyRegion;
  onChange: (value: SessionConfig) => void;
}) {
  const envelope = resolveSafeEnvelope(bodyRegion);

  return (
    <section className="rounded-[2rem] border border-slate-200 bg-[linear-gradient(180deg,rgba(255,255,255,1),rgba(248,250,252,0.98))] p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Edit protocol
          </p>
          <h3 className="mt-1 text-xl font-semibold text-slate-950">Safe envelope controls</h3>
          <p className="mt-1 text-sm leading-6 text-slate-600">
            Every slider stays inside the region-adjusted safe envelope for {bodyRegion.replace("_", " ")}.
          </p>
        </div>
        <div className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
          Hydrawav3 ready
        </div>
      </div>

      <div className="mt-5 grid gap-4 lg:grid-cols-2">
        <div className="space-y-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
            Thermal values
          </p>
          {value.pwmValues.hot.map((hotValue, index) => (
            <ConstrainedSlider
              key={`hot-${index}`}
              label={`Hot PWM ${index + 1}`}
              value={hotValue}
              onChange={(next) =>
                onChange({
                  ...value,
                  pwmValues: {
                    ...value.pwmValues,
                    hot: updateTuple(value.pwmValues.hot, index, next),
                  },
                })
              }
              min={envelope.pwmHotMin}
              max={envelope.pwmHotMax}
              unit="PWM"
              recommended={recommended.pwmValues.hot[index]}
              description="Warming intensity stays within the safe thermal band."
            />
          ))}
          {value.pwmValues.cold.map((coldValue, index) => (
            <ConstrainedSlider
              key={`cold-${index}`}
              label={`Cold PWM ${index + 1}`}
              value={coldValue}
              onChange={(next) =>
                onChange({
                  ...value,
                  pwmValues: {
                    ...value.pwmValues,
                    cold: updateTuple(value.pwmValues.cold, index, next),
                  },
                })
              }
              min={envelope.pwmColdMin}
              max={envelope.pwmColdMax}
              unit="PWM"
              recommended={recommended.pwmValues.cold[index]}
              description="Cooling intensity remains constrained to the envelope."
            />
          ))}
        </div>

        <div className="space-y-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
            Support settings
          </p>
          <ConstrainedSlider
            label="Vibration minimum"
            value={value.vibMin}
            onChange={(next) => onChange({ ...value, vibMin: next })}
            min={envelope.vibMinFloor}
            max={envelope.vibMinCeiling}
            unit="Hz"
            recommended={recommended.vibMin}
            description="Keeps the lower vibration floor within the safe range."
          />
          <ConstrainedSlider
            label="Vibration maximum"
            value={value.vibMax}
            onChange={(next) => onChange({ ...value, vibMax: next })}
            min={envelope.vibMaxFloor}
            max={envelope.vibMaxCeiling}
            unit="Hz"
            recommended={recommended.vibMax}
            description="Upper vibration ceiling for the selected body region."
          />
          <ConstrainedSlider
            label="Hot drop"
            value={value.hotDrop}
            onChange={(next) => onChange({ ...value, hotDrop: next })}
            min={envelope.hotDropMin}
            max={envelope.hotDropMax}
            unit="steps"
            recommended={recommended.hotDrop}
          />
          <ConstrainedSlider
            label="Cold drop"
            value={value.coldDrop}
            onChange={(next) => onChange({ ...value, coldDrop: next })}
            min={envelope.coldDropMin}
            max={envelope.coldDropMax}
            unit="steps"
            recommended={recommended.coldDrop}
          />
          <ConstrainedSlider
            label="Edge cycle duration"
            value={value.edgeCycleDuration}
            onChange={(next) => onChange({ ...value, edgeCycleDuration: next })}
            min={envelope.edgeCycleDurationMin}
            max={envelope.edgeCycleDurationMax}
            unit="min"
            recommended={recommended.edgeCycleDuration}
            description="The cycle window remains within the approved session band."
          />
          <ConstrainedSlider
            label="Session pause"
            value={value.sessionPause}
            onChange={(next) => onChange({ ...value, sessionPause: next })}
            min={0}
            max={120}
            unit="sec"
            recommended={recommended.sessionPause}
          />
          <ConstrainedSlider
            label="Signal delay"
            value={value.sDelay}
            onChange={(next) => onChange({ ...value, sDelay: next })}
            min={0}
            max={30}
            unit="sec"
            recommended={recommended.sDelay}
          />

          <div className="rounded-2xl border border-slate-200 bg-white p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
              LED control
            </p>
            <div className="mt-3 flex items-center justify-between gap-3">
              <p className="text-sm text-slate-600">Photobiomodulation remains part of the plan.</p>
              <button
                type="button"
                onClick={() => onChange({ ...value, led: value.led === 1 ? 0 : 1 })}
                className={[
                  "rounded-full px-4 py-2 text-sm font-semibold transition",
                  value.led === 1
                    ? "bg-emerald-600 text-white shadow-sm shadow-emerald-200"
                    : "border border-slate-200 bg-slate-50 text-slate-700",
                ].join(" ")}
              >
                {value.led === 1 ? "On" : "Off"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
