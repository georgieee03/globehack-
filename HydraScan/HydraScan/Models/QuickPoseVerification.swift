import Foundation

enum QuickPoseFixtureClip: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case happyDance = "quickpose-happy-dance"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .happyDance:
            return "Happy Dance"
        }
    }

    nonisolated var resourceExtension: String { "mov" }

    var bundleURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: resourceExtension)
    }
}

struct QuickPoseVerificationMetric: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let value: Double
    let stringValue: String
}

struct QuickPoseVerificationPoint: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
    let z: Double
    let visibility: Double
    let presence: Double
    let cameraAspectY: Double
}

struct QuickPoseVerificationFrameArtifact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let progress: Double
    let timeSeconds: Double
    let status: String
    let fps: Int?
    let latencyMilliseconds: Double?
    let metrics: [QuickPoseVerificationMetric]
    let bodyLandmarks: [QuickPoseVerificationPoint]
    let worldBodyLandmarks: [QuickPoseVerificationPoint]
}

struct QuickPoseVerificationAssertion: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let passed: Bool
    let details: String
}

struct QuickPoseVerificationSummary: Codable, Hashable, Sendable {
    let clipName: String
    let totalFrames: Int
    let successFrames: Int
    let noPersonFrames: Int
    let validationErrorFrames: Int
    let maxRightShoulderROM: Double?
    let maxLeftShoulderROM: Double?
    let maxAsymmetryPercent: Double?
    let estimatedRepCount: Int
    let sdkKeyConfigured: Bool
    let outputMovieFilename: String?
    let assertions: [QuickPoseVerificationAssertion]
    let generatedAt: Date

    var allAssertionsPassed: Bool {
        assertions.allSatisfy(\.passed)
    }
}

struct QuickPoseVerificationRun: Codable, Hashable, Sendable {
    let summary: QuickPoseVerificationSummary
    let frames: [QuickPoseVerificationFrameArtifact]
}
