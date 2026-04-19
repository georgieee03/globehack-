import Foundation

protocol OfflineCacheServiceProtocol {
    func cacheAssessment(_ assessment: Assessment) async throws
    func getCachedAssessments() async throws -> [CachedAssessment]
    func syncCachedAssessments(using service: SupabaseServiceProtocol) async throws -> Int
    func clearSyncedAssessments() async throws
    func hasPendingUploads() async -> Bool
}

struct CachedAssessment: Identifiable, Codable, Hashable {
    var id: UUID
    var assessment: Assessment
    var createdAt: Date
    var syncedAt: Date?
    var lastError: String?
}

actor OfflineCacheService: OfflineCacheServiceProtocol {
    nonisolated static let shared = OfflineCacheService()

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let cacheDirectoryURL = applicationSupportURL
            .appendingPathComponent("HydraScan", isDirectory: true)
            .appendingPathComponent("OfflineCache", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        fileURL = cacheDirectoryURL.appendingPathComponent("cached-assessments.json")
    }

    func cacheAssessment(_ assessment: Assessment) async throws {
        var cachedAssessments = try loadCache()
        guard !cachedAssessments.contains(where: { $0.assessment.id == assessment.id }) else {
            return
        }

        cachedAssessments.insert(
            CachedAssessment(
                id: assessment.id,
                assessment: assessment,
                createdAt: Date(),
                syncedAt: nil,
                lastError: nil
            ),
            at: 0
        )
        try saveCache(cachedAssessments)
    }

    func getCachedAssessments() async throws -> [CachedAssessment] {
        try loadCache().filter { $0.syncedAt == nil }
    }

    func syncCachedAssessments(using service: SupabaseServiceProtocol) async throws -> Int {
        var cachedAssessments = try loadCache()
        var syncedCount = 0

        for index in cachedAssessments.indices {
            guard cachedAssessments[index].syncedAt == nil else { continue }

            do {
                _ = try await service.createAssessment(cachedAssessments[index].assessment)
                cachedAssessments[index].syncedAt = Date()
                cachedAssessments[index].lastError = nil
                syncedCount += 1
            } catch {
                cachedAssessments[index].lastError = error.localizedDescription
            }
        }

        try saveCache(cachedAssessments)
        return syncedCount
    }

    func clearSyncedAssessments() async throws {
        try saveCache(try loadCache().filter { $0.syncedAt == nil })
    }

    func hasPendingUploads() async -> Bool {
        (try? loadCache().contains(where: { $0.syncedAt == nil })) ?? false
    }

    private func loadCache() throws -> [CachedAssessment] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return []
        }

        return try decoder.decode([CachedAssessment].self, from: data)
    }

    private func saveCache(_ cachedAssessments: [CachedAssessment]) throws {
        let data = try encoder.encode(cachedAssessments)
        try data.write(to: fileURL, options: .atomic)
    }
}
