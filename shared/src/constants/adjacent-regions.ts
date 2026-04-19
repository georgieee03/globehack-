import type { BodyRegion } from "../types/client-profile.js";

export const ADJACENT_REGIONS: Record<BodyRegion, BodyRegion[]> = {
  right_shoulder: ['neck', 'upper_back', 'right_arm'],
  left_shoulder: ['neck', 'upper_back', 'left_arm'],
  neck: ['right_shoulder', 'left_shoulder', 'upper_back'],
  upper_back: ['neck', 'right_shoulder', 'left_shoulder', 'lower_back'],
  lower_back: ['upper_back', 'right_hip', 'left_hip'],
  right_hip: ['lower_back', 'right_knee'],
  left_hip: ['lower_back', 'left_knee'],
  right_knee: ['right_hip', 'right_calf'],
  left_knee: ['left_hip', 'left_calf'],
  right_calf: ['right_knee', 'right_foot'],
  left_calf: ['left_knee', 'left_foot'],
  right_arm: ['right_shoulder'],
  left_arm: ['left_shoulder'],
  right_foot: ['right_calf'],
  left_foot: ['left_calf'],
};
