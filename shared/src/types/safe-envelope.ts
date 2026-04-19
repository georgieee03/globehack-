export interface SafeEnvelope {
  pwmHotMin: number;
  pwmHotMax: number;
  pwmColdMin: number;
  pwmColdMax: number;
  vibMinFloor: number;
  vibMinCeiling: number;
  vibMaxFloor: number;
  vibMaxCeiling: number;
  hotDropMin: number;
  hotDropMax: number;
  coldDropMin: number;
  coldDropMax: number;
  edgeCycleDurationMin: number;
  edgeCycleDurationMax: number;
}

export type SafeEnvelopeOverride = Partial<SafeEnvelope>;

export interface SafeEnvelopeViolation {
  parameter: string;
  actual: number;
  min: number;
  max: number;
}

export interface SafeEnvelopeValidationResult {
  valid: boolean;
  violations: SafeEnvelopeViolation[];
  envelope: SafeEnvelope;
}
