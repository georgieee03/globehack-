import {
  assertArrayIncludes,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  normalizeCheckinRequest,
  toStoredTargetRegions,
} from "./logic.ts";

Deno.test("normalizeCheckinRequest accepts Swift-style camelCase payloads", () => {
  const { value, errors } = normalizeCheckinRequest({
    checkinType: "daily",
    overallFeeling: 4,
    targetRegions: ["neck", "upper_back"],
    activitySinceLast: "  Long walk and desk work  ",
  });

  assertEquals(errors, []);
  assertEquals(value?.checkinType, "daily");
  assertEquals(value?.overallFeeling, 4);
  assertEquals(value?.activitySinceLast, "Long walk and desk work");
  assertEquals(value?.targetRegions, [
    { region: "neck", status: 4 },
    { region: "upper_back", status: 4 },
  ]);
});

Deno.test("normalizeCheckinRequest keeps explicit target region statuses", () => {
  const { value, errors } = normalizeCheckinRequest({
    overall_feeling: 3,
    target_regions: [
      { region: "left_knee", status: 7 },
      { body_region: "right_hip" },
    ],
  });

  assertEquals(errors, []);
  assertEquals(toStoredTargetRegions(value?.targetRegions ?? []), [
    { region: "left_knee", status: 7 },
    { region: "right_hip", status: 3 },
  ]);
});

Deno.test("normalizeCheckinRequest rejects invalid region payloads", () => {
  const { errors } = normalizeCheckinRequest({
    overall_feeling: 4,
    target_regions: ["mid_back"],
  });

  assertArrayIncludes(errors, [
    "target_regions contains an unsupported body region",
  ]);
});
