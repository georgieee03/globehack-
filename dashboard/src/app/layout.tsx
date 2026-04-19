import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HydraScan Dashboard",
  description: "Practitioner Recovery Intelligence Dashboard for Hydrawav3 sessions",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-[var(--canvas)] text-slate-950 antialiased">
        <div className="absolute inset-x-0 top-0 -z-10 h-72 bg-[radial-gradient(circle_at_top_left,_rgba(34,197,94,0.18),_transparent_42%),radial-gradient(circle_at_top_right,_rgba(14,165,233,0.18),_transparent_36%)]" />
        <nav className="sticky top-0 z-20 border-b border-white/70 bg-white/80 px-6 py-4 backdrop-blur">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-4">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.28em] text-emerald-700">
                HydraScan
              </p>
              <h1 className="text-lg font-semibold text-slate-900">
                Recovery Intelligence Dashboard
              </h1>
            </div>
            <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-800">
              Hydrawav3 workflow
            </span>
          </div>
        </nav>
        <main className="mx-auto max-w-7xl p-6">{children}</main>
      </body>
    </html>
  );
}
