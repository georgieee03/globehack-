import Foundation

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Security)
import Security
#endif

#if canImport(UIKit)
import UIKit
#endif

protocol AuthServiceProtocol {
    func restoreSession() async -> HydraUser?
    func signInWithApple() async throws -> HydraUser
    func signInWithEmail(_ email: String) async throws
    func verifyMagicLink(_ url: URL?) async throws -> HydraUser
    func refreshSession() async -> HydraUser?
    func currentUser() async -> HydraUser?
    func isAuthenticated() async -> Bool
    func signOut() async
}

enum AuthServiceError: LocalizedError {
    case invalidEmail
    case cancelled
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address to receive your magic link."
        case .cancelled:
            return "Sign-in was cancelled. You can try again whenever you're ready."
        case let .unavailable(message):
            return message
        }
    }
}

actor MockAuthService: AuthServiceProtocol {
    private var cachedUser: HydraUser?
    private var pendingMagicLinkEmail: String?
    private let supabaseService: SupabaseServiceProtocol

    init(supabaseService: SupabaseServiceProtocol) {
        self.supabaseService = supabaseService
    }

    func restoreSession() async -> HydraUser? {
        cachedUser
    }

    func signInWithApple() async throws -> HydraUser {
        let user = HydraUser(
            id: UUID(),
            clinicID: UUID(),
            role: .client,
            email: "apple-client@hydrascan.app",
            fullName: "Apple Sign-In Client",
            phone: nil,
            dateOfBirth: nil,
            authProvider: "apple",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedUser = user
        _ = try? await supabaseService.ensureClientProfile(for: user)
        return user
    }

    func signInWithEmail(_ email: String) async throws {
        guard email.contains("@"), email.contains(".") else {
            throw AuthServiceError.invalidEmail
        }

        pendingMagicLinkEmail = email
    }

    func verifyMagicLink(_ url: URL?) async throws -> HydraUser {
        let email = pendingMagicLinkEmail
            ?? url?.absoluteString
            ?? "magic-link-client@hydrascan.app"

        let user = HydraUser(
            id: UUID(),
            clinicID: UUID(),
            role: .client,
            email: email,
            fullName: "Magic Link Client",
            phone: nil,
            dateOfBirth: nil,
            authProvider: "email",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        cachedUser = user
        pendingMagicLinkEmail = nil
        _ = try? await supabaseService.ensureClientProfile(for: user)
        return user
    }

    func refreshSession() async -> HydraUser? {
        cachedUser
    }

    func currentUser() async -> HydraUser? {
        cachedUser
    }

    func isAuthenticated() async -> Bool {
        cachedUser != nil
    }

    func signOut() async {
        cachedUser = nil
        pendingMagicLinkEmail = nil
    }
}

#if canImport(AuthenticationServices)
private struct SupabaseAuthUser: Codable {
    let id: UUID
    let email: String?
}

private struct SupabaseAuthSessionResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

private struct StoredSupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let authUserID: UUID?
}

private struct HydraUserRow: Codable {
    let id: UUID
    let clinicID: UUID?
    let role: UserRole
    let email: String?
    let fullName: String
    let phone: String?
    let dateOfBirth: Date?
    let authProvider: String?
    let avatarURL: URL?
    let createdAt: Date
    let updatedAt: Date

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        clinicID = try container.decodeIfPresent(UUID.self, forKey: .clinicID)
        role = try container.decode(UserRole.self, forKey: .role)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        fullName = try container.decode(String.self, forKey: .fullName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)

        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateOfBirth) {
            dateOfBirth = Self.birthDateFormatter.date(from: dateString)
        } else {
            dateOfBirth = nil
        }

        authProvider = try container.decodeIfPresent(String.self, forKey: .authProvider)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var hydraUser: HydraUser {
        HydraUser(
            id: id,
            clinicID: clinicID,
            role: role,
            email: email,
            fullName: fullName,
            phone: phone,
            dateOfBirth: dateOfBirth,
            authProvider: authProvider,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct SupabaseVerifyResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
}

private enum SupabaseAuthEndpoint {
    case otp
    case token(grantType: String)
    case verify
    case user
    case logout

    var path: String {
        switch self {
        case .otp:
            return "/auth/v1/otp"
        case let .token(grantType):
            return "/auth/v1/token?grant_type=\(grantType)"
        case .verify:
            return "/auth/v1/verify"
        case .user:
            return "/auth/v1/user"
        case .logout:
            return "/auth/v1/logout"
        }
    }
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result {
        let idToken: String
        let rawNonce: String
        let fullName: String?
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var rawNonce: String?
    private var controller: ASAuthorizationController?

    @MainActor
    func start() async throws -> Result {
        guard let window = Self.presentationWindow() else {
            throw AuthServiceError.unavailable("Apple Sign-In needs an active window scene.")
        }

        let nonce = Self.randomNonce()
        rawNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()

            _ = window
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.presentationWindow() ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8),
            let rawNonce
        else {
            continuation?.resume(throwing: AuthServiceError.unavailable("Apple Sign-In did not return a usable identity token."))
            continuation = nil
            self.controller = nil
            return
        }

        continuation?.resume(
            returning: Result(
                idToken: token,
                rawNonce: rawNonce,
                fullName: Self.makeFullName(from: credential.fullName)
            )
        )
        continuation = nil
        self.controller = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
            continuation?.resume(throwing: AuthServiceError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        self.controller = nil
    }

    @MainActor
    private static func presentationWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = randomBytes.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
            }

            if status != errSecSuccess {
                return String((0..<length).compactMap { _ in characters.randomElement() })
            }

            for byte in randomBytes where remainingLength > 0 {
                if Int(byte) < characters.count {
                    result.append(characters[Int(byte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeFullName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }

        let parts = [
            components.givenName,
            components.middleName,
            components.familyName,
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: " ")
    }
}

actor LiveAuthService: AuthServiceProtocol {
    private let supabaseService: SupabaseServiceProtocol?
    private let urlSession: URLSession
    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var cachedUser: HydraUser?

    init(
        supabaseService: SupabaseServiceProtocol? = nil,
        urlSession: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) throws {
        guard HydraScanConstants.usesLiveServices else {
            throw AuthServiceError.unavailable("Set SUPABASE_URL and SUPABASE_ANON_KEY before using live auth.")
        }

        self.supabaseService = supabaseService
        self.urlSession = urlSession
        self.userDefaults = userDefaults

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date string \(value)")
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func restoreSession() async -> HydraUser? {
        if let cachedUser {
            return cachedUser
        }

        guard let storedSession = loadStoredSession() else {
            return nil
        }

        do {
            let user: HydraUser
            if storedSession.expiresAt > Date().addingTimeInterval(30) {
                user = try await fetchHydraUser(
                    accessToken: storedSession.accessToken,
                    authUserID: storedSession.authUserID
                )
            } else if let refreshed = try await refreshStoredSession(storedSession) {
                user = try await fetchHydraUser(
                    accessToken: refreshed.accessToken,
                    authUserID: refreshed.authUserID
                )
            } else {
                clearStoredSession()
                return nil
            }

            cachedUser = user
            return user
        } catch {
            clearStoredSession()
            return nil
        }
    }

    func signInWithApple() async throws -> HydraUser {
        let result = try await AppleSignInCoordinator().start()

        let session = try await exchangeAuthBody(
            endpoint: .token(grantType: "id_token"),
            body: [
                "provider": "apple",
                "id_token": result.idToken,
                "nonce": result.rawNonce,
            ]
        )

        var user = try await finalizeSignedInSession(session)

        if let fullName = result.fullName?.nilIfEmpty {
            let userID = session.user?.id ?? user.id
            try? await updateUserDisplayName(
                fullName,
                accessToken: session.accessToken,
                userID: userID
            )

            user = HydraUser(
                id: user.id,
                clinicID: user.clinicID,
                role: user.role,
                email: user.email,
                fullName: fullName,
                phone: user.phone,
                dateOfBirth: user.dateOfBirth,
                authProvider: user.authProvider ?? "apple",
                avatarURL: user.avatarURL,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt
            )
            cachedUser = user
        }

        return user
    }

    func signInWithEmail(_ email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            throw AuthServiceError.invalidEmail
        }

        guard isAuthRedirectSchemeRegistered else {
            throw AuthServiceError.unavailable(
                "Magic links need the \(HydraScanConstants.authRedirectScheme) app URL scheme registered in the iOS target before live email sign-in can complete."
            )
        }

        _ = try await requestVoid(
            endpoint: .otp,
            method: .post,
            body: [
                "email": normalizedEmail,
                "create_user": true,
                "email_redirect_to": HydraScanConstants.authRedirectURLString,
            ]
        )
        userDefaults.set(normalizedEmail, forKey: HydraScanConstants.pendingMagicLinkEmailKey)
    }

    func verifyMagicLink(_ url: URL?) async throws -> HydraUser {
        guard let url else {
            throw AuthServiceError.unavailable("Open the magic link from your email on this device to continue.")
        }

        let parameters = parseAuthParameters(from: url)

        if let errorDescription = parameters["error_description"] ?? parameters["error"] {
            throw AuthServiceError.unavailable(errorDescription.removingPercentEncoding ?? errorDescription)
        }

        if parameters["code"] != nil {
            throw AuthServiceError.unavailable(
                "This magic link callback used an auth code flow that is not fully configured in the current app build yet. Use the registered app callback scheme flow or fall back to demo mode for now."
            )
        }

        if
            let accessToken = parameters["access_token"],
            let refreshToken = parameters["refresh_token"]
        {
            let expiresIn = Int(parameters["expires_in"] ?? "") ?? 3600
            let userID = parameters["user_id"].flatMap(UUID.init(uuidString:))
            let session = StoredSupabaseSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
                authUserID: userID
            )
            userDefaults.removeObject(forKey: HydraScanConstants.pendingMagicLinkEmailKey)
            return try await resolveSignedInUser(from: session)
        }

        if let tokenHash = parameters["token_hash"] {
            let response = try await verifyMagicLinkToken(
                tokenHash: tokenHash,
                type: parameters["type"] ?? "magiclink",
                email: parameters["email"] ?? userDefaults.string(forKey: HydraScanConstants.pendingMagicLinkEmailKey)
            )

            let session = StoredSupabaseSession(
                accessToken: response.accessToken ?? "",
                refreshToken: response.refreshToken ?? "",
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)),
                authUserID: response.user?.id
            )

            guard !session.accessToken.isEmpty, !session.refreshToken.isEmpty else {
                throw AuthServiceError.unavailable("The magic link was verified, but no session was returned.")
            }

            userDefaults.removeObject(forKey: HydraScanConstants.pendingMagicLinkEmailKey)
            return try await resolveSignedInUser(from: session)
        }

        throw AuthServiceError.unavailable("This link is missing the session details needed to complete sign-in.")
    }

    func refreshSession() async -> HydraUser? {
        guard let storedSession = loadStoredSession() else {
            return nil
        }

        do {
            guard let refreshed = try await refreshStoredSession(storedSession) else {
                clearStoredSession()
                return nil
            }

            let user = try await fetchHydraUser(
                accessToken: refreshed.accessToken,
                authUserID: refreshed.authUserID
            )
            cachedUser = user
            return user
        } catch {
            clearStoredSession()
            return nil
        }
    }

    func currentUser() async -> HydraUser? {
        if let cachedUser {
            return cachedUser
        }

        return await restoreSession()
    }

    func isAuthenticated() async -> Bool {
        await currentUser() != nil
    }

    func signOut() async {
        let session = loadStoredSession()
        cachedUser = nil
        clearStoredSession()
        userDefaults.removeObject(forKey: HydraScanConstants.pendingMagicLinkEmailKey)

        guard let accessToken = session?.accessToken else {
            return
        }

        var request = URLRequest(url: try! authURL(for: .logout))
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue(HydraScanConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        _ = try? await urlSession.data(for: request)
    }

    private func finalizeSignedInSession(_ session: SupabaseAuthSessionResponse) async throws -> HydraUser {
        let storedSession = StoredSupabaseSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(session.expiresIn)),
            authUserID: session.user?.id
        )
        return try await resolveSignedInUser(from: storedSession)
    }

    private func refreshStoredSession(_ storedSession: StoredSupabaseSession) async throws -> StoredSupabaseSession? {
        let response = try await exchangeAuthBody(
            endpoint: .token(grantType: "refresh_token"),
            body: [
                "refresh_token": storedSession.refreshToken,
            ]
        )

        let refreshed = StoredSupabaseSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            authUserID: response.user?.id ?? storedSession.authUserID
        )
        saveStoredSession(refreshed)
        return refreshed
    }

    private func resolveSignedInUser(from storedSession: StoredSupabaseSession) async throws -> HydraUser {
        saveStoredSession(storedSession)

        do {
            let user = try await fetchHydraUser(
                accessToken: storedSession.accessToken,
                authUserID: storedSession.authUserID
            )
            cachedUser = user

            if user.role == .client {
                _ = try? await supabaseService?.ensureClientProfile(for: user)
            }

            return user
        } catch {
            cachedUser = nil
            clearStoredSession()
            throw error
        }
    }

    private func fetchHydraUser(accessToken: String, authUserID: UUID?) async throws -> HydraUser {
        let authUser = try await fetchAuthUser(accessToken: accessToken)
        let userID = authUserID ?? authUser.id

        let rows: [HydraUserRow] = try await requestJSON(
            path: "/rest/v1/users",
            method: .get,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "select", value: "id,clinic_id,role,email,full_name,phone,date_of_birth,auth_provider,avatar_url,created_at,updated_at"),
            ],
            accessToken: accessToken,
            responseType: [HydraUserRow].self
        )

        guard let row = rows.first else {
            throw AuthServiceError.unavailable("Signed in successfully, but no clinic workspace is assigned yet. Ask your practitioner or admin for an invite before continuing.")
        }

        guard row.role == .client else {
            throw AuthServiceError.unavailable("This iOS build is currently set up for client accounts only. Sign in with a client invite or use demo mode for previews.")
        }

        return row.hydraUser
    }

    private func updateUserDisplayName(
        _ fullName: String,
        accessToken: String,
        userID: UUID
    ) async throws {
        _ = try await requestVoid(
            path: "/rest/v1/users",
            method: .patch,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userID.uuidString)")
            ],
            body: [
                "full_name": fullName,
                "auth_provider": "apple",
            ],
            accessToken: accessToken
        )
    }

    private func fetchAuthUser(accessToken: String) async throws -> SupabaseAuthUser {
        try await requestJSON(
            endpoint: .user,
            method: .get,
            accessToken: accessToken,
            responseType: SupabaseAuthUser.self
        )
    }

    private func verifyMagicLinkToken(
        tokenHash: String,
        type: String,
        email: String?
    ) async throws -> SupabaseVerifyResponse {
        var body: [String: Any] = [
            "token_hash": tokenHash,
            "type": type,
        ]

        if let email, !email.isEmpty {
            body["email"] = email
        }

        return try await requestJSON(
            endpoint: .verify,
            method: .post,
            body: body,
            responseType: SupabaseVerifyResponse.self
        )
    }

    private func exchangeAuthBody(
        endpoint: SupabaseAuthEndpoint,
        body: [String: Any]
    ) async throws -> SupabaseAuthSessionResponse {
        try await requestJSON(
            endpoint: endpoint,
            method: .post,
            body: body,
            responseType: SupabaseAuthSessionResponse.self
        )
    }

    private func requestVoid(
        endpoint: SupabaseAuthEndpoint,
        method: HTTPMethod,
        body: [String: Any]? = nil,
        accessToken: String? = nil
    ) async throws -> Void {
        let _: EmptyAPIResponse = try await requestJSON(
            endpoint: endpoint,
            method: method,
            body: body,
            accessToken: accessToken,
            responseType: EmptyAPIResponse.self,
            acceptEmptyResponse: true
        )
    }

    private func requestVoid(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        accessToken: String? = nil
    ) async throws -> Void {
        let _: EmptyAPIResponse = try await requestJSON(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            accessToken: accessToken,
            responseType: EmptyAPIResponse.self,
            acceptEmptyResponse: true
        )
    }

    private func requestJSON<ResponseType: Decodable>(
        endpoint: SupabaseAuthEndpoint,
        method: HTTPMethod,
        body: [String: Any]? = nil,
        accessToken: String? = nil,
        responseType: ResponseType.Type,
        acceptEmptyResponse: Bool = false
    ) async throws -> ResponseType {
        try await requestJSON(
            path: endpoint.path,
            method: method,
            body: body,
            accessToken: accessToken,
            responseType: responseType,
            acceptEmptyResponse: acceptEmptyResponse
        )
    }

    private func requestJSON<ResponseType: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        accessToken: String? = nil,
        responseType: ResponseType.Type,
        acceptEmptyResponse: Bool = false
    ) async throws -> ResponseType {
        guard var components = URLComponents(
            url: try authURL(forPath: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw AuthServiceError.unavailable("Supabase URL is not valid.")
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw AuthServiceError.unavailable("Supabase request URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(HydraScanConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.unavailable("Supabase did not return a valid HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw AuthServiceError.unavailable(message)
        }

        if acceptEmptyResponse && data.isEmpty, let empty = EmptyAPIResponse() as? ResponseType {
            return empty
        }

        if data.isEmpty, let empty = EmptyAPIResponse() as? ResponseType {
            return empty
        }

        return try decoder.decode(ResponseType.self, from: data)
    }

    private func parseAuthParameters(from url: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                parameters[item.name] = item.value
            }
        }

        if let fragment = URLComponents(string: "scheme://host?\(url.fragment ?? "")") {
            fragment.queryItems?.forEach { item in
                parameters[item.name] = item.value
            }
        }

        return parameters
    }

    private func authURL(for endpoint: SupabaseAuthEndpoint) throws -> URL {
        try authURL(forPath: endpoint.path)
    }

    private func authURL(forPath path: String) throws -> URL {
        guard let baseURL = HydraScanConstants.supabaseURL else {
            throw AuthServiceError.unavailable("Supabase URL is not configured.")
        }

        return baseURL.appending(path: path)
    }

    private func loadStoredSession() -> StoredSupabaseSession? {
        guard let data = userDefaults.data(forKey: HydraScanConstants.sessionStorageKey) else {
            return nil
        }

        return try? decoder.decode(StoredSupabaseSession.self, from: data)
    }

    private func saveStoredSession(_ session: StoredSupabaseSession) {
        if let data = try? encoder.encode(session) {
            userDefaults.set(data, forKey: HydraScanConstants.sessionStorageKey)
        }
    }

    private func clearStoredSession() {
        userDefaults.removeObject(forKey: HydraScanConstants.sessionStorageKey)
    }

    private var isAuthRedirectSchemeRegistered: Bool {
        guard
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else {
            return false
        }

        let schemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        return schemes.contains(HydraScanConstants.authRedirectScheme)
    }

    private struct EmptyAPIResponse: Decodable {
        init?() {}
    }
}
#endif

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private func parseErrorMessage(from data: Data) -> String? {
    guard
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return String(data: data, encoding: .utf8)?.nilIfEmpty
    }

    let preferredKeys = ["msg", "message", "error_description", "error"]
    for key in preferredKeys {
        if let value = object[key] as? String, !value.isEmpty {
            return value
        }
    }

    return nil
}
