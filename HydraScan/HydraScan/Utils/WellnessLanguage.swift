import Foundation

struct WellnessViolation: Identifiable, Hashable {
    var id: String { "\(term)-\(position)" }
    var term: String
    var replacement: String
    var position: Int
}

enum WellnessLanguage {
    private static let forbiddenTerms: [String: String] = [
        "patient": "client",
        "symptom": "recovery signal",
        "clinical finding": "movement insight",
        "medical": "recovery",
        "clinical": "wellness",
        "treat": "support",
        "diagnos": "assessment",
        "HydraWav3": "Hydrawav3",
    ]

    static func validate(_ text: String) -> [WellnessViolation] {
        forbiddenTerms.compactMap { term, replacement in
            guard let range = text.range(of: term, options: [.caseInsensitive]) else {
                return nil
            }

            return WellnessViolation(
                term: term,
                replacement: replacement,
                position: text.distance(from: text.startIndex, to: range.lowerBound)
            )
        }
    }

    static func sanitize(_ text: String) -> String {
        forbiddenTerms.reduce(text) { partialResult, entry in
            partialResult.replacingOccurrences(
                of: entry.key,
                with: entry.value,
                options: [.caseInsensitive]
            )
        }
    }
}
