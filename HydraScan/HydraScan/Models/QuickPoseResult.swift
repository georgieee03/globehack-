import Foundation

struct Landmark: Identifiable, Codable, Hashable {
    var id: Int { index }
    var index: Int
    var x: Double
    var y: Double
    var z: Double
    var visibility: Double
}

struct LandmarkFrame: Identifiable, Codable, Hashable {
    var id = UUID()
    var capturedAt: Date
    var landmarks: [Landmark]
}

struct GaitMetrics: Codable, Hashable {
    var cadence: Double?
    var strideLength: Double?
    var groundContactTime: Double?
}

struct RepSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var movement: String
    var count: Int
    var peakAngles: [String: Double]
    var troughAngles: [String: Double]
}

struct QuickPoseResult: Codable, Hashable {
    var landmarks: [LandmarkFrame]
    var jointAngles: [String: Double]
    var romValues: [String: Double]
    var asymmetryScores: [String: Double]
    var movementQualityScores: [String: Double]
    var gaitMetrics: GaitMetrics?
    var repSummaries: [RepSummary]
    var capturedAt: Date

    static let empty = QuickPoseResult(
        landmarks: [],
        jointAngles: [:],
        romValues: [:],
        asymmetryScores: [:],
        movementQualityScores: [:],
        gaitMetrics: nil,
        repSummaries: [],
        capturedAt: Date()
    )
}
