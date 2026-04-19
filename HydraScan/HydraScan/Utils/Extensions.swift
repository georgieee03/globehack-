import Foundation
import simd

extension Date {
    var shortDateLabel: String {
        Self.shortDateFormatter.string(from: self)
    }

    var iso8601String: String {
        Self.iso8601Formatter.string(from: self)
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension SIMD3 where Scalar == Double {
    var normalizedOrZero: SIMD3<Double> {
        let length = simd_length(self)
        guard length > 0 else { return .zero }
        return self / length
    }

    func angleDegrees(to other: SIMD3<Double>) -> Double {
        let lhs = normalizedOrZero
        let rhs = other.normalizedOrZero
        let cosine = simd_clamp(simd_dot(lhs, rhs), -1.0, 1.0)
        return acos(cosine) * 180 / .pi
    }
}
