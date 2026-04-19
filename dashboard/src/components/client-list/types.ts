import type { BodyRegion } from "@hydrascan/shared";

export type ClientListSortMode = "recent" | "score";

export interface ClientListItem {
  id: string;
  fullName: string;
  latestRecoveryScore: number | null;
  primaryRegions: BodyRegion[];
  mostRecentSessionDate: string | null;
  nextSessionStatus: string;
  activityAt: string;
  sessionCount: number;
}
