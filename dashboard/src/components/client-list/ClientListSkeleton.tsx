"use client";

export function ClientListSkeleton() {
  return (
    <div className="space-y-4">
      {Array.from({ length: 5 }).map((_, index) => (
        <div
          key={index}
          className="rounded-3xl border border-slate-200 bg-white p-4 shadow-sm"
          aria-hidden="true"
        >
          <div className="animate-pulse space-y-5">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div className="space-y-3">
                <div className="h-3 w-32 rounded-full bg-slate-200" />
                <div className="h-6 w-56 rounded-full bg-slate-200" />
                <div className="flex flex-wrap gap-2">
                  <div className="h-7 w-24 rounded-full bg-slate-200" />
                  <div className="h-7 w-28 rounded-full bg-slate-200" />
                  <div className="h-7 w-20 rounded-full bg-slate-200" />
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-3 lg:min-w-[32rem]">
                <div className="rounded-2xl bg-slate-50 px-4 py-3">
                  <div className="h-3 w-24 rounded-full bg-slate-200" />
                  <div className="mt-3 h-7 w-20 rounded-full bg-slate-200" />
                </div>
                <div className="rounded-2xl bg-slate-50 px-4 py-3">
                  <div className="h-3 w-28 rounded-full bg-slate-200" />
                  <div className="mt-3 h-5 w-28 rounded-full bg-slate-200" />
                </div>
                <div className="rounded-2xl bg-slate-50 px-4 py-3">
                  <div className="h-3 w-20 rounded-full bg-slate-200" />
                  <div className="mt-3 h-7 w-24 rounded-full bg-slate-200" />
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
