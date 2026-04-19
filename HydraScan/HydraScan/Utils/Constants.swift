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

private enum CaptureSide {
    case left
    case right
}

enum HydraScanConstants {
    static let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "Not configured"
    static let supabaseURL = URL(string: supabaseURLString)
    static let supabaseAnonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    static let quickPoseSDKKey = Bundle.main.object(forInfoDictionaryKey: "QUICKPOSE_SDK_KEY") as? String ?? ""

    private static let standingFrontStep = CaptureStepDefinition(
        step: .standingFront,
        title: "Standing Front",
        instruction: "Stand tall facing the camera.",
        durationSeconds: 5
    )

    private static let standingSideStep = CaptureStepDefinition(
        step: .standingSide,
        title: "Standing Side",
        instruction: "Turn sideways and stay relaxed.",
        durationSeconds: 5
    )

    private static let generalShoulderFlexionStep = CaptureStepDefinition(
        step: .shoulderFlexion,
        title: "Shoulder Flexion",
        instruction: "Lift both arms overhead with control.",
        durationSeconds: 10
    )

    private static let generalSquatStep = CaptureStepDefinition(
        step: .squat,
        title: "Squat",
        instruction: "Move into a comfortable squat and stand tall again.",
        durationSeconds: 10
    )

    private static let generalHipHingeStep = CaptureStepDefinition(
        step: .hipHinge,
        title: "Hip Hinge",
        instruction: "Hinge from your hips while keeping your chest long.",
        durationSeconds: 8
    )

    private static let rightBalanceStep = CaptureStepDefinition(
        step: .singleLegBalanceRight,
        title: "Right Balance",
        instruction: "Stand on your right leg and find a steady hold.",
        durationSeconds: 10
    )

    private static let leftBalanceStep = CaptureStepDefinition(
        step: .singleLegBalanceLeft,
        title: "Left Balance",
        instruction: "Stand on your left leg and find a steady hold.",
        durationSeconds: 10
    )

    static let defaultCaptureSteps: [CaptureStepDefinition] = [
        standingFrontStep,
        standingSideStep,
        generalShoulderFlexionStep,
        generalSquatStep,
        generalHipHingeStep,
        rightBalanceStep,
        leftBalanceStep,
    ]

    static func captureSteps(for primaryRegions: [BodyRegion]) -> [CaptureStepDefinition] {
        let selectedRegions = Set(primaryRegions)
        guard !selectedRegions.isEmpty else {
            return defaultCaptureSteps
        }

        let shoulderRegions: Set<BodyRegion> = [.leftShoulder, .rightShoulder, .leftArm, .rightArm, .neck, .upperBack]
        let lowerBodyRegions: Set<BodyRegion> = [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftCalf, .rightCalf, .leftFoot, .rightFoot, .lowerBack]
        let rightSideLoadRegions: Set<BodyRegion> = [.rightHip, .rightKnee, .rightCalf, .rightFoot]
        let leftSideLoadRegions: Set<BodyRegion> = [.leftHip, .leftKnee, .leftCalf, .leftFoot]

        var steps: [CaptureStepDefinition] = [standingFrontStep]

        if !selectedRegions.isDisjoint(with: shoulderRegions.union(lowerBodyRegions).union([.upperBack, .lowerBack, .neck])) {
            steps.append(standingSideStep)
        }

        if !selectedRegions.isDisjoint(with: shoulderRegions) {
            steps.append(shoulderFocusStep(for: selectedRegions))
        }

        if !selectedRegions.isDisjoint(with: lowerBodyRegions.subtracting([.lowerBack])) {
            steps.append(squatFocusStep(for: selectedRegions))
        }

        if !selectedRegions.isDisjoint(with: [.leftHip, .rightHip, .upperBack, .lowerBack, .neck]) {
            steps.append(hipHingeFocusStep(for: selectedRegions))
        }

        if !selectedRegions.isDisjoint(with: rightSideLoadRegions) {
            steps.append(balanceStep(side: .right, regions: selectedRegions))
        }

        if !selectedRegions.isDisjoint(with: leftSideLoadRegions) {
            steps.append(balanceStep(side: .left, regions: selectedRegions))
        }

        if steps.count == 1 {
            steps.append(standingSideStep)
        }

        if steps.count < 3, selectedRegions.isDisjoint(with: shoulderRegions) {
            steps.append(shoulderFocusStep(for: selectedRegions))
        }

        return steps.reduce(into: []) { result, step in
            if !result.contains(where: { $0.step == step.step }) {
                result.append(step)
            }
        }
    }

    private static func shoulderFocusStep(for regions: Set<BodyRegion>) -> CaptureStepDefinition {
        if regions.contains(.rightShoulder) || regions.contains(.rightArm) {
            return CaptureStepDefinition(
                step: .shoulderFlexion,
                title: "Right Shoulder Reach",
                instruction: "Lift both arms overhead and notice how your right shoulder tracks.",
                durationSeconds: 10
            )
        }

        if regions.contains(.leftShoulder) || regions.contains(.leftArm) {
            return CaptureStepDefinition(
                step: .shoulderFlexion,
                title: "Left Shoulder Reach",
                instruction: "Lift both arms overhead and notice how your left shoulder tracks.",
                durationSeconds: 10
            )
        }

        if regions.contains(.neck) || regions.contains(.upperBack) {
            return CaptureStepDefinition(
                step: .shoulderFlexion,
                title: "Upper Chain Reach",
                instruction: "Lift both arms overhead with your neck relaxed and ribs stacked.",
                durationSeconds: 10
            )
        }

        return generalShoulderFlexionStep
    }

    private static func squatFocusStep(for regions: Set<BodyRegion>) -> CaptureStepDefinition {
        if regions.contains(.rightKnee) || regions.contains(.leftKnee) {
            return CaptureStepDefinition(
                step: .squat,
                title: "Knee-Friendly Squat",
                instruction: "Move through a comfortable squat and watch how both knees track.",
                durationSeconds: 10
            )
        }

        if regions.contains(.rightFoot) || regions.contains(.leftFoot) || regions.contains(.rightCalf) || regions.contains(.leftCalf) {
            return CaptureStepDefinition(
                step: .squat,
                title: "Ankle + Knee Squat",
                instruction: "Sink into a small squat and press evenly through both feet.",
                durationSeconds: 10
            )
        }

        return generalSquatStep
    }

    private static func hipHingeFocusStep(for regions: Set<BodyRegion>) -> CaptureStepDefinition {
        if regions.contains(.lowerBack) {
            return CaptureStepDefinition(
                step: .hipHinge,
                title: "Back-Friendly Hinge",
                instruction: "Hinge from your hips and keep your low back long and quiet.",
                durationSeconds: 8
            )
        }

        if regions.contains(.rightHip) || regions.contains(.leftHip) {
            return CaptureStepDefinition(
                step: .hipHinge,
                title: "Hip Hinge",
                instruction: "Hinge from your hips and notice whether one side feels tighter.",
                durationSeconds: 8
            )
        }

        return generalHipHingeStep
    }

    private static func balanceStep(side: CaptureSide, regions: Set<BodyRegion>) -> CaptureStepDefinition {
        switch side {
        case .right:
            if regions.contains(.rightFoot) || regions.contains(.rightCalf) {
                return CaptureStepDefinition(
                    step: .singleLegBalanceRight,
                    title: "Right Foot Balance",
                    instruction: "Stand on your right leg and feel for a steady tripod foot.",
                    durationSeconds: 10
                )
            }

            return rightBalanceStep
        case .left:
            if regions.contains(.leftFoot) || regions.contains(.leftCalf) {
                return CaptureStepDefinition(
                    step: .singleLegBalanceLeft,
                    title: "Left Foot Balance",
                    instruction: "Stand on your left leg and feel for a steady tripod foot.",
                    durationSeconds: 10
                )
            }

            return leftBalanceStep
        }
    }

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
