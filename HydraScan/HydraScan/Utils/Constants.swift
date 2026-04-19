import Foundation

enum AppTab: Hashable {
    case home
    case capture
    case checkIn
    case profile
}

enum XPRewardEvent: String, CaseIterable, Codable, Hashable {
    case assessmentCompleted = "assessment_completed"
    case dailyCheckIn = "daily_check_in"
    case postSessionFeedback = "post_session_feedback"
    case streakBonus = "streak_bonus"
}

enum CaptureStep: String, CaseIterable, Codable, Hashable, Identifiable {
    case standingFront = "standing_front"
    case standingSide = "standing_side"
    case shoulderFlexion = "shoulder_flexion"
    case squat
    case hipHinge = "hip_hinge"
    case singleLegBalanceRight = "single_leg_balance_right"
    case singleLegBalanceLeft = "single_leg_balance_left"

    var id: String { rawValue }
}

struct CaptureStepDefinition: Identifiable, Codable, Hashable {
    var id: CaptureStep { step }
    var step: CaptureStep
    var title: String
    var instruction: String
    var durationSeconds: Int
}

enum HydraScanConstants {
    static let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "Not configured"
    static let supabaseURL = URL(string: supabaseURLString)
    static let supabaseAnonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    static let quickPoseSDKKey = Bundle.main.object(forInfoDictionaryKey: "QUICKPOSE_SDK_KEY") as? String ?? ""

    static let captureSteps: [CaptureStepDefinition] = [
        CaptureStepDefinition(step: .standingFront, title: "Standing Front", instruction: "Stand tall facing the camera.", durationSeconds: 5),
        CaptureStepDefinition(step: .standingSide, title: "Standing Side", instruction: "Turn sideways and stay relaxed.", durationSeconds: 5),
        CaptureStepDefinition(step: .shoulderFlexion, title: "Shoulder Flexion", instruction: "Lift both arms overhead with control.", durationSeconds: 10),
        CaptureStepDefinition(step: .squat, title: "Squat", instruction: "Move into a comfortable squat and stand tall again.", durationSeconds: 10),
        CaptureStepDefinition(step: .hipHinge, title: "Hip Hinge", instruction: "Hinge from your hips while keeping your chest long.", durationSeconds: 8),
        CaptureStepDefinition(step: .singleLegBalanceRight, title: "Right Balance", instruction: "Stand on your right leg and find a steady hold.", durationSeconds: 10),
        CaptureStepDefinition(step: .singleLegBalanceLeft, title: "Left Balance", instruction: "Stand on your left leg and find a steady hold.", durationSeconds: 10),
    ]

    static let levelThresholds: [Int: Int] = [
        1: 0,
        2: 120,
        3: 280,
        4: 520,
        5: 860,
    ]

    static let xpRewards: [XPRewardEvent: Int] = [
        .assessmentCompleted: 50,
        .dailyCheckIn: 20,
        .postSessionFeedback: 25,
        .streakBonus: 15,
    ]
}
