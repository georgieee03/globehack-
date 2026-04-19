import {
  assertArrayIncludes,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { normalizeClaimClinicInviteRequest } from "./logic.ts";

Deno.test("normalizeClaimClinicInviteRequest accepts snake_case and camelCase", () => {
  const snakeCase = normalizeClaimClinicInviteRequest({
    invite_code: "az1234",
    full_name: "Alex Client",
  });
  const camelCase = normalizeClaimClinicInviteRequest({
    inviteCode: "xy9999",
    fullName: "Jordan Client",
  });

  assertEquals(snakeCase.errors, []);
  assertEquals(snakeCase.value, {
    inviteCode: "AZ1234",
    fullName: "Alex Client",
  });
  assertEquals(camelCase.errors, []);
  assertEquals(camelCase.value, {
    inviteCode: "XY9999",
    fullName: "Jordan Client",
  });
});

Deno.test("normalizeClaimClinicInviteRequest rejects blank required fields", () => {
  const { errors } = normalizeClaimClinicInviteRequest({
    inviteCode: "   ",
    fullName: "",
  });

  assertArrayIncludes(errors, [
    "invite_code is required",
    "full_name is required",
  ]);
});
