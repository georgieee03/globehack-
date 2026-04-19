import type {
  RecoverySignal,
  RecoverySignalValue,
  RecoverySignalsByRegion,
} from "../types/client-profile.js";

export function mapRecoverySignalsByRegion(
  signals: RecoverySignal[],
): RecoverySignalsByRegion {
  return signals.reduce<RecoverySignalsByRegion>((accumulator, signal) => {
    const { region, ...value } = signal;
    accumulator[region] = value satisfies RecoverySignalValue;
    return accumulator;
  }, {});
}
