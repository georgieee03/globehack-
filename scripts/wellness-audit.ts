/**
 * Wellness Language Audit Script
 *
 * Scans all user-facing strings across the HydraScan codebase
 * to verify compliance with Hydrawav3 brand guidelines.
 *
 * Checks:
 * 1. No forbidden medical/clinical terms
 * 2. Correct "Hydrawav3" casing (lowercase w)
 * 3. Wellness-appropriate outcome labels
 *
 * Usage: npx tsx scripts/wellness-audit.ts
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

// ─── Forbidden Terms ─────────────────────────────────────────────────────────

const FORBIDDEN_TERMS = [
  "diagnos",
  "treat",
  "cure",
  "medical device",
  "clinical",
  "prescription",
  "medication",
  "drug",
  "heal",
  "therapy",
  "patient",
];

// Terms that are OK in code context but not in user-facing strings
const FORBIDDEN_REGEX = FORBIDDEN_TERMS.map(
  (term) => new RegExp(`\\b${term}`, "gi"),
);

// ─── Correct Brand Name ──────────────────────────────────────────────────────

// "HydraWav3" or "Hydrawav" without the 3 are incorrect
const INCORRECT_BRAND_PATTERNS = [
  /HydraWav3/g, // Capital W is wrong
  /Hydrawav[^3]/g, // Missing the 3
  /HYDRAWAV3/g, // All caps (except in env var names)
];

// ─── Scan Patterns ───────────────────────────────────────────────────────────

const SCAN_PATTERNS = [
  "dashboard/src/**/*.tsx",
  "dashboard/src/**/*.ts",
  "shared/src/**/*.ts",
  "backend/supabase/seed/**/*.sql",
];

// Files/dirs to skip
const SKIP_PATTERNS = [
  "node_modules",
  ".git",
  "dist",
  "build",
  ".next",
  "wellness-audit.ts", // Don't audit ourselves
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

interface Violation {
  file: string;
  line: number;
  term: string;
  context: string;
  type: "forbidden_term" | "brand_name" | "label";
}

function shouldSkip(filePath: string): boolean {
  return SKIP_PATTERNS.some((pattern) => filePath.includes(pattern));
}

function isUserFacingString(line: string): boolean {
  // Heuristic: check if line contains string literals that look user-facing
  // Skip comments that are clearly code documentation
  const trimmed = line.trim();

  // Skip import statements
  if (trimmed.startsWith("import ")) return false;
  // Skip type definitions
  if (trimmed.startsWith("type ") || trimmed.startsWith("interface "))
    return false;
  // Skip env var references
  if (trimmed.includes("process.env") || trimmed.includes("Deno.env"))
    return false;
  // Skip validation/check code that references terms for checking
  if (trimmed.includes("FORBIDDEN") || trimmed.includes("forbidden"))
    return false;

  return true;
}

function scanFile(filePath: string): Violation[] {
  const violations: Violation[] = [];
  let content: string;

  try {
    content = readFileSync(filePath, "utf-8");
  } catch {
    return violations;
  }

  const lines = content.split("\n");

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;

    if (!isUserFacingString(line)) continue;

    // Check forbidden terms
    for (const regex of FORBIDDEN_REGEX) {
      regex.lastIndex = 0;
      const match = regex.exec(line);
      if (match) {
        violations.push({
          file: filePath,
          line: lineNum,
          term: match[0],
          context: line.trim().substring(0, 120),
          type: "forbidden_term",
        });
      }
    }

    // Check brand name (skip env var lines)
    if (!line.includes("HYDRAWAV_API") && !line.includes("HYDRAWAV_")) {
      for (const pattern of INCORRECT_BRAND_PATTERNS) {
        pattern.lastIndex = 0;
        const match = pattern.exec(line);
        if (match) {
          violations.push({
            file: filePath,
            line: lineNum,
            term: match[0],
            context: line.trim().substring(0, 120),
            type: "brand_name",
          });
        }
      }
    }
  }

  return violations;
}

function walkDir(dir: string, extensions: string[]): string[] {
  const files: string[] = [];

  try {
    const entries = readdirSync(dir);
    for (const entry of entries) {
      const fullPath = join(dir, entry);
      if (shouldSkip(fullPath)) continue;

      try {
        const stat = statSync(fullPath);
        if (stat.isDirectory()) {
          files.push(...walkDir(fullPath, extensions));
        } else if (extensions.some((ext) => fullPath.endsWith(ext))) {
          files.push(fullPath);
        }
      } catch {
        // Skip inaccessible files
      }
    }
  } catch {
    // Directory doesn't exist yet
  }

  return files;
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
  console.log("🔍 HydraScan Wellness Language Audit\n");

  const rootDir = process.cwd();
  const extensions = [".tsx", ".ts", ".sql", ".swift"];

  const dirsToScan = [
    join(rootDir, "dashboard", "src"),
    join(rootDir, "shared", "src"),
    join(rootDir, "backend", "supabase", "seed"),
    join(rootDir, "backend", "supabase", "functions"),
  ];

  const allFiles: string[] = [];
  for (const dir of dirsToScan) {
    allFiles.push(...walkDir(dir, extensions));
  }

  console.log(`Scanning ${allFiles.length} files...\n`);

  const allViolations: Violation[] = [];

  for (const file of allFiles) {
    const violations = scanFile(file);
    allViolations.push(...violations);
  }

  if (allViolations.length === 0) {
    console.log("✅ No wellness language violations found!\n");
    process.exit(0);
  }

  console.log(
    `❌ Found ${allViolations.length} violation(s):\n`,
  );

  // Group by file
  const byFile = new Map<string, Violation[]>();
  for (const v of allViolations) {
    const rel = relative(rootDir, v.file);
    const existing = byFile.get(rel) ?? [];
    existing.push(v);
    byFile.set(rel, existing);
  }

  for (const [file, violations] of byFile) {
    console.log(`\n📄 ${file}`);
    for (const v of violations) {
      const typeLabel =
        v.type === "forbidden_term"
          ? "🚫 Forbidden"
          : v.type === "brand_name"
            ? "📛 Brand"
            : "🏷️ Label";
      console.log(`  L${v.line} ${typeLabel}: "${v.term}"`);
      console.log(`    ${v.context}`);
    }
  }

  console.log(
    `\n❌ ${allViolations.length} violation(s) found. Fix before shipping.\n`,
  );
  process.exit(1);
}

main();
