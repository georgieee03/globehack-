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

    enum CodingKeys: String, CodingKey {
        case id
        case clinicID = "clinic_id"
        case role
        case email
        case fullName = "full_name"
        case phone
        case dateOfBirth = "date_of_birth"
        case authProvider = "auth_provider"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        clinicID: UUID?,
        role: UserRole,
        email: String?,
        fullName: String,
        phone: String?,
        dateOfBirth: Date?,
        authProvider: String?,
        avatarURL: URL?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.clinicID = clinicID
        self.role = role
        self.email = email
        self.fullName = fullName
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.authProvider = authProvider
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

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

struct HydraAuthUser: Identifiable, Codable, Hashable {
    var id: UUID
    var email: String?
    var phone: String?
    var providers: [String]
    var lastSignInAt: Date?
    var createdAt: Date
    var updatedAt: Date
}

struct HydraClinic: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var address: String?
    var timezone: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case timezone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        name: String,
        address: String?,
        timezone: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.timezone = timezone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HydraSessionContext: Codable, Hashable {
    var authUserID: UUID
    var userID: UUID
    var clinicID: UUID?
    var role: UserRole
    var clientProfileID: UUID?
    var authUser: HydraAuthUser
    var appUser: HydraUser
    var clinic: HydraClinic?

    init(
        authUserID: UUID,
        userID: UUID,
        clinicID: UUID?,
        role: UserRole,
        clientProfileID: UUID?,
        authUser: HydraAuthUser,
        appUser: HydraUser,
        clinic: HydraClinic?
    ) {
        self.authUserID = authUserID
        self.userID = userID
        self.clinicID = clinicID
        self.role = role
        self.clientProfileID = clientProfileID
        self.authUser = authUser
        self.appUser = appUser
        self.clinic = clinic
    }
}
