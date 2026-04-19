import Foundation

enum AsymmetryCalculator {
    static func percentage(right: Double?, left: Double?) -> Double? {
        guard let right, let left else { return nil }
        let average = (abs(right) + abs(left)) / 2
        guard average > 0.0001 else { return 0 }
        return abs(right - left) / average * 100
    }

    static func normalizedSymmetryScore(asymmetry: Double?) -> Double? {
        guard let asymmetry else { return nil }
        return ScanMath.clamp(1 - (asymmetry / 100), lower: 0, upper: 1)
    }
}
