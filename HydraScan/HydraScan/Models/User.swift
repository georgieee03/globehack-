import Foundation

enum UserRole: String, Codable, CaseIterable, Hashable {
    case client
    case practitioner
    case admin
}

struct HydraUser: Identifiable, Codable, Hashable {
    var id: UUID
    var clinicID: UUID?
    var role: UserRole
    var email: String?
    var fullName: String
    var phone: String?
    var dateOfBirth: Date?
    var authProvider: String?
    var avatarURL: URL?
    var createdAt: Date
    var updatedAt: Date

    static let preview = HydraUser(
        id: UUID(),
        clinicID: UUID(),
        role: .client,
        email: "demo@hydrascan.app",
        fullName: "HydraScan Demo",
        phone: nil,
        dateOfBirth: nil,
        authProvider: "demo",
        avatarURL: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
